# Salesforce metadata

Populated by retrieving from the org, not by hand.

This org has no source tracking, so the plain `sf project retrieve start`
never works here — it errors with `noSourceTracking` and asks you to scope
the retrieve yourself. Use the standing manifest instead:

```bash
sf project retrieve start --manifest manifest/agentgrade-retrieve.xml --target-org agentgrade
```

The manifest (`manifest/agentgrade-retrieve.xml`) covers ApexClass, Flow,
CustomObject, and every agent/bot/generative-AI metadata type this org
reported having (via `sf org list metadata-types`) as of Phase 0: Bot,
BotBlock, BotTemplate, GenAiFunction, GenAiPlannerBundle, GenAiPlugin,
GenAiPromptTemplate, GenAiPromptTemplateActv, AiAgentScorerDefinition,
AiAuthoringBundle, AiEvaluationDefinition, AiTestingDefinition,
AiResponseFormat, AiSurface, AIApplication, AIApplicationConfig,
ExternalAIModel, ServiceAISetupDefinition, ServiceAISetupField. If new
metadata types get added later (e.g. once Phase 1 work introduces new
components), regenerate the manifest with
`sf project generate manifest --metadata <types> --name agentgrade-retrieve --output-dir manifest`.

`scripts/keep_alive.sh` runs this retrieve automatically after its org
display check.

Expected contents once Phases 1 to 4 are done:

- `objects/` — Order, ReturnRequest, RefundPolicy, EscalationCase
- `classes/` — the Apex actions and their tests
- `flows/` — Flow based actions
- `genAiPlannerBundles/`, `aiAuthoringBundles/`, `bots/` — agent configuration (this org's agents are `AiAuthoringBundle` — a `.agent` Agent Script file plus `.bundle-meta.xml` — not the older `GenAiPlannerBundle`/`GenAiPlugin` shape; `genAiPlannerBundles/` here is the default Employee Copilot only)

Retrieve and commit after every working session. This is your backup if the org lapses.
