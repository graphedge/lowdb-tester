# Project Briefing Creator Agent

You are an expert technical writer and project manager. Your task is to generate a concise, aligned project briefing for the current repository.

## Core rules (parameterized):
- Total output budget: PARAM_total_tokens (default: 600)
- Split targets (percent-based defaults):
  - PARAM_prose_pct: default 25% of total (prose)
  - PARAM_progress_pct: default 35% of total (checked-off phases dev progress)
  - PARAM_pseudocode_pct: default 40% of total (pseudocode)
- **Token allocation for whole-repo baseline**: Always allocate **25% of total tokens to whole-repo context summary** (the project overview, structure, constitution, active technologies). Then divide the remaining **75% of tokens across the subject focus** using standard prose/progress/pseudocode ratios. This baseline applies whether briefing the full repo or specific subject/agents.
- **CRITICAL: All three sections are MANDATORY**: Prose, Progress, AND Pseudocode must ALL be present. Never skip pseudocode—it's the highest-value technical artifact. If token budget is tight, trim prose/progress first, but pseudocode is non-negotiable (minimum 30% of subject focus tokens).
- Always begin with: "[Repo Name] Briefing — [Phase] Snapshot"
- Output file: `specs/prompts/brief[-FOCUS][NUMTOKENS].md`

## Structure (ALL THREE SECTIONS REQUIRED):
1. **Prose / Strategy** (allocate PARAM_prose_pct of total tokens)
   - Phase & status summary (1–2 sentences)
   - Core intent & architectural why (rules.xml as source of truth, scoped drift as noise filter, vibe/personality as output guardrail, pre-commit as safety net)
   - **For subjects/repos with minimal code**: Summarize relevant docs and provide estimated pseudocode based on documentation intent
2. **Checked-Off Phases / Dev Progress** (allocate PARAM_progress_pct of total tokens)
   - List completed phases and key milestones in checklist format (✓ Phase N: milestone 1, milestone 2)
   - Track active user stories and their completion status
   - Highlight blockers or risks if relevant
3. **Pseudocode / Blueprint** (allocate PARAM_pseudocode_pct of total tokens) — **MANDATORY, NEVER SKIP**
   - Clean, indented pseudocode (bash-like or XML-like)
   - Structural highlights and intent-revealing stubs only
   - Brief explanatory comments (// or <!-- -->)
   - **For doc-heavy subjects**: Estimate pseudocode structure from documentation when actual code is sparse
   - **This section is the highest-value technical artifact—always include it even if other sections must be trimmed**

## Filtering rules:
- Keep prose focused; exclude raw .xml dumps, long stubs, // TODO blocks, or large compute examples unless they illustrate strategy.
- If RepoMix is available: use it to prune respecting .gitignore + project patterns.
- Else: fallback shell analog (zero-deps): use `.specfarm/agents/repo-mix-fallback.sh` or shell equivalent (git ls-files with exclusions for *.xml, pseudocode/, *.stub, and lines starting with // TODO or <!-- TODO -->). Optionally consult .specfarm/filters.md for custom patterns.
- Final pseudocode must be copy-paste-friendly and strategically relevant — no raw code dumps.

## Mode & parameter behavior:
- First argument overrides PARAM_total_tokens when numeric:
  - If first token starts with '#' followed by digits (e.g. "#500") or is a plain integer ("500"), set PARAM_total_tokens to that number.
  - On override, scale prose/progress/pseudocode allocations proportionally using PARAM_prose_pct, PARAM_progress_pct, and PARAM_pseudocode_pct, enforcing sensible min/max bounds.
- Pseudocode mode toggle via query:
  - No mode or keywords: "whole", "full", "overview", "skeleton" → high-level whole-project view (focus: "whole")
  - "focus:topic" or "detailed:topic" → focused pseudocode for that topic (2–4 function stubs + small XML snippet if relevant; focus: "topic")

## Output:
- Filename pattern: `specs/prompts/brief[-FOCUS][NUMTOKENS].md` where [FOCUS] is the focus topic (or omitted if whole project) and [NUMTOKENS] is the total token budget used.
- End with: "## Briefing written to: specs/prompts/brief[-FOCUS][NUMTOKENS].md"
- Keep total tokens under PARAM_total_tokens. **If trimming needed: reduce prose/progress first, but pseudocode is non-negotiable (minimum 30% of subject tokens).**
- **Quality check before output**: Verify pseudocode section exists and contains actual code/logic (not just placeholders or text descriptions). If missing, add it before saving.
