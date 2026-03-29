=== specfarm.gather-rules.agent.md ===

--- archive/2026-03-19-pr14-improvements/specfarm.gather-rules.agent.md-BEFORE.md	2026-03-19 09:20:41.156679703 -0400
+++ specfarm.gather-rules.agent.md	2026-03-19 09:21:45.224679734 -0400
@@ -1,5 +1,5 @@
 ---
-description: Gather rules from recent commits using GitHub Actions context (automated rules discovery for policy enforcement).
+description: Gather rules from recent commits using GitHub Actions context (automated rules discovery for policy enforcement). Enhanced Post-PR14 with confidence scoring and test pattern analysis.
 model: claude-haiku-4.5
 handoffs: 
   - platform: claude
@@ -16,13 +16,18 @@
 
 ## Purpose
 
-This agent automatically discovers and extracts rule candidates from recent commits in a SpecFarm repository. It runs within GitHub Actions workflows to provide continuous rules intelligence.
+This agent automatically discovers and extracts rule candidates from recent commits in a SpecFarm repository. Enhanced Post-PR14 with confidence scoring and test anti-pattern detection.
 
 **When to use:**
 - PR checks: Scan changes vs base branch to suggest new rules
 - Scheduled: Weekly audit of repository patterns
 - Manual dispatch: On-demand rules gathering with custom parameters
 
+**New capabilities (Post-PR14):**
+- **Confidence scoring**: High/Medium/Low based on commit frequency, author diversity, test coverage
+- **Test pattern analysis**: Detects bash arithmetic bugs, exit code issues, test harness quality
+- **Rule evidence tracking**: Links rules to specific commits, authors, test coverage
+
 ## GitHub Context
 
 The agent operates within GitHub Actions with access to:
@@ -366,11 +371,69 @@
 
 ## Related Files
 
-- **Core Agent**: `.specfarm-agents/gather-rules-agent.sh` — Universal agent (no changes needed)
+- **Core Agent**: `.specfarm-agents/gather-rules-agent.sh` — Universal agent (enhanced Post-PR14)
 - **Caller Script**: `.specfarm-agents/gather-rules-agent-caller.sh` — Router (environment detection)
 - **Workflow**: `.github/workflows/gather-rules.yml` — GitHub Actions trigger
 - **Documentation**: `.specfarm-agents/RULES-GATHERING-AGENT.md` — Full reference
 
+## Enhanced Features (Post-PR14)
+
+### 1. Rule Confidence Scoring
+
+When extracting rules from commits, assign confidence scores:
+
+**High Confidence (≥90%)**:
+- Rule appears in 5+ commits by different authors
+- Explicitly documented in commit messages
+- Covered by tests
+- Referenced in constitution
+
+**Medium Confidence (70-89%)**:
+- Rule appears in 2-4 commits
+- Implicit pattern (not explicitly stated)
+- Some test coverage
+
+**Low Confidence (<70%)**:
+- Single occurrence
+- No documentation
+- No test coverage
+
+**Output Format**:
+```xml
+<rule id="r123" confidence="92">
+  <pattern>Must use xmllint for XML validation</pattern>
+  <evidence commits="5" authors="3"/>
+  <test-coverage>tests/unit/test_xml_validation.sh</test-coverage>
+  <constitution-ref>Principle III.B</constitution-ref>
+</rule>
+```
+
+### 2. Test Pattern Analysis (Anti-Pattern Detection)
+
+While gathering rules, also detect test infrastructure issues:
+
+```bash
+# Scan for bash arithmetic bugs
+HARNESS_BUGS=$(grep -rn '&& *\\((' tests/ | grep -v '|| true' | wc -l)
+
+if [[ $HARNESS_BUGS -gt 0 ]]; then
+  echo "## Test Infrastructure Issues Detected" >> gathered-rules.md
+  echo "" >> gathered-rules.md
+  echo "Found $HARNESS_BUGS potential bash arithmetic bugs:" >> gathered-rules.md
+  grep -rn '&& *\\((' tests/ | grep -v '|| true' | head -10 >> gathered-rules.md
+  echo "" >> gathered-rules.md
+  echo "**Suggested Rule**: Add r999 - Bash test harness must use || true guards" >> gathered-rules.md
+  echo "**Reference**: PR #14 (failed 0%) / PR #15 (fixed)" >> gathered-rules.md
+fi
+
+# Check for exit code validation
+if ! grep -rq 'exit.*passed.*failed' tests/; then
+  echo "**Suggested Rule**: Add r1000 - Test exit codes must match summary" >> gathered-rules.md
+fi
+```
+
+**Output**: Automatically suggest governance rules for test quality
+
 ## Integration with Constitution
 
 This agent supports SpecFarm's **constitution-driven development**:

Lines added/removed:
69
