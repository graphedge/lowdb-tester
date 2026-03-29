---
description: Shows most recently modified files in repo, grouped by commit (newest first). Helps devs understand recent activity before starting work.
model: claude-haiku-4.5
---

# Historylast Agent

## Command Syntax

**Primary Command**:
```
historylast [num_files] [--exclude-pattern PATTERN] [--output PATH]
```

Examples:
- `historylast` — last 10 files (default)
- `historylast 15` — last 15 files
- `historylast 5 --exclude-pattern "\.md$"` — exclude markdown
- `historylast 10 --output ./reports/` — custom output directory

---

## Purpose

Generate a markdown report of the **most recently modified files**, grouped by commit (newest first). Perfect for dev context: "What changed last?"

**Output Location**: `specs/prompts/recent-edits-{DATE}-{COMMIT-HASH}.md`

**Default Scope**: Last 10 files, ~10-token change descriptions per file

---

## Behavior

### 1. Parse Arguments
- `num_files` (optional, default: 10) — how many recent files to include
- `--exclude-pattern PATTERN` (optional) — regex to exclude files (e.g., `\.log$`, `\.md$`)
- `--output PATH` (optional) — custom output directory (default: `specs/prompts/`)

### 2. Fetch Recent Commits & Files
- Use `git log --name-only --pretty=format:...` to get commits + files
- Sort commits newest-first
- Track unique files (deduped by path, most recent change wins)

### 3. Filter Files
**Always exclude**:
- `.git/`, `*.log`, `*.tmp`, `*.bak`, `*.backup`
- `.gitignore`
- `node_modules/`, `__pycache__/`, `.venv/`, `venv/`
- `dist/`, `build/`, `out/`

**Optionally exclude** (via --exclude-pattern):
- User-provided regex patterns

### 4. Generate Change Descriptions
For each file, extract **~10-token description** from:
- First line of commit message, OR
- Diff stats (insertions/deletions), whichever is clearer

Include **change type**: added/modified/deleted

### 5. Add Classification Labels (if manifest exists)
- Read `.specify/onboarding/directory-manifest.json` (if present)
- For each file, append classification label:
  - Example: `src/drift/drift_engine.sh [production-active]`

### 6. Generate Markdown Report
Output to `specs/prompts/recent-edits-{YYYY-MM-DD}-{HASH7}.md` with structure:

```markdown
# Recent Edits
Generated: {TIMESTAMP} UTC
Showing: {N} most recently touched files (grouped by commit)
Repo: {REPO_NAME}

## Commit {HASH7} ({DATE}) – {AUTHOR} – {SUBJECT}
- `{file/path}` [classification] – {change_type}: {~10_token_description}

## Metadata
- Last commit in report: {HASH}
- Total files shown: {N}
- Files skipped (filter): {N}
- Manifest version (if used): {VERSION}
```

### 7. Handle Edge Cases
- **No commits**: Output "Repository has no commits. Nothing to report."
- **Shallow clone**: Warn user, suggest `git fetch --unshallow`
- **Manifest missing**: Proceed without labels; note in metadata
- **Corrupt git history**: Exit with diagnostic error

---

## Performance Requirements

- Target: Complete in **< 2 seconds** for typical repos (< 100k commits)
- No external deps beyond `git`, `bash`, optional `jq`
- Read-only operation (never modify repo or git state)

---

## Success Criteria

✅ Report in `specs/prompts/recent-edits-{DATE}-{HASH}.md`  
✅ Last N files shown (default 10)  
✅ ~10-token change descriptions  
✅ Commits grouped newest-first  
✅ Noise patterns excluded  
✅ Classification labels included (if manifest present)  
✅ Runs in < 2 seconds  
✅ Edge cases handled gracefully  

---

## Integration

- **Manifest**: Read (optional) `.specify/onboarding/directory-manifest.json`
- **Output**: Markdown saved to `specs/prompts/`
- **Trigger**: Manual/on-request only (no auto-scheduling)
- **Downstream**: Available to speckit CLI, intake agent, wktree

---

## Implementation Reference

See `specs/prompts/historylast-agent.md` for detailed meta prompt and implementation guidance.
