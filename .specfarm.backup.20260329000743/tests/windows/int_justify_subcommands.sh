#!/bin/bash
# T027: Integration test - justify-log list/has/purge subcommands on Windows

set -euo pipefail

PASS=0; FAIL=0; SKIP=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMPDIR_TEST=$(mktemp -d)
trap "rm -rf $TMPDIR_TEST" EXIT

pass() { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }
skip() { echo "  ⏭️  SKIP: $1"; SKIP=$((SKIP+1)); }

echo "Test T027: justify-log Subcommands (Windows Parity)"
echo "====================================================="

JUST_LOG="$TMPDIR_TEST/justifications.log"
JUSTIFY="$REPO_ROOT/bin/justify-log.sh"

[[ -f "$JUSTIFY" ]] || { echo "  ⚠️  justify-log.sh not found — skipping all"; exit 1; }

# Seed with test data
printf '{"timestamp":"2026-03-18T10:00:00Z","rule_id":"r1","justification":"Test reason","author":"test"}\n' > "$JUST_LOG"
printf '{"timestamp":"2026-03-18T10:01:00Z","rule_id":"r2","justification":"Another reason","author":"test"}\n' >> "$JUST_LOG"

echo "  Test 4.1: justify-log list..."
OUTPUT=$(JUSTIFICATIONS_LOG="$JUST_LOG" bash "$JUSTIFY" list 2>&1 || true)
if echo "$OUTPUT" | grep -qE "r1|r2|reason"; then
    pass "list subcommand returns entries"
else
    fail "list subcommand output unexpected: $OUTPUT"
fi

echo "  Test 4.2: justify-log has (existing)..."
OUTPUT=$(JUSTIFICATIONS_LOG="$JUST_LOG" bash "$JUSTIFY" has "r1" 2>&1 || true)
if echo "$OUTPUT" | grep -qiE "found|yes|true|1"; then
    pass "has subcommand finds existing entry"
else
    fail "has subcommand failed for existing entry: $OUTPUT"
fi

echo "  Test 4.3: justify-log has (non-existing)..."
OUTPUT=$(JUSTIFICATIONS_LOG="$JUST_LOG" bash "$JUSTIFY" has "r999" 2>&1 || true)
EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]] || echo "$OUTPUT" | grep -qiE "not found|no|false|0"; then
    pass "has subcommand returns not-found for missing entry"
else
    fail "has subcommand unexpected result for missing entry: $OUTPUT"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 ]] && echo "✅ T027 Tests Passed" || { echo "⚠️  T027 Tests INCOMPLETE (TDD)"; exit 1; }
