# Agent Improvement Suggestions - Post PR #14 Analysis

**Context**: PR #14 had 0% test pass rate despite claiming "55/55 passing" with approval before CI ran. These improvements prevent similar issues.

---

## 🎯 Quick Overview (TL;DR)

### **5 Critical Improvements**

1. **Test-Before-Approve Rule** — Never write approval/completion before tests pass
2. **Incremental Test Validation** — Test after each task, not end
3. **Repeated Failure Detection** — Stop after 3 consecutive test failures
4. **Scope Verification** — Verify `git diff --stat` matches documented scope
5. **Test Pattern Validation** — Detect bash arithmetic bugs in test harness

### **Model Adjustments**

- ✅ **Keep Sonnet-4.5** for both agents (complexity requires it)
- ⚠️ **Add line limits** per phase (not per agent):
  - Task implementation: 500 lines max per task
  - Test creation: 300 lines max per test file
  - Approval writing: ONLY after all tests pass

### **Stop Conditions**

- ❌ Stop if same test fails 3 times in a row
- ❌ Stop if test pass rate drops below 50% after fixes
- ❌ Stop if scope grows >20% from documented plan
- ✅ Continue if tests pass and scope matches

---

## 📋 Detailed Improvements

### 1. specfarm.implement4speckit.agent.md

#### **Issue: Approval Before Testing**
PR #14 marked tasks "COMPLETE" before tests actually ran, then wrote approval document claiming success.

**Current Code (Lines 157-165)**:
```markdown
Mark task complete only if:
- [ ] All acceptance criteria met
- [ ] Constitution checkpoints validated
- [ ] Pre-commit validation passed
- [ ] Tests passed (if applicable)
```

**Problem**: "if applicable" is too vague; tests were skipped.

**Fix: Add Strict Test-Before-Complete Rule**
```markdown
#### D. Completion Check (STRICT MODE)

Mark task complete **ONLY AFTER ALL VALIDATIONS PASS**:
1. **BLOCKING**: Tests executed successfully (exit code 0)
2. **BLOCKING**: Test results match expected pass count
3. **BLOCKING**: No test suite timeouts or hangs
4. **BLOCKING**: Pre-commit validation passed
5. **BLOCKING**: Constitution checkpoints validated
6. **ADVISORY**: All acceptance criteria met

**CRITICAL RULE**: Never mark a task complete if:
- Tests exist but were skipped
- Tests ran but exit code indicates failure
- Test output claims "N passed" but exit code != 0
- git diff --stat shows more files changed than task documented

**Test Execution Requirements**:
- Run tests specified in task acceptance criteria
- If no tests specified AND task modifies src/, search for:
  - tests/unit/test_<module>.sh
  - tests/integration/test_<module>.sh
  - tests/e2e/test_<module>.sh
- If tests found, run them; if fail, task = INCOMPLETE
- Log actual exit code and pass count for audit trail
```

---

#### **Issue: Bash Test Harness Bug Not Detected**
The `((passed++))` pattern with `set -e` caused false failures, undetected during implementation.

**New Section: Test Pattern Validation**
```markdown
#### C2. Test Harness Pattern Validation (NEW)

**BEFORE** marking tests as passing, validate test file patterns:

**Check 1: Bash Arithmetic with set -e**
```bash
# BAD PATTERN (causes false failures):
_run_test "name" func && ((passed++)) || ((failed++))

# DETECTION:
grep -n '&& ((' tests/**/*.sh
# If found, flag as HIGH RISK test harness bug

# AUTO-FIX:
sed -i 's/then ((passed++))/then ((passed++)) || true/g' <file>
sed -i 's/else ((failed++))/else ((failed++)) || true/g' <file>
```

**Check 2: Exit Code Validation**
```bash
# After running test, verify exit code matches outcome:
bash test_file.sh
EXIT_CODE=$?
SUMMARY=$(tail -1 test_results.log | grep "Summary:")

# If summary says "0 failed" but EXIT_CODE=1, flag harness bug
```

**Auto-Fix Strategy**:
- If pattern detected: Apply fix, re-run test, verify exit code
- If still fails: Mark test as BLOCKED and report
- Log auto-fix action to `.specfarm/error-memory.md`
```

---

