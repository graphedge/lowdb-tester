---
description: Fully flesh out implementation plans and tasks while respecting constitution and home repo conventions. If plan/tasks pass validation and user confirms, automatically hands off to specfarm.implement4speckit for implementation in the same cloud run.
model: claude-sonnet-4.5
handoffs:
  - label: Analyze Plan Quality
    agent: speckit.analyze
    prompt: Run consistency analysis on generated plan and tasks
    send: true
  - label: Implement Plan
    agent: specfarm.implement4speckit
    prompt: Implement manageable-risk tasks from the plan generated above. Start with per-task prompts by default.
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

Generate a fully detailed implementation plan and task breakdown for a feature, ensuring:
- Every high-level goal breaks into numbered tasks with acceptance criteria
- Risk levels are estimated (LOW/MEDIUM/HIGH/CRITICAL)
- Tasks link to relevant constitution principles, speckit flows, and home repo conventions
- Cross-platform requirements are identified
- Pre-commit and validation checkpoints are embedded

## Operating Constraints

**Constitution Authority**: The project constitution (`.specify/memory/constitution.md`) is **binding**. All plans must respect constitutional principles. If a principle conflicts with user requirements, flag it explicitly and ask for clarification before proceeding.

**Home Repo Context**: Always load and respect:
- `.specify/memory/constitution.md` (principles and constraints)
- `.github/CODEOWNERS` (if present; ownership context)
- `.specify/scripts/bash/check-prerequisites.sh` output (current feature context)
- Any coding standards or workflow templates in `.github/`

**External References**: May reference open speckit documentation (GitHub repos, CLI help) for background context, but all decisions must ground in home repo files.

**Ambiguity Tolerance**: Up to 70% confidence is acceptable. If below 70%, pause and ask user for clarification rather than guessing.

## Execution Steps

### 1. Initialize Context

Run `.specify/scripts/bash/check-prerequisites.sh --json` from repo root and parse:
- `FEATURE_DIR`: Location of current feature artifacts
- `AVAILABLE_DOCS`: List of existing documents (spec.md, plan.md, etc.)

Load constitution from `.specify/memory/constitution.md`.

For single quotes in args like "I'm Groot", use escape syntax: 'I'\''m Groot' (or double-quote: "I'm Groot").

### 2. Load Input Artifacts

