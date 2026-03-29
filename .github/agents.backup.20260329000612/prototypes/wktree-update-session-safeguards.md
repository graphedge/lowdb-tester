# Wktree Agent Update: Session Safeguards & Pre-Creation Validation

**Context**: During historylast development session, wktree agent was referenced but not invoked to create a worktree. User worked in main repo (phase-3B) directly. This revealed gaps in wktree agent behavior when:
1. User mentions wktree but doesn't explicitly request creation
2. Agent is consulted for reference without permission flow
3. No active worktree needed for advisory/Q&A collaboration

---

## Gap Analysis

### Current Behavior (wktree.agent.md)
- ✅ Clear activation confirmation
- ✅ Permission workflow (yes/no)
- ✅ Worktree creation steps
- ✅ Manifest-driven locking
- ✅ Error detection (worktree location validation)

### Missing Safeguards
1. **Pre-decision validation** — No check whether worktree is needed BEFORE asking permission
   - When should wktree NOT be created? (e.g., small advisory task, Q&A session)
   - When SHOULD worktree be created? (e.g., multi-file refactor, long-lived feature branch)

2. **Advisory vs. Execution mode** — No distinction between:
   - `"Tell me about wktree workflow"` (reference-only, no creation)
   - `"Start work on T0445"` (execution-mode, needs creation)
   - `"Help me plan T0445"` (planning-mode, maybe ephemeral worktree?)

