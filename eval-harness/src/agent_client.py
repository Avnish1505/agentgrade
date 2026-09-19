"""Thin client for the Agent API and the session trace API.

Endpoints and request/response shapes below are confirmed, not guessed:

- start_session / send_message / end_session bodies and paths come straight
  from the @salesforce/agents SDK source (productionAgent.js - the library
  `sf agent` itself uses), cross-checked against three real, printed
  responses from this org's AgentGrade agent (see
  eval-harness/results/baselines/ for the raw captures).
- fetch_trace targets the real Agentforce Session Trace (OTel, Beta)
  endpoint. In THIS org it returns a confirmed, reproducible error:
  400 {"errorCode": "BAD_REQUEST", "message": "No selected dataspace for
  Einstein Audit"} - Data Cloud has no dataspace configured for Einstein
  Audit here. That is treated as a normal, expected outcome (not a crash):
  fetch_trace returns {"available": False, ...} rather than raising, so
  run_case still reaches end_session for every case.
- extract_subagent / extract_actions have NEVER seen a real, populated
  trace in this org (every attempt returned the dataspace error above), so
  they do not invent a field mapping. They return None / [] when the trace
  is unavailable, and raise NotImplementedError if a trace ever DOES come
  back with a shape nobody has verified yet - map it from a real response
  when that happens, not before.
"""

import time
import uuid
from dataclasses import dataclass, field
from typing import Any

import requests


@dataclass
class AgentTurn:
    """One request/response exchange with the agent."""

    case_id: str
    utterance: str
    response_text: str = ""
    session_id: str = ""
    routed_subagent: str | None = None
    actions_invoked: list[str] = field(default_factory=list)
    citations: list[Any] = field(default_factory=list)
    latency_ms: float = 0.0
    error: str | None = None
    raw_trace: dict[str, Any] | None = None
    trace_available: bool = False


