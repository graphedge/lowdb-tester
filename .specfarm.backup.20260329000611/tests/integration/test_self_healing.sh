#!/bin/bash
# tests/integration/test_self_healing.sh
#
# Integration test for SelfHealingExecutor prototype
# Task T0443: Validate rollback safety and audit logging
#
# Tests the prototype that simulates patch+rollback with audit trail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

PASS=0
FAIL=0

_run_test() {
  local name="$1"
  local func="$2"
  local test_root
  test_root=$(mktemp -d)
  mkdir -p "$test_root/.specfarm/audit"
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

# Helper: create a test file to "heal"
_setup_healable_file() {
  mkdir -p src
  echo '#!/bin/bash' > src/broken.sh
  echo 'echo "missing strict mode"' >> src/broken.sh
}

# ---- Test: Executor produces audit log ----
t0443_produces_audit() {
  _setup_healable_file
  bash "$REPO_ROOT/src/healing/self_healing_executor.sh" \
    --file src/broken.sh \
    --rule-id "strict-mode" \
    --action "suggest" \
    --dry-run 2>&1
  [ -f ".specfarm/audit/healing-log.ndjson" ]
}

# ---- Test: Audit log is valid NDJSON ----
t0443_audit_valid_ndjson() {
  _setup_healable_file
  bash "$REPO_ROOT/src/healing/self_healing_executor.sh" \
    --file src/broken.sh \
    --rule-id "strict-mode" \
    --action "suggest" \
    --dry-run 2>&1
  local valid=true
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      echo "$line" | python3 -m json.tool >/dev/null 2>&1 || { valid=false; break; }
    fi
  done < ".specfarm/audit/healing-log.ndjson"
  $valid
}

# ---- Test: Dry-run does NOT modify the source file ----
t0443_dry_run_no_modify() {
  _setup_healable_file
  local before
  before=$(cat src/broken.sh)
  bash "$REPO_ROOT/src/healing/self_healing_executor.sh" \
    --file src/broken.sh \
    --rule-id "strict-mode" \
    --action "apply_patch" \
    --dry-run 2>&1
  local after
  after=$(cat src/broken.sh)
  [ "$before" = "$after" ]
}

# ---- Test: Audit log contains required fields ----
t0443_audit_fields() {
  _setup_healable_file
  bash "$REPO_ROOT/src/healing/self_healing_executor.sh" \
    --file src/broken.sh \
    --rule-id "strict-mode" \
    --action "suggest" \
    --dry-run 2>&1
  local entry
  entry=$(head -1 ".specfarm/audit/healing-log.ndjson")
  local has_ts has_rule has_action has_status
  has_ts=$(echo "$entry" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'timestamp' in d else 'no')")
  has_rule=$(echo "$entry" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'rule_id' in d else 'no')")
  has_action=$(echo "$entry" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'action' in d else 'no')")
  has_status=$(echo "$entry" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'status' in d else 'no')")
  [[ "$has_ts" == "yes" && "$has_rule" == "yes" && "$has_action" == "yes" && "$has_status" == "yes" ]]
}

# ---- Test: Rollback flag is present in audit ----
t0443_rollback_flag() {
  _setup_healable_file
  bash "$REPO_ROOT/src/healing/self_healing_executor.sh" \
    --file src/broken.sh \
    --rule-id "strict-mode" \
    --action "apply_patch" \
    --dry-run 2>&1
  local entry
  entry=$(head -1 ".specfarm/audit/healing-log.ndjson")
  local has_rollback
  has_rollback=$(echo "$entry" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'rollback_available' in d else 'no')")
  [ "$has_rollback" = "yes" ]
}

# ---- Test: Exit code is 0 for dry-run ----
t0443_dry_run_exit_zero() {
  _setup_healable_file
  bash "$REPO_ROOT/src/healing/self_healing_executor.sh" \
    --file src/broken.sh \
    --rule-id "strict-mode" \
    --action "suggest" \
    --dry-run >/dev/null 2>&1
}

echo "=== Integration Tests: SelfHealingExecutor (T0443) ==="
_run_test "T0443: executor produces audit log" t0443_produces_audit
_run_test "T0443: audit log is valid NDJSON" t0443_audit_valid_ndjson
_run_test "T0443: dry-run does not modify source file" t0443_dry_run_no_modify
_run_test "T0443: audit log contains required fields" t0443_audit_fields
_run_test "T0443: rollback flag present in audit" t0443_rollback_flag
_run_test "T0443: dry-run exits 0" t0443_dry_run_exit_zero

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
