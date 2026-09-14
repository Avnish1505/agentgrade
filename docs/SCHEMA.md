# Backend schema — AgentGrade

Owner: Avnish
Status: draft

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

Only if Phase 4 survives.

| Layer | Object | Source | Notes |
| --- | --- | --- | --- |
| DLO | TODO | Return policy document | Raw ingested |
| DMO | TODO | Mapped from DLO | TODO |
| Retriever | TODO | Over the DMO | Chunking config, fields returned |

TODO: draw the DLO to DMO to retriever flow.

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

Record moves: seeded object -> Data 360 DLO -> DMO -> retriever -> agent answer -> session trace -> harness metric -> dashboard.

TODO: one paragraph describing where data can go stale or get lost.

## 5. Sample data

TODO: how the synthetic records were generated, how many, and why the distribution is realistic. Note deliberately included edge cases: orders just inside and just outside the return window, refunds just under and just over the cap.
