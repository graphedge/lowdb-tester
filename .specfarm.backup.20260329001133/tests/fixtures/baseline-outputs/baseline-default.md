# Rules Gathering Report — specfarm2

**Generated**: 2026-03-27T03:57:13Z
**Repository**: /storage/emulated/0/Download/github/specfarm2
**Commit Range**: HEAD~10..HEAD
**Maximum Rules**: 20
**Rule Prefix**: auto

---

## Execution Summary

### Environment
- **Project**: specfarm2
- **Git Repository**: /storage/emulated/0/Download/github/specfarm2
- **Branch**: 010-update-gather-rules-agent
- **Schema**: rules-schema.xsd

### Scan Configuration
- **Scan Directories**: src,tests,specs,specs/prompts,docs
- **Excluded Patterns**: third-party,build,config,.github,node_modules,venv,__pycache__,.git,.specfarm
- **Commit Range**: HEAD~10..HEAD

### Discovery Results

#### Changed Files
```
  
  [0;32m===[0m [0;34mAnalyzing Changed Files[0m [0;32m===[0m
    [0;32m[✓][0m Analyzed 30 changed files
  .specfarm-agents/gather-rules-agent.sh
  .specfarm-agents/intake-agent.md
  .specfarm/error-memory.md
  .specify/amendments/2026-03-18-churn-reduction.md
  .specify/experiments/briefing-variants/MIGRATION-MAP.md
  .specify/experiments/briefing-variants/specfarm-briefing-terse.md
  .specify/experiments/briefing-variants/specfarm-briefing-whole-1500.md
  .specify/experiments/briefing-variants/specfarm-briefing-whole-2500.md
  .specify/experiments/briefing-variants/specfarm-briefing-whole-2501.md
  .specify/experiments/briefing-variants/specfarm-briefing3000.md
  .specify/memory/constitution.md
  .specify/onboarding/orphaned-agents-manifest.md
```

