#!/bin/bash
# tests/crossplatform/testdata/repo-clean/setup.sh
# Clean shell script that follows best practices
# - Uses #!/bin/bash
# - No hardcoded platform-specific paths
# - Uses $HOME and relative paths

set -euo pipefail

SPECFARM_DIR="${SPECFARM_DIR:-.specfarm}"
LOG_FILE="$SPECFARM_DIR/specfarm.log"

echo "Logging to $LOG_FILE"
