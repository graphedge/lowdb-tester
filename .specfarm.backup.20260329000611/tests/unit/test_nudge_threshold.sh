#!/bin/bash
# tests/unit/test_nudge_threshold.sh
#
# Test suite for nudge/whisper threshold logic
# Phase 1 Task T030-T036: Add Threshold Specification
#
# Thresholds:
#   - Green: score > 0.9 (drift < 0.1 / 10%)
#   - Whisper: 0.5 < score ≤ 0.9 (drift 10-50%)
#   - Nudge: score ≤ 0.5 (drift ≥ 50%)
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

# T030: Make decision on hardcoded vs configurable
# T031: Research threshold patterns
# T033: Add "Drift Threshold" section
# T036: Update acceptance criteria

# Test 1: Nudge required at exact threshold (score = 0.5)
t033_nudge_required_at_threshold() {
  run nudge_required 0.5
  [ "$status" -eq 0 ] && [ "$output" = "true" ]
}

# Test 2: Nudge required when drift > 50%
t033_nudge_required_below_threshold() {
  run nudge_required 0.4
  [ "$status" -eq 0 ] && [ "$output" = "true" ]
}

# Test 3: No nudge when score > 0.5
t033_nudge_not_required_above_threshold() {
  run nudge_required 0.6
  [ "$status" -eq 0 ] && [ "$output" = "false" ]
}

# Test 4: Whisper required at threshold boundary (score = 0.7, drift = 30%)
t033_whisper_required_mid_range() {
  run whisper_required 0.7
  [ "$status" -eq 0 ] && [ "$output" = "true" ]
}

# Test 5: No whisper when score too low (nudge range)
t033_whisper_not_required_nudge_range() {
  run whisper_required 0.5
  [ "$status" -eq 0 ] && [ "$output" = "false" ]
}

# Test 6: No whisper when score too high (green range)
t033_whisper_not_required_green_range() {
  run whisper_required 0.9
  [ "$status" -eq 0 ] && [ "$output" = "false" ]
}

# T032: Design farm-themed messaging
# T034-T035: Create example outputs

# Test 7: Nudge message contains farm emoji 🚜
t034_nudge_message_emoji() {
  run get_nudge_message 0.4
  [ "$status" -eq 0 ] && [[ "$output" =~ 🚜 ]]
}

# Test 8: Nudge message is actionable
t034_nudge_message_actionable() {
  run get_nudge_message 0.4
  [ "$status" -eq 0 ] && ([[ "$output" =~ drift ]] || [[ "$output" =~ Drift ]])
}

# Test 9: Whisper message contains farm emoji 🐴
t035_whisper_message_emoji() {
  run get_whisper_message 0.7
  [ "$status" -eq 0 ] && [[ "$output" =~ 🐴 ]]
}

# Test 10: Whisper message is gentle
t035_whisper_message_gentle() {
  run get_whisper_message 0.7
  [ "$status" -eq 0 ] && [[ "$output" =~ [Gg]entle ]]
}

# Test 11: Green message (no nudge/whisper)
t033_green_message_no_farm_emoji() {
  run get_feedback_message 0.95
  [ "$status" -eq 0 ] && [[ ! "$output" =~ 🚜 ]] && [[ ! "$output" =~ 🐴 ]]
}

# Test 12: Threshold hardcoded in Phase 1 (not configurable)
t030_nudge_threshold_hardcoded() {
  export SPECFARM_NUDGE_THRESHOLD="0.3"
  run nudge_required 0.4
  [ "$status" -eq 0 ] && [ "$output" = "true" ]
}

echo "=== Unit Tests: Nudge Threshold ==="
_run_test "T033: nudge_required returns true when score equals 0.5 (50% drift)" t033_nudge_required_at_threshold
_run_test "T033: nudge_required returns true when score < 0.5 (drift > 50%)" t033_nudge_required_below_threshold
_run_test "T033: nudge_required returns false when score > 0.5" t033_nudge_not_required_above_threshold
_run_test "T033: whisper_required returns true when 0.5 < score < 0.9" t033_whisper_required_mid_range
_run_test "T033: whisper_required returns false when score <= 0.5 (nudge range)" t033_whisper_not_required_nudge_range
_run_test "T033: whisper_required returns false when score >= 0.9 (green range)" t033_whisper_not_required_green_range
_run_test "T034: nudge_message contains farm emoji 🚜" t034_nudge_message_emoji
_run_test "T034: nudge_message is readable and actionable" t034_nudge_message_actionable
_run_test "T035: whisper_message contains farm emoji 🐴" t035_whisper_message_emoji
_run_test "T035: whisper_message suggests gentle action" t035_whisper_message_gentle
_run_test "T033: green_message returns empty or positive when score > 0.9" t033_green_message_no_farm_emoji
_run_test "T030: nudge_threshold is hardcoded to 0.5" t030_nudge_threshold_hardcoded

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
