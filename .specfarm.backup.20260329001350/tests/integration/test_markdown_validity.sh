#!/bin/bash
# Integration test: verify generated markdown is valid and parseable (T019)

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
NUDGE_QUIET="true"
EOF

cat <<EOF > .specfarm/rules.xml
<specfarm-rules version="1.0">
  <rule id="VALID-MD-01" global="true">
    <description>Markdown validity test rule</description>
    <signature type="keyword">UNIQUE_VALID_MD_KW_ZZZ</signature>
  </rule>
</specfarm-rules>
EOF

rm -f .specfarm/justifications.log

echo "Test 1: generate drift.md and verify it is non-empty..."
bash bin/drift-engine --export markdown 2>&1
if [[ -f "reports/drift.md" ]] && [[ -s "reports/drift.md" ]]; then
    echo "PASS: reports/drift.md exists and is non-empty"
else
    echo "FAIL: reports/drift.md missing or empty"
    exit 1
fi

echo "Test 2: markdown has at least one heading (# or ##)..."
if grep -qE "^#{1,6} " reports/drift.md; then
    echo "PASS: markdown headings found"
else
    echo "FAIL: no markdown headings found"
    cat reports/drift.md
    exit 1
fi

echo "Test 3: markdown table rows are properly formatted (| col | col |)..."
if grep -qE "^\|.+\|.+\|" reports/drift.md; then
    echo "PASS: markdown table rows found"
else
    echo "FAIL: no properly-formatted table rows found"
    cat reports/drift.md
    exit 1
fi

echo "Test 4: markdown has no unmatched template placeholders..."
if grep -q "{{" reports/drift.md || grep -q "}}" reports/drift.md; then
    echo "FAIL: unmatched template placeholders found in output"
    grep "{{" reports/drift.md || true
    exit 1
else
    echo "PASS: no unmatched template placeholders"
fi

echo "Test 5: markdown contains SpecFarm branding footer..."
if grep -q "SpecFarm" reports/drift.md; then
    echo "PASS: SpecFarm branding found in output"
else
    echo "FAIL: SpecFarm branding not found in output"
    exit 1
fi

echo "Test 6: markdown is parseable by grep (line-based tool)..."
line_count=$(wc -l < reports/drift.md)
if [[ "$line_count" -gt 3 ]]; then
    echo "PASS: markdown has $line_count lines (parseable)"
else
    echo "FAIL: markdown has only $line_count lines"
    exit 1
fi

echo "All markdown validity tests PASSED"
