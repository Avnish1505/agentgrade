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

As authored in `force-app/main/default/aiAuthoringBundles/AgentGrade/AgentGrade.agent` (read from the file, not from an earlier plan):

Router (`start_agent agent_router`) instructions: Route to OrderStatus when the customer asks about the status or delivery of an existing order, such as where it is, whether it has shipped, or when it arrived. Route to ReturnsRefunds when the customer wants to send something back, get money back, cancel an order, or asks about return and refund policy. Route to Fallback when the request is not about an order, a return, or a refund. When a request is too vague to place, ask one short clarifying question before routing rather than guessing.

| Subagent | Description (from file) | Actions wired (from file) | Instructions |
| --- | --- | --- | --- |
| OrderStatus | Looks up order status, dates and total for the customer. | GetOrderStatus | This subagent handles questions about the status and delivery of an existing order. It looks up the order and reports what it finds. It does not handle returns, refunds, cancellations, or policy questions. If the customer asks for any of those, hand off to ReturnsRefunds. If no matching order is found, say so plainly and do not speculate about what may have happened. |
| ReturnsRefunds | Checks return-window eligibility and escalates return requests to a human. | CheckReturnWindow, CreateEscalationCase | This subagent handles returns, refunds, order cancellations, and questions about return and refund policy. It gathers facts first: whether the order exists, when it was delivered, and what the customer is asking for. It does not announce a refund decision on its own. Cancellation requests are not processed automatically; gather the details and escalate them for a person to handle, and do not check the return window for an order that has not been delivered. If a customer asks a policy question without naming an order, answer the policy question rather than asking for an order number. |
| Fallback | Records a user message the agent could not handle, for later human review. | LogUnhandled | This subagent handles anything the other two do not cover, such as questions about products we do not sell, general enquiries, or messages unrelated to an order. It never invents an answer and never guesses at account or order details. It records the request and tells the customer that a person will follow up. |

ProcessRefund is not wired to any subagent, by design (see section 3).

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

Note (Phase 2): ProcessRefund itself enforces none of the rows above — it is a plain executor that creates an Approved ReturnRequest__c for whatever amount it is given, with no cap, window or ownership check. That is deliberate: all three checks live only in the Phase 3 Agent Script gate, so Phase 5 can measure the agent's behavior with and without that gate in front of this action.

## 4. Grounding and retrieval design

TODO once Phase 4 is done or cut.

Cover: which documents are ingested, DLO to DMO mapping, chunking, what the retriever returns, and how citations are surfaced so the harness can verify them.

If grounding was cut, say so plainly here and describe the fallback. A documented cut is fine; a silent gap is not.

## 5. Actions

For each action: inputs, outputs, errors, and limits. All five are `@InvocableMethod` Apex classes in `force-app/main/default/classes/`, bulk-safe (each does a fixed number of SOQL/DML statements regardless of list size), and designed to never throw for bad input — a malformed Id or a missing record produces a result with `success`/`found = false` and a message, not an exception.

### GetOrderStatus
- Type: Apex (`GetOrderStatus.getOrderStatus`)
- Inputs: `orderNumber` (String, optional), `customerEmail` (String, optional). If both are given, order number takes precedence.
- Outputs: `found` (Boolean), `orderNumber`, `status`, `orderDate`, `deliveredDate`, `totalAmount`, `message`
- Failure modes: neither input given, or no matching order → `found = false` with an explanatory message. By email, returns only the single most recent order (by `OrderDate__c`) if the customer has more than one.
- Limits to respect: bulkification, action timeout

### CheckReturnWindow
- Type: Apex (`CheckReturnWindow.checkReturnWindow`)
- Inputs: `orderId` (String, optional), `orderNumber` (String, optional). Order Id takes precedence if both are given.
- Outputs: `found`, `isDelivered`, `insideWindow`, `daysSinceDelivery`, `windowDays` (read from `RefundPolicy__mdt.Default.ReturnWindowDays__c`), `message`
- Failure modes: neither input given, no matching order, or a malformed Id → `found = false`. Not yet delivered → `isDelivered = false`, `insideWindow` and `daysSinceDelivery` left blank. Missing `RefundPolicy__mdt.Default` record → `windowDays` and `insideWindow` left blank rather than guessing a default.
- Fact-only: does not approve, deny, or process anything.

