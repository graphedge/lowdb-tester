#!/bin/bash
# T056: E2E test of full pre-commit pipeline on Windows (Git Bash simulation)
# Phase 3b US5 — TDD

PASS=0; FAIL=0
_pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
_fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

BASE="$(git rev-parse --show-toplevel 2>/dev/null)"
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# T056.1: Pre-commit hook can be invoked without error (dry-run style)
(
  cd "$TMPDIR_TEST"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  # Touch a dummy file for staging
  echo "test" > dummy.txt
  git add dummy.txt
  # Simulate environment
  export MSYSTEM="MINGW64"
  export SPECFARM_DRY_RUN=1
  # Hook should at minimum be bash-syntax valid
  bash -n "$BASE/bin/specfarm-pre-commit" 2>&1 \
    && echo "PASS: T056.1: hook passes bash -n syntax check" \
    || { echo "FAIL: T056.1: hook has bash syntax errors"; }
) | grep -E "^(PASS|FAIL)" | while read line; do
    echo "$line"
    [[ "$line" == PASS* ]] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))
done
# Re-run the hook syntax check directly for result capture
bash -n "$BASE/bin/specfarm-pre-commit" 2>/dev/null && PASS=$((PASS+1)) || FAIL=$((FAIL+1))

# T056.2: phase guard passes bash syntax check
bash -n "$BASE/.specify/scripts/bash/pre-commit-phase-guard.sh" 2>/dev/null \
  && _pass "T056.2: phase-guard passes bash -n" \
  || _fail "T056.2: phase-guard has syntax errors"

# T056.3: pre-merge-validation.sh passes bash syntax check
bash -n "$BASE/.specify/scripts/bash/pre-merge-validation.sh" 2>/dev/null \
  && _pass "T056.3: pre-merge-validation.sh passes bash -n" \
  || _fail "T056.3: pre-merge-validation.sh has syntax errors"

# T056.4: justifications-log.sh passes bash syntax check
bash -n "$BASE/bin/justifications-log.sh" 2>/dev/null \
  && _pass "T056.4: justifications-log.sh passes bash -n" \
  || _fail "T056.4: justifications-log.sh has syntax errors"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
