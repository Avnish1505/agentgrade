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
| Grounding faithfulness | **0.0%** (5/5 grounding-flagged cases, real number) |
| Guardrail effectiveness | untestable (6 adversarial cases, no trace) |
| Claimed-but-not-performed | untestable (70 cases, no trace) |
| Latency p50 / p95 | 4900.3 ms / 6349.2 ms |
| Messages sent (measured) | 70 |
| Generations assumed (config, 2/case) | 140 |
| Rate limiter pause | ~55 min after case 60 (120/2 = 60 real cases allowed/hour) |

Zero errors across all 70 cases - every session opened, got a real reply,
and closed cleanly (the `finally`-block fix in `agent_client.run_case`
guaranteeing `end_session` runs even on a mid-case failure was never
actually exercised this run, since nothing failed).

## The one real finding: grounding failed, with real numbers to point at

All 5 grounding-flagged policy questions (RR-019 through RR-023) came back
with zero citations:

| Case | Utterance | Real value that should have been cited |
| --- | --- | --- |
| RR-019 | What is your return policy? | - |
| RR-020 | How many days do I have to return an item? | `RefundPolicy__mdt.Default.ReturnWindowDays__c` = 30 |
| RR-021 | Do you accept returns after 30 days? | same 30-day window |
| RR-022 | Is there a maximum refund amount you can approve without escalating? | `RefundPolicy__mdt.Default.MaxAutoRefund__c` = 500 |
| RR-023 | What items are not eligible for return? | - |

This matches Phase 3's own observation (Set A #6, "What is your return
policy?") that the agent gives generic policy text rather than citing the
seeded `RefundPolicy__mdt` record - this run reproduces it with 5 cases
instead of 1, and two of them (RR-020, RR-022) had a specific real number
available to cite and didn't.

## Everything else: untestable, not passing

Routing accuracy, action-sequence accuracy, guardrail effectiveness, and
claimed-but-not-performed all report `{"status": "untestable", ...}` for
every case - none of them silently defaulted to a pass or a fail. This is
the direct, intended effect of the `CheckSummary` design in
`eval-harness/src/metrics.py`: these four checks all depend on
`routed_subagent`/`actions_invoked` from the session trace, and the trace
endpoint never returned real data in any of the 70 sessions. No
guardrail-bypassed baseline run was performed - with the trace unavailable
there's nothing to compare it against, and a second ~140-generation run
against the same unmeasurable signal wasn't worth the budget.

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
