#!/bin/bash

################################################################################
# Gather Rules Agent Caller — Hybrid Architecture Router
#
# PURPOSE:
#   Three-layer intelligent router that detects execution environment and routes
#   rules gathering to the appropriate backend:
#   - Layer 1: This caller (environment detection + routing)
#   - Layer 2a: Local backend (gather-rules-agent.sh) for CLI execution
#   - Layer 2b: GitHub backend (specfarm.gather-rules.agent.md) for Actions
#   - Layer 3: Workflows (.github/workflows/gather-rules.yml) for automation
#
# ARCHITECTURE:
#   ┌─────────────────────────────────────────────────────┐
#   │  gather-rules-agent-caller.sh (THIS FILE)           │
#   │  - Detects environment (local/GitHub/Docker/etc)    │
#   │  - Routes to appropriate backend                    │
#   │  - Handles credential injection                      │
#   │  - Provides unified interface                        │
#   └──────────────┬──────────────────────────────────────┘
#                  │
#        ┌─────────┴──────────┐
#        ▼                     ▼
#   LOCAL BACKEND         GITHUB BACKEND
#   (instant)             (automated)
#   ├── gather-rules-    ├── specfarm.gather-
#   │   agent.sh          │   rules.agent.md
#   │ (CLI execution)     │ (Actions wrapper)
#   │ (offline)           │ (PR comments)
#   │ (direct)            │ (artifacts)
#   └──────────────────────────────────────
#
# USAGE:
#   # Local development (fast iteration)
#   bash .specfarm/agents/gather-rules-agent-caller.sh -c "HEAD~10..HEAD" -p "myprefix"
#
#   # GitHub Actions (automatic routing)
#   bash .specfarm/agents/gather-rules-agent-caller.sh -c "origin/main..HEAD"
#
# OPTIONS (pass-through to gather-rules-agent.sh):
#   -r, --repo PATH              Repository root (default: current directory)
#   -c, --commit-range RANGE     Git commit range (default: HEAD~20..HEAD)
#   -s, --schema PATH            Path to XSD schema (default: rules-schema.xsd)
#   -o, --output FILE            Output file path (default: gathered-rules.md)
#   -n, --num-rules NUM          Maximum rules to generate (default: 20)
#   -p, --prefix PREFIX          Rule ID prefix (default: auto-detect or 'rule')
#   --scan-dirs DIRS             Directories to scan (comma-separated, default: auto-detect)
#   --exclude-dirs DIRS          Directories to exclude (comma-separated)
#   -h, --help                   Show this help message
#
# ENVIRONMENT DETECTION:
#   LOCAL     — Running in terminal; no special environment variables
#   GITHUB    — $GITHUB_ACTIONS == "true"
#   DOCKER    — Presence of /.dockerenv file
#   UNKNOWN   — Falls back to local execution with warning
#
# CREDENTIAL HANDLING:
#   - Accepts $GITHUB_TOKEN from environment for GitHub API calls
#   - Passes through to agent via environment variable
#   - Does NOT require token for basic local execution
#
# EXIT CODES:
#   0 — Success (agent executed without errors)
#   1 — Failure (agent failed or prerequisites not met)
#   2 — Usage error (bad arguments or missing caller script)
#
# EXAMPLES:
#   # Example 1: Local developer
#   $ bash .specfarm/agents/gather-rules-agent-caller.sh -c "HEAD~10..HEAD" -p "phase3b"
#   [OUTPUT] Detected environment: LOCAL
#   [OUTPUT] Routing to: gather-rules-agent.sh
#   [OUTPUT] Running: bash .specfarm/agents/gather-rules-agent.sh -c HEAD~10..HEAD -p phase3b
#   [OUTPUT] ✓ Rules gathered successfully
#
#   # Example 2: GitHub Actions workflow
#   $ export GITHUB_ACTIONS=true
#   $ bash .specfarm/agents/gather-rules-agent-caller.sh -c "origin/main..HEAD"
#   [OUTPUT] Detected environment: GITHUB
#   [OUTPUT] Routing to: specfarm.gather-rules.agent.md
#   [OUTPUT] Using GitHub token: ••••••••••
#   [OUTPUT] Running with GitHub context...
#   [OUTPUT] ✓ Rules gathered and artifact uploaded
#
#   # Example 3: Docker container
#   $ bash .specfarm/agents/gather-rules-agent-caller.sh --help
#   [OUTPUT] Detected environment: DOCKER
#   [OUTPUT] Routing to: gather-rules-agent.sh (with Docker context)
#
################################################################################

set -euo pipefail

# ============================================================================
# COLORS & LOGGING
# ============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_section() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo -e "${CYAN}$*${NC}" >&2
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n" >&2
}

