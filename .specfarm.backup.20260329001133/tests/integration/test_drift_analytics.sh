#!/bin/bash
# tests/integration/test_drift_analytics.sh
#
# Integration test for DriftAnalyticsProvider
# Task T0442: Validate NDJSON drift report export
#
# Tests: specfarm drift --format ndjson and --format json-summary

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

PASS=0
FAIL=0

_run_test() {
  local name="$1"
  local func="$2"
  local test_root
  test_root=$(mktemp -d)
  mkdir -p "$test_root/.specfarm"
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

# Helper: create minimal rules.xml for testing
_setup_test_rules() {
  cat > .specfarm/rules.xml <<'RULES'
<?xml version="1.0" encoding="UTF-8"?>
<rules version="1.0">
  <rule id="test-rule-1" severity="hard-block" phase="1">
    <signature>set -euo pipefail</signature>
    <description>Strict mode required</description>
  </rule>
  <rule id="test-rule-2" severity="advisory" phase="2">
    <signature>SCRIPT_DIR=</signature>
    <description>Script dir detection</description>
  </rule>
</rules>
RULES
  # Create a sample source file
  mkdir -p src
  echo '#!/bin/bash' > src/sample.sh
  echo 'set -euo pipefail' >> src/sample.sh
  echo 'echo "hello"' >> src/sample.sh
}

# ---- Test: NDJSON export produces output ----
t0442_ndjson_produces_output() {
  _setup_test_rules
  local output
  output=$(bash "$REPO_ROOT/src/drift/drift_analytics.sh" --format ndjson 2>&1)
  [ -n "$output" ]
}

# ---- Test: Each NDJSON line is valid JSON ----
t0442_ndjson_valid_json() {
  _setup_test_rules
  local output
  output=$(bash "$REPO_ROOT/src/drift/drift_analytics.sh" --format ndjson 2>&1)
  local valid=true
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      echo "$line" | python3 -m json.tool >/dev/null 2>&1 || { valid=false; break; }
    fi
  done <<< "$output"
  $valid
}

# ---- Test: NDJSON lines contain required fields ----
t0442_ndjson_fields() {
  _setup_test_rules
  local output
  output=$(bash "$REPO_ROOT/src/drift/drift_analytics.sh" --format ndjson 2>&1)
  local first_line
  first_line=$(echo "$output" | head -1)
  local has_ts has_rule has_status
  has_ts=$(echo "$first_line" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'timestamp' in d else 'no')")
  has_rule=$(echo "$first_line" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'rule_id' in d else 'no')")
  has_status=$(echo "$first_line" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'status' in d else 'no')")
  [[ "$has_ts" == "yes" && "$has_rule" == "yes" && "$has_status" == "yes" ]]
}

# ---- Test: JSON summary produces valid JSON ----
t0442_json_summary_valid() {
  _setup_test_rules
  local output
  output=$(bash "$REPO_ROOT/src/drift/drift_analytics.sh" --format json-summary 2>&1)
  echo "$output" | python3 -m json.tool >/dev/null 2>&1
}

# ---- Test: JSON summary contains report_id ----
t0442_json_summary_report_id() {
  _setup_test_rules
  local output
  output=$(bash "$REPO_ROOT/src/drift/drift_analytics.sh" --format json-summary 2>&1)
  local has_id
  has_id=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'report_id' in d else 'no')")
  [ "$has_id" = "yes" ]
}

# ---- Test: JSON summary contains adherence score ----
t0442_json_summary_adherence() {
  _setup_test_rules
  local output
  output=$(bash "$REPO_ROOT/src/drift/drift_analytics.sh" --format json-summary 2>&1)
  local has_adherence
  has_adherence=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'adherence_pct' in d else 'no')")
  [ "$has_adherence" = "yes" ]
}

echo "=== Integration Tests: DriftAnalyticsProvider (T0442) ==="
_run_test "T0442: NDJSON export produces output" t0442_ndjson_produces_output
_run_test "T0442: each NDJSON line is valid JSON" t0442_ndjson_valid_json
_run_test "T0442: NDJSON lines contain required fields" t0442_ndjson_fields
_run_test "T0442: JSON summary is valid JSON" t0442_json_summary_valid
_run_test "T0442: JSON summary contains report_id" t0442_json_summary_report_id
_run_test "T0442: JSON summary contains adherence score" t0442_json_summary_adherence

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
