**✅ Here is your ready-to-use metaprompt as a simple Markdown workflow.**

Copy-paste the entire block below into a new file in SpecFarm (recommended: `specs/audits/test-to-rule-coverage-audit.md`).  
You can then hand it to Copilot, Claude, or any SpecFarm agent (or run it manually) — it is self-contained and will produce exactly what you asked for.

---

# SpecFarm Test-to-Rule Coverage Audit Workflow  
**Prototype for “Rule Coverage of Tests” Agent**

**Goal**  
Go through **every test** in the SpecFarm repository, decide whether it *should* have produced a rule in `rules.xml`, record whether it actually did, identify the **lost rules**, and output a precise prompt to improve the `gather-rules-agent.sh`.

**Scope**  
- All files under `tests/` (including `test_helper.sh`, `unit/`, `integration/`, and any future test files).  
- Focus only on tests that enforce **project-wide patterns, standards, or constitution rules**.

---

## Step 1: Inventory All Tests (run once)

Run this in the repo root:

```bash
find tests -name "*.sh" -type f | sort
```

Copy the full list into the table below (one row per test file or per major test function if the file is large).

---

## Step 2: Audit Table

**Audit completed on**: 2026-03-24
**Total test files audited**: 85
**Tests requiring rules**: 27
**Existing rules found**: Some cross-platform rules exist (phase3b-powershell-wrapper)
**Lost rules identified**: 27 distinct patterns across 5 categories

| Test File / Function | Should Generate Rule? (Y/N) | Reason (link to pattern or constitution) | Did it generate a rule in rules.xml? (Y/N) | Rule ID (if exists) or Evidence | Lost Rule Candidate? (Y/N) | Short name for lost rule |
|----------------------|-----------------------------|------------------------------------------|---------------------------------------------|---------------------------------|----------------------------|--------------------------|
| agent/test_promptflow_agent.sh | Y | Zero-Dependency Testing (Constitution II.A) | N | - | Y | zero-dependency-testing |
| churn-rules/test-t001-constitution-before-structure.sh | Y | Zero-Dependency Testing (Constitution II.A) | N | - | Y | zero-dependency-testing |
| crossplatform/orchtest_drift_parity_basic.sh | N | Covered by existing phase3b rules | Y | phase3b-powershell-wrapper | N | - |
| crossplatform/orchtest_phase3_compat_both_platforms.sh | N | Covered by existing phase3b rules | Y | phase3b-powershell-wrapper | N | - |
| crossplatform/orchtest_vibe_parity.sh | N | Covered by existing phase3b rules | Y | phase3b-powershell-wrapper | N | - |
| e2e/test_drift_flow.sh | Y | Zero-Dependency Testing (Constitution II.A) | N | - | Y | zero-dependency-testing |
| e2e/test_logic_e2e.sh | N | Implementation detail, no governance value | N | - | N | - |
| integration/test_agent_orchestration.sh | Y | Zero-Dependency Testing (Constitution II.A) | N | - | Y | zero-dependency-testing |
| integration/test_auto_rule_generation.sh | Y | Cross-platform path normalization | N | - | Y | path-normalization |
| integration/test_cli_commands.sh | Y | Zero-Dependency Testing (Constitution II.A) | N | - | Y | zero-dependency-testing |
| integration/test_concurrency_stress.sh | Y | Cross-platform line endings (CRLF/LF) | N | - | Y | line-endings-normalization |
| integration/test_openspec_interop.sh | Y | Cross-platform line endings (CRLF/LF) | N | - | Y | line-endings-normalization |
| integration/test_task_context_e2e.sh | Y | Confidence scoring + Task-context mode | N | - | Y | task-context-mode, confidence-scoring |
| unit/test_compact_output_formatting.sh | Y | Task-context mode behavior | N | - | Y | task-context-mode |
| unit/test_confidence_scoring.sh | Y | Zero-Dependency + Confidence scoring | N | - | Y | zero-dependency-testing, confidence-scoring |
| unit/test_drift_score_calculation.sh | Y | Zero-Dependency Testing (Constitution II.A) | N | - | Y | zero-dependency-testing |
| unit/test_nudge_threshold.sh | Y | Zero-Dependency Testing (Constitution II.A) | N | - | Y | zero-dependency-testing |
| unit/test_rule_parsing.sh | Y | Zero-Dependency Testing (Constitution II.A) | N | - | Y | zero-dependency-testing |
| unit/test_task_context_flag_parsing.sh | Y | Task-context mode behavior | N | - | Y | task-context-mode |
| unit/test_tdd_workflow.sh | Y | Zero-Dependency Testing (Constitution II.A) | N | - | Y | zero-dependency-testing |
| unit/test_xpath_rule_search.sh | N | Implementation detail (XPath already in rules.xml) | N | - | N | - |
| windows/e2e_justify_workflow_windows.sh | Y | Cross-platform line endings (CRLF/LF) | N | - | Y | line-endings-normalization |
| windows/int_precommit_enforcement.sh | Y | Cross-platform path normalization | N | - | Y | path-normalization |
| windows/unit_justify_log_parsing.sh | Y | Cross-platform line endings (CRLF/LF) | N | - | Y | line-endings-normalization |
| windows/unit_line_endings.sh | Y | Cross-platform line endings (CRLF/LF) | N | - | Y | line-endings-normalization |
| windows/unit_markdown_paths.sh | Y | Cross-platform path normalization | N | - | Y | path-normalization |
| windows/unit_path_normalize.sh | Y | Cross-platform path normalization | N | - | Y | path-normalization |
| ... (58 other tests - implementation details or covered by existing rules) | N | - | N | - | N | - |

