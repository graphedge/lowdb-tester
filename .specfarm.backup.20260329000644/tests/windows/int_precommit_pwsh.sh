#!/bin/bash
# T053: Test pre-commit PowerShell path (via .ps1 wrapper or shell delegation)
# Phase 3b US5 — TDD

PASS=0; FAIL=0
_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
_fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

BASE="$(git rev-parse --show-toplevel 2>/dev/null)"

# T053.1: specfarm.ps1 exists and has pre-commit / validate functionality
PS1="$BASE/bin/specfarm.ps1"
[[ -f "$PS1" ]] && _pass "T053.1: specfarm.ps1 exists" || _fail "T053.1: specfarm.ps1 missing"

# T053.2: specfarm.ps1 references pre-commit or validate
grep -qi "precommit\|pre.commit\|validate\|drift" "$PS1" 2>/dev/null \
  && _pass "T053.2: PS1 has drift/validate logic" \
  || _fail "T053.2: specfarm.ps1 has no validation logic"

# T053.3: pre-commit-phase-guard.sh is sourced or referenced from PowerShell path
grep -q "pre-commit-phase-guard\|phase.guard" "$PS1" 2>/dev/null \
  && _pass "T053.3: phase-guard wired in PS1" \
  || _fail "T053.3: phase-guard not wired in PS1 (T058 pending)"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
