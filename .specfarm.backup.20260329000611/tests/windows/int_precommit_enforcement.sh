#!/bin/bash
# T055: Test that pre-commit enforcement rules are applied on Windows
# Phase 3b US5 — TDD

PASS=0; FAIL=0
_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
_fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

BASE="$(git rev-parse --show-toplevel 2>/dev/null)"

# T055.1: pre-commit-phase-guard.sh exists
GUARD="$BASE/.specify/scripts/bash/pre-commit-phase-guard.sh"
[[ -f "$GUARD" ]] && _pass "T055.1: pre-commit-phase-guard.sh exists" || _fail "T055.1: phase-guard missing"

# T055.2: phase-guard has T003 prompt-readonly check
grep -q "specify/prompts\|PROMPTS_DIR\|prompts-readonly" "$GUARD" 2>/dev/null \
  && _pass "T055.2: phase-guard has prompts-readonly check" \
  || _fail "T055.2: no prompts-readonly check"

# T055.3: phase-guard has T001 constitution-before-structure check
grep -q "constitution\|CONSTITUTION" "$GUARD" 2>/dev/null \
  && _pass "T055.3: phase-guard has constitution check" \
  || _fail "T055.3: no constitution check"

# T055.4: setup-hooks-windows.sh sets correct hook path
SETUP="$BASE/scripts/setup-hooks-windows.sh"
if [[ -f "$SETUP" ]]; then
  grep -q "specfarm-pre-commit\|pre-commit" "$SETUP" 2>/dev/null \
    && _pass "T055.4: setup script references hook" \
    || _fail "T055.4: setup script doesn't wire hook"
else
  _fail "T055.4: setup-hooks-windows.sh missing (T059 pending)"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
