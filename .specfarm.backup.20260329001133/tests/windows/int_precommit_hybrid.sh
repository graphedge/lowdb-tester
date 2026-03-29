#!/bin/bash
# T054: Test pre-commit hybrid mode (bash + PS coexistence)
# Phase 3b US5 — TDD

PASS=0; FAIL=0
_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
_fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

BASE="$(git rev-parse --show-toplevel 2>/dev/null)"
HOOK="$BASE/bin/specfarm-pre-commit"

# T054.1: hook handles missing platform-check.sh gracefully
grep -q "\-f.*platform.check\|source.*platform" "$HOOK" 2>/dev/null \
  && _pass "T054.1: graceful source of platform-check.sh" \
  || _fail "T054.1: no graceful platform-check handling"

# T054.2: phase guard script fails gracefully if not present
grep -q "\-f.*pre-commit-phase-guard\|source.*phase.guard" "$HOOK" 2>/dev/null \
  && _pass "T054.2: phase-guard sourced conditionally" \
  || _fail "T054.2: phase-guard not sourced conditionally (T058 pending)"

# T054.3: pre-commit hook does not hardcode Unix paths with /home/ or /usr/
grep -q "/home/\|/usr/local/" "$HOOK" 2>/dev/null \
  && _fail "T054.3: hardcoded Unix paths found" \
  || _pass "T054.3: no hardcoded Unix home/usr paths"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
