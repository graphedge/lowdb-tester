---
description: Resolution plan for Phase 1 critical specification issues blocking implementation
model: claude-haiku-4.5
status: BLOCKING
date-created: 2026-03-15
source: analyze1.md critical issues
---

# Phase 1 Critical Issues Resolution Plan

## Overview

**Status**: 🚫 BLOCKING — Do not proceed to `/speckit.implement` until all issues resolved.

**Source**: `specs/001-specfarm-phase-1/analyze1.md` specification analysis report  
**Severity**: 3 CRITICAL + 2 HIGH issues identified  
**Constitution Alignment**: Multiple violations of Principle II (TDD) and underspecification conflicts

---

## Critical Issue #1: Add TDD/Test Specification

**Addresses**: C1 (Coverage Gap), Constitution II (Testing: TDD)  
**Severity**: 🔴 CRITICAL

### Problem Statement
- **Finding**: Constitution mandates TDD (test-first) but *no task explicitly addresses writing tests before implementation*.
- **Impact**: Phase 1 risks non-compliant implementation. Constitution requires verification every 3-4 task updates.
- **Current State**: tasks.md tasks 1-5 focus on implementation but do not define test specifications upfront.

### Requirements to Add
1. **Create Task 0 (Test Specification)** or **Expand Task 1** to include:
   - Test specification requirements written BEFORE implementation
   - Unit test framework selection (e.g., bash unit testing with `bats` or custom harness)
   - Integration test scenarios for drift detection and nudges
   - End-to-end test cases for CLI commands (`/specfarm drift`, `/specfarm justify`)
   - Acceptance criteria for each test (pass/fail conditions)

2. **Define Test Structure** in plan.md:
   - Tests directory layout: `tests/unit/`, `tests/integration/`, `tests/e2e/`
   - Test naming convention: `test_*.sh` or `*.bats`
   - Test execution command: documented in README or setup script
   - Coverage expectations: target % for drift detection logic

3. **Add Test-First Workflow** to tasks.md:
   - Each task MUST include a "Test First" subsection
   - Example for Task 1:
     ```
     ### Task 1: Build Drift Detection Engine
     
     #### Test First (BEFORE implementation)
     - Write unit tests for rule parsing
     - Write integration tests for drift score calculation
     - Define acceptance criteria for performance (<500ms)
     - All tests initially RED (failing)
     
     #### Implementation (GREEN phase)
     - Implement rule parsing logic
     - Implement drift scoring algorithm
     - Ensure all tests pass
     
     #### Refactor (REFACTOR phase)
     - Optimize performance if needed
     - Ensure tests remain GREEN
     ```

### Resolution Actions
- [ ] Add "Test First" subsection to each of Tasks 1-5 in tasks.md
- [ ] Create `tests/phase-1-spec.md` documenting test framework, structure, and naming conventions
- [ ] Add testing command to `bin/run-phase1-tests.sh` (or similar)
- [ ] Update spec.md Core Deliverables to explicitly include "Comprehensive test suite for Phase 1"

### Verification
- Run test suite before implementation: `bash tests/phase-1-spec.sh --dry-run` → all tests RED
- Run test suite after Task N: `bash tests/phase-1-spec.sh` → N suite(s) GREEN

---

## Critical Issue #2: Clarify `/specfarm xml export`

**Addresses**: A1 (Ambiguity), I1 (Inconsistency)  
**Severity**: 🔴 CRITICAL

### Problem Statement
- **Finding**: Task 1 includes `/specfarm xml export` but no spec requirement for XML export command exists in spec.md.
- **Impact**: Unclear whether XML export is a Phase 1 core deliverable or an implementation detail; scope creep risk.
- **Current State**: tasks.md Task 1 lists XML export; spec.md does not mention it.

### Requirements to Clarify
**Option A: XML Export IS Core Deliverable**
1. Add to spec.md Core Deliverables:
   ```
   - Local CLI (`/specfarm xml export`) — Export drift data and rules to XML format
   ```
