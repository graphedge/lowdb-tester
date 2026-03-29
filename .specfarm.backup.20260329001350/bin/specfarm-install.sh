#!/usr/bin/env bash
################################################################################
# SpecFarm Installation Script
#
# PURPOSE:
#   Install or update SpecFarm infrastructure in a target repository.
#   Copies .specfarm/ and .github/agents/ with optional validation.
#
#   INCLUDES (as of Phase 0b):
#   - Enhanced gather-rules-agent.sh with --audit-duplicates flag
#   - Lost-rules discovery test suite (9/9 tests passing)
#   - CrossPlatform & Windows compatibility tests
#   - specfarm-stub CLI for template generation
#   - Premium-filter agent in .github/agents/
#   - 5 recovered rules in .specfarm/rules.xml
#
# USAGE:
#   bash .specfarm/bin/specfarm-install.sh --target /path/to/repo
#   bash .specfarm/bin/specfarm-install.sh --target /path/to/repo --dry-run
#   bash .specfarm/bin/specfarm-install.sh --target /path/to/repo --yes
#
# OPTIONS:
#   --target PATH    Target repository path (required unless $TARGET_REPO_PATH set)
#   --dry-run        Show what would be done without making changes
#   --yes            Skip confirmation prompts
#   --force          Skip change detection and overwrite without prompting
#   --help           Show this help message
#
# ENVIRONMENT:
#   TARGET_REPO_PATH    Fallback target path if --target not provided
#   SPECFARM_ROOT       Override source path (default: auto-detect)
#
# EXIT CODES:
#   0 - Success
#   1 - General error
#   2 - Invalid arguments
#   3 - Target validation failed
#   4 - Copy operation failed
#   5 - Test suite failed
#
# Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
################################################################################

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Flags
DRY_RUN=false
SKIP_PROMPT=false
SKIP_TESTS=false
FORCE_INSTALL=false
TARGET_PATH=""

# Auto-detect SPECFARM_ROOT (directory containing this script's parent .specfarm/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPECFARM_ROOT="${SPECFARM_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

################################################################################
# Logging functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

################################################################################
# Help message
################################################################################

show_help() {
    cat << 'EOF'
SpecFarm Installation Script

Install or update SpecFarm infrastructure in a target repository.

USAGE:
    bash .specfarm/bin/specfarm-install.sh --target /path/to/repo [OPTIONS]

OPTIONS:
    --target PATH    Target repository path (required unless $TARGET_REPO_PATH set)
    --dry-run        Show planned actions without making changes
    --yes            Skip confirmation prompts
    --force          Skip change detection and overwrite without prompting
    --skip-tests     Skip post-install test suite (useful for CI/testing)
    --help           Show this help message

ENVIRONMENT:
    TARGET_REPO_PATH    Fallback target path if --target not provided
    SPECFARM_ROOT       Override source path (default: auto-detect)

EXAMPLES:
    # Install to a new repo
    bash .specfarm/bin/specfarm-install.sh --target ~/my-project

    # Update existing installation (with diff review)
    bash .specfarm/bin/specfarm-install.sh --target ~/my-project

    # Dry-run to see what would change
    bash .specfarm/bin/specfarm-install.sh --target ~/my-project --dry-run

    # Auto-accept updates
    bash .specfarm/bin/specfarm-install.sh --target ~/my-project --yes

POST-INSTALL:
    After installation, optionally validate rule duplications in target:
    bash /path/to/repo/.specfarm/agents/gather-rules-agent.sh --audit-duplicates

    See docs/ for feature overview and user guide.

EXIT CODES:
    0 - Success
    1 - General error
    2 - Invalid arguments
    3 - Target validation failed
    4 - Copy operation failed
    5 - Test suite failed
EOF
}

################################################################################
# Argument parsing
################################################################################

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target)
                TARGET_PATH="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --yes)
                SKIP_PROMPT=true
                shift
                ;;
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --force)
                FORCE_INSTALL=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information."
                exit 2
                ;;
        esac
    done

    # Use TARGET_REPO_PATH env var as fallback
    if [[ -z "$TARGET_PATH" ]]; then
        TARGET_PATH="${TARGET_REPO_PATH:-}"
    fi

    if [[ -z "$TARGET_PATH" ]]; then
        log_error "Target path required. Use --target or set TARGET_REPO_PATH"
        exit 2
    fi
}