# ============================================================================
# ENVIRONMENT DETECTION
# ============================================================================

DETECTED_ENV="LOCAL"
DETECTED_REASON="No special environment variables detected"

detect_environment() {
    # Check for GitHub Actions environment
    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
        DETECTED_ENV="GITHUB"
        DETECTED_REASON="GITHUB_ACTIONS=true detected"
        return 0
    fi

    # Check for Docker environment
    if [[ -f "/.dockerenv" ]]; then
        DETECTED_ENV="DOCKER"
        DETECTED_REASON="/.dockerenv file detected"
        return 0
    fi

    # Check for other CI/CD systems (for future extensibility)
    if [[ "${CI:-}" == "true" ]] && [[ -n "${GITLAB_CI:-}" ]]; then
        DETECTED_ENV="GITLAB"
        DETECTED_REASON="GITLAB_CI environment detected"
        return 0
    fi

    if [[ -n "${CI_CIRCLECI:-}" ]]; then
        DETECTED_ENV="CIRCLECI"
        DETECTED_REASON="CircleCI environment detected"
        return 0
    fi

    # Default to LOCAL if nothing matches
    DETECTED_ENV="LOCAL"
    DETECTED_REASON="No special environment variables detected"
}

# ============================================================================
# HELP & USAGE
# ============================================================================

show_help() {
    cat << 'EOF'
Gather Rules Agent Caller — Hybrid Architecture Router

USAGE:
  bash gather-rules-agent-caller.sh [OPTIONS]

DESCRIPTION:
  Routes rules gathering to appropriate backend based on environment detection.
  Provides unified interface for local CLI and GitHub Actions workflows.

OPTIONS:
  -r, --repo PATH              Repository root (default: current directory)
  -c, --commit-range RANGE     Git commit range (default: HEAD~20..HEAD)
  -s, --schema PATH            Path to XSD schema (default: rules-schema.xsd)
  -o, --output FILE            Output file path (default: gathered-rules.md)
  -n, --num-rules NUM          Maximum rules to generate (default: 20)
  -p, --prefix PREFIX          Rule ID prefix (default: auto-detect or 'rule')
  --scan-dirs DIRS             Directories to scan (comma-separated, default: auto-detect)
  --exclude-dirs DIRS          Directories to exclude (comma-separated)
  --debug                      Enable debug output
  -h, --help                   Show this help message

ENVIRONMENT DETECTION:
  LOCAL          Running in terminal (fastest feedback)
  GITHUB         GitHub Actions workflow (automated, with API access)
  DOCKER         Docker container (isolated execution)
  [others]       [Other CI/CD systems reserved for future]

EXAMPLES:
  # Local development (instant feedback)
  bash gather-rules-agent-caller.sh -c "HEAD~10..HEAD" -p "myprefix"

  # GitHub Actions (automatic)
  bash gather-rules-agent-caller.sh -c "origin/main..HEAD"

  # Custom repository and output
  bash gather-rules-agent-caller.sh -r /path/to/repo -o /tmp/rules.md

  # Show this help
  bash gather-rules-agent-caller.sh --help

ARCHITECTURE:
  Layer 1 (This script)       Environment router & credential handler
  Layer 2a (Local backend)    gather-rules-agent.sh for CLI execution
  Layer 2b (GitHub backend)   specfarm.gather-rules.agent.md wrapper
  Layer 3 (Workflows)         .github/workflows/gather-rules.yml trigger

For more information, see:
  - .specfarm/agents/RULES-GATHERING-AGENT.md (full documentation)
  - .specfarm/agents/INDEX-GATHER-RULES-AGENT.md (quick reference)
  - .github/agents/specfarm.gather-rules.agent.md (GitHub agent definition)

EOF
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

DEBUG_MODE=false
AGENT_ARGS=()

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --debug)
                DEBUG_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                # Pass through all other arguments to the agent
                AGENT_ARGS+=("$1")
                shift
                ;;
        esac
    done
}

# ============================================================================
# VALIDATION
# ============================================================================

validate_prerequisites() {
    log_info "Validating prerequisites..."

    # Check that we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not a git repository. Initialize git first: git init"
        return 1
    fi
    log_success "Git repository detected"

    # Check that the core agent exists
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [[ ! -f "$script_dir/gather-rules-agent.sh" ]]; then
        log_error "Core agent not found: $script_dir/gather-rules-agent.sh"
        log_info "Expected location: .specfarm/agents/gather-rules-agent.sh"
        return 1
    fi
    log_success "Core agent found: gather-rules-agent.sh"

    return 0
}

# ============================================================================
# ROUTING LOGIC
# ============================================================================