2. Add acceptance criteria:
   - XML schema complies with `rules-schema.xsd` if applicable
   - Round-trip consistency: drift JSON → XML → JSON preserves data
   - Performance: <500ms for typical ruleset

**Option B: XML Export is NOT Phase 1 (Defer)**
1. Remove from Task 1 in tasks.md
2. Move to Phase 2 backlog with rationale: "Phase 1 focuses on core drift detection; XML export deferred to Phase 2 for extensibility phase"
3. Keep Markdown export and JSON Lines export as Phase 1 core

### Recommended Direction
**Option B (Defer XML Export)** — Rationale:
- spec.md currently specifies Markdown and JSON Lines export (no XML mentioned)
- XML adds complexity without immediate user demand
- Phase 1 should focus on core drift detection loop, not export format proliferation
- Phase 2 can introduce extensible export architecture (Markdown, JSON, XML, YAML)

### Resolution Actions
- [ ] Decide: Is XML export Phase 1 or Phase 2? (Recommend: Phase 2)
- [ ] Update spec.md to explicitly list export formats in scope (currently: Markdown, JSON Lines)
- [ ] Update tasks.md Task 1: remove XML export or clarify as "prep for Phase 2 extensibility"
- [ ] Add note to plan.md Phase 1 scope: "Export formats: Markdown, JSON Lines; XML deferred to Phase 2"

### Verification
- `grep -r "xml export" specs/001-specfarm-phase-1/` → should find 0 or 1 occurrence (updated Task 1 only if deferred)
- spec.md Core Deliverables → explicitly list export formats

---

## Critical Issue #3: Define Drift Score Criteria

**Addresses**: U1 (Underspecification), E1 (Env./Constraint)  
**Severity**: 🔴 CRITICAL

### Problem Statement
- **Finding**: "Drift score (0-1)" defined in spec.md but acceptance criteria missing: What constitutes 0.0? 1.0? How is it calculated?
- **Impact**: Unclear implementation target; acceptance tests cannot be written (TDD blocker); performance constraint (<500ms) lacks baseline.
- **Current State**: spec.md says "simple drift score table" but provides no numerical definition.

### Requirements to Add

1. **Drift Score Numerical Definition** in plan.md → "Data Model & Drift Score Calculation":
   ```
   Drift Score = (Rules Violated) / (Total Rules) × 100%
   - 0.0 (0%) = All rules satisfied; no violations
   - 1.0 (100%) = All rules violated; maximum drift
   - Example:
     * 10 total rules, 3 rules violated → drift score = 0.3 (30%)
     * 10 total rules, 0 rules violated → drift score = 0.0 (0%)
   
   Display Format:
   - CLI output: "Drift Score: 0.3 (30%)" 
   - Table: Column "Violated", Column "Total", Calculated Percentage
   ```

2. **Rule Violation Logic** in data-model.md:
   ```
   Rule Violation:
   - A rule is "violated" if its condition evaluates to FALSE for the target code/repo
   - A rule is "satisfied" if its condition evaluates to TRUE
   - Example TDD Rule:
     * Condition: "All new .sh files have corresponding test_*.sh"
     * Violated if: .sh files exist without test files
     * Satisfied if: All .sh files paired with tests
   ```

3. **Acceptance Criteria for Drift Score Task** in tasks.md:
   ```
   ### Acceptance Criteria
   - Drift score ranges 0.0-1.0
   - Score correctly calculated: (violations / total) = decimal result
   - Edge cases handled:
     * 0 total rules → score = 0 (or error handled gracefully)
     * 1 rule, violated → score = 1.0
     * 10 rules, 3 violated → score = 0.3
   - Performance: Calculation <50ms for 100 rules
   ```

4. **Example Drift Score Output** in plan.md → "Terminal Output Examples":
   ```
   $ /specfarm drift
   
   Drift Analysis
   ==============
   Total Rules: 12
   Violated:    3
   Satisfied:   9
   
   Drift Score: 0.25 (25%)
   Status: ✓ ACCEPTABLE (below 0.3 threshold)
   
   Details:
   - Rule "TDD-001" (Test-First): VIOLATED
   - Rule "TDD-002" (No Silent Deletions): SATISFIED
   - Rule "STYLE-001" (ShellCheck): VIOLATED
   ...
   ```

