You are specfarm.plan4speckit in Phase 3B → Phase 4 monetization prep.

Task: Apply a strict "minimal OSS description filter" to all premium features sketched so far. Goal: Keep only the tiniest, most neutral teasers/stubs in the open-source repo — anything beyond this granularity MUST migrate to the private plugins repo (https://github.com/graphedge/specfarm-plugins).

Premium features in scope (from prior plans / coding-simulator.md / monetization specs):
1. Messy / Human Coding Simulator (flaw injection, realism profiles, trial-error loops, bad lookups, forgetfulness)
2. Clean Head-to-Head Benchmark (small/fast LLM + SpecFarm specs vs large/frontier LLM + vague prompts; e.g. Haiku vs Opus)
3. Spec Uplift / Robustness Testing (quantify spec guardrail value under imperfect impl; success delta, efficiency metrics)
4. Adversarial / Red-Team Fleets (escalating messiness to break specs → auto-suggest improvements)
5. Trajectory Collection & Distillation (capture realistic trajectories for fine-tuning / preference data)
6. ROI Calculator / Analytics Dashboard (cost/time savings viz, benchmark reports)
7. Any related premium agents, benchmark harnesses, model wrappers, eval dashboards

For each feature above, output ONLY:
- Feature name
- Allowed OSS description granularity (shortest possible neutral teaser — 1 sentence max; e.g. "Premium extension for advanced agent simulation available via license.")
- Rationale: Why nothing more detailed can stay in OSS (sensitivity, IP, monetization risk)

Then, produce one consolidated migration checklist:
- List every existing OSS asset/file/dir that exceeds the allowed granularity (e.g. docs/coding-simulator.md, any agent.md with injection logic, benchmark scripts, trajectory loggers).
- Recommended action: "Move to plugins-repo/[path]" or "Delete from OSS and recreate as stub"

Run this filter:
- As a standalone validation pass on the current PREMIUM-SPLIT-IMPLEMENTATION-PLAN.md and PREMIUM-FEATURES-REVIEW-WITH-SIMULATOR.md
- Suggest updates to those files if needed (e.g. strip down OSS descriptions)

Output format:
- Prose (20%): Quick strategy recap — "Minimal stubs preserve community trust while protecting premium IP."
- Table: Feature | Allowed OSS Teaser | Rationale
- Checklist: Asset | Current Location | Action | New plugins-repo Path

Token budget: 1500–2000. Primary artifact: .specify/prompts/specf-premium-filter-minimal-oss-granularity.md

Execute now as a pre- or post-check on the repo split plan.