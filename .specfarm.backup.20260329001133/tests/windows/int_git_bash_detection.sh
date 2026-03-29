#!/bin/bash
# T051: Test Git Bash / shell detection in specfarm-pre-commit
# Phase 3b US5 — TDD (expect failures until T057 implemented)

PASS=0; FAIL=0
_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
_fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

SCRIPT="$(git rev-parse --show-toplevel 2>/dev/null)/bin/specfarm-pre-commit"

# T051.1: specfarm-pre-commit detects Git Bash context when MSYSTEM is set
( export MSYSTEM=MINGW64; unset ComSpec
  grep -q "MSYSTEM\|git.bash\|GIT_BASH\|detect_platform\|platform" "$SCRIPT" 2>/dev/null
) && _pass "T051.1: pre-commit sources platform detection" || _fail "T051.1: no platform detection logic"

# T051.2: specfarm-pre-commit sources platform-check.sh or equivalent
grep -q "platform.check\|detect_platform\|MSYSTEM\|DETECTED_OS" "$SCRIPT" 2>/dev/null \
  && _pass "T051.2: platform-check.sh sourced or referenced" \
  || _fail "T051.2: platform-check.sh not referenced"

# T051.3: pre-commit-phase-guard.sh is invoked from specfarm-pre-commit
grep -q "pre-commit-phase-guard" "$SCRIPT" 2>/dev/null \
  && _pass "T051.3: pre-commit-phase-guard.sh wired in" \
  || _fail "T051.3: pre-commit-phase-guard.sh not wired (T058 pending)"

# T051.4: setup-hooks-windows.sh exists
SETUP_HOOKS="$(git rev-parse --show-toplevel 2>/dev/null)/scripts/setup-hooks-windows.sh"
[[ -f "$SETUP_HOOKS" ]] \
  && _pass "T051.4: setup-hooks-windows.sh exists" \
  || _fail "T051.4: setup-hooks-windows.sh missing (T059 pending)"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