### Resolution Actions
- [ ] Add "Drift Score Calculation" section to plan.md with numerical formula
- [ ] Add rule violation logic to data-model.md
- [ ] Update tasks.md Task 1 acceptance criteria to include drift score edge cases
- [ ] Create `tests/unit/test_drift_score_calculation.sh` with test cases (TDD-first)
- [ ] Document example outputs in quickstart.md

### Verification
- `grep "Drift Score" plan.md` → should show numerical formula (e.g., "(violations / total)")
- `grep "0.0\|1.0\|calculation" plan.md` → should define edge cases
- `bash tests/unit/test_drift_score_calculation.sh` → all tests GREEN

---

## Critical Issue #4: Reconcile Platform Scope

**Addresses**: C3 (Coverage Gap), Task 6 (Unmapped)  
**Severity**: 🔴 CRITICAL

### Problem Statement
- **Finding**: plan.md lists target platforms as "Linux, macOS, Termux" but Task 6 introduces Windows/PowerShell support; scope conflict.
- **Impact**: Unclear whether Phase 1 supports Windows; Task 6 appears disconnected from Phase 1 scope.
- **Current State**: plan.md target platform and Task 6 (PowerShell support) are misaligned.

### Requirements to Clarify

**Option A: Windows/PowerShell Deferred to Phase 3+**
1. Update plan.md:
   ```
   ### Target Platform (Phase 1)
   - Linux (Ubuntu, Debian, Fedora, CentOS)
   - macOS (10.15+)
   - Termux (Android)
   
   ### Future Scope (Phase 2+)
   - Windows (via WSL2 or PowerShell wrappers)
   ```
2. Remove Task 6 from Phase 1 tasks.md
3. Move Task 6 to Phase 3b tasks.md (Windows/PowerShell support)

**Option B: Windows/PowerShell as Phase 1 Quality Gate**
1. Update spec.md to explicitly include "Windows compatibility" as non-goal for Phase 1
2. Reframe Task 6 as "prepare for Phase 2 Windows support" (documentation/architecture only)
3. Update plan.md: "Phase 1 runs on Linux/macOS/Termux; PowerShell wrapper architecture documented for Phase 2"

### Recommended Direction
**Option A (Defer Windows to Phase 3+)** — Rationale:
- Phase 1 spec focuses on bash-only implementation (CLI-centric principle)
- Constitution (Phase 3b) added PowerShell allowance; Phase 1 predates this
- Phase 1 should stabilize core drift detection on Unix; Windows added later
- Cleaner scope: Phase 1 = core, Phase 3b = cross-platform

### Resolution Actions
- [ ] Decide: Windows/PowerShell in Phase 1 or defer? (Recommend: Defer to Phase 3b)
- [ ] Update plan.md target platforms section to explicitly exclude Windows for Phase 1
- [ ] Update spec.md non-goals: "Windows support (deferred to Phase 3b)"
- [ ] Move Task 6 from Phase 1 tasks.md to Phase 3b tasks.md (or remove entirely if Phase 1 only)
- [ ] Add note to tasks.md Task 6: "Deferred: Phase 1 scope is Linux/macOS/Termux only"

### Verification
- `grep -i "windows\|powershell" specs/001-specfarm-phase-1/plan.md` → should show "deferred" or be absent
- `grep -i "target platform" specs/001-specfarm-phase-1/plan.md` → should list Linux, macOS, Termux (no Windows)
- `wc -l specs/001-specfarm-phase-1/tasks.md` → should show 5 tasks (not 6) if Task 6 removed/moved

---

## Critical Issue #5: Add Threshold Specification

**Addresses**: U2 (Underspecification)  
**Severity**: 🔴 CRITICAL

