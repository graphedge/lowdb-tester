# Agent Improvements Analysis - Other SpecFarm Agents + XML Rules

**Date**: 2026-03-19  
**Context**: Post PR #14 analysis - applying lessons learned to all agents

---

## 🤖 Other SpecFarm Agents Requiring Similar Improvements

### 1. specfarm.reviewer4speckit.agent.md

**Current State**: Already has robust validation (v2.0 enhanced post-PR13)

**Recommended Additions from PR #14 Lessons**:

#### A. Add Test Harness Pattern Detection to Review Checklist

```markdown
### Check F: Test Harness Quality (NEW - Post PR #14)

**Applies to**: All PRs modifying tests/ directory

**Detection Patterns**:
```bash
# Check for bash arithmetic pitfall
if grep -E '&& *\(\(' tests/**/*.sh | grep -E '\)\) *\|\|'; then
  echo "❌ HARD BLOCK: Bash arithmetic under set -e detected"
  echo "   Pattern: _run_test && ((passed++)) || ((failed++))"
  echo "   Risk: Tests report PASS but exit with code 1"
  echo "   Fix: Use if/then/else with || true guards"
  SEVERITY=HARD_BLOCK
fi

# Check for exit code validation
if ! grep -q "exit.*\$.*passed.*failed" tests/**/*.sh; then
  echo "⚠️ ADVISORY: No explicit exit code logic found"
  echo "   Tests should exit 0 when passed > 0 and failed == 0"
  SEVERITY=ADVISORY
fi
```

**Remediation**:
- Flag pattern in review report
- Reference PR #14 / PR #15 for examples
- Block approval if pattern found + test failures present
```

#### B. Add Scope Verification to Review Process

```markdown
### Check G: Scope Verification (NEW - Post PR #14)

**Applies to**: All PRs

**Verification Steps**:
```bash
# Get documented scope from PR description
DOCUMENTED=$(grep -oP "Files Changed.*\K\d+" PR_BODY.md || echo 0)

# Get actual scope
ACTUAL=$(git diff --name-only base..head | wc -l)

# Calculate variance
VARIANCE=$(bc <<< "scale=1; ($ACTUAL - $DOCUMENTED) / ($DOCUMENTED + 0.01) * 100")

if (( $(bc <<< "$VARIANCE > 15") )); then
  echo "🚨 SCOPE VARIANCE ALERT"
  echo "   Documented: $DOCUMENTED files"
  echo "   Actual: $ACTUAL files"  
  echo "   Variance: ${VARIANCE}%"
  echo ""
  echo "   Potential scope creep or undocumented changes."
  SEVERITY=HARD_BLOCK
fi

# Red flag: src/ changed but no tests/
if git diff --name-only | grep -q '^src/' && ! git diff --name-only | grep -q '^tests/'; then
  echo "🚨 ZERO-TEST RED FLAG"
  echo "   src/ files modified but no tests/ touched"
  echo "   Risk: Untested production code"
  SEVERITY=HARD_BLOCK
fi
```
```

---

### 2. specfarm.gather-rules.agent.md

**Current State**: Haiku-4.5, automated rules discovery

**Recommended Additions**:

#### A. Add Rule Confidence Scoring

```markdown
## Rules Confidence Scoring (NEW)

When extracting rules from commits, assign confidence scores:

**High Confidence (≥90%)**:
- Rule appears in 5+ commits by different authors
- Explicitly documented in commit messages
- Covered by tests
- Referenced in constitution

**Medium Confidence (70-89%)**:
- Rule appears in 2-4 commits
- Implicit pattern (not explicitly stated)
- Some test coverage

**Low Confidence (<70%)**:
- Single occurrence
- No documentation
- No test coverage

**Output Format**:
```xml
<rule id="r123" confidence="92">
  <pattern>Must use xmllint for XML validation</pattern>
  <evidence commits="5" authors="3"/>
  <test-coverage>tests/unit/test_xml_validation.sh</test-coverage>
</rule>
```
```

#### B. Add Test Pattern Analysis

```markdown
## Test Pattern Detection (NEW - Post PR #14)

While gathering rules, also detect test anti-patterns:

```bash
# Scan for bash arithmetic bugs
HARNESS_BUGS=$(grep -rn '&& ((' tests/ | grep -v '|| true' | wc -l)

