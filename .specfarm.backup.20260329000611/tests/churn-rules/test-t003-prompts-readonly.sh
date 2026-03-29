#!/bin/bash
# Test T003: Prompts Read-Only Rule
# Validates that churn-prompts-readonly-unless-invoked rule exists in rules.xml

set -euo pipefail

PASS=0; FAIL=0
RULES_FILE="/home/brett/projects/specfarm/.specfarm/rules.xml"

pass() { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }

echo "Test T003: Prompts Read-Only Rule"
echo "=================================="

echo "  Test 3.1: Rule ID present..."
if grep -q 'id="churn-prompts-readonly-unless-invoked"' "$RULES_FILE"; then
    pass "Rule churn-prompts-readonly-unless-invoked present"
else
    fail "Rule NOT found"
fi

echo "  Test 3.2: Exit code 43 registered..."
if grep -A20 'id="churn-prompts-readonly-unless-invoked"' "$RULES_FILE" | grep -q '<exit_code>43</exit_code>'; then
    pass "Exit code 43 registered"
else
    fail "Exit code 43 NOT found"
fi

echo "  Test 3.3: specs/prompts/ in scope..."
if grep -A15 'id="churn-prompts-readonly-unless-invoked"' "$RULES_FILE" | grep -q '\specs/prompts/'; then
    pass "specs/prompts/ scope defined"
else
    fail "specs/prompts/ scope NOT found"
fi

echo "  Test 3.4: Action is fail-build..."
if grep -A15 'id="churn-prompts-readonly-unless-invoked"' "$RULES_FILE" | grep -q 'type="fail-build"'; then
    pass "Action is fail-build"
else
    fail "Action is not fail-build"
fi

echo "  Test 3.5: XML valid..."
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

echo "  Test 3.6: Owner archiving allowed (description mentions 'archive')..."
if grep -A5 'id="churn-prompts-readonly-unless-invoked"' "$RULES_FILE" | grep -q "archive"; then
    pass "Owner archiving exception present in rule description"
else
    fail "Owner archiving exception NOT found — rule should allow 'archive prompt' commits"
fi

echo "  Test 3.7: pre-commit-phase-guard.sh covers archive invocation..."
GUARD=".specify/scripts/bash/pre-commit-phase-guard.sh"
if [[ -f "$GUARD" ]]; then
    if grep -q "archive prompt\|archiving prompt\|owner-approved" "$GUARD"; then
        pass "Guard script includes archive/owner-approved invocation checks"
    else
        fail "Guard script missing archive/owner-approved check"
    fi
else
    fail "pre-commit-phase-guard.sh not found"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "✅ T003 Tests Passed" || { echo "❌ T003 Tests FAILED"; exit 1; }
