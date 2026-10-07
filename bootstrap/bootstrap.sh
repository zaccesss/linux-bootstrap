#!/usr/bin/env bash
#
# Linux Bootstrap entry point. Runs every default stage in order, then any optional extras asked
# for with --with. Every stage is safe to re-run: apt skips what is installed and each installer
# checks for an existing copy first.

set -Eeuo pipefail

BOOTSTRAP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BOOTSTRAP_ROOT
readonly STAGES_DIR="$BOOTSTRAP_ROOT/stages"

# shellcheck source=bootstrap/lib/logging.sh
source "$BOOTSTRAP_ROOT/lib/logging.sh"
# shellcheck source=bootstrap/lib/common.sh
source "$BOOTSTRAP_ROOT/lib/common.sh"
# shellcheck source=bootstrap/lib/platform.sh
source "$BOOTSTRAP_ROOT/lib/platform.sh"
# shellcheck source=bootstrap/lib/packages.sh
source "$BOOTSTRAP_ROOT/lib/packages.sh"
# shellcheck source=bootstrap/lib/toolchains.sh
source "$BOOTSTRAP_ROOT/lib/toolchains.sh"
# shellcheck source=bootstrap/lib/embedded.sh
source "$BOOTSTRAP_ROOT/lib/embedded.sh"
# shellcheck source=bootstrap/lib/cloud.sh
source "$BOOTSTRAP_ROOT/lib/cloud.sh"
# shellcheck source=bootstrap/lib/cli.sh
source "$BOOTSTRAP_ROOT/lib/cli.sh"
# shellcheck source=bootstrap/lib/devtools.sh
source "$BOOTSTRAP_ROOT/lib/devtools.sh"
# shellcheck source=bootstrap/lib/integration.sh
source "$BOOTSTRAP_ROOT/lib/integration.sh"
# shellcheck source=bootstrap/lib/environment.sh
source "$BOOTSTRAP_ROOT/lib/environment.sh"
# shellcheck source=bootstrap/lib/optional.sh
source "$BOOTSTRAP_ROOT/lib/optional.sh"

trap 'handle_error "$LINENO" "$BASH_COMMAND" "$?"' ERR

usage() {
    cat <<'EOF'
Usage: bootstrap.sh [options]

Sets up an Ubuntu 24.04 or 26.04 development machine (ARM64 or x86_64, desktop, WSL or server).

Options:
  --with a,b,c     also install these optional extras (see --list)
  --extras-only    skip the default stages and install only the --with extras
  --list           list the optional extras and exit
  -h, --help       show this help and exit

Environment:
  LINUX_BOOTSTRAP_ALLOW_UNSUPPORTED=1   try an Ubuntu release other than 24.04 or 26.04
  LINUX_BOOTSTRAP_SIMULATE=1            resolve packages without installing (used by CI)
EOF
}

OPTIONAL_REQUESTED=()
EXTRAS_ONLY=0

parse_arguments() {
    while (( $# > 0 )); do
        case "$1" in
            --with)
                if [[ -z "${2:-}" ]]; then
                    log_error "--with needs a comma-separated list of extras"
                    return 1
                fi
                local -a names
                IFS=',' read -r -a names <<< "$2"
                OPTIONAL_REQUESTED+=("${names[@]}")
                shift 2
                ;;
            --with=*)
                local -a names
                IFS=',' read -r -a names <<< "${1#--with=}"
                OPTIONAL_REQUESTED+=("${names[@]}")
                shift
                ;;
            --extras-only)
                EXTRAS_ONLY=1
                shift
                ;;
            --list)
                list_optional_tools
                exit 0
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage >&2
                return 1
                ;;
        esac
    done

    if (( EXTRAS_ONLY )) && (( ${#OPTIONAL_REQUESTED[@]} == 0 )); then
        log_error "--extras-only needs --with to say which extras to install"
        return 1
    fi

    if (( ${#OPTIONAL_REQUESTED[@]} > 0 )); then
        validate_optional_tools "${OPTIONAL_REQUESTED[@]}"
    fi
}

# what still needs a person after the run: things the bootstrap deliberately never does itself
print_next_steps() {
    log_info "Next steps:"
    log_info "  - sign in to GitHub: gh auth login"
    log_info "  - install your dotfiles for shell, git identity and editor settings"
    if is_wsl; then
        log_info "  - if systemd was just enabled, run 'wsl --shutdown' in Windows and reopen Ubuntu"
    else
        log_info "  - log out and back in so the docker and dialout groups apply"
    fi
}

main() {
    parse_arguments "$@"

    log_info "Starting Linux Bootstrap"

    require_supported_platform
    initialise_bootstrap
    require_sudo

    if (( ! EXTRAS_ONLY )); then
        run_stage "base" "$STAGES_DIR/00-base.sh"
        run_stage "language-toolchains" "$STAGES_DIR/10-language-toolchains.sh"
        run_stage "embedded-tooling" "$STAGES_DIR/20-embedded-tooling.sh"
        run_stage "cloud-devops" "$STAGES_DIR/30-cloud-devops.sh"
        run_stage "cli-productivity" "$STAGES_DIR/40-cli-productivity.sh"
        run_stage "developer-tools" "$STAGES_DIR/45-developer-tools.sh"
        run_stage "git-integration" "$STAGES_DIR/50-git-integration.sh"
        run_stage "environment" "$STAGES_DIR/60-environment.sh"
    fi

    if (( ${#OPTIONAL_REQUESTED[@]} > 0 )); then
        install_optional_tools "${OPTIONAL_REQUESTED[@]}"
    fi

    log_success "Linux Bootstrap foundation completed"
    print_next_steps
}

main "$@"
