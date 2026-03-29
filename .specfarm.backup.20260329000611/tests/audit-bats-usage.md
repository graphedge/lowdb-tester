# BATS Usage Audit Report

**Generated**: 2026-03-15  
**Scope**: All shell test files in `tests/` directory  
**Objective**: Quantify BATS dependencies before removal migration

---

## Executive Summary

| Metric | Count | Notes |
|--------|-------|-------|
| Total test files with BATS patterns | 7 | Plus test_helper.sh (shared) |
| Total @test declarations | 63 | Unit: 43, Integration: 10, E2E: 10, Policy: 0, Windows: 0 |
| Total load statements | 5 | Unit: 4, Integration: 1 |
| Total BATS variable references | 2 (in test_helper.sh) | Context variables, $BATS_TMPDIR-like references |
| Files impacted | 7 core test files + 1 helper | Ready for conversion |

**Compliance Status**: ❌ **NON-COMPLIANT with Constitution II.A (Zero-Dependency Testing)**

---

## Detailed Breakdown by Category

### Unit Tests (tests/unit/*.sh)

| File | @test | load | run | $BATS vars | Conversion Complexity |
|------|-------|------|-----|------------|----------------------|
| test_drift_score_calculation.sh | 8 | 1 | 8 | 1 | **MEDIUM** |
| test_nudge_threshold.sh | 12 | 1 | 12 | 1 | **MEDIUM** |
| test_rule_parsing.sh | 10 | 1 | 10 | 1 | **MEDIUM** |
| test_export_markdown.sh | 5 | 1 | 5 | 0 | **LOW** |
| test_ci_verification.sh | 4 | 0 | 4 | 0 | **LOW** |
| test_tdd_workflow.sh | 10 | 1 | 11 | 1 | **MEDIUM** |
| *Others (4 files)* | 0 | 0 | 0 | 0 | N/A (not BATS-based) |
| **UNIT SUBTOTAL** | **49** | **5** | **50** | **4** | |

**Impact**: 6 of 10 unit test files require conversion. Critical path for TDD compliance.

---

### Integration Tests (tests/integration/*.sh)

| File | @test | load | run | $BATS vars | Conversion Complexity |
|------|-------|------|-----|------------|----------------------|
| test_cli_commands.sh | 4 | 1 | 4 | 0 | **MEDIUM** |
| test_rule_enforcement_e2e.sh | 3 | 0 | 3 | 0 | **LOW** |
| test_auto_rule_generation.sh | 1 | 0 | 1 | 0 | **LOW** |
| test_justifications_audit.sh | 2 | 0 | 2 | 0 | **LOW** |
| *Others (8 files)* | 0 | 0 | 0 | 0 | N/A (not BATS-based) |
| **INTEGRATION SUBTOTAL** | **10** | **1** | **10** | **0** | |

**Impact**: 4 of 12 integration test files require conversion. Lower complexity than unit tests.

---

### End-to-End Tests (tests/e2e/*.sh)

| File | @test | load | run | $BATS vars | Conversion Complexity |
|------|-------|------|-----|------------|----------------------|
| test_drift_flow.sh | 10 | 0 | 10 | 0 | **MEDIUM** |
| *Others (? files)* | 0 | 0 | 0 | 0 | N/A (not BATS-based) |
| **E2E SUBTOTAL** | **10** | **0** | **10** | **0** | |

**Impact**: 1 file identified; e2e directory may need full audit for completeness.

---

### Policy Tests (tests/policy/*.sh)

| File | @test | load | run | $BATS vars | Notes |
|------|-------|------|-----|------------|-------|
| test_agent_command_check.sh | 0 | 0 | 0 | 0 | Not BATS-based |
| *Others* | 0 | 0 | 0 | 0 | No BATS usage detected |
| **POLICY SUBTOTAL** | **0** | **0** | **0** | **0** | |

**Impact**: No conversion needed for policy tests; already plain shell.

---

### Windows Tests (tests/windows/*.sh)

| File | @test | load | run | $BATS vars | Notes |
|------|-------|------|-----|------------|-------|
| *All files* | 0 | 0 | 0 | 0 | PowerShell validation intact; no BATS usage |
| **WINDOWS SUBTOTAL** | **0** | **0** | **0** | **0** | |

**Impact**: No conversion needed; Windows tests use native shell already.

---

### Shared Infrastructure (tests/test_helper.sh)

**BATS Patterns Found**: 2

**Patterns**:
1. BATS context check (conditional logic for BATS detection)
2. Reference to $BATS_* variables or similar context

**Conversion Impact**: **CRITICAL** — All test files depend on test_helper.sh; requires refactoring first.

---

## Conversion Effort Estimate

