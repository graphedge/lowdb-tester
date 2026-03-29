#!/bin/bash
# Test T002: Migration Audit Trail Rule
# Validates that churn-migration-audit-trail rule exists and is properly formed in rules.xml

set -euo pipefail

PASS=0; FAIL=0
RULES_FILE="/home/brett/projects/specfarm/.specfarm/rules.xml"

pass() { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }

echo "Test T002: Migration Audit Trail Rule"
echo "======================================"

echo "  Test 2.1: Rule ID present..."
if grep -q 'id="churn-migration-audit-trail"' "$RULES_FILE"; then
    pass "Rule churn-migration-audit-trail present"
else
    fail "Rule churn-migration-audit-trail NOT found"
fi

echo "  Test 2.2: Exit code 42 registered..."
if grep -A25 'id="churn-migration-audit-trail"' "$RULES_FILE" | grep -q '<exit_code>42</exit_code>'; then
    pass "Exit code 42 registered"
else
    fail "Exit code 42 NOT found"
fi

echo "  Test 2.3: Action is fail-build..."
if grep -A15 'id="churn-migration-audit-trail"' "$RULES_FILE" | grep -q 'type="fail-build"'; then
    pass "Action is fail-build"
else
    fail "Action is not fail-build"
fi

echo "  Test 2.4: .bak pattern in condition..."
if grep -A10 'id="churn-migration-audit-trail"' "$RULES_FILE" | grep -q '\.bak'; then
    pass ".bak pattern present in condition"
else
    fail ".bak pattern NOT found in condition"
fi

echo "  Test 2.5: XML valid..."
if command -v xmllint &>/dev/null; then
    xmllint --noout "$RULES_FILE" 2>/dev/null && pass "XML valid" || fail "XML invalid"
else
    python3 -c "
import xml.etree.ElementTree as ET
try:
    ET.parse('$RULES_FILE')
    print('  ✅ PASS: XML valid (python3)')
except ET.ParseError as e:
    print(f'  ❌ FAIL: {e}')
    exit(1)
"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "✅ T002 Tests Passed" || { echo "❌ T002 Tests FAILED"; exit 1; }
