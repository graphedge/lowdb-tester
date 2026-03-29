# Formal Agent Evaluation: wktree.md & rules-filter.md

**Framework**: speckit.analyze.agent.md (read-only analysis, consistency, ambiguity, coverage focus)

**Date**: 2026-03-16  
**Evaluator**: Copilot CLI

---

## AGENT 1: wktree.md (Git Worktree Automation)

### Strengths ✓
- Clear trigger phrases (4 distinct entry points)
- Deterministic naming logic (kebab-case, 5–18 chars, lowercase)
- Execution-first design ("Execute, don't simulate")
- State reuse detection (git worktree list check)
- Shared file protection model (prevents collision)

---

### CRITICAL Issues 🔴

#### 1. Missing cleanup/removal workflow
- **Problem**: Agent creates worktrees but never addresses how to finish/remove them
- **Impact**: Orphaned worktrees accumulate; no clear "exit task" or cleanup command
- **Severity**: CRITICAL (blocks production use)
- **Recommendation**: Add step 9: "On task completion, run: `git worktree remove ../specfarm-[name]`" OR link to cleanup companion agent

#### 2. Global `chmod -w` blocks parallel work
- **Problem**: Line 35 says "make them read-only globally (since files are shared): chmod -w <file1>"
- **Impact**: ONE worktree locking a file prevents edits in ALL parallel trees — contradicts multi-tree safety model
- **Severity**: CRITICAL (defeats parallelism)
- **Recommendation**: Replace with `git worktree lock [worktree]` OR clarify that these are truly *shared* (not per-tree) state files

---

### HIGH Issues 🟠

#### 3. "Infer 3–8 files" heuristic is vague
- **Problem**: Line 33 says "infer 3–8 files most likely to be modified" but provides no explicit criteria
- **Impact**: Different models/runs pick different file sets; not deterministic
- **Severity**: HIGH (non-deterministic behavior)
- **Recommendation**: Replace inference with explicit rule:
  ```
  Protected files = {.specfarm/, rules.xml}
  IF task touches src/drift/ → add src/drift/drift_engine.sh
  IF task touches src/vibe/ → add src/vibe/nudge_engine.sh
  ```

#### 4. Background watch uses Bash-ism
- **Problem**: Line 38 uses `disown %%` which is Bash-specific; fails in POSIX shells
- **Impact**: Script fails silently on pure POSIX systems
- **Severity**: HIGH (portability)
- **Recommendation**: Use `nohup tail -f .specfarm/error-memory.md > /tmp/wktree-watch.log 2>&1 &` OR document "Requires Bash"

#### 5. No branch conflict fallback
- **Problem**: Line 29 attempts `git worktree add` but doesn't handle case where `feature/[name]` branch already exists remotely
- **Impact**: Command fails silently; user confused
- **Severity**: HIGH (error recovery)
- **Recommendation**: Add fallback logic:
  ```
  If branch exists: offer user choices
  (1) Reuse existing branch
  (2) Auto-suffix with -v2
  (3) Abort and pick different name
  ```

---

### MEDIUM Issues 🟡

#### 6. Step numbering inconsistency
- **Problem**: Instructions say "in order" (step 1–8) but step 8 says "do NOT ask for confirmation unless"—suggests some async behavior
- **Severity**: MEDIUM (clarity)
- **Recommendation**: Reorder to: steps 1–7 (setup), step 8 (confirmation logic), step 9 (cleanup)

---

## AGENT 2: rules-filter.md (XML Rules Export)

### Strengths ✓
- 7 sequential filter conditions (clear, testable logic)
- Safety-first conservatism ("If filtering logic ambiguous → keep the rule")
- XML-aware (preserves attributes, comments, child elements)
- Auto-generated header with timestamp and rule count
- Clear workflow: parse → filter → validate → commit → PR

---

### CRITICAL Issues 🔴

#### 1. Constitution integration missing
- **Problem**: No reference to `.specify/memory/constitution.md` as filter source
- **Impact**: May export rules that conflict with project's core principles (MUST violations)
- **Severity**: CRITICAL (governance violation)
- **Recommendation**: Add step 2.5:
  ```
  Load .specify/memory/constitution.md
  If constitution defines 'preferred-rules' or 'rule-category-weights':
    Apply those BEFORE generic scope/category filtering
  ```

#### 2. No XML parse error handling
- **Problem**: Step 1 says "parse rules.xml" but doesn't specify error behavior if parse fails
- **Impact**: Malformed rules.xml → silent failure OR corrupted rules-export.xml
- **Severity**: CRITICAL (data integrity)
- **Recommendation**: Add:
  ```
  If xmllint parse fails:
    Emit diagnostic: "rules.xml line N: <error message>"
    Abort and DO NOT write rules-export.xml
  ```

---

### HIGH Issues 🟠

#### 3. Ambiguous scope + applies-to boolean logic
- **Problem**: Filter #1 says "Keep rules with `<scope>` OR `<applies-to>` that includes repo, 'all', 'specfarm', or no scope"
- **Ambiguity**: What if `<scope>` = "specfarm" but `<applies-to>` = "other-repo"? Which wins?
- **Severity**: HIGH (logic contradiction)
- **Recommendation**: Clarify:
  ```
  scope_match = (no <scope> tag) OR (<scope> matches repo/all/specfarm)
  applies_match = (no <applies-to> tag) OR (<applies-to> matches repo)
  Keep if: (scope_match AND applies_match) OR (scope_match AND no applies-to)
  Default: INCLUSIVE (err on keeping)
  ```

