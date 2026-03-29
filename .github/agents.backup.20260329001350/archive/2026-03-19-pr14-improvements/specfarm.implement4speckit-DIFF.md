=== specfarm.implement4speckit.agent.md ===

--- archive/2026-03-19-pr14-improvements/specfarm.implement4speckit.agent.md-BEFORE.md	2026-03-19 09:16:43.064289409 -0400
+++ specfarm.implement4speckit.agent.md	2026-03-19 09:18:06.880679627 -0400
@@ -21,10 +21,34 @@
 Implement tasks from `tasks.md` that meet the "manageable risk" threshold, ensuring:
 - Constitution principles are respected
 - Pre-commit validation passes
-- Tests are run before marking complete
-- Implementation stops on cascaded failures
+- Tests are run **and verified** before marking complete
+- Implementation stops on cascaded failures or circuit breaker
+- Test-before-complete rule enforced (PR #14 lesson)
 - All changes are auditable and logged
 
+## Configuration Parameters (Line Limits)
+
+**Multiplier-based system** (model-agnostic):
+
+The `--lines=N` parameter applies a multiplier to the model's default output limit:
+
+- `--lines=1.0` → Use model default (implicit if not specified)
+- `--lines=1.2` → 20% above default
+- `--lines=1.5` → 50% above default (good for refactors)
+- `--lines=0.8` → 20% below default (tight mode)
+
+**Approximate defaults by model** (for reference):
+- Claude Opus 4.6: ~900 lines
+- Claude Sonnet 4.6: ~500 lines  
+- Claude Haiku 4.5: ~300 lines
+- GPT-5 Mini High: ~200 lines
+- GPT-5 Mini Medium: ~180 lines
+
+**Enforcement**: Check line count before writing files. If soft breach:
+- Warn user
+- Offer to split into multiple files
+- Do NOT write oversized files without approval
+
 ## Operating Constraints
 
 **Constitution Authority**: The project constitution (`.specify/memory/constitution.md`) is **binding**. All implementations must comply. If a task requires violating a principle, abort and flag for user review.
@@ -125,65 +149,229 @@
 - Use `src/crossplatform/line-endings.sh` for text normalization
 - Test on both platforms if specified in acceptance criteria
 
-#### C. Validation Phase
+#### C. Validation Phase (Enhanced Post-PR14)
 
 **Required validations** (in order):
-1. **Syntax check**:
-   - Bash scripts: `bash -n <file>`
-   - PowerShell scripts: `pwsh -NoProfile -Command "Test-Path <file>"`
-   - XML: validate against schema if `.xsd` exists
-2. **Constitution compliance**:
+1. **Smoke syntax pre-check** (BLOCKING):
+   ```bash
+   # Syntax validation for bash files
+   for f in $(git diff --name-only | grep '\.sh$'); do
+     bash -n "$f" || { echo "❌ Syntax smoke fail: $f"; exit 1; }
+   done
+   
+   # PowerShell syntax (if applicable)
+   for f in $(git diff --name-only | grep '\.ps1$'); do
+     pwsh -NoProfile -File "$f" -ErrorAction Stop 2>/dev/null || {
+       echo "❌ PowerShell syntax fail: $f"; exit 1
+     }
+   done
+   
+   # XML validation (if .xsd exists)
+   for f in $(git diff --name-only | grep '\.xml$'); do
+     xmllint --noout --schema ".specify/schemas/rules.xsd" "$f" 2>/dev/null || {
+       echo "⚠️ XML validation failed: $f (non-blocking if schema missing)"
+     }
+   done
+   ```
+
+2. **ShellCheck advisory linting** (NON-BLOCKING, graceful):
+   ```bash
+   # Only if ShellCheck is available
+   if command -v shellcheck >/dev/null 2>&1; then
+     shellcheck_files=$(git diff --name-only | grep '\.sh$')
+     if [ -n "$shellcheck_files" ]; then
+       mkdir -p .specfarm
+       shellcheck -f gcc $shellcheck_files > .specfarm/shellcheck.log 2>&1
+       if [ -s .specfarm/shellcheck.log ]; then
+         echo "ℹ️  ShellCheck found issues (advisory - not blocking):"
+         cat .specfarm/shellcheck.log | head -n 20
+         echo ""
+         echo "   Review .specfarm/shellcheck.log for details."
+       fi
+     fi
+   else
+     echo "ℹ️  ShellCheck not found on PATH (this is OK)."
+     echo "   Would have linted bash files for common issues."
+     echo "   Install: brew install shellcheck / apt install shellcheck"
+     echo "   (advisory only - continuing without it)"
+   fi
+   ```
+
+3. **Test harness bug detector** (BLOCKING if found):
+   ```bash
+   # Detect dangerous bash arithmetic patterns under set -e
+   if grep -rn '&& *((' tests/ 2>/dev/null | grep -E '\)\).*\|\|' | grep -v '|| true'; then
+     echo "❌ HIGH RISK: Bash arithmetic under set -e detected"
+     echo "   Pattern: _run_test && ((passed++)) || ((failed++))"
+     echo "   Risk: Tests report PASS but exit with code 1"
+     echo ""
+     echo "   Auto-fix attempt..."
+     # Attempt fix: add || true guards
+     find tests/ -name '*.sh' -exec sed -i \
+       's/&& *((\([^)]*\)))/\&\& { ((\1)); } || true/g' {} \;
+     find tests/ -name '*.sh' -exec sed -i \
+       's/|| *((\([^)]*\)))/|| { ((\1)); } || true/g' {} \;
+     echo "   Applied || true guards. Re-validating..."
+     bash -n tests/**/*.sh || { echo "Fix failed - BLOCKED"; exit 1; }
+   fi
+   ```
+
+4. **Constitution compliance**:
    - Check each acceptance criterion marked "Constitution checkpoint"
    - Verify no MUST principles violated
-3. **Pre-commit validation**:
+
+5. **Pre-commit validation**:
    - Run `.git/hooks/pre-commit` (or `bin/specfarm-pre-commit` if present)
    - If fails, abort and report
-4. **Test suite** (if applicable):
-   - Run tests specified in acceptance criteria
-   - If no tests specified, check for `tests/unit/test_<module>.sh` and run
-   - If fails, abort and report
 
-#### D. Completion Check
+6. **Test suite execution with exit-code paranoia** (CRITICAL):
+   ```bash
+   # Run tests
+   bash tests/unit/*.sh > test_results.log 2>&1
+   EXIT=$?
+   
+   # Parse summary
+   SUMMARY=$(tail -20 test_results.log | grep -iE "summary|passed|failed|tests")
+   
+   # Exit-code paranoia check (PR #14 lesson)
+   if [ $EXIT -ne 0 ] && echo "$SUMMARY" | grep -qiE "0 failed|all pass"; then
+     echo "❌ TEST HARNESS LIE DETECTED"
+     echo "   Exit code: $EXIT (failure)"
+     echo "   But summary claims: $SUMMARY"
+     echo ""
+     echo "   This indicates a bash arithmetic bug in test harness."
+     echo "   BLOCKED - human review required."
+     exit 1
+   fi
+   
+   # If tests failed legitimately
+   if [ $EXIT -ne 0 ]; then
+     echo "❌ Tests failed (exit=$EXIT)"
+     tail -50 test_results.log
+     exit 1
+   fi
+   
+   echo "✓ Tests passed (exit=$EXIT, summary verified)"
+   ```
+
+7. **Scope verification** (15% tolerance):
+   ```bash
+   ACTUAL_FILES=$(git diff --name-only | wc -l)
+   DOCUMENTED_FILES=$(grep -cE "^- File:|^  - \`" tasks.md || echo 1)
+   VARIANCE=$(echo "scale=1; ($ACTUAL_FILES - $DOCUMENTED_FILES) / ($DOCUMENTED_FILES + 0.01) * 100" | bc)
+   
+   if [ $(echo "$VARIANCE > 15" | bc) -eq 1 ] || [ $(echo "$VARIANCE < -15" | bc) -eq 1 ]; then
+     echo "❌ SCOPE CREEP ALERT"
+     echo "   Documented: $DOCUMENTED_FILES files"
+     echo "   Actual: $ACTUAL_FILES files"
+     echo "   Variance: ${VARIANCE}%"
+     echo ""
+     echo "   Threshold: ±15%"
+     echo "   Review plan.md and tasks.md for accuracy."
+     exit 1
+   fi
+   
+   # Zero-test red flag
+   if git diff --name-only | grep -q '^src/' && ! git diff --name-only | grep -q '^tests/'; then
+     echo "🚨 ZERO-TEST RED FLAG"
+     echo "   src/ files modified but no tests/ touched"
+     echo "   Risk: Untested production code"
+     echo ""
+     echo "   Either add tests or document why not needed."
+     exit 1
+   fi
+   ```
 
-Mark task complete only if:
+#### D. Completion Check (STRICT - Post-PR14)
+
+**NEVER mark task COMPLETE unless ALL criteria met**:
 - [ ] All acceptance criteria met
-- [ ] Constitution checkpoints validated
+- [ ] Constitution checkpoints validated  
 - [ ] Pre-commit validation passed
-- [ ] Tests passed (if applicable)
+- [ ] Tests executed and **exited with code 0**
+- [ ] Test summary parsed and **pass count matches expected**
+- [ ] No test suite timeouts or hangs (>300s = timeout)
+- [ ] Exit code matches summary outcome (no lies)
+- [ ] Scope variance ≤ ±15% from documented
+- [ ] If src/ changed, tests/ also touched (zero-test check)
 - [ ] Implementation logged to `.specfarm/error-memory.md`
 
-Update `tasks.md` with completion marker:
+**Never mark complete if**:
+- Tests exist but were skipped
+- Exit code ≠ summary outcome (PR #14 bug)
+- `git diff --stat` shows >15% variance from plan
+- No test files added/modified when src/ changed
+
+Update `tasks.md` with **verified** completion marker:
 ```markdown
 ### Task: [TASK_ID] - [Title] ✓ COMPLETE
 
 **Implemented**: [timestamp]
 **Validation Results**:
 - Syntax: ✓ PASS
+- ShellCheck: ✓ ADVISORY (N issues)
+- Test Harness: ✓ NO BUGS
 - Constitution: ✓ PASS
 - Pre-commit: ✓ PASS
-- Tests: ✓ PASS ([N]/[N] passed)
+- Tests: ✓ PASS ([N]/[N] passed, exit=0, verified)
+- Scope: ✓ PASS ([ACTUAL] files vs [DOCUMENTED] documented, variance=[X]%)
 ```
 
-#### E. Cascade Failure Handling with Independent Task Recovery
+#### E. Cascade Failure Handling with Circuit Breaker (Enhanced Post-PR14)
+
+**Circuit Breaker State Tracking**:
+```bash
+declare -A failure_count  # Track per-task failures
+MAX_RETRIES=3
+```
 
 If any validation fails:
-1. **Mark failed task as blocked** (do not continue downstream dependent tasks)
-2. **Report failure details**:
+1. **Increment failure counter** for the task:
+   ```bash
+   ((failure_count[$TASK_ID]++)) || true
+   
+   if (( failure_count[$TASK_ID] >= MAX_RETRIES )); then
+     echo "🔴 CIRCUIT BREAKER TRIGGERED"
+     echo "   Task $TASK_ID failed $MAX_RETRIES times"
+     echo "   Last 30 lines of output:"
+     tail -30 test_results.log | tee -a .specfarm/failures/$(date +%s)-$TASK_ID.log
+     echo ""
+     echo "   HUMAN REQUIRED - stopping execution"
+     exit 1
+   fi
+   ```
+
+2. **Mark failed task as blocked** (do not continue downstream dependent tasks)
+
+3. **Report failure details**:
    ```markdown
-   ## Task [TASK_ID] FAILED
+   ## Task [TASK_ID] FAILED (Attempt [N]/3)
    
-   **Failure Type**: [Syntax | Constitution | Pre-commit | Tests]
+   **Failure Type**: [Syntax | Constitution | Pre-commit | Tests | Scope]
    **Details**: [error output]
    **Rollback Required**: [Yes | No]
    **Dependent Tasks Blocked**: [TASK_ID_1, TASK_ID_2, ...]
+   **Retry Available**: [Yes (N attempts left) | No (circuit breaker)]
    ```
-3. **Search for independent tasks** (no dependencies on the failed task):
+
+4. **Rollback on failure** (incremental):
+   ```bash
+   if [[ "$ROLLBACK_ON_FAIL" == "true" ]]; then
+     TASK_FILES=$(grep -A 20 "### Task: $TASK_ID" tasks.md | grep -oP '`\K[^`]+' | grep -E '\.(sh|ps1|xml|md)$')
+     for file in $TASK_FILES; do
+       git checkout -- "$file" 2>/dev/null && echo "   Rolled back: $file"
+     done
+   fi
+   ```
+
+5. **Search for independent tasks** (no dependencies on the failed task):
    - Scan remaining unimplemented tasks
    - Filter to those with **zero dependency** on any failed/blocked task
    - Continue implementing independent tasks in dependency order
    - Only stop when **no independent tasks remain**
-4. **Offer remediation for the failed task**:
-   - `--fix` → attempt auto-fix (if syntax error)
+
+6. **Offer remediation for the failed task**:
+   - `--fix` → attempt auto-fix (if syntax error) and retry (increment counter)
    - `--skip` → mark task skipped and continue searching for independent tasks
    - `--abort` → stop and exit immediately
 

Lines added/removed:
242
