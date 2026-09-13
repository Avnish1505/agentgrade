# Evaluation harness

Calls the agent through the Agent API, pulls the session trace, and scores three failure modes.

## Setup

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp config.example.yaml config.yaml   # then fill in your org details
```

`config.yaml` is gitignored. Never commit credentials.

## Run

```bash
python -m src.run_eval --cases testcases/testcases.csv --out results/latest.json
python -m src.run_eval --cases testcases/testcases.csv --no-guardrail --out results/no_guardrail.json
```

The second run is the comparison baseline. The difference between the two is the number worth quoting.

## Before you run anything

Three endpoint details must be verified against current Salesforce documentation and filled into `config.yaml` and `src/agent_client.py`:

1. The token endpoint and the External Client App client-credentials flow
2. The Agent API paths for starting a session and sending a message
3. The session trace endpoint and its response shape

These are marked `VERIFY` in the code. They are deliberately not guessed, because a wrong endpoint copied from memory wastes a day of debugging.

## Pacing

The Developer Edition caps LLM generations per hour. `rate_limiter.py` paces requests to stay under the configured budget and sleeps when the window is exhausted. Set `rate_limit.generations_per_hour` in `config.yaml` to the real limit for your org, and leave headroom.
