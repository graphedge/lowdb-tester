# Git Worktree Agent (wktree.md)

## Command Syntax

**Primary Command** (Copilot CLI):
```
wktree [subject]              # Normal execution with assessment
wktree --help                 # Show agent info (no creation)
wktree --examples             # Show usage examples (no creation)
wktree --validate             # Validate worktree config (no creation)
```

Examples:
- `wktree T0445 error-memory deduplication`
- `wktree PR 42 windows ci fix`
- `wktree velocity trend forecaster`
- `wktree fix-regional-enforcer`

**Alternative Triggers**:
- `work on [subject]`
- `autostart [subject]`
- `spawn tree for [subject]`

---

## Step 0: Pre-Decision Gate (Task Assessment)

**BEFORE asking "Ready to proceed?"**, agent must evaluate if worktree is needed:

```
ASSESS TASK SCOPE:
├─ Task type: (feature / bugfix / refactor / docs / Q&A / planning)
├─ Estimated duration: (quick <30min / medium 30min-2hrs / long >2hrs)
├─ Files to modify: (single / few / many / unknown)
├─ Change risk: (low / medium / high)
│
└─ DECISION: Worktree needed?
   ├─ YES (feature/bugfix/refactor with files > 3, high risk)
   ├─ MAYBE (docs, planning, exploratory — create temp if user confirms)
   └─ NO (reference, Q&A, info, scaffolding — skip worktree)
```

**If DECISION = NO** (reference/advisory mode):
```
ℹ️  This task doesn't require a worktree. Proceeding in-place (main checkout).
   If you need isolation later, ask: "start wktree for [subject]"
```
→ Skip to advisory/reference output, DO NOT proceed to activation.

**If DECISION = YES or MAYBE**:
→ Proceed to Activation & Permission Confirmation below.

---

## ✓ Activation & Permission Confirmation

**REQUIRED BEFORE EXECUTION**: When worktree is recommended (from Step 0), you MUST perform this sequence:

1. **Echo confirmation with execution context** (proof of detection):
   ```
   ✓ WKTREE AGENT ACTIVATED
   Focus: [extracted focus description]
   Worktree name: [kebab-case-name]
   Path: ../specfarm-[kebab-case-name]
   Branch: feature/[kebab-case-name] (or pr-[number])
   
   Scope: [feature / bugfix / refactor / docs]
   Duration estimate: [quick / medium / long]
   Isolation level: [full / per-tree / temporary]
   
   This will:
   - Create ../specfarm-[kebab-case-name]
   - Lock: [manifest-protected dirs list or "TBD after manifest load"]
   - Watch: .specfarm/error-memory.md
   - Auto-cleanup: [yes (QUICK mode) / no (persistent)]
   ```

2. **Request explicit user permission with enhanced options** (blocking wait):
   ```
   Ready to proceed? (options):
   
   1. YES — Create persistent worktree (default for long-lived features)
   2. QUICK — Temporary worktree (auto-cleanup on session exit)
   3. PLAN FIRST — Skip worktree; analyze scope and ask again later
   4. NO — Cancel, work in-place on main checkout
   
   Enter choice (1-4 or YES/QUICK/PLAN/NO):
   ```

3. **User response determines behavior**:
   - `1` or `YES` → Create persistent worktree, proceed to implementation steps
   - `2` or `QUICK` → Create temporary worktree with auto-cleanup flag, proceed
   - `3` or `PLAN` → Skip creation, provide analysis/planning output only
   - `4` or `NO` → Abort gracefully with "Worktree creation cancelled."
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

4. cd into the new worktree directory (../specfarm-[inferred-name]) and verify directory-manifest.json exists:
   - If manifest missing, warn: "WARNING: .specify/onboarding/directory-manifest.json not found. Run intake agent first to generate classifications."
   - If manifest found, load it and display version

