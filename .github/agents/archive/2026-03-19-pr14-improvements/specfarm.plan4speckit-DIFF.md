=== specfarm.plan4speckit.agent.md ===

--- archive/2026-03-19-pr14-improvements/specfarm.plan4speckit.agent.md-BEFORE.md	2026-03-19 09:18:14.204679631 -0400
+++ specfarm.plan4speckit.agent.md	2026-03-19 09:19:10.996679659 -0400
@@ -95,7 +95,7 @@
 
 Create or update `tasks.md` using `.specify/templates/tasks-template.md` structure:
 
-#### Task Format (per task):
+#### Task Format (per task - Enhanced Post-PR14):
 ```markdown
 ### Task: [TASK_ID] - [Brief Title]
 
@@ -103,12 +103,37 @@
 
 **Risk Level**: [LOW|MEDIUM|HIGH|CRITICAL]
 
+**Files Modified/Created**:
+- `path/to/file1.sh` (modify)
+- `path/to/file2.xml` (create)
+- `tests/unit/test_feature.sh` (create) ← MANDATORY if src/ touched
+
+**Test Coverage Plan** (MANDATORY - Post-PR14):
+- **Test Files**: 
+  - `tests/unit/test_[module].sh` (N tests expected)
+  - `tests/integration/test_[feature].sh` (M tests expected)
+- **Test Harness**: [bash | BATS | pytest | other]
+- **Success Criteria**: 
+  - ≥ XX% pass rate required
+  - Exit code 0 mandatory
+  - Exit code must match summary (no bash arithmetic bugs)
+  - Test-before-complete: Tests pass BEFORE marking task COMPLETE
+
 **Acceptance Criteria**:
 - [ ] Criterion 1 (measurable, testable)
 - [ ] Criterion 2
+- [ ] Tests created and passing **before** COMPLETE marker
+- [ ] Exit code matches test summary (no lies)
+- [ ] Scope variance ≤ ±15%
 - [ ] Constitution checkpoint: [principle name from constitution.md]
 - [ ] Cross-platform validation: [if applicable, specify bash + powershell test]
 - [ ] Pre-commit validation passes
+- [ ] If src/ modified, tests/ also touched (zero-test check)
+
+**Stop Conditions** (Circuit Breaker):
+- [ ] 3× consecutive failure → halt
+- [ ] Pass rate drops below 50% → escalate
+- [ ] Scope variance > 15% → audit
 
 **Implementation Notes**:
 - File paths: [list files to create/modify]
@@ -174,10 +199,16 @@
 3. If handoff skipped: Run `/specfarm.implement4speckit` manually when ready
 ```
 
-### 8. Handoff Conditions & Execution
+### 8. Handoff Conditions & Execution (Stricter Post-PR14)
 
 **Trigger automatic handoff to specfarm.implement4speckit only if ALL conditions met**:
 1. Constitution Compliance = `✓ PASS` (no MUST principle violations)
+2. All tasks have **Test Coverage Plan** section (mandatory)
+3. All tasks that touch src/ also touch tests/ (zero-test check)
+4. All tasks have explicit "Test-before-complete" checkpoint
+5. All tasks document exit-code validation strategy
+6. Scope estimates present (file counts documented)
+7. No test harness anti-patterns flagged (e.g., `&& ((passed++))` without guards)
 2. Overall Confidence ≥ 70% (majority of tasks achievable)
 3. At least 1 manageable task (LOW/MEDIUM risk, ≥70% confidence)
 4. User explicitly confirms: "Proceed to implementation?" [Y/n]

Lines added/removed:
35
