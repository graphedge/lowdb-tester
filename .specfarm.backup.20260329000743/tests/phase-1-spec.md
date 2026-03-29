# Phase 1 TDD Specification: Test Framework & Patterns

**Date**: 2026-03-15  
**Purpose**: Document the test framework, structure, and TDD patterns for Phase 1 implementation  
**Status**: FRAMEWORK DEFINED (Tests will be RED in Phase 3)

---

## Overview

All Phase 1 tasks follow **Test-Driven Development (TDD)** methodology:
1. **RED**: Write failing tests first (tests don't exist yet in Phase 1)
2. **GREEN**: Implement code to pass tests (Phase 4)
3. **REFACTOR**: Optimize and clean up (Phase 5)

This document defines the testing structure, naming conventions, and execution approach for Phase 1.

---

## Test Framework: Bash Automated Testing System (BATS)

Phase 1 uses **BATS** (Bash Automated Testing System) as the primary test framework for shell scripts.

### Why BATS?

- ✅ **Minimal dependencies**: Only requires bash and basic utilities
- ✅ **Native bash testing**: Tests are written in bash with intuitive assertions
- ✅ **Easy to read**: TAP (Test Anything Protocol) output
- ✅ **Fast execution**: All tests run quickly (<1s for typical suites)
- ✅ **Git-trackable**: Test files are plain bash scripts
- ✅ **Constitution Compliant**: Aligns with "minimal dependencies" principle

### BATS Installation

```bash
# Install via package manager (if available)
apt-get install bats                    # Debian/Ubuntu
brew install bats-core                  # macOS

# Or via git clone
git clone https://github.com/bats-core/bats-core.git
cd bats-core && ./install.sh /usr/local
```

---

## Test Directory Structure

```
tests/
├── phase-1-spec.md              # This file: Framework & patterns
├── unit/                        # Unit tests for individual functions
│   ├── test_drift_score_calculation.sh
│   ├── test_nudge_threshold.sh
│   ├── test_rule_parsing.sh
│   └── test_tdd_workflow.sh
├── integration/                 # Integration tests for components
│   └── test_cli_commands.sh
└── e2e/                         # End-to-end tests for full workflows
    └── test_drift_flow.sh
```

---

## BATS Test Structure

### Basic Test File Template

```bash
#!/usr/bin/env bats
# tests/unit/test_drift_score_calculation.sh

load test_helper          # Source common test utilities (optional)

# Setup: Run before each test
setup() {
  export SPECFARM_ROOT="$BATS_TMPDIR/specfarm-test-$$"
  mkdir -p "$SPECFARM_ROOT/.specfarm"
  cd "$SPECFARM_ROOT" || exit 1
}

# Teardown: Run after each test
teardown() {
  rm -rf "$SPECFARM_ROOT"
}

# Test: Perfect adherence (score = 1.0)
@test "drift_score returns 1.0 when all rules pass" {
  # Arrange
  echo "0" > /tmp/violations.txt
  echo "10" > /tmp/total_rules.txt
  
  # Act
  result=$(drift_score)
  
  # Assert
  [[ "$result" == "1.0" ]] || fail "Expected 1.0, got $result"
}

# Test: 50% violation (score = 0.5)
@test "drift_score returns 0.5 when half rules violated" {
  result=$(drift_score 5 10)
  [[ "$result" == "0.5" ]]
}

# Test: Edge case - zero total rules
@test "drift_score returns 1.0 when no rules defined" {
  result=$(drift_score 0 0)
  [[ "$result" == "1.0" ]]
}
```

### Test Naming Conventions

- **Test file**: `test_<component>.sh` (e.g., `test_drift_score_calculation.sh`)
- **Test function**: `@test "<description>"` (e.g., `@test "drift_score returns 1.0 when all rules pass"`)
- **Clear naming**: Describe the scenario and expected outcome
  - ✅ GOOD: `@test "nudge triggers when drift exceeds 0.5"`
  - ❌ BAD: `@test "test nudge"`

---

## Common Assertions

BATS provides simple bash-based assertions:

```bash
# Equality
[[ "$result" == "expected" ]]           # String comparison
[[ "$count" -eq 5 ]]                    # Numeric comparison

# File/Directory checks
[[ -f "$file" ]]                        # File exists
[[ -d "$dir" ]]                         # Directory exists
[[ ! -f "$file" ]]                      # File does NOT exist

# Command success/failure
run command_name                        # Execute command, capture output
[[ $status -eq 0 ]]                     # Check exit code (0 = success)
[[ "$output" =~ "pattern" ]]            # Check output contains pattern
[[ "$output" == *"substring"* ]]        # String contains substring

# Function existence
declare -f function_name &>/dev/null    # Function is defined
```

### Assertion Helpers

```bash
# From bats-core (built-in)
assert_equal <expected> <actual>
assert_not_equal <unexpected> <actual>
assert_success                          # Last command succeeded
assert_failure                          # Last command failed
assert_output <output>                  # Output matches (regex support with --)
refute_output <output>                  # Output does NOT match
assert_line <line> "<output_line>"      # Specific output line
```

---

## Phase 1 Test Categories

### 1. Unit Tests: Drift Score Calculation

**File**: `tests/unit/test_drift_score_calculation.sh`

**Tests to implement** (will be RED in Phase 3):
```bash
@test "calculates drift_score as 1.0 - (violations / total)" { }
@test "returns 1.0 when no violations" { }
@test "returns 0.5 when 50% rules violated" { }
@test "returns 0.0 when all rules violated" { }
@test "handles zero total rules safely (returns 1.0)" { }
@test "handles floating point precision (rounds to 2 decimals)" { }
```

### 2. Unit Tests: Nudge/Whisper Thresholds

**File**: `tests/unit/test_nudge_threshold.sh`

**Tests to implement**:
```bash
@test "nudge_required returns true when score <= 0.5 (drift >= 0.5)" { }
@test "nudge_required returns false when score > 0.5" { }
@test "whisper_required returns true when 0.7 >= score > 0.5" { }
@test "whisper_required returns false when score > 0.7 or score <= 0.5" { }
@test "nudge message contains farm emoji 🚜" { }
@test "whisper message contains farm emoji 🐴" { }
```

### 3. Unit Tests: Rule Parsing

**File**: `tests/unit/test_rule_parsing.sh`

**Tests to implement**:
```bash
@test "parse_rules extracts rule IDs from rules.xml" { }
@test "parse_rules extracts rule descriptions" { }
@test "parse_rules handles immutable attribute" { }
@test "parse_rules filters by phase (available-from)" { }
@test "parse_rules handles edge case: malformed XML" { }
@test "parse_rules returns empty list when no rules defined" { }
```

### 4. Integration Tests: CLI Commands

**File**: `tests/integration/test_cli_commands.sh`

**Tests to implement**:
```bash
@test "specfarm drift command executes without error" { }
@test "specfarm drift returns table with rule ids and scores" { }
@test "specfarm drift includes overall drift score" { }
@test "specfarm justify logs justification to justifications.log" { }
@test "specfarm justify preserves git commit hash" { }
@test "specfarm help displays all available commands" { }
```

### 5. End-to-End Tests: Drift Flow

**File**: `tests/e2e/test_drift_flow.sh`

**Tests to implement**:
```bash
@test "full drift detection flow: create rules -> detect violations -> calculate score" { }
@test "drift score updates when new rule is added" { }
@test "drift score improves when code fixed to match rule" { }
@test "whisper message displays at correct threshold" { }
@test "nudge message displays at correct threshold" { }
@test "justification prevents violation from counting toward drift" { }
```

### 6. TDD Workflow Tests

**File**: `tests/unit/test_tdd_workflow.sh`

**Tests to implement** (meta-tests ensuring TDD compliance):
```bash
@test "all Phase 1 tasks have test-first requirement documented" { }
@test "all test files follow naming convention test_*.sh" { }
@test "all test functions use @test decorator" { }
@test "all test functions have descriptive names" { }
@test "test functions reference implementation tasks (T00X)" { }
```

---

## Test Execution Commands

### Run all tests
```bash
# Run all tests with summary
bats tests/**/*.sh

# Run tests with verbose output
bats tests/**/*.sh --verbose

# Run specific test file
bats tests/unit/test_drift_score_calculation.sh

# Run tests matching pattern
bats tests --grep "drift_score"
```

### Run tests for Phase 1 verification
```bash
# Create convenience script: bin/run-phase1-tests.sh
#!/bin/bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1

echo "🌱 Running Phase 1 Test Suite..."
bats tests/unit/*.sh tests/integration/*.sh tests/e2e/*.sh
echo "✅ All tests passed!"
```

Then execute:
```bash
bash bin/run-phase1-tests.sh
```

---

## Test Coverage Expectations

### Phase 1 Coverage Goals
- **Unit Tests**: 80%+ coverage of core functions (drift_score, rule parsing, thresholds)
- **Integration Tests**: All CLI commands tested (drift, justify, help)
- **E2E Tests**: Full workflow from rules → detection → output
- **Edge Cases**: All edge cases from data-model.md covered by tests

### Coverage Reporting (Phase 2+)
```bash
# With coverage tracking (requires kcov or similar)
kcov coverage bats tests/**/*.sh
open coverage/index.html
```

---

## TDD Workflow for Phase 1 Tasks

### Task Implementation Cycle

For each Phase 1 task (T001-T005, Task 1-5):

1. **RED** (Phase 3):
   ```bash
   # Write failing test first
   @test "description of what should happen" {
     # Test code that will fail initially
     run implementation_command_here
     [ $status -eq 0 ]
     [[ "$output" =~ "expected output" ]]
   }
   ```
   
   Execute: `bats tests/unit/test_*.sh` → Verify FAIL ❌

2. **GREEN** (Phase 4):
   ```bash
   # Implement code to pass test
   implementation_command_here() {
     # Minimal implementation to pass test
     # ...
   }
   ```
   
   Execute: `bats tests/unit/test_*.sh` → Verify PASS ✅

3. **REFACTOR** (Phase 5):
   ```bash
   # Clean up, optimize, document
   # Keep tests passing throughout
   ```

---

## Test Dependencies (Phase 1)

Essential packages (all included in standard environments):
- `bash` ≥ 4.0
- `bats-core` (install via package manager or git)
- `git` (already required for SpecFarm)
- Standard utilities: `grep`, `awk`, `sed`, `cat`, `mkdir`, `rm`

### No External Dependencies
- ✅ No Docker required for Phase 1 tests
- ✅ No Python/Node.js test runners
- ✅ No CI/CD runners (local execution only)
- ✅ Tests execute on Linux, macOS, Termux

---

## Test Success Criteria

Phase 1 tests are successful when:

✅ All unit tests pass (`tests/unit/*.sh`)
✅ All integration tests pass (`tests/integration/*.sh`)  
✅ All e2e tests pass (`tests/e2e/*.sh`)
✅ Coverage: ≥80% of core functions  
✅ Execution time: <5 seconds for full suite  
✅ Each test is independent (can run in any order)  
✅ Tests are deterministic (always pass/fail, never flaky)  
✅ Test files follow naming conventions  
✅ Tests reference corresponding task IDs (T001-T037)

---

## Notes for Implementation Team

1. **Phase 3 Tasks** (T044-T051):
   - Create each test file with failing tests (RED state)
   - Link tests to corresponding implementation tasks
   - Document test-to-task mapping

2. **Phase 4 Implementation**:
   - Implement code to pass tests
   - Keep tests in GREEN state
   - Do NOT modify tests to make them pass

3. **Phase 5 Verification**:
   - All tests still passing
   - Coverage metrics recorded
   - Documentation complete

---

## Reference: BATS Documentation

- **Official BATS**: https://github.com/bats-core/bats-core
- **TAP Standard**: https://testanything.org/
- **Bash Testing Best Practices**: https://github.com/bats-core/bats-core/wiki/Background:-writing-tests
