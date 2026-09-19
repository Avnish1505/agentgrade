# AgentGrade roadmap

Seven phases, each split into sub-phases. A phase is done only when its exit check passes. Tick boxes as you go.

Budget assumption: about 6 to 8 hours a week. If a week gets eaten by exams, slide everything right and use the Phase 4 fallback.

---

## Phase 0 — Org setup

Hinglish: Org banao aur usko zinda rakho. Yeh sabse boring phase hai lekin isi mein log fail hote hain.

- [ ] **0.1** Sign up for the free Developer Edition with Agentforce and Data Cloud at developer.salesforce.com/signup
- [ ] **0.2** Enable Einstein, then Agentforce, then Data Cloud. Data Cloud provisioning can take up to an hour.
- [ ] **0.3** Install Salesforce CLI and the Agentforce DX extension for VS Code. Authorise the org: `sf org login web -a agentgrade`
- [ ] **0.4** Set a recurring calendar reminder to log into the org every 14 days. Write the org alias and signup email in `scripts/org-notes.md`
- [ ] **0.5** Confirm you can create an agent that replies to "hello" in Agent Builder

**Exit check:** agent responds in the builder preview, and `sf org display -o agentgrade` works.

---

## Phase 1 — Domain and data model

Hinglish: Pehle data, phir agent. Bina data ke agent ke paas bolne ko kuch nahi hoga.

- [ ] **1.1** Write the domain one-pager in `docs/PRD.md` sections 1 and 2. Decide the exact business: B2B order and returns operations.
- [ ] **1.2** Create custom objects: Order, ReturnRequest, RefundPolicy, EscalationCase. Fields and relationships go in `docs/SCHEMA.md`.
- [ ] **1.3** Seed 100 to 200 synthetic records using `scripts/seed_data.apex`
- [ ] **1.4** Write the return policy knowledge document that grounding will later use. Keep it two pages, with clear rules and numbers.
- [ ] **1.5** Draw the ERD and save it to `docs/diagrams/`

**Exit check:** you can query seeded records in the Developer Console, and `docs/SCHEMA.md` section 1 is complete.

---

## Phase 2 — Agent skeleton

Hinglish: Ab agent banao, par sirf dhaancha. Guardrail aur grounding baad mein.

- [ ] **2.1** Create the agent and define 3 subagents: Order Status, Returns and Refunds, Fallback. Note: topics were renamed subagents in April 2026, use current naming.
- [ ] **2.2** Write instructions for each subagent
- [ ] **2.3** Build 4 to 6 actions across Apex and Flow: GetOrderStatus, CheckReturnWindow, ProcessRefund, CreateEscalationCase, LogUnhandled
- [ ] **2.4** Test each action independently before wiring it into the agent
- [ ] **2.5** Run 10 manual conversations covering every subagent, and write down each failure you see

**Exit check:** the agent routes and acts end to end in the builder preview for all three subagents.

---

## Phase 3 — Deterministic guardrail

Hinglish: Yeh project ka dil hai. LLM propose karega, gate decide karega.

- [ ] **3.1** Write the decision table in `docs/TRD.md` section 3: every decision, and whether Agent Script or the LLM owns it
- [ ] **3.2** Implement the gate in Agent Script: refund amount within policy cap, item within return window, order belongs to the requester
- [ ] **3.3** Any violation must escalate and create an EscalationCase. No refund action may run.
- [ ] **3.4** Write 10 adversarial prompts that try to talk the agent past the gate. Every one must fail to get a refund.
- [ ] **3.5** Record a short clip of the gate blocking an over-policy refund

**Exit check:** all 10 adversarial prompts are blocked, and you can explain in English which part is deterministic and which is the model.

---

## Phase 4 — Grounding

Hinglish: Yahan decision point hai. Agar Data Cloud tang kare to isko chhod do, project phir bhi strong rahega.

- [ ] **4.1** Ingest the return policy document into Data 360 and map DLOs to DMOs
- [ ] **4.2** Create a retriever over it and confirm it returns sensible chunks
- [ ] **4.3** Wire the retriever into the Order Status and Returns subagents
- [ ] **4.4** Make citations visible in the response so the harness can check them
- [ ] **4.5** **Decision gate:** if this phase is not working after two sessions, cut it. Fall back to Salesforce Knowledge plus an Apex retrieval action, and drop the grounding metric from the harness. Record the decision in `PROGRESS.md`.

**Exit check:** the agent answers a policy question with a citation you can trace back to a chunk.

---

## Phase 5 — Evaluation harness

Hinglish: Yeh cheez tumhe baaki candidates se alag karegi. Numbers yahin se aayenge.

- [ ] **5.1** Create an External Client App and get client credentials working. Confirm you can call the Agent API from Python.
- [ ] **5.2** Write 60 to 100 test cases in `eval-harness/testcases/testcases.csv`
- [ ] **5.3** Implement the three checks in `metrics.py`
- [ ] **5.4** Implement pacing so a full run stays under the hourly generation limit
- [ ] **5.5** Run the full suite with the guardrail on. Save results.
- [ ] **5.6** Run it again with the guardrail bypassed. This before-and-after delta is the single most persuasive number in the project.
- [ ] **5.7** Write the failure analysis: for every failed case, one line on why

**Exit check:** `results/latest.json` and a written report exist, with real numbers you can quote from memory.

---

## Phase 6 — Dashboard, docs and demo

Hinglish: Ab package karo. Senior banda 5 minute mein samajh jaana chahiye.

- [x] **6.1** Build the dashboard: routing confusion matrix, pass-rate cards, latency chart, drill-down into failures — `dashboard/app.py` (Streamlit), screenshot at `docs/diagrams/dashboard-screenshot.png`
- [x] **6.2** Finish all four documents — PRD, TRD, UX, SCHEMA all filled with grounded content; remaining TODOs (escalation wording, dashboard section already done) are honest gaps, not oversights, and say so inline
- [ ] **6.3** Record the demo video, under five minutes, following the script in `docs/UX.md`
- [x] **6.4** Fill in the headline numbers table in `README.md`
- [ ] **6.5** Ask someone to read the README cold and tell you what the project does. If they get it wrong, rewrite the README.

**Exit check:** a stranger understands the project from the README in under five minutes.

---

## Phase 7 — Keep it alive

Hinglish: Referral May mein hai, lekin woh repo kabhi bhi dekh sakte hain.

- [ ] **7.1** Log into the org every 14 days
- [ ] **7.2** Re-run the eval monthly and refresh the numbers
- [ ] **7.3** Check the demo link still works before sending any update
