# Org notes

Keep this current. Losing the org is the most common way this project dies.

| Item | Value |
| --- | --- |
| Signup email | TODO |
| Username | avnishsingh150606.dd5d597b1b4f@agentforce.com |
| My Domain URL | https://orgfarm-a5685c6333-dev-ed.develop.my.salesforce.com |
| CLI alias | agentgrade |
| Created on | TODO |
| Last login | 2026-09-13 (verified via `sf org display`, Phase 0 setup) |

## Keep alive

Log into the org at least every 14 days. Developer orgs are removed after a period of inactivity, and community reports suggest the Agentforce and Data Cloud orgs lapse considerably sooner than a standard Developer Edition. Do not rely on remembering; set a recurring reminder.

Quick check from the terminal:

```bash
sf org display -o agentgrade
```

## Export before any long break

Before exam weeks, retrieve metadata so the work survives even if the org does not:

```bash
sf project retrieve start -o agentgrade
```

Commit what comes back.
