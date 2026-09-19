# AgentGrade

An Agentforce agent for B2B order and returns operations, with a deterministic guardrail layer in Agent Script and an external Python evaluation harness that scores routing, action-sequence and grounding failures.

**Status:** Phase 5 closed. Phase 6 docs and dashboard done; demo video and the cold-read README check are still open. See `ROADMAP.md` and `PROGRESS.md`.

---

## The idea in one line

The LLM proposes, a deterministic gate decides, and an external harness measures how often either one gets it wrong.

## Why this exists

Agent demos pass by hand and drift in production. AgentGrade pairs a narrow, real agent with a harness that scores three failure modes on every build:

1. **Routing** — did the request reach the right subagent?
2. **Action sequence** — did the agent invoke the right actions, in the right order?
3. **Grounding** — is every factual claim backed by a retrieved chunk?

## Headline numbers

These are the real, run-once numbers from the 70-case Phase 5 suite
(`eval-harness/results/baselines/phase5-70case-suite.md`) plus the
trace-free SOQL guardrail check
(`eval-harness/results/baselines/phase5-guardrail-soql-check.md`), both run
2026-09-19. No guardrail-bypassed baseline was run (see the suite writeup
for why), so the "without guardrail" column is genuinely blank, not
omitted.

| Metric | With guardrail | Without guardrail |
| --- | --- | --- |
| Routing accuracy | untestable — trace endpoint never returned data (0/70 sessions) | not run |
| Action-sequence correctness | untestable — same trace failure | not run |
| Grounding faithfulness | 0.0% — structural, not a finding: Phase 4 was cut, citations disabled at the platform level (`docs/TRD.md` section 4) | not run |
| Over-policy refunds blocked | 0 leaks confirmed via direct SOQL, but because `process_refund` never fired at all in this run (0 `ReturnRequest__c` created) — "never exercised," not "held" | not run |
| p95 action latency | 6349.2 ms (p50: 4900.3 ms) — full per-case round trip (session open through session close), not isolated model-generation time; see `docs/TRD.md` section 8 | not run |

The one finding that actually says something about the agent, independent
of any of the above: across 93 total test sessions (23 Phase 3 + 70 Phase 5),
`check_return_window` was invoked zero times through the deterministic
path. The Agent Script gate is correct as written and validates clean, but
is unreachable at runtime in this org — see `docs/TRD.md` section 10 for
the full evidence chain. Everything above follows from that one root
cause.

A Streamlit dashboard renders these same numbers (`dashboard/app.py`,
screenshot at `docs/diagrams/dashboard-screenshot.png`) — the untestable
checks show as "Untestable," not a fake pass rate, matching this table.

## Repo map

| Path | What's in it |
| --- | --- |
| `ROADMAP.md` | Phases and sub-phases with checkboxes |
| `PROGRESS.md` | Running log, one line per session |
| `docs/` | PRD, TRD, UX doc, schema doc, diagrams |
| `force-app/` | Salesforce metadata (objects, Apex, Flows, agent config) |
| `agent-script/` | Agent Script files, including the deterministic gate |
| `eval-harness/` | Python harness that calls the Agent API and scores results |
| `dashboard/` | Metrics dashboard |
| `scripts/` | Org setup, data seeding, keep-alive |

## Demo

Video link goes here after Phase 6. Keep it under five minutes.
