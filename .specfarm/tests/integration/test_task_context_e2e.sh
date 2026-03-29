#!/bin/bash
# tests/integration/test_task_context_e2e.sh
# T012: Integration tests for full task-context pipeline

. "$(dirname "$0")/../test_helper.sh"

AGENT=".specfarm/agents/gather-rules-agent.sh"

echo "Running task-context end-to-end integration tests..."

# ── Test 1: Task-context returns ranked rules for known keyword ───────────────
echo "Test 1: Task-context pipeline finds and ranks rules"
output=$(RULES_XML_PATH="$(dirname "${BASH_SOURCE[0]}")/../fixtures/sample-rules.xml" \
    bash "$AGENT" --task-context "Update tests/test_helper.sh assertion functions" 2>&1)
if echo "$output" | grep -q "r_test_001"; then
  echo "✓ PASS: Pipeline found r_test_001 for 'test_helper.sh' keyword"
else
  echo "✗ FAIL: Expected r_test_001 in output"
  echo "$output"
  exit 1
fi

# ── Test 2: Task-context returns structured markdown output ──────────────────
echo "Test 2: Task-context output is structured markdown"
output=$(RULES_XML_PATH="$(dirname "${BASH_SOURCE[0]}")/../fixtures/sample-rules.xml" \
    bash "$AGENT" --task-context "Update tests/test_helper.sh assertion functions" 2>&1)
if echo "$output" | grep -q "## Context for:" && echo "$output" | grep -q "confidence"; then
  echo "✓ PASS: Output is structured markdown with confidence scores"
else
  echo "✗ FAIL: Missing markdown structure or confidence scores"
  echo "$output"
  exit 1
fi

# ── Test 3: Task-context with no matches exits cleanly ────────────────────────
echo "Test 3: No-match task-context exits cleanly"
output=$(RULES_XML_PATH="$(dirname "${BASH_SOURCE[0]}")/../fixtures/sample-rules.xml" \
    bash "$AGENT" --task-context "completely unrelated task xyz123" 2>&1)
exit_code=$?
if [[ $exit_code -eq 0 ]]; then
  echo "✓ PASS: No-match case exits 0 cleanly"
else
  echo "✗ FAIL: Expected exit 0 for no-match, got $exit_code"
  exit 1
fi

echo "All task-context e2e tests passed"
