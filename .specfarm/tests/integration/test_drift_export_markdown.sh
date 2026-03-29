#!/bin/bash
# Integration test: run --export markdown and verify reports/drift.md is created (T018)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

cp -r "$BASE_DIR/." "$TEST_DIR/"
cd "$TEST_DIR"
chmod +x bin/drift-engine bin/specfarm

mkdir -p .specfarm

cat <<EOF > .specfarm/config
VIBE="plain"
PHASE_MODE="loose"
DRIFT_THRESHOLD=5
NUDGE_QUIET="true"
EOF

cat <<EOF > .specfarm/rules.xml
<specfarm-rules version="1.0">
  <rule id="EXPORT-TEST-01" global="true">
    <description>Export test rule 1</description>
    <signature type="keyword">UNIQUE_EXPORT_KW_AAA</signature>
  </rule>
  <rule id="EXPORT-TEST-02" global="true">
    <description>Export test rule 2</description>
    <signature type="keyword">UNIQUE_EXPORT_KW_BBB</signature>
  </rule>
</specfarm-rules>
EOF

rm -f .specfarm/justifications.log

# Add a file that satisfies EXPORT-TEST-01
echo "UNIQUE_EXPORT_KW_AAA present here" > src/marker.txt

echo "Test 1: --export markdown creates reports/drift.md..."
bash bin/drift-engine --export markdown 2>&1

if [[ -f "reports/drift.md" ]]; then
    echo "PASS: reports/drift.md was created"
else
    echo "FAIL: reports/drift.md was not created"
    exit 1
fi

echo "Test 2: reports/drift.md contains markdown heading..."
if grep -q "# SpecFarm Drift Report" reports/drift.md; then
    echo "PASS: markdown heading found"
else
    echo "FAIL: markdown heading not found in reports/drift.md"
    cat reports/drift.md
    exit 1
fi

echo "Test 3: reports/drift.md contains rule table..."
if grep -q "| Rule ID" reports/drift.md; then
    echo "PASS: rule table header found"
else
    echo "FAIL: rule table header not found"
    cat reports/drift.md
    exit 1
fi

echo "Test 4: reports/drift.md contains adherence value..."
if grep -qE "[0-9]+%" reports/drift.md; then
    echo "PASS: adherence percentage found in report"
else
    echo "FAIL: adherence percentage not found in report"
    cat reports/drift.md
    exit 1
fi

echo "Test 5: --export markdown --dry-run writes to stdout only (no file overwrite)..."
rm -f reports/drift.md
OUTPUT=$(bash bin/drift-engine --export markdown --dry-run 2>&1)
if [[ ! -f "reports/drift.md" ]]; then
    echo "PASS: dry-run did not create reports/drift.md"
else
    echo "FAIL: dry-run should not create file"
    exit 1
fi
if echo "$OUTPUT" | grep -q "SpecFarm Drift Report"; then
    echo "PASS: dry-run output printed to stdout"
else
    echo "FAIL: dry-run did not print report to stdout"
    exit 1
fi

echo "All drift export markdown integration tests PASSED"