#### **Issue: No Repeated Failure Detection**
If a test fails 3 times in a row, agent should stop trying.

**Add to Section 5E (Cascade Failure Handling)**:
```markdown
#### E. Cascade Failure Handling with Repeated Failure Detection (ENHANCED)

**NEW: Repeated Failure Circuit Breaker**

Track failures per task/test:
```bash
declare -A failure_count
MAX_RETRIES=3

# When task validation fails:
task_id="$1"
((failure_count[$task_id]++))

if [[ ${failure_count[$task_id]} -ge $MAX_RETRIES ]]; then
  echo "❌ CIRCUIT BREAKER: Task $task_id failed $MAX_RETRIES times"
  echo "   Stopping implementation to prevent infinite retry loop"
  echo "   Last error: $error_details"
  echo ""
  echo "**HUMAN INTERVENTION REQUIRED**"
  echo "   Fix underlying issue before retrying"
  exit 1
fi
```

**Trigger Conditions**:
1. Same test file fails 3 consecutive times
2. Same task fails validation 3 times (syntax, pre-commit, tests)
3. Test pass rate drops below 50% after attempted fixes

**Actions**:
- Stop implementation immediately
- Report failure pattern to user
- Suggest root cause analysis
- Do NOT mark task complete
- Do NOT continue to next task
```

---

#### **Issue: No Scope Verification**
PR #14 changed 493 files but tasks.md documented 12-13.

**Add to Section 7 (Post-Implementation Validation)**:
```markdown
### 7. Post-Implementation Validation (ENHANCED)

**NEW: Scope Verification Check**

Before finalizing, verify git scope matches documented scope:
```bash
# Get actual changes
ACTUAL_FILES=$(git diff --name-only master | wc -l)
ACTUAL_ADDITIONS=$(git diff --stat master | tail -1 | awk '{print $4}')

# Parse tasks.md for documented scope
DOCUMENTED_FILES=$(grep -c "^- File:" tasks.md)

# Calculate variance
VARIANCE=$(echo "scale=2; ($ACTUAL_FILES - $DOCUMENTED_FILES) / $DOCUMENTED_FILES * 100" | bc)

if (( $(echo "$VARIANCE > 20" | bc -l) )); then
  echo "⚠️ SCOPE VARIANCE ALERT"
  echo "   Documented: $DOCUMENTED_FILES files"
  echo "   Actual: $ACTUAL_FILES files"
  echo "   Variance: ${VARIANCE}%"
  echo ""
  echo "   This suggests scope creep or undocumented changes."
  echo "   Review git diff to identify extra files."
  echo ""
  echo "**RECOMMENDED ACTION**: Stop and audit changes"
  exit 1
fi
```

**Acceptance Threshold**: ±20% variance allowed (to account for generated files, tests, docs)
```

---

#### **Issue: Incremental Testing Not Enforced**
Tests were run at the end, allowing multiple broken tasks to accumulate.

**Modify Section 5C (Validation Phase)**:
```markdown
#### C. Validation Phase (INCREMENTAL MODE)

**CRITICAL**: Validate **AFTER EACH TASK**, not at the end.

**Incremental Test Strategy**:
1. Implement Task N
2. Run syntax check → if fail, stop
3. Run pre-commit → if fail, stop
4. Run tests for Task N only → if fail, stop
5. Mark Task N complete ONLY IF all pass
6. Proceed to Task N+1

**Benefits**:
- Failures isolated to single task
- Easy rollback (git reset to last passing task)
- Prevents accumulation of broken tasks
- Faster feedback loop

**Implementation**:
```bash
for task in "${tasks[@]}"; do
  echo "▶ Implementing $task"
  
  # Implement task
  implement_task "$task"
  
  # IMMEDIATE validation (don't wait)
  if ! validate_task "$task"; then
    echo "❌ Task $task failed validation"
    echo "   Rolling back changes..."
    git checkout -- $(get_task_files "$task")
    
    # Mark task as FAILED in tasks.md
    sed -i "s/^### Task: $task/### Task: $task ❌ FAILED/" tasks.md
    
    # Check circuit breaker
    check_repeated_failures "$task"
    
    # Try independent tasks (if any)
    find_and_implement_independent_tasks
    break
  fi
  
  echo "✅ Task $task validated and complete"
done
```
```

---

