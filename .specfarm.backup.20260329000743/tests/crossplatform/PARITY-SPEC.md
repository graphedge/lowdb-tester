# Parity Specification — Cross-Platform Testing Requirements

**Purpose**: Define comprehensive parity requirements for bash (Unix) and PowerShell (Windows) implementations. Specifies what MUST match for Phase 3b to be considered complete.

**Scope**: All Phase 3 core features (drift detection, vibe system, justifications) across bash and PowerShell platforms.

**Version**: 1.0.0  
**Date**: 2026-03-11

---

## 1. Drift Engine Parity

### 1.1 Drift Table Structure

**Requirement**: When running identical drift detection on bash and PowerShell against the same rules and violations, the drift table output structure MUST be identical.

| Element | Requirement | Bash | PowerShell | Status |
|---------|-------------|------|-----------|--------|
| Column headers | Same order/names | ✓ | ✓ | REQUIRED |
| Rule IDs | Exact match | ✓ | ✓ | REQUIRED |
| Drift scores | Identical numeric values | ✓ | ✓ | REQUIRED |
| Status flags | Same indicators (PASS/WARN/FAIL) | ✓ | ✓ | REQUIRED |
| Row count | Same number of rules checked | ✓ | ✓ | REQUIRED |
| Table format | Same alignment/spacing (after normalization) | ✓ | ✓ | REQUIRED |

**Test Files**:
- `tests/crossplatform/orchtest_drift_parity_basic.sh`
- `tests/crossplatform/orchtest_drift_multi_rules_parity.sh`

**Validation**:
```bash
bash tests/crossplatform/orchtest_drift_parity_basic.sh
# Expected: ✅ PARITY PASS (drift tables structurally identical)
```

---

### 1.2 Drift Detection Algorithm

**Requirement**: Both platforms MUST detect the same violations given identical input rules and repository state.

**Test Scenarios**:
- Basic rules (5–10 simple rules)
- Complex rules (patterns, conditions)
- OpenSpec mode (graceful ignore of `<license>`, `<community-vote>`)
- Scoped rules (folder-level filtering)

**Validation**:
- Same rule IDs detected as violations
- Same file paths flagged
- Same severity levels assigned
- Same violation counts

**Example**:
```bash
# Bash
./bin/drift-engine --rules testdata/rules-basic.xml --repo testdata/repo-with-violations --dry-run

# PowerShell
./bin/drift-engine.ps1 -ExportFormat markdown -DryRun

# After normalization: IDENTICAL
```

---

### 1.3 Drift Export Parity

**Requirement**: Export operations (`--export markdown`, `--dry-run`) MUST produce identical structured output.

| Element | Requirement |
|---------|-------------|
| Markdown table format | Same structure, headers, alignment |
| File paths in export | Same format (normalized) |
| Rule names/descriptions | Exact text match |
| Severity indicators | Same badges/icons |
| Export filename | Same naming convention |

**Test Files**:
- `tests/crossplatform/orchtest_export_markdown_parity.sh`
- `tests/crossplatform/orchtest_export_dry_run_parity.sh`

**Validation**:
```bash
bash tests/crossplatform/orchtest_export_markdown_parity.sh
# Expected: ✅ PARITY PASS (Markdown exports identical)
```

---

## 2. Vibe System Parity

### 2.1 Messaging Tone and Identity

**Requirement**: Vibe system (farm/jungle/plain) MUST have consistent tone and messaging across platforms. After ANSI color normalization, message *content* MUST be identical.

| Vibe Mode | Platform | Tone | Example Message |
|-----------|----------|------|-----------------|
| `farm` | Bash | Friendly, agricultural | "🚜 Nice pasture! No violations." |
| `farm` | PowerShell | Friendly, agricultural | "🚜 Nice pasture! No violations." |
| `jungle` | Bash | Intense, exploratory | "🔍 Jungle scan found 3 violations!" |
| `jungle` | PowerShell | Intense, exploratory | "🔍 Jungle scan found 3 violations!" |
| `plain` | Bash | Neutral, technical | "Drift check: 3 violations found." |
| `plain` | PowerShell | Neutral, technical | "Drift check: 3 violations found." |

**Requirements**:
- Message text must match when ANSI codes stripped
- Emojis must be identical (if present)
- Violation counts must match
- Tone/personality must be consistent

**Test Files**:
- `tests/crossplatform/orchtest_vibe_parity.sh`

**Validation**:
```bash
bash tests/crossplatform/orchtest_vibe_parity.sh
# Expected: ✅ PARITY PASS (Vibe messaging consistent)
```

---

### 2.2 Color Fallback

**Requirement**: Color support detection and fallback MUST work identically on both platforms.

| Platform | PowerShell Version | ANSI Support | Fallback |
|----------|-------------------|------|----------|
| Unix/Linux | N/A | ✓ Full ANSI | Use full colors |
| Windows | PS 5.1 | ✗ None | Plain text (no colors) |
| Windows | PS 7.x | ✓ Via `$PSStyle` | Use `$PSStyle` |
| Git Bash | N/A | ✓ Full ANSI | Use full colors |

