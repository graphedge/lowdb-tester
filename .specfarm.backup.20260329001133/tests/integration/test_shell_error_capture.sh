#!/bin/bash
# Integration test: capture shell error and verify entry logged (T009)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TEST_DIR=$(mktemp -d)
trap '[[ -n "${TEST_DIR:-}" ]] && rm -rf "$TEST_DIR"' EXIT

cp -r "$BASE_DIR/." "$TEST_DIR/"
cd "$TEST_DIR"

mkdir -p .specfarm
chmod +x bin/capture-shell-error.sh

JUSTIFICATIONS_LOG=".specfarm/justifications.log"
SHELL_ERRORS_LOG=".specfarm/shell-errors.log"

# Clear logs before test
rm -f "$JUSTIFICATIONS_LOG" "$SHELL_ERRORS_LOG"

echo "Test 1: capture_shell_error logs to shell-errors.log..."
JUSTIFICATIONS_LOG="$JUSTIFICATIONS_LOG" SHELL_ERRORS_LOG="$SHELL_ERRORS_LOG" \
    bash bin/capture-shell-error.sh \
        --command "docker build --no-cache ." \
        --exit-code 1 \
        --stderr "Build failed" \
        --context "CI test"

if [[ -f "$SHELL_ERRORS_LOG" ]]; then
    echo "PASS: shell-errors.log created"
else
    echo "FAIL: shell-errors.log not created"
    exit 1
fi

if grep -q "docker build" "$SHELL_ERRORS_LOG"; then
    echo "PASS: command found in shell-errors.log"
else
    echo "FAIL: command not found in shell-errors.log"
    exit 1
fi

echo "Test 2: capture_shell_error logs to justifications.log..."
if [[ -f "$JUSTIFICATIONS_LOG" ]]; then
    echo "PASS: justifications.log created"
else
    echo "FAIL: justifications.log not created"
    exit 1
fi

if grep -q "shell-error" "$JUSTIFICATIONS_LOG"; then
    echo "PASS: shell-error entry found in justifications.log"
else
    echo "FAIL: shell-error entry not found in justifications.log"
    exit 1
fi

echo "Test 3: justifications.log entry has timestamp..."
if grep -qE "^\[[0-9]{4}-[0-9]{2}-[0-9]{2}T" "$JUSTIFICATIONS_LOG"; then
    echo "PASS: timestamp found in justifications.log entry"
else
    echo "FAIL: timestamp not found in justifications.log entry"
    exit 1
fi

echo "Test 4: capturing multiple errors appends to log..."
initial_count=$(wc -l < "$SHELL_ERRORS_LOG")
JUSTIFICATIONS_LOG="$JUSTIFICATIONS_LOG" SHELL_ERRORS_LOG="$SHELL_ERRORS_LOG" \
    bash bin/capture-shell-error.sh \
        --command "pip install requests" \
        --exit-code 1 \
        --context "second error"
new_count=$(wc -l < "$SHELL_ERRORS_LOG")
if [[ "$new_count" -gt "$initial_count" ]]; then
    echo "PASS: second error appended to shell-errors.log"
else
    echo "FAIL: log count did not increase after second capture"
    exit 1
fi

echo "All shell-error capture integration tests PASSED"
