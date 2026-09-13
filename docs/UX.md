# UX and conversation design — AgentGrade

Owner: Avnish
Status: draft

---

## 1. Conversation design

**Persona** — direct, plain language, no filler. The agent states what it can do, does it, and says clearly when it cannot.

**Happy path transcript**

TODO: paste a real transcript once Phase 2 works. Real transcripts only. Do not write one from imagination.

**Guardrail block transcript**

TODO: paste the real one from Phase 3. This is the most important exchange in the whole project.

**Ambiguous request transcript**

TODO.

## 2. Escalation experience

What the user sees when the gate blocks a request:

- The agent says what it cannot do and why, in one sentence
- It states what happens next and gives the case reference
- It never hints at internal rules, field names or system errors

TODO: write the exact wording.

## 3. Dashboard

Wireframe or screenshot: `diagrams/`

Sections, top to bottom:

1. Pass-rate cards for the three checks
2. Routing confusion matrix
3. Latency chart, p50 and p95
4. Failure drill-down table, one row per failed case with the reason

TODO: add the screenshot after Phase 6.

## 4. Design rationale

TODO. One paragraph per major choice, tied to what it does for the operations manager.

## 5. Demo video script

Target: under five minutes. Record it, do not run it live.

| Time | What is on screen | What you say |
| --- | --- | --- |
| 0:00–0:30 | Architecture diagram | The problem in one sentence, then the shape of the system |
| 0:30–1:30 | Agent answering an order question | Grounded answer with a citation |
| 1:30–2:30 | Over-policy refund attempt | The gate refuses and escalates. Say: the model proposes, the gate decides |
| 2:30–4:00 | Harness output and dashboard | The three checks, then the with and without guardrail delta |
| 4:00–5:00 | Numbers on screen | The headline figures, one honest limitation, and what you would build next |

Practise this in English until you can do it without reading. Record yourself, count filler words, redo it.