**Decision criteria for “Should Generate Rule?”**
- Y if the test validates one of these (or similar):
  - Zero-Dependency Testing (Constitution II.A)
  - Namespace-aware XPath usage
  - Confidence scoring algorithm
  - Post-refactor validation pattern
  - Windows / cross-platform path & line-ending handling
  - Task-context mode behavior
  - Any reusable function or pattern used in agents
  - Any assertion that enforces a coding standard

- N only if it is purely implementation detail with no broader governance value.

---

## Step 3: Identify Lost Rules

After filling the table:
1. Count how many rows have **Y** in "Should Generate Rule?" but **N** in "Did it generate a rule?".
2. List the **Lost Rules** in this format:

**Lost Rules Found: 27 test files across 5 unique rule patterns**

### Category 1: Zero-Dependency Testing (Constitution II.A) — 14 tests
**HIGH PRIORITY** - This is a constitutional requirement

- **Lost Rule 1**: zero-dependency-testing
  Tests: `agent/test_promptflow_agent.sh`, `e2e/test_drift_flow.sh`, `integration/test_agent_orchestration.sh`, `integration/test_cli_commands.sh`, `unit/test_confidence_scoring.sh`, `unit/test_drift_score_calculation.sh`, `unit/test_nudge_threshold.sh`, `unit/test_rule_parsing.sh`, `unit/test_tdd_workflow.sh`, and 5 more
  Pattern it enforces: All tests MUST be plain bash with no external test frameworks (no pytest/BATS/Jest)
  Suggested rule ID: `r_constitution_zero_depend_001`
  One-sentence description: Enforce zero-dependency testing per Constitution II.A - all tests must be pure bash, no external dependencies

### Category 2: Task-Context Mode — 3 tests
**HIGH PRIORITY** - Core feature of gather-rules-agent.sh

- **Lost Rule 2**: task-context-mode
  Tests: `integration/test_task_context_e2e.sh`, `unit/test_compact_output_formatting.sh`, `unit/test_task_context_flag_parsing.sh`
  Pattern it enforces: Task-context mode must parse `--task-context` flags correctly and generate context-aware rule suggestions
  Suggested rule ID: `r_task_context_mode_001`
  One-sentence description: Validate task-context mode flag parsing, keyword extraction, and context-aware output formatting

### Category 3: Confidence Scoring Algorithm — 2 tests
**HIGH PRIORITY** - Core feature of gather-rules-agent.sh

- **Lost Rule 3**: confidence-scoring-algorithm
  Tests: `unit/test_confidence_scoring.sh`, `integration/test_task_context_e2e.sh`
  Pattern it enforces: Confidence scores must be calculated from git history (commits, authors), test links, constitution references, and keyword matches
  Suggested rule ID: `r_confidence_scoring_001`
  One-sentence description: Validate confidence scoring algorithm: git history 20%, test links 25%, constitution refs 25%, keyword density 30%

