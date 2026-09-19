# Backend schema — AgentGrade

Owner: Avnish
Status: draft
Last updated: 2026-09-19

---

## 1. Salesforce custom objects

ERD: `diagrams/erd.mmd`

Escalations use the standard `Case` object, not a custom object. Refund
policy is a Custom Metadata Type (`RefundPolicy__mdt`), not a custom object,
because it is configuration rather than data — see below.

### Order__c
A customer order. Parent of `OrderItem__c` (master-detail) and referenced by `ReturnRequest__c` (lookup).

| Field | Type | Notes |
| --- | --- | --- |
| Name | Auto number, format `ORD-{0000}` | Order number |
| Account__c | Lookup(Account) | Optional; not required |
| CustomerEmail__c | Email | |
| OrderDate__c | Date | Drives the return window calculation |
| DeliveredDate__c | Date | Set once the order ships and is delivered; blank for Pending/Shipped/Cancelled |
| TotalAmount__c | Currency(18,2) | Not a rollup — set explicitly (e.g. by `seed_data.apex`, later by Apex actions) |
| Status__c | Picklist, restricted | Pending (default), Shipped, Delivered, Cancelled |

### OrderItem__c
A line item on an Order__c. Sharing model `ControlledByParent` (inherits from Order__c).

| Field | Type | Notes |
| --- | --- | --- |
| Name | Text | Line item label |
| Order__c | Master-detail(Order__c) | Required; deleting the Order__c cascades to its items |
| ProductName__c | Text(120) | |
| Quantity__c | Number(3,0) | |
| UnitPrice__c | Currency(18,2) | |
| LineTotal__c | Formula, Currency(18,2) | `Quantity__c * UnitPrice__c`; blanks treated as zero |
| IsReturnable__c | Checkbox | Default `true`; items marked non-returnable are not eligible for a return regardless of reason (see `docs/return-policy.md`) |

### ReturnRequest__c
A customer request to return an order or line item. Outcome is decided by the Phase 3 deterministic gate.

| Field | Type | Notes |
| --- | --- | --- |
| Name | Text | |
| Order__c | Lookup(Order__c) | |
| OrderItem__c | Lookup(OrderItem__c) | |
| RequestedAmount__c | Currency(18,2) | Compared against `RefundPolicy__mdt.MaxAutoRefund__c` by the gate |
| Reason__c | Picklist, restricted | Damaged, Wrong item, Not as described, Changed mind |
| Outcome__c | Picklist, restricted | Pending (default), Approved, Blocked, Escalated |
| DecisionReason__c | Text(255) | Why the gate reached its outcome |
| EscalationCase__c | Lookup(Case) | Populated when Outcome__c = Escalated |

### RefundPolicy__mdt (Custom Metadata Type, not a custom object)
Configuration the deterministic gate reads, not transactional data. One record deployed: `RefundPolicy.Default`.

| Field | Type | Notes |
| --- | --- | --- |
| MaxAutoRefund__c | **Number(18,2)** | The auto-approve cap the gate enforces. Not Currency: Salesforce custom metadata fields do not support the Currency type (org-verified — deploy fails with `Type Currency ... is not supported for the Entity RefundPolicy__mdt`), so this is a plain Number despite the field name. Default record value: 500 |
| ReturnWindowDays__c | Number(3,0) | Default record value: 30 |
| AppliesToCategory__c | Text(255) | Unset on the Default record (blank = applies to all categories) |

TODO: adjust these as you build. Keep this table matching the org, or it becomes a lie.

## 2. Data 360 model

**Cut.** Phase 4 was never attempted — see `docs/TRD.md` section 4 and
`ROADMAP.md`'s own Phase 4.5 decision gate. No DLO, no DMO, no retriever
exist in this org. Both deployed bot versions ship
`citationsEnabled = false` (org-verified,
`force-app/main/default/bots/AgentGrade/v1.botVersion-meta.xml` and
`v2.botVersion-meta.xml`), so there is no platform-level path for a
citation to reach a response either. This table is left empty rather than
filled with a plan that was never built:

| Layer | Object | Source | Notes |
| --- | --- | --- | --- |
| DLO | — not built | — | Phase 4 cut before any ingestion started |
| DMO | — not built | — | Phase 4 cut before any ingestion started |
| Retriever | — not built | — | Phase 4 cut before any ingestion started |

