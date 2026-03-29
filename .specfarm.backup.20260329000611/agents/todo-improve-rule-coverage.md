You are improving the gather-rules-agent.sh in SpecFarm2.

Current capabilities:
- Keyword extraction from tasks
- Namespace-aware XPath search in rules.xml
- Confidence scoring (commits, authors, test links, constitution refs, keywords)
- Task-context mode

Audit results attached:

<LOST_RULES>
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
</LOST_RULES>

<DUPLICATION_RISKS>
**Duplication Analysis Results: CLEAN**

After reviewing all 36 existing rules in rules.xml and comparing with the 5 lost rules:

- **No duplication risks detected**
- **No overlapping patterns found**
- **No similar rules requiring merge**

The lost rules are entirely new patterns not covered by existing governance:
1. zero-dependency-testing - NEW (constitution enforcement)
2. task-context-mode - NEW (gather-rules agent feature)
3. confidence-scoring-algorithm - NEW (gather-rules agent feature)
4. line-endings-normalization - NEW (Phase 3b cross-platform)
5. path-normalization - NEW (Phase 3b cross-platform)

Existing rules cover: shell preferences, error handling, logging, pre-commit gates, and Phase 2 structure.
Lost rules add: Constitution compliance testing, agent feature validation, Windows compatibility.

**Recommendation**: Proceed with adding all 5 lost rules without merge conflicts.
</DUPLICATION_RISKS>

<Task>
Enhance the gather-rules agent so it:
1. Better discovers the lost rules above (update keyword extraction, XPath patterns, or confidence boosters).
2. Actively detects potential rule duplications when scanning or when a new rule candidate appears.
3. Suggests merges or refinements for similar rules.

Requirements (strict):
- Remain pure bash, zero external dependencies beyond git + xmllint.
- Add logic (or new helper functions) to compare rule descriptions/names/metadata for similarity (simple string overlap, shared keywords, or constitution section).
- Output:
   - Diff-style patch for .specfarm-agents/gather-rules-agent.sh
   - Updated extract_task_keywords(), search_rules_xpath(), calculate_confidence(), and any new duplication_check() function
   - One or two new test cases that prove both lost rules are found AND duplication risks are flagged
   - A short recommendation on whether to add a --audit-duplicates flag

Return a complete, ready-to-apply modification prompt we can give to the next agent.