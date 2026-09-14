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
|---|---|---|
| Which subagent handles the request | LLM | Intent classification is a language problem |
| How the response is worded | LLM | Tone and phrasing |
| Whether the order exists and its current status | Apex action | A data lookup, not a decision |
| Whether the requester owns the order | Agent Script | Authorisation is never a model decision |
| Whether the item was delivered within 30 days | Agent Script | Date arithmetic, not judgement |
| Whether the refund amount is 500 or less | Agent Script | A number comparison must never be negotiable |
| Whether the item is marked returnable | Agent Script | A stored flag, read not interpreted |
| Whether the return reason qualifies for an automatic refund | Agent Script | The policy lists the qualifying reasons explicitly |
| Whether to escalate | Agent Script | Follows deterministically from the checks above |
| Whether ProcessRefund runs at all | Agent Script | The refund action must be unreachable unless every check passes |
| Whether a cancellation is processed automatically | Agent Script, always no | The policy allows no exception |
| The summary text written into the escalation case | LLM | Summarisation |

Note (Phase 3 scope decision, deliberate): the "whether the requester owns the order" row is not implemented in the Phase 3 gate for this dev environment. There is no authenticated customer in an `sf agent preview` session, so any `requester_email` the gate compared against `Order__c.CustomerEmail__c` would be invented, and the check would prove nothing - it would always pass or always fail by construction, not by fact. The other four Agent Script rows run against real seeded data and are sufficient for this phase. In production, ownership would be verified against the authenticated session's identity (for example a linked variable sourced from the Messaging session's end-user record), not a value the agent or the harness supplies itself.

Note (Phase 3 implementation, org-verified): the table above is now implemented in `ReturnsRefunds`, not just designed. `check_return_window`'s tool call chains automatically into `get_order_items` (the LLM's one call triggers both, deterministically, per Agent Script's action-chaining mechanism). A deterministic `if`/`set` block at the top of `ReturnsRefunds`' `reasoning.instructions` - which runs unconditionally every time the subagent is processed, before any prompt reaches the LLM - computes `amount_ok`, `reason_qualifies`, `must_escalate` and `refund_approved` from values echoed back by `check_return_window` (`orderId`, the verified `orderItemId`, `lineTotal`, `isReturnable`, `insideWindow`, `reason`). `process_refund` (newly exposed here - previously unreachable from any subagent, see the note below) is gated `available when @variables.refund_approved == True`; `create_escalation_case` is gated `available when @variables.must_escalate == True`. `is_cancellation` is captured via `@utils.setVariables`, the documented mechanism for the LLM to record a fact directly into a variable with no backing Apex action. `sf agent validate authoring-bundle` passes clean against this. One real syntax lesson: the `must_escalate`/`refund_approved` boolean expressions must be a single line each - a first draft split them across multiple parenthesized lines and the validator rejected it with a long cascade of errors; Agent Script's own documented examples never split a conditional expression across lines, however long.

