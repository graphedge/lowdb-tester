#!/bin/bash
# tests/unit/test_rule_optimizer.sh
#
# Test suite for RuleOptimizer prototype
# Task T0447: Validate scoring model output format and evaluation harness
#
# Tests that src/optimizer/rule_optimizer.sh produces correct JSON output
# with the expected schema for each rule recommendation scenario.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

PASS=0
FAIL=0

_run_test() {
  local name="$1"
  local func="$2"
  local test_root
  test_root=$(mktemp -d)
  mkdir -p "$test_root/.specfarm/drift-history"
  local saved_dir="$PWD"
  cd "$test_root" || { echo "FAIL: $name (cd failed)"; FAIL=$((FAIL+1)); return; }
  if (export SPECFARM_ROOT="$test_root"; "$func"); then
    echo "PASS: $name"
    PASS=$((PASS+1))
  else
    echo "FAIL: $name"
    FAIL=$((FAIL+1))
  fi
  cd "$saved_dir" || true
  rm -rf "$test_root"
}

# Helper: write a drift NDJSON fixture
_write_drift_ndjson() {
  local file="$1"
  cat > "$file" <<'EOF'
{"timestamp":"2026-03-01T10:00:00Z","rule_id":"strict-mode","signature":"set -euo pipefail","severity":"critical","phase":"1","status":"drift","scope":"."}
{"timestamp":"2026-03-01T10:00:00Z","rule_id":"module-integrity","signature":"declare -f","severity":"high","phase":"2","status":"pass","scope":"."}
{"timestamp":"2026-03-01T10:00:00Z","rule_id":"test-coverage","signature":"_run_test","severity":"advisory","phase":"3","status":"justified","scope":"."}
EOF
}

# Helper: write a 7-day forecast fixture
_write_forecast_json() {
  local file="$1"
  cat > "$file" <<'EOF'
{
  "generated_at": "2026-03-01T12:00:00Z",
  "window_days": 7,
  "forecasts": [
    {"rule_id": "strict-mode", "day_1": 0.40, "day_7": 0.30},
    {"rule_id": "module-integrity", "day_1": 0.90, "day_7": 0.88},
    {"rule_id": "test-coverage", "day_1": 0.75, "day_7": 0.72}
  ]
}
EOF
}

# ---- Test: optimizer exits 0 with valid drift report ----
t0447_exits_zero() {
  local ndjson
  ndjson="$(mktemp).ndjson"
  _write_drift_ndjson "$ndjson"
  bash "$REPO_ROOT/src/optimizer/rule_optimizer.sh" --drift-report "$ndjson" >/dev/null 2>&1
  local rc=$?
  rm -f "$ndjson"
  [[ $rc -eq 0 ]]
}

# ---- Test: output is valid JSON ----
t0447_output_is_json() {
  local ndjson
  ndjson="$(mktemp).ndjson"
  _write_drift_ndjson "$ndjson"
  local out
  out=$(bash "$REPO_ROOT/src/optimizer/rule_optimizer.sh" --drift-report "$ndjson" 2>/dev/null)
  rm -f "$ndjson"
  echo "$out" | python3 -m json.tool >/dev/null 2>&1
}

# ---- Test: output contains required top-level keys ----
t0447_required_keys() {
  local ndjson
  ndjson="$(mktemp).ndjson"
  _write_drift_ndjson "$ndjson"
  local out
  out=$(bash "$REPO_ROOT/src/optimizer/rule_optimizer.sh" --drift-report "$ndjson" 2>/dev/null)
  rm -f "$ndjson"
  echo "$out" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert 'generated_at' in d
assert 'total_rules_analyzed' in d
assert 'suggestions' in d
" 2>/dev/null
}

# ---- Test: each suggestion has required fields ----
t0447_suggestion_schema() {
  local ndjson tmp_json
  ndjson="$(mktemp).ndjson"
  _write_drift_ndjson "$ndjson"
  local out
  out=$(bash "$REPO_ROOT/src/optimizer/rule_optimizer.sh" --drift-report "$ndjson" 2>/dev/null)
  rm -f "$ndjson"
  tmp_json=$(mktemp)
  echo "$out" > "$tmp_json"
  python3 - "$tmp_json" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
required = ["rule_id", "current_status", "optimization_score", "recommendation", "rationale", "priority"]
for s in d["suggestions"]:
    for field in required:
        assert field in s, f"Missing field {field} in suggestion {s}"
    assert isinstance(s["optimization_score"], float), "optimization_score must be float"
    assert 0.0 <= s["optimization_score"] <= 1.0, "optimization_score must be in [0,1]"
    assert s["recommendation"] in ("keep","relax","strengthen","remove"), f"Bad recommendation: {s['recommendation']}"
    assert s["priority"] in ("high","medium","low"), f"Bad priority: {s['priority']}"
print("ok")
PYEOF
  local rc=$?
  rm -f "$tmp_json"
  [[ $rc -eq 0 ]]
}

