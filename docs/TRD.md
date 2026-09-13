# Technical Requirements Document — AgentGrade

Owner: Avnish
Status: draft
Last updated: TODO

> This is the document a senior engineer will actually read. Section 3 is the core of it.

---

## 1. Architecture overview

Diagram: `diagrams/architecture.mmd`

The agent runs natively in a Salesforce Developer Edition org. The evaluation harness is an external Python service that calls the Agent API and reads session traces. Nothing about the agent is simulated.

TODO: two paragraphs of prose explaining the flow.

## 2. Agent topology

Diagram: `diagrams/topology.mmd`

| Subagent | Purpose | Actions it can call |
| --- | --- | --- |
| Order Status | Answer questions about an existing order | GetOrderStatus, GroundedPolicyAnswer |
| Returns and Refunds | Handle return and refund requests | CheckReturnWindow, ProcessRefund, CreateEscalationCase |
| Fallback | Anything else | LogUnhandled, CreateEscalationCase |

TODO: paste the final instructions for each subagent here once written.

## 3. Deterministic versus prompt boundary

This table is the intellectual core of the project. Every row is a decision, and every decision has exactly one owner.

| Decision | Owner | Why |
| --- | --- | --- |
| Which subagent handles the request | LLM | Intent classification is a language problem |
| How the response is worded | LLM | Tone and phrasing |
| Whether a refund is within the policy cap | Agent Script | A number comparison must never be negotiable |
| Whether the item is inside the return window | Agent Script | Date arithmetic, not judgement |
| Whether the requester owns the order | Agent Script | Authorisation is never a model decision |
| Whether to escalate | Agent Script | Follows deterministically from the checks above |
| What context goes into the escalation case | LLM | Summarisation |

TODO: add rows as you build. If a row is hard to classify, that is the interesting part — write down why.

## 4. Grounding and retrieval design

TODO once Phase 4 is done or cut.

Cover: which documents are ingested, DLO to DMO mapping, chunking, what the retriever returns, and how citations are surfaced so the harness can verify them.

If grounding was cut, say so plainly here and describe the fallback. A documented cut is fine; a silent gap is not.

## 5. Actions

For each action: inputs, outputs, errors, and limits.

### GetOrderStatus
- Type: Apex
- Inputs: TODO
- Outputs: TODO
- Failure modes: TODO
- Limits to respect: bulkification, action timeout

### ProcessRefund
- Type: Apex
- Inputs: TODO
- Outputs: TODO
- Precondition: the Agent Script gate must have passed. This action must be unreachable otherwise.
- Failure modes: TODO

TODO: repeat for the remaining actions.

## 6. Error handling and escalation

TODO. Cover: action failure, ambiguous intent, guardrail violation, repeated failure in one session, and what the user sees in each case.

## 7. Evaluation harness design

**Test case schema** — see `eval-harness/testcases/testcases.csv`.

**Checks**

| Check | Method | Why this method |
| --- | --- | --- |
| Routing | Deterministic comparison against expected subagent from the session trace | No judgement needed, so no model needed |
| Action sequence | Deterministic comparison of the ordered action list | Same reason |
| Grounding | Deterministic citation presence first, model judgement only for claim support | An LLM judge is useful but not trustworthy on its own |

Note on the grounding check: an LLM-as-judge baseline once outperformed my deterministic detector on a previous benchmark project. That result is why the judge here is scoped to the one check that genuinely needs language understanding, and why its disagreements with the deterministic check are reported rather than hidden.

**Pacing** — the Developer Edition allows a limited number of LLM generations per hour. The runner paces requests to stay under it and resumes cleanly. TODO: record the measured generations consumed by one full suite run.

## 8. Observability

TODO. Which session trace fields are consumed, how latency is derived, and what the dashboard shows.

## 9. Security and trust

TODO. Agent user permissions, field level access, what data the agent can and cannot see, and where the Einstein Trust Layer sits in the flow.

## 10. Platform limits and constraints

TODO: record the actual limits you hit, with dates. Verify each against current Salesforce documentation before quoting it in an interview; limits change between releases.

| Limit | Value observed | Where it bit me |
| --- | --- | --- |
| LLM generations per hour | TODO | TODO |
| Data Cloud data spaces | TODO | TODO |
| Org inactivity before deletion | TODO | TODO |