### 2. specfarm.plan4speckit.agent.md

#### **Issue: No Pre-Implementation Test Coverage Estimate**
Plan didn't specify how many tests would be created or what pass rate to expect.

**Add to Section 4 (Generate Task Breakdown)**:
```markdown
#### Task Format (ENHANCED):
```markdown
### Task: [TASK_ID] - [Brief Title]

**Description**: [2-3 sentence description]

**Risk Level**: [LOW|MEDIUM|HIGH|CRITICAL]

**Test Coverage Plan** (NEW):
- Test files to create: [list test files]
- Expected test count: [N unit + N integration + N e2e]
- Success criteria: ≥[XX]% pass rate (typically ≥90% for LOW risk, ≥70% for MEDIUM)
- Test harness: [bash plain | BATS | pytest | other]

**Acceptance Criteria**:
- [ ] Criterion 1 (measurable, testable)
- [ ] Constitution checkpoint: [principle name]
- [ ] **Tests created and passing before marking complete** (NEW)
- [ ] **Exit code validation: tests exit 0 when passing** (NEW)
- [ ] **Scope verification: git diff matches documented files** (NEW)
- [ ] Pre-commit validation passes

**Implementation Notes**:
- File paths: [list files to create/modify]
- Dependencies: [list task IDs]
- **Stop conditions** (NEW):
  - If this task fails 3 times, stop implementation
  - If test pass rate < 50%, escalate to human
  - If scope variance > 20%, audit changes

**Estimated Confidence**: [XX%]
```
```

---

#### **Issue: No Handoff Safety Check**
Plan automatically handed off to implement without verifying tests exist or pass.

**Modify Section 8 (Handoff Conditions)**:
```markdown
### 8. Handoff Conditions & Execution (ENHANCED)

**Trigger automatic handoff to specfarm.implement4speckit only if ALL conditions met**:
1. Constitution Compliance = `✓ PASS`
2. Overall Confidence ≥ 70%
3. At least 1 manageable task
4. **NEW**: All task acceptance criteria include test requirements
5. **NEW**: Plan includes test coverage estimates (expected pass count)
6. **NEW**: No test harness pattern warnings flagged
7. User explicitly confirms: "Proceed to implementation?" [Y/n]

**PRE-HANDOFF SAFETY CHECKS** (NEW):
```bash
# Check 1: Test requirements present
if ! grep -q "Tests created and passing" tasks.md; then
  echo "⚠️ HANDOFF BLOCKED: tasks.md missing test requirements"
  echo "   Add 'Tests created and passing' to acceptance criteria"
  exit 1
fi

# Check 2: Expected test counts documented
if ! grep -q "Expected test count:" tasks.md; then
  echo "⚠️ HANDOFF BLOCKED: No test coverage plan"
  echo "   Add 'Expected test count: N' to each task"
  exit 1
fi

# Check 3: Scope documented
DOCUMENTED_FILES=$(grep -c "File paths:" tasks.md)
if [[ $DOCUMENTED_FILES -eq 0 ]]; then
  echo "⚠️ HANDOFF BLOCKED: No file paths documented"
  echo "   Add 'File paths:' section to implementation notes"
  exit 1
fi
```

**If ANY safety check fails**:
- Block automatic handoff
- Report missing elements to user
- Suggest re-running plan agent with missing details
- User can override with `--force-handoff` flag (not recommended)
```

---

#### **Issue: No Test Pattern Guidance**
Plan didn't specify that test harness should avoid bash arithmetic pitfalls.

**Add to Section 3 (Generate Detailed Plan)**:
```markdown
#### E. Test Strategy & Quality Gates (NEW)

**Test Harness Standards**:
- **For bash tests**: Use explicit if/then/else, not `&& ((var++))` patterns
  - GOOD: `if _run_test; then ((passed++)) || true; else ((failed++)) || true; fi`
  - BAD: `_run_test && ((passed++)) || ((failed++))`  (breaks with set -e)
  
- **Exit code contract**: Tests MUST exit 0 when all pass, 1 when any fail
  - Verify with: `bash test.sh && echo "PASS" || echo "FAIL"`
  
- **Summary validation**: Test summary output must match exit code
  - If output says "0 failed" but exit code = 1, test harness is broken
  
**Incremental Testing Policy**:
- Tests run after each task (not at end)
- Task marked complete only if its tests pass
- Stop implementation if 3 consecutive test failures

**Quality Gates**:
- Unit tests: ≥90% pass rate before integration tests
- Integration tests: ≥80% pass rate before e2e tests
- Overall: ≥85% pass rate before marking feature complete

**Pre-Commit Integration**:
- All tests run as part of pre-commit hook
- Feature not committable if tests fail
- CI re-runs all tests; results must match local
```