### Problem Statement
- **Finding**: "1-2 lines of farm-colored output if drift exceeds a threshold" mentioned but threshold value not specified.
- **Impact**: Nudge/whisper logic cannot be implemented; acceptance tests cannot verify behavior.
- **Current State**: spec.md defines nudges but does not specify trigger threshold.

### Requirements to Add

1. **Drift Threshold Definition** in spec.md or plan.md:
   ```
   ### Nudge Trigger Threshold
   - Nudges are displayed when drift score EXCEEDS 0.3 (30%)
   - Whispers are displayed when drift score EXCEEDS 0.5 (50%)
   
   ### Threshold Justification
   - 0.3 (30%): Moderate drift; early warning before major violations
   - 0.5 (50%): High drift; urgent intervention needed
   - Below 0.3: System in acceptable state; no nudges
   ```

2. **Nudge Output Format** in plan.md → "Terminal Output Examples":
   ```
   DRIFT SCORE: 0.32 (32%)
   🚜 NUDGE: Drift above acceptable threshold (0.3). Review violated rules.
   ```

3. **Whisper Output Format** in plan.md:
   ```
   DRIFT SCORE: 0.52 (52%)
   ⚠️  WHISPER: Drift CRITICAL (0.5). Immediate action required.
   Violated Rules: TDD-001, STYLE-001, SECURITY-002
   Run '/specfarm drift --details' for full report.
   ```

4. **Configuration Option** in plan.md:
   ```
   Thresholds may be configurable via:
   - Environment variable: SPECFARM_NUDGE_THRESHOLD=0.4
   - Config file: .specfarm/config.sh with NUDGE_THRESHOLD=0.4
   (Deferred to Phase 2 if not Phase 1 scope)
   ```

5. **Acceptance Criteria** in tasks.md:
   ```
   - Nudges triggered when drift > 0.3 ✓
   - Whispers triggered when drift > 0.5 ✓
   - Threshold values documented in plan.md ✓
   - CLI respects thresholds in all outputs ✓
   - Farm-themed language used ("🚜 NUDGE", "⚠️  WHISPER") ✓
   ```

### Resolution Actions
- [ ] Add "Drift Threshold" section to plan.md with 0.3 (nudge) and 0.5 (whisper) values
- [ ] Add example nudge/whisper outputs to plan.md "Terminal Output Examples"
- [ ] Update tasks.md Task 4 acceptance criteria to verify threshold triggering
- [ ] Create `tests/unit/test_nudge_threshold.sh` (TDD-first tests)
- [ ] Document thresholds in spec.md Core Deliverables

### Verification
- `grep -A5 "Nudge Trigger\|threshold" specs/001-specfarm-phase-1/plan.md` → should show 0.3 and 0.5 values
- `bash tests/unit/test_nudge_threshold.sh` → test cases for drift > 0.3, > 0.5, etc. pass
- `grep "NUDGE\|WHISPER" specs/001-specfarm-phase-1/plan.md` → should show example outputs

---

## Resolution Workflow

### Step 1: Prioritization & Decision Points
**Decide on each issue**:
1. TDD/Test Specification: → Add Task 0 or expand Task 1 (RECOMMENDED)
2. `/specfarm xml export`: → Defer to Phase 2 (RECOMMENDED)
3. Drift Score Criteria: → Add formula to plan.md (MANDATORY)
4. Platform Scope: → Defer Windows to Phase 3b (RECOMMENDED)
5. Threshold Specification: → Add 0.3/0.5 values to plan.md (MANDATORY)

### Step 2: Update Specification Documents
**Update files in order**:
1. `specs/001-specfarm-phase-1/plan.md` — Add sections for drift score, thresholds, export formats
2. `specs/001-specfarm-phase-1/spec.md` — Update core deliverables, non-goals, export formats
3. `specs/001-specfarm-phase-1/data-model.md` — Add drift score calculation, rule violation logic
4. `specs/001-specfarm-phase-1/tasks.md` — Add "Test First" sections, update Task 1, remove/defer Task 6

