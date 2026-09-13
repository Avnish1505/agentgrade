# Dashboard

Reads `eval-harness/results/latest.json` and renders it.

Four sections, in this order:

1. Pass-rate cards for routing, action sequence, grounding, guardrail
2. Routing confusion matrix
3. Latency, p50 and p95
4. Failure drill-down, one row per failed case

Keep it plain. A senior reviewer is looking for whether the numbers exist and whether you understand them, not for animation.

Suggested stack: Streamlit, because it is one file and runs locally. Anything that renders JSON is fine.

TODO: add a screenshot to `docs/diagrams/` once built, so the repo shows the dashboard without anyone having to run it.
