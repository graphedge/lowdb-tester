---
description: Gather rules from recent commits using GitHub Actions context (automated rules discovery for policy enforcement). Enhanced Post-PR14 with confidence scoring and test pattern analysis.
model: claude-haiku-4.5
handoffs: 
  - platform: claude
    label: Review Rules
    agent: speckit.checklist
    prompt: Create a review checklist for the gathered rules
    send: false
  - platform: github
    label: Review Rules
    type: artifact
    action: Upload gathered-rules.md and post link in PR comment
    send: true
---

## Purpose

This agent automatically discovers and extracts rule candidates from recent commits in a SpecFarm repository. Enhanced Post-PR14 with confidence scoring and test anti-pattern detection.

**When to use:**
- PR checks: Scan changes vs base branch to suggest new rules
- Scheduled: Weekly audit of repository patterns
- Manual dispatch: On-demand rules gathering with custom parameters

**New capabilities (Post-PR14):**
- **Confidence scoring**: High/Medium/Low based on commit frequency, author diversity, test coverage
- **Test pattern analysis**: Detects bash arithmetic bugs, exit code issues, test harness quality
- **Rule evidence tracking**: Links rules to specific commits, authors, test coverage

## GitHub Context

The agent operates within GitHub Actions with access to:

- **Repository**: Current repository context via `$GITHUB_WORKSPACE`
- **Commits**: Full commit history (thanks to `fetch-depth: 0`)
- **PR Context**: If running on PR, access to `$GITHUB_BASE_REF` and `$GITHUB_HEAD_REF`
- **GitHub Token**: Optional `$GITHUB_TOKEN` for API calls (PR comments, artifacts)
- **Workflow Context**: Run ID, SHA, branch from `$GITHUB_RUN_ID`, `$GITHUB_SHA`, `$GITHUB_REF`

## Platform-Specific Behavior

### Running as Claude CLI (Copilot)
- When triggered via `/specfarm.gather-rules` in Copilot CLI environment
- Can call `.specfarm/agents/gather-rules-agent-caller.sh` directly
- Receives full CLI toolset (view, edit, bash, grep, etc.)
- User can then trigger `/speckit.checklist` for review (see handoffs)

### Running in GitHub Actions (Cloud Agent)
- Triggered by workflow dispatch, PR, or schedule
- Environment detected: `$GITHUB_ACTIONS=true`
- Cannot access `/speckit.checklist` (no CLI agent framework)
- **Equivalent behavior**: Uploads `gathered-rules.md` as artifact
- **User sees**: PR comment with link to artifact for review

## How It Works

### Execution Flow

1. **Environment Detection**
   - Caller script detects `GITHUB_ACTIONS=true`
   - Routes to GitHub backend via `.specfarm/agents/gather-rules-agent-caller.sh`
   - Injects GitHub credentials and context

2. **Rules Gathering**
   - Core agent executes in GitHub environment
   - Scans commits in specified range (default: `HEAD~20..HEAD`)
   - Extracts rule candidates from:
     - **Test files** (test_* functions, describe blocks)
     - **Specification files** (markdown headers in spec.md, plan.md, etc.)
     - **Changed code** (patterns from modified files)

3. **Output & Artifacts**
   - Generates `gathered-rules.md` markdown report
   - Uploads as GitHub artifact for inspection
   - On PR: Posts comment with summary and results
   - Provides integration instructions

### Rule Candidate Extraction

**From Test Files:**
```
test_platform_detection
test_path_normalization
test_powershell_compatibility
```

**From Specification Files:**
```
## Cross-Platform Abstraction Layer
## PowerShell Wrapper Scripts
## Pre-commit Hook Integration
```

**From Changed Files:**
Analysis of what work was done to suggest governance rules.

## Parameters

### Environment Variables (set by workflow)

| Variable | Description | Example |
|----------|-------------|---------|
| `GITHUB_ACTIONS` | Set to `"true"` (auto-detected) | `true` |
| `GITHUB_TOKEN` | Optional GitHub API token | `ghp_****` |
| `GITHUB_RUN_ID` | Unique workflow run identifier | `12345678` |
| `GITHUB_SHA` | Current commit SHA | `abc123def456...` |
| `GITHUB_REF` | Current branch reference | `refs/heads/main` |
| `GITHUB_WORKSPACE` | Repository root directory | `/home/runner/work/specfarm` |

