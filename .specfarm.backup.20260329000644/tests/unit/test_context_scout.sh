#!/bin/bash
# tests/unit/test_context_scout.sh
#
# Test suite for Context Scout (spec-env-brief.sh)
# Task T0440: Session environment briefing for agent handoff
#
# Validates JSON output schema with shell, OS, git status, rules count

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

# ---- Test: Script exits 0 and produces output ----
t0440_exits_zero() {
  local output
  output=$(bash "$REPO_ROOT/bin/spec-env-brief.sh" 2>&1)
  [ $? -eq 0 ] && [ -n "$output" ]
}

# ---- Test: Output is valid JSON ----
t0440_valid_json() {
  local output
  output=$(bash "$REPO_ROOT/bin/spec-env-brief.sh" 2>&1)
  echo "$output" | python3 -m json.tool >/dev/null 2>&1
}

# ---- Test: JSON contains required top-level keys ----
t0440_required_keys() {
  local output
  output=$(bash "$REPO_ROOT/bin/spec-env-brief.sh" 2>&1)
  local has_shell has_os has_git has_rules has_timestamp
  has_shell=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'shell' in d else 'no')")
  has_os=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'os' in d else 'no')")
  has_git=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'git' in d else 'no')")
  has_rules=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'rules' in d else 'no')")
  has_timestamp=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'timestamp' in d else 'no')")
  [[ "$has_shell" == "yes" && "$has_os" == "yes" && "$has_git" == "yes" && "$has_rules" == "yes" && "$has_timestamp" == "yes" ]]
}

# ---- Test: Shell field is non-empty string ----
t0440_shell_nonempty() {
  local output
  output=$(bash "$REPO_ROOT/bin/spec-env-brief.sh" 2>&1)
  local shell_val
  shell_val=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['shell'])")
  [ -n "$shell_val" ]
}

# ---- Test: OS field matches known platform ----
t0440_os_field() {
  local output
  output=$(bash "$REPO_ROOT/bin/spec-env-brief.sh" 2>&1)
  local os_val
  os_val=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['os'])")
  [[ "$os_val" =~ ^(linux|macos|windows-wsl|windows-mingw|unknown)$ ]]
}

# ---- Test: Git field contains branch key ----
t0440_git_branch() {
  local output
  output=$(bash "$REPO_ROOT/bin/spec-env-brief.sh" 2>&1)
  local has_branch
  has_branch=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'branch' in d.get('git',{}) else 'no')")
  [ "$has_branch" = "yes" ]
}

# ---- Test: Rules count is an integer >= 0 ----
t0440_rules_count() {
  local output
  output=$(bash "$REPO_ROOT/bin/spec-env-brief.sh" 2>&1)
  local count
  count=$(echo "$output" | python3 -c "import sys,json; print(json.load(sys.stdin)['rules']['count'])")
  [[ "$count" =~ ^[0-9]+$ ]]
}

# ---- Test: Error-memory section exists ----
t0440_error_memory_section() {
  local output
  output=$(bash "$REPO_ROOT/bin/spec-env-brief.sh" 2>&1)
  local has_errors
  has_errors=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print('yes' if 'error_memory' in d else 'no')")
  [ "$has_errors" = "yes" ]
}

echo "=== Unit Tests: Context Scout (T0440) ==="
_run_test "T0440: spec-env-brief.sh exits 0 and produces output" t0440_exits_zero
_run_test "T0440: output is valid JSON" t0440_valid_json
_run_test "T0440: JSON contains required keys (shell, os, git, rules, timestamp)" t0440_required_keys
_run_test "T0440: shell field is non-empty" t0440_shell_nonempty
_run_test "T0440: os field matches known platform" t0440_os_field
_run_test "T0440: git field contains branch key" t0440_git_branch
_run_test "T0440: rules count is integer >= 0" t0440_rules_count
_run_test "T0440: error_memory section exists" t0440_error_memory_section

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