3. **Session context awareness** — Agent doesn't know:
   - Is user already in a main worktree? (don't nest)
   - How long will this task take? (impact on worktree cost)
   - Are changes experimental or production? (protect locked dirs accordingly)

4. **Confirmation messaging** — Current yes/no is binary; missing nuance:
   - `"yes"` → create persistent worktree (long-lived feature)
   - `"start lightweight"` → temporary worktree for quick fixes
   - `"plan first"` → don't create; analyze scope, then ask later

5. **Cleanup reminder** — No proactive reminder that worktree must be cleaned:
   - User forgets to `finish [name]`
   - Orphaned worktrees pile up
   - Lock files remain, blocking future work

---

## Recommended Updates

### 1. Add Pre-Decision Gate (Step 0)

**BEFORE asking "Ready to proceed?"**, agent should evaluate:

```
ASSESS TASK SCOPE:
├─ Task type: (feature / bugfix / refactor / docs / Q&A / planning)
├─ Estimated duration: (quick <30min / medium 30min-2hrs / long >2hrs)
├─ Files to modify: (single / few / many / unknown)
├─ Change risk: (low / medium / high)
│
└─ DECISION: Worktree needed?
   ├─ YES (feature/bugfix/refactor with files > 3)
   ├─ MAYBE (Q&A, planning, docs — create temp if user confirms)
   └─ NO (reference, info, scaffolding — skip worktree)
```

If DECISION = NO:
```
ℹ️  This task doesn't require a worktree. Proceeding in-place (main checkout).
   If you need isolation later, ask: "start wktree for [subject]"
```

If DECISION = YES:
```
✓ WKTREE AGENT ACTIVATED
  [existing confirmation flow]
```

### 2. Enhanced Permission Options

Instead of binary yes/no:

```
Ready to proceed? (options):

1. YES — Create persistent worktree (default for long-lived features)
2. QUICK — Temporary worktree (expires after session, auto-cleanup)
3. PLAN FIRST — Skip worktree; analyze scope and ask again later
4. NO — Cancel, work in-place on main checkout
```

### 3. Add Execution Context

Enhance activation echo to include:

```
✓ WKTREE AGENT ACTIVATED
Focus: [extracted focus]
Worktree name: [kebab-case-name]
Scope: [feature / bugfix / refactor / docs]
Duration estimate: [quick / medium / long]
Isolation level: [full / per-tree / temporary]

This will:
- Create ../specfarm-[name]
- Lock: [manifest-protected dirs list]
- Watch: .specfarm/error-memory.md
- Auto-cleanup: [yes/no/on-exit]
```

### 4. Cleanup Proactive Messaging

After worktree creation, always print:

```
═══════════════════════════════════════════════════════════════════════
When finished, run ONE of:
  • finish [inferred-name]              (cleanup + remove worktree)
  • git worktree remove ../specfarm-[inferred-name]  (manual cleanup)
═══════════════════════════════════════════════════════════════════════
```

And log cleanup reminder to `.specfarm/error-memory.md`:
```
[WKTREE-REMINDER] {timestamp} – User created worktree [name].
Reminder: Run "finish [name]" when complete to clean up locks & watches.
```

### 5. Advisory Mode Flag

Add optional flag to enable reference-only invocation:

```
wktree --help           # Show agent info (no creation)
wktree --examples       # Show usage examples (no creation)
wktree --validate       # Validate worktree config (no creation)
wktree [subject]        # Normal execution flow (with confirmation)
```

### 6. **CRITICAL: Continuous Location Validation During Session**

Current behavior: One-time validation at step 4b (after creation), then NO ongoing protection.

**New requirement**: Agent must guard against accidental work in wrong location:

```bash
# At session start + after each agent command, validate:

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
  return 0
}

# Usage: After any major operation or before git push/commit
_verify_in_worktree "$WKTREE_NAME" || exit 1
```

**Integration Points**:
- After `git add` / before `git commit` — validate we're in correct tree
- After any `cd` or directory change — re-verify location
- Before `git push` — absolute gate (never push from wrong tree)
- Log each validation to `.specfarm/error-memory.md`:
  ```
  [WKTREE-LOCATION-CHECK] {timestamp} – Verified in worktree {name} at {path}
  ```

**User Safeguards**:
- Store worktree path in session var: `WKTREE_PATH=$(pwd)`
- Provide shell alias/function: `verify` → runs location check
- Prevent accidental git commands in main checkout:
  ```bash
  if [[ $(pwd) == */specfarm && ! -d .git/worktrees/* ]]; then
    echo "❌ BLOCKED: You're in main checkout, not a worktree."
    echo "   Use: cd \$WKTREE_PATH"
    return 1
  fi
  ```

**Edge Case**: User `cd`s back to main checkout mid-task
```
User runs: cd ../specfarm
Agent detects: Left worktree
Agent warns: "You have left worktree [name]. Currently working in: main checkout"
Agent prevents: git commit / git push (blocks until back in worktree)
```

---

## Test Scenarios for Updated Agent

**Scenario 1: Q&A Session (No Worktree Needed)**
```
User: "wktree --help for historylast development"
Agent: Shows reference, no confirmation asked
Result: PASS (advisory mode)
```

**Scenario 2: Feature Branch (Persistent Worktree)**
```
User: "start work on T0445 error-memory optimization"
Agent: 
  - Assesses: feature, many files, high risk
  - Asks: "YES / QUICK / PLAN / NO?"
  - User: "YES"
  - Creates: persistent worktree with cleanup reminder
Result: PASS (long-lived)
```

**Scenario 3: Quick Fix (Temporary Worktree)**
```
User: "autostart PR 42 windows ci fix"
Agent:
  - Assesses: bugfix, few files, low risk
  - Asks: "YES / QUICK / PLAN / NO?"
  - User: "QUICK"
  - Creates: temp worktree, auto-cleanup on exit
Result: PASS (ephemeral)
```

**Scenario 4: Planning (No Worktree Yet)**
```
User: "help me plan T0450 spec generation enhancement"
Agent:
  - Assesses: planning phase, scope unknown
  - Decision: NO (planning, not implementation)
  - Message: "Analyzing scope... ask again when ready to implement"
Result: PASS (deferred)
```

---

## Files to Update

1. **`.github/agents/wktree.agent.md`** — Add:
   - Step 0: Pre-decision gate (task assessment)
   - Enhanced permission options (YES / QUICK / PLAN / NO)
   - Advisory mode flags (--help, --examples, --validate)
   - Cleanup proactive messaging
   - Execution context in activation echo

2. **`.github/agents/prototypes/wktree-implementation-checklist.md`** (NEW) — Document:
   - Pre-decision logic flowchart
   - Session safeguards checklist
   - Test scenarios (4 minimum)
   - Integration with error-memory tracking

3. **`.github/agents/prototypes/wktree-update-history.md`** (NEW) — Track:
   - Session 2026-03-23: historylast dev → revealed gap (no pre-decision gate)
   - Decision: Add advisory mode + scope assessment
   - Status: Pending implementation

---

## Priority

**HIGH** — Without pre-decision gate, agent creates unnecessary worktrees, leading to:
- Orphaned locks (.specfarm/.wktree-watch-pid-*)
- Accumulated background processes
- Confusing permission prompts for reference-only queries
- Session overhead (user worked 2hrs in main repo when worktree might have been cleaner)

**Recommendation**: Update wktree.agent.md before next feature implementation session.