class AgentClient:
    def __init__(self, cfg: dict):
        self.cfg = cfg
        self.session = requests.Session()
        self._token: str | None = None
        self._seq_counters: dict[str, int] = {}
        # Real, measured count of send_message calls made - not an estimate.
        # No API signal for actual LLM-generation cost was found anywhere:
        # every real response's "metrics" field came back {} (empty), and
        # no matching row exists in TenantUsageEntitlement (checked all 24
        # rows in this org, none reference AI/generation/Einstein/Agent
        # usage). This counter is the honest floor - one confirmed agent
        # turn per increment - not a claim about Salesforce's internal
        # generation-credit accounting, which stays opaque from outside.
        self.messages_sent = 0

    # --- auth -------------------------------------------------------------

    def authenticate(self) -> None:
        """Client credentials flow via an External Client App.

        Confirmed working (2026-09-19) once the ECA's OAuth policy had
        "Issue JSON Web Token (JWT)-based access tokens for named users"
        enabled. Before that fix the token was opaque-format and every
        Agent API call 404'd - the token itself looked valid (200, real
        access_token) so this failure mode is easy to miss.
        """
        org = self.cfg["org"]
        resp = self.session.post(
            org["token_url"],
            data={
                "grant_type": "client_credentials",
                "client_id": org["client_id"],
                "client_secret": org["client_secret"],
            },
            timeout=self.cfg["run"]["timeout_seconds"],
        )
        resp.raise_for_status()
        self._token = resp.json()["access_token"]

    def _headers(self) -> dict:
        if not self._token:
            self.authenticate()
        return {
            "Authorization": f"Bearer {self._token}",
            "Content-Type": "application/json",
        }

    # --- conversation -----------------------------------------------------

    def start_session(self) -> str:
        """POST {api_base}/agents/{agent_id}/sessions.

        Body shape and the api.salesforce.com host are confirmed from the
        @salesforce/agents SDK (productionAgent.js) and a real 200 response
        captured in this org: {"sessionId": "...", "_links": {...},
        "messages": [{"type": "Inform", "message": "<greeting>", ...}]}.
        """
        org = self.cfg["org"]
        agent = self.cfg["agent"]
        timeout = self.cfg["run"]["timeout_seconds"]
        sf_domain = org["instance_url"].rstrip("/")
        url = f"{agent['api_base']}/agents/{agent['agent_id']}/sessions"
        body = {
            "externalSessionKey": str(uuid.uuid4()),
            "instanceConfig": {"endpoint": sf_domain + "/"},
            "tz": "Asia/Kolkata",
            "featureSupport": "Sync",
            "bypassUser": True,
        }
        resp = self.session.post(url, headers=self._headers(), json=body, timeout=timeout)
        resp.raise_for_status()
        session_id = resp.json()["sessionId"]
        self._seq_counters[session_id] = 0
        return session_id

    def send_message(self, session_id: str, text: str) -> dict:
        """POST {api_base}/sessions/{session_id}/messages.

        Confirmed real response shape: {"messages": [{"type": "Inform",
        "feedbackId": "...", "isContentSafe": true, "message": "<reply
        text>", "id": "...", "metrics": {}, "planId": "...",
        "result": [], "citedReferences": []}], "_links": {...}}.

        "result" and "citedReferences" have only ever been observed empty
        in this org - extract_citations passes them through as-is rather
        than assuming a populated shape nobody has seen.
        """
        agent = self.cfg["agent"]
        timeout = self.cfg["run"]["timeout_seconds"]
        self._seq_counters[session_id] = self._seq_counters.get(session_id, 0) + 1
        url = f"{agent['api_base']}/sessions/{session_id}/messages"
        body = {
            "message": {
                "sequenceId": self._seq_counters[session_id],
                "type": "Text",
                "text": text,
            },
            "variables": [],
        }
        resp = self.session.post(url, headers=self._headers(), json=body, timeout=timeout)
        resp.raise_for_status()
        self.messages_sent += 1
        return resp.json()

    def end_session(self, session_id: str, reason: str = "UserRequest") -> None:
        """DELETE {api_base}/sessions/{session_id}.

        Confirmed: returns 200 with {"messages": [{"type": "SessionEnded",
        "reason": "ClientRequest", ...}], "_links": {...}}. Note the
        response's "reason" came back "ClientRequest" regardless of the
        x-session-end-reason header value sent ("UserRequest") - the header
        doesn't appear to be echoed verbatim, so don't rely on it downstream.
        """
        agent = self.cfg["agent"]
        timeout = self.cfg["run"]["timeout_seconds"]
        url = f"{agent['api_base']}/sessions/{session_id}"
        headers = self._headers()
        headers["x-session-end-reason"] = reason
        resp = self.session.delete(url, headers=headers, timeout=timeout)
        resp.raise_for_status()
        self._seq_counters.pop(session_id, None)

    def fetch_trace(self, session_id: str) -> dict:
        """GET {instance_url}/services/data/v66.0/einstein/audit/otel/{session_id}.

        Confirmed in this org: 400 {"errorCode": "BAD_REQUEST", "message":
        "No selected dataspace for Einstein Audit"} - Data Cloud has no
        dataspace wired up for Einstein Audit here. This is treated as an
        expected, non-fatal outcome so the harness can still end every
        session: returns {"available": False, "status": <code>,
        "error": <raw body>} instead of raising. If a future call ever
        returns 200 with real trace content, that dict is returned under
        {"available": True, "data": <raw json>} UNCHANGED - map its real
        fields in extract_subagent/extract_actions once that happens, not
        before.
        """
        org = self.cfg["org"]
        timeout = self.cfg["run"]["timeout_seconds"]
        sf_domain = org["instance_url"].rstrip("/")
        url = f"{sf_domain}/services/data/v66.0/einstein/audit/otel/{session_id}"
        resp = self.session.get(url, headers=self._headers(), timeout=timeout)
        if resp.status_code != 200:
            return {"available": False, "status": resp.status_code, "error": resp.text}
        return {"available": True, "data": resp.json()}

    # --- one full case ----------------------------------------------------

    def run_case(self, case_id: str, utterance: str) -> AgentTurn:
        turn = AgentTurn(case_id=case_id, utterance=utterance)
        started = time.perf_counter()
        session_started = False
        try:
            turn.session_id = self.start_session()
            session_started = True
            reply = self.send_message(turn.session_id, utterance)
            turn.response_text = extract_text(reply)
            turn.citations = extract_citations(reply)
            turn.raw_trace = self.fetch_trace(turn.session_id)
            turn.trace_available = bool(turn.raw_trace.get("available"))
            turn.routed_subagent = extract_subagent(turn.raw_trace)
            turn.actions_invoked = extract_actions(turn.raw_trace)
        except Exception as exc:  # noqa: BLE001 - record and continue the suite
            turn.error = f"{type(exc).__name__}: {exc}"
        finally:
            # Always try to close the session we opened, even if a later
            # step (trace fetch, parsing) failed - otherwise every failed
            # case leaks an open session for the rest of the hourly window.
            if session_started and turn.session_id:
                try:
                    self.end_session(turn.session_id)
                except Exception as exc:  # noqa: BLE001
                    if not turn.error:
                        turn.error = f"end_session failed: {type(exc).__name__}: {exc}"
        turn.latency_ms = (time.perf_counter() - started) * 1000
        return turn


# --- response parsing -----------------------------------------------------
# Mapped from the real responses captured in this org (2026-09-19). Nothing
# here is guessed; see the docstrings above for the exact raw shapes.


def extract_text(reply: dict) -> str:
    """Join every message's "message" text. Every real response so far has
    had exactly one entry in "messages", but join defensively in case a
    turn ever returns more than one."""
    parts = [m.get("message", "") for m in reply.get("messages", []) if m.get("message")]
    return "\n".join(parts)


def extract_citations(reply: dict) -> list[Any]:
    """Flatten "citedReferences" across all messages. Every real response
    so far has had this as an empty list, so the internal shape of a
    populated citation object is unconfirmed - pass entries through
    unchanged rather than guessing a field to pull out of them."""
    citations: list[Any] = []
    for m in reply.get("messages", []):
        citations.extend(m.get("citedReferences", []))
    return citations


def extract_subagent(trace: dict | None) -> str | None:
    if not trace or not trace.get("available"):
        return None
    raise NotImplementedError(
        "A real trace came back with data for the first time - map the "
        "routed-subagent field from trace['data'] here before relying on "
        "this, rather than guessing."
    )


def extract_actions(trace: dict | None) -> list[str]:
    if not trace or not trace.get("available"):
        return []
    raise NotImplementedError(
        "A real trace came back with data for the first time - map the "
        "ordered action list from trace['data'] here before relying on "
        "this, rather than guessing."
    )
