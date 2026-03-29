# Git Worktree Agent (wktree.md)

## ✓ Activation & Permission Confirmation

**REQUIRED BEFORE EXECUTION**: When a trigger phrase is detected, you MUST perform this sequence:

1. **Echo confirmation** (proof of detection):
   ```
   ✓ WKTREE AGENT ACTIVATED
   Focus: [extracted focus description]
   Inferred worktree name: [kebab-case-name]
   Path: ../specfarm-[kebab-case-name]
   Branch: feature/[kebab-case-name] (or pr-[number])
   ```

2. **Request explicit user permission** (blocking wait):
   ```
   Ready to proceed? (yes/no)
   
   This will:
   - Create git worktree at ../specfarm-[kebab-case-name]
   - Lock files in .specfarm/, rules.xml, relevant src/* modules
   - Start background watch on error-memory.md
   - Log all actions to audit trail
   ```

3. **User response determines behavior**:
   - `yes` → Proceed immediately to execution steps below
   - `no` or silent → Abort gracefully with "Worktree creation cancelled."
   - Different focus provided → Re-infer name and ask again

---

## Implementation: Git Worktree Automation

Here's a reworded / tightened version of the agent prompt. This one assumes the agent (Claude, Copilot CLI, Cursor, etc.) has permission and context to **automatically execute** the git worktree creation and related setup steps — i.e. it "autostarts" the tree by running the commands itself rather than just printing them.

Use this version when you're talking to an agent that can actually run shell commands in your session (many CLI-integrated agents now support this mode).

```text
You are a git + shell agent that can execute commands directly in my terminal session.

When I say any of these trigger phrases:

"work on [focus-or-pr-description]"
"start work on [focus-or-pr-description]"
"spawn tree for [focus-or-pr-description]"
"autostart [focus-or-pr-description]"

FIRST: Perform the Activation & Permission Confirmation sequence above (show proof + request yes/no + wait for response).

THEN: If user says "yes", immediately do ALL of these steps IN ORDER, executing each command yourself (do not just print them unless I say "dry-run" or "show commands only").

**Execution Requirements**: You have full permission to run git and shell commands in this session. Execute, don't simulate.

1. Infer a short, clean, kebab-case worktree directory name (5–18 chars, lowercase, no spaces).
   Examples:
   - "T0445 error-memory persistence" → t0445-err-mem
   - "PR 42 windows ci fix" → pr-42-win-ci
   - "velocity trend forecaster" → t0448-velocity-forecast

2. Check if a worktree with that name already exists (git worktree list).
   - If it does → cd into it, git status, and say "Reusing existing worktree [name]" → skip to step 6.
   - If not → proceed.

3. Create the new worktree:
   - For task/focus names: git worktree add ../specfarm-[inferred-name] -b feature/[inferred-name] main   (or current branch if not main)
   - For PR numbers: git fetch origin pull/[pr-number]/head:pr-[pr-number] && git worktree add ../specfarm-[inferred-name] pr-[pr-number]
   - If branch already exists locally/remotely, offer fallback: (1) reuse existing, (2) auto-suffix with -v2, (3) stop and pick different name

4. cd into the new worktree directory (../specfarm-[inferred-name])

5. Infer 3–8 files/paths most likely to be modified for this task. Use explicit rules:
   - ALWAYS protect: `.specfarm/`, `rules.xml`, `.github/workflows/`
   - IF task touches `src/drift/`: add `src/drift/drift_engine.sh`
   - IF task touches `src/vibe/`: add `src/vibe/nudge_engine.sh`
   - IF task touches `src/regional/`: add `src/regional/enforcer.sh`
   - Print the list: echo "Protecting these files (read-only locks):"
   - Lock them per-worktree (non-blocking to other trees): git worktree lock ../specfarm-[inferred-name]
   - RATIONALE: git worktree lock prevents accidental edits in THIS tree without blocking parallel trees

6. If .specfarm/error-memory.md (or rules.xml) is in the protected list → start a background watch AND log setup:
   - Append to .specfarm/error-memory.md:
     ```
     [WKTREE-SETUP] inferred-name=$(date +%s) focus="[focus-or-pr-description]"
     ```
   - Start background watch:
     nohup tail -f .specfarm/error-memory.md > /tmp/wktree-watch-[inferred-name].log 2>&1 &
     echo $! > .specfarm/.wktree-watch-pid-[inferred-name]
     echo "Background watch started (PID logged to .specfarm/.wktree-watch-pid-[inferred-name])"

7. Print current status:
   git status
   pwd
   echo "Worktree [inferred-name] is active and ready. Locked per-tree (doesn't block other trees). Watching error-memory.md."

8. **CLEANUP/FINISH** (run when task is complete):
   - Kill background watch: if [ -f .specfarm/.wktree-watch-pid-[inferred-name] ]; then kill $(cat .specfarm/.wktree-watch-pid-[inferred-name]) 2>/dev/null; rm .specfarm/.wktree-watch-pid-[inferred-name]; fi
   - Unlock worktree: git worktree unlock ../specfarm-[inferred-name]
   - Remove worktree: git worktree remove ../specfarm-[inferred-name]
   - Append final log: echo "[WKTREE-CLEANUP] inferred-name=$(date +%s)" >> .specfarm/error-memory.md

9. Do NOT ask for confirmation unless something is ambiguous (missing PR number, branch conflict, repo root not found, etc.).
   If ambiguous → say exactly what's unclear, show diagnostic, and STOP (don't proceed until user clarifies).

Stay silent after setup unless I give a new command or ask a question.
```

---

## Cleanup Companion Commands

After completing your task, ask the agent:
- "finish [inferred-name]" — cleans up worktree, unlocks files, stops watch, logs completion
- Or manually: `git worktree remove ../specfarm-[inferred-name]`

### Quick copy-paste ready one-liner starters you can say to the agent

- autostart T0445 error-memory deduplication
- spawn tree for PR 42 fix windows regional enforcer
- work on T0448 velocity trend forecaster
- start work on plugin registry manifest

This version tells the agent to **do the thing** (create tree, cd, lock files, start watch) rather than just propose commands — which matches the "autostart the tree" behavior you're looking for.

If the agent still hesitates / only prints instead of running, add at the top:  
`You have full permission to run git and shell commands in this session. Execute, don't simulate.`
