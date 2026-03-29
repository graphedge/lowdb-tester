#!/bin/bash
# src/optimizer/rule_optimizer.sh — RuleOptimizer prototype + evaluation harness
# Task T0447: Scores rules for optimization potential using drift + velocity data
#
# Usage: bash src/optimizer/rule_optimizer.sh [--drift-report <ndjson_file>]
#                                              [--forecast <forecast_json>]
#                                              [--output json|text]
#
# Input schema:
#   --drift-report: NDJSON file (one drift record per line) from DriftAnalyticsProvider
#   --forecast:     7-day forecast JSON from VelocityTrendForecaster (optional)
#
# Output schema (JSON):
#   {
#     "generated_at": "ISO-timestamp",
#     "total_rules_analyzed": N,
#     "suggestions": [
#       {
#         "rule_id": "...",
#         "current_status": "pass|drift|justified",
#         "optimization_score": 0.0-1.0,
#         "recommendation": "keep|relax|strengthen|remove",
#         "rationale": "...",
#         "priority": "high|medium|low"
#       }
#     ]
#   }
#
# Note: This is a Phase 5 prototype. No auto-apply; human approval required.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

DRIFT_REPORT=""
FORECAST_FILE=""
OUTPUT_FORMAT="json"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --drift-report) DRIFT_REPORT="$2"; shift 2 ;;
        --forecast)     FORECAST_FILE="$2"; shift 2 ;;
        --output)       OUTPUT_FORMAT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Default to most recent NDJSON in .specfarm/drift-history/ if not specified
if [[ -z "$DRIFT_REPORT" ]]; then
    drift_history_dir="${SPECFARM_ROOT:-.}/.specfarm/drift-history"
    if [[ -d "$drift_history_dir" ]]; then
        DRIFT_REPORT=$(find "$drift_history_dir" -name "*.ndjson" -type f | sort | tail -1 2>/dev/null || echo "")
    fi
fi

if [[ -z "$DRIFT_REPORT" || ! -f "$DRIFT_REPORT" ]]; then
    echo "ERROR: no drift report found. Provide --drift-report <file> or run 'specfarm drift --format ndjson'" >&2
    exit 1
fi

# ---- Scoring engine ----

python3 - "$DRIFT_REPORT" "${FORECAST_FILE:-}" "$OUTPUT_FORMAT" <<'PYEOF'
import json, sys, os, math
from datetime import datetime

drift_path    = sys.argv[1]
forecast_path = sys.argv[2] if len(sys.argv) > 2 else ""
output_fmt    = sys.argv[3] if len(sys.argv) > 3 else "json"

# Load drift records
records = []
try:
    with open(drift_path) as f:
        for line in f:
            line = line.strip()
            if line:
                records.append(json.loads(line))
except Exception as e:
    print(f"ERROR: could not parse drift report: {e}", file=sys.stderr)
    sys.exit(1)

# Load forecast if provided
forecast_map = {}  # rule_id -> predicted_score
if forecast_path and os.path.isfile(forecast_path):
    try:
        with open(forecast_path) as f:
            forecast_data = json.load(f)
        for entry in forecast_data.get("forecasts", []):
            rule_id = entry.get("rule_id", "")
            day7    = entry.get("day_7", None)
            if rule_id and day7 is not None:
                forecast_map[rule_id] = float(day7)
    except Exception:
        pass  # forecast is optional; silently ignore parse errors


def score_rule(record, predicted_score):
    """
    Compute an optimization_score ∈ [0, 1] and recommendation for a rule.

    Scoring rationale:
      - Drift rules (status=drift) score high → need attention → recommend 'strengthen'
      - Pass rules with declining forecast → score medium → recommend 'keep' with note
      - Justified rules → score low → recommend 'relax' or 'remove' if always justified
      - Pass rules with stable/improving forecast → score near 0 → recommend 'keep'
    """
    status   = record.get("status", "unknown")
    severity = record.get("severity", "advisory")

    # Base score by status
    if status == "drift":
        base = 0.8
    elif status == "justified":
        base = 0.5
    else:
        base = 0.1

    # Severity modifier
    sev_mod = {"critical": 0.15, "high": 0.10, "advisory": 0.0, "low": -0.05}.get(severity, 0.0)
    base = min(1.0, max(0.0, base + sev_mod))

    # Forecast modifier: declining trend increases urgency for drift rules
    if predicted_score is not None:
        # If forecast shows declining score (more drift expected), bump score up
        trend_mod = 0.0
        if status == "drift" and predicted_score < 0.5:
            trend_mod = 0.10
        elif status == "pass" and predicted_score < 0.6:
            trend_mod = 0.05
        base = min(1.0, base + trend_mod)

    # Recommendation
    if status == "drift" and base >= 0.7:
        rec = "strengthen"
        rationale = "Rule is currently violated and has high optimization impact. Enforce or rewrite acceptance criteria."
    elif status == "drift" and base < 0.7:
        rec = "strengthen"
        rationale = "Rule is violated. Review whether rule is still relevant."
    elif status == "justified":
        rec = "relax"
        rationale = "Rule is consistently justified. Consider relaxing or removing if no longer relevant."
    elif status == "pass" and predicted_score is not None and predicted_score < 0.6:
        rec = "keep"
        rationale = "Rule currently passes but forecast indicates potential drift. Monitor closely."
    else:
        rec = "keep"
        rationale = "Rule is passing and stable. No action required."

    # Priority
    if base >= 0.7:
        priority = "high"
    elif base >= 0.4:
        priority = "medium"
    else:
        priority = "low"

    return round(base, 3), rec, rationale, priority


suggestions = []
for rec in records:
    rule_id = rec.get("rule_id", "unknown")
    predicted = forecast_map.get(rule_id, None)
    opt_score, recommendation, rationale, priority = score_rule(rec, predicted)

    suggestions.append({
        "rule_id": rule_id,
        "current_status": rec.get("status", "unknown"),
        "optimization_score": opt_score,
        "recommendation": recommendation,
        "rationale": rationale,
        "priority": priority
    })

# Sort by optimization_score descending (highest priority first)
suggestions.sort(key=lambda x: x["optimization_score"], reverse=True)

output = {
    "generated_at": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    "total_rules_analyzed": len(suggestions),
    "suggestions": suggestions
}

if output_fmt == "json":
    print(json.dumps(output, indent=2))
else:
    # Text summary
    print(f"RuleOptimizer Report — {output['generated_at']}")
    print(f"Rules analyzed: {output['total_rules_analyzed']}")
    print("")
    for s in suggestions:
        print(f"  [{s['priority'].upper():6s}] {s['rule_id']:30s} score={s['optimization_score']:.3f}  {s['recommendation']:10s}  {s['rationale'][:80]}")
PYEOF