### Step 3: Create Test Specifications
**Before implementation**:
1. Create `tests/phase-1-spec.md` documenting test framework and structure
2. Create test files (all initially RED):
   - `tests/unit/test_drift_score_calculation.sh`
   - `tests/unit/test_nudge_threshold.sh`
   - `tests/integration/test_cli_commands.sh`
   - `tests/e2e/test_drift_flow.sh`

### Step 4: Verification & Gate
**Before proceeding to implementation**:
1. Run `bash tests/phase-1-spec.sh --dry-run` → all tests RED ✓
2. Run `grep -r "0.3\|0.5" specs/001-specfarm-phase-1/` → thresholds present ✓
3. Run `/specfarm drift --version` → verify Phase 1 core commands ready ✓
4. Constitution compliance check: TDD sections present in all tasks ✓

### Step 5: Proceed to Implementation
**After all clarifications**:
- Run `/speckit.tasks` to regenerate task breakdown with resolved specs
- Run `/speckit.implement` to begin Phase 1 implementation

---

## Blocking Gate Checklist

✅ **MUST RESOLVE BEFORE IMPLEMENTATION**:

- [ ] **TDD/Test Specification**: Task 0 or Task 1 updated with "Test First" subsection
- [ ] **XML Export Scope**: Decision made (defer to Phase 2 or add to spec.md)
- [ ] **Drift Score Formula**: Documented in plan.md (e.g., "violations / total")
- [ ] **Platform Scope**: Windows explicitly deferred or removed from Phase 1 scope
- [ ] **Thresholds**: 0.3 (nudge) and 0.5 (whisper) values in plan.md
- [ ] **Test Files Created**: All test files created and RED (/speckit.implement will drive them GREEN)
- [ ] **Constitution Check**: Phase II (TDD) compliance verified via updated tasks.md

---

## Success Criteria

After resolving all critical issues, the Phase 1 specification MUST satisfy:

1. ✅ **No ambiguity in scope**: All questions answered, all decisions documented
2. ✅ **TDD-compliant**: Each task includes "Test First" subsection with failing tests
3. ✅ **Numerical precision**: Drift score formula, thresholds, and performance targets specified
4. ✅ **Platform clarity**: Windows support explicitly scoped (Phase 1 or deferred)
5. ✅ **Export clarity**: XML export scoped (Phase 1, Phase 2, or deferred)
6. ✅ **Constitution aligned**: Principle II (TDD), III.B (Aliases), VIII (Dependencies) verified
7. ✅ **Test coverage**: Unit, integration, e2e tests cover all Phase 1 deliverables
8. ✅ **Ready for implementation**: No clarifications remain; all tests RED; ready to drive GREEN

---

## Related Files to Update

- `specs/001-specfarm-phase-1/spec.md` — Core deliverables, non-goals, scope
- `specs/001-specfarm-phase-1/plan.md` — Drift score calculation, thresholds, export formats, platform scope
- `specs/001-specfarm-phase-1/data-model.md` — Drift score model, rule violation logic
- `specs/001-specfarm-phase-1/tasks.md` — Add "Test First" to all tasks, scope Task 6
- `specs/001-specfarm-phase-1/research.md` — Optional: document design decisions
- `tests/phase-1-spec.md` — NEW: Test framework, structure, naming conventions
- `tests/unit/test_*.sh` — NEW: Test files (initially RED)
- `tests/integration/test_*.sh` — NEW: Test files (initially RED)
- `tests/e2e/test_*.sh` — NEW: Test files (initially RED)

---

## Approval & Ratification

**Plan Owner**: [ASSIGN]  
**Phase 1 Lead**: [ASSIGN]  
**Constitution Steward**: [ASSIGN]  

**Approval Status**: ⏳ PENDING  
**Expected Completion**: [SET DATE]  
**Estimated Effort**: 2-3 days (specification + test creation)

---

**Version**: 1.0  
**Created**: 2026-03-15  
**Last Updated**: 2026-03-15  
**Source**: `specs/001-specfarm-phase-1/analyze1.md`
