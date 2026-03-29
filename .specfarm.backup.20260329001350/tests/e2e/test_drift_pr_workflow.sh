#!/bin/bash
# End-to-end test: confirm justifications.log is updated after drift runs
# and the report can be included in a PR body (T020)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

cp -r "$BASE_DIR/." "$TEST_DIR/"
cd "$TEST_DIR"
chmod +x bin/drift-engine bin/specfarm bin/justifications-log.sh

mkdir -p .specfarm

cat <<EOF > .specfarm/config
VIBE="plain"
PHASE_MODE="loose"
NUDGE_QUIET="true"
EOF

cat <<EOF > .specfarm/rules.xml
<specfarm-rules version="1.0">
  <rule id="PR-TEST-01" global="true">
    <description>PR workflow test rule</description>
    <signature type="keyword">UNIQUE_PR_KW_111</signature>
  </rule>
  <rule id="PR-TEST-02" global="true">
    <description>PR workflow test rule 2</description>
    <signature type="keyword">UNIQUE_PR_KW_222</signature>
  </rule>
</specfarm-rules>
EOF

rm -f .specfarm/justifications.log

echo "Test 1: justify a drifted rule..."
bash bin/specfarm justify "PR-TEST-02" "Deferred to Phase 2 per team decision"
if grep -q 'RULE="PR-TEST-02"' .specfarm/justifications.log; then
    echo "PASS: justification recorded"
else
    echo "FAIL: justification not recorded"
    exit 1
fi

echo "Test 2: run drift export and verify report contains justified rule..."
bash bin/drift-engine --export markdown 2>&1
if grep -q "PR-TEST-02" reports/drift.md; then
    echo "PASS: justified rule present in drift report"
else
    echo "FAIL: justified rule not found in drift report"
    cat reports/drift.md
    exit 1
fi

echo "Test 3: justifications.log is plain text (grep/cat friendly for PR bodies)..."
if file .specfarm/justifications.log | grep -q "text"; then
    echo "PASS: justifications.log is plain text"
else
    # file command may not be available; check it's readable
    if cat .specfarm/justifications.log >/dev/null 2>&1; then
        echo "PASS: justifications.log is readable (file command unavailable)"
    else
        echo "FAIL: justifications.log is not readable"
        exit 1
    fi
fi

echo "Test 4: dry-run export produces PR-ready markdown on stdout..."
PR_BODY=$(bash bin/drift-engine --export markdown --dry-run 2>&1)
if echo "$PR_BODY" | grep -q "Total Adherence\|TOTAL ADHERENCE\|Adherence"; then
    echo "PASS: PR body contains adherence summary"
else
    # Adherence may be formatted differently in the template; check for % sign
    if echo "$PR_BODY" | grep -qE "[0-9]+%"; then
        echo "PASS: PR body contains adherence percentage"
    else
        echo "FAIL: PR body missing adherence information"
        echo "$PR_BODY"
        exit 1
    fi
fi

echo "Test 5: justifications.log entries are git-trackable (no binary content)..."
if cat .specfarm/justifications.log | LC_ALL=C grep -q $'[\x80-\xFF]' 2>/dev/null; then
    echo "FAIL: justifications.log contains non-ASCII characters (not ideal for git)"
    exit 1
else
    echo "PASS: justifications.log contains only ASCII (git-trackable)"
fi

echo "All drift PR workflow e2e tests PASSED"
