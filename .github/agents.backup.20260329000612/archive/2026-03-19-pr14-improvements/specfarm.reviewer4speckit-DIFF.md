=== specfarm.reviewer4speckit.agent.md ===

--- archive/2026-03-19-pr14-improvements/specfarm.reviewer4speckit.agent.md-BEFORE.md	2026-03-19 09:19:11.380679659 -0400
+++ specfarm.reviewer4speckit.agent.md	2026-03-19 09:19:55.384679680 -0400
@@ -97,6 +97,101 @@
 
 ---
 
+### Phase 3.5: Test Harness Quality Check (NEW — Post-PR14)
+
+**Applies to**: All PRs modifying `tests/` directory
+
+**Detection Patterns:**
+
+```bash
+# 1. Check for bash arithmetic pitfall
+if grep -rn '&& *((' tests/ | grep -E '\)\).*\|\|' | grep -v '|| true'; then
+  echo "❌ HARD BLOCK: Bash arithmetic under set -e detected"
+  echo "   Pattern: _run_test && ((passed++)) || ((failed++))"
+  echo "   Risk: Tests report PASS but exit with code 1"
+  echo "   Fix: Use if/then/else with || true guards"
+  echo ""
+  echo "   Reference: PR #14 (failed 0%) / PR #15 (fixed)"
+  SEVERITY=HARD_BLOCK
+fi
+
+# 2. Check for exit code validation
+if grep -rq "set -e" tests/ && ! grep -rq 'exit.*passed.*failed' tests/; then
+  echo "⚠️  ADVISORY: Tests use 'set -e' but no explicit exit code logic"
+  echo "   Tests should exit 0 when passed > 0 and failed == 0"
+  echo "   Risk: Silent failures or false positives"
+  SEVERITY=ADVISORY
+fi
+
+# 3. Check for test summary validation
+if ! grep -rq 'PASS:\|FAIL:' tests/; then
+  echo "⚠️  ADVISORY: No PASS:/FAIL: output prefixes found"
+  echo "   Convention: Prefix each test result with PASS: or FAIL:"
+  echo "   Helps with automated parsing and debugging"
+  SEVERITY=ADVISORY
+fi
+```
+
+**Remediation**:
+- Flag pattern in review report
+- Reference PR #14 / PR #15 for examples
+- **Block approval** if pattern found + test failures present in CI
+- If pattern found + tests passing → advisory warning with upgrade path
+
+**Output**: Test harness quality card (pass/fail/advisory)
+
+---
+
+### Phase 3.6: Scope Verification Check (NEW — Post-PR14)
+
+**Applies to**: All PRs
+
+**Verification Steps:**
+
+```bash
+# 1. Get documented scope from PR description
+DOCUMENTED=$(grep -oP "Files Changed.*\K\d+" PR_BODY.md || \
+             grep -oP "\d+\s+files changed" PR_BODY.md | head -1 | awk '{print $1}' || \
+             echo 0)
+
+# 2. Get actual scope from git diff
+ACTUAL=$(git diff --name-only base..head | wc -l)
+
+# 3. Calculate variance
+VARIANCE=$(echo "scale=1; ($ACTUAL - $DOCUMENTED) / ($DOCUMENTED + 0.01) * 100" | bc)
+
+# 4. Check threshold
+if [ $(echo "$VARIANCE > 15" | bc) -eq 1 ] || [ $(echo "$VARIANCE < -15" | bc) -eq 1 ]; then
+  echo "🚨 SCOPE VARIANCE ALERT"
+  echo "   Documented: $DOCUMENTED files"
+  echo "   Actual: $ACTUAL files"  
+  echo "   Variance: ${VARIANCE}%"
+  echo "   Threshold: ±15%"
+  echo ""
+  echo "   Potential scope creep or undocumented changes."
+  echo "   Review plan.md and tasks.md for accuracy."
+  SEVERITY=HARD_BLOCK
+fi
+
+# 5. Zero-test red flag
+if git diff --name-only base..head | grep -q '^src/' && \
+   ! git diff --name-only base..head | grep -q '^tests/'; then
+  echo "🚨 ZERO-TEST RED FLAG"
+  echo "   src/ files modified but no tests/ touched"
+  echo "   Risk: Untested production code"
+  echo ""
+  echo "   Required: Either add tests or document in PR why not needed"
+  SEVERITY=HARD_BLOCK
+fi
+```
+
+**Exception Handling:**
+- If documented scope = 0 (not specified) → advisory warning only
+- If PR is labeled "docs-only" or "config-only" → skip zero-test check
+- If documented scope includes justification for variance → reduce to advisory
+
+**Output**: Scope verification card (pass/warning/block)
+
 ### Phase 4: Spec-Kit Adherence Check
 
 **If `.specify/` files present in repo:**

Lines added/removed:
95