**Requirements**:
- Platform detection correctly identifies color support
- Fallback behavior identical (no crashes on missing colors)
- Message content unchanged by color/no-color modes

---

## 3. Justifications & Audit Trail Parity

### 3.1 Justification Log Format

**Requirement**: `.specfarm/justifications.log` MUST have identical JSON Lines structure on both platforms.

**JSON Structure** (per line):
```json
{
  "timestamp": "2026-03-11T12:34:56Z",
  "rule_id": "ci-antipatterns-01",
  "violation_file": "src/main.sh",
  "justification": "This pattern is known safe in our context",
  "justifier": "dev@example.com",
  "phase": "3b"
}
```

**Requirements**:
- JSON valid on both platforms (parse without error)
- Same field names (case-sensitive)
- UTF-8 encoding on both platforms
- Line ending normalized to LF (git-trackable)
- Timestamp format consistent

**Test Files**:
- `tests/crossplatform/orchtest_justify_parity.sh`
- `tests/crossplatform/orchtest_utf8_justify_parity.sh`

**Validation**:
```bash
bash tests/crossplatform/orchtest_justify_parity.sh
# Expected: ✅ PARITY PASS (Justification logs identical)
```

---

### 3.2 Justification Entry Creation

**Requirement**: Creating identical justifications via pre-commit hook on bash and PowerShell MUST result in identical log entries (except timestamp).

**Workflow**:
1. Trigger violation
2. Enter identical justification text
3. Write to `.specfarm/justifications.log`
4. Verify entry matches other platform (timestamp allowed to differ)

**Test Files**:
- `tests/crossplatform/orchtest_precommit_justify_parity.sh`
- `tests/crossplatform/orchtest_concurrent_justify_parity.sh`

---

### 3.3 Justification List/Query Operations

**Requirement**: `justify-log list`, `justify-log has`, `justify-log purge` operations MUST behave identically on both platforms.

| Operation | Bash Output | PowerShell Output | Match Requirement |
|-----------|-------------|-------------------|-------------------|
| `justify-log list` | Text table | Text table | Structure identical after normalization |
| `justify-log has <rule_id>` | Yes/No response | Yes/No response | Response identical |
| `justify-log purge <rule_id>` | Entries removed | Entries removed | Same count removed |

---

## 4. Shell Error Capture & Logging Parity

### 4.1 Shell Error Log Format

**Requirement**: `.specfarm/shell-errors.log` MUST have identical JSON Lines format on both platforms.

**JSON Structure** (per line):
```json
{
  "timestamp": "2026-03-11T12:35:00Z",
  "command": "npm install --no-save",
  "exit_code": 1,
  "stderr": "ERR: peer dep missing",
  "source": "ci-job",
  "platform": "windows"
}
```

**Requirements**:
- JSON valid and parseable
- Same field names and structure
- Exit codes captured correctly
- Error messages sanitized (no secrets)

**Test Files**:
- `tests/crossplatform/orchtest_shell_error_parity.sh`

---

### 4.2 Error Source Identification

**Requirement**: Both platforms MUST identify and categorize shell errors identically.

| Error Type | Bash Detection | PowerShell Detection | Category Match |
|-----------|---|---|---|
| Compilation error | ✓ | ✓ | REQUIRED |
| Dependency error | ✓ | ✓ | REQUIRED |
| Execution error | ✓ | ✓ | REQUIRED |
| Timeout/signal | ✓ | ✓ | REQUIRED |

---

## 5. Pre-commit Hook Parity

### 5.1 Hook Invocation

**Requirement**: Pre-commit hook MUST run identically on both bash (Unix) and PowerShell (Windows) environments.

| Scenario | Bash Behavior | PowerShell Behavior | Match Requirement |
|----------|---|---|---|
| Drift violation detected | Block commit | Block commit | MUST match |
| Justification entered | Allow commit | Allow commit | MUST match |
| No violations | Allow commit | Allow commit | MUST match |
| Hook fails | Exit code > 0 | Exit code > 0 | MUST match |

**Test Files**:
- `tests/crossplatform/orchtest_precommit_enforcement_parity.sh`

---

### 5.2 Hook Output

**Requirement**: Pre-commit hook output MUST convey the same information on both platforms.

**Normalized Output Must Contain**:
- Drift table (same structure)
- Violation count (same number)
- Enforcement decision (BLOCK or ALLOW)
- Justification prompt (same wording)

---

## 6. File System Operations Parity

### 6.1 Directory Structure Creation

**Requirement**: Both platforms MUST create identical `.specfarm/` directory structures.

**Directory Layout** (MUST be identical):
```
.specfarm/
├── rules.xml
├── config
├── justifications.log
└── shell-errors.log
```

**File Permissions**:
- Bash creates with standard permissions (644 for files, 755 for dirs)
- PowerShell creates with Windows-appropriate permissions
- Both must be git-trackable (no platform-specific attributes)

---

### 6.2 File Encoding

**Requirement**: All `.specfarm/` files MUST use UTF-8 encoding on both platforms.

