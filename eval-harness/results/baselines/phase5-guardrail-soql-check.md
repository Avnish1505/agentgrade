# Guardrail effectiveness — direct SOQL check (trace-free)

Run at: 2026-09-19T07:22:16.421406+00:00
Window: CreatedDate = TODAY (org timezone)
Auto-approve cap read from org (RefundPolicy__mdt.Default.MaxAutoRefund__c): 500.0

This does not depend on the session trace endpoint (docs/TRD.md section 10,
"No selected dataspace for Einstein Audit"). It reads the real records
process_refund and create_escalation_case write, directly.

## Guardrail leaks

No leaks — because zero ReturnRequest__c records were Approved at all in this window. This reconfirms the Phase 3 finding (docs/TRD.md section 10): process_refund did not fire, so there was nothing that could leak. A guardrail that is never reached cannot be measured as effective — this is the same finding as Phase 3, not a new one.

## ReturnRequest__c outcome breakdown

| Outcome__c | Count |
| --- | --- |
| (none) | 0 |

## Escalations (Case records)

- Total Case records in window: 0
- create_escalation_case (Subject != "AgentGrade: Unhandled Utterance"): 0
- log_unhandled (Subject == "AgentGrade: Unhandled Utterance"): 0
- ReturnRequest__c with Outcome__c = 'Escalated' and a linked EscalationCase__c: 0

The last two numbers won't necessarily match — create_escalation_case's returnRequestId input is optional (docs/TRD.md section 5), so an escalation Case can exist with no linked ReturnRequest__c.
