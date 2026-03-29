#!/bin/bash
# Test T001: Constitution-Before-Structure Rule
# Validates that churn-constitution-before-structure rule exists and is properly formed in rules.xml
# Zero-dependency: uses only bash, grep, xmllint

set -euo pipefail

PASS=0; FAIL=0
RULES_FILE="/home/brett/projects/specfarm/.specfarm/rules.xml"

pass() { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }

echo "Test T001: Constitution-Before-Structure Rule"
echo "============================================="

# Test 1.1: Rule exists in rules.xml
echo "  Test 1.1: Rule ID present..."
if grep -q 'id="churn-constitution-before-structure"' "$RULES_FILE"; then
    pass "Rule churn-constitution-before-structure present in rules.xml"
else
    fail "Rule churn-constitution-before-structure NOT found in rules.xml"
fi

# Test 1.2: Rule is enabled
echo "  Test 1.2: Rule enabled..."
if grep -A2 'id="churn-constitution-before-structure"' "$RULES_FILE" | grep -q 'enabled="true"'; then
    pass "Rule is enabled"
else
    fail "Rule is not enabled"
fi

# Test 1.3: Exit code 41 registered
echo "  Test 1.3: Exit code 41 registered..."
if grep -A20 'id="churn-constitution-before-structure"' "$RULES_FILE" | grep -q '<exit_code>41</exit_code>'; then
    pass "Exit code 41 registered"
else
    fail "Exit code 41 NOT found in rule metadata"
fi

# Test 1.4: Action is fail-build
echo "  Test 1.4: Action type is fail-build..."
if grep -A15 'id="churn-constitution-before-structure"' "$RULES_FILE" | grep -q 'type="fail-build"'; then
    pass "Action type is fail-build"
else
    fail "Action type is not fail-build"
fi

# Test 1.5: XML remains valid after rule addition
echo "  Test 1.5: XML syntax valid..."
if command -v xmllint &>/dev/null; then
    if xmllint --noout "$RULES_FILE" 2>/dev/null; then
        pass "XML syntax valid"
    else
        fail "XML syntax error after rule addition"
    fi
else
    python3 -c "
import xml.etree.ElementTree as ET
try:
    ET.parse('$RULES_FILE')
    print('  ✅ PASS: XML syntax valid (python3)')
except ET.ParseError as e:
    print(f'  ❌ FAIL: XML syntax error: {e}')
    exit(1)
"
fi

# Test 1.6: Rule has #dechurn tag
echo "  Test 1.6: Commit tag present..."
if grep -A25 'id="churn-constitution-before-structure"' "$RULES_FILE" | grep -q '#dechurn'; then
    pass "Commit tag #dechurn present"
else
    fail "#dechurn tag not found in rule metadata"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "✅ T001 Tests Passed" || { echo "❌ T001 Tests FAILED"; exit 1; }
