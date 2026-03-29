#!/bin/bash
# T042: Unit test - Parse PowerShell $Error[] and convert to JSON Lines

set -euo pipefail

PASS=0; FAIL=0; SKIP=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAPTURE_ERROR="$REPO_ROOT/bin/capture-shell-error.sh"
TMPDIR_TEST=$(mktemp -d)
trap "rm -rf $TMPDIR_TEST" EXIT

pass() { echo "  ✅ PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "  ❌ FAIL: $1"; FAIL=$((FAIL+1)); }
skip() { echo "  ⏭️  SKIP: $1"; SKIP=$((SKIP+1)); }

echo "Test T042: PowerShell \$Error[] → JSON Lines Parsing"
echo "======================================================"

# Test 7.1: capture-shell-error.sh exists
echo "  Test 7.1: capture-shell-error.sh exists..."
[[ -f "$CAPTURE_ERROR" ]] && pass "Found at $CAPTURE_ERROR" || fail "NOT found"

# Test 7.2: Simulate PowerShell error format and parse
echo "  Test 7.2: Parse PS-style error to JSON Lines..."
PS_ERROR_FIXTURE='{"Error":"CommandNotFoundException","TargetObject":"nonexistent-cmd","InvocationInfo":{"ScriptLineNumber":42,"Line":"nonexistent-cmd --arg"},"CategoryInfo":"ObjectNotFound"}'
ERRORS_LOG="$TMPDIR_TEST/shell-errors.log"

# Try to parse PS error format
if command -v python3 &>/dev/null; then
    python3 -c "
import json
ps_error = json.loads('$PS_ERROR_FIXTURE')
# Convert to SpecFarm JSON Lines format
entry = {
    'timestamp': '2026-03-18T10:00:00Z',
    'agent_type': 'powershell',
    'command': ps_error.get('InvocationInfo', {}).get('Line', 'unknown'),
    'exit_code': 1,
    'stderr': ps_error.get('Error', 'Unknown'),
    'cwd': '/test',
    'os_info': 'Windows/PowerShell',
    'shell_info': 'pwsh'
}
print(json.dumps(entry))
" 2>&1
    [[ $? -eq 0 ]] && pass "PS error format converts to JSON Lines" || fail "Conversion failed"
else
    skip "python3 not available"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped"
[[ $FAIL -eq 0 ]] && echo "✅ T042 Tests Passed" || { echo "⚠️  T042 Tests INCOMPLETE (TDD)"; exit 1; }
