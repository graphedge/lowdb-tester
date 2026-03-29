#!/bin/bash
# End-to-end test: verify justifications.log entries include timestamp and context (T011)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

cp -r "$BASE_DIR/." "$TEST_DIR/"
cd "$TEST_DIR"
chmod +x bin/specfarm bin/justifications-log.sh bin/capture-shell-error.sh

mkdir -p .specfarm
rm -f .specfarm/justifications.log

echo "Test 1: specfarm justify writes timestamped entry..."
bash bin/specfarm justify "RULE-001" "Testing justification trail"

if [[ -f .specfarm/justifications.log ]]; then
    echo "PASS: justifications.log created"
else
    echo "FAIL: justifications.log not created"
    exit 1
fi

ENTRY=$(cat .specfarm/justifications.log)
if echo "$ENTRY" | grep -qE "^\[[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\]"; then
    echo "PASS: entry has ISO 8601 timestamp"
else
    echo "FAIL: entry missing ISO 8601 timestamp. Got: $ENTRY"
    exit 1
fi

if echo "$ENTRY" | grep -q 'RULE="RULE-001"'; then
    echo "PASS: entry contains RULE field"
else
    echo "FAIL: entry missing RULE field. Got: $ENTRY"
    exit 1
fi

if echo "$ENTRY" | grep -q 'JUSTIFICATION="Testing justification trail"'; then
    echo "PASS: entry contains JUSTIFICATION field"
else
    echo "FAIL: entry missing JUSTIFICATION field. Got: $ENTRY"
    exit 1
fi

if echo "$ENTRY" | grep -qE 'COMMIT="[a-f0-9]+"' || echo "$ENTRY" | grep -q 'COMMIT="no-git"'; then
    echo "PASS: entry contains COMMIT field"
else
    echo "FAIL: entry missing COMMIT field. Got: $ENTRY"
    exit 1
fi

echo "Test 2: justifications-log.sh log command adds FILE and LINE context..."
bash bin/justifications-log.sh log "RULE-002" "Context test" "src/app.sh" "42"
ENTRY2=$(grep 'RULE="RULE-002"' .specfarm/justifications.log)
if echo "$ENTRY2" | grep -q 'FILE="src/app.sh"'; then
    echo "PASS: FILE context included in entry"
else
    echo "FAIL: FILE context missing from entry. Got: $ENTRY2"
    exit 1
fi
if echo "$ENTRY2" | grep -q 'LINE="42"'; then
    echo "PASS: LINE context included in entry"
else
    echo "FAIL: LINE context missing from entry. Got: $ENTRY2"
    exit 1
fi

echo "Test 3: shell-error capture entries include timestamp in justifications.log..."
bash bin/capture-shell-error.sh \
    --command "docker build --no-cache ." \
    --exit-code 1 \
    --context "e2e test"
ENTRY3=$(tail -1 .specfarm/justifications.log)
if echo "$ENTRY3" | grep -qE "^\[[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\]"; then
    echo "PASS: shell-error entry has ISO 8601 timestamp"
else
    echo "FAIL: shell-error entry missing timestamp. Got: $ENTRY3"
    exit 1
fi

echo "Test 4: multiple justifications are all present in log..."
bash bin/specfarm justify "RULE-003" "Third justification"
bash bin/specfarm justify "RULE-004" "Fourth justification"
count=$(wc -l < .specfarm/justifications.log)
if [[ "$count" -ge 4 ]]; then
    echo "PASS: at least 4 entries in justifications.log ($count found)"
else
    echo "FAIL: expected at least 4 entries, found $count"
    exit 1
fi

echo "All justifications format e2e tests PASSED"
