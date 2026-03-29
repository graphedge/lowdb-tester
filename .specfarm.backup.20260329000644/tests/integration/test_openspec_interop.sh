#!/bin/bash
# Integration test for SpecFarm OpenSpec interop
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
cp /storage/emulated/0/Download/github/specfarm/bin/process-shell-errors bin/ # needed for potential rule generation
chmod +x bin/*

# Check for xmlstarlet since openspec-mode requires it
if ! command -v xmlstarlet &> /dev/null; then
    echo "SKIP: xmlstarlet is not installed. Skipping OpenSpec interop tests."
    exit 0
fi

# Initial mock rules.xml (well-formed)
cat <<EOF > .specfarm/rules.xml
<specfarm-rules version="1.0">
  <rule id="standard-rule-1" certainty="0.9">
    <description>This is a standard rule.</description>
    <signature type="keyword">STANDARD_KEYWORD</signature>
  </rule>
  
  <rule id="openspec-soft-rule" certainty="0.3">
    <description>This is an OpenSpec soft rule.</description>
    <signature type="keyword">SOFT_KEYWORD</signature>
  </rule>

  <rule id="openspec-unknown-tag" certainty="0.5">
    <description>This rule has an unknown OpenSpec tag.</description>
    <signature type="keyword">UNKNOWN_TAG_KEYWORD</signature>
    <community-vote>10</community-vote> <!-- Unknown OpenSpec element -->
  </rule>
</specfarm-rules>
EOF

# Create files that contain the keywords for matching
echo "STANDARD_KEYWORD" > src/standard_keyword_file.txt
echo "SOFT_KEYWORD" > src/soft_keyword_file.txt
echo "UNKNOWN_TAG_KEYWORD" > src/unknown_tag_keyword_file.txt

# 1. Test unknown OpenSpec elements are ignored gracefully in OpenSpec mode
echo "Test 1: Handling unknown OpenSpec elements in OpenSpec mode..."

# Run drift without a filter_folder to process all rules
OUTPUT=$(bash .specfarm/bin/specfarm drift --export text --openspec-mode)

# Clean the output to make grep more robust against whitespace issues
CLEANED_OUTPUT=$(echo "$OUTPUT" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr -s ' ')

if echo "$CLEANED_OUTPUT" | grep -qF "Rule ID | Score | Status"; then # Basic check for table header
    echo "PASS: Drift engine (xmlstarlet) processed rules with unknown OpenSpec elements without crashing."
    # Check that all rules (which are matched but not justified) are marked as DRIFT (due to re-labeling logic)
    if echo "$CLEANED_OUTPUT" | grep -q "standard-rule-1.*DRIFT"; then
        echo "PASS: standard-rule-1 correctly marked as DRIFT."
    else
        echo "FAIL: standard-rule-1 not correctly marked as DRIFT."
        echo "Output: $OUTPUT"
        exit 1
    fi
else
    echo "FAIL: Drift engine (xmlstarlet) failed to process rules. Header not found."
    echo "Output: $OUTPUT"
    exit 1
fi

# 2. Test malformed XML handling in OpenSpec mode
echo "Test 2: Handling malformed XML in OpenSpec mode..."
# Re-create rules.xml with a clearly malformed section to test parsing robustness
cat <<EOF > .specfarm/rules.xml
<specfarm-rules version="1.0">
  <rule id="malformed-openspec-test" certainty="0.1">
    <description>This rule is intentionally malformed.</description>
    <signature type="keyword">MALFORMED_KEYWORD</signature>
    <community-vote>invalid xml
  </rule>
</specfarm-rules>
EOF

if ! OUTPUT=$(bash .specfarm/bin/specfarm drift --export text --openspec-mode 2>&1); then
    EXIT_CODE=1
else
    EXIT_CODE=0
fi

if [[ $EXIT_CODE -ne 0 ]] && echo "$OUTPUT" | grep -q "rules.xml is malformed"; then
    echo "PASS: Drift engine (xmlstarlet) reported error and exited non-zero for malformed rules.xml."
else
    echo "FAIL: Drift engine (xmlstarlet) did not report expected error or crashed for malformed rules.xml."
    echo "Test 2 EXIT_CODE: $EXIT_CODE"
    echo "Test 2 OUTPUT: $OUTPUT"
    exit 1
fi

echo "All OpenSpec interop tests PASSED"
