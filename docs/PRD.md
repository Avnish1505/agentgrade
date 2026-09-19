# Product Requirements Document — AgentGrade

Owner: Avnish
Status: draft
Last updated: 2026-09-19

> How to use this file: fill the TODOs as you make decisions, not before. An empty section is honest; an invented section is not.

---

## 1. Problem and context

A B2B seller's order-status and returns questions today go through the same slow path: a customer emails or calls, someone looks up the order in the system of record, and someone else decides whether a return qualifies for an automatic refund or needs a manager's judgment call. None of that is hard, but all of it is manual, and manual means slow, inconsistent between reps, and hard to audit after the fact — two reps applying the same 30-day window and $500 cap can reach different answers depending on how carefully they read the policy that day.

A static form doesn't fix this: a form can collect an order number, but it can't answer "where is my order" conversationally, can't tell a customer why their return doesn't qualify in the way the policy actually explains it, and can't distinguish a routine damaged-item return from someone testing whether the wording of their message can talk the system into an refund it shouldn't grant. An agent that reads intent handles the first two; a deterministic gate behind it, not the agent's own judgment, has to handle the third — answering a question is low-risk and forgiving of an imperfect response, but approving a refund is a real financial transaction, so the two need different owners for their decisions (`docs/TRD.md` section 3 is the design that follows from this).

## 2. Goals and non-goals

**Goals**

- Keep every refund-approval decision (amount vs. cap, return window, returnable flag) deterministic and owned by code, not by the model's judgment — the LLM proposes, a gate decides (`docs/TRD.md` section 3)
- Measure the agent's actual failure modes objectively, with an external harness against the real Agent API, rather than trusting a rehearsed Builder-preview demo (`eval-harness/`)
- Where a metric can't honestly be measured (trace unavailable, grounding never built), say so plainly rather than report a number that looks real and isn't (`docs/TRD.md` sections 4 and 10)

**Non-goals** — state these plainly, they protect your scope.

- Not a general purpose chatbot
- Not multi-industry
- Not a replacement for a human in refund disputes
- No voice, no paid add-ons

## 3. Users and personas

| Persona | What they want | How they interact |
| --- | --- | --- |
| Customer or account contact | A fast, correct answer about an order or return | Chat with the agent |
| Operations manager | Confidence the agent is not making costly mistakes | Reads the eval dashboard |
| Support agent | Clean escalations with context already gathered | Picks up escalated cases |

## 4. Use cases

Write 5 to 8. Two are filled in as examples; the rest are yours.

1. A customer asks where their order is. The agent looks it up and answers with the current status.
2. A customer requests a refund above the policy cap. The agent refuses, explains the policy, and escalates with a case containing the full context.
3. A customer asks a return-policy question without naming an order ("how many days do I have to return something?"). ReturnsRefunds answers the policy question directly rather than demanding an order number first (`docs/TRD.md` section 2's subagent table).
4. A customer's message isn't about an order, a return, or a refund at all ("do you sell gift cards?"). Fallback logs it for human review and says so, rather than guessing at an answer (`LogUnhandled`).
5. A customer tries to talk the agent past the policy — explicitly asking it to ignore the return window, or to mislabel a return reason so it auto-approves. This is the adversarial case the deterministic gate exists for; real attempts of this shape were tested in Phase 3 (`eval-harness/results/baselines/phase3-gate.md`, Set B #10-11) and were intercepted before reaching the subagent at all, by a platform-level classifier rather than this project's own gate — see `docs/TRD.md` section 10 for why the gate itself was never actually exercised.

## 5. Success metrics

Set targets before you build, so you cannot move the goalposts afterwards.

**This section is being filled after Phase 5, with the actuals already known — the Target column below was not set in advance, which is exactly what this section's own instruction exists to prevent.** Writing in a target now that happens to look reasonable next to the actual would be moving the goalposts under a different name. Recorded honestly instead: no pre-build targets exist for this run. If this project continues past this portfolio deadline, targets for the next milestone should be written at the start of that phase, before the next harness run, not after.

| Metric | Target (set in advance) | Actual |
| --- | --- | --- |
| Routing accuracy | not set before building — see note above | untestable, 0/93 sessions had trace data |
| Action-sequence correctness | not set before building | untestable, same reason |
| Grounding faithfulness | not set before building | 0.0% — structural (Phase 4 cut), not a measured behavior; see `docs/TRD.md` section 4 |
| Over-policy refunds blocked | 100% (this one target predates the build — see `docs/PRD.md` section 6 fallback note) | 0 leaks confirmed via direct SOQL, but because the refund action never fired at all — "never exercised," not "held" (`eval-harness/results/baselines/phase5-guardrail-soql-check.md`) |
| p95 action latency | not set before building | 6349.2 ms (p50: 4900.3 ms), real, measured |

## 6. Scope and release plan

**MVP (what actually shipped)** — three subagents (OrderStatus, ReturnsRefunds, Fallback) over five Apex actions; the deterministic decision table in `docs/TRD.md` section 3 implemented in Agent Script (correct as written, unreachable at runtime — section 10); an external Python harness calling the real Agent API against 93 total test cases across two runs; a trace-free guardrail check reading Salesforce records directly, since the session trace endpoint never worked in this org.

**Stretch (not built, and why)** — Data 360 grounding with real citations (Phase 4, cut per the 4.5 decision gate before two sessions were spent on it, `docs/TRD.md` section 4); authenticated-session ownership verification for the "requester owns the order" row, deliberately out of scope for a dev-preview environment with no real authenticated customer (`docs/TRD.md` section 3's Phase 3 scope note); resolving why `run @actions.X` inside `reasoning.instructions` doesn't execute at runtime in this org, which is the root cause blocking almost every other untestable metric in this project (`docs/TRD.md` section 10) — fixing this, not adding new features, is the highest-value next step if this project continues.

**Fallback** — if Data 360 grounding does not work within two sessions in Phase 4, cut grounding, use Salesforce Knowledge with an Apex retrieval action, and drop the grounding metric. Record the decision and the date.

## 7. Risks and assumptions

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Dev org expires from inactivity | Total loss of work | Log in every 14 days, reminder set in Phase 0.4 |
| Hourly generation limit hit during eval | Eval stalls | Pace requests, cache results, never run live in a call |
| Data Cloud will not provision | Grounding blocked | Phase 4 fallback |
| Exams eat the schedule | Slippage | Buffer week, phases are independently shippable |
| Scope creep into a general chatbot | Nothing gets polished | Non-goals above are binding |

**Materialized, as of 2026-09-19:** the Data Cloud row above, though not in the way anticipated — Phase 4 was never attempted at all rather than attempted-and-blocked (`docs/TRD.md` section 4), and separately, an unlisted risk hit hard: the session trace endpoint (Data Cloud dataspace, a different Data Cloud dependency than grounding) also failed, blocking four of five harness metrics (`docs/TRD.md` section 10). Worth adding to this table if this project's risk register gets revisited: "session trace / Einstein Audit dataspace unavailable" was not anticipated here and should have been.