No DLO-to-DMO-to-retriever flow to draw. If this project resumes Phase 4,
the fallback in `ROADMAP.md` 4.5 (Salesforce Knowledge plus an Apex
retrieval action) is the documented starting point, not this table.

## 3. External harness schema

**Test case CSV** — `eval-harness/testcases/testcases.csv`

| Column | Type | Meaning |
| --- | --- | --- |
| case_id | string | Stable identifier |
| utterance | string | What the user says |
| expected_subagent | string | Which subagent should handle it |
| expected_actions | string | Pipe separated, in order |
| must_be_grounded | bool | Whether the answer must carry a citation |
| is_adversarial | bool | Whether this case tries to defeat the gate |
| notes | string | Free text |

**Results JSON** — one object per case plus an aggregate block. Schema lives in `eval-harness/src/metrics.py`.

## 4. Data flow

The originally planned flow (seeded object -> Data 360 DLO -> DMO ->
retriever -> agent answer -> session trace -> harness metric -> dashboard)
is not what actually runs, because two of those eight hops don't exist in
this build: DLO/DMO/retriever were cut (section 2), and the session trace
hop is a confirmed platform failure (`docs/TRD.md` section 10, "No
selected dataspace for Einstein Audit"). The real flow, as built:

`seeded Order__c/OrderItem__c/RefundPolicy__mdt` -> `Apex action (GetOrderStatus,
CheckReturnWindow, GetOrderItems, ProcessRefund, CreateEscalationCase,
LogUnhandled)` -> `agent response text` -> `eval harness (Agent API only,
no trace)` -> `metrics.py (grounding scored from response text; routing/
action-sequence/claimed-but-not-performed reported as untestable, not
guessed)` -> `dashboard`.

Where this loses data, concretely: routing and action-sequence information
exists only inside the session trace, which never returns real data in
this org — that information is gone the moment the turn ends, not stale,
simply never captured. Guardrail effectiveness has a second, trace-free
path (`eval-harness/src/soql_guardrail_check.py` reads `ReturnRequest__c`/
`Case` directly), but it depends on those objects' `CreatedDate` to
isolate a run — a window that would silently include a different day's
records if two test runs happened on the same calendar day. The synthetic
seed data itself (section 5) is deterministic and re-seedable, so that
layer does not go stale between runs — re-running `scripts/seed_data.apex`
deletes and recreates it identically.

## 5. Sample data

Generated by `scripts/seed_data.apex` (`sf apex run -f scripts/seed_data.apex
-o agentgrade`), idempotent — it deletes every previously seeded `Order__c`
(identified by the reserved `@seed.agentgrade.test` email domain, which
cascades to its `OrderItem__c` children via master-detail) before
inserting fresh records, so re-running it does not accumulate duplicates.

**150 orders**, `Status__c` cycled evenly across Pending/Shipped/Delivered/
Cancelled, `OrderDate__c` spread pseudo-randomly across roughly the last
400 days. Deliberately not a real-world distribution (e.g. no seasonality,
no clustering) — the point of this data is exercising specific boundary
conditions the eval harness depends on, not simulating realistic order
volume.

**Deliberate edge cases, reserved by index so they always exist after a
reseed:**
- 6 cancelled orders (`DeliveredDate__c` null) — spec asked for at least 5
- Orders delivered exactly 28, 29, 31, and 35 days ago — the policy return
  window is 30 days, so this straddles the boundary on both sides
- Dedicated line items with `LineTotal__c` of exactly 450, 499, 501, and
  900 — the auto-approve cap is 500, so this straddles that boundary too.
  These four are always `IsReturnable__c = true`, so they test only the
  refund-amount boundary, not a second condition at the same time
- Roughly 10% of all other order items `IsReturnable__c = false`
  (`Math.mod((i*31)+(j*7), 10) != 0`), spread across orders and line
  positions rather than clustered, so a non-returnable item and a
  return-window edge case aren't accidentally correlated

**Line items:** 1 to 3 per order (deterministic pseudo-random count) for
every order outside the four reserved edge-case orders, 5 product names
cycled (Widget, Gadget, Gizmo, Doohickey, Thingamajig), quantity 1-4, unit
price 10-309. `Order__c.TotalAmount__c` is not a rollup field in this
schema (`docs/SCHEMA.md` section 1 notes why) — the script sums each
order's own line items and updates it explicitly as a second pass, after
insert.