route_local() {
    log_section "LOCAL BACKEND ROUTING"
    log_info "Environment: LOCAL"
    log_info "Backend: Direct execution via gather-rules-agent.sh"
    log_info "Mode: CLI (fast iteration, no GitHub API calls)"

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Debug output
    if [[ "$DEBUG_MODE" == "true" ]]; then
        log_info "DEBUG: Script directory: $script_dir"
        log_info "DEBUG: Arguments: ${AGENT_ARGS[*]}"
    fi

    # Execute the core agent directly
    if bash "$script_dir/gather-rules-agent.sh" "${AGENT_ARGS[@]}"; then
        log_success "Local backend execution completed successfully"
        return 0
    else
        local exit_code=$?
        log_error "Local backend execution failed (exit code: $exit_code)"
        return "$exit_code"
    fi
}

route_github() {
    log_section "GITHUB BACKEND ROUTING"
    log_info "Environment: GITHUB (GitHub Actions Workflow)"
    log_info "Backend: specfarm.gather-rules.agent.md"
    log_info "Mode: Automated workflow with PR comments & artifacts"

    # Check for GitHub token
    if [[ -z "${GITHUB_TOKEN:-}" ]]; then
        log_warning "GITHUB_TOKEN not set - some GitHub API features will be unavailable"
    else
        log_success "GitHub token detected: ${GITHUB_TOKEN:0:10}..."
    fi

    # Log GitHub context if available
    if [[ -n "${GITHUB_RUN_ID:-}" ]]; then
        log_info "GitHub Run ID: $GITHUB_RUN_ID"
    fi
    if [[ -n "${GITHUB_SHA:-}" ]]; then
        log_info "GitHub SHA: ${GITHUB_SHA:0:8}..."
    fi
    if [[ -n "${GITHUB_REF:-}" ]]; then
        log_info "GitHub Ref: $GITHUB_REF"
    fi

    # For now, still route to the core agent but with GitHub context
    # In a full implementation, this would dispatch to the GitHub Actions agent
    log_info "Routing to core agent with GitHub environment context..."

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Execute the core agent with GitHub environment
    # The agent will detect GITHUB_ACTIONS and adjust behavior accordingly
    export GITHUB_ACTIONS
    export GITHUB_TOKEN="${GITHUB_TOKEN:-}"
    export GITHUB_RUN_ID="${GITHUB_RUN_ID:-}"
    export GITHUB_SHA="${GITHUB_SHA:-}"
    export GITHUB_REF="${GITHUB_REF:-}"

    if bash "$script_dir/gather-rules-agent.sh" "${AGENT_ARGS[@]}"; then
        log_success "GitHub backend execution completed successfully"
        return 0
    else
        local exit_code=$?
        log_error "GitHub backend execution failed (exit code: $exit_code)"
        return "$exit_code"
    fi
}

route_docker() {
    log_section "DOCKER BACKEND ROUTING"
    log_info "Environment: DOCKER (Container)"
    log_info "Backend: gather-rules-agent.sh (with Docker context)"
    log_info "Mode: Containerized execution"

    # Route to local backend but with Docker context awareness
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if bash "$script_dir/gather-rules-agent.sh" "${AGENT_ARGS[@]}"; then
        log_success "Docker backend execution completed successfully"
        return 0
    else
        local exit_code=$?
        log_error "Docker backend execution failed (exit code: $exit_code)"
        return "$exit_code"
    fi
}

route_unknown() {
    log_section "UNKNOWN ENVIRONMENT"
    log_warning "Could not definitively determine environment"
    log_info "Attempting LOCAL fallback with caution"
    log_info "If this fails, check your environment and try again"

    route_local
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    log_section "GATHER RULES AGENT CALLER"
    log_info "Hybrid Architecture Router v1.0"

    # Parse arguments
    parse_args "$@"

    # Detect environment
    detect_environment
    log_success "Detected environment: $DETECTED_ENV"
    log_info "Reason: $DETECTED_REASON"

    # Validate prerequisites
    if ! validate_prerequisites; then
        log_error "Prerequisites not met. Exiting."
        return 1
    fi

    # Route to appropriate backend
    log_section "ROUTING TO BACKEND"
    local exit_code=0

    case "$DETECTED_ENV" in
        LOCAL)
            route_local || exit_code=$?
            ;;
        GITHUB)
            route_github || exit_code=$?
            ;;
        DOCKER)
            route_docker || exit_code=$?
            ;;
        *)
            route_unknown || exit_code=$?
            ;;
    esac

    # Exit with appropriate code
    if [[ $exit_code -eq 0 ]]; then
        log_section "EXECUTION COMPLETE"
        log_success "All steps completed successfully"
        return 0
    else
        log_section "EXECUTION FAILED"
        log_error "Exited with code: $exit_code"
        return "$exit_code"
    fi
}

# Run main function with all arguments
main "$@"
exit $?