4b. **CRITICAL: Verify we're working in the worktree** (Initial + Continuous validation):
   ```bash
   # Store worktree path in session variable for continuous checks
   export WKTREE_NAME="[inferred-name]"
   export WKTREE_PATH=$(pwd)
   
   _verify_in_worktree() {
     local expected_worktree="$1"
     local actual_path=$(pwd)
     local worktree_root=$(git worktree list --porcelain | grep "$expected_worktree" | awk '{print $1}')
     
     if [[ "$actual_path" != "$worktree_root" ]]; then
       echo "⚠️  WARNING: You are NOT in the worktree!"
       echo "   Expected: $worktree_root"
       echo "   Actual:   $actual_path"
       echo "   This command will run in the WRONG location."
       echo ""
       echo "   Worktree status:"
       git worktree list
       echo ""
       echo "   FIX: cd $worktree_root"
       return 1
     fi
     
     # Verify git-dir is worktree
     if ! git rev-parse --git-dir | grep -q "worktrees"; then
       echo "❌ ERROR: Current directory is NOT a git worktree!"
       echo "   Run: git worktree list"
       return 1
     fi
     
     echo "✓ Verified: Working in worktree at $actual_path"
     echo "[WKTREE-LOCATION-CHECK] $(date -u +%Y-%m-%dT%H:%M:%SZ) – Verified in worktree $expected_worktree at $actual_path" >> .specfarm/error-memory.md
     return 0
   }
   
   # Initial verification
   _verify_in_worktree "$WKTREE_NAME" || exit 1
   
   # Create helper alias for continuous checks
   alias verify='_verify_in_worktree "$WKTREE_NAME"'
   
   # Gate for git operations (prevents accidental main checkout commits)
   _gate_git_operation() {
     if [[ $(pwd) == */specfarm && ! $(git rev-parse --git-dir) =~ worktrees ]]; then
       echo "❌ BLOCKED: You're in main checkout, not a worktree."
       echo "   Use: cd \$WKTREE_PATH"
       return 1
     fi
     _verify_in_worktree "$WKTREE_NAME" || return 1
   }
   ```
   - **Usage**: Run `_gate_git_operation` before any `git commit` or `git push`
   - **Continuous checks**: After any `cd` command or directory change, re-verify location
   - Abort if check fails (do NOT proceed with task if we're in wrong directory)

5. Load Directory Manifest & Determine Protected Paths:
   - Load `.specify/onboarding/directory-manifest.json` (authoritative source for directory classifications)
   - For the inferred task, determine which directories will be modified using focus keywords
   - Query manifest to classify each directory:
     ```
     PROTECTED (from manifest): dirs with classification = production-canonical OR write_access = never/ci-only
     UNLOCKED (from manifest): dirs with classification = production-active/experiments-trial OR write_access = human-only
     ```
   - ALWAYS include in protected list:
     - All production-canonical classified dirs from manifest
     - `.specfarm/`, `rules.xml`, `.github/workflows/` (core governance)
     - Task-specific protected modules (check manifest for src/drift/, src/vibe/, src/regional/ classifications)
   - Print protection plan with manifest metadata:
     ```
     Manifest-Protected Files (per directory-manifest.json v{version}):
     - {path}: {classification} (owner: {owner}, confidence: {confidence})
     ```
   - Lock them per-worktree: git worktree lock ../specfarm-[inferred-name]
   - RATIONALE: Manifest-driven locking aligns with intake agent governance and enables consistent, automated protection across all worktrees

6. If .specfarm/error-memory.md (or rules.xml) is in the protected list → start a background watch AND log setup:
   - Append to .specfarm/error-memory.md:
     ```
     [WKTREE-SETUP] inferred-name=$(date +%s) focus="[focus-or-pr-description]"
     ```
   - Start background watch:
     nohup tail -f .specfarm/error-memory.md > /tmp/wktree-watch-[inferred-name].log 2>&1 &
     echo $! > .specfarm/.wktree-watch-pid-[inferred-name]
     echo "Background watch started (PID logged to .specfarm/.wktree-watch-pid-[inferred-name])"

7. **Print current status with cleanup reminder**:
   ```
   git status
   pwd
   echo "Worktree [$WKTREE_NAME] is active and ready."
   echo "Locked per-tree (doesn't block other trees). Watching error-memory.md."
   echo ""
   echo "═══════════════════════════════════════════════════════════════════════"
   echo "CLEANUP REMINDER: When finished, run ONE of:"
   echo "  • finish [$WKTREE_NAME]                              (cleanup + remove)"
   echo "  • git worktree remove ../specfarm-[$WKTREE_NAME]     (manual cleanup)"
   echo "═══════════════════════════════════════════════════════════════════════"
   ```
   
   - Log cleanup reminder to `.specfarm/error-memory.md`:
     ```
     [WKTREE-REMINDER] $(date -u +%Y-%m-%dT%H:%M:%SZ) – Created worktree [$WKTREE_NAME].
     Reminder: Run "finish [$WKTREE_NAME]" when complete to clean up locks & watches.
     ```

8. **CONTINUOUS VALIDATION (During Session)**:
   - Before ANY `git commit`: Run `_gate_git_operation` to verify location
   - Before ANY `git push`: Run `_gate_git_operation` (absolute gate)
   - After ANY `cd` command: Re-run `verify` to check location
   - If user leaves worktree mid-task:
     ```
     ⚠️  You have left worktree [$WKTREE_NAME]. 
        Currently working in: $(pwd)
        To return: cd $WKTREE_PATH
     ```

9. **CLEANUP/FINISH** (run when task is complete):
   - Kill background watch: if [ -f .specfarm/.wktree-watch-pid-[$WKTREE_NAME] ]; then kill $(cat .specfarm/.wktree-watch-pid-[$WKTREE_NAME]) 2>/dev/null; rm .specfarm/.wktree-watch-pid-[$WKTREE_NAME]; fi
   - Unlock worktree: git worktree unlock ../specfarm-[$WKTREE_NAME]
   - Remove worktree: git worktree remove ../specfarm-[$WKTREE_NAME]
   - Append final log: echo "[WKTREE-CLEANUP] $(date -u +%Y-%m-%dT%H:%M:%SZ) – Removed worktree [$WKTREE_NAME]" >> .specfarm/error-memory.md
   - Unset session vars: unset WKTREE_NAME WKTREE_PATH
   - Remove aliases: unalias verify 2>/dev/null

10. Do NOT ask for confirmation unless something is ambiguous (missing PR number, branch conflict, repo root not found, etc.).
   If ambiguous → say exactly what's unclear, show diagnostic, and STOP (don't proceed until user clarifies).

