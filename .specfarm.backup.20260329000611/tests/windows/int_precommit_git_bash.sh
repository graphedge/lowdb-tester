#!/bin/bash
# T052: Test pre-commit runs correctly in Git Bash context
# Phase 3b US5 — TDD

PASS=0; FAIL=0
_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
_fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

BASE="$(git rev-parse --show-toplevel 2>/dev/null)"
HOOK="$BASE/bin/specfarm-pre-commit"

# T052.1: pre-commit hook is executable
[[ -x "$HOOK" ]] && _pass "T052.1: hook is executable" || _fail "T052.1: hook not executable"

# T052.2: hook has bash shebang (Git Bash compatible)
head -1 "$HOOK" | grep -q "bash" \
  && _pass "T052.2: bash shebang present" \
  || _fail "T052.2: missing bash shebang"

# T052.3: hook exports or returns DETECTED_OS
grep -q "DETECTED_OS\|detect_platform\|_PLATFORM" "$HOOK" 2>/dev/null \
  && _pass "T052.3: platform variable used" \
  || _fail "T052.3: no platform variable (T057 pending)"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
