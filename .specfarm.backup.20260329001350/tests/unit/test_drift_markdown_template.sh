#!/bin/bash
# Unit test: verify markdown template rendering with sample drift data (T017)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$BASE_DIR/src/drift/export_markdown.sh"

PASS=0
FAIL=0

assert_pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
assert_fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# Sample drift output for template rendering tests
SAMPLE_DRIFT=$(cat <<'EOF'
SpecFarm Drift Report
Scope: payroll (+ global rules)

Rule ID                        | Score  | Status
-------------------------------|--------|----------
ARCH-001                       | 1.00   | PASS
TEST-002                       | 0.00   | DRIFT
SEC-003                        | 1.00   | JUSTIFIED
-------------------------------|--------|----------
TOTAL ADHERENCE: 67%
EOF
)

echo "Test 1: export_drift_markdown renders to stdout..."
OUTPUT=$(export_drift_markdown "$SAMPLE_DRIFT" "-")
if [[ -n "$OUTPUT" ]]; then
    assert_pass "export_drift_markdown produced output"
else
    assert_fail "export_drift_markdown produced empty output"
fi

echo "Test 2: output contains markdown heading..."
if echo "$OUTPUT" | grep -q "^# SpecFarm Drift Report"; then
    assert_pass "markdown heading present"
else
    assert_fail "markdown heading missing"
fi

echo "Test 3: output contains adherence percentage..."
if echo "$OUTPUT" | grep -q "67%"; then
    assert_pass "adherence percentage (67%) present in output"
else
    assert_fail "adherence percentage not found in output"
fi

echo "Test 4: output contains rule table..."
if echo "$OUTPUT" | grep -q "| Rule ID"; then
    assert_pass "rule table header present"
else
    assert_fail "rule table header missing"
fi

echo "Test 5: PASS rules show check mark icon..."
if echo "$OUTPUT" | grep -q "✅"; then
    assert_pass "check mark icon present for PASS rules"
else
    assert_fail "check mark icon missing for PASS rules"
fi

echo "Test 6: DRIFT rules show cross icon..."
if echo "$OUTPUT" | grep -q "❌"; then
    assert_pass "cross icon present for DRIFT rules"
else
    assert_fail "cross icon missing for DRIFT rules"
fi

echo "Test 7: JUSTIFIED rules show blue circle icon..."
if echo "$OUTPUT" | grep -q "🔵"; then
    assert_pass "blue circle icon present for JUSTIFIED rules"
else
    assert_fail "blue circle icon missing for JUSTIFIED rules"
fi

echo "Test 8: output contains timestamp..."
if echo "$OUTPUT" | grep -qE "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"; then
    assert_pass "ISO 8601 timestamp present in output"
else
    assert_fail "timestamp missing from output"
fi

echo "Test 9: dry-run mode writes to stdout not to file..."
REPORT_FILE="/tmp/test_drift_report_$$.md"
OUTPUT2=$(DRIFT_REPORT_DIR=/tmp export_drift_markdown "$SAMPLE_DRIFT" "-")
if [[ -n "$OUTPUT2" ]] && [[ ! -f "$REPORT_FILE" ]]; then
    assert_pass "dry-run (stdout) mode does not write a file"
else
    assert_fail "dry-run mode wrote unexpected file or had empty output"
    rm -f "$REPORT_FILE"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
