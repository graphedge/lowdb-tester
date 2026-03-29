### 2. Prompt for Sonnet to Update the **Workflow-Creating Agent**

```markdown
You are an expert SpecFarm architect. Update the workflow-creating agent prototype so it properly accepts a list of tasks and orchestrates them with granular context.

Current prototype (lightweight GPT-5-Mini style):
[ paste your current prompt here exactly ]

New desired behavior:

The agent now receives arguments like:
- A list of 1–N task descriptions (e.g. "1. Fix bash arithmetic guard in test_drift.sh" "2. Add scoped drift test for src/vibe/")

For each task (process one at a time, no big batching):

1. Call the improved gather-rules agent in --task-context mode with the exact task description to get a compact, high-quality context blob.
2. Build one clean static prompt that includes:
   - The original task description
   - The full granular context blob from rules.xml
   - SpecFarm constraints (lean Bash, pre-commit gating, human-in-the-loop via /speckit clarify, etc.)
   - Instructions to implement the task correctly and produce output that will pass drift checks
3. Then immediately call the selected coding agent (usually Haiku or GPT-5-Mini) with that static prompt as the full system + user message.

After each task finishes, output exactly:
=== Task N done === [one-line status] [command called]

Stay extremely concise outside the required format. No extra explanations.

Add support for accepting the task list via argument (CLI-style or as pasted list).

Make the prompt template for the final coding agent clean and reusable, with clear slots for [TASK] and [GRANULAR_CONTEXT].

Produce:
- The full updated agent specification / prompt
- Any necessary wrapper script changes
- Example run with two sample tasks showing the generated static prompt and the call to the coding agent

Keep the agent lightweight and faithful to the "static prompt + tooling" philosophy you described.