| Phase | Files | @test | Complexity | Est. Time |
|-------|-------|-------|------------|-----------|
| T001  | 1     | 0 | LOW | < 30 min |
| T002  | 0     | 0 | LOW | < 30 min |
| T003  | 1     | 0 | MEDIUM | 30-60 min |
| T004-T006 | 6 | 49 | MEDIUM | 2-3 hours |
| T007  | 1     | 0 | LOW | 15-30 min |
| T008-T010 | 4 | 10 | MEDIUM | 1-1.5 hours |
| T011  | 1     | 0 | LOW | 15-30 min |
| T012-T013 | 2 | 10 | MEDIUM | 1-1.5 hours |
| T014-T016 | 3 | 0 | LOW | 1 hour |
| T017 (NEW) | 0 | 0 | LOW | 15-30 min |
| **TOTAL ESTIMATED** | **19** | **69** | **MEDIUM** | **7-9 hours** |

---

## Dependency Chain Analysis

### Critical Path (Blocking Dependencies)

```
T001 (Audit) ✓ COMPLETE
  ↓
T002 (Harness) — Depends on audit results
  ├─ Must handle 49 @test declarations → 49 test_ functions
  ├─ Must handle 5 load statements → 5 source statements
  └─ Must handle $BATS_* references → mktemp -d patterns

T003 (Refactor test_helper.sh) — BLOCKER for all tests
  ├─ Remove BATS context check (2 patterns)
  ├─ Preserve mock functions (drift_score, nudge_required, etc.)
  └─ Makes 69 tests unblocked for conversion

T004-T006 [Parallel]: Unit Tests Conversion (49 @test → test_* functions)
  ├─ Replace 50 `run` commands with $() capture
  └─ Replace 5 `load` with proper source statements

T008-T010 [Parallel]: Integration Tests Conversion (10 @test → test_* functions)
  └─ Replace 10 `run` commands with $() capture

T012-T013 [Parallel]: E2E + Policy + Windows Conversion (10 @test → test_* functions)
  └─ Replace 10 `run` commands with $() capture

T014-T016 [After tests pass]: Documentation cleanup
  └─ Remove BATS install instructions
  └─ Verify dependencies.txt, package.json clean

T017 [Final]: Constitution compliance verification
  └─ Confirm all tests pass zero-deps harness
  └─ Document compliance with Constitution II.A
```

---

## Risk Assessment

| Risk | Severity | Mitigation |
|------|----------|-----------|
| **Test logic loss during conversion** | HIGH | Preserve all test comments and assertion logic; manual review each file |
| **$BATS_* variable replacement inaccuracy** | MEDIUM | Only 2 patterns found in test_helper.sh; straightforward replacement |
| **load statement interdependencies** | MEDIUM | Only 5 statements; trace all imports; create source chain map |
| **Parallel conversion consistency** | MEDIUM | Use CONVERSION-GUIDE.md templates for all conversions; peer review |
| **CI/CD breakage** | MEDIUM | Update .github/workflows/lint.yml concurrently; test locally first |
| **Documentation staleness** | LOW | Update README, PHASE-1-TEST-GUIDE during T014-T016 |

---

## Pre-Conversion Checklist

- [ ] This audit report reviewed and approved
- [ ] CONVERSION-GUIDE.md created with pattern templates
- [ ] DAG diagram added to tasks.md for dependency clarity
- [ ] T002 test harness designed based on 69 test count
- [ ] T003 refactoring plan documented (2 BATS patterns)
- [ ] All test files tagged with conversion task IDs
- [ ] Local environment ready for testing (bash, coreutils only)
- [ ] Backup of original tests/ directory created
- [ ] Git hooks configured to prevent accidental BATS commits

---

## Next Steps

1. **IMMEDIATE** (Review this audit):
   - Validate counts and complexity assessments
   - Approve risk mitigations
   - Confirm effort estimate alignment

2. **T002 onwards** (Execute conversion):
   - Use CONVERSION-GUIDE.md for all pattern conversions
   - Follow DAG for dependency ordering
   - Tag each conversion with task ID and verification status

3. **T017 onwards** (Validate compliance):
   - Run full test suite under zero-deps harness
   - Generate Constitution II.A compliance report
   - Document lessons learned for future phases

---

## References

- **Constitution II.A**: [.specify/memory/constitution.md#L47](.specify/memory/constitution.md#L47) — Zero-Dependency Testing policy
- **BATS Documentation**: https://github.com/bats-core/bats-core (for validation during conversion)
- **Conversion Guide**: [CONVERSION-GUIDE.md](CONVERSION-GUIDE.md) (pattern templates and examples)
- **Tasks**: [specs/.bats-removal/tasks.md](specs/.bats-removal/tasks.md) (execution plan with updated DAG)
