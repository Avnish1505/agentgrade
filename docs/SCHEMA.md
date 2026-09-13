# Backend schema — AgentGrade

Owner: Avnish
Status: draft

---

## 1. Salesforce custom objects

ERD: `diagrams/erd.mmd`

### Order__c
| Field | Type | Notes |
| --- | --- | --- |
| Name | Auto number | Order number |
| Account__c | Lookup | TODO |
| OrderDate__c | Date | Drives the return window calculation |
| TotalAmount__c | Currency | TODO |
| Status__c | Picklist | TODO: list the values |

### ReturnRequest__c
| Field | Type | Notes |
| --- | --- | --- |
| Order__c | Master-detail | TODO |
| RequestedAmount__c | Currency | Compared against the policy cap by the gate |
| Reason__c | Picklist | TODO |
| Outcome__c | Picklist | Approved, Blocked, Escalated |

### RefundPolicy__c
| Field | Type | Notes |
| --- | --- | --- |
| MaxAutoRefund__c | Currency | The cap the gate enforces |
| ReturnWindowDays__c | Number | TODO |
| AppliesTo__c | Picklist | TODO |

### EscalationCase__c
| Field | Type | Notes |
| --- | --- | --- |
| ReturnRequest__c | Lookup | TODO |
| Reason__c | Text | Why the gate blocked it |
| ContextSummary__c | Long text | Written by the model |

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
