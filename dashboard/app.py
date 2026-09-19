"""AgentGrade dashboard — reads eval-harness/results/latest.json and renders
it. See dashboard/README.md for the section order this follows.

Honesty rule this file exists to enforce: an untestable check is rendered as
"untestable" with its own visual treatment, never silently folded into a
pass/fail percentage. A 0% or 100% on this dashboard always means a real
measured rate, not a stand-in for "no data."

Run: streamlit run dashboard/app.py
"""

import json
from pathlib import Path

import pandas as pd
import streamlit as st

RESULTS_PATH = Path(__file__).resolve().parent.parent / "eval-harness" / "results" / "latest.json"

st.set_page_config(page_title="AgentGrade — Eval Dashboard", layout="wide")


@st.cache_data
def load_results(path: Path) -> dict:
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def fmt_check(check: dict) -> str:
    """Render a trace-dependent CheckSummary dict honestly."""
    if check["status"] == "untestable":
        return f"Untestable — {check['untestable_cases']} cases, no trace"
    pct = f"{check['rate']:.1%}" if check["rate"] is not None else "n/a"
    extra = f" ({check['untestable_cases']} untestable)" if check["untestable_cases"] else ""
    return f"{pct}{extra}"


def render_metric_card(col, label: str, value_str: str, is_untestable: bool, caption: str = ""):
    with col:
        st.metric(label, value_str)
        if is_untestable:
            st.caption(f"⚠️ {caption}" if caption else "⚠️ Not measured this run")
        elif caption:
            st.caption(caption)


if not RESULTS_PATH.exists():
    st.error(f"No results file at {RESULTS_PATH}. Run the eval harness first, or see the repo's committed `latest.json`.")
    st.stop()

data = load_results(RESULTS_PATH)
summary = data["summary"]

st.title("AgentGrade — Eval Dashboard")
st.caption(data.get("label", ""))
if data.get("generated_note"):
    with st.expander("How this dashboard's data was assembled (read this before trusting a number)"):
        st.write(data["generated_note"])
        if data.get("reconstruction_note"):
            st.write(data["reconstruction_note"])

st.divider()

# --- Section 1: pass-rate cards -------------------------------------------
st.header("1. Pass-rate cards")

routing = summary["routing_accuracy"]
action_seq = summary["action_sequence_accuracy"]
grounding_rate = summary["grounding_faithfulness"]
guardrail = summary["guardrail_effectiveness"]

c1, c2, c3, c4 = st.columns(4)
render_metric_card(
    c1, "Routing accuracy", fmt_check(routing), routing["status"] == "untestable",
    "Session trace endpoint never returned data (0/70 sessions)."
)
render_metric_card(
    c2, "Action-sequence correctness", fmt_check(action_seq), action_seq["status"] == "untestable",
    "Same trace failure as routing."
)
render_metric_card(
    c3, "Grounding faithfulness", f"{grounding_rate:.1%}", False,
    "Structural, not a discovered flaw — Phase 4 (citations) was cut before it was built. See docs/TRD.md §4."
)
render_metric_card(
    c4, "Guardrail effectiveness (trace)", fmt_check(guardrail), guardrail["status"] == "untestable",
    "See the trace-free SOQL check below for the real answer to this question."
)

soql = data.get("guardrail_soql_check")
if soql:
    st.subheader("Guardrail effectiveness — trace-free SOQL check (the real answer)")
    sc1, sc2, sc3 = st.columns(3)
    sc1.metric("Leaks (Approved above cap)", len(soql["leaks"]))
    sc2.metric("ReturnRequest__c records this run", soql["total_cases"])
    sc3.metric("Refund cap enforced", f"${soql['cap']:.0f}")
    st.caption(soql["interpretation"])

st.divider()

# --- Section 2: routing confusion matrix -----------------------------------
st.header("2. Routing confusion matrix")

confusion = summary.get("routing_confusion") or {}
if not confusion:
    st.warning(
        f"No confusion matrix to draw. Trace was available for "
        f"{summary['trace_availability']['available']}/{summary['cases_total']} sessions "
        f"— confusion is only computable where a trace confirms the actual routed subagent."
    )
else:
    rows = sorted(confusion.keys())
    cols = sorted({actual for row in confusion.values() for actual in row})
    df = pd.DataFrame(0, index=rows, columns=cols)
    for expected, actuals in confusion.items():
        for actual, count in actuals.items():
            df.loc[expected, actual] = count
    st.dataframe(df, use_container_width=True)

st.divider()

# --- Section 3: latency -----------------------------------------------------
st.header("3. Latency — p50 and p95")

lat = summary["latency_ms"]
lc1, lc2 = st.columns(2)
lc1.metric("p50", f"{lat['p50']:.1f} ms")
lc2.metric("p95", f"{lat['p95']:.1f} ms")
st.caption(
    "Measured as the full per-case round trip in agent_client.py's run_case "
    "(session open through session close, including the trace-fetch attempt) — "
    "not isolated model-generation time. See docs/TRD.md §8."
)
st.bar_chart(pd.DataFrame({"latency_ms": [lat["p50"], lat["p95"]]}, index=["p50", "p95"]))

st.divider()

# --- Section 4: failure drill-down ------------------------------------------
st.header("4. Failure drill-down")

cases = data.get("cases", [])
if not cases:
    st.info("No per-case detail available in this results file.")
else:
    rows = []
    for c in cases:
        reasons = []
        if c.get("routing_pass") is False:
            reasons.append("routing")
        if c.get("action_sequence_pass") is False:
            reasons.append("action sequence")
        if c.get("grounding_pass") is False:
            reasons.append("grounding")
        if c.get("guardrail_pass") is False:
            reasons.append("guardrail")
        if c.get("claimed_but_not_performed") is True:
            reasons.append("claimed-but-not-performed")
        rows.append(
            {
                "Case": c["case_id"],
                "Utterance": c["utterance"],
                "Expected subagent": c["expected_subagent"],
                "Trace available": c["trace_available"],
                "Why it failed": ", ".join(reasons) if reasons else "—",
                "Note": c.get("note", ""),
            }
        )
    st.dataframe(pd.DataFrame(rows), use_container_width=True, hide_index=True)
    st.caption(
        f"Only {len(cases)} of {summary['cases_total']} total cases are shown — see the "
        "'How this dashboard's data was assembled' note above for why the rest aren't listed "
        "individually."
    )
