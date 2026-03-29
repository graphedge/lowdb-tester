#!/bin/bash
# tests/integration/test_velocity_forecaster.sh
#
# Integration tests for VelocityTrendForecaster
# Task T0448: Validate forecast format and data ingestion from NDJSON drift history
#
# Tests that src/forecast/velocity_forecaster.sh correctly:
# - Ingests historical NDJSON drift records
# - Produces valid 7-day linear forecast JSON
# - Validates the output schema and trend classification

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
  if (export SPECFARM_ROOT="$test_root"; HIST_DIR="$test_root/.specfarm/drift-history"; "$func"); then
    echo "PASS: $name"
    PASS=$((PASS+1))
  else
    echo "FAIL: $name"
    FAIL=$((FAIL+1))
  fi
  cd "$saved_dir" || true
  rm -rf "$test_root"
}

# Helper: write a multi-day drift history fixture
# Simulates 5 days of drift scans for two rules
_write_history_fixture() {
  local dir="$1"
  # Day 1: strict-mode drifting, module-integrity passing
  cat > "$dir/2026-02-25.ndjson" <<'EOF'
{"timestamp":"2026-02-25T10:00:00Z","rule_id":"strict-mode","signature":"set -euo pipefail","severity":"critical","phase":"1","status":"drift","scope":"."}
{"timestamp":"2026-02-25T10:00:00Z","rule_id":"module-integrity","signature":"declare -f","severity":"high","phase":"2","status":"pass","scope":"."}
EOF
  # Day 2
  cat > "$dir/2026-02-26.ndjson" <<'EOF'
{"timestamp":"2026-02-26T10:00:00Z","rule_id":"strict-mode","signature":"set -euo pipefail","severity":"critical","phase":"1","status":"drift","scope":"."}
{"timestamp":"2026-02-26T10:00:00Z","rule_id":"module-integrity","signature":"declare -f","severity":"high","phase":"2","status":"pass","scope":"."}
EOF
  # Day 3: strict-mode still drifting
  cat > "$dir/2026-02-27.ndjson" <<'EOF'
{"timestamp":"2026-02-27T10:00:00Z","rule_id":"strict-mode","signature":"set -euo pipefail","severity":"critical","phase":"1","status":"drift","scope":"."}
{"timestamp":"2026-02-27T10:00:00Z","rule_id":"module-integrity","signature":"declare -f","severity":"high","phase":"2","status":"pass","scope":"."}
EOF
  # Day 4: strict-mode starts passing (fixed)
  cat > "$dir/2026-02-28.ndjson" <<'EOF'
{"timestamp":"2026-02-28T10:00:00Z","rule_id":"strict-mode","signature":"set -euo pipefail","severity":"critical","phase":"1","status":"pass","scope":"."}
{"timestamp":"2026-02-28T10:00:00Z","rule_id":"module-integrity","signature":"declare -f","severity":"high","phase":"2","status":"pass","scope":"."}
EOF
  # Day 5
  cat > "$dir/2026-03-01.ndjson" <<'EOF'
{"timestamp":"2026-03-01T10:00:00Z","rule_id":"strict-mode","signature":"set -euo pipefail","severity":"critical","phase":"1","status":"pass","scope":"."}
{"timestamp":"2026-03-01T10:00:00Z","rule_id":"module-integrity","signature":"declare -f","severity":"high","phase":"2","status":"pass","scope":"."}
EOF
}

# ---- Test: forecaster exits 0 with valid history ----
t0448_exits_zero() {
  _write_history_fixture "$HIST_DIR"
  bash "$REPO_ROOT/src/forecast/velocity_forecaster.sh" \
    --history-dir "$HIST_DIR" >/dev/null 2>&1
}

# ---- Test: output is valid JSON ----
t0448_output_is_json() {
  _write_history_fixture "$HIST_DIR"
  local out
  out=$(bash "$REPO_ROOT/src/forecast/velocity_forecaster.sh" \
    --history-dir "$HIST_DIR" 2>/dev/null)
  echo "$out" | python3 -m json.tool >/dev/null 2>&1
}

# ---- Test: output contains required top-level keys ----
t0448_required_top_keys() {
  _write_history_fixture "$HIST_DIR"
  local out
  out=$(bash "$REPO_ROOT/src/forecast/velocity_forecaster.sh" \
    --history-dir "$HIST_DIR" 2>/dev/null)
  echo "$out" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert 'generated_at' in d, 'missing generated_at'
assert 'window_days' in d,  'missing window_days'
assert 'data_points' in d,  'missing data_points'
assert 'forecasts' in d,    'missing forecasts'
assert d['window_days'] == 7
" 2>/dev/null
}