################################################################################
# Validation
################################################################################

validate_source() {
    log_info "Validating source: $SPECFARM_ROOT"

    if [[ ! -d "$SPECFARM_ROOT/.specfarm" ]]; then
        log_error "Source .specfarm/ not found at: $SPECFARM_ROOT"
        log_info "Expected: $SPECFARM_ROOT/.specfarm/"
        exit 3
    fi

    if [[ ! -d "$SPECFARM_ROOT/.github/agents" ]]; then
        log_warn ".github/agents/ not found (optional)"
    fi

    log_success "Source validated: $SPECFARM_ROOT"
}

validate_target() {
    log_info "Validating target: $TARGET_PATH"

    if [[ ! -d "$TARGET_PATH" ]]; then
        log_error "Target directory does not exist: $TARGET_PATH"
        exit 3
    fi

    if [[ ! -d "$TARGET_PATH/.git" ]]; then
        log_warn "Target is not a git repository: $TARGET_PATH"
        log_info "Continuing anyway..."
    fi

    log_success "Target validated: $TARGET_PATH"
}

################################################################################
# Diff and change detection
################################################################################

compute_diff() {
    local source="$1"
    local target="$2"

    if [[ ! -d "$target" ]]; then
        echo "NEW_INSTALLATION"
        return 0
    fi

    # Compare using md5sum/sha256sum
    local hash_cmd="md5sum"
    if ! command -v md5sum &>/dev/null; then
        hash_cmd="sha256sum"
    fi

    local source_files target_files
    source_files=$(cd "$source" && find . -type f -exec $hash_cmd {} \; 2>/dev/null | sort -k2)
    target_files=$(cd "$target" && find . -type f -exec $hash_cmd {} \; 2>/dev/null | sort -k2)

    if [[ "$source_files" == "$target_files" ]]; then
        echo "NO_CHANGES"
    else
        echo "HAS_CHANGES"
    fi
}

show_changes() {
    local source="$1"
    local target="$2"

    log_info "Detecting changes..."

    # New files
    local new_files
    new_files=$(cd "$source" && find . -type f | while read -r f; do
        [[ ! -f "$target/$f" ]] && echo "  + $f"
    done)

    # Modified files
    local modified_files
    modified_files=$(cd "$source" && find . -type f | while read -r f; do
        if [[ -f "$target/$f" ]]; then
            if ! cmp -s "$source/$f" "$target/$f"; then
                echo "  ~ $f"
            fi
        fi
    done)

    # Deleted files (in target but not in source)
    local deleted_files
    deleted_files=$(cd "$target" && find . -type f | while read -r f; do
        [[ ! -f "$source/$f" ]] && echo "  - $f"
    done)

    if [[ -n "$new_files" ]]; then
        echo -e "${GREEN}New files:${NC}"
        echo "$new_files"
    fi

    if [[ -n "$modified_files" ]]; then
        echo -e "${YELLOW}Modified files:${NC}"
        echo "$modified_files"
    fi

    if [[ -n "$deleted_files" ]]; then
        echo -e "${RED}Deleted files (will be removed from target):${NC}"
        echo "$deleted_files"
    fi

    if [[ -z "$new_files" && -z "$modified_files" && -z "$deleted_files" ]]; then
        echo "  No changes detected."
    fi
}

################################################################################
# Installation
################################################################################

install_specfarm() {
    local source_specfarm="$SPECFARM_ROOT/.specfarm"
    local target_specfarm="$TARGET_PATH/.specfarm"

    log_info "Installing .specfarm/ to target..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would copy: $source_specfarm → $target_specfarm"
        return 0
    fi

    # Create backup if target exists, then remove before fresh copy
    if [[ -d "$target_specfarm" ]]; then
        local backup="$target_specfarm.backup.$(date +%Y%m%d%H%M%S)"
        log_info "Creating backup: $backup"
        cp -rp "$target_specfarm" "$backup"
        rm -rf "$target_specfarm"
    fi

    # Copy with preserved permissions
    mkdir -p "$TARGET_PATH"
    cp -rp "$source_specfarm" "$target_specfarm" || {
        log_error "Failed to copy .specfarm/"
        exit 4
    }

    log_success "Copied .specfarm/ to target"
}

