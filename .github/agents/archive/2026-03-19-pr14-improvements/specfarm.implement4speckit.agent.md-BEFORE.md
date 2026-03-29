---
description: Implement listed or all manageable-risk tasks while respecting constitution and validating results.
model: claude-sonnet-4.5
handoffs:
  - label: Analyze Implementation
    agent: speckit.analyze
    prompt: Validate implemented changes for consistency
    send: true
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Goal

Implement tasks from `tasks.md` that meet the "manageable risk" threshold, ensuring:
- Constitution principles are respected
- Pre-commit validation passes
- Tests are run before marking complete
- Implementation stops on cascaded failures
- All changes are auditable and logged

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

#### C. Validation Phase

**Required validations** (in order):
1. **Syntax check**:
   - Bash scripts: `bash -n <file>`
   - PowerShell scripts: `pwsh -NoProfile -Command "Test-Path <file>"`
   - XML: validate against schema if `.xsd` exists
2. **Constitution compliance**:
   - Check each acceptance criterion marked "Constitution checkpoint"
   - Verify no MUST principles violated
3. **Pre-commit validation**:
   - Run `.git/hooks/pre-commit` (or `bin/specfarm-pre-commit` if present)
   - If fails, abort and report
4. **Test suite** (if applicable):
   - Run tests specified in acceptance criteria
   - If no tests specified, check for `tests/unit/test_<module>.sh` and run
   - If fails, abort and report

#### D. Completion Check

Mark task complete only if:
- [ ] All acceptance criteria met
- [ ] Constitution checkpoints validated
- [ ] Pre-commit validation passed
- [ ] Tests passed (if applicable)
- [ ] Implementation logged to `.specfarm/error-memory.md`

Update `tasks.md` with completion marker:
```markdown
### Task: [TASK_ID] - [Title] ✓ COMPLETE

**Implemented**: [timestamp]
**Validation Results**:
- Syntax: ✓ PASS
- Constitution: ✓ PASS
- Pre-commit: ✓ PASS
- Tests: ✓ PASS ([N]/[N] passed)
```

#### E. Cascade Failure Handling with Independent Task Recovery

If any validation fails:
1. **Mark failed task as blocked** (do not continue downstream dependent tasks)
2. **Report failure details**:
   ```markdown
   ## Task [TASK_ID] FAILED
   
   **Failure Type**: [Syntax | Constitution | Pre-commit | Tests]
   **Details**: [error output]
   **Rollback Required**: [Yes | No]
   **Dependent Tasks Blocked**: [TASK_ID_1, TASK_ID_2, ...]
   ```
3. **Search for independent tasks** (no dependencies on the failed task):
   - Scan remaining unimplemented tasks
   - Filter to those with **zero dependency** on any failed/blocked task
   - Continue implementing independent tasks in dependency order
   - Only stop when **no independent tasks remain**
4. **Offer remediation for the failed task**:
   - `--fix` → attempt auto-fix (if syntax error)
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