### CLI Arguments (passed via workflow)

All arguments from the caller are passed through to the core agent:

```bash
bash .specfarm/agents/gather-rules-agent-caller.sh \
  -c "HEAD~10..HEAD"                    # Commit range
  -p "myprefix"                         # Rule ID prefix
  -o /tmp/rules.md                      # Output path
  -n 25                                 # Max rules
  --scan-dirs "src,tests,specs"         # Custom dirs
  --exclude-dirs "vendor,node_modules"  # Exclude dirs
```

## Usage Patterns

### Pattern 1: PR Rules Analysis

**When**: A pull request is created/updated  
**Goal**: Scan PR changes vs base branch to suggest new rules

```yaml
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  analyze-rules:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Analyze rules from PR changes
        run: |
          bash .specfarm/agents/gather-rules-agent-caller.sh \
            -c "origin/${{ github.base_ref }}..HEAD" \
            -p "phase3b"
      
      - name: Post PR comment
        if: always()
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const rulesReport = fs.readFileSync('gathered-rules.md', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '## Rules Gathering Results\n\n' + rulesReport
            });
```

### Pattern 2: Scheduled Weekly Audit

**When**: Weekly schedule (e.g., Sundays 00:00 UTC)  
**Goal**: Continuous monitoring of repository patterns

```yaml
on:
  schedule:
    - cron: '0 0 * * 0'  # Every Sunday at 00:00

jobs:
  weekly-rules-audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Weekly rules gathering
        run: |
          bash .specfarm/agents/gather-rules-agent-caller.sh \
            -c "HEAD~168..HEAD"  # Last 7 days (roughly)
            -p "weekly"
      
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: weekly-rules-report
          path: gathered-rules.md
```

### Pattern 3: Manual Dispatch

**When**: User manually triggers workflow  
**Goal**: On-demand rules gathering with custom parameters

```yaml
on:
  workflow_dispatch:
    inputs:
      commit_range:
        description: Git commit range
        required: true
        default: HEAD~20..HEAD
      rule_prefix:
        description: Rule ID prefix
        required: false
        default: custom

jobs:
  manual-rules-gathering:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Gather rules (manual)
        run: |
          bash .specfarm/agents/gather-rules-agent-caller.sh \
            -c "${{ github.event.inputs.commit_range }}" \
            -p "${{ github.event.inputs.rule_prefix }}"
      
      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: manual-rules-report
          path: gathered-rules.md
```

## Output

### generated Artifacts

1. **gathered-rules.md** (markdown report)
   - Execution summary with repository details
   - Discovery results (changed files, test files, specs)
   - Rule candidates extracted
   - Integration instructions for rules.xml

### PR Comments (if running on PR)

Automatically posted to pull request with:
- Summary of rules discovered
- Number of candidates extracted
- Link to artifact for detailed review

### GitHub Artifacts

All runs upload `gathered-rules.md` as a workflow artifact for:
- Historical tracking
- Review without GitHub token
- Offline inspection

## Implementation Details

### Execution Path

```
.github/workflows/gather-rules.yml
  │
  ├─ Triggers on: PR | Schedule | Manual dispatch
  ├─ Checks out repo (fetch-depth: 0 for full history)
  │
  ├─ Calls: bash .specfarm/agents/gather-rules-agent-caller.sh
  │    │
  │    └─ Detects: GITHUB_ACTIONS=true
  │       Injects: GITHUB_TOKEN, GITHUB_SHA, etc.
  │
  └─ Routes to: .specfarm/agents/gather-rules-agent.sh
       (core agent with GitHub context)
       │
       ├─ Scans commits
       ├─ Extracts candidates
       └─ Generates gathered-rules.md
```

### Error Handling

- **Missing prerequisites**: Script validates git repo and agent files
- **Invalid commit range**: Provides helpful error with git log suggestion
- **No tests/specs found**: Reports gracefully with directory recommendations
- **Output write failure**: Suggests alternative output paths

### GitHub Token Security

- Token is **not** required for basic execution
- Only needed if posting PR comments or accessing GitHub API
- Token is automatically stripped from logs (GitHub Actions feature)
- Recommended: Use `secrets.GITHUB_TOKEN` (auto-provided by GitHub)

## Examples

### Example 1: Check PR for new rules

```bash
# This runs automatically on PR creation/update
# Results posted to PR comments
# Output available in artifacts
```

