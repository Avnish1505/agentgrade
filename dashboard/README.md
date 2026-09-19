# Dashboard

Reads `eval-harness/results/latest.json` and renders it.

Four sections, in this order:

1. Pass-rate cards for routing, action sequence, grounding, guardrail
2. Routing confusion matrix
3. Latency, p50 and p95
4. Failure drill-down, one row per failed case

Keep it plain. A senior reviewer is looking for whether the numbers exist and whether you understand them, not for animation.

Stack: Streamlit (`dashboard/app.py`), one file, reads `eval-harness/results/latest.json` and runs locally with `streamlit run dashboard/app.py`.

Screenshot: `docs/diagrams/dashboard-screenshot.png`, captured 2026-09-19 headless via Playwright/Chromium against a local Streamlit instance, so the repo shows the dashboard without anyone having to run it.

Data note: `latest.json` is not raw output from a fresh `run_eval.py` run — the actual per-case JSON from the real 70-case run is gitignored and was never committed, so it isn't recoverable from this repo. `latest.json` is a hand-assembled reconstruction from the committed baseline reports (`eval-harness/results/baselines/phase5-70case-suite.md` and `phase5-guardrail-soql-check.json`), carrying only the 5 grounding-flagged cases that were published individually; the other 65 real cases are accounted for in the aggregate summary but not listed per-case, and the file says so in its own `reconstruction_note` field rather than padding the case list with invented rows.
