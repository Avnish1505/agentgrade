# Salesforce metadata

Populated by retrieving from the org, not by hand:

```bash
sf project retrieve start -o agentgrade
```

Expected contents once Phases 1 to 4 are done:

- `objects/` — Order, ReturnRequest, RefundPolicy, EscalationCase
- `classes/` — the Apex actions and their tests
- `flows/` — Flow based actions
- `genAiPlanners/` — agent configuration

Retrieve and commit after every working session. This is your backup if the org lapses.