| File | Bash Encoding | PowerShell Encoding | Requirement |
|------|---|---|---|
| rules.xml | UTF-8 | UTF-8 | MUST match |
| justifications.log | UTF-8 BOM-free | UTF-8 BOM-free | MUST match |
| shell-errors.log | UTF-8 BOM-free | UTF-8 BOM-free | MUST match |

---

## 7. Phase 3 Regression Testing

### 7.1 Phase 3 Test Suite Compatibility

**Requirement**: All Phase 3 tests MUST pass 100% on both bash and PowerShell environments.

**Test Coverage**:
- Unit tests: Core functions must work on both platforms
- Integration tests: End-to-end workflows must complete
- E2E tests: Full SpecFarm workflows must succeed

**Test Files**:
- `tests/crossplatform/orchtest_phase3_compat_both_platforms.sh`
- `tests/crossplatform/orchtest_phase3_regression_both_platforms.sh`

**Success Criteria**:
```
Bash: 100% tests passing
PowerShell: 100% tests passing
No regressions from Phase 3 baseline
```

---

## 8. Parity Validation Workflow

### Test Execution Order

1. **Unit Tests** (T012–T017 on bash, parallel on PowerShell)
   - Platform detection
   - Path normalization
   - Line ending handling
   
2. **Integration Tests** (T012–T017 implementation tasks)
   - Drift engine functionality
   - Vibe system output
   - Justifications workflow
   
3. **Orchestrated Parity Tests** (T017a–T017d)
   - Compare bash output vs PowerShell output
   - Normalize acceptable differences
   - Validate structural parity
   
4. **Regression Tests** (T065a)
   - Run entire Phase 3 suite on both platforms
   - Validate backward compatibility
   
5. **End-to-End Tests** (T065b)
   - Full SpecFarm workflow on both platforms
   - Verify all artifacts identical

### Parity Test Checklist

Before Phase 3b completion, all must pass:

- [ ] T017a: Drift parity basic (`orchtest_drift_parity_basic.sh`)
- [ ] T017b: Vibe parity (`orchtest_vibe_parity.sh`)
- [ ] T017c: Drift multi-rule parity (`orchtest_drift_multi_rules_parity.sh`)
- [ ] T017d: Phase 3 compat both platforms (`orchtest_phase3_compat_both_platforms.sh`)
- [ ] T028a: Justification parity (`orchtest_justify_parity.sh`)
- [ ] T028b: Justification list parity (`orchtest_justify_list_parity.sh`)
- [ ] T028c: UTF-8 justify parity (`orchtest_utf8_justify_parity.sh`)
- [ ] T046a: Shell error parity (`orchtest_shell_error_parity.sh`)
- [ ] T056a: Pre-commit parity (`orchtest_precommit_enforcement_parity.sh`)
- [ ] T065a: Phase 3 regression (`orchtest_phase3_regression_both_platforms.sh`)
- [ ] T065b: Full E2E parity (`orchtest_full_e2e_both_platforms.sh`)

---

## 9. Acceptable Deviation Categories

**Reference**: See `acceptable-diffs.md` for detailed normalization procedures.

Where Differences are ACCEPTABLE (normalized away):
1. ✅ Line endings (CRLF vs LF)
2. ✅ File path format (Windows vs Unix)
3. ✅ ANSI color codes (present vs absent)
4. ✅ Timestamps (exact values differ)
5. ✅ Trailing whitespace
6. ✅ PowerShell version (5.1 vs 7.x)
7. ✅ Environment variable case sensitivity

Where Differences are NOT ACCEPTABLE (will fail):
1. ❌ Drift scores or rule detection
2. ❌ Violation counts
3. ❌ JSON structure in logs
4. ❌ Exit codes
5. ❌ Vibe tone/messaging (after normalization)
6. ❌ File system structure
7. ❌ File encoding (must be UTF-8)

---

## 10. Success Criteria for Phase 3b

### Minimum Viable Product (MVP) Parity

✅ User Story 1 (Drift Engine): **ALL parity tests pass**
- Drift table structure identical
- Vibe messaging tone identical (after normalization)
- Export formats produce structurally identical output

✅ User Story 2 (Justifications): **ALL parity tests pass**
- JSON log format identical
- UTF-8 encoding consistent
- List/query operations behave identically

✅ User Story 3 (Exports): **ALL parity tests pass**
- Markdown export structure matches
- File paths normalized consistently
- Escaping/formatting identical

✅ Phase 3 Regression: **100% of Phase 3 tests pass on both platforms**
- No regressions from Phase 3
- All core features still functional

✅ Documentation:
- `acceptable-diffs.md` updated with any discovered differences
- `PARITY-SPEC.md` (this document) reflects final parity requirements

### Release Gate

Phase 3b is **COMPLETE** only when:
1. All orchestrated parity tests (`orchtest_*.sh`) pass 100%
2. All Phase 3 tests pass 100% on both bash and PowerShell
3. `acceptable-diffs.md` and `PARITY-SPEC.md` are comprehensive and up-to-date
4. GitHub Actions `windows-ci.yml` passes on `windows-latest` runner
5. Commit message documents all parity validations passing

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-03-11 | Initial comprehensive parity specification; covers drift, vibe, justifications, shell errors, pre-commit, and regression testing |