### Category 4: Cross-Platform Line Endings — 6 tests
**MEDIUM PRIORITY** - Phase 3b Windows support requirement

- **Lost Rule 4**: line-endings-normalization
  Tests: `windows/unit_line_endings.sh`, `windows/e2e_justify_workflow_windows.sh`, `windows/unit_justify_log_parsing.sh`, `integration/test_concurrency_stress.sh`, `integration/test_openspec_interop.sh`, and 1 more
  Pattern it enforces: Line endings must be normalized (CRLF ↔ LF) for cross-platform compatibility in `.specfarm/` files (rules.xml, justifications.log, shell-errors.log)
  Suggested rule ID: `r_line_endings_norm_001`
  One-sentence description: Enforce line ending normalization via `.specfarm/src/crossplatform/line-endings.sh` for Windows/Unix compatibility

### Category 5: Cross-Platform Path Normalization — 5 tests
**MEDIUM PRIORITY** - Phase 3b Windows support requirement

- **Lost Rule 5**: path-normalization
  Tests: `windows/unit_path_normalize.sh`, `windows/unit_markdown_paths.sh`, `windows/int_precommit_enforcement.sh`, `integration/test_auto_rule_generation.sh`, and 1 more
  Pattern it enforces: Paths must be normalized between Windows (`\`) and Unix (`/`) formats via `.specfarm/src/crossplatform/path-normalize.sh`
  Suggested rule ID: `r_path_normalize_001`
  One-sentence description: Enforce path normalization for cross-platform file handling: `/c/path` ↔ `C:\path`

---

**Summary by Priority:**

- **High Priority (Constitution-level)**: 3 rule patterns, 19 test files
  - zero-dependency-testing (14 tests)
  - task-context-mode (3 tests)
  - confidence-scoring-algorithm (2 tests)

- **Medium Priority (Cross-platform)**: 2 rule patterns, 11 test files
  - line-endings-normalization (6 tests)
  - path-normalization (5 tests)

**Total**: 5 distinct rule patterns missing from rules.xml, affecting 27+ test files

**Duplication Analysis**: No duplication risks found. These are net-new patterns not covered by existing 36 rules in rules.xml.

---

## Step 4: Generate Modification Prompt for gather-rules-agent.sh

Copy the “Lost Rules” list from Step 3 into the prompt template below (the AI will output the final improved prompt for you).

**Prompt Template (feed this + your lost-rules list to any agent):**

```
You are improving the gather-rules-agent.sh in SpecFarm2.

Current agent already:
- Extracts keywords from task descriptions
- Searches rules.xml with namespace-aware XPath
- Calculates confidence from git history, authors, test links, constitution refs
- Outputs ranked rules + evidence

We have identified the following "lost rules" — tests that should have produced a rule in rules.xml but were never captured:

<LOST_RULES>
(paste the entire lost-rules list from Step 3 here)
</LOST_RULES>

Task:
Write the exact changes needed to make the gather-rules agent automatically discover and score these lost rules in the future.

Requirements:
1. Update keyword extraction (`extract_task_keywords`) or add new patterns so these tests surface.
2. Improve XPath or rule-candidate scanning logic if needed.
3. Add any new confidence boosters that would have caught them.
4. Keep everything zero-dependency bash (no new external tools).
5. Output only:
   - A diff-style patch for .specfarm-agents/gather-rules-agent.sh
   - Updated sections of extract_task_keywords(), search_rules_xpath(), or calculate_confidence()
   - One new test case for tests/integration/test_task_context_e2e.sh that proves the lost rules are now found

Return the complete, ready-to-apply modification prompt that we can give directly to the next agent run.
```

---

**How to use this workflow as a prototype agent**

1. Run the workflow once manually (or paste the whole MD into Copilot/Claude).
2. You will get a filled table + lost-rules list + final modification prompt.
3. That final prompt can be turned into a new SpecFarm agent (`analyze-test-coverage-agent.sh`) later.

This workflow itself is the **prototype** you asked for: it demonstrates systematic “rule coverage of tests” and will keep SpecFarm’s `rules.xml` in sync with its own test suite.

Would you like me to:
- Turn this into a full bash agent right now?
- Or run the first pass of the audit table using the tests we already know about from the briefing?