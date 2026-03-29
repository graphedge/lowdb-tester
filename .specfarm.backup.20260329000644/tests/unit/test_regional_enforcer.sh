#!/bin/bash
# tests/unit/test_regional_enforcer.sh
#
# Test suite for RegionalEnforcer command adaptation
# Task T0441: Validate OS/shell/agent command adaptation strategies
#
# Tests that commands are properly adapted for different OS/shell combos

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

source "$REPO_ROOT/src/regional/enforcer.sh"

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

# ---- Test: Default strategy returns command unchanged ----
t0441_default_passthrough() {
  local result
  result=$(adapt_command "npm run build" "unknown-agent" "linux" "bash")
  local cmd
  cmd=$(echo "$result" | grep '"adapted_command"' | head -1)
  [[ "$cmd" == *"npm run build"* ]]
}

# ---- Test: Cline+zsh wraps with script for output capture ----
t0441_cline_zsh_wrapping() {
  local result
  result=$(adapt_command "npm run build" "Cline" "linux" "zsh")
  [[ "$result" == *"strip_ansi"* ]] && [[ "$result" == *"true"* ]]
}

# ---- Test: PowerShell adaptation uses pwsh ----
t0441_powershell_adaptation() {
  local result
  result=$(adapt_command "npm run build" "generic" "windows-mingw" "powershell")
  [[ "$result" == *"powershell"* ]] || [[ "$result" == *"pwsh"* ]]
}

# ---- Test: Output is valid JSON ----
t0441_valid_json() {
  local result
  result=$(adapt_command "npm test" "Cline" "linux" "bash")
  echo "$result" | python3 -m json.tool >/dev/null 2>&1
}

# ---- Test: Strategy field is present ----
t0441_has_strategy() {
  local result
  result=$(adapt_command "npm test" "Cline" "linux" "bash")
  local has_strategy
  has_strategy=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'strategy' in d else 'no')")
  [ "$has_strategy" = "yes" ]
}

# ---- Test: Timeout is respected ----
t0441_timeout_present() {
  local result
  result=$(adapt_command "make build" "generic" "linux" "bash" 60)
  local timeout
  timeout=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin)['strategy']['timeout'])")
  [ "$timeout" = "60s" ]
}

# ---- Test: Empty command returns error ----
t0441_empty_command_error() {
  local result
  result=$(adapt_command "" "Cline" "linux" "bash")
  [[ "$result" == *"error"* ]] || [[ "$result" == *"ERROR"* ]]
}

# ---- Test: Adapted command for macOS ----
t0441_macos_adaptation() {
  local result
  result=$(adapt_command "npm run build" "generic" "macos" "zsh")
  echo "$result" | python3 -m json.tool >/dev/null 2>&1
}

echo "=== Unit Tests: RegionalEnforcer (T0441) ==="
_run_test "T0441: default strategy passes command through" t0441_default_passthrough
_run_test "T0441: Cline+zsh strips ANSI" t0441_cline_zsh_wrapping
_run_test "T0441: PowerShell adaptation detected" t0441_powershell_adaptation
_run_test "T0441: output is valid JSON" t0441_valid_json
_run_test "T0441: strategy field present" t0441_has_strategy
_run_test "T0441: timeout respected" t0441_timeout_present
_run_test "T0441: empty command returns error" t0441_empty_command_error
_run_test "T0441: macOS adaptation produces valid JSON" t0441_macos_adaptation

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
