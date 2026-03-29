#!/bin/bash
# Integration test for SpecFarm full auto-rule -> enforcement cycle
set -euo pipefail

# Setup
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
cd "$TEST_DIR"

# Mock bins and src
mkdir -p bin .specfarm
cp -r /storage/emulated/0/Download/github/specfarm/src .
cp /storage/emulated/0/Download/github/specfarm/bin/specfarm bin/
cp /storage/emulated/0/Download/github/specfarm/bin/drift-engine bin/
cp /storage/emulated/0/Download/github/specfarm/bin/process-shell-errors bin/
cp /storage/emulated/0/Download/github/specfarm/bin/log-shell-error bin/
chmod +x bin/*

# Initialize SpecFarm environment
bash bin/specfarm onboard
cat <<EOF > .specfarm/rules.xml
<specfarm-rules version="1.0">
  <rule id="rule-to-justify-1" global="true">
    <description>Rule for justification audit test</description>
    <signature type="keyword">JUSTIFY_ME</signature>
  </rule>
  <rule id="another-rule" global="true">
    <description>Another rule</description>
    <signature type="keyword">OTHER_KEYWORD</signature>
  </rule>
</specfarm-rules>
EOF
> .specfarm/justifications.log # Ensure justifications log is clean

# --- Test Scenario: Auto-rule generation and then enforcement ---

# 1. Inject 3 failing commands to trigger rule generation (threshold is 2 by default)
echo "Test 1: Injecting failing commands to trigger rule generation..."
python3 bin/log-shell-error --command "flaky-command-A --arg1" --exit-code 1 --stderr "Error A occurred" > /dev/null
python3 bin/log-shell-error --command "flaky-command-A --arg1" --exit-code 1 --stderr "Error A failed again" > /dev/null
python3 bin/log-shell-error --command "flaky-command-B --arg2" --exit-code 1 --stderr "Error B" > /dev/null

# Process logs to generate rules
python3 bin/process-shell-errors > /dev/null

# Verify that rules were added to rules.xml
if ! grep -q "shell-error-avoid-" .specfarm/rules.xml; then
    echo "FAIL: No rules generated after injecting 2 flaky-command-A errors."
    exit 1
fi
echo "PASS: Rule for 'flaky-command-A' generated."

# Check content of the generated rule
RULE_ID=$(grep "shell-error-avoid-" .specfarm/rules.xml | sed -n 's/.*id="\([^"]*\)".*/\1/p')
echo "Generated Rule ID: $RULE_ID"

# 2. Simulate adding a rule manually to ensure it's enforced
echo "Test 2: Adding a rule manually and checking enforcement..."

# Add a rule to rules.xml that mimics the generated one, but with 'enforced-from="2.0"'
# This ensures it would be picked up by drift engine
# We use the generated rule's signature pattern to make it detectable
echo "Verifying rules.xml content after auto-generation:"
cat .specfarm/rules.xml
echo "---"

GENERATED_RULE_LINE=$(grep 'id="shell-error-avoid-[^"]*"' .specfarm/rules.xml)
echo "Generated rule line: $GENERATED_RULE_LINE"
GENERATED_PATTERN=$(echo "$GENERATED_RULE_LINE" | sed -n "s/.*<signature[^>]*>\([^<]*\)<\/signature>.*/\1/p")
echo "Extracted GENERATED_PATTERN: $GENERATED_PATTERN"

if [[ -z "$GENERATED_PATTERN" ]]; then
    echo "FAIL: GENERATED_PATTERN is empty after extraction."
    exit 1
fi


# Insert the rule before the closing </specfarm-rules> tag
NEW_RULE="  <rule id=\"manual-enforced-rule-1\" enforced-from=\"2.0\">\n    <description>Manually added rule for enforcement test.</description>\n    <signature type=\"regex\">${GENERATED_PATTERN}</signature>\n  </rule>"

# Temporarily store the content of rules.xml excluding the closing tag
head -n -1 .specfarm/rules.xml > .specfarm/rules.xml.tmp

# Append the new rule
echo -e "$NEW_RULE" >> .specfarm/rules.xml.tmp

# Append the closing tag
echo "</specfarm-rules>" >> .specfarm/rules.xml.tmp

# Replace the original rules.xml with the modified content
mv .specfarm/rules.xml.tmp .specfarm/rules.xml

# Now run drift check. It should detect the rule and enforce it if the pattern matches.
# We need to simulate a file that would match the pattern
echo "Simulating a match for the enforced rule pattern..."
# The pattern is likely something like /*/*command --arg1, based on normalize_command
# Let's create a file that would trigger this pattern
mkdir -p some_dir
echo "This is a file that might trigger the pattern: flaky-command-A --arg1" > some_dir/trigger_file.txt

# Run drift check. It should detect the rule and show it as "PASS" or "JUSTIFIED"
# We expect adherence to increase because of the manually added rule.
OUTPUT=$(bash bin/specfarm drift --export text)

