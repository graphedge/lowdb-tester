#!/bin/bash
# tests/unit/test_plugin_registry.sh
#
# Test suite for Plugin Registry
# Task T0446: Validate manifest schema and sandbox constraints
#
# Tests that specfarm-plugin-validate correctly validates manifests
# and that sandbox constraints are enforced.

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

PASS=0
FAIL=0

_run_test() {
  local name="$1"
  local func="$2"
  local test_root
  test_root=$(mktemp -d)
  mkdir -p "$test_root/.specfarm/plugins"
  local saved_dir="$PWD"
  cd "$test_root" || { echo "FAIL: $name (cd failed)"; FAIL=$((FAIL+1)); return; }
  if (export SPECFARM_ROOT="$test_root"; "$func"); then
    echo "PASS: $name"
    PASS=$((PASS+1))
  else
    echo "FAIL: $name"
    FAIL=$((FAIL+1))
  fi
  cd "$saved_dir" || true
  rm -rf "$test_root"
}

# Helper: write a minimal valid plugin manifest to a temp dir
_write_valid_manifest() {
  local dir="$1"
  mkdir -p "$dir"
  touch "$dir/main.sh"
  cat > "$dir/plugin.json" <<'EOF'
{
  "id": "test-plugin",
  "name": "Test Plugin",
  "version": "1.0.0",
  "description": "A test plugin",
  "entrypoint": "main.sh",
  "permissions": {
    "filesystem": {
      "read": [".specfarm/rules.xml"],
      "write": [".specfarm/plugins/test-plugin/output.log"]
    },
    "network": false,
    "exec": ["git", "jq"]
  }
}
EOF
}

# ---- Test: valid manifest passes validation ----
t0446_valid_manifest_passes() {
  local plugin_dir
  plugin_dir="$(mktemp -d)"
  _write_valid_manifest "$plugin_dir"
  bash "$REPO_ROOT/bin/specfarm-plugin-validate" "$plugin_dir/plugin.json" >/dev/null 2>&1
  local rc=$?
  rm -rf "$plugin_dir"
  [[ $rc -eq 0 ]]
}

# ---- Test: missing required field fails validation ----
t0446_missing_field_fails() {
  local plugin_dir
  plugin_dir="$(mktemp -d)"
  touch "$plugin_dir/main.sh"
  cat > "$plugin_dir/plugin.json" <<'EOF'
{
  "name": "No ID Plugin",
  "version": "1.0.0",
  "entrypoint": "main.sh",
  "permissions": {"filesystem": {"read": [], "write": []}, "network": false, "exec": []}
}
EOF
  bash "$REPO_ROOT/bin/specfarm-plugin-validate" "$plugin_dir/plugin.json" >/dev/null 2>&1
  local rc=$?
  rm -rf "$plugin_dir"
  [[ $rc -ne 0 ]]
}

# ---- Test: invalid semver version fails ----
t0446_invalid_version_fails() {
  local plugin_dir
  plugin_dir="$(mktemp -d)"
  touch "$plugin_dir/main.sh"
  cat > "$plugin_dir/plugin.json" <<'EOF'
{
  "id": "my-plugin",
  "name": "My Plugin",
  "version": "v1.0",
  "entrypoint": "main.sh",
  "permissions": {"filesystem": {"read": [], "write": []}, "network": false, "exec": []}
}
EOF
  bash "$REPO_ROOT/bin/specfarm-plugin-validate" "$plugin_dir/plugin.json" >/dev/null 2>&1
  local rc=$?
  rm -rf "$plugin_dir"
  [[ $rc -ne 0 ]]
}

# ---- Test: invalid id format fails ----
t0446_invalid_id_fails() {
  local plugin_dir
  plugin_dir="$(mktemp -d)"
  touch "$plugin_dir/main.sh"
  cat > "$plugin_dir/plugin.json" <<'EOF'
{
  "id": "My_Plugin!",
  "name": "My Plugin",
  "version": "1.0.0",
  "entrypoint": "main.sh",
  "permissions": {"filesystem": {"read": [], "write": []}, "network": false, "exec": []}
}
EOF
  bash "$REPO_ROOT/bin/specfarm-plugin-validate" "$plugin_dir/plugin.json" >/dev/null 2>&1
  local rc=$?
  rm -rf "$plugin_dir"
  [[ $rc -ne 0 ]]
}