**Output:**
```markdown
## Rules Gathering Results

### Summary
- Repository: specfarm
- Commits scanned: 5
- Changed files: 12
- Test files found: 8
- Spec files found: 3

### Extracted Rules
- test_platform_detection
- test_path_normalization
- ## Cross-Platform Abstraction Layer
- [...]

### Next Steps
Review the full report in: Artifacts > rules-report
```

### Example 2: Manual rules gathering with custom prefix

```
Workflow: gather-rules.yml
Trigger: Manual dispatch
Inputs:
  commit_range: "v1.0.0..HEAD"
  rule_prefix: "phase3b"
```

**Execution:**
```
bash .specfarm/agents/gather-rules-agent-caller.sh \
  -c "v1.0.0..HEAD" \
  -p "phase3b"
```

**Result:**
- Rule IDs: `phase3b-001`, `phase3b-002`, etc.
- Output: `gathered-rules.md`
- Artifact: Available for download

## Troubleshooting

### Issue: "Commit range may not exist"

**Cause**: Specified range doesn't exist in repository  
**Solution**: Use valid ranges like `HEAD~20..HEAD` or verify with `git log`

### Issue: "No test files found"

**Cause**: Test files don't match expected patterns  
**Solution**: Use `--scan-dirs` to specify custom test directories

### Issue: PR comment not posting

**Cause**: Missing GitHub token or insufficient permissions  
**Solution**: Ensure workflow has `contents: write` permission for PR comments

### Issue: Output file not created

**Cause**: Directory not writable  
**Solution**: Use `-o` flag to specify writable path, e.g., `/tmp/rules.md`

## Related Files

- **Core Agent**: `.specfarm/agents/gather-rules-agent.sh` — Universal agent (enhanced Post-PR14)
- **Caller Script**: `.specfarm/agents/gather-rules-agent-caller.sh` — Router (environment detection)
- **Workflow**: `.github/workflows/gather-rules.yml` — GitHub Actions trigger
- **Documentation**: `.specfarm/agents/RULES-GATHERING-AGENT.md` — Full reference

## Enhanced Features (Post-PR14)

### 1. Rule Confidence Scoring

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
  <constitution-ref>Principle III.B</constitution-ref>
</rule>
```

### 2. Test Pattern Analysis (Anti-Pattern Detection)

While gathering rules, also detect test infrastructure issues:

```bash
# Scan for bash arithmetic bugs
HARNESS_BUGS=$(grep -rn '&& *\\((' tests/ | grep -v '|| true' | wc -l)

if [[ $HARNESS_BUGS -gt 0 ]]; then
  echo "## Test Infrastructure Issues Detected" >> gathered-rules.md
  echo "" >> gathered-rules.md
  echo "Found $HARNESS_BUGS potential bash arithmetic bugs:" >> gathered-rules.md
  grep -rn '&& *\\((' tests/ | grep -v '|| true' | head -10 >> gathered-rules.md
  echo "" >> gathered-rules.md
  echo "**Suggested Rule**: Add r999 - Bash test harness must use || true guards" >> gathered-rules.md
  echo "**Reference**: PR #14 (failed 0%) / PR #15 (fixed)" >> gathered-rules.md
fi

# Check for exit code validation
if ! grep -rq 'exit.*passed.*failed' tests/; then
  echo "**Suggested Rule**: Add r1000 - Test exit codes must match summary" >> gathered-rules.md
fi
```

**Output**: Automatically suggest governance rules for test quality

## Integration with Constitution

This agent supports SpecFarm's **constitution-driven development**:

- Generated rules integrate with `rules.xml` schema validation
- Rule candidates extracted from spec.md feed into planning workflows
- Automated rules gathering enforces consistency across phases

For more information, see:
- `.specify/memory/constitution.md` — Project principles
- `.specfarm/agents/RULES-GATHERING-AGENT.md` — Agent documentation
- `specseeds/` — Phase documents and architectural specs

## See Also

- `/speckit.checklist` — Create a review checklist for rules
- `/speckit.specify` — Define feature specifications
- `/speckit.plan` — Create implementation plans
- `/speckit.tasks` — Generate actionable tasks

---

**Status**: Production-Ready  
**Architecture**: Three-layer hybrid (router → backend → execution)  
**Compatibility**: GitHub Actions + SpecFarm ecosystem
