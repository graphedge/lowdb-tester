#!/bin/bash
# tests/crossplatform/testdata/repo-with-violations/setup.sh
# Minimal shell script that violates test-prefer-bash (uses /bin/sh)
# and contains a hardcoded Termux path (violates test-no-termux-hardcoded-paths)

#!/bin/sh
TERMUX_HOME="/storage/emulated/0/termux-setup"
LOG="$TERMUX_HOME/specfarm.log"
echo "Logging to $LOG"
