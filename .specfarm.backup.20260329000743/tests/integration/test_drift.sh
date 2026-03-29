#!/bin/bash
# Test: specfarm drift
set -euo pipefail

# Setup
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

cp -r . "$TEST_DIR"
cd "$TEST_DIR"
chmod +x .specfarm/bin/specfarm

# Create a clean test environment with specific rules
mkdir -p .specfarm
echo "Phase 1" > .specfarm/phase

cat <<EOF > .specfarm/rules.xml
<specfarm-rules version="1.0">
  <rule id="architecture" global="true">
    <description>CLI only</description>
    <signature type="keyword">UNIQUE_KEYWORD_ARCH_123</signature>
  </rule>
  <rule id="testing" global="true">
    <description>Test mandatory</description>
    <signature type="keyword">UNIQUE_KEYWORD_TEST_456</signature>
  </rule>
  <rule id="code-quality" global="true">
    <description>Convention check</description>
    <signature type="keyword">UNIQUE_KEYWORD_QUAL_789</signature>
  </rule>
  <rule id="security" global="true">
    <description>Privilege least</description>
    <signature type="keyword">UNIQUE_KEYWORD_SEC_012</signature>
  </rule>
  <rule id="performance" global="true">
    <description>Optimize now</description>
    <signature type="keyword">UNIQUE_KEYWORD_PERF_345</signature>
  </rule>
</specfarm-rules>
EOF

rm -f .specfarm/justifications.log

# 1. Test drift score with no keywords (DRIFT)
echo "Test 1: Drift with no keywords..."
OUTPUT=$(bash .specfarm/bin/specfarm drift)
if echo "$OUTPUT" | grep -q "TOTAL ADHERENCE: 0%"; then
  echo "PASS"
else
  echo "FAIL: Expected 0% adherence, got: $OUTPUT"
  exit 1
fi

# 2. Test drift score with keywords (PASS)
echo "Test 2: Drift with keywords..."
mkdir -p src
echo "This is a test with UNIQUE_KEYWORD_ARCH_123 and UNIQUE_KEYWORD_PERF_345" > src/app.sh
OUTPUT=$(bash .specfarm/bin/specfarm drift)
# keywords 'UNIQUE_KEYWORD_ARCH_123' and 'UNIQUE_KEYWORD_PERF_345' are present (2/5 = 40%)
if echo "$OUTPUT" | grep -q "TOTAL ADHERENCE: 40%"; then
  echo "PASS"
else
  echo "FAIL: Expected 40% adherence, got: $OUTPUT"
  exit 1
fi

# 3. Test justification (JUSTIFIED)
echo "Test 3: Justification..."
bash .specfarm/bin/specfarm justify testing "Testing deferred to Phase 1B"
OUTPUT=$(bash .specfarm/bin/specfarm drift)
# architecture:found, testing:JUSTIFIED, code-quality:drift, security:drift, performance:found
# (2/5 found, 1/5 justified -> 3/5 = 60%)
if echo "$OUTPUT" | grep -q "TOTAL ADHERENCE: 60%"; then
  echo "PASS"
else
  echo "FAIL: Expected 60% adherence, got: $OUTPUT"
  exit 1
fi
