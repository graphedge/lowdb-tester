# Phase 1 Test Guide — RED State Execution

**Generated**: 2026-03-15  
**Task**: T052-T053 (Test creation & execution)  
**Status**: RED phase — tests for unimplemented functionality intentionally FAILING  

---

## How to Run Phase 1 Tests

### Prerequisites

No external dependencies required. Tests run with plain `/bin/bash` and standard POSIX utilities.

```bash
# Verify bash is available
bash --version

# No other tools required
```

### Execution

From repository root:

```bash
# Run all Phase 1 tests (expect most FAIL on unimplemented features)
bash tests/run_all_tests.sh

# Run specific category
bash tests/run_all_tests.sh unit
bash tests/run_all_tests.sh integration
bash tests/run_all_tests.sh e2e

# Run single test file
bash tests/unit/test_drift_score_calculation.sh
bash tests/integration/test_cli_commands.sh
bash tests/e2e/test_drift_flow.sh

# Validate bash syntax without running
bash -n tests/unit/test_drift_score_calculation.sh
```

### Interpreting RED Output

**Expected behavior during Phase 1 (RED state):**

```
=== Unit Tests: Drift Score Calculation ===
PASS: T016: drift_score returns 1.0 when no violations
PASS: T016: drift_score returns 0.5 when half rules violated (5/10)
...
Results: 8 passed, 0 failed
```

- Tests against **mock functions** (defined in `tests/test_helper.sh`) pass in RED state
- Tests against **real implementation** (Phase 4) will fail until code is written
- This is correct — tests define the spec before implementation

---

## Test Structure

### Organization

```
tests/
├── test_helper.sh          # Shared utilities, mock implementations, run() helper
├── run_all_tests.sh        # Unified zero-dependency test runner
├── unit/
│   ├── test_drift_score_calculation.sh     # Math tests (8 tests)
│   ├── test_nudge_threshold.sh              # Threshold logic (12 tests)
│   ├── test_rule_parsing.sh                 # XML parsing (10 tests)
│   └── test_tdd_workflow.sh                 # Meta tests (10 tests)
├── integration/
│   └── test_cli_commands.sh                 # CLI drift & justify (10 tests)
└── e2e/
    ├── test_drift_flow.sh                   # End-to-end (10 tests)
    └── test_function_exports.sh             # Function availability (varies)
```

**Total**: 50+ test cases

### Test File Header Pattern

```bash
#!/bin/bash
# Description: What this test file verifies
# Converted from BATS to plain bash (no external dependencies)

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$TESTS_DIR/test_helper.sh"

PASS=0
FAIL=0

_run_test() {
  local name="$1"
  local func="$2"
  local test_root
  test_root=$(mktemp -d)
  mkdir -p "$test_root/.specfarm"
  local saved_dir="$PWD"
  cd "$test_root" || { echo "FAIL: $name (cd failed)"; FAIL=$((FAIL+1)); return; }
  if (export SPECFARM_ROOT="$test_root"; "$func"); then
    echo "PASS: $name"; PASS=$((PASS+1))
  else
    echo "FAIL: $name"; FAIL=$((FAIL+1))
  fi
  cd "$saved_dir" || true
  rm -rf "$test_root"
}

t016_my_test() {
  run drift_score 0 10
  [ "$status" -eq 0 ] && [ "$output" = "1.0" ]
}

echo "=== My Tests ==="
_run_test "T016: drift_score returns 1.0 when no violations" t016_my_test

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

### The `run()` Helper

`tests/test_helper.sh` provides a `run()` helper that captures command output and exit status:

```bash
run drift_score 0 10
# Sets: $output = "1.0", $status = 0
```

This mirrors the BATS `run` command but requires no external tools.

### Naming Conventions

- **Function names**: `t<taskid>_<description>` (e.g., `t016_drift_score_no_violations`)
- **Test names** (for output): descriptive string passed to `_run_test()`
- **Each test is independent** — uses isolated temp directories
- **Mock functions** in `test_helper.sh` prevent cascading failures

---

## Task References (Traceability)

Each test references one or more Phase 1 tasks:

| Test File | Coverage | Task Refs |
|-----------|----------|-----------|
| `test_drift_score_calculation.sh` | Drift formula, edge cases | T015-T020 |
| `test_nudge_threshold.sh` | Nudge/whisper logic, messaging | T030-T036 |
| `test_rule_parsing.sh` | XML parsing, phase filtering | T017 |
| `test_cli_commands.sh` | CLI drift & justify commands | T019, T046 |
| `test_drift_flow.sh` | End-to-end workflow | T047 |
| `test_tdd_workflow.sh` | TDD meta-tests | T049 |

---

## What the RED State Means

| Phase | Status | Action |
|-------|--------|--------|
| **Phase 3 (now)** | 🔴 RED | Tests against mocks pass; tests against real impl fail |
| **Phase 4** | 🟡 TRANSITIONAL | Implement code incrementally. Tests turn GREEN as features are built |
| **Phase 4 (complete)** | 🟢 GREEN | All tests PASS. Implementation complete |

---

## Edge Cases Tested

### Drift Score Formula: `score = 1.0 - (violations / max(total_rules, 1))`

- **Zero total rules** → score = 1.0 (perfect adherence by definition)
- **Zero violations** → score = 1.0 (perfect compliance)
- **All violated** → score = 0.0 (complete drift)
- **Floating-point rounding** → Values normalized via awk

### Threshold Logic

- **score ≤ 0.5** → Nudge trigger (🚜 "Heads up farmer!")
- **0.5 < score < 0.9** → Whisper trigger (🐴 "Gentle nudge:")
- **score ≥ 0.9** → No action

---

## Common Issues & Fixes

### Issue: `command not found` for test functions

**Cause**: Test file not sourcing `test_helper.sh` correctly.  
**Fix**: Ensure `. "$TESTS_DIR/test_helper.sh"` is at the top of the file.

### Issue: `No such file or directory` for test_helper.sh

**Cause**: `TESTS_DIR` path is wrong.  
**Fix**: Use `TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`.

### Issue: All tests pass (wrong during RED state!)

**Cause**: You may be testing mock behavior, not real implementation.  
**Fix**: Check if tests call real `bin/specfarm` or mock `specfarm()` from test_helper.

---

## Next Steps (Phase 4)

1. **Implement `bin/specfarm`** — CLI entry point
2. **Implement `src/core/drift_score.sh`** — Make math tests GREEN
3. **Implement `src/cli/drift_command.sh`** — Make CLI tests GREEN
4. **Continue until all tests pass** — TDD workflow
5. **Validate with full test suite** — No regressions

---

## References

- **Specification**: `specs/001-specfarm-phase-1/spec.md`
- **Test Framework**: Plain bash (zero external dependencies — Constitution II.A)
- **Test Helper**: `tests/test_helper.sh` (shared mocks & `run()` helper)
- **Conversion Guide**: `specs/.bats-removal/CONVERSION-GUIDE.md`
- **Decision Record**: `specs/001-specfarm-phase-1/decisions.md` (D001: TDD framework selection)

---

**T053 COMPLETE**: Test guide updated for zero-dependency bash execution. RED state instructions accurate.
