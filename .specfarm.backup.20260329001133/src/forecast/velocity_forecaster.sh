#!/bin/bash
# src/forecast/velocity_forecaster.sh — VelocityTrendForecaster prototype
# Task T0448: Ingests historical NDJSON drift reports; outputs 7-day linear forecast JSON
#
# Usage: bash src/forecast/velocity_forecaster.sh [--history-dir <path>]
#                                                   [--rule-id <id>]
#
# Input:  NDJSON drift records from .specfarm/drift-history/*.ndjson
#         Each line: {"timestamp":"...","rule_id":"...","status":"pass|drift|justified",...}
#
# Output schema (JSON):
#   {
#     "generated_at": "ISO-timestamp",
#     "window_days": 7,
#     "data_points": N,
#     "forecasts": [
#       {
#         "rule_id": "...",
#         "slope": -0.02,
#         "intercept": 0.95,
#         "trend": "improving|declining|stable",
#         "day_1": 0.88,
#         "day_3": 0.84,
#         "day_7": 0.76
#       }
#     ]
#   }
#
# Note: uses simple ordinary least-squares linear regression on pass-rate per day.
# Only stdlib used (math, json, sys, os, datetime, collections).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

HISTORY_DIR="${SPECFARM_ROOT:-.}/.specfarm/drift-history"
RULE_FILTER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --history-dir) HISTORY_DIR="$2"; shift 2 ;;
        --rule-id)     RULE_FILTER="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [[ ! -d "$HISTORY_DIR" ]]; then
    echo "ERROR: history directory not found: $HISTORY_DIR" >&2
    echo "       Run 'specfarm drift --format ndjson >> .specfarm/drift-history/\$(date +%F).ndjson' to populate it." >&2
    exit 1
fi

# Collect all NDJSON files in the history directory
NDJSON_FILES=()
while IFS= read -r -d '' f; do
    NDJSON_FILES+=("$f")
done < <(find "$HISTORY_DIR" -maxdepth 1 -name "*.ndjson" -type f -print0 2>/dev/null | sort -z)

if [[ ${#NDJSON_FILES[@]} -eq 0 ]]; then
    echo "ERROR: no .ndjson files found in $HISTORY_DIR" >&2
    exit 1
fi

# Pass file list and filter to Python for ingestion + linear regression (stdlib only)
python3 - "$RULE_FILTER" "${NDJSON_FILES[@]}" <<'PYEOF'
import json, sys, os, math
from datetime import datetime, timezone
from collections import defaultdict

rule_filter = sys.argv[1]   # empty string = all rules
ndjson_files = sys.argv[2:]

# ---- Ingest records ----
# Build: {rule_id: [(epoch_day, is_pass), ...]}
rule_days = defaultdict(list)
total_records = 0

for filepath in ndjson_files:
    try:
        with open(filepath) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue
                total_records += 1
                rule_id = rec.get("rule_id", "")
                if not rule_id:
                    continue
                if rule_filter and rule_id != rule_filter:
                    continue
                status = rec.get("status", "")
                ts_str = rec.get("timestamp", "")
                try:
                    dt = datetime.strptime(ts_str, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
                    epoch_day = dt.toordinal()  # integer day number
                except ValueError:
                    continue
                # 1 = pass/justified, 0 = drift
                is_pass = 1 if status in ("pass", "justified") else 0
                rule_days[rule_id].append((epoch_day, is_pass))
    except OSError:
        continue

if not rule_days:
    print(json.dumps({
        "error": "no parseable drift records found",
        "hint": "ensure NDJSON files contain timestamp, rule_id, and status fields"
    }))
    sys.exit(1)

# ---- Linear regression (OLS) per rule ----

def linear_regression(xs, ys):
    """Return (slope, intercept) from lists of x and y values."""
    n = len(xs)
    if n < 2:
        # Not enough data — return flat line at mean
        mean_y = sum(ys) / n if n > 0 else 0.5
        return 0.0, mean_y
    sum_x  = sum(xs)
    sum_y  = sum(ys)
    sum_xx = sum(x * x for x in xs)
    sum_xy = sum(x * y for x, y in zip(xs, ys))
    denom  = n * sum_xx - sum_x ** 2
    if denom == 0:
        return 0.0, sum_y / n
    slope     = (n * sum_xy - sum_x * sum_y) / denom
    intercept = (sum_y - slope * sum_x) / n
    return slope, intercept

def clamp(val, lo=0.0, hi=1.0):
    return max(lo, min(hi, val))

forecasts = []
for rule_id, day_points in sorted(rule_days.items()):
    xs = [p[0] for p in day_points]
    ys = [p[1] for p in day_points]

    slope, intercept = linear_regression(xs, ys)

    # Forecast relative to the last observed day
    last_day = max(xs)
    def predict(delta):
        return clamp(slope * (last_day + delta) + intercept)

    day1 = round(predict(1), 4)
    day3 = round(predict(3), 4)
    day7 = round(predict(7), 4)

    # Trend classification based on slope
    if slope > 0.005:
        trend = "improving"
    elif slope < -0.005:
        trend = "declining"
    else:
        trend = "stable"

    forecasts.append({
        "rule_id":   rule_id,
        "slope":     round(slope, 6),
        "intercept": round(intercept, 6),
        "trend":     trend,
        "day_1":     day1,
        "day_3":     day3,
        "day_7":     day7,
    })

output = {
    "generated_at": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    "window_days":  7,
    "data_points":  total_records,
    "forecasts":    forecasts,
}
print(json.dumps(output, indent=2))
PYEOF
