# AgentGrade

An Agentforce agent for B2B order and returns operations, with a deterministic guardrail layer in Agent Script and an external Python evaluation harness that scores routing, action-sequence and grounding failures.

**Status:** Phase 0 (setup). See `ROADMAP.md`.

---

## The idea in one line

The LLM proposes, a deterministic gate decides, and an external harness measures how often either one gets it wrong.

## Why this exists

Agent demos pass by hand and drift in production. AgentGrade pairs a narrow, real agent with a harness that scores three failure modes on every build:

1. **Routing** — did the request reach the right subagent?
2. **Action sequence** — did the agent invoke the right actions, in the right order?
3. **Grounding** — is every factual claim backed by a retrieved chunk?

## Headline numbers

Filled in after Phase 5. Do not write anything here until the harness produces it.

| Metric | With guardrail | Without guardrail |
| --- | --- | --- |
| Routing accuracy | TBD | TBD |
| Action-sequence correctness | TBD | TBD |
| Grounding faithfulness | TBD | TBD |
| Over-policy refunds blocked | TBD | TBD |
| p95 action latency | TBD | TBD |

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
