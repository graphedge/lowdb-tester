#!/bin/bash
# Unit test for SpecFarm markdown export
set -euo pipefail

# Setup
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
cd "$TEST_DIR"

# Mock bins and src
mkdir -p bin .specfarm
cp -r /storage/emulated/0/Download/github/specfarm/src .
cp /storage/emulated/0/Download/github/specfarm/bin/specfarm bin/
cp /storage/emulated/0/Download/github/specfarm/bin/drift-engine bin/
chmod +x bin/*

# Create mock rules.xml
cat <<EOF > .specfarm/rules.xml
<specfarm-rules version="1.0">
  <rule id="test-rule-1" global="true">
    <description>Description with | pipe</description>
    <signature type="keyword">KEYWORD1</signature>
  </rule>
  <rule id="scoped-rule" global="false" folder="only-this-folder">
    <description>Scoped rule</description>
    <signature type="keyword">SCOPED_KEYWORD</signature>
  </rule>
</specfarm-rules>
EOF

# 1. Test markdown output format
echo "Test 1: Markdown output format..."
OUTPUT=$(bash bin/specfarm drift --export markdown)

if echo "$OUTPUT" | grep -q "## SpecFarm Drift Report"; then
    echo "PASS: Markdown header found"
else
    echo "FAIL: Markdown header NOT found: $OUTPUT"
    exit 1
fi

if echo "$OUTPUT" | grep -q "| Rule ID | Score | Status | Description |"; then
    echo "PASS: Markdown table header found"
else
    echo "FAIL: Markdown table header NOT found"
    exit 1
fi

# Check escaping of pipes in description
if echo "$OUTPUT" | grep -q "Description with \| pipe"; then
    echo "PASS: Pipes escaped in description"
else
    echo "FAIL: Pipes NOT escaped in description: $OUTPUT"
    exit 1
fi

# 2. Test empty drift (no rules matching scope)
echo "Test 2: Empty drift..."
cat <<EOF > .specfarm/rules.xml
<specfarm-rules version="1.0">
  <rule id="scoped-rule" global="false" folder="only-this-folder">
    <description>Scoped rule</description>
    <signature type="keyword">SCOPED_KEYWORD</signature>
  </rule>
</specfarm-rules>
EOF
OUTPUT=$(bash bin/specfarm drift nonexistent-folder --export markdown)
if echo "$OUTPUT" | grep -q "_No rules found for this scope._"; then
    echo "PASS: Correct message for empty drift"
else
    echo "FAIL: Unexpected message for empty drift: $OUTPUT"
    exit 1
fi

# 3. Test nudge quiet
echo "Test 3: Nudge quiet..."
OUTPUT=$(bash bin/specfarm drift --nudge-quiet)
if echo "$OUTPUT" | grep -q "\[VIBE WHISPER\]"; then
    echo "FAIL: Vibe whisper NOT suppressed by --nudge-quiet: $OUTPUT"
    exit 1
else
    echo "PASS: Vibe whisper suppressed by --nudge-quiet"
fi

echo "All markdown export and drift flag tests PASSED"
