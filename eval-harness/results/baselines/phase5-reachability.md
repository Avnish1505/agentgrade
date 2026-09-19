# Phase 5 — Agent API reachability (Step 1 verification)

Date: 2026-09-19

## Fix

Root cause of the earlier 404s (session-start returning 404 despite a valid,
non-empty client-credentials token): the External Client App
(AgentGrade Eval Harness) was issuing an **opaque** access token instead of
a **JWT-format** one. Fixed manually in Setup:
Setup > External Client Apps > AgentGrade Eval Harness > OAuth Policies >
Security > "Issue JSON Web Token (JWT)-based access tokens for named users"
- enabled and saved. "Enable JWT Bearer Flow" was deliberately left off
(different auth flow).

Token before fix: opaque, ~181 chars, `00D...!...` format, no `token_format`
field in the token response.
Token after fix: JWT (3 dot-separated segments), 1610 chars, token response
includes `"token_format": "jwt"` and `"scope": "sfap_api chatbot_api api"`.

## Step 1 — session start (raw, real)

`POST https://api.salesforce.com/einstein/ai-agent/v1/agents/0Xxak0000043713CAA/sessions`

Request body:
```json
{
  "externalSessionKey": "<uuid4>",
  "instanceConfig": { "endpoint": "https://orgfarm-a5685c6333-dev-ed.develop.my.salesforce.com/" },
  "tz": "Asia/Kolkata",
  "featureSupport": "Sync",
  "bypassUser": true
}
```

Response: `200`
```json
{
  "sessionId": "01a0b7fa-fe3d-74b2-baaf-d99a2b1f1090",
  "_links": {
    "self": null,
    "messages": {"href": "https://api.salesforce.com/einstein/ai-agent/v1/sessions/01a0b7fa-fe3d-74b2-baaf-d99a2b1f1090/messages"},
    "messagesStream": {"href": "https://api.salesforce.com/einstein/ai-agent/v1/sessions/01a0b7fa-fe3d-74b2-baaf-d99a2b1f1090/messages/stream"},
    "session": {"href": "https://api.salesforce.com/einstein/ai-agent/v1/agents/0Xxak0000043713CAA/sessions"},
    "end": {"href": "https://api.salesforce.com/einstein/ai-agent/v1/sessions/01a0b7fa-fe3d-74b2-baaf-d99a2b1f1090"}
  },
  "messages": [
    {
      "type": "Inform",
      "feedbackId": "",
      "isContentSafe": true,
      "message": "Hi, I'm here to help with your order or a return. What can I help you with?",
      "id": "9d9b5c76-6f07-4548-97e1-38165891e0b4",
      "metrics": {},
      "planId": "",
      "result": [],
      "citedReferences": []
    }
  ]
}
```

**Verdict: reachable. Fix confirmed.**

## Step 2 — send one message (raw, real)

`POST https://api.salesforce.com/einstein/ai-agent/v1/sessions/{sessionId}/messages`

Request: `{"message": {"sequenceId": 1, "type": "Text", "text": "Where is my order ORD-0007?"}, "variables": []}`

Response: `200`
```json
{
  "messages": [
    {
      "type": "Inform",
      "feedbackId": "0b41d9b9-3066-436d-9b5b-0cd05784442e",
      "isContentSafe": true,
      "message": "I am checking the status of order ORD-0007. Could you confirm the name or email address used for this order to help me locate it?",
      "id": "7d6a8a59-7ea4-471b-b0e5-fddfab672d5a",
      "metrics": {},
      "planId": "0b41d9b9-3066-436d-9b5b-0cd05784442e",
      "result": [],
      "citedReferences": []
    }
  ],
  "_links": { "...": "same shape as session start" }
}
```

`result` and `citedReferences` were empty in every real call made during this
verification (three separate turns). Their populated shape is unconfirmed.

`feedbackId` and `planId` were equal in every observed response.

## end_session (raw, real)

`DELETE {api_base}/sessions/{sessionId}` with header
`x-session-end-reason: UserRequest` →

```json
{"messages": [{"type": "SessionEnded", "reason": "ClientRequest", "id": "...", "metrics": {}, "feedbackId": ""}], "_links": {...}}
```

Note: the response's `reason` came back `"ClientRequest"` regardless of the
`x-session-end-reason` header value sent - the header is not echoed
verbatim.

## Trace fetch — confirmed unavailable in this org

`GET {instance_url}/services/data/v66.0/einstein/audit/otel/{sessionId}`
(same bearer token, called immediately after a real send_message) →

`400`
```json
[{"errorCode": "BAD_REQUEST", "message": "No selected dataspace for Einstein Audit"}]
```

This is Data Cloud / Einstein Audit dataspace provisioning, not an auth or
path problem - the same token is accepted (it's a business-logic 400, not
401/403), and the error is specific and named. **This means routing,
action-sequence, and claimed-but-not-performed checks are structurally
untestable in this org right now, on top of the guardrail gate already
documented as unreachable in `docs/TRD.md` sections 3 and 10** - not a new
problem, but a wider-than-expected instance of the same one. See
`eval-harness/src/agent_client.py` (`fetch_trace`) and `metrics.py` for how
the harness handles this without crashing or reporting false pass/fail
signals.

## Re-test after Setup > Einstein Audit, Analytics, and Monitoring Setup check (2026-09-19, same day)

Re-ran the identical probe (fresh session, real send_message, immediate
`GET .../einstein/audit/otel/{sessionId}` with the same bearer token) after
checking Data Cloud / Agentforce Session Tracing setup:

`400`
```json
[{"errorCode": "BAD_REQUEST", "message": "No selected dataspace for Einstein Audit"}]
```

Identical error, byte-for-byte, on a new session id. Not chased further per
instruction - see `docs/TRD.md` section 10 for the closing note. The 70-case
suite was run as-is: grounding scored for real, routing/action-sequence/
guardrail/claimed-but-not-performed all report `"status": "untestable"`.