---

### 3. New Agent (Optional): specfarm.testvalidator4speckit

**Purpose**: Dedicated agent to validate test suite health before approvals.

**Triggers**:
- After implementation completes
- Before writing approval documents
- After test fixes (to verify fixes worked)

**Actions**:
1. Run all tests with explicit exit code capture
2. Parse test output for pass/fail counts
3. Verify exit codes match outcomes
4. Detect test harness bugs (bash arithmetic, etc.)
5. Compare scope (git diff) vs documented scope
6. Generate pass/fail report with actionable remediation

**Would prevent PR #14 scenario**: Agent would have caught 0% pass rate before approval was written.

---

## 🔧 Configuration Recommendations

### Model Selection

**Current**:
- implement4speckit: Sonnet-4.5
- plan4speckit: Sonnet-4.5

**Recommendation**: **Keep Sonnet-4.5 for both** ✅

**Rationale**:
- Haiku insufficient for complex validation logic
- Sonnet-4.5 handles multi-step reasoning needed for:
  - Detecting test harness bugs
  - Scope verification with variance calculation
  - Repeated failure pattern detection
  - Incremental test orchestration

**Alternative**: Use Haiku ONLY for single-task atomic operations:
- Individual file syntax check (one file at a time)
- Single test execution (one test at a time)
- But NOT for orchestration/validation across tasks

---

### Line Limits Per Phase (Argument Parameters)

Add configurable line limit arguments to both agents for surgical control:

#### **For specfarm.implement4speckit.agent.md**

**Add to "User Argument Patterns" section**:

```markdown
**Line limit controls** (per-phase surgical limits):
- `--max-lines-per-task=N` → Max lines of code per task implementation (default: 500)
- `--max-lines-per-test=N` → Max lines per test file creation (default: 300)
- `--max-lines-per-validation=N` → Max lines for validation logic (default: 100)
- `--unlimited-lines` → Remove all line limits (use with caution)

**Examples**:
```bash
# Conservative mode (smaller increments)
/specfarm.implement4speckit --max-lines-per-task=200 --max-lines-per-test=150

# Large refactor mode (bigger chunks)
/specfarm.implement4speckit --max-lines-per-task=1000 --max-lines-per-test=500

# Test-only mode (focus on test creation)
/specfarm.implement4speckit --task=T010 --max-lines-per-test=500
```

**Enforcement**:
- Validate line counts BEFORE writing files
- If limit exceeded, split into subtasks automatically
- Log limit violations to `.specfarm/error-memory.md`
- Offer user choice: split task OR increase limit for this task only
```

**Add validation logic in Section 5B (Implementation Phase)**:

```markdown
#### B. Implementation Phase (with Line Limit Validation)

**Step-by-step**:
1. Load acceptance criteria from task
2. Load constitution refs from task
3. **NEW: Check line limit parameters**:
   ```bash
   MAX_LINES_PER_TASK=${MAX_LINES_PER_TASK:-500}  # Default 500
   MAX_LINES_PER_TEST=${MAX_LINES_PER_TEST:-300}   # Default 300
   
   # Before creating/modifying file:
   ESTIMATED_LINES=$(estimate_implementation_size "$task")
   
   if [[ $ESTIMATED_LINES -gt $MAX_LINES_PER_TASK ]]; then
     echo "⚠️ LINE LIMIT WARNING"
     echo "   Task: $task"
     echo "   Estimated: $ESTIMATED_LINES lines"
     echo "   Limit: $MAX_LINES_PER_TASK lines"
     echo ""
     echo "Options:"
     echo "  1. Split task into subtasks (recommended)"
     echo "  2. Increase limit for this task: --max-lines-per-task=$ESTIMATED_LINES"
     echo "  3. Skip line limits: --unlimited-lines"
     
     read -p "Choose [1/2/3]: " choice
     case $choice in
       1) split_task_into_subtasks "$task"; return ;;
       2) MAX_LINES_PER_TASK=$ESTIMATED_LINES ;;
       3) MAX_LINES_PER_TASK=999999 ;;
     esac
   fi
   ```

4. Create/modify files as specified in task description
5. **NEW: Post-implementation line count verification**:
   ```bash
   for file in $(get_task_files "$task"); do
     ACTUAL_LINES=$(wc -l < "$file")
     LIMIT=$(get_limit_for_file_type "$file")  # Uses --max-lines-per-* flags
     
     if [[ $ACTUAL_LINES -gt $LIMIT ]]; then
       echo "❌ LINE LIMIT EXCEEDED: $file"
       echo "   Actual: $ACTUAL_LINES lines"
       echo "   Limit: $LIMIT lines"
       echo "   Variance: +$(( ACTUAL_LINES - LIMIT )) lines"
       echo ""
       echo "   Consider refactoring or splitting this file."
       # Log but don't block (advisory only)
     fi
   done
   ```
6. Apply constitution constraints
7. Add inline comments only where clarification needed
```