#### 4. No output validation
- **Problem**: Step 5 writes rules-export.xml but doesn't verify it's well-formed XML
- **Impact**: Downstream tools fail parsing corrupted export; no diagnostic
- **Severity**: HIGH (data quality)
- **Recommendation**: Add after write:
  ```
  if ! xmllint --noout rules-export.xml 2>&1; then
    echo "ERROR: rules-export.xml is malformed; aborting commit"
    exit 1
  fi
  ```

#### 5. Repo name detection is underspecified
- **Problem**: Step 2 says "determine current repo context (name, files present, OS hints)"—but HOW?
- **Impact**: Different runs may infer different repo names; filtering inconsistent
- **Severity**: HIGH (non-determinism)
- **Recommendation**: Add explicit method:
  ```
  repo_name=$(git config --get remote.origin.url | sed 's|.*/\([^.]*\)\.git||')
  echo "Detected repo: $repo_name"
  ```

---

### MEDIUM Issues 🟡

#### 6. Multi-platform rule precedence unclear
- **Problem**: Filter #4 says "Prefer rules tagged with `<category>` = 'powershell'" for repos with PowerShell
- **Impact**: May exclude Bash rules if PowerShell preferred, causing incomplete export
- **Severity**: MEDIUM (cross-platform support)
- **Recommendation**: Clarify:
  ```
  For multi-platform repos (both .sh and .ps1):
    Keep BOTH Bash AND PowerShell rule categories
    Don't deprioritize Bash rules
  ```

#### 7. No logging to error-memory
- **Problem**: Agent doesn't record filtered rules/decisions to `.specfarm/error-memory.md`
- **Impact**: No audit trail; hard to debug filtering decisions later
- **Severity**: MEDIUM (observability)
- **Recommendation**: Add:
  ```
  Log to .specfarm/error-memory.md:
    - Repo name detected
    - Rules applied count
    - Rules excluded count
    - Any filtering ambiguities
  ```

---

## Cross-Agent Consistency Issues

| Issue | wktree.md | rules-filter.md | Severity |
|-------|-----------|-----------------|----------|
| Trigger phrase format | "autostart T0445" | "@rules-exporter filter" | LOW (stylistic) |
| Constitution reference | None | Missing | HIGH (governance) |
| Error handling on ambiguity | Minimal | Minimal | HIGH (robustness) |
| Determinism | Good (explicit names) | Vague (inferred repo) | HIGH (reproducibility) |
| Observability logging | No mention | No mention | MEDIUM (auditability) |
| Output validation | No mention | No mention | HIGH (data integrity) |

---

## Clarifying Questions for You

**Before I suggest concrete modifications, please clarify:**

1. **wktree.md file protection**: Should protected files use `git worktree lock [name]` instead of global `chmod -w`? (Preserves parallel safety)

2. **rules-filter.md constitution priority**: Is `.specify/memory/constitution.md` the SINGLE SOURCE OF TRUTH for rule preferences, or should generic scope matching override it?

3. **Both agents - error behavior**: When encountering ambiguity (e.g., branch exists, XML parse fails):
   - **Conservative**: Abort with diagnostic and ask user
   - **Pragmatic**: Warn but proceed with safe fallback
   - Which policy?

4. **Both agents - observability**: Should agents log all decisions to `.specfarm/error-memory.md` for audit trail? (Optional, but aids debugging)

5. **wktree.md cleanup**: Should cleanup be a separate agent (e.g., `finish-worktree.md`) or integrated into existing agent?

---

## Modification Roadmap (If You Approve)

### wktree.md (5 fixes → estimated 25 lines added/modified)
- [ ] Add cleanup/removal step + command examples
- [ ] Replace vague "infer files" with explicit rule table
- [ ] Fix global `chmod -w` → clarify OR replace with `git worktree lock`
- [ ] Document Bash requirement OR provide POSIX fallback
- [ ] Add branch conflict fallback logic

### rules-filter.md (6 fixes → estimated 30 lines added/modified)
- [ ] Integrate `.specify/memory/constitution.md` as filter source
- [ ] Add XML parse error handling + diagnostics
- [ ] Clarify scope/applies-to boolean logic with examples
- [ ] Add output validation (xmllint check before commit)
- [ ] Specify repo name detection method explicitly
- [ ] Clarify multi-platform rule precedence
- [ ] (Optional) Add `.specfarm/error-memory.md` logging

---

## Summary

Both agents are **well-designed but incomplete**. They need:
- **Better error handling** (parse failures, branch conflicts)
- **Explicit logic** (file inference, repo detection, boolean filters)
- **Constitution integration** (governance layer)
- **Determinism** (same inputs → same outputs across runs)
- **Observability** (audit trail for debugging)

**Next Step**: Answer the 5 clarifying questions above, and I'll provide exact concrete modifications to both files.
