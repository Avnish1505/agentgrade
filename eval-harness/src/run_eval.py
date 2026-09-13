"""Runs the full test suite against the agent and writes results.

Usage:
    python -m src.run_eval --cases testcases/testcases.csv --out results/latest.json
    python -m src.run_eval --cases testcases/testcases.csv --no-guardrail --out results/no_guardrail.json

The second run is the baseline. The delta between the two is the number that
actually persuades someone.
"""

import argparse
import csv
import json
import os
from datetime import datetime, timezone

import yaml

from .agent_client import AgentClient
from .metrics import Aggregate, CaseResult, write_markdown_report
from .rate_limiter import RateLimiter


def load_config(path: str = "config.yaml") -> dict:
    if not os.path.exists(path):
        raise SystemExit(
            f"{path} not found. Copy config.example.yaml to config.yaml and fill it in."
        )
    with open(path, encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def load_cases(path: str) -> list[dict]:
    with open(path, encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))
    if not rows:
        raise SystemExit(f"No test cases found in {path}")
    return rows


def as_bool(value: str) -> bool:
    return str(value).strip().lower() in {"true", "1", "yes", "y"}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--cases", default="testcases/testcases.csv")
    parser.add_argument("--out", default="results/latest.json")
    parser.add_argument("--config", default="config.yaml")
    parser.add_argument(
        "--no-guardrail",
        action="store_true",
        help="Label this run as the guardrail-bypassed baseline. Bypassing is "
        "configured in the org, not here; this flag only labels the output.",
    )
    parser.add_argument("--limit", type=int, default=0, help="Run only the first N cases")
    args = parser.parse_args()

    cfg = load_config(args.config)
    cases = load_cases(args.cases)
    if args.limit:
        cases = cases[: args.limit]

    limiter = RateLimiter(
        cfg["rate_limit"]["generations_per_hour"],
        cfg["rate_limit"]["generations_per_case"],
    )
    client = AgentClient(cfg)
    client.authenticate()

    agg = Aggregate()
    label = "no guardrail" if args.no_guardrail else "with guardrail"
    print(f"Running {len(cases)} cases ({label})")

    for i, row in enumerate(cases, start=1):
        limiter.acquire()
        turn = client.run_case(row["case_id"], row["utterance"])
        expected_actions = [a for a in row["expected_actions"].split("|") if a]
        result = CaseResult(
            case_id=row["case_id"],
            utterance=row["utterance"],
            expected_subagent=row["expected_subagent"],
            actual_subagent=turn.routed_subagent,
            expected_actions=expected_actions,
            actual_actions=turn.actions_invoked,
            must_be_grounded=as_bool(row.get("must_be_grounded", "false")),
            is_adversarial=as_bool(row.get("is_adversarial", "false")),
            citations=turn.citations,
            latency_ms=turn.latency_ms,
            error=turn.error,
        )
        agg.results.append(result)
        mark = "." if result.routing_pass and result.action_sequence_pass else "F"
        print(f"  [{i}/{len(cases)}] {row['case_id']} {mark}")

    payload = {
        "run_label": label,
        "run_at": datetime.now(timezone.utc).isoformat(),
        "generations_consumed_estimate": limiter.consumed,
        "summary": agg.summary(),
        "cases": [r.to_dict() for r in agg.results],
    }

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2)

    report_path = args.out.replace(".json", ".md")
    write_markdown_report(agg, report_path, label)

    s = payload["summary"]
    print("\n--- summary ---")
    print(f"routing accuracy          {s['routing_accuracy']:.1%}")
    print(f"action sequence accuracy  {s['action_sequence_accuracy']:.1%}")
    print(f"grounding faithfulness    {s['grounding_faithfulness']:.1%}")
    print(f"guardrail effectiveness   {s['guardrail_effectiveness']:.1%}")
    print(f"latency p50 / p95         {s['latency_ms']['p50']} / {s['latency_ms']['p95']} ms")
    print(f"\nwrote {args.out} and {report_path}")


if __name__ == "__main__":
    main()
