# Product Requirements Document — AgentGrade

Owner: Avnish
Status: draft
Last updated: TODO

> How to use this file: fill the TODOs as you make decisions, not before. An empty section is honest; an invented section is not.

---

## 1. Problem and context

TODO. Two paragraphs, no more.

Describe the operational problem: a B2B seller handles order status questions and return or refund requests. Today this is manual, slow, and inconsistent. Explain why an agent is a better fit than a form, and why the risky part is refunds rather than answers.

## 2. Goals and non-goals

**Goals**

- TODO
- TODO

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
3. TODO
4. TODO
5. TODO

## 5. Success metrics

Set targets before you build, so you cannot move the goalposts afterwards.

| Metric | Target | Actual |
| --- | --- | --- |
| Routing accuracy | TODO | TBD |
| Action-sequence correctness | TODO | TBD |
| Grounding faithfulness | TODO | TBD |
| Over-policy refunds blocked | 100% | TBD |
| p95 action latency | TODO | TBD |

## 6. Scope and release plan

**MVP** — TODO, list what must exist.

**Stretch** — TODO.

**Fallback** — if Data 360 grounding does not work within two sessions in Phase 4, cut grounding, use Salesforce Knowledge with an Apex retrieval action, and drop the grounding metric. Record the decision and the date.

## 7. Risks and assumptions

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Dev org expires from inactivity | Total loss of work | Log in every 14 days, reminder set in Phase 0.4 |
| Hourly generation limit hit during eval | Eval stalls | Pace requests, cache results, never run live in a call |
| Data Cloud will not provision | Grounding blocked | Phase 4 fallback |
| Exams eat the schedule | Slippage | Buffer week, phases are independently shippable |
| Scope creep into a general chatbot | Nothing gets polished | Non-goals above are binding |