Note (Phase 3, known and accepted limitation - later revisited, see below): the turn-1 extraction gap identified in the Phase 2 baseline (no documented Agent Script mechanism deterministically extracts a value already stated in the customer's own utterance into a variable, before any LLM tool call) is not solved by this gate and was not attempted - see section 10. The gate's deterministic checks only run once `order_id` etc. are populated, which still depends on the LLM choosing to call `check_return_window`. The Phase 3 gate test utterances are written to supply the order number, item and reason together for this reason, so the model has no missing information that would give it a reason to ask instead of calling the tool.

Note (Phase 3, revisited and closed): the acceptance above was reconsidered - a deterministic fetch was designed, implemented, and fully investigated (see section 10 for the complete evidence chain). Stated plainly, without softening: **the deterministic `if`/`set` block and both `available when` guards (`process_refund` gated on `refund_approved == True`, `create_escalation_case` gated on `must_escalate == True`) remain in the shipped Agent Script and are correct as written** - `sf agent validate` accepts them, and their logic matches every row in the table above exactly. **But the block is unreachable in practice**, because the data it depends on (`order_id`, `within_window`, `line_total`, `item_returnable`, `return_reason`) is never populated: the deterministic `run @actions.check_return_window` statement meant to populate them does not execute at runtime, for this agent, in this org (section 10 has the full evidence). Every gate-test session observed asks a clarifying question instead of calling the fact-gathering action - the same outcome as the Phase 2 baseline, before any of Phase 3's work. **The gate has not been proven to work under real traffic**, and cannot be, until the underlying non-execution is resolved or worked around.

TODO: add rows as you build. If a row is hard to classify, that is the interesting part — write down why.

Note (Phase 2): ProcessRefund itself enforces none of the rows above — it is a plain executor that creates an Approved ReturnRequest__c for whatever amount it is given, with no cap, window or ownership check. That is deliberate: all three checks live only in the Phase 3 Agent Script gate, so Phase 5 can measure the agent's behavior with and without that gate in front of this action.

## 4. Grounding and retrieval design

TODO once Phase 4 is done or cut.

Cover: which documents are ingested, DLO to DMO mapping, chunking, what the retriever returns, and how citations are surfaced so the harness can verify them.

If grounding was cut, say so plainly here and describe the fallback. A documented cut is fine; a silent gap is not.

## 5. Actions

For each action: inputs, outputs, errors, and limits. All six are `@InvocableMethod` Apex classes in `force-app/main/default/classes/`, bulk-safe (each does a fixed number of SOQL/DML statements regardless of list size), and designed to never throw for bad input — a malformed Id or a missing record produces a result with `success`/`found = false` and a message, not an exception.

### GetOrderStatus
- Type: Apex (`GetOrderStatus.getOrderStatus`)
- Inputs: `orderNumber` (String, optional), `customerEmail` (String, optional). If both are given, order number takes precedence.
- Outputs: `found` (Boolean), `orderNumber`, `status`, `orderDate`, `deliveredDate`, `totalAmount`, `message`
- Failure modes: neither input given, or no matching order → `found = false` with an explanatory message. By email, returns only the single most recent order (by `OrderDate__c`) if the customer has more than one.
- Limits to respect: bulkification, action timeout

### CheckReturnWindow
- Type: Apex (`CheckReturnWindow.checkReturnWindow`)
- Inputs: `orderId` (String, optional), `orderNumber` (String, optional), `orderItemId` (String, optional, added Phase 3), `reason` (String, optional, added Phase 3). Order Id takes precedence over order number if both are given.
- Outputs: `found`, `orderId` (added Phase 3 - echoes the resolved order's Id, so `GetOrderItems` has something to chain from when the order was looked up by number, not Id), `isDelivered`, `insideWindow`, `daysSinceDelivery`, `windowDays` (read from `RefundPolicy__mdt.Default.ReturnWindowDays__c`), `orderItemId` (added Phase 3 - echoes the input back, but only once verified to belong to the matched order), `lineTotal` (added Phase 3), `isReturnable` (added Phase 3), `reason` (added Phase 3 - echoes the input back unchanged, unvalidated), `message`
- Failure modes: neither `orderId` nor `orderNumber` given, no matching order, or a malformed Id → `found = false`. Not yet delivered → `isDelivered = false`, `insideWindow` and `daysSinceDelivery` left blank. Missing `RefundPolicy__mdt.Default` record → `windowDays` and `insideWindow` left blank rather than guessing a default. `orderItemId` given but it doesn't exist, is malformed, or belongs to a *different* order than the one matched → `orderItemId`/`lineTotal`/`isReturnable` all left blank, never defaulted - a mismatched Id must never read as "returnable" (see `CheckReturnWindowTest.testItemBelongsToWrongOrder`).
- Fact-only: does not approve, deny, or process anything. The Phase 3 additions (`orderItemId`/`reason` echoes) exist purely so the Agent Script gate can capture LLM-supplied values into variables via `set @variables.x = @outputs.y` - there is no documented way to capture an action *input*'s value into a variable directly, only an output's.

### GetOrderItems
- Type: Apex (`GetOrderItems.getOrderItems`) — added Phase 3
- Inputs: `orderId` (String, required)
- Outputs: `found` (Boolean), `orderItemId` (list[String]), `productName` (list[String]), `lineTotal` (list[Decimal]), `isReturnable` (list[Boolean]) — all four lists parallel, one entry per line item — `message`
- Failure modes: blank/malformed `orderId`, or no matching order → `found = false`, all lists empty. Order found but has no line items → `found = true`, lists empty, message says so - not a failure.
- Purpose: lets the LLM resolve a product the customer named (e.g. "the Gadget") to a specific `OrderItem__c` Id, since neither `GetOrderStatus` nor `CheckReturnWindow` exposes item-level data. A separate action rather than folding into `GetOrderStatus`, so the Phase 5 action-sequence check can see this step distinctly.
- Chained automatically off `check_return_window` in the gate (see section 3) - the LLM does not need to call it directly in the common path, though it remains directly callable.

### ProcessRefund
- Type: Apex (`ProcessRefund.processRefund`)
- Inputs: `orderId` (String, required), `orderItemId` (String, optional — blank for a whole-order refund), `amount` (Decimal, required), `reason` (String, required — must be one of `ReturnRequest__c.Reason__c`'s restricted picklist values or the insert fails)
- Outputs: `success`, `returnRequestId`, `message`
- Creates a `ReturnRequest__c` with `Outcome__c = 'Approved'` unconditionally.
- Precondition: the Agent Script gate must have passed. This action must be unreachable otherwise - see the note in section 3.
- Failure modes: malformed `orderId`/`orderItemId`, or a DML-level rejection (e.g. an invalid `reason` value) → `success = false` with the platform error message, per request, without failing the whole batch.
- Phase 3 update: now wired into `ReturnsRefunds`, gated `available when @variables.refund_approved == True` - no longer unreachable from every subagent as it was through Phase 2 (section 2's "ProcessRefund is not wired to any subagent" is accordingly stale as of Phase 3; not updating section 2's prose here since only sections 3, 5 and 10 were in scope for this pass, but flagging it so it isn't silently wrong).

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
| `sf agent publish` from this CLI environment | Consistently times out (`ConnectTimeoutError` to raw IPs, not the org's normal API host) - a network egress restriction in this sandbox, not the org | Phase 2 and Phase 3 both - worked around by deploying `AiAuthoringBundle` metadata directly and committing/activating from the Builder UI instead |
| Committing a locally-edited Agent Script file, from Builder UI, does not reliably pick up an externally-deployed `AiAuthoringBundle` | Observed 2026-09-14: three separate Builder "Commit" actions (creating BotVersions v1, v2, v3 in sequence) all committed byte-identical pre-gate content, none reflecting a CLI deploy of the gate made beforehand | Phase 3 - cost a full round of "confirm the gate is live" → discover it isn't → redeploy → re-verify before the gate test could run at all. The Builder tab appears to hold its own draft state, decoupled from `sf project deploy start --metadata AiAuthoringBundle:...`; closing and reopening the agent in Builder (loading fresh from the deployed source) before committing is the working fix, not confirmed as documented platform behavior |
| Deleting a BotVersion in Builder also deletes its linked `AiAuthoringBundle` (and vice versa - the two are 1:1 by `<target>`) | Observed 2026-09-14: deleting `v2`/`v3` removed the `AgentGrade`/`AgentGrade_2` bundles along with them; the org auto-creates a numbered fallback bundle (e.g. `AgentGrade_1`) rather than leaving an already-published version with no editable source | Same Phase 3 incident. Also: redeploying `AiAuthoringBundle` metadata whose local `bundle-meta.xml` still declares a `<target>` pointing at a version that no longer exists (or is already claimed) fails with `duplicate value found: UniqueIndexFormula duplicates value on <name>` - remove the `<target>` element before redeploying an edited bundle; it gets written back by a publish/commit, not supplied by the deployer |
| `sf project retrieve start --output-dir <dot-prefixed-path>` | Silently returns success with zero files extracted to disk (verified on both a known-good `ApexClass` and an `AiAuthoringBundle` - not specific to either) | Phase 3, while trying to verify org state in a scratch directory. A plain (non-dot-prefixed) directory name works correctly |
| `run @actions.X` inside `reasoning.instructions` (the documented Fetch Data Before Reasoning pattern) | Accepted by `sf agent validate`, does not execute at runtime | Phase 3 - full writeup below |

Note (Phase 3, closed - `run` statements inside `reasoning.instructions` do not execute at runtime for this agent, in this org): the Agent Script documentation's [Fetch Data Before Reasoning](https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-patterns-fetch-data.html) pattern describes exactly the mechanism this project needed to close the turn-1 extraction gap - a `run @actions.X` statement placed in a subagent's `reasoning.instructions`, guarded by an emptiness check, executing deterministically before any LLM prompt is built. `sf agent validate authoring-bundle` accepts this syntax without error in every variant tried below. It does not execute at runtime.

Evidence chain, all against the live, org-verified `AgentGrade` `AgentforceServiceAgent` (each variant deployed to the org and confirmed byte-identical to the tested source before running):

1. **Guarded version** (`if @variables.order_id == "": run @actions.check_return_window with orderNumber = @system_variables.user_input ...`), run against the full 23-case Set A + Set B gate test: `order_id` never left its default `""` in any of the 23 sessions; `CheckReturnWindow` (the Apex class name) and `orderId` (its output field) never appear anywhere in any of the 23 traces.
2. **Guard reworded for `None` versus `""`** (`if @variables.order_id is None or @variables.order_id == "":`, per the documented recommendation in [Variables (Custom and Linked)](https://developer.salesforce.com/docs/ai/agentforce/guide/ascript-ref-variables.html) that a string variable's "not yet populated" check should test both), run against 3 probe cases (a clean auto-approve candidate, an over-cap case, a cancellation): identical result across all 3 - `order_id` stayed `""`.
3. **No guard at all** - the `run @actions.check_return_window` statement placed completely unconditionally as the first line of `reasoning.instructions`, run once against the auto-approve-candidate utterance: still `order_id` stayed `""`, still zero mentions of `CheckReturnWindow` or `orderId` in the trace.

27 sessions total across the three variants (23 + 3 + 1), zero invocations of `check_return_window` from the deterministic path in any of them. One additional, unexplained data point: a compiled internal variable observed in the traces (`AgentScriptInternal_condition_1`) evaluated `False` identically in every case regardless of which guard was in place or whether one existed at all - further evidence the failure isn't a conditional-logic bug in the guard itself.

**This is behavior observed in one org, on one agent type (`AgentforceServiceAgent`), on one Salesforce release, at one point in time - not a general claim about the Agent Script language or the Agentforce platform.** It may be a bug specific to this org or release, a documentation/implementation mismatch not yet fixed upstream, or a constraint specific to this `agent_type` that the documentation's general-purpose examples (written without specifying an agent type) don't surface. It has not been reported to Salesforce or checked against release notes. Full test-by-test evidence is in `eval-harness/results/baselines/phase3-gate.md`.