---

#### **For specfarm.plan4speckit.agent.md**

**Add to "User Input" section**:

```markdown
## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Supported Arguments**:
- `--max-lines-per-task=N` → Max lines for each task breakdown (default: 100)
- `--max-lines-plan=N` → Max total lines for plan.md (default: 2000)
- `--max-lines-test-strategy=N` → Max lines for test strategy section (default: 200)
- `--unlimited-lines` → No line limits (comprehensive planning mode)

**Examples**:
```bash
# Concise mode (minimal documentation)
/specfarm.plan4speckit --max-lines-per-task=50 --max-lines-plan=1000

# Detailed mode (comprehensive planning)
/specfarm.plan4speckit --max-lines-per-task=200 --max-lines-plan=5000

# Test-focused mode
/specfarm.plan4speckit --max-lines-test-strategy=500
```
```

**Add enforcement in Section 4 (Generate Task Breakdown)**:

```markdown
### 4. Generate Task Breakdown (with Line Limit Validation)

Create or update `tasks.md` using `.specify/templates/tasks-template.md` structure:

**NEW: Line Limit Enforcement**:
```bash
MAX_LINES_PER_TASK=${MAX_LINES_PER_TASK:-100}  # Default 100 lines per task
MAX_LINES_PLAN=${MAX_LINES_PLAN:-2000}          # Default 2000 lines total
MAX_LINES_TEST_STRATEGY=${MAX_LINES_TEST_STRATEGY:-200}  # Default 200

# Validate after generating each task
TASK_LINES=$(count_lines_for_task "$task_id")

if [[ $TASK_LINES -gt $MAX_LINES_PER_TASK ]]; then
  echo "⚠️ Task $task_id exceeds line limit"
  echo "   Actual: $TASK_LINES lines"
  echo "   Limit: $MAX_LINES_PER_TASK lines"
  echo ""
  echo "   Breaking into subtasks..."
  split_task "$task_id" "$MAX_LINES_PER_TASK"
fi

# Validate total plan.md size
PLAN_LINES=$(wc -l < plan.md)
if [[ $PLAN_LINES -gt $MAX_LINES_PLAN ]]; then
  echo "⚠️ plan.md exceeds total line limit"
  echo "   Actual: $PLAN_LINES lines"
  echo "   Limit: $MAX_LINES_PLAN lines"
  echo ""
  echo "   Consider:"
  echo "   1. Move detailed sections to separate docs (data-model.md, contracts/)"
  echo "   2. Increase limit: --max-lines-plan=$PLAN_LINES"
  echo "   3. Use --unlimited-lines flag"
fi
```

#### Task Format (per task):
```markdown
### Task: [TASK_ID] - [Brief Title]
<!-- Target: ≤ $MAX_LINES_PER_TASK lines per task -->

**Description**: [2-3 sentence description of what needs to be done]

**Risk Level**: [LOW|MEDIUM|HIGH|CRITICAL]

**Test Coverage Plan**:
<!-- Target: ≤ $MAX_LINES_TEST_STRATEGY lines for test strategy -->
- Test files to create: [list test files]
- Expected test count: [N unit + N integration + N e2e]
- Success criteria: ≥[XX]% pass rate
- Test harness: [bash plain | BATS | pytest | other]

