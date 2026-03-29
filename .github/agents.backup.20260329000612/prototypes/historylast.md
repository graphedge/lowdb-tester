# GitHub Copilot CLI Agent: Recent Edits Reporter

**Agent Name:** recent-edits  
**Description:** Lists the most recently modified files in the repository (across all history), grouped by commit in descending order (newest commits first). Outputs to `.specify/params/Recent Edits.md`. Ignores .git/, .gitignore, logs, and typical temp/junk patterns.

**Invocation Examples (via Copilot CLI or alias):**
- `gh copilot suggest "recent edits"` → default: last 10 files, 10-token summaries
- `gh copilot suggest "recent edits 15"` → last 15 files
- `gh copilot suggest "recent edits 20 12"` → last 20 files, ~12-token blurbs each

**Arguments (positional, parsed from user input):**
1. num_files (optional, int, default: 10) – how many most-recently-touched files to include
2. summary_tokens (optional, int, default: 10) – approximate tokens per file summary

**Behavior Rules:**
- Use `git log --name-only --pretty=format:"%h %ad %an %s" --date=short` to get commits + files
- Sort commits descending (newest first)
- Track unique files across history until reaching requested count (avoid duplicates)
- Ignore patterns: .git/*, *.log, *.tmp, .gitignore, node_modules/, __pycache__/, *.bak, *.backup
- For each commit shown: display commit hash, date, author, short subject
- Under each commit: bullet list of changed files + ~10-token description of change
- Output markdown file: `.specify/params/Recent Edits.md`
- Overwrite existing file (or append timestamp if --append requested, but default overwrite)
- If repo is very large, cap at 50 files max unless overridden

**Output Markdown Structure Example:**

```markdown
# Recent Edits
Generated: 2026-03-23 13:45 EDT  
Showing: 10 most recently touched files (grouped by commit)

## Commit ea27d54 (2026-03-22) – VibeDataScience – Merge dashboard branch
- .github/agents/wktree.agent.md          Added [subject] command syntax support
- specs/prompts/specfarm-briefing.md   Updated vibe tone for stakeholder alignment
- constitution.md                         Amended phase nomenclature rules

## Commit 93af6e8 (2026-03-21) – AgentUpdateBot – Enhance wktree agent
- .github/agents/wktree.agent.md          Modified command syntax documentation

## Commit b912d5e (2026-03-20) – CleanupBot – Remove deprecated agents
- .specfarm-agents/briefer.md             Deleted (moved to .github/agents/)
- .specfarm-agents/rules-filter.md        Deleted (obsolete)

... (continues until 10 files reached or no more commits)