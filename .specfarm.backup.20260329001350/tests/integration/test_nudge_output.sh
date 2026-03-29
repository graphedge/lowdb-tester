#!/bin/bash
# Integration test: run drift engine against sample repo and verify nudge output (T010)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

cp -r "$BASE_DIR/." "$TEST_DIR/"
cd "$TEST_DIR"
chmod +x bin/drift-engine bin/specfarm

mkdir -p .specfarm src

# Setup: config with nudge enabled (non-plain vibe)
cat <<EOF > .specfarm/config
VIBE="farm"
PHASE_MODE="loose"
DRIFT_THRESHOLD=5
NUDGE_QUIET="false"
EOF

# Create a rules.xml with a known rule that will drift
cat <<EOF > .specfarm/rules.xml
<specfarm-rules version="1.0">
  <rule id="TEST-NUDGE-01" global="true">
    <description>Test nudge rule</description>
    <signature type="keyword">UNIQUE_NUDGE_KEYWORD_XYZ_987</signature>
  </rule>
</specfarm-rules>
EOF

rm -f .specfarm/justifications.log

echo "Test 1: drift engine runs successfully..."
OUTPUT=$(bash bin/drift-engine 2>&1)
if echo "$OUTPUT" | grep -q "SpecFarm Drift Report"; then
    echo "PASS: drift engine produced output"
else
    echo "FAIL: drift engine did not produce expected output"
    echo "Got: $OUTPUT"
    exit 1
fi

echo "Test 2: drifting rule shows DRIFT status..."
if echo "$OUTPUT" | grep -q "DRIFT"; then
    echo "PASS: DRIFT status found in output"
else
    echo "FAIL: DRIFT status not found in output"
    exit 1
fi

echo "Test 3: drift engine outputs TOTAL ADHERENCE..."
if echo "$OUTPUT" | grep -q "TOTAL ADHERENCE:"; then
    echo "PASS: TOTAL ADHERENCE line found"
else
    echo "FAIL: TOTAL ADHERENCE line not found"
    exit 1
fi

echo "Test 4: vibe nudge message is shown when vibe != plain..."
if echo "$OUTPUT" | grep -q "VIBE WHISPER"; then
    echo "PASS: vibe nudge message shown"
else
    echo "FAIL: vibe nudge message not shown (check VIBE setting)"
    exit 1
fi

echo "Test 5: drift engine with NUDGE_QUIET=true suppresses nudge to stderr but still runs..."
OUTPUT2=$(NUDGE_QUIET=true bash bin/drift-engine 2>/dev/null)
if echo "$OUTPUT2" | grep -q "TOTAL ADHERENCE:"; then
    echo "PASS: drift engine runs in quiet nudge mode"
else
    echo "FAIL: drift engine failed in quiet nudge mode"
    exit 1
fi

echo "All nudge output integration tests PASSED"
