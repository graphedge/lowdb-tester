Step-by-Step Guide: Testing SpecFarm's
  gather-rules agent on lowdb-tester

  This guide will walk you through setting up
  and running the gather-rules agent on your
  lowdb-tester repository to extract and score
  rules from its commit history and tests.

  Phase 1: Prepare Your Repository

  First, ensure your lowdb-tester repository
  meets the following criteria for optimal
  rule extraction:
   * Real, not a toy: Has 20–100+ commits and
     some recent feature work.
   * Has confidence scorer signal: Contains
     some tests, commit messages with keywords
     relevant to coding patterns, and ideally
     contributions from multiple authors.
   * Mid-sized: Approximately 10–80 source
     files.
   * Language-friendly: Python or Bash-heavy
     repositories are ideal, but others will
     also work.

  Phase 2: Minimal Bootstrap Setup (inside
  your lowdb-tester repo)

  Navigate to the root of your lowdb-tester
  repository. Then, execute the following
  commands to set up the agent:

   1 # 1. Grab the gather-rules agent and a
     starter rules.xml
   2 cp
     /storage/emulated/0/Download/github/specf
     arm2/.specfarm-agents/gather-rules-agent.
     sh .
   3 cp
     /storage/emulated/0/Download/github/specf
     arm2/.specfarm/rules.xml .
   4
   5 # 2. (Recommended) Create a dedicated
     directory for cleanliness and move the
     agent
   6 mkdir -p .specfarm-agents
   7 mv gather-rules-agent.sh
     .specfarm-agents/

  Phase 3: Run the First Real Test

  From the root of your lowdb-tester
  repository, execute the
  gather-rules-agent.sh script in full
   1 ./.specfarm-agents/gather-rules-agent.sh

  Expected Output:
   * A ranked list of rule candidates with
     confidence scores (30–100 scale).
   * Evidence pulled from your git log,
     linking back to real commits/tests.
   * Markdown output that you can immediately
     review.

  Success Criteria for this run:
   * You should see 5–10+ rules scored above
     70 that are relevant to your codebase.
   * The evidence provided should correctly
     link to real commits or tests within
     lowdb-tester.
   * The script should run without crashes,
     processing your lowdb-tester's git
     history successfully.

  Phase 4: Immediate Next Steps (Post-First
  Run)

  After a successful initial run:

   1. Curate Rules: Manually review the
      generated rules and select the top 6–8
      high-confidence rules that are most
      relevant. Integrate these into your
      local rules.xml file.
   2. Task-Context Mode (Optional): Experiment
      with the agent in task-context mode by
      providing a relevant task from your
      lowdb-tester project:

   1
     ./.specfarm-agents/gather-rules-agent.sh
     --task-context "Implement new data
     persistence mechanism"
      (Adjust the task context to something
  meaningful for lowdb-tester.)

  This process allows you to immediately
  validate specfarm's gather-rules agent on a
  real-world repository, highlighting areas
  for further refinement or customization of
  keyword lists and XPath rules if necessary.