#!/bin/bash
# src/crossplatform/platform-check.sh — OS detection and PowerShell availability check
# Phase 3b T005: Cross-platform abstraction layer
# Usage: source this file, then call detect_platform, get_ps_version, check_bash_available

# ------------------------------------------------------------------
# Platform Detection
# Returns: linux | macos | windows | unknown
# ------------------------------------------------------------------
detect_platform() {
    local os_type
    os_type="$(uname -s 2>/dev/null || echo "unknown")"

    case "$os_type" in
        Linux*)
            # Check for WSL (Windows Subsystem for Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "windows-wsl"
            else
                echo "linux"
            fi
            ;;
        Darwin*)
            echo "macos"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            echo "windows-mingw"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# ------------------------------------------------------------------
# PowerShell Version Detection
# Returns: "none" if not found, or "5.1", "7.x" etc.
# ------------------------------------------------------------------
get_ps_version() {
    local ps_cmd=""

    # Check for PowerShell Core (pwsh) first (cross-platform v7+)
    if command -v pwsh >/dev/null 2>&1; then
        ps_cmd="pwsh"
    # Then check for legacy PowerShell 5.1 (Windows only)
    elif command -v powershell >/dev/null 2>&1; then
        ps_cmd="powershell"
    fi

    if [[ -z "$ps_cmd" ]]; then
        echo "none"
        return 0
    fi

    # Extract major.minor version
    local version
    version=$("$ps_cmd" -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()' 2>/dev/null | tr -d '\r')
    if [[ -n "$version" ]]; then
        echo "$version"
    else
        echo "unknown"
    fi
}

# ------------------------------------------------------------------
# Bash Availability Check
# Returns: "available" or "unavailable"
# ------------------------------------------------------------------
check_bash_available() {
    if command -v bash >/dev/null 2>&1; then
        echo "available"
    else
        echo "unavailable"
    fi
}

# ------------------------------------------------------------------
# Full Platform Report (structured for use in logs)
# Outputs key=value pairs for easy sourcing
# ------------------------------------------------------------------
platform_report() {
    local platform
    local ps_version
    local bash_status
    platform="$(detect_platform)"
    ps_version="$(get_ps_version)"
    bash_status="$(check_bash_available)"

    echo "PLATFORM=${platform}"
    echo "POWERSHELL_VERSION=${ps_version}"
    echo "BASH_STATUS=${bash_status}"
    echo "UNAME=$(uname -s 2>/dev/null || echo unknown)"
    echo "ARCH=$(uname -m 2>/dev/null || echo unknown)"
}

# ------------------------------------------------------------------
# Graceful Fallback: warn and continue on unsupported OS
# Call at entry points; does not exit — allows graceful degradation
# ------------------------------------------------------------------
assert_supported_platform() {
    local platform
    platform="$(detect_platform)"

    case "$platform" in
        linux|macos|windows-wsl|windows-mingw)
            return 0
            ;;
        unknown|*)
            echo "⚠️  Warning: Unsupported platform '${platform}'. SpecFarm may not behave correctly." >&2
            echo "   Supported: linux, macos, windows (WSL/MinGW). Proceeding with best-effort defaults." >&2
            return 0  # Do not exit — graceful degradation
            ;;
    esac
}

# ------------------------------------------------------------------
# Self-test (run when executed directly, not when sourced)
# ------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "=== SpecFarm Platform Check ==="
    platform_report
    assert_supported_platform
fi