#### Test Files Found
  
  [0;32m===[0m [0;34mLocating Test Files[0m [0;32m===[0m
    [0;32m[✓][0m Found 20 test files
  /storage/emulated/0/Download/github/specfarm2/.specify/tests/test-phase1-completion.sh
  /storage/emulated/0/Download/github/specfarm2/scripts/run_policy_tests_local.sh
  /storage/emulated/0/Download/github/specfarm2/tests/churn-rules/test-t001-constitution-before-structure.sh
  /storage/emulated/0/Download/github/specfarm2/tests/churn-rules/test-t002-migration-audit.sh
  /storage/emulated/0/Download/github/specfarm2/tests/churn-rules/test-t003-prompts-readonly.sh
  /storage/emulated/0/Download/github/specfarm2/tests/crossplatform/orchtest_drift_multi_rules_parity.sh
  /storage/emulated/0/Download/github/specfarm2/tests/crossplatform/orchtest_drift_parity_basic.sh

#### Specification Files Found
  
  [0;32m===[0m [0;34mLocating Specification Files[0m [0;32m===[0m
    [0;32m[✓][0m Found 20 specification files
  /storage/emulated/0/Download/github/specfarm2/.github/agents/archive/2026-03-19-pr14-improvements/specfarm.gather-rules-DIFF.md
  /storage/emulated/0/Download/github/specfarm2/.github/agents/archive/2026-03-19-pr14-improvements/specfarm.gather-rules.agent.md-BEFORE.md
  /storage/emulated/0/Download/github/specfarm2/.github/agents/archive/2026-03-19-pr14-improvements/specfarm.implement4speckit-DIFF.md
  /storage/emulated/0/Download/github/specfarm2/.github/agents/archive/2026-03-19-pr14-improvements/specfarm.implement4speckit.agent.md-BEFORE.md
  /storage/emulated/0/Download/github/specfarm2/.github/agents/archive/2026-03-19-pr14-improvements/specfarm.plan4speckit-DIFF.md
  /storage/emulated/0/Download/github/specfarm2/.github/agents/archive/2026-03-19-pr14-improvements/specfarm.plan4speckit.agent.md-BEFORE.md
  /storage/emulated/0/Download/github/specfarm2/.github/agents/archive/2026-03-19-pr14-improvements/specfarm.reviewer4speckit-DIFF.md

#### Rule Candidates Extracted
```

[0;32m===[0m [0;34mExtracting Rule Candidates[0m [0;32m===[0m
  [1;33m[INFO][0m Scanning test files for rule patterns...
  [1;33m[INFO][0m Scanning specification files for rule patterns...
  Source: /storage/emulated/0/Download/github/specfarm2/.github/agents/archive/2026-03-19-pr14-improvements/specfarm.gather-rules.agent.md-BEFORE.md: ### Pattern 1: PR Rules Analysis
  Source: /storage/emulated/0/Download/github/specfarm2/.github/agents/archive/2026-03-19-pr14-improvements/specfarm.gather-rules.agent.md-BEFORE.md: ### Pattern 2: Scheduled Weekly Audit
  Source: /storage/emulated/0/Download/github/specfarm2/.github/agents/archive/2026-03-19-pr14-improvements/specfarm.gather-rules.agent.md-BEFORE.md: ### Pattern 3: Manual Dispatch
  Source: /storage/emulated/0/Download/github/specfarm2/.github/agents/archive/2026-03-19-pr14-improvements/specfarm.implement4speckit.agent.md-BEFORE.md: ## Task: [TASK_ID] - [Title]
  Source: /storage/emulated/0/Download/github/specfarm2/.github/agents/archive/2026-03-19-pr14-improvements/specfarm.implement4speckit.agent.md-BEFORE.md: ### Task: [TASK_ID] - [Title] ✓ COMPLETE
  Source: /storage/emulated/0/Download/github/specfarm2/.github/agents/archive/2026-03-19-pr14-improvements/specfarm.plan4speckit.agent.md-BEFORE.md: #### Task Format (per task):
  Source: /storage/emulated/0/Download/github/specfarm2/.github/agents/archive/2026-03-19-pr14-improvements/specfarm.plan4speckit.agent.md-BEFORE.md: ### Task: [TASK_ID] - [Brief Title]
  Source: /storage/emulated/0/Download/github/specfarm2/.github/agents/archive/2026-03-19-pr14-improvements/specfarm.plan4speckit.agent.md-BEFORE.md: #### Task Organization:
  Source: /storage/emulated/0/Download/github/specfarm2/.github/agents/archive/2026-03-19-pr14-improvements/specfarm.reviewer4speckit.agent.md-BEFORE.md: ### Phase 1: Intake & Triage
  Source: /storage/emulated/0/Download/github/specfarm2/.github/agents/archive/2026-03-19-pr14-improvements/specfarm.reviewer4speckit.agent.md-BEFORE.md: ### Phase 2: Constitution Validation (Mandatory)
  Source: /storage/emulated/0/Download/github/specfarm2/.github/agents/archive/2026-03-19-pr14-improvements/specfarm.reviewer4speckit.agent.md-BEFORE.md: ### Phase 3: CI Status Audit (Enhanced Post-PR13)
  Source: /storage/emulated/0/Download/github/specfarm2/.github/agents/specfarm.gather-rules.agent.md: ### Pattern 1: PR Rules Analysis
  Source: /storage/emulated/0/Download/github/specfarm2/.github/agents/specfarm.gather-rules.agent.md: ### Pattern 2: Scheduled Weekly Audit
  Source: /storage/emulated/0/Download/github/specfarm2/.github/agents/specfarm.gather-rules.agent.md: ### Pattern 3: Manual Dispatch
  Source: /storage/emulated/0/Download/github/specfarm2/.github/agents/specfarm.implement4speckit.agent.md: ## Task: [TASK_ID] - [Title]
  Source: /storage/emulated/0/Download/github/specfarm2/.github/agents/specfarm.implement4speckit.agent.md: ### Task: [TASK_ID] - [Title] ✓ COMPLETE
```

---

## Integration Instructions

### Step 1: Review Extracted Candidates
Review the rule candidates above and identify which patterns should become formal XML rules.

### Step 2: Generate XML Rules
For each candidate, create a `<rule>` element following this template:

```xml
<rule id="PREFIX-FEATURE-000N" enabled="true" severity="warn" phase="post-analysis">
  <name>Rule Title</name>
  <description>Detailed description of what this rule checks</description>
  <rationale>Link to source file or task that motivated this rule</rationale>
  <metadata>
    <source>Source file path</source>
    <test_link>tests/path/to/test.sh::test_name</test_link>
  </metadata>
</rule>
```

### Step 3: Validate Against Schema
```bash
xmllint --schema /storage/emulated/0/Download/github/specfarm2/rules-schema.xsd rules.xml --noout
```

### Step 4: Integrate into Project
Add generated rules to your project's `rules.xml` file (or equivalent).

---

## Next Steps

1. **Analyze Candidates**: Review extracted rule candidates above
2. **Create Rules**: Generate formal XML rule definitions
3. **Test**: Validate rules against schema (/storage/emulated/0/Download/github/specfarm2/rules-schema.xsd)
4. **Commit**: Add rules to version control

---

## Report Metadata

- **Scan Date**: 2026-03-27
- **Scan Time**: 
- **Report File**: tests/fixtures/baseline-outputs/baseline-default.md
- **Schema File**: /storage/emulated/0/Download/github/specfarm2/rules-schema.xsd

For questions or issues, refer to the gather-rules-agent.sh script documentation.

