#!/bin/bash
# Unit test for SpecFarm CI verification
set -euo pipefail

# Setup
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
cd "$TEST_DIR"

# Mock bins and src
mkdir -p bin .specfarm
cp -r "$REPO_ROOT/src" .
cp "$REPO_ROOT/bin/specfarm" bin/
cp "$REPO_ROOT/bin/drift-engine" bin/
cp "$REPO_ROOT/bin/process-shell-errors" bin/
cp "$REPO_ROOT/bin/log-shell-error" bin/
chmod +x bin/*

# Initialize SpecFarm environment
bash bin/specfarm onboard
cat <<EOF > .specfarm/rules.xml
<specfarm-rules version="1.0">
  <rule id="ci-test-rule" global="true">
    <description>Rule for CI verification test</description>
    <signature type="keyword">CI_TEST_KEYWORD</signature>
  </rule>
</specfarm-rules>
EOF

# 1. Test CI behavior for non-compliance and compliance
echo "Test 1: CI behavior for non-compliance and compliance..."
# Create a file that violates a rule
echo "This file contains CI_TEST_KEYWORD but should not." > src/violating_file.sh
chmod +x src/violating_file.sh

# Ensure the rule is not justified initially
bash bin/specfarm audit purge ci-test-rule 2>/dev/null || true # Ignore errors if no justifications exist

# Run drift. It should report non-compliance (status DRIFT) and low adherence.
OUTPUT=$(bash bin/specfarm drift --export text)

# Check if ci-test-rule shows as DRIFT and adherence is not 100%
if echo "$OUTPUT" | grep -q "ci-test-rule.*DRIFT"; then
    echo "PASS: 'specfarm drift' correctly reports DRIFT status for unjustified rule."
else
    echo "FAIL: 'specfarm drift' did not report DRIFT status correctly for unjustified rule."
    echo "Output: $OUTPUT"
    exit 1
fi

if echo "$OUTPUT" | grep -q "TOTAL ADHERENCE: 0%"; then # Assuming default is 0% if DRIFT
    echo "PASS: TOTAL ADHERENCE is low due to unjustified drift."
else
    echo "FAIL: TOTAL ADHERENCE is not as expected for unjustified drift."
    echo "Output: $OUTPUT"
    exit 1
fi

# 2. Test CI behavior with justified drift
echo "Test 2: CI behavior with justified drift..."
# Justify the rule that was violated
bash bin/specfarm justify ci-test-rule "Temporarily allowed for CI test."

# Run drift again. This time, it should report as JUSTIFIED and adherence should be 100%.
OUTPUT=$(bash bin/specfarm drift --export text)

if echo "$OUTPUT" | grep -q "ci-test-rule.*JUSTIFIED"; then
    echo "PASS: 'specfarm drift' reports JUSTIFIED status after justification."
else
    echo "FAIL: 'specfarm drift' did not report JUSTIFIED status correctly after justification."
    echo "Output: $OUTPUT"
    exit 1
fi

if echo "$OUTPUT" | grep -q "TOTAL ADHERENCE: 100%"; then
    echo "PASS: TOTAL ADHERENCE is 100% after justification."
else
    echo "FAIL: TOTAL ADHERENCE is not 100% after justification."
    echo "Output: $OUTPUT"
    exit 1
fi

# 3. Golden file pattern check (simulated)
# This is a simulation. A true golden file test would compare against a stored file.
# Here, we check for a specific output pattern in markdown export.
echo "Test 3: Golden file pattern check (markdown export)..."
mkdir -p src/golden_test
echo "This file should be included in markdown output." > src/golden_test/markdown_content.txt

OUTPUT=$(bash bin/specfarm drift --export markdown)

# Check for specific markdown table structure and content
if echo "$OUTPUT" | grep -q "| ci-test-rule | 1.00 | JUSTIFIED |"; then
    echo "PASS: Markdown export contains expected justified rule data."
else
    echo "FAIL: Markdown export does not contain expected justified rule data."
    echo "Output: $OUTPUT"
    exit 1
fi

echo "All CI verification tests PASSED"
