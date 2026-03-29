#!/bin/bash
# T024: Unit test - justify-log.sh JSON Lines parsing on Windows-generated files
# TDD: Expected to FAIL until T029 implementation complete

set -euo pipefail

PASS=0; FAIL=0; SKIP=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
JUSTIFY_LOG="$REPO_ROOT/bin/justify-log.sh"
TMPDIR_TEST=$(mktemp -d)
trap "rm -rf $TMPDIR_TEST" EXIT

pass() { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }
skip() { echo "  ⏭️  SKIP: $1"; SKIP=$((SKIP+1)); }

echo "Test T024: justify-log.sh Windows JSON Lines Parsing"
echo "======================================================"

# Test 2.1: justify-log.sh exists
echo "  Test 2.1: justify-log.sh exists..."
if [[ -f "$JUSTIFY_LOG" ]]; then
    pass "justify-log.sh found at $JUSTIFY_LOG"
else
    fail "justify-log.sh not found at $JUSTIFY_LOG"
fi

# Test 2.2: Create CRLF JSON Lines fixture and verify parsing
echo "  Test 2.2: Parse CRLF-encoded JSON Lines..."
CRLF_LOG="$TMPDIR_TEST/justifications-crlf.log"
# Create CRLF-encoded log (Windows-style)
printf '{"timestamp":"2026-03-18T10:00:00Z","rule_id":"r1","justification":"Test reason 1","author":"user@test"}\r\n' > "$CRLF_LOG"
printf '{"timestamp":"2026-03-18T10:01:00Z","rule_id":"r2","justification":"Test reason 2","author":"user@test"}\r\n' >> "$CRLF_LOG"

# Verify CRLF exists in file
if file "$CRLF_LOG" | grep -q "CRLF" || cat "$CRLF_LOG" | od -c | grep -q '\\r'; then
    pass "CRLF fixture created successfully"
else
    skip "Could not verify CRLF (platform may not support it)"
fi

# Test 2.3: justify-log.sh should handle CRLF without errors
echo "  Test 2.3: justify-log.sh handles CRLF input..."
if [[ -f "$JUSTIFY_LOG" ]]; then
    if JUSTIFICATIONS_LOG="$CRLF_LOG" bash "$JUSTIFY_LOG" list 2>&1 | grep -qvE "^(binary|Error|error)"; then
        pass "justify-log.sh handles CRLF without binary file error"
    else
        fail "justify-log.sh fails on CRLF input (T029 implementation needed)"
    fi
else
    skip "justify-log.sh not found"
fi

# Test 2.4: Normalized output should contain expected entries
echo "  Test 2.4: Parsed entries contain expected data..."
LF_LOG="$TMPDIR_TEST/justifications-lf.log"
# Create LF-encoded equivalent
printf '{"timestamp":"2026-03-18T10:00:00Z","rule_id":"r1","justification":"Test reason 1","author":"user@test"}\n' > "$LF_LOG"

if [[ -f "$JUSTIFY_LOG" ]]; then
    OUTPUT=$(JUSTIFICATIONS_LOG="$LF_LOG" bash "$JUSTIFY_LOG" list 2>&1 || true)
    if echo "$OUTPUT" | grep -q "r1"; then
        pass "Parsed entry contains rule_id r1"
    else
        fail "Parsed entry does not contain expected rule_id (got: $OUTPUT)"
    fi
else
    skip "justify-log.sh not found"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 ]] && echo "✅ T024 Tests Passed" || { echo "⚠️  T024 Tests INCOMPLETE (expected — TDD)"; exit 1; }
