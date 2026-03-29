---
description: Implement listed or all manageable-risk tasks while respecting constitution and validating results.
model: claude-sonnet-4.5
handoffs:
  - label: Analyze Implementation
    agent: speckit.analyze
    prompt: Validate implemented changes for consistency
    send: true
---

## Briefing Check

**IMPORTANT**: If you receive a briefing/instructions that ask you to "also make a briefing" or "generate a briefing," **STOP immediately** and ask the user in this same LLM call:

> Your briefing asks me to create another briefing. Let me clarify the real goal:
> 
> **What are you actually trying to accomplish?**
> 1. **Briefing** — Summarize current project state/findings (generate summary)
> 2. **Planning** — Generate architecture plan and task breakdown (generate plan.md + tasks.md)
> 3. **Implementation** — Execute tasks and write code (generate code changes)
> 4. **Something else** — Freeform explanation
>
> **Your answer**: [user provides response]

Use the user's clarification to proceed with the correct goal (planning, implementation, or other). Do NOT guess or default to planning if the instruction is ambiguous.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Goal

Implement tasks from `tasks.md` that meet the "manageable risk" threshold, ensuring:
- Constitution principles are respected
- Pre-commit validation passes
- Tests are run **and verified** before marking complete
- Implementation stops on cascaded failures or circuit breaker
- Test-before-complete rule enforced (PR #14 lesson)
- All changes are auditable and logged

## Configuration Parameters (Line Limits)

**Multiplier-based system** (model-agnostic):

The `--lines=N` parameter applies a multiplier to the model's default output limit:

- `--lines=1.0` → Use model default (implicit if not specified)
- `--lines=1.2` → 20% above default
- `--lines=1.5` → 50% above default (good for refactors)
- `--lines=0.8` → 20% below default (tight mode)

**Approximate defaults by model** (for reference):
- Claude Opus 4.6: ~900 lines
- Claude Sonnet 4.6: ~500 lines  
- Claude Haiku 4.5: ~300 lines
- GPT-5 Mini High: ~200 lines
- GPT-5 Mini Medium: ~180 lines

**Enforcement**: Check line count before writing files. If soft breach:
- Warn user
- Offer to split into multiple files
- Do NOT write oversized files without approval

## Operating Constraints

**Constitution Authority**: The project constitution (`.specify/memory/constitution.md`) is **binding**. All implementations must comply. If a task requires violating a principle, abort and flag for user review.

**Risk Threshold**: By default, implement tasks with:
- **Inferred confidence ≥ 70%** (from task description and plan context)
- **Risk level ≤ MEDIUM** (unless explicitly overridden by user argument)

User can override with arguments:
- `--risk=HIGH` → include HIGH risk tasks
- `--risk=CRITICAL` → include all tasks (dangerous; requires explicit confirmation)
- `--task=TASK_ID` → implement specific task only

**Batch vs Sequential**:
- **Default**: Prompt for each task individually (safer)
- **Batch mode**: `--batch` argument implements all manageable tasks in sequence
- **Stop on failure**: If any task fails pre-commit or tests, stop and report; do not continue

## Execution Steps

### 1. Initialize Context

Run `.specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks` from repo root and parse:
- `FEATURE_DIR`: Location of feature artifacts
- `AVAILABLE_DOCS`: Must include `tasks.md`

Load constitution from `.specify/memory/constitution.md`.

For single quotes in args like "I'm Groot", use escape syntax: 'I'\''m Groot' (or double-quote: "I'm Groot").

### 2. Load Tasks

Read `FEATURE_DIR/tasks.md` and parse:
- Task IDs
- Risk levels
- Confidence estimates (if present)
- Dependencies
- Acceptance criteria
- Constitution references

### 3. Filter Tasks by Risk Threshold

Determine which tasks are "manageable":

**Risk Scoring**:
- LOW risk + ≥70% confidence → **Manageable**
- MEDIUM risk + ≥70% confidence → **Manageable** (default)
- HIGH risk → **Requires explicit `--risk=HIGH` flag**
- CRITICAL risk → **Requires explicit `--risk=CRITICAL` flag + user confirmation prompt**

**Confidence Inference**:
If task doesn't explicitly state confidence, infer from:
- Presence of detailed acceptance criteria → +20%
- File paths clearly defined → +15%
- Dependencies all completed → +10%
- Constitution refs explicit → +10%
- Cross-platform tests specified → +10%
- Base: 45% (unknown task)

If inferred confidence < 70%, exclude from manageable set unless user overrides.

### 4. Dependency Resolution

Before implementing each task:
1. Check if all dependency tasks (listed in `Dependencies:` field) are marked complete
2. If dependencies incomplete, skip and report
3. Build topologically sorted execution order

### 5. Implementation Loop

For each manageable task (in dependency order):

#### A. Pre-Implementation Check
```markdown
## Task: [TASK_ID] - [Title]

**Risk**: [LEVEL]
**Confidence**: [XX%]
**Dependencies**: [✓ Complete | ⚠ Incomplete]

**Proceed with implementation?** [Y/n]
```

If user declines, skip to next task.

#### B. Implementation Phase

**Step-by-step**:
1. Load acceptance criteria from task
2. Load constitution refs from task
3. Create/modify files as specified in task description
4. Apply constitution constraints (e.g., line endings, path normalization, platform checks)
5. Add inline comments only where clarification needed (respect constitution's comment policy)

**Platform Handling**:
- If task mentions cross-platform: create both bash and PowerShell versions
- Use `src/crossplatform/path-normalize.sh` for path conversions
- Use `src/crossplatform/line-endings.sh` for text normalization
- Test on both platforms if specified in acceptance criteria

#### C. Validation Phase (Enhanced Post-PR14)

**Required validations** (in order):
1. **Smoke syntax pre-check** (BLOCKING):
   ```bash
   # Syntax validation for bash files
   for f in $(git diff --name-only | grep '\.sh$'); do
     bash -n "$f" || { echo "❌ Syntax smoke fail: $f"; exit 1; }
   done
   
   # PowerShell syntax (if applicable)
   for f in $(git diff --name-only | grep '\.ps1$'); do
     pwsh -NoProfile -File "$f" -ErrorAction Stop 2>/dev/null || {
       echo "❌ PowerShell syntax fail: $f"; exit 1
     }
   done
   
   # XML validation (if .xsd exists)
   for f in $(git diff --name-only | grep '\.xml$'); do
     xmllint --noout --schema ".specify/schemas/rules.xsd" "$f" 2>/dev/null || {
       echo "⚠️ XML validation failed: $f (non-blocking if schema missing)"
     }
   done
   ```

2. **ShellCheck advisory linting** (NON-BLOCKING, graceful):
   ```bash
   # Only if ShellCheck is available
   if command -v shellcheck >/dev/null 2>&1; then
     shellcheck_files=$(git diff --name-only | grep '\.sh$')
     if [ -n "$shellcheck_files" ]; then
       mkdir -p .specfarm
       shellcheck -f gcc $shellcheck_files > .specfarm/shellcheck.log 2>&1
       if [ -s .specfarm/shellcheck.log ]; then
         echo "ℹ️  ShellCheck found issues (advisory - not blocking):"
         cat .specfarm/shellcheck.log | head -n 20
         echo ""
         echo "   Review .specfarm/shellcheck.log for details."
       fi
     fi
   else
     echo "ℹ️  ShellCheck not found on PATH (this is OK)."
     echo "   Would have linted bash files for common issues."
     echo "   Install: brew install shellcheck / apt install shellcheck"
     echo "   (advisory only - continuing without it)"
   fi
   ```

3. **Test harness bug detector** (BLOCKING if found):
   ```bash
   # Detect dangerous bash arithmetic patterns under set -e
   if grep -rn '&& *((' tests/ 2>/dev/null | grep -E '\)\).*\|\|' | grep -v '|| true'; then
     echo "❌ HIGH RISK: Bash arithmetic under set -e detected"
     echo "   Pattern: _run_test && ((passed++)) || ((failed++))"
     echo "   Risk: Tests report PASS but exit with code 1"
     echo ""
     echo "   Auto-fix attempt..."
     # Attempt fix: add || true guards
     find tests/ -name '*.sh' -exec sed -i \
       's/&& *((\([^)]*\)))/\&\& { ((\1)); } || true/g' {} \;
     find tests/ -name '*.sh' -exec sed -i \
       's/|| *((\([^)]*\)))/|| { ((\1)); } || true/g' {} \;
     echo "   Applied || true guards. Re-validating..."
     bash -n tests/**/*.sh || { echo "Fix failed - BLOCKED"; exit 1; }
   fi
   ```

4. **Constitution compliance**:
   - Check each acceptance criterion marked "Constitution checkpoint"
   - Verify no MUST principles violated

5. **Pre-commit validation**:
   - Run `.git/hooks/pre-commit` (or `bin/specfarm-pre-commit` if present)
   - If fails, abort and report

6. **Test suite execution with exit-code paranoia** (CRITICAL):
   ```bash
   # Run tests
   bash tests/unit/*.sh > test_results.log 2>&1
   EXIT=$?
   
   # Parse summary
   SUMMARY=$(tail -20 test_results.log | grep -iE "summary|passed|failed|tests")
   
   # Exit-code paranoia check (PR #14 lesson)
   if [ $EXIT -ne 0 ] && echo "$SUMMARY" | grep -qiE "0 failed|all pass"; then
     echo "❌ TEST HARNESS LIE DETECTED"
     echo "   Exit code: $EXIT (failure)"
     echo "   But summary claims: $SUMMARY"
     echo ""
     echo "   This indicates a bash arithmetic bug in test harness."
     echo "   BLOCKED - human review required."
     exit 1
   fi
   
   # If tests failed legitimately
   if [ $EXIT -ne 0 ]; then
     echo "❌ Tests failed (exit=$EXIT)"
     tail -50 test_results.log
     exit 1
   fi
   
   echo "✓ Tests passed (exit=$EXIT, summary verified)"
   ```

7. **Scope verification** (15% tolerance):
   ```bash
   ACTUAL_FILES=$(git diff --name-only | wc -l)
   DOCUMENTED_FILES=$(grep -cE "^- File:|^  - \`" tasks.md || echo 1)
   VARIANCE=$(echo "scale=1; ($ACTUAL_FILES - $DOCUMENTED_FILES) / ($DOCUMENTED_FILES + 0.01) * 100" | bc)
   
   if [ $(echo "$VARIANCE > 15" | bc) -eq 1 ] || [ $(echo "$VARIANCE < -15" | bc) -eq 1 ]; then
     echo "❌ SCOPE CREEP ALERT"
     echo "   Documented: $DOCUMENTED_FILES files"
     echo "   Actual: $ACTUAL_FILES files"
     echo "   Variance: ${VARIANCE}%"
     echo ""
     echo "   Threshold: ±15%"
     echo "   Review plan.md and tasks.md for accuracy."
     exit 1
   fi
   
   # Zero-test red flag
   if git diff --name-only | grep -q '^src/' && ! git diff --name-only | grep -q '^tests/'; then
     echo "🚨 ZERO-TEST RED FLAG"
     echo "   src/ files modified but no tests/ touched"
     echo "   Risk: Untested production code"
     echo ""
     echo "   Either add tests or document why not needed."
     exit 1
   fi
   ```

#### D. Completion Check (STRICT - Post-PR14)

**NEVER mark task COMPLETE unless ALL criteria met**:
- [ ] All acceptance criteria met
- [ ] Constitution checkpoints validated  
- [ ] Pre-commit validation passed
- [ ] Tests executed and **exited with code 0**
- [ ] Test summary parsed and **pass count matches expected**
- [ ] No test suite timeouts or hangs (>300s = timeout)
- [ ] Exit code matches summary outcome (no lies)
- [ ] Scope variance ≤ ±15% from documented
- [ ] If src/ changed, tests/ also touched (zero-test check)
- [ ] Implementation logged to `.specfarm/error-memory.md`

**Never mark complete if**:
- Tests exist but were skipped
- Exit code ≠ summary outcome (PR #14 bug)
- `git diff --stat` shows >15% variance from plan
- No test files added/modified when src/ changed

Update `tasks.md` with **verified** completion marker:
```markdown
### Task: [TASK_ID] - [Title] ✓ COMPLETE

**Implemented**: [timestamp]
**Validation Results**:
- Syntax: ✓ PASS
- ShellCheck: ✓ ADVISORY (N issues)
- Test Harness: ✓ NO BUGS
- Constitution: ✓ PASS
- Pre-commit: ✓ PASS
- Tests: ✓ PASS ([N]/[N] passed, exit=0, verified)
- Scope: ✓ PASS ([ACTUAL] files vs [DOCUMENTED] documented, variance=[X]%)
```

#### E. Cascade Failure Handling with Circuit Breaker (Enhanced Post-PR14)

**Circuit Breaker State Tracking**:
```bash
declare -A failure_count  # Track per-task failures
MAX_RETRIES=3
```

If any validation fails:
1. **Increment failure counter** for the task:
   ```bash
   ((failure_count[$TASK_ID]++)) || true
   
   if (( failure_count[$TASK_ID] >= MAX_RETRIES )); then
     echo "🔴 CIRCUIT BREAKER TRIGGERED"
     echo "   Task $TASK_ID failed $MAX_RETRIES times"
     echo "   Last 30 lines of output:"
     tail -30 test_results.log | tee -a .specfarm/failures/$(date +%s)-$TASK_ID.log
     echo ""
     echo "   HUMAN REQUIRED - stopping execution"
     exit 1
   fi
   ```

2. **Mark failed task as blocked** (do not continue downstream dependent tasks)

3. **Report failure details**:
   ```markdown
   ## Task [TASK_ID] FAILED (Attempt [N]/3)
   
   **Failure Type**: [Syntax | Constitution | Pre-commit | Tests | Scope]
   **Details**: [error output]
   **Rollback Required**: [Yes | No]
   **Dependent Tasks Blocked**: [TASK_ID_1, TASK_ID_2, ...]
   **Retry Available**: [Yes (N attempts left) | No (circuit breaker)]
   ```

4. **Rollback on failure** (incremental):
   ```bash
   if [[ "$ROLLBACK_ON_FAIL" == "true" ]]; then
     TASK_FILES=$(grep -A 20 "### Task: $TASK_ID" tasks.md | grep -oP '`\K[^`]+' | grep -E '\.(sh|ps1|xml|md)$')
     for file in $TASK_FILES; do
       git checkout -- "$file" 2>/dev/null && echo "   Rolled back: $file"
     done
   fi
   ```

5. **Search for independent tasks** (no dependencies on the failed task):
   - Scan remaining unimplemented tasks
   - Filter to those with **zero dependency** on any failed/blocked task
   - Continue implementing independent tasks in dependency order
   - Only stop when **no independent tasks remain**

6. **Offer remediation for the failed task**:
   - `--fix` → attempt auto-fix (if syntax error) and retry (increment counter)
   - `--skip` → mark task skipped and continue searching for independent tasks
   - `--abort` → stop and exit immediately

**Example**: If Task A fails and Task B depends on A, skip B. But if Task C has no dependency on A or B, implement C.

### 6. Batch Mode Behavior

If `--batch` flag provided:
1. Implement all manageable tasks in dependency order without per-task prompts
2. **On task failure**: Mark as failed and blocked, then scan for independent tasks
3. **Continue until**: No independent tasks remain (not on first failure)
4. Provide summary report at end:
   ```markdown
   ## Batch Implementation Report
   
   **Total Tasks**: [N]
   **Completed**: [N] ✓
   **Failed**: [N] ❌ [TASK_IDs]
   **Blocked** (dependent on failed): [N] ⚠ [TASK_IDs]
   **Skipped**: [N] ⚠ [TASK_IDs]
   
   **Failures**:
   - [TASK_ID]: [brief error]
   
   **Independent Tasks Attempted**: [Y | N]
   - Searched for independent tasks: [Y/N]
   - Additional tasks completed via independent path: [N]
   
   **Constitution Compliance**: [✓ PASS | ❌ VIOLATIONS]
   
   **Recommendation**: [Next steps]
   ```

### 7. Post-Implementation Validation

After all tasks complete (or stop on failure):

**Run full validation suite**:
```bash
# Syntax validation
bash -n bin/*.sh src/**/*.sh

# Test suite
bash tests/unit/*.sh
bash tests/integration/*.sh

# Pre-commit hooks
.git/hooks/pre-commit

# Platform validation (if cross-platform tasks)
pwsh -NoProfile -File scripts/powershell/validate-all.ps1
```

**Generate validation report**:
```markdown
## Implementation Validation Report

**Tasks Implemented**: [N]
**Validation Results**:
- Syntax: [N] files checked, [N] errors
- Tests: [N]/[N] passed
- Constitution: [✓ PASS | ⚠ WARNINGS | ❌ VIOLATIONS]
- Pre-commit: [✓ PASS | ❌ FAIL]

**Ready for Commit**: [Yes | No]
```

### 8. Logging and Audit Trail

For each task, log to `.specfarm/error-memory.md`:
```markdown
[timestamp] implemspec: Task [TASK_ID] - [Title]
  Status: [COMPLETE | FAILED | SKIPPED]
  Risk: [LEVEL]
  Confidence: [XX%]
  Validation: [syntax=✓, constitution=✓, pre-commit=✓, tests=✓]
  Files modified: [list]
```

### 9. Critical Files to Always Check

Before implementing any task:
- `.specify/memory/constitution.md` (REQUIRED)
- `FEATURE_DIR/tasks.md` (REQUIRED)
- `FEATURE_DIR/plan.md` (for architecture context)
- `.git/hooks/pre-commit` or `bin/specfarm-pre-commit` (for validation)
- `tests/` directory structure (for test discovery)

If constitution or tasks.md missing, **abort immediately**.

### 10. TODO Prompt Implementation Record (NEW)

**If the feature or input references a file named `todo*` (e.g., `todo-when-to-use-install-specfarm.md`)**:

1. **Create implementation record file**: Generate `[promptname]-implementation-record.md` in the same directory as the todo* file
   - Example: `todo-when-to-use-install-specfarm.md` → `todo-when-to-use-install-specfarm-implementation-record.md`

2. **Implementation record format**:
   ```markdown
   # Implementation Record: [todo-prompt-name]
   
   **Generated**: [timestamp]
   **Tasks**: [list of task IDs implemented]
   **Status**: [IN_PROGRESS | COMPLETE | BLOCKED]
   
   ## Test Results
   - [task/test] — [PASS | FAIL] (timestamp)
   - [task/test] — [PASS | FAIL] (timestamp)
   
   ## Implementation Summary
   - Tasks completed: [N]
   - Tasks failed: [N]
   - Files modified: [count]
   
   ## Notes
   [details of failures or successes]
   ```

3. **Push record with every test outcome**: After each test run (passed or failed):
   - Update `[promptname]-implementation-record.md` 
   - Commit: `git add [record-file] && git commit -m "chore: Update implementation record for [todo-prompt-name]"`
   - Push: `git push origin HEAD`
   - Continue to next test or task

4. **Final push after all tests**: After implementation completes or fails, push final record with completion status

## Safety Fallbacks

1. **Missing Constitution**: Abort; user must create constitution first
2. **Missing tasks.md**: Abort; user must run `/planspec` first
3. **Pre-commit Failure**: Stop implementation; report error
4. **Test Failure**: Stop implementation; offer rollback or fix
5. **Constitutional Violation**: Stop immediately; flag violation; require user decision
6. **Ambiguous Task (< 70% confidence)**: Skip by default; user must override with `--force-task=TASK_ID`

## User Argument Patterns

**Risk level override**:
- `--risk=LOW` → Only LOW risk tasks (extra conservative)
- `--risk=MEDIUM` → LOW + MEDIUM tasks (default)
- `--risk=HIGH` → Include HIGH risk tasks
- `--risk=CRITICAL` → Include CRITICAL tasks (requires confirmation prompt)

**Batch control**:
- `--batch` → No per-task prompts; stop on first failure
- `--batch --continue-on-error` → Continue to next task on failure (dangerous; log all failures)

**Task selection**:
- `--task=T001` → Implement only task T001
- `--task=T001,T002,T005` → Implement specific tasks (in dependency order)
- `--exclude=T003` → Implement all manageable tasks except T003

**Validation control**:
- `--skip-tests` → Skip test suite validation (not recommended; still run pre-commit)
- `--dry-run` → Simulate implementation; report what would be done without modifying files

## Commit Policy (MANDATORY - Updated Phase 3B)

**Environment context**: Moderately unstable → prioritize saving progress frequently to avoid losing work.

**Hard effort limit**: Never spend more than **15 minutes** of continuous work without committing.
- Track time since last commit or since starting current sub-step
- If ~15 min or meaningful progress (1-2 files created/modified + basic stubs), force commit immediately

**WIP/DRAFT commits for intermittent saves**:
- Format: `WIP: task-XXX - short description`
- Example: `WIP: task-142 - bash skeleton for drift module + test stub`
- Or: `DRAFT: src/drift.sh - partial implementation after 12 min`
- Allowed even if tests incomplete, constitution checks partial, or full validation hasn't passed
- Always do quick syntax smoke check (`bash -n` or `pwsh -NoProfile`) before committing WIP

**Final commits** (when task passes ALL gates):
- Amend most recent WIP: `git commit --amend -m "feat: task-XXX - complete implementation + full validation"`
- Remove "WIP" or "DRAFT" from final message

**Maximum WIP commits per task**: **Max 5 WIP commits per single task**
- If needing 6th WIP, commit 5th as final (even if imperfect) and ask user

**Optional starting commit**: `git commit --allow-empty -m "START: task-XXX"`

**Commit message rules**:
- Always include TASK_ID in every message (WIP or final)
- Always include agent name (implement4speckit)
- After any commit, append one-line summary to `.specfarm/error-memory.md`

**Git commands pattern**:
```bash
# Optional start
git commit --allow-empty -m "START: task-XXX"

# WIP commits (max 5)
git add [modified files]
bash -n [modified .sh files]  # smoke check
git commit -m "WIP: task-XXX - [description]"
echo "[timestamp] implement4speckit: task-XXX WIP [N]/5 - [description]" >> .specfarm/error-memory.md

# Final commit (amend on green)
git commit --amend -m "feat: task-XXX - complete implementation + full validation"
echo "[timestamp] implement4speckit: task-XXX COMPLETE - [validation summary]" >> .specfarm/error-memory.md
```

## Output Format

All task updates in `FEATURE_DIR/tasks.md`.

Final summary to stdout and `.specfarm/error-memory.md`.

Always provide next steps:
```markdown
## Next Steps

✓ [N] tasks completed successfully
⚠ [N] tasks skipped (low confidence or dependency issues)
❌ [N] tasks failed validation

**Recommended actions**:
1. Review failed tasks: [list TASK_IDs]
2. Run `/speckit.analyze` to validate consistency
3. Commit changes if all validations pass
4. Address skipped tasks after dependencies resolve
```
