#!/bin/bash
# Integration test for auto-rule generation in SpecFarm
set -euo pipefail

# Setup
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT
cd "$TEST_DIR"

# Mock bins
mkdir -p bin
cp /storage/emulated/0/Download/github/specfarm/bin/log-shell-error bin/
cp /storage/emulated/0/Download/github/specfarm/bin/process-shell-errors bin/
chmod +x bin/*

# 1. Test threshold: exactly 2 occurrences should trigger a rule
echo "Test 1: Rule generation threshold (2 occurrences)..."
mkdir -p .specfarm
cat <<EOF > .specfarm/rules.xml
<specfarm-rules version="1.0">
</specfarm-rules>
EOF

# Log two similar errors
python3 bin/log-shell-error --command "curl http://unstable-service.com/api" --exit-code 7 --stderr "Failed to connect" > /dev/null
python3 bin/log-shell-error --command "curl http://unstable-service.com/api" --exit-code 7 --stderr "Failed to connect again" > /dev/null

# Process errors
python3 bin/process-shell-errors > /dev/null

# Check if rule was added
if grep -q "shell-error-avoid-" .specfarm/rules.xml; then
    echo "PASS: Rule generated after 2 occurrences"
else
    echo "FAIL: Rule NOT generated after 2 occurrences"
    exit 1
fi

# 2. Test threshold: 1 occurrence should NOT trigger a rule
echo "Test 2: Rule generation threshold (1 occurrence)..."
# Clear log and reset rules
cat <<EOF > .specfarm/rules.xml
<specfarm-rules version="1.0">
</specfarm-rules>
EOF
> .specfarm/shell-errors.log

python3 bin/log-shell-error --command "unique-failing-command" --exit-code 1 --stderr "Kaboom" > /dev/null
python3 bin/process-shell-errors > /dev/null

if grep -q "shell-error-avoid-" .specfarm/rules.xml; then
    echo "FAIL: Rule generated for single occurrence"
    exit 1
else
    echo "PASS: No rule for single occurrence"
fi

# 3. Test similar but not identical (path normalization)
echo "Test 3: Path normalization in rules..."
cat <<EOF > .specfarm/rules.xml
<specfarm-rules version="1.0">
</specfarm-rules>
EOF
> .specfarm/shell-errors.log

python3 bin/log-shell-error --command "/usr/bin/python3 /tmp/script_a.py" --exit-code 1 --stderr "Error in script" > /dev/null
python3 bin/log-shell-error --command "/usr/bin/python3 /tmp/script_b.py" --exit-code 1 --stderr "Error in script" > /dev/null

# Both should normalize to "/*bin/python3 /*script_*.py" or something similar depending on the normalize_command function
# The current normalize_command is: re.sub(r'/[a-zA-Z0-9\._\-/]+', '/*', command)

python3 bin/process-shell-errors > /dev/null

if grep -q "shell-error-avoid-" .specfarm/rules.xml; then
    echo "PASS: Rule generated for similar commands after normalization"
else
    echo "FAIL: Rule NOT generated for similar commands"
    # Debug: show normalization
    # cat .specfarm/shell-errors.log.bak
    exit 1
fi

# 4. Test custom threshold
echo "Test 4: Custom threshold (3 occurrences)..."
cat <<EOF > .specfarm/rules.xml
<specfarm-rules version="1.0">
</specfarm-rules>
EOF
> .specfarm/shell-errors.log

python3 bin/log-shell-error --command "triplicate-command" --exit-code 1 > /dev/null
python3 bin/log-shell-error --command "triplicate-command" --exit-code 1 > /dev/null
python3 bin/log-shell-error --command "triplicate-command" --exit-code 1 > /dev/null

# threshold 4 -> should NOT generate
python3 bin/process-shell-errors --threshold 4 > /dev/null

if grep -q "shell-error-avoid-" .specfarm/rules.xml; then
    echo "FAIL: Rule generated before reaching threshold 4"
    exit 1
else
    echo "PASS: No rule generated with 3 occurrences and threshold 4"
fi

# But wait, the previous run cleared the log. Let's log again.
python3 bin/log-shell-error --command "triplicate-command" --exit-code 1 > /dev/null
python3 bin/log-shell-error --command "triplicate-command" --exit-code 1 > /dev/null
python3 bin/log-shell-error --command "triplicate-command" --exit-code 1 > /dev/null

# threshold 3 -> should generate
python3 bin/process-shell-errors --threshold 3 > /dev/null

if grep -q "shell-error-avoid-" .specfarm/rules.xml; then
    echo "PASS: Rule generated after reaching threshold 3"
else
    echo "FAIL: Rule NOT generated after 3 occurrences with threshold 3"
    exit 1
fi

echo "All auto-rule generation tests PASSED"
