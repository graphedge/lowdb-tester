#!/bin/bash
# tests/unit/test_vibe_tone.sh
#
# Test suite for Vibe/Tone mapping
# Task T0444: Validate all 7 vibes produce correct output patterns
#
# Tests that each vibe (strict, chill, corporate, playful, sarcastic, farm, jungle, plain)
# produces expected tone for all adherence levels (low, medium, perfect)

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

source "$REPO_ROOT/src/vibe/templates.sh"

PASS=0
FAIL=0

_run_test() {
  local name="$1"
  local func="$2"
  if "$func"; then
    echo "PASS: $name"
    PASS=$((PASS+1))
  else
    echo "FAIL: $name"
    FAIL=$((FAIL+1))
  fi
}

# ---- Farm vibe tests ----
t0444_farm_low() {
  local msg
  msg=$(get_nudge "farm" 60)
  [[ "$msg" == *"Grumpy Farmer"* ]] || [[ "$msg" == *"weeds"* ]]
}

t0444_farm_mid() {
  local msg
  msg=$(get_nudge "farm" 90)
  [[ "$msg" == *"Encouraging Farmer"* ]] || [[ "$msg" == *"thrive"* ]]
}

t0444_farm_perfect() {
  local msg
  msg=$(get_nudge "farm" 100)
  [[ "$msg" == *"Happy Farmer"* ]] || [[ "$msg" == *"bountiful"* ]]
}

# ---- Jungle vibe tests ----
t0444_jungle_low() {
  local msg
  msg=$(get_nudge "jungle" 60)
  [[ "$msg" == *"Jaguar"* ]] || [[ "$msg" == *"vines"* ]]
}

t0444_jungle_mid() {
  local msg
  msg=$(get_nudge "jungle" 90)
  [[ "$msg" == *"Monkey"* ]] || [[ "$msg" == *"climbing"* ]]
}

t0444_jungle_perfect() {
  local msg
  msg=$(get_nudge "jungle" 100)
  [[ "$msg" == *"Lion"* ]] || [[ "$msg" == *"king"* ]]
}

# ---- Strict vibe tests ----
t0444_strict_low() {
  local msg
  msg=$(get_nudge "strict" 60)
  [[ "$msg" == *"ERROR"* ]]
}

t0444_strict_mid() {
  local msg
  msg=$(get_nudge "strict" 90)
  [[ "$msg" == *"WARNING"* ]]
}

t0444_strict_perfect() {
  local msg
  msg=$(get_nudge "strict" 100)
  [[ "$msg" == *"PASS"* ]]
}

# ---- Chill vibe tests ----
t0444_chill_low() {
  local msg
  msg=$(get_nudge "chill" 60)
  [[ "$msg" == *"together"* ]] || [[ "$msg" == *"Hey"* ]]
}

t0444_chill_mid() {
  local msg
  msg=$(get_nudge "chill" 90)
  [[ "$msg" == *"Almost"* ]] || [[ "$msg" == *"tidy"* ]]
}

t0444_chill_perfect() {
  local msg
  msg=$(get_nudge "chill" 100)
  [[ "$msg" == *"Great"* ]] || [[ "$msg" == *"perfectly"* ]]
}

# ---- Corporate vibe tests ----
t0444_corporate_low() {
  local msg
  msg=$(get_nudge "corporate" 60)
  [[ "$msg" == *"ACTION REQUIRED"* ]]
}

t0444_corporate_mid() {
  local msg
  msg=$(get_nudge "corporate" 90)
  [[ "$msg" == *"ADVISORY"* ]]
}

t0444_corporate_perfect() {
  local msg
  msg=$(get_nudge "corporate" 100)
  [[ "$msg" == *"COMPLIANCE VERIFIED"* ]]
}

# ---- Sarcastic vibe tests ----
t0444_sarcastic_low() {
  local msg
  msg=$(get_nudge "sarcastic" 60)
  [[ "$msg" == *"wonderful"* ]] || [[ "$msg" == *"expected"* ]]
}

t0444_sarcastic_mid() {
  local msg
  msg=$(get_nudge "sarcastic" 90)
  [[ "$msg" == *"Shockingly"* ]] || [[ "$msg" == *"close"* ]]
}

t0444_sarcastic_perfect() {
  local msg
  msg=$(get_nudge "sarcastic" 100)
  [[ "$msg" == *"Impressive"* ]] || [[ "$msg" == *"compliant"* ]]
}

# ---- Cross-vibe consistency tests ----
t0444_all_vibes_produce_output() {
  local vibes=("farm" "jungle" "strict" "chill" "corporate" "sarcastic" "plain")
  local levels=(60 90 100)
  for v in "${vibes[@]}"; do
    for l in "${levels[@]}"; do
      local msg
      msg=$(get_nudge "$v" "$l")
      if [[ -z "$msg" ]]; then
        echo "  Empty output for vibe=$v adherence=$l" >&2
        return 1
      fi
    done
  done
  return 0
}

t0444_vibes_differ() {
  local farm_msg jungle_msg
  farm_msg=$(get_nudge "farm" 60)
  jungle_msg=$(get_nudge "jungle" 60)
  [[ "$farm_msg" != "$jungle_msg" ]]
}

echo "=== Unit Tests: Vibe/Tone Mapping (T0444) ==="
_run_test "T0444: farm vibe low adherence" t0444_farm_low
_run_test "T0444: farm vibe mid adherence" t0444_farm_mid
_run_test "T0444: farm vibe perfect adherence" t0444_farm_perfect
_run_test "T0444: jungle vibe low adherence" t0444_jungle_low
_run_test "T0444: jungle vibe mid adherence" t0444_jungle_mid
_run_test "T0444: jungle vibe perfect adherence" t0444_jungle_perfect
_run_test "T0444: strict vibe low adherence" t0444_strict_low
_run_test "T0444: strict vibe mid adherence" t0444_strict_mid
_run_test "T0444: strict vibe perfect adherence" t0444_strict_perfect
_run_test "T0444: chill vibe low adherence" t0444_chill_low
_run_test "T0444: chill vibe mid adherence" t0444_chill_mid
_run_test "T0444: chill vibe perfect adherence" t0444_chill_perfect
_run_test "T0444: corporate vibe low adherence" t0444_corporate_low
_run_test "T0444: corporate vibe mid adherence" t0444_corporate_mid
_run_test "T0444: corporate vibe perfect adherence" t0444_corporate_perfect
_run_test "T0444: sarcastic vibe low adherence" t0444_sarcastic_low
_run_test "T0444: sarcastic vibe mid adherence" t0444_sarcastic_mid
_run_test "T0444: sarcastic vibe perfect adherence" t0444_sarcastic_perfect
_run_test "T0444: all vibes produce non-empty output at all levels" t0444_all_vibes_produce_output
_run_test "T0444: different vibes produce different messages" t0444_vibes_differ

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