Stay silent after setup unless I give a new command or ask a question.
```

---

## Test Scenarios

**Scenario 1: Advisory Mode (No Worktree Needed)**
```
User: "wktree --help for historylast development"
Agent: Shows reference documentation, NO confirmation asked
Result: PASS (advisory mode, no creation)
```

**Scenario 2: Feature Branch (Persistent Worktree)**
```
User: "start work on T0445 error-memory optimization"
Agent: 
  Step 0: Assesses → feature, many files, high risk → DECISION: YES
  Step 1: Shows activation echo with context
  Step 2: Asks: "1-YES / 2-QUICK / 3-PLAN / 4-NO?"
  User: "1" or "YES"
  Agent: Creates persistent worktree → cleanup reminder → continuous validation
Result: PASS (long-lived, full safeguards)
```

**Scenario 3: Quick Fix (Temporary Worktree)**
```
User: "autostart PR 42 windows ci fix"
Agent:
  Step 0: Assesses → bugfix, few files, low risk → DECISION: MAYBE
  Step 2: Asks: "1-YES / 2-QUICK / 3-PLAN / 4-NO?"
  User: "2" or "QUICK"
  Agent: Creates temp worktree with auto-cleanup flag
Result: PASS (ephemeral, session-scoped)
```

**Scenario 4: Planning Phase (No Worktree Yet)**
```
User: "help me plan T0450 spec generation enhancement"
Agent:
  Step 0: Assesses → planning, scope unknown → DECISION: NO
  Agent: "ℹ️ This task doesn't require a worktree. Analyzing scope..."
  Agent: Provides planning output, suggests: "start wktree for T0450" when ready
Result: PASS (deferred creation)
```

**Scenario 5: Location Validation During Session**
```
User: Creates worktree, starts work, then accidentally: cd ../specfarm
Agent: Detects location change → "⚠️ You have left worktree [name]"
User: Attempts: git commit -m "fix"
Agent: Runs _gate_git_operation → BLOCKS commit → "Use: cd $WKTREE_PATH"
Result: PASS (prevented wrong-location commit)
```

---

## Cleanup Companion Commands

After completing your task, ask the agent:
- **"finish [inferred-name]"** — Full cleanup: stops watch, unlocks files, removes worktree, logs completion
- Or manually: `git worktree remove ../specfarm-[inferred-name]` (then clean up watch PID manually)

### Quick copy-paste ready one-liner starters you can say to the agent

- `autostart T0445 error-memory deduplication`
- `spawn tree for PR 42 fix windows regional enforcer`
- `work on T0448 velocity trend forecaster`
- `start work on plugin registry manifest`

This version tells the agent to **do the thing** (create tree, cd, lock files, start watch) rather than just propose commands — which matches the "autostart the tree" behavior you're looking for.

If the agent still hesitates / only prints instead of running, add at the top:  
`You have full permission to run git and shell commands in this session. Execute, don't simulate.`