Read from `FEATURE_DIR`:
- **spec.md** (if exists): User stories, requirements, priorities
- **plan.md** (if exists): Tech stack, architecture decisions
- **research.md** (if exists): Technical decisions and trade-offs
- **data-model.md** (if exists): Entity definitions
- **contracts/** (if exists): Interface specifications

If no spec.md exists, create one from user input first.

### 3. Generate Detailed Plan

Create or update `plan.md` with:

#### A. Tech Stack & Dependencies
- List all libraries, frameworks, and tools
- Version constraints (from constitution if mandated)
- Installation/setup requirements

#### B. Architecture Overview
- Component structure (directories, modules, services)
- Data flow diagrams (textual)
- Integration points

#### C. Cross-Platform Considerations
- Bash vs PowerShell requirements
- Path normalization needs (if file I/O involved)
- Line-ending handling (if text processing)
- Platform-specific constraints from constitution

#### D. Risk Assessment
- Identify HIGH/CRITICAL risk components
- Dependencies on external services
- Breaking changes to existing code

### 4. Generate Task Breakdown

Create or update `tasks.md` using `.specify/templates/tasks-template.md` structure:

#### Task Format (per task - Enhanced Post-PR14):
```markdown
### Task: [TASK_ID] - [Brief Title]

**Description**: [2-3 sentence description of what needs to be done]

**Risk Level**: [LOW|MEDIUM|HIGH|CRITICAL]

**Files Modified/Created**:
- `path/to/file1.sh` (modify)
- `path/to/file2.xml` (create)
- `tests/unit/test_feature.sh` (create) ← MANDATORY if src/ touched

**Test Coverage Plan** (MANDATORY - Post-PR14):
- **Test Files**: 
  - `tests/unit/test_[module].sh` (N tests expected)
  - `tests/integration/test_[feature].sh` (M tests expected)
- **Test Harness**: [bash | BATS | pytest | other]
- **Success Criteria**: 
  - ≥ XX% pass rate required
  - Exit code 0 mandatory
  - Exit code must match summary (no bash arithmetic bugs)
  - Test-before-complete: Tests pass BEFORE marking task COMPLETE

**Acceptance Criteria**:
- [ ] Criterion 1 (measurable, testable)
- [ ] Criterion 2
- [ ] Tests created and passing **before** COMPLETE marker
- [ ] Exit code matches test summary (no lies)
- [ ] Scope variance ≤ ±15%
- [ ] Constitution checkpoint: [principle name from constitution.md]
- [ ] Cross-platform validation: [if applicable, specify bash + powershell test]
- [ ] Pre-commit validation passes
- [ ] If src/ modified, tests/ also touched (zero-test check)

**Stop Conditions** (Circuit Breaker):
- [ ] 3× consecutive failure → halt
- [ ] Pass rate drops below 50% → escalate
- [ ] Scope variance > 15% → audit

**Implementation Notes**:
- File paths: [list files to create/modify]
- Dependencies: [list task IDs this depends on]
- Constitution refs: [link to specific principles from constitution.md]

**Estimated Confidence**: [XX%] (likelihood of success on first attempt)
```

#### Task Organization:
- Group by user story or feature area
- Dependency-order within each group
- Mark parallel-safe tasks with `[P]`
- Separate setup/infrastructure tasks from feature tasks

### 5. Constitution Checkpoint Validation

For each task, verify:
- Does it respect MUST principles from constitution?
- Are mandated quality gates included in acceptance criteria?
- Are platform-specific requirements called out?

If any task conflicts with constitution, **flag it explicitly** and suggest either:
1. Modify the task to comply
2. Ask user if constitutional principle should be updated (separate workflow)

### 6. Output Generation

Create two files in `FEATURE_DIR`:

**plan.md**: Full implementation plan with architecture, stack, and risk analysis

**tasks.md**: Dependency-ordered task list with acceptance criteria and risk levels

### 7. Confidence Report & Automatic Handoff Decision

Provide a summary with explicit handoff trigger:
```markdown
## Plan Generation Summary

**Total Tasks**: [N]
**Risk Distribution**:
- LOW: [N] tasks
- MEDIUM: [N] tasks
- HIGH: [N] tasks
- CRITICAL: [N] tasks

**Constitution Compliance**: [✓ PASS | ⚠ WARNINGS | ❌ CONFLICTS]

**Estimated Overall Confidence**: [XX%]
- [XX%] of tasks have ≥70% success likelihood
- [N] tasks require clarification before implementation

**Automatic Handoff to specfarm.implement4speckit**:
- ✓ TRIGGERED if: Constitution Compliance = PASS AND Confidence ≥ 70% AND (N manageable tasks > 0)
- User will be prompted: "Hand off to specfarm.implement4speckit for immediate implementation? [Y/n]"
- If YES: specfarm.implement4speckit runs in same cloud session with --batch flag
- If NO: User retains plan/tasks for manual review or later execution

**Recommended Next Steps**:
1. Review flagged constitutional conflicts [if any]
2. If handoff skipped: Run `/speckit.analyze` for consistency check
3. If handoff skipped: Run `/specfarm.implement4speckit` manually when ready
```

### 8. Handoff Conditions & Execution (Stricter Post-PR14)

**Trigger automatic handoff to specfarm.implement4speckit only if ALL conditions met**:
1. Constitution Compliance = `✓ PASS` (no MUST principle violations)
2. All tasks have **Test Coverage Plan** section (mandatory)
3. All tasks that touch src/ also touch tests/ (zero-test check)
4. All tasks have explicit "Test-before-complete" checkpoint
5. All tasks document exit-code validation strategy
6. Scope estimates present (file counts documented)
7. No test harness anti-patterns flagged (e.g., `&& ((passed++))` without guards)
2. Overall Confidence ≥ 70% (majority of tasks achievable)
3. At least 1 manageable task (LOW/MEDIUM risk, ≥70% confidence)
4. User explicitly confirms: "Proceed to implementation?" [Y/n]

**If triggered**:
- Hand off to specfarm.implement4speckit with context:
  - FEATURE_DIR path
  - tasks.md content (already generated)
  - Risk/confidence thresholds (inferred from plan)
  - Default mode: `--batch` (implement all manageable tasks sequentially, stop on first failure)
- specfarm.implement4speckit runs in same cloud session; user sees continuous progress
- If specfarm.implement4speckit completes successfully, return to planspec for summary

**If NOT triggered**:
- Plan/tasks saved to FEATURE_DIR for later review
- User can run specfarm.implement4speckit manually with custom flags (--risk=HIGH, --task=TASK_ID, etc.)
- User can run speckit.analyze first for consistency check

### 9. Critical Files to Always Check

Before finalizing plan, always verify existence and load if present:
- `.specify/memory/constitution.md` (REQUIRED)
- `.github/CODEOWNERS` (for ownership context)
- `.specify/templates/tasks-template.md` (for task structure)
- `.specify/scripts/bash/check-prerequisites.sh` (for repo context)
- Any `.github/workflows/*.yml` files (for CI/CD constraints)

If constitution is missing, **abort and instruct user to run `/speckit.constitution` first**.

### 10. TODO Prompt Implementation Record (NEW)

**If the feature or input references a file named `todo*` (e.g., `todo-when-to-use-install-specfarm.md`)**:

1. **Create implementation record file**: Generate `[promptname]-implementation-record.md` in the same directory as the todo* file
   - Example: `todo-when-to-use-install-specfarm.md` → `todo-when-to-use-install-specfarm-implementation-record.md`

2. **Implementation record format**:
   ```markdown
   # Implementation Record: [todo-prompt-name]
   
   **Generated**: [timestamp]
   **Plan Generated**: [yes/no]
   **Tasks Generated**: [N]
   **Status**: [PLANNING | AWAITING_IMPLEMENTATION | IN_PROGRESS | COMPLETE | BLOCKED]
   
   ## Test Results
   - [task/test] — [PASS | FAIL] (timestamp)
   - [task/test] — [PASS | FAIL] (timestamp)
   
   ## Notes
   [user/agent notes]
   ```

3. **Push record with every test outcome**: After each test run (passed or failed), commit and push `[promptname]-implementation-record.md` to remote before continuing

4. **Update record before each test**: Log the test name, result (PASS/FAIL), and timestamp

## Safety Fallbacks

1. **Missing Constitution**: Cannot proceed; user must create constitution first
2. **Ambiguous Requirements (< 70% confidence)**: Pause and ask targeted clarifying questions
3. **Constitutional Conflicts**: Flag explicitly; do not auto-resolve by weakening principles
4. **Missing Prerequisites**: List required documents and suggest speckit commands to generate them

## Commit Policy (MANDATORY - Updated Phase 3B)

**Environment context**: Moderately unstable → prioritize saving progress frequently.

**Hard effort limit**: Never spend more than **15 minutes** of continuous work without committing.

**WIP/DRAFT commits for intermittent saves**:
- Format: `WIP: plan4speckit - short description`
- Example: `WIP: plan4speckit - generated initial tasks.md skeleton`
- Do quick sanity check (file exists and readable) before committing
- Allowed even if constitution checks incomplete or validation hasn't passed

**Final commits** (when artifact passes all gates):
- Amend latest WIP: `git commit --amend -m "docs: plan4speckit - completed plan.md + tasks.md with full validation"`
- Remove "WIP" or "DRAFT" from final message

**Maximum WIP commits**: **Max 3 WIP commits per planning run**
- If exceeding limit, commit current state as final and ask user

**Commit message rules**:
- Always include agent name (plan4speckit) in message
- Include TASK_ID if applicable
- After any commit, append one-line summary to `.specfarm/error-memory.md`

**Git commands pattern**:
```bash
# WIP commit
git add FEATURE_DIR/plan.md FEATURE_DIR/tasks.md
git commit -m "WIP: plan4speckit - [description]"
echo "[timestamp] plan4speckit: WIP commit [N]/3 - [description]" >> .specfarm/error-memory.md

# Final commit (amend)
git commit --amend -m "docs: plan4speckit - completed plan.md + tasks.md with full validation"
echo "[timestamp] plan4speckit: FINAL - Generated plan with [N] tasks. Risk: [distribution]. Confidence: [XX%]" >> .specfarm/error-memory.md
```

## Output Format

All outputs in markdown, saved to `FEATURE_DIR/plan.md` and `FEATURE_DIR/tasks.md`.

Always log completion to `.specfarm/error-memory.md`:
```markdown
[timestamp] planspec: Generated plan with [N] tasks for [feature name]. Risk: [distribution]. Confidence: [XX%].
```
