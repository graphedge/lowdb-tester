#!/bin/bash
# tests/unit/test_task_context_flag_parsing.sh

. "$(dirname "$0")/../test_helper.sh"

AGENT=".specfarm/agents/gather-rules-agent.sh"

echo "Running --task-context flag parsing tests..."

# Test 1: --task-context flag
echo "Test 1: --task-context flag"
run bash "$AGENT" --task-context "Fix bash arithmetic guard"
if echo "$output" | grep -q "Unknown option"; then
  echo "✗ FAIL: --task-context should be known"
  exit 1
fi
echo "✓ PASS: --task-context is known"

# Test 2: Missing task description
echo "Test 2: Missing task description"
run bash "$AGENT" --task-context ""
if [[ $status -ne 0 ]]; then
  echo "✓ PASS: Missing description returns error"
else
  echo "✗ FAIL: Missing description should return error"
  exit 1
fi

# Test 3: --task alias
echo "Test 3: --task alias"
run bash "$AGENT" --task "Fix bash arithmetic guard"
if echo "$output" | grep -q "Unknown option"; then
  echo "✗ FAIL: --task should be known"
  exit 1
fi
echo "✓ PASS: --task is known"

# Test 4: Conflict with --pr-context
echo "Test 4: Conflict with --pr-context"
run bash "$AGENT" --pr-context --task-context "some task"
if [[ $status -ne 0 ]] && echo "$output" | grep -qi "conflict"; then
  echo "✓ PASS: Conflict detected"
else
  echo "✗ FAIL: Conflict not detected (status=$status, output=$output)"
  exit 1
fi

echo "All tests passed"
