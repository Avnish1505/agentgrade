"""Thin client for the Agent API and the session trace API.

Every endpoint below is marked VERIFY. Fill them in from the current
Salesforce developer documentation for your org before running. They are not
guessed here on purpose: a wrong path copied from memory costs more time than
looking it up once.
"""

import time
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
    citations: list[str] = field(default_factory=list)
    latency_ms: float = 0.0
    error: str | None = None
    raw_trace: dict[str, Any] | None = None


class AgentClient:
    def __init__(self, cfg: dict):
        self.cfg = cfg
        self.session = requests.Session()
        self._token: str | None = None

    # --- auth -------------------------------------------------------------

    def authenticate(self) -> None:
        """Client credentials flow via an External Client App.

        VERIFY: token_url and the expected payload shape.
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
        """VERIFY: Agent API session start path and response field name."""
        raise NotImplementedError(
            "Fill in the Agent API session start call from current docs."
        )

    def send_message(self, session_id: str, text: str) -> dict:
        """VERIFY: Agent API message path and response shape."""
        raise NotImplementedError(
            "Fill in the Agent API send message call from current docs."
        )

    def end_session(self, session_id: str) -> None:
        """VERIFY: Agent API session end path."""
        raise NotImplementedError

    def fetch_trace(self, session_id: str) -> dict:
        """VERIFY: session trace endpoint.

        Note: trace data is only retrievable for a limited window after the
        session, so fetch it immediately rather than at the end of the run.
        """
        raise NotImplementedError

    # --- one full case ----------------------------------------------------

    def run_case(self, case_id: str, utterance: str) -> AgentTurn:
        turn = AgentTurn(case_id=case_id, utterance=utterance)
        started = time.perf_counter()
        try:
            turn.session_id = self.start_session()
            reply = self.send_message(turn.session_id, utterance)
            turn.response_text = extract_text(reply)
            turn.citations = extract_citations(reply)
            turn.raw_trace = self.fetch_trace(turn.session_id)
            turn.routed_subagent = extract_subagent(turn.raw_trace)
            turn.actions_invoked = extract_actions(turn.raw_trace)
            self.end_session(turn.session_id)
        except Exception as exc:  # noqa: BLE001 - record and continue the suite
            turn.error = f"{type(exc).__name__}: {exc}"
        turn.latency_ms = (time.perf_counter() - started) * 1000
        return turn


# --- response parsing -----------------------------------------------------
# These depend on the exact response shape. Write them once you have printed
# a real response, not before.


def extract_text(reply: dict) -> str:
    raise NotImplementedError("Print a real Agent API response, then map it here.")


def extract_citations(reply: dict) -> list[str]:
    raise NotImplementedError("Map citation objects once grounding is wired up.")


def extract_subagent(trace: dict | None) -> str | None:
    raise NotImplementedError("Map the routed subagent field from a real trace.")


def extract_actions(trace: dict | None) -> list[str]:
    raise NotImplementedError("Map the ordered action list from a real trace.")
