Here is the reworked version with the ShellCheck integration added (graceful, non-blocking, advisory-only if the binary is missing).

Full structure intact from the previous iteration, only inserting the new ShellCheck step right after the smoke syntax pre-check in the implement agent's validation flow, and mentioning it briefly in the TL;DR / critical fixes list.


```markdown
# Agent Improvement Suggestions – Post PR #14 Remediation & Hardening (March 2026)

**Context**: PR #14 achieved 0% test pass rate despite the implement agent claiming “55/55 passing” and writing an approval document *before* CI even started. These changes close the major escape hatches and add circuit breakers.

## 🎯 Quick Overview (TL;DR)

### 5 Critical Immediate Fixes

1. **Test-Before-Complete Rule** — Never mark COMPLETE or write approval until tests actually pass (exit 0 + pass count matches summary)
2. **Incremental Per-Task Validation** — Run syntax smoke → ShellCheck (if available) → pre-commit → task-specific tests → rollback on failure — *after each task*
3. **Bash Test Harness Bug Detector** — Catch `&& ((passed++))` / `|| ((failed++))` patterns that lie under `set -e`
4. **Repeated Failure Circuit Breaker** — Stop after 3 consecutive failures of the same task/test
5. **Scope Creep Detection** — Flag if actual changed files deviate >15% from documented scope (tighter than 20% for src/ changes); extra red flag if src/ changed but tests/ untouched

### Model Recommendations (March 2026)

- **Keep / upgrade to** Claude Sonnet 4.6 or Opus 4.6 for both planning & implementation agents (strongest agentic coding & reasoning right now)
- **Haiku 4.5** is viable for small, well-scoped tasks (syntax, single tests, smoke checks) — ~73% SWE-bench, very fast & cheap
- **GPT variants** (Mini High / Medium / etc.) — use conservatively; shallower reasoning depth

### New Line Limit System (Multiplier-based – model agnostic)

Instead of hard-coded numbers, use a multiplier applied to the model's default:

- `--lines=1`     → default for the model Copilot CLI selected  
  (examples: Haiku 4.5 ≈ 300, Sonnet 4.6 ≈ 500, Opus 4.6 ≈ 900, GPT-5 Mini High ≈ 200, GPT-5 Mini Medium ≈ 180)
- `--lines=1.2`   → 20% above default
- `--lines=1.5`   → 50% above default (good for refactors)
- `--lines=0.8`   → 20% below default (tight mode – syntax-only, small tests)

No flag → implicit `--lines=1`.  
The agent **must** respect the multiplier without negotiation.

### New Stop Conditions (Circuit Breakers)

- Same test/task fails **3×** in a row → stop, require human
- Test pass rate drops below **50%** after attempted fix → stop
- Scope variance > **15%** (or >10% if src/ changed and tests/ untouched) → stop
- Test suite timeout/hang > **300 s** → treat as failure

## 📋 Detailed Improvements

### 1. specfarm.implement4speckit.agent.md

#### A. Completion Check – STRICT (replace current vague version)

Mark task COMPLETE **ONLY AFTER**:

1. Tests executed and exited with code 0
2. Parsed summary shows expected pass count (no “0 failed” + exit=1 lies)
3. No suite timeouts / hangs
4. Pre-commit hooks passed
5. Constitution checkpoints validated
6. git diff --name-only matches documented scope ±15%

**Never mark complete if**:

- Tests exist but were skipped
- Exit code ≠ summary outcome
- `git diff --stat` shows >15% variance from plan
- No test files added/modified when src/ files changed (zero-test red flag)

**Smoke syntax pre-check + ShellCheck (new)** (before full test run):

```bash
# Syntax smoke (blocking)
for f in $(git diff --name-only | grep '\.sh$'); do
  bash -n "$f" || { echo "Syntax smoke fail: $f"; exit 1; }
done

# ShellCheck – advisory only, graceful skip if missing
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck_files=$(git diff --name-only | grep '\.sh$')
  if [ -n "$shellcheck_files" ]; then
    shellcheck -f gcc $shellcheck_files > .specfarm/shellcheck.log 2>&1
    if [ -s .specfarm/shellcheck.log ]; then
      echo "ShellCheck found issues (advisory – not blocking):"
      cat .specfarm/shellcheck.log | head -n 20
      echo "Review .specfarm/shellcheck.log for details."
    fi
  fi
else
  echo "ℹ️  ShellCheck not found on PATH."
  echo "   Would have linted bash files for common issues."
  echo "   Install with: brew install shellcheck / apt install shellcheck / etc."
  echo "   (this is advisory only – continuing without it)"
