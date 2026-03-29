#!/bin/bash
# Integration test for SpecFarm Justifications Audit Trail integrity
set -euo pipefail

# Setup
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
cd "$TEST_DIR"

# Mock bins and src
mkdir -p bin .specfarm
cp -r /storage/emulated/0/Download/github/specfarm/src .
cp /storage/emulated/0/Download/github/specfarm/.specfarm/bin/specfarm bin/
cp /storage/emulated/0/Download/github/specfarm/.specfarm/bin/drift-engine bin/
cp /storage/emulated/0/Download/github/specfarm/bin/process-shell-errors bin/
cp /storage/emulated/0/Download/github/specfarm/bin/log-shell-error bin/
chmod +x bin/*

# Initialize SpecFarm environment
bash .specfarm/bin/specfarm onboard
cat <<EOF > .specfarm/rules.xml
<specfarm-rules version="1.0">
  <rule id="rule-to-justify-1" global="true">
    <description>Rule for justification audit test</description>
    <signature type="keyword">JUSTIFY_ME</signature>
  </rule>
</specfarm-rules>
EOF
> .specfarm/justifications.log # Ensure justifications log is clean

# --- Test Scenario: Justifications Audit Trail Integrity ---

# 1. Test adding justifications
echo "Test 1: Adding justifications..."
bash .specfarm/bin/specfarm justify rule-to-justify-1 "Reason 1 for justification"

# Check if log has correct format (timestamp, rule, reason, commit)
# The log format is [timestamp] RULE="..." JUSTIFICATION="..." COMMIT="..."
# In test env, commit is "no-git"
if ! grep -q "RULE=\"rule-to-justify-1\" JUSTIFICATION=\"Reason 1 for justification\" COMMIT=\"no-git\"" .specfarm/justifications.log; then
    echo "FAIL: Justification for rule-to-justify-1 not logged correctly."
    cat .specfarm/justifications.log
    exit 1
fi
echo "PASS: First justification logged."

# 2. Test listing justifications (audit)
echo "Test 2: Listing justifications..."
OUTPUT=$(bash .specfarm/bin/specfarm audit)

if echo "$OUTPUT" | grep -q "rule-to-justify-1"; then
    echo "PASS: Listing justifications shows added entry."
else
    echo "FAIL: Listing justifications did not show rule-to-justify-1."
    echo "Output: $OUTPUT"
    exit 1
fi

# 3. Test drift check uses justifications
echo "Test 3: Drift check recognizes justification..."
# Create a file that matches JUSTIFY_ME
echo "JUSTIFY_ME" > src/match.txt

# Run drift. It should show JUSTIFIED.
OUTPUT=$(bash .specfarm/bin/specfarm drift --export text)

if echo "$OUTPUT" | grep -q "rule-to-justify-1.*JUSTIFIED"; then
    echo "PASS: Drift check correctly identified justified rule."
else
    echo "FAIL: Drift check did not identify justified rule."
    echo "Output: $OUTPUT"
    exit 1
fi

echo "All justifications audit trail tests PASSED"