# ---- Test: write path outside allowed namespace fails (sandbox) ----
t0446_write_outside_namespace_fails() {
  local plugin_dir
  plugin_dir="$(mktemp -d)"
  touch "$plugin_dir/main.sh"
  cat > "$plugin_dir/plugin.json" <<'EOF'
{
  "id": "bad-plugin",
  "name": "Bad Plugin",
  "version": "1.0.0",
  "entrypoint": "main.sh",
  "permissions": {
    "filesystem": {
      "read": [],
      "write": ["src/important.sh"]
    },
    "network": false,
    "exec": []
  }
}
EOF
  bash "$REPO_ROOT/bin/specfarm-plugin-validate" "$plugin_dir/plugin.json" >/dev/null 2>&1
  local rc=$?
  rm -rf "$plugin_dir"
  [[ $rc -ne 0 ]]
}

# ---- Test: forbidden exec (curl) fails sandbox check ----
t0446_forbidden_exec_fails() {
  local plugin_dir
  plugin_dir="$(mktemp -d)"
  touch "$plugin_dir/main.sh"
  cat > "$plugin_dir/plugin.json" <<'EOF'
{
  "id": "net-plugin",
  "name": "Net Plugin",
  "version": "1.0.0",
  "entrypoint": "main.sh",
  "permissions": {
    "filesystem": {"read": [], "write": [".specfarm/plugins/net-plugin/"]},
    "network": false,
    "exec": ["curl"]
  }
}
EOF
  bash "$REPO_ROOT/bin/specfarm-plugin-validate" "$plugin_dir/plugin.json" >/dev/null 2>&1
  local rc=$?
  rm -rf "$plugin_dir"
  [[ $rc -ne 0 ]]
}

# ---- Test: missing entrypoint file fails ----
t0446_missing_entrypoint_fails() {
  local plugin_dir
  plugin_dir="$(mktemp -d)"
  # Do NOT create main.sh
  cat > "$plugin_dir/plugin.json" <<'EOF'
{
  "id": "ghost-plugin",
  "name": "Ghost Plugin",
  "version": "1.0.0",
  "entrypoint": "main.sh",
  "permissions": {"filesystem": {"read": [], "write": []}, "network": false, "exec": []}
}
EOF
  bash "$REPO_ROOT/bin/specfarm-plugin-validate" "$plugin_dir/plugin.json" >/dev/null 2>&1
  local rc=$?
  rm -rf "$plugin_dir"
  [[ $rc -ne 0 ]]
}

# ---- Test: write to .git/ is forbidden ----
t0446_write_to_git_forbidden() {
  local plugin_dir
  plugin_dir="$(mktemp -d)"
  touch "$plugin_dir/main.sh"
  cat > "$plugin_dir/plugin.json" <<'EOF'
{
  "id": "git-writer",
  "name": "Git Writer",
  "version": "1.0.0",
  "entrypoint": "main.sh",
  "permissions": {
    "filesystem": {"read": [], "write": [".git/hooks/pre-commit"]},
    "network": false,
    "exec": []
  }
}
EOF
  bash "$REPO_ROOT/bin/specfarm-plugin-validate" "$plugin_dir/plugin.json" >/dev/null 2>&1
  local rc=$?
  rm -rf "$plugin_dir"
  [[ $rc -ne 0 ]]
}

# ---- Test: tmp write path is allowed ----
t0446_tmp_write_allowed() {
  local plugin_dir
  plugin_dir="$(mktemp -d)"
  touch "$plugin_dir/main.sh"
  cat > "$plugin_dir/plugin.json" <<'EOF'
{
  "id": "tmp-plugin",
  "name": "Tmp Plugin",
  "version": "1.0.0",
  "entrypoint": "main.sh",
  "permissions": {
    "filesystem": {
      "read": [],
      "write": ["tmp/output.txt", ".specfarm/plugins/tmp-plugin/log.txt"]
    },
    "network": false,
    "exec": ["git"]
  }
}
EOF
  bash "$REPO_ROOT/bin/specfarm-plugin-validate" "$plugin_dir/plugin.json" >/dev/null 2>&1
  local rc=$?
  rm -rf "$plugin_dir"
  [[ $rc -eq 0 ]]
}

echo "=== Unit Tests: Plugin Registry (T0446) ==="
_run_test "T0446: valid manifest passes validation"          t0446_valid_manifest_passes
_run_test "T0446: missing required field fails"             t0446_missing_field_fails
_run_test "T0446: invalid semver version fails"             t0446_invalid_version_fails
_run_test "T0446: invalid id format fails"                  t0446_invalid_id_fails
_run_test "T0446: write outside namespace fails (sandbox)"  t0446_write_outside_namespace_fails
_run_test "T0446: forbidden exec (curl) fails sandbox"      t0446_forbidden_exec_fails
_run_test "T0446: missing entrypoint file fails"            t0446_missing_entrypoint_fails
_run_test "T0446: write to .git/ is forbidden"              t0446_write_to_git_forbidden
_run_test "T0446: write to tmp/ is allowed"                 t0446_tmp_write_allowed

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