**Acceptance Criteria**:
- [ ] Criterion 1 (measurable, testable)
- [ ] Constitution checkpoint: [principle name]
- [ ] Tests created and passing before marking complete
- [ ] Exit code validation: tests exit 0 when passing
- [ ] Scope verification: git diff matches documented files
- [ ] Pre-commit validation passes

**Implementation Notes**:
- File paths: [list files to create/modify]
- Dependencies: [list task IDs]
- Stop conditions:
  - If this task fails 3 times, stop implementation
  - If test pass rate < 50%, escalate to human
  - If scope variance > 20%, audit changes

**Estimated Confidence**: [XX%]

<!-- Line count for this task: [AUTO-CALCULATED] / $MAX_LINES_PER_TASK -->
```
```

---

### Default Line Limits (Recommended)

Based on PR #14 analysis and typical task complexity:

| Phase | Parameter | Default | Min | Max | Rationale |
|-------|-----------|---------|-----|-----|-----------|
| **Task Implementation** | `--max-lines-per-task` | 500 | 100 | 2000 | Keep tasks focused; 500 = ~1 screen of code |
| **Test Creation** | `--max-lines-per-test` | 300 | 50 | 1000 | Tests should be readable; 300 = ~1 test file |
| **Validation Logic** | `--max-lines-per-validation` | 100 | 20 | 500 | Validation simple; 100 = pre-commit hook size |
| **Plan Document** | `--max-lines-plan` | 2000 | 500 | 10000 | Comprehensive but scannable; 2K = ~10 pages |
| **Per-Task Breakdown** | `--max-lines-per-task` (plan) | 100 | 30 | 500 | Task description concise; 100 = 1-2 paragraphs |
| **Test Strategy** | `--max-lines-test-strategy` | 200 | 50 | 1000 | Strategy overview only; 200 = half page |

**Override Philosophy**:
- **Defaults work for 80% of cases** (small-to-medium tasks)
- **Double limits for complex tasks** (e.g., `--max-lines-per-task=1000` for refactors)
- **Use `--unlimited-lines` sparingly** (architectural plans, generated code)

**Rationale**: Limits prevent runaway generation but don't handicap complex reasoning.

---

### Stop Conditions (Circuit Breakers)

**Add to both agents**:
```yaml
circuit_breakers:
  repeated_test_failure: 3          # Stop after 3 same test fails
  test_pass_rate_minimum: 50%       # Stop if <50% passing
  scope_variance_maximum: 20%       # Stop if >20% files than documented
  validation_timeout: 300           # Stop test if >5min hang
  consecutive_syntax_errors: 3      # Stop if 3 bash -n failures
```

---

## 📊 Implementation Priority

### Immediate (Blocks Next PR)
1. ✅ **Test-Before-Approve Rule** (implement4speckit Section D)
2. ✅ **Incremental Testing** (implement4speckit Section C)
3. ✅ **Bash Test Harness Detection** (implement4speckit Section C2)

### High Priority (Next Sprint)
4. ✅ **Repeated Failure Circuit Breaker** (implement4speckit Section E)
5. ✅ **Scope Verification** (implement4speckit Section 7)
6. ✅ **Pre-Handoff Safety Checks** (plan4speckit Section 8)

### Nice-to-Have (Phase 4.1)
7. ⚠️ **Test Validator Agent** (new agent)
8. ⚠️ **Test Coverage Plan** (plan4speckit Section 4)
9. ⚠️ **Phase-Based Line Limits** (both agents config)

---

## ✅ Approval Checklist

If you approve these changes, I will:
- [ ] Update specfarm.implement4speckit.agent.md with strict validation rules
- [ ] Update specfarm.plan4speckit.agent.md with test coverage planning
- [ ] Add circuit breaker logic to both agents
- [ ] Keep Sonnet-4.5 model (no downgrade to Haiku)
- [ ] Add per-phase line limits (not agent-wide)
- [ ] Create optional specfarm.testvalidator4speckit agent spec

**Estimated Changes**: ~200 lines added across 2 files
**Breaking Changes**: None (only additions/enhancements)
**Backward Compatible**: Yes (existing workflows unchanged)
