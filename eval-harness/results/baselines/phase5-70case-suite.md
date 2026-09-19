# Phase 5 — 70-case suite run (with guardrail)

Date: 2026-09-19
Run label: "with guardrail" (no config change to bypass the gate)
Full raw output (gitignored, local only): `eval-harness/results/phase5-70case-with-guardrail.json` / `.md`

## Why this ran now

`eval-harness/results/baselines/phase5-reachability.md` documents that the
session trace (Einstein Audit / OTel) endpoint returned `400 "No selected
dataspace for Einstein Audit"` on first contact. Before running the full
suite, Setup > Einstein Audit, Analytics, and Monitoring Setup was checked
for Data Cloud / Agentforce Session Tracing configuration, and the trace
endpoint was re-tested on a fresh session. **Identical error, byte-for-byte,
on a new session id.** Not chased further (see `docs/TRD.md` section 10) -
the suite was run as currently built, with the known consequence that
trace-dependent checks would report as untestable.

## Summary

| Metric | Value |
| --- | --- |
| Cases | 70 (0 errored) |
| Trace available | 0 / 70 |
| Routing accuracy | untestable (70 cases, no trace) |
| Action sequence correctness | untestable (70 cases, no trace) |
| Grounding faithfulness | **0.0%** (5/5 grounding-flagged cases) — structural, not a finding; see note below |
| Guardrail effectiveness | untestable via trace (6 adversarial cases) — see the trace-free SOQL check instead |
| Claimed-but-not-performed | untestable (70 cases, no trace) |
| Latency p50 / p95 | 4900.3 ms / 6349.2 ms |
| Messages sent (measured) | 70 |
| Generations assumed (config, 2/case) | 140 |
| Rate limiter pause | ~55 min after case 60 (120/2 = 60 real cases allowed/hour) |

Zero errors across all 70 cases - every session opened, got a real reply,
and closed cleanly (the `finally`-block fix in `agent_client.run_case`
guaranteeing `end_session` runs even on a mid-case failure was never
actually exercised this run, since nothing failed).

## Grounding: 0%, and why that is not the finding it looks like

All 5 grounding-flagged policy questions (RR-019 through RR-023) came back
with zero citations:

| Case | Utterance | Real value that should have been cited |
| --- | --- | --- |
| RR-019 | What is your return policy? | - |
| RR-020 | How many days do I have to return an item? | `RefundPolicy__mdt.Default.ReturnWindowDays__c` = 30 |
| RR-021 | Do you accept returns after 30 days? | same 30-day window |
| RR-022 | Is there a maximum refund amount you can approve without escalating? | `RefundPolicy__mdt.Default.MaxAutoRefund__c` = 500 |
| RR-023 | What items are not eligible for return? | - |

**Read this before quoting the number.** Phase 4 (Data 360 ingestion, a
retriever, citations wired into the response) was never built - this
project went straight from Phase 3 to Phase 5 (`ROADMAP.md`'s own Phase 4.5
decision gate covers exactly this call). Both deployed bot versions have
`citationsEnabled = false` at the Salesforce platform-config level
(`force-app/main/default/bots/AgentGrade/v1.botVersion-meta.xml` and
`v2.botVersion-meta.xml`) - there is no code path in this org for a
citation to appear in a response, for any question, ever. A citation-presence
check run against that agent has exactly one possible result. 0% here is
the structurally guaranteed output of the check, not a discovered flaw in
the agent's behavior - see `docs/TRD.md` section 4 for the full writeup.

This is different from Phase 3's own observation (Set A #6, "What is your
return policy?") that the agent gives generic policy text instead of
citing the seeded `RefundPolicy__mdt` record. That Phase 3 note, and the
Phase 2 baseline note it built on, are about the agent stating a fact
without having called the action that would verify it - a real behavior
this run reproduces with 5 cases instead of 1, and it doesn't need Phase 4
or a retriever to be true or false: `GetOrderStatus` and `CheckReturnWindow`
already exist and are already wired. RR-020 and RR-022 did have a specific
real number available and the agent didn't ground either answer in it -
that finding stands on its own, independent of whether a citation was ever
possible.

## Everything else: untestable via trace, not passing

Routing accuracy, action-sequence accuracy, guardrail effectiveness, and
claimed-but-not-performed all report `{"status": "untestable", ...}` for
every case in `metrics.py`'s own scoring - none of them silently defaulted
to a pass or a fail. This is the direct, intended effect of the
`CheckSummary` design in `eval-harness/src/metrics.py`: these four checks
all depend on `routed_subagent`/`actions_invoked` from the session trace,
and the trace endpoint never returned real data in any of the 70 sessions.
No guardrail-bypassed baseline run was performed - with the trace
unavailable there's nothing to compare it against, and a second
~140-generation run against the same unmeasurable signal wasn't worth the
budget.

Guardrail effectiveness is the one exception with a real answer available
anyway: `process_refund` and `create_escalation_case` both write durable
Salesforce records regardless of the trace, so
`eval-harness/src/soql_guardrail_check.py` checks the org directly for the
same thing the trace would have shown - any `ReturnRequest__c` with
`Outcome__c = 'Approved'` above the configured cap is a leak, full stop.
**Status: script written, not yet run against this org** (blocked on
Salesforce API access in the environment that was building it) - its
output will land at
`eval-harness/results/baselines/phase5-guardrail-soql-check.md` once it
runs; that file does not exist yet as of this writeup. Routing,
action-sequence, and claimed-but-not-performed have no equivalent
trace-free path - they need to know which subagent handled a turn and
which actions it called, and nothing outside the trace records that.

## A side finding: the configured generations-per-case looks like an overestimate

`messages_sent_measured` (the harness's own real count of successful
`send_message` calls) was exactly 70 for 70 cases - 1 per case, as designed.
The rate limiter's pacing, however, is driven by `config.yaml`'s configured
`generations_per_case: 2`, which is what forced the ~55-minute pause after
case 60 (120 budget / 2 assumed = 60 real cases/hour). If Salesforce's real
per-turn cost is actually 1, not 2, the configured value is roughly double
what's needed - but there is no API response field or org
`TenantUsageEntitlement` row that exposes the real number to confirm this
(both checked directly; see `eval-harness/src/agent_client.py`
`AgentClient.__init__`). Worth checking against Setup's own usage page
around a future run rather than assuming either number.
