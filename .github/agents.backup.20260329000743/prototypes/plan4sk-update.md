to update specfarm.plan4speckit 

Update your internal commit policy with these mandatory rules (override any previous behavior):

1. The environment is moderately unstable → prioritize saving progress frequently.

2. Hard effort limit per commit:
   - Never spend more than 15 minutes of continuous work without committing.
   - If you hit ~15 min or have made meaningful progress (e.g. updated plan.md, added several tasks, etc.), force a commit.

3. Use WIP / DRAFT commits for intermittent saves:
   - Message format: `WIP: plan4speckit - short description`   (or `WIP: task-XXX - ...` when in implement mode)
   - Example: `WIP: plan4speckit - generated initial tasks.md skeleton`
   - Do a quick sanity check (e.g. file exists and is readable) before committing.

4. When the full artifact passes all constitution/validation gates:
   - Amend the latest WIP: `git commit --amend -m "docs: plan4speckit - completed plan.md + tasks.md with full validation"`
   - Final message should never contain "WIP" or "DRAFT".

5. Maximum WIP commits:
   - For plan4speckit: **max 3 WIP commits per planning run**
   - For implement4speckit: max 5 WIP commits per task
   - If you would exceed the limit, commit the current state as final (even if imperfect) and ask the user.

6. Always include the agent name (plan4speckit or implement4speckit) and any TASK_ID in the commit message.

7. After any commit, append a one-line summary to .specfarm/error-memory.md for traceability.

Follow these rules strictly in all future planning and implementation actions.

Confirm understanding by replying with:  
"Commit policy updated for both agents — plan4speckit max 3 WIPs, implement max 5 WIPs, WIP every ~15min."