# ---- Test: each forecast entry has required fields ----
t0448_forecast_entry_schema() {
  _write_history_fixture "$HIST_DIR"
  local out tmp_json
  out=$(bash "$REPO_ROOT/src/forecast/velocity_forecaster.sh" \
    --history-dir "$HIST_DIR" 2>/dev/null)
  tmp_json=$(mktemp)
  echo "$out" > "$tmp_json"
  python3 - "$tmp_json" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
assert len(d["forecasts"]) > 0, "no forecast entries"
required = ["rule_id", "slope", "intercept", "trend", "day_1", "day_3", "day_7"]
for f in d["forecasts"]:
    for field in required:
        assert field in f, f"missing field '{field}' in forecast {f}"
    assert f["trend"] in ("improving", "declining", "stable"), f"bad trend: {f['trend']}"
    for day_key in ("day_1", "day_3", "day_7"):
        val = f[day_key]
        assert isinstance(val, (int, float)), f"{day_key} must be numeric"
        assert 0.0 <= val <= 1.0, f"{day_key} must be in [0,1], got {val}"
print("ok")
PYEOF
  local rc=$?
  rm -f "$tmp_json"
  [[ $rc -eq 0 ]]
}

# ---- Test: improves-over-time rule trends "improving" ----
t0448_improving_trend_detected() {
  # strict-mode goes from 0,0,0,1,1 (drift then pass) → improving slope
  _write_history_fixture "$HIST_DIR"
  local out tmp_json
  out=$(bash "$REPO_ROOT/src/forecast/velocity_forecaster.sh" \
    --history-dir "$HIST_DIR" 2>/dev/null)
  tmp_json=$(mktemp)
  echo "$out" > "$tmp_json"
  python3 - "$tmp_json" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
trends = {f["rule_id"]: f["trend"] for f in d["forecasts"]}
assert trends.get("strict-mode") == "improving", \
    f"expected improving for strict-mode, got {trends.get('strict-mode')}"
print("ok")
PYEOF
  local rc=$?
  rm -f "$tmp_json"
  [[ $rc -eq 0 ]]
}

# ---- Test: always-passing rule trends "stable" ----
t0448_stable_trend_detected() {
  _write_history_fixture "$HIST_DIR"
  local out tmp_json
  out=$(bash "$REPO_ROOT/src/forecast/velocity_forecaster.sh" \
    --history-dir "$HIST_DIR" 2>/dev/null)
  tmp_json=$(mktemp)
  echo "$out" > "$tmp_json"
  python3 - "$tmp_json" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
trends = {f["rule_id"]: f["trend"] for f in d["forecasts"]}
assert trends.get("module-integrity") == "stable", \
    f"expected stable for module-integrity, got {trends.get('module-integrity')}"
print("ok")
PYEOF
  local rc=$?
  rm -f "$tmp_json"
  [[ $rc -eq 0 ]]
}

# ---- Test: --rule-id filter returns only that rule ----
t0448_rule_filter() {
  _write_history_fixture "$HIST_DIR"
  local out
  out=$(bash "$REPO_ROOT/src/forecast/velocity_forecaster.sh" \
    --history-dir "$HIST_DIR" --rule-id "strict-mode" 2>/dev/null)
  echo "$out" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert len(d['forecasts']) == 1
assert d['forecasts'][0]['rule_id'] == 'strict-mode'
" 2>/dev/null
}

# ---- Test: missing history dir exits non-zero ----
t0448_missing_dir_fails() {
  bash "$REPO_ROOT/src/forecast/velocity_forecaster.sh" \
    --history-dir "/nonexistent/drift-history" >/dev/null 2>&1
  [[ $? -ne 0 ]]
}

# ---- Test: empty history dir exits non-zero ----
t0448_empty_dir_fails() {
  # dir exists but no .ndjson files
  bash "$REPO_ROOT/src/forecast/velocity_forecaster.sh" \
    --history-dir "$HIST_DIR" >/dev/null 2>&1
  [[ $? -ne 0 ]]
}

# ---- Test: data_points count matches total NDJSON records ingested ----
t0448_data_points_count() {
  _write_history_fixture "$HIST_DIR"
  local out
  out=$(bash "$REPO_ROOT/src/forecast/velocity_forecaster.sh" \
    --history-dir "$HIST_DIR" 2>/dev/null)
  echo "$out" | python3 -c "
import json, sys
d = json.load(sys.stdin)
# 5 days × 2 rules = 10 records
assert d['data_points'] == 10, f\"expected 10 data_points, got {d['data_points']}\"
" 2>/dev/null
}

echo "=== Integration Tests: VelocityTrendForecaster (T0448) ==="
_run_test "T0448: exits 0 with valid history"               t0448_exits_zero
_run_test "T0448: output is valid JSON"                      t0448_output_is_json
_run_test "T0448: output has required top-level keys"        t0448_required_top_keys
_run_test "T0448: each forecast entry has required fields"   t0448_forecast_entry_schema
_run_test "T0448: improving rule trend detected correctly"   t0448_improving_trend_detected
_run_test "T0448: stable rule trend detected correctly"      t0448_stable_trend_detected
_run_test "T0448: --rule-id filter returns only that rule"   t0448_rule_filter
_run_test "T0448: missing history dir exits non-zero"        t0448_missing_dir_fails
_run_test "T0448: empty history dir exits non-zero"          t0448_empty_dir_fails
_run_test "T0448: data_points count matches ingested records" t0448_data_points_count

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