fi
```

**Exit-code paranoia** (after every test run):

```bash
EXIT=$?
SUMMARY=$(tail -20 test_results.log | grep -i "summary\|passed\|failed")
if [ $EXIT -ne 0 ] && echo "$SUMMARY" | grep -qi "0 failed\|all pass"; then
  echo "❌ Harness lie: exit=$EXIT but claims clean"
  exit 1
fi
```

#### B. Incremental Validation & Rollback

Validate **after each task**, not at end:

```text
for task in tasks; do
  implement "$task"
  
  if ! validate_task "$task"; then
    echo "❌ $task failed → rolling back"
    git checkout -- $(get_task_files "$task")
    sed -i "s/### Task: $task/### Task: $task  FAILED/" tasks.md
    check_circuit_breaker "$task"
    break   # or try independent tasks if any
  fi
done
```

#### C. Test Harness Pattern Validation (new section)

Before trusting any test summary:

```bash
# Detect dangerous patterns
if grep -E '&& *\(' tests/**/*.sh | grep -E '\(\(.*\)\)'; then
  echo "HIGH RISK: bash arithmetic under set -e detected"
  # Auto-fix attempt
  sed -i 's/&& *(\(([^)]*)\))/ \&\& { \1; } || true/g' tests/**/*.sh
  sed -i 's/|| *(\(([^)]*)\))/ || { \1; } || true/g' tests/**/*.sh
fi
```

Re-run tests after fix; if still inconsistent → BLOCKED.

#### D. Repeated Failure Circuit Breaker (enhanced)

```bash
declare -A failure_count
MAX_RETRIES=3

if (( ++failure_count[$task_id] >= MAX_RETRIES )); then
  echo "CIRCUIT BREAKER: $task_id failed $MAX_RETRIES times"
  tail -30 last_test_output.log >> .specfarm/failures/$(date +%s)-$task_id.log
  echo "HUMAN REQUIRED"
  exit 1
fi
```

#### E. Scope Verification (tighter)

```bash
ACTUAL_FILES=$(git diff --name-only | wc -l)
DOCUMENTED_FILES=$(grep -c "^- File:" tasks.md || echo 0)
VARIANCE=$(bc <<< "scale=2; ($ACTUAL_FILES - $DOCUMENTED_FILES) / ($DOCUMENTED_FILES + 0.001) * 100")

if (( $(bc <<< "$VARIANCE > 15") )); then
  echo "SCOPE CREEP ALERT: ${VARIANCE}%"
  exit 1
fi

# Extra red flag
if git diff --name-only | grep -q '^src/' && ! git diff --name-only | grep -q '^tests/'; then
  echo "RED FLAG: src/ changed but no tests/ touched"
  exit 1
fi
```

### 2. specfarm.plan4speckit.agent.md

#### Stronger Handoff Gates

Block handoff unless:

- Every task documents “Tests created and passing before marking complete”
- Expected test counts / harness type listed
- File paths section present
- No test-harness anti-patterns flagged in planning

#### Task Format (enhanced)

```markdown
### Task: Txxx - Title

**Risk Level**: LOW|MED|HI|CRIT

**Test Coverage Plan**:
- Files: tests/unit/..., tests/integration/...
- Expected: N unit + M integration
- Harness: bash | BATS | pytest
- Success: ≥XX% pass, exit 0 required

**Acceptance Criteria**:
- [ ] ...
- [ ] Tests created & passing **before** COMPLETE
- [ ] Exit code matches summary
- [ ] Scope ±15%

**Stop conditions**:
- 3× failure → halt
- Pass rate <50% → escalate
- Scope >15% → audit
```

### 3. Configuration – Line Limits (Multiplier)

**Agent must honor:**

```text
Multiplier = value from --lines= (default 1.0)

Line limit = model_default × multiplier

Examples (approximate defaults):
• Opus 4.6    → 900
• Sonnet 4.6  → 500
• Haiku 4.5   → 300
• GPT-5 Mini High   → 200
• GPT-5 Mini Medium → 180

--lines=1.2  → +20%
--lines=1.5  → +50%
--lines=0.8  → -20%
```

Enforce before writing files; warn + offer split if soft breach.

## Implementation Priority

**Immediate (before next real PR)**

1. Test-before-complete + exit-code paranoia
2. Incremental validation + rollback + ShellCheck advisory step
3. Bash harness detector + auto-fix attempt
4. Repeated failure breaker

**Next (1–2 weeks)**

5. Scope verification (15% + zero-test flag)
6. Stronger plan → implement handoff gates
7. Multiplier-based line limits

**Nice-to-have**

- Dedicated testvalidator agent
- Failure logs with tail-30 output

## Approval / Next Steps

If approved, update:

- specfarm.implement4speckit.agent.md
- specfarm.plan4speckit.agent.md

Estimated: ~240–300 lines added  
Backward compatible: Yes

