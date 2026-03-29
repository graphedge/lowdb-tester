#!/bin/bash
# src/regional/enforcer.sh — RegionalEnforcer: Command adaptation per OS/shell/agent
# Task T0441: Adapts commands based on regional rules (OS, shell, agent context)
#
# Usage: source this file, then call adapt_command
# Contract: POST /regional/adapt-command (see 03-contract-api-specs.md)

# Adapt a command for the given agent/OS/shell context
# Args: command, agent_id, os_family, shell, [timeout]
# Returns: JSON with adapted_command + strategy metadata
adapt_command() {
    local command="${1:-}"
    local agent_id="${2:-generic}"
    local os_family="${3:-linux}"
    local shell="${4:-bash}"
    local timeout="${5:-30}"

    # Validate input
    if [[ -z "$command" ]]; then
        echo '{"error":"EMPTY_COMMAND","message":"Command cannot be empty"}'
        return 1
    fi

    local adapted_command="$command"
    local strategy_prefix=""
    local strip_ansi="false"
    local redirect_stderr="false"
    local output_capture=""
    local fallback="default"

    # Apply agent-specific strategies
    case "$agent_id" in
        Cline|cline)
            # Cline has known terminal capture issues
            case "$shell" in
                zsh)
                    strategy_prefix="script -q /dev/null"
                    strip_ansi="true"
                    redirect_stderr="true"
                    output_capture=".specfarm/agent-output.log"
                    fallback="log-and-summarize"
                    adapted_command="${strategy_prefix} ${command} 2>&1 | sed 's/\\x1b\\[[0-9;]*m//g'"
                    ;;
                bash)
                    strip_ansi="true"
                    redirect_stderr="true"
                    output_capture=".specfarm/agent-output.log"
                    adapted_command="${command} 2>&1 | sed 's/\\x1b\\[[0-9;]*m//g'"
                    ;;
                *)
                    adapted_command="$command"
                    ;;
            esac
            ;;
        *)
            # Generic agent handling based on OS/shell
            case "$os_family" in
                windows-mingw|windows-wsl)
                    case "$shell" in
                        powershell|pwsh)
                            adapted_command="pwsh -NoProfile -Command '${command}'"
                            ;;
                        *)
                            adapted_command="$command"
                            ;;
                    esac
                    ;;
                macos)
                    case "$shell" in
                        zsh)
                            strip_ansi="true"
                            adapted_command="${command} 2>&1"
                            ;;
                        *)
                            adapted_command="$command"
                            ;;
                    esac
                    ;;
                *)
                    adapted_command="$command"
                    ;;
            esac
            ;;
    esac

    # Build JSON response
    # Escape command strings for JSON safety
    local escaped_adapted
    escaped_adapted="${adapted_command//\\/\\\\}"
    escaped_adapted="${escaped_adapted//\"/\\\"}"
    escaped_adapted="${escaped_adapted//$'\t'/\\t}"
    escaped_adapted="${escaped_adapted//$'\n'/\\n}"
    escaped_adapted="${escaped_adapted//$'\r'/}"

    local escaped_original
    escaped_original="${command//\\/\\\\}"
    escaped_original="${escaped_original//\"/\\\"}"
    escaped_original="${escaped_original//$'\t'/\\t}"
    escaped_original="${escaped_original//$'\n'/\\n}"
    escaped_original="${escaped_original//$'\r'/}"

    cat <<EOF
{"adapted_command":"${escaped_adapted}","original_command":"${escaped_original}","strategy":{"prefix":"${strategy_prefix}","strip_ansi":${strip_ansi},"redirect_stderr":${redirect_stderr},"output_capture":"${output_capture}","timeout":"${timeout}s","fallback":"${fallback}"},"agent_id":"${agent_id}","os_family":"${os_family}","shell":"${shell}"}
EOF
}