# Check if the manual rule is detected as DRIFT (matched but not justified)
if echo "$OUTPUT" | grep -A 3 "manual-enforced-rule-1" | grep -q "DRIFT"; then
    echo "PASS: Manual rule 'manual-enforced-rule-1' detected as DRIFT (unjustified match)."
else
    echo "FAIL: Manual rule 'manual-enforced-rule-1' not detected as DRIFT."
    echo "Output: $OUTPUT"
    exit 1
fi

# Now justify the manual rule
echo "Justifying manual-enforced-rule-1..."
bash bin/specfarm justify manual-enforced-rule-1 "Manually enforced rule for testing."

# Run drift again. It should now show as JUSTIFIED.
OUTPUT=$(bash bin/specfarm drift --export text)

if echo "$OUTPUT" | grep -A 3 "manual-enforced-rule-1" | grep -q "JUSTIFIED"; then
    echo "PASS: Manual rule 'manual-enforced-rule-1' correctly shows as JUSTIFIED."
else
    echo "FAIL: Manual rule 'manual-enforced-rule-1' does not show as JUSTIFIED after justification."
    echo "Output: $OUTPUT"
    exit 1
fi

# 3. Test --dry-run after rule addition
echo "Test 3: --dry-run flag..."
# --dry-run doesn't really do anything in drift currently, as it's already a report.
# But we can ensure it doesn't crash.
OUTPUT=$(bash bin/specfarm drift --dry-run --export text)
if echo "$OUTPUT" | grep -q "TOTAL ADHERENCE:"; then
    echo "PASS: --dry-run did not break drift output."
else
    echo "FAIL: --dry-run broke drift output."
    echo "Output: $OUTPUT"
    exit 1
fi

# 4. Test conflicting rules and justifications
echo "Test 4: Conflicting rules and justifications..."

# Add a rule that conflicts with standard-rule-1 by having the same signature but different ID/description.
# This tests how the drift engine handles multiple rules matching the same pattern.
# The current drift engine counts matches per rule. If multiple rules match, all should show PASS/JUSTIFIED.
# We'll test if justifications are applied correctly to distinct rules.

# Ensure standard-rule-1 is present and justified from previous steps
# (Onboard might not create it, so explicitly adding it for robustness)
# Insert the new rule for standard-rule-1
NEW_RULE_STANDARD="  <rule id=\"standard-rule-1\" global=\"true\" certainty=\"0.9\">\n    <description>This is a standard rule.</description>\n    <signature type=\"keyword\">STANDARD_KEYWORD</signature>\n  </rule>"
head -n -1 .specfarm/rules.xml > .specfarm/rules.xml.tmp
echo -e "$NEW_RULE_STANDARD" >> .specfarm/rules.xml.tmp
echo "</specfarm-rules>" >> .specfarm/rules.xml.tmp
mv .specfarm/rules.xml.tmp .specfarm/rules.xml

# Justify standard-rule-1
echo "Justifying standard-rule-1..."
bash bin/specfarm justify standard-rule-1 "Temporarily allowed for testing conflicts."

# Add a second rule with the same signature but different ID.
NEW_RULE_CONFLICTING="  <rule id=\"conflicting-signature-rule\" global=\"true\" certainty=\"0.8\">\n    <description>A rule with a conflicting signature.</description>\n    <signature type=\"keyword\">STANDARD_KEYWORD</signature>\n  </rule>"
head -n -1 .specfarm/rules.xml > .specfarm/rules.xml.tmp
echo -e "$NEW_RULE_CONFLICTING" >> .specfarm/rules.xml.tmp
echo "</specfarm-rules>" >> .specfarm/rules.xml.tmp
mv .specfarm/rules.xml.tmp .specfarm/rules.xml

# Create a file that matches STANDARD_KEYWORD
echo "This file contains STANDARD_KEYWORD." > src/standard_match_conflict.sh
chmod +x src/standard_match_conflict.sh

# Run drift. Standard-rule-1 should be JUSTIFIED (from previous step).
# The new rule 'conflicting-signature-rule' should show as PASS (matched, not justified).
OUTPUT=$(bash bin/specfarm drift --export text)

if echo "$OUTPUT" | grep -A 5 "standard-rule-1" | grep -q "JUSTIFIED"; then
    echo "PASS: Standard rule 'standard-rule-1' shows as JUSTIFIED."
else
    echo "FAIL: Standard rule 'standard-rule-1' did not show JUSTIFIED."
    echo "Output: $OUTPUT"
    exit 1
fi

if echo "$OUTPUT" | grep -A 5 "conflicting-signature-rule" | grep -q "DRIFT"; then
    echo "PASS: Conflicting rule 'conflicting-signature-rule' detected as DRIFT (unjustified match)."
else
    echo "FAIL: Conflicting rule 'conflicting-signature-rule' not detected as DRIFT."
    echo "Output: $OUTPUT"
    exit 1
fi

echo "All full auto-rule -> enforcement tests PASSED"