install_agents() {
    local source_agents="$SPECFARM_ROOT/.github/agents"
    local target_agents="$TARGET_PATH/.github/agents"

    if [[ ! -d "$source_agents" ]]; then
        log_warn "Source .github/agents/ not found, skipping"
        return 0
    fi

    log_info "Installing .github/agents/ to target..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would copy: $source_agents → $target_agents"
        return 0
    fi

    # Create backup if target exists, then remove before fresh copy
    if [[ -d "$target_agents" ]]; then
        local backup="$target_agents.backup.$(date +%Y%m%d%H%M%S)"
        log_info "Creating backup: $backup"
        cp -rp "$target_agents" "$backup"
        rm -rf "$target_agents"
    fi

    mkdir -p "$(dirname "$target_agents")"
    cp -rp "$source_agents" "$target_agents" || {
        log_error "Failed to copy .github/agents/"
        exit 4
    }

    log_success "Copied .github/agents/ to target"
}

install_templates() {
    local source_templates="$SPECFARM_ROOT/.specfarm/templates"
    local target_templates="$TARGET_PATH/.specfarm/templates"

    if [[ ! -d "$source_templates" ]]; then
        log_warn "Source .specfarm/templates/ not found, skipping"
        return 0
    fi

    log_info "Installing .specfarm/templates/ to target..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would copy: $source_templates → $target_templates"
        return 0
    fi

    # Create backup if target exists, then remove before fresh copy
    if [[ -d "$target_templates" ]]; then
        local backup="$target_templates.backup.$(date +%Y%m%d%H%M%S)"
        log_info "Creating backup: $backup"
        cp -rp "$target_templates" "$backup"
        rm -rf "$target_templates"
    fi

    mkdir -p "$(dirname "$target_templates")"
    cp -rp "$source_templates" "$target_templates" || {
        log_error "Failed to copy .specfarm/templates/"
        exit 4
    }

    log_success "Copied .specfarm/templates/ to target"
}

################################################################################
# Post-install validation
################################################################################

run_tests() {
    local test_runner="$TARGET_PATH/.specfarm/tests/run_all_tests.sh"

    if [[ "$SKIP_TESTS" == "true" ]]; then
        log_info "Skipping post-install tests (--skip-tests)"
        return 0
    fi

    if [[ ! -f "$test_runner" ]]; then
        log_warn "Test runner not found: $test_runner"
        log_info "Skipping tests"
        return 0
    fi

    log_info "Running test suite in target..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would run: bash $test_runner"
        return 0
    fi

    local output
    if output=$(cd "$TARGET_PATH" && bash "$test_runner" 2>&1); then
        log_success "Test suite passed"
        echo "$output" | tail -20
        return 0
    else
        log_error "Test suite failed"
        echo "$output" | tail -40
        return 5
    fi
}

################################################################################
# Main workflow
################################################################################

main() {
    parse_args "$@"

    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║           SpecFarm Installation Script                   ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""

    validate_source
    validate_target

    # Check if this is an update
    local diff_result
    diff_result=$(compute_diff "$SPECFARM_ROOT/.specfarm" "$TARGET_PATH/.specfarm")

    case "$diff_result" in
        NEW_INSTALLATION)
            log_info "New installation detected"
            ;;
        NO_CHANGES)
            log_success "Target is up-to-date, no changes needed"
            exit 0
            ;;
        HAS_CHANGES)
            if [[ "$FORCE_INSTALL" == "true" ]]; then
                log_info "Forcing installation, skipping change detection"
            else
                log_warn "Existing installation detected with changes"
                echo ""
                show_changes "$SPECFARM_ROOT/.specfarm" "$TARGET_PATH/.specfarm"
                echo ""

                if [[ "$SKIP_PROMPT" != "true" && "$DRY_RUN" != "true" ]]; then
                    read -p "Proceed with update? [Y/n] " -n 1 -r
                    echo
                    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
                        log_info "Update cancelled by user"
                        exit 0
                    fi
                fi
            fi
            ;;
    esac

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY-RUN mode: no changes will be made"
        echo ""
    fi

    install_specfarm
    install_agents
    install_templates


    if [[ "$DRY_RUN" != "true" ]]; then
        echo ""
        run_tests || {
            log_warn "Tests failed, but installation complete"
            log_info "Review test output above"
            exit 5
        }
    fi

    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║           Installation Complete                          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    log_success "SpecFarm installed to: $TARGET_PATH"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "Run without --dry-run to apply changes"
    fi
}

main "$@"