if [[ $HARNESS_BUGS -gt 0 ]]; then
  echo "## Test Infrastructure Issues Detected"
  echo ""
  echo "Found $HARNESS_BUGS potential bash arithmetic bugs:"
  grep -rn '&& ((' tests/ | grep -v '|| true' | head -10
  echo ""
  echo "**Suggested Rule**: Add r999 - Bash test harness must use || true guards"
fi
```

**Output**: Automatically suggest rule for test quality
```

---

### 3. specfarm.testinfra.agent.md

**Current State**: Haiku-4.5, dependency/config validation

**Recommended Enhancements**:

#### A. Add Test Suite Health Check

```markdown
## Test Suite Health Validation (NEW - Post PR #14)

**New Capability**: `test_suite_health`

**Checks**:
1. **Exit Code Consistency**:
   ```bash
   for test in tests/**/*.sh; do
     bash "$test" >/dev/null 2>&1
     EXIT=$?
     SUMMARY=$(bash "$test" 2>&1 | tail -1)
     
     # Check for mismatch
     if [[ $EXIT -eq 0 ]] && echo "$SUMMARY" | grep -qi "failed"; then
       echo "❌ INCONSISTENT: $test (exit 0 but claims failures)"
     fi
     if [[ $EXIT -ne 0 ]] && echo "$SUMMARY" | grep -qi "0 failed"; then
       echo "❌ HARNESS BUG: $test (exit $EXIT but claims clean)"
     fi
   done
   ```

2. **Test Harness Pattern Scan**:
   ```bash
   echo "Scanning for bash arithmetic pitfalls..."
   grep -rn '&& ((' tests/ | grep -v '|| true'
   ```

3. **Timeout Detection**:
   ```bash
   for test in tests/**/*.sh; do
     timeout 30 bash "$test" >/dev/null 2>&1 || {
       echo "⚠️ TIMEOUT: $test (>30s or failed)"
     }
   done
   ```

**Usage**:
```bash
/specfarm.testinfra --check-test-health
```

**Output**: Health report with remediation suggestions
```

#### B. Add ShellCheck Integration Check

```markdown
## ShellCheck Availability Check (NEW)

**Capability**: `shellcheck_check`

```bash
if ! command -v shellcheck >/dev/null 2>&1; then
  echo "⚠️ ShellCheck not found in PATH"
  echo "   Advisory linting unavailable"
  echo "   Install: brew/apt install shellcheck"
  echo "   Impact: Missing bash quality checks in CI"
  SEVERITY=ADVISORY
else
  SHELLCHECK_VERSION=$(shellcheck --version | head -1)
  echo "✓ ShellCheck available: $SHELLCHECK_VERSION"
fi
```
```

---

## 🔖 New XML Rules Suggestions (Post PR #14)

