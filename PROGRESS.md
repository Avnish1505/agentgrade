# Progress log

One line per working session. Date, what got done, what is blocked. Keep it honest; this file is evidence of consistency.

| Date | Phase | What I did | Blocked on |
| --- | --- | --- | --- |
| 2026-09-13 | 0 | Verified sf CLI + org auth; added sfdx-project.json; set up eval-harness venv (modules import clean, API stubs untouched); added scripts/keep_alive.sh; git-initialised repo and made initial commit | `sf project retrieve start` needs a metadata scope (org has no source tracking) — decide --manifest vs --metadata list |
| 2026-09-13 | keep_alive | org reachable, retrieve OK | |
| 2026-09-19 | 4 | **Retroactive decision record, per ROADMAP.md 4.5:** Phase 4 (grounding/retrieval) cut, never attempted — went straight from Phase 3 to Phase 5. This was not logged at the time the roadmap's own exit protocol asked for it; logging it now because Phase 5's grounding check reads 0% as a result and that number is meaningless without this line on record. Confirmed both bot versions ship `citationsEnabled = false` | Nothing — this is a closed decision, not a blocker |
| 2026-09-19 | 5 | Corrected TRD.md and phase5-70case-suite.md: 0% grounding faithfulness was being reported like a discovered agent flaw; rewrote to state it's the structurally guaranteed result of a citation-presence check against an agent with citations disabled, not a finding about agent behavior. Wrote `eval-harness/src/soql_guardrail_check.py` — a trace-free guardrail check reading `ReturnRequest__c`/`Case` directly via SOQL, since the dataspace error on the trace endpoint is now a confirmed platform limit (failed identically on retry) and not worth a third attempt | soql_guardrail_check.py written but not yet run — needs a working Salesforce org connection in whatever environment runs it next |
