# bin/specfarm-plugin-validate.ps1 — Plugin manifest validator (PowerShell wrapper)
# Task T0446: Windows parity wrapper for bash validator
# Delegates to bash implementation (bin/specfarm-plugin-validate) for feature parity
# Constitution Amendment: PowerShell Entrypoint Allowance (Section I)
#
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File bin/specfarm-plugin-validate.ps1 <path/to/plugin.json>
# Exit 0 → PASS; Exit 1 → FAIL

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Determine script directory and repo root
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$BASE_DIR = Split-Path -Parent $SCRIPT_DIR
$BASH_VALIDATOR = Join-Path $SCRIPT_DIR "specfarm-plugin-validate"

# Parse arguments
if ($args.Count -eq 0) {
    Write-Error "Usage: specfarm-plugin-validate.ps1 <path/to/plugin.json>" -ErrorAction Stop
}

$MANIFEST_PATH = $args[0]

# Validate bash validator exists
if (-not (Test-Path $BASH_VALIDATOR)) {
    Write-Error "ERROR: bash validator not found at $BASH_VALIDATOR" -ErrorAction Stop
}

# Detect bash availability
$bash_cmd = if (Get-Command bash -ErrorAction SilentlyContinue) { "bash" } elseif (Get-Command wsl -ErrorAction SilentlyContinue) { "wsl" } else { $null }

if ($null -eq $bash_cmd) {
    Write-Error "ERROR: bash not found in PATH (neither 'bash' nor 'wsl' available)" -ErrorAction Stop
}

# Invoke bash validator with error handling
try {
    if ($bash_cmd -eq "bash") {
        # Direct bash invocation
        & bash $BASH_VALIDATOR $MANIFEST_PATH
        $exit_code = $LASTEXITCODE
    } else {
        # WSL fallback for Windows
        $wsl_validator = "bash " + ($BASH_VALIDATOR -replace '\\', '/') -replace '(.*):', '/mnt/$1'
        $wsl_manifest = $MANIFEST_PATH -replace '\\', '/' -replace '(.*):', '/mnt/$1'
        & wsl $wsl_validator $wsl_manifest
        $exit_code = $LASTEXITCODE
    }
    
    exit $exit_code
} catch {
    Write-Error "ERROR: validator execution failed: $_" -ErrorAction Stop
}