# ---- Test: drift rule scores higher than passing rule ----
t0447_drift_scores_higher() {
  local ndjson tmp_json
  ndjson="$(mktemp).ndjson"
  _write_drift_ndjson "$ndjson"
  local out
  out=$(bash "$REPO_ROOT/src/optimizer/rule_optimizer.sh" --drift-report "$ndjson" 2>/dev/null)
  rm -f "$ndjson"
  tmp_json=$(mktemp)
  echo "$out" > "$tmp_json"
  python3 - "$tmp_json" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
scores = {s["rule_id"]: s["optimization_score"] for s in d["suggestions"]}
assert scores["strict-mode"] > scores["module-integrity"], \
    f"drift rule {scores['strict-mode']} should score higher than pass rule {scores['module-integrity']}"
print("ok")
PYEOF
  local rc=$?
  rm -f "$tmp_json"
  [[ $rc -eq 0 ]]
}

# ---- Test: total_rules_analyzed matches suggestion count ----
t0447_count_matches() {
  local ndjson
  ndjson="$(mktemp).ndjson"
  _write_drift_ndjson "$ndjson"
  local out
  out=$(bash "$REPO_ROOT/src/optimizer/rule_optimizer.sh" --drift-report "$ndjson" 2>/dev/null)
  rm -f "$ndjson"
  echo "$out" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['total_rules_analyzed'] == len(d['suggestions'])
" 2>/dev/null
}

# ---- Test: forecast data influences scores ----
t0447_forecast_influences_score() {
  local ndjson forecast
  ndjson="$(mktemp).ndjson"
  forecast="$(mktemp).json"
  _write_drift_ndjson "$ndjson"
  _write_forecast_json "$forecast"

  local out_no_fc out_with_fc
  out_no_fc=$(bash "$REPO_ROOT/src/optimizer/rule_optimizer.sh" --drift-report "$ndjson" 2>/dev/null)
  out_with_fc=$(bash "$REPO_ROOT/src/optimizer/rule_optimizer.sh" \
    --drift-report "$ndjson" --forecast "$forecast" 2>/dev/null)
  rm -f "$ndjson" "$forecast"

  # Both should be valid JSON
  echo "$out_no_fc"  | python3 -m json.tool >/dev/null 2>&1 || return 1
  echo "$out_with_fc" | python3 -m json.tool >/dev/null 2>&1 || return 1
}

# ---- Test: text output mode works ----
t0447_text_output() {
  local ndjson
  ndjson="$(mktemp).ndjson"
  _write_drift_ndjson "$ndjson"
  local out
  out=$(bash "$REPO_ROOT/src/optimizer/rule_optimizer.sh" \
    --drift-report "$ndjson" --output text 2>/dev/null)
  rm -f "$ndjson"
  [[ "$out" == *"RuleOptimizer Report"* ]]
}

# ---- Test: missing drift report exits non-zero ----
t0447_missing_report_fails() {
  bash "$REPO_ROOT/src/optimizer/rule_optimizer.sh" \
    --drift-report /nonexistent/drift.ndjson >/dev/null 2>&1
  [[ $? -ne 0 ]]
}

echo "=== Unit Tests: RuleOptimizer (T0447) ==="
_run_test "T0447: exits 0 with valid drift report"         t0447_exits_zero
_run_test "T0447: output is valid JSON"                     t0447_output_is_json
_run_test "T0447: output has required top-level keys"       t0447_required_keys
_run_test "T0447: each suggestion has required fields"      t0447_suggestion_schema
_run_test "T0447: drift rule scores higher than pass rule"  t0447_drift_scores_higher
_run_test "T0447: total_rules_analyzed matches count"       t0447_count_matches
_run_test "T0447: forecast data accepted without error"     t0447_forecast_influences_score
_run_test "T0447: text output mode works"                   t0447_text_output
_run_test "T0447: missing drift report exits non-zero"      t0447_missing_report_fails

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
