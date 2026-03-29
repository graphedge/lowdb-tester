#!/bin/bash
# tests/unit/test_drift_score_calculation.sh
#
# Test suite for drift score calculation logic
# Phase 1 Task T015-T021: Define Drift Score Criteria
#
# Formula: drift_score = 1.0 - (violated_rules / max(total_rules, 1))
# Converted from BATS to plain bash (no external dependencies)

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TESTS_DIR/test_helper.sh"

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

# T015: Research drift scoring patterns
# T016: Define drift score formula
# Test 1: Basic formula - perfect adherence (1.0)
t016_drift_score_no_violations() {
  run drift_score 0 10
  [ "$status" -eq 0 ] && [ "$output" = "1.0" ]
}

# Test 2: 50% drift - half rules violated
t016_drift_score_half_violated() {
  run drift_score 5 10
  [ "$status" -eq 0 ] && [ "$output" = "0.5" ]
}

# T018: Define edge cases
# Test 3: Edge case - zero total rules
t018_drift_score_zero_total() {
  run drift_score 0 0
  [ "$status" -eq 0 ] && [ "$output" = "1.0" ]
}

# Test 4: Edge case - single rule violated
t016_drift_score_all_violated_1_1() {
  run drift_score 1 1
  [ "$status" -eq 0 ] && [ "$output" = "0.0" ]
}

# Test 5: Edge case - 90% adherence
t016_drift_score_one_violation_ten() {
  run drift_score 1 10
  [ "$status" -eq 0 ] && [ "$output" = "0.9" ]
}

# T016-T020: Scoring precision and examples
# Test 6: Floating point precision (rounds to 2 decimals)
t020_drift_score_float_precision() {
  run drift_score 1 3
  [ "$status" -eq 0 ] && [[ "$output" =~ ^0\.6[67] ]]
}

# Test 7: Complete drift (all rules violated)
t016_drift_score_all_violated_10_10() {
  run drift_score 10 10
  [ "$status" -eq 0 ] && [ "$output" = "0.0" ]
}

# Test 8: Large number of rules
t016_drift_score_large_counts() {
  run drift_score 100 1000
  [ "$status" -eq 0 ] && [ "$output" = "0.9" ]
}

echo "=== Unit Tests: Drift Score Calculation ==="
_run_test "T016: drift_score returns 1.0 when no violations" t016_drift_score_no_violations
_run_test "T016: drift_score returns 0.5 when half rules violated (5/10)" t016_drift_score_half_violated
_run_test "T018: drift_score returns 1.0 when zero total rules (no drift possible)" t018_drift_score_zero_total
_run_test "T016: drift_score returns 0.0 when all rules violated (1/1)" t016_drift_score_all_violated_1_1
_run_test "T016: drift_score returns 0.9 when 1 violation in 10 rules" t016_drift_score_one_violation_ten
_run_test "T020: drift_score handles floating point precision (0.333...)" t020_drift_score_float_precision
_run_test "T016: drift_score returns 0.0 when all rules violated (10/10)" t016_drift_score_all_violated_10_10
_run_test "T016: drift_score handles large rule counts (1000 rules, 100 violations)" t016_drift_score_large_counts

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
