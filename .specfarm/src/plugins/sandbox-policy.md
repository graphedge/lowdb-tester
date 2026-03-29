# SpecFarm Plugin Sandbox Policy

**Version**: 1.0  
**Status**: Active — Phase 4  
**Source**: T0446 Plugin Registry

---

## Purpose

This document defines the sandbox constraints that govern all SpecFarm plugins. Plugins extend SpecFarm capabilities but must not introduce arbitrary code execution, data exfiltration, or uncontrolled side-effects.

---

## Guiding Principles

1. **Deny-by-default** — All permissions are denied unless explicitly declared in the plugin manifest.
2. **Least-privilege** — Plugins request only the permissions they need; reviewers reject over-broad requests.
3. **Auditability** — Every plugin invocation is logged to `.specfarm/audit/plugin-log.ndjson`.
4. **No auto-apply in CI** — Plugins that modify files must declare `write` permissions and may not be invoked automatically in CI without explicit user approval.
5. **Human-approval gate** — Plugins with `network: true` or any `write` path outside `.specfarm/plugins/<id>/` require explicit human sign-off before activation.

---

## Filesystem Permissions

### Read

- Plugins may request read access to specific glob patterns relative to the repo root.
- Commonly allowed: `.specfarm/rules.xml`, `.specfarm/drift-history/**`, `src/**/*.sh`.
- **Forbidden read paths**: `.git/`, `.specfarm/justifications.log`, `.env*`, secrets files.

### Write

- Write access is restricted to the plugin's own namespace: `.specfarm/plugins/<plugin-id>/`.
- Plugins may also write to `tmp/` or `/tmp/`.
- **Write access outside the plugin namespace is FORBIDDEN** unless a human reviewer explicitly approves and documents the exception in this policy file.

---

## Network

- Network access is **disabled** by default (`network: false`).
- Plugins that need network access must set `"network": true` in their manifest.
- Network-enabled plugins are subject to additional review and must document their endpoints.
- **CI environments block all plugin network calls** regardless of manifest declarations.

---

## Executable Allowlist

- Plugins declare an explicit list of executables they may invoke (e.g. `["git", "jq", "python3"]`).
- Wildcards are not permitted.
- Executables not on the allowlist are blocked by the registry validator.
- **Forbidden executables**: `curl`, `wget`, `nc`, `ncat`, `ssh`, `scp`, `ftp`, `python3 -c` (inline exec), `eval`, `bash -c <dynamic>` sourced from external input.

---

## Lifecycle Hooks

| Hook | Triggered by | Risk Level | Notes |
|------|-------------|------------|-------|
| `pre-drift` | Before drift scan | Low | Read-only hooks only |
| `post-drift` | After drift scan completes | Medium | May write to plugin namespace |
| `pre-commit` | Before git commit | High | Subject to extra review |
| `post-commit` | After git commit | Medium | Audit log required |
| `on-heal` | After SelfHealingExecutor action | High | Dry-run enforced in CI |
| `on-nudge` | When nudge message is generated | Low | Output-only |

---

## Validation Requirements

All plugins must pass `bin/specfarm-plugin-validate` before they can be activated. The validator checks:

1. Manifest exists at `<plugin-dir>/plugin.json`
2. Manifest conforms to `src/plugins/manifest-schema.json`
3. `id` field matches the directory name
4. `entrypoint` file exists and is executable
5. `write` paths are confined to allowed directories
6. `exec` list contains no forbidden executables
7. Version field is valid semver

---

## Activation Flow

```
1. Developer creates plugin directory: .specfarm/plugins/<id>/
2. Writes plugin.json manifest
3. Runs: bin/specfarm-plugin-validate .specfarm/plugins/<id>/plugin.json
4. If PASS: plugin is registered in .specfarm/plugins/registry.json
5. If network:true or broad write: requires human review & approval comment in registry.json
6. Plugin hooks are invoked only when explicitly listed in registry.json "active_plugins"
```

---

## Violation Handling

- Manifest validation failures → plugin NOT activated; error written to `.specfarm/audit/plugin-log.ndjson`
- Runtime permission violations → plugin invocation aborted; error logged
- Repeated violations → plugin automatically deactivated; human review required for re-activation