### ProcessRefund
- Type: Apex (`ProcessRefund.processRefund`)
- Inputs: `orderId` (String, required), `orderItemId` (String, optional — blank for a whole-order refund), `amount` (Decimal, required), `reason` (String, required — must be one of `ReturnRequest__c.Reason__c`'s restricted picklist values or the insert fails)
- Outputs: `success`, `returnRequestId`, `message`
- Creates a `ReturnRequest__c` with `Outcome__c = 'Approved'` unconditionally.
- Precondition: the Agent Script gate must have passed. This action must be unreachable otherwise - see the note in section 3.
- Failure modes: malformed `orderId`/`orderItemId`, or a DML-level rejection (e.g. an invalid `reason` value) → `success = false` with the platform error message, per request, without failing the whole batch.

### CreateEscalationCase
- Type: Apex (`CreateEscalationCase.createEscalationCase`)
- Inputs: `orderId` (String, required — recorded in the case description; Case has no direct order relationship), `reason` (String, required — becomes the case subject), `contextSummary` (String, required), `returnRequestId` (String, optional)
- Outputs: `success`, `caseId`, `caseNumber`, `message`
- If `returnRequestId` is supplied: sets that record's `Outcome__c = 'Escalated'`, `DecisionReason__c = reason`, and `EscalationCase__c` to the new case.
- Failure modes: the Case insert itself failing (e.g. an oversized `contextSummary`) → `success = false`. A malformed or nonexistent `returnRequestId` does not fail the case creation - the case is still created and the result message carries a warning instead.

### LogUnhandled
- Type: Apex (`LogUnhandled.logUnhandled`)
- Inputs: `utterance` (String, required)
- Outputs: `success`, `caseId`, `message`
- Creates a Case with a fixed `Subject` (`AgentGrade: Unhandled Utterance`) and the utterance as `Description`, rather than a new object.
- Failure modes: DML-level rejection (e.g. an oversized utterance) → `success = false`.

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

Note (Phase 2 baseline, org-verified): ungrounded factual assertions were observed in the Phase 2 baseline run (`eval-harness/results/phase2-baseline.md`) — the agent stated an order lookup result and a policy answer without invoking the underlying action or data lookup. This is the grounding failure mode the harness's grounding check is meant to catch.

**Pacing** — the Developer Edition allows a limited number of LLM generations per hour. The runner paces requests to stay under it and resumes cleanly. TODO: record the measured generations consumed by one full suite run.

## 8. Observability

TODO. Which session trace fields are consumed, how latency is derived, and what the dashboard shows.

## 9. Security and trust

TODO. Agent user permissions, field level access, what data the agent can and cannot see, and where the Einstein Trust Layer sits in the flow.

Note (Phase 1, org-verified): Metadata API deploys do not grant field-level security — a freshly deployed custom field is invisible to SOQL and Apex ("No such column") for every profile until FLS is granted explicitly, confirmed via `FieldPermissions` for this org. `AgentGrade_Access` (`force-app/main/default/permissionsets/`) is the permission set that grants it for `Order__c`, `OrderItem__c`, `ReturnRequest__c`, and read on `Case`; assign it to any user or agent-running user that needs these records.

Note (Phase 2, org-verified): `access.default_agent_user` in an Agent Script file requires a user holding the Einstein Agent license specifically — a Standard User's Salesforce license does not satisfy this, and the org rejects reassigning an existing Standard User to that license type directly. `agentgrade.runner.agent@00dak00001f6nyt.agentgrade.test` is the dedicated Einstein Agent User-profile user created for this, with `AgentGrade_Access` assigned.

Note (Phase 2, org-verified): a manually created agent runner user does not receive the platform-provisioned grants that an auto-created one (e.g. Greeting_Assistant's) gets automatically, which surfaces as "User doesn't have access to agent" on commit even though the user's profile, license, and custom permission set all look correct. For `agentgrade.runner.agent@...`, the four missing grants were the `AgentforceServiceAgentUserPsg` and `AgentforceServiceAgentSecureBase` permission sets and the `Data Cloud` and `Einstein Prompt Templates` permission set licenses. Assigning `AgentforceServiceAgentSecureBase` auto-granted both permission set licenses as a side effect; only the two permission sets needed explicit assignment.

## 10. Platform limits and constraints

TODO: record the actual limits you hit, with dates. Verify each against current Salesforce documentation before quoting it in an interview; limits change between releases.

| Limit | Value observed | Where it bit me |
| --- | --- | --- |
| LLM generations per hour | TODO | TODO |
| Data Cloud data spaces | TODO | TODO |
| Org inactivity before deletion | TODO | TODO |