### For `.specfarm/rules.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<rules version="2.0" updated="2026-03-19">
  
  <!-- ================================================================== -->
  <!-- SECTION: Test Infrastructure Quality (NEW - Post PR #14)          -->
  <!-- ================================================================== -->
  
  <rule id="r099" priority="CRITICAL" category="test-infrastructure">
    <title>Bash Test Harness Must Use Exit Code Guards</title>
    <pattern>
      <file>tests/**/*.sh</file>
      <anti-pattern>&amp;&amp; \(\(.*\+\+\)\) \|\| \(\(.*\+\+\)\)</anti-pattern>
    </pattern>
    <description>
      Test harnesses using bash arithmetic increments with set -e MUST include
      || true guards to prevent false exit codes.
      
      BAD:  _run_test &amp;&amp; ((passed++)) || ((failed++))
      GOOD: if _run_test; then ((passed++)) || true; else ((failed++)) || true; fi
      
      Rationale: When passed=0, ((passed++)) evaluates to 0 (falsy), causing
      set -e to trigger even on success.
    </description>
    <severity>HARD_BLOCK</severity>
    <reference>PR #14, PR #15 test harness fix</reference>
    <exemption-criteria>
      Test file explicitly documents alternative pattern with proof of correctness
    </exemption-criteria>
  </rule>

  <rule id="r100" priority="HIGH" category="test-infrastructure">
    <title>Test Exit Codes Must Match Summary Output</title>
    <pattern>
      <file>tests/**/*.sh</file>
      <required>exit code validation logic</required>
    </pattern>
    <description>
      All test files MUST exit with code matching their summary:
      - Exit 0 when all tests pass (failed == 0)
      - Exit 1 when any test fails (failed > 0)
      - Exit 2 for test infrastructure errors
      
      Required pattern at end of main():
      ```bash
      if [[ $failed -gt 0 ]]; then
        exit 1
      fi
      # implicit exit 0
      ```
    </description>
    <severity>HARD_BLOCK</severity>
    <auto-fix>Add exit logic template to test files</auto-fix>
  </rule>

  <rule id="r101" priority="HIGH" category="test-infrastructure">
    <title>ShellCheck Advisory Linting for Bash Scripts</title>
    <pattern>
      <file>*.sh</file>
      <file>bin/*</file>
      <file>scripts/**/*.sh</file>
    </pattern>
    <description>
      All bash scripts SHOULD pass ShellCheck linting (advisory only).
      
      CI will run: shellcheck -f gcc file.sh
      
      Warnings are logged but do not block PR merge. Critical issues
      (SC2086, SC2046, SC2154) should be addressed before merge.
    </description>
    <severity>ADVISORY</severity>
    <exemption-criteria>
      Known false positives documented in .shellcheckrc or inline directives
    </exemption-criteria>
  </rule>

  <rule id="r102" priority="CRITICAL" category="ci-governance">
    <title>Test Results Before Approval Documents</title>
    <pattern>
      <file>*-REVIEW-*.md</file>
      <file>GOVERNANCE-*.md</file>
      <file>*-APPROVAL-*.md</file>
    </pattern>
    <description>
      Approval/review documents MUST only be created AFTER all tests pass.
      
      Required workflow:
      1. Run full test suite
      2. Verify exit codes == 0
      3. Verify pass counts match summary
      4. THEN write approval document
      
      Blocked patterns:
      - Writing approval before CI completes
      - Claiming "N/N passing" without CI evidence
      - Approving with failing hard-blocking checks
    </description>
    <severity>HARD_BLOCK</severity>
    <reference>Constitution Principle IV.A, PR #13, PR #14</reference>
    <auto-detect>
      <check>git log --all --format='%H %s' | grep -i 'approval\|review'</check>
      <check>Compare timestamp of approval commit vs CI completion time</check>
      <violation-if>Approval commit timestamp &lt; CI completion timestamp</violation-if>
    </auto-detect>
  </rule>

  <rule id="r103" priority="HIGH" category="scope-governance">
    <title>Documented Scope Must Match Actual Changes</title>
    <pattern>
      <pr-description>Files Changed: (\d+)</pr-description>
      <git-diff>$(git diff --name-only base..head | wc -l)</git-diff>
    </pattern>
    <description>
      PR descriptions MUST accurately document scope of changes.
      
      Variance tolerance: ±15% for generated files, tests, docs
      
      Violations:
      - Actual files changed >15% higher than documented
      - Claiming "N files changed" but actual is 10x+ larger
      
      Auto-detection in CI:
      ```bash
      DOCUMENTED=$(grep -oP "Files.*\K\d+" PR_BODY)
      ACTUAL=$(git diff --name-only | wc -l)
      VARIANCE=$((100 * (ACTUAL - DOCUMENTED) / DOCUMENTED))
      [[ $VARIANCE -gt 15 ]] && exit 1
      ```
    </description>
    <severity>HARD_BLOCK</severity>
    <reference>PR #14 (493 actual vs 13 documented)</reference>
  </rule>

  <rule id="r104" priority="HIGH" category="test-coverage">
    <title>Source Changes Require Test Changes</title>
    <pattern>
      <if-modified>src/**/*.sh</if-modified>
      <then-required>tests/**/*.sh</then-required>
    </pattern>
    <description>
      PRs modifying src/ files MUST also modify tests/ files (unless exempted).
      
      Exemptions:
      - Documentation-only changes (comments, docstrings)
      - Whitespace/formatting fixes
      - Configuration changes (explicitly marked)
      
      Zero-test red flag: src/ changed but no tests/ touched
    </description>
    <severity>HARD_BLOCK</severity>
    <auto-detect>
      ```bash
      SRC_CHANGED=$(git diff --name-only | grep '^src/' | wc -l)
      TEST_CHANGED=$(git diff --name-only | grep '^tests/' | wc -l)
      [[ $SRC_CHANGED -gt 0 && $TEST_CHANGED -eq 0 ]] && echo "ZERO-TEST"
      ```
    </auto-detect>
  </rule>

  <rule id="r105" priority="MEDIUM" category="test-infrastructure">
    <title>Incremental Test Validation in Implementation</title>
    <pattern>
      <agent>specfarm.implement4speckit</agent>
      <workflow>Test after each task</workflow>
    </pattern>
    <description>
      Implementation agents MUST validate tests after each task, not at end.
      
      Required workflow:
      1. Implement Task N
      2. Run Task N tests → if fail, rollback Task N
      3. Mark Task N complete only if tests pass
      4. Proceed to Task N+1
      
      Benefits:
      - Isolates failures to single task
      - Faster feedback loop
      - Easy rollback (git reset to last passing task)
      
      Circuit breaker: Stop after 3 consecutive task failures
    </description>
    <severity>ADVISORY</severity>
    <reference>PR #14 analysis, Option B execution</reference>
  </rule>

  <rule id="r106" priority="CRITICAL" category="ci-governance">
    <title>Circuit Breaker for Repeated Test Failures</title>
    <pattern>
      <test-execution>Same test fails 3+ consecutive times</test-execution>
    </pattern>
    <description>
      Implementation/test agents MUST stop after 3 consecutive failures
      of the same test or task.
      
      Tracking:
      ```bash
      declare -A failure_count
      ((failure_count[$task_id]++))
      
      if [[ ${failure_count[$task_id]} -ge 3 ]]; then
        echo "CIRCUIT BREAKER: $task_id failed 3 times"
        echo "HUMAN INTERVENTION REQUIRED"
        exit 1
      fi
      ```
      
      Prevents: Infinite retry loops, resource waste, false progress
    </description>
    <severity>HARD_BLOCK</severity>
  </rule>

  <!-- ================================================================== -->
  <!-- SECTION: Agent Line Limit Governance (NEW)                        -->
  <!-- ================================================================== -->

  <rule id="r107" priority="MEDIUM" category="agent-governance">
    <title>Agent Line Limits via Multiplier System</title>
    <pattern>
      <agent>specfarm.implement4speckit</agent>
      <agent>specfarm.plan4speckit</agent>
      <parameter>--lines=N</parameter>
    </pattern>
    <description>
      Agents support configurable line limits via multiplier:
      
      --lines=1.0  → model default (Sonnet ≈500, Haiku ≈300, Opus ≈900)
      --lines=1.2  → +20% (refactors)
      --lines=1.5  → +50% (complex tasks)
      --lines=0.8  → -20% (tight mode)
      
      Enforcement:
      - Validate line counts before writing files
      - Warn + offer split if soft breach
      - Hard block if >2x multiplier without --unlimited-lines
      
      No flag = implicit --lines=1.0
    </description>
    <severity>ADVISORY</severity>
    <exemption-criteria>
      Explicit --unlimited-lines flag with justification in commit message
    </exemption-criteria>
  </rule>

</rules>
```

---

## 📊 Summary Table: Agent Improvements

| Agent | Current Model | Needs Improvements? | Priority | Key Additions |
|-------|---------------|---------------------|----------|---------------|
| **implement4speckit** | Sonnet-4.5 | ✅ YES | CRITICAL | Test-before-complete, incremental validation, harness detection, circuit breaker, scope verification |
| **plan4speckit** | Sonnet-4.5 | ✅ YES | HIGH | Stronger handoff gates, test coverage planning, scope documentation |
| **reviewer4speckit** | Haiku-4.5 | ⚠️ YES | MEDIUM | Add test harness pattern check, scope verification to review checklist |
| **gather-rules** | Haiku-4.5 | ⚠️ YES | LOW | Add confidence scoring, test anti-pattern detection |
| **testinfra** | Haiku-4.5 | ⚠️ YES | MEDIUM | Add test suite health check, ShellCheck availability check, timeout detection |

---

## ✅ Approval Checklist

**Phase 1 (Immediate - Block Next PR)**:
- [ ] Update specfarm.implement4speckit with revB improvements
- [ ] Update specfarm.plan4speckit with stronger gates
- [ ] Add XML rules r099-r104 to rules.xml

**Phase 2 (Next Sprint)**:
- [ ] Update specfarm.reviewer4speckit with test harness checks
- [ ] Update specfarm.testinfra with health checks
- [ ] Add XML rules r105-r107

**Phase 3 (Nice-to-Have)**:
- [ ] Update specfarm.gather-rules with confidence scoring
- [ ] Create optional specfarm.testvalidator4speckit agent

---

**Estimated Effort**:
- Phase 1: ~4-6 hours
- Phase 2: ~2-3 hours  
- Phase 3: ~1-2 hours

**Impact**: Prevents PR #14 class failures across all agents
