#!/usr/bin/env bash
#
# shared plumbing for every stage: run modes, privilege handling, apt wrappers and vendor
# repositories. Stages call these helpers instead of apt-get or sudo directly, so the three run
# modes below behave the same everywhere.
#
# run modes:
#   normal     installs everything for real
#   simulate   LINUX_BOOTSTRAP_SIMULATE=1. Vendor repositories are added for real, apt only resolves
#              packages (apt-get --simulate) and external installers are skipped. CI uses it in clean
#              containers to prove every package exists on every supported release and architecture
#   test       LINUX_BOOTSTRAP_TEST_MODE=1. apt-get and sudo are stubs from the test suite, so
#              nothing touches the network or the machine

readonly BOOTSTRAP_STATE_DIR="${HOME}/.local/state/linux-bootstrap"
readonly BOOTSTRAP_KEYRING_DIR="/etc/apt/keyrings"

# a freshly installed desktop runs unattended upgrades for its first minutes and holds apt's lock,
# so apt waits up to five minutes for it instead of failing straight away
readonly APT_LOCK_WAIT=(-o DPkg::Lock::Timeout=300)

# set when a vendor repository is added, so the next install refreshes apt metadata first
APT_METADATA_STALE=1

is_test_mode() {
    [[ "${LINUX_BOOTSTRAP_TEST_MODE:-0}" == "1" ]]
}

is_simulate_mode() {
    [[ "${LINUX_BOOTSTRAP_SIMULATE:-0}" == "1" ]]
}

# external installers (nvm, rustup, swiftly, the AWS CLI, PlatformIO and the like) download and
# run vendor scripts, which only makes sense on a real install
external_installers_enabled() {
    ! is_test_mode && ! is_simulate_mode
}

initialise_bootstrap() {
    mkdir -p "$BOOTSTRAP_STATE_DIR"

    log_info "Bootstrap state directory: $BOOTSTRAP_STATE_DIR"
}

# runs a command as root. CI containers already run as root and have no sudo; everywhere else
# sudo runs non-interactively because require_sudo has already cached the password
as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    else
        sudo -n "$@"
    fi
}

# asks for the sudo password once up front and keeps the timestamp fresh, so a long run never
# stops at a password prompt halfway through a stage
require_sudo() {
    if [[ "$(id -u)" -eq 0 ]] || is_test_mode; then
        return 0
    fi

    # machines with password-free sudo (cloud images, OrbStack, some WSL setups) need no prompt;
    # sudo -v would still ask on those, because validating always wants a password by default
    if ! sudo -n true 2>/dev/null; then
        log_info "Administrator access is needed to install packages"
        sudo -v
    fi

    # refresh the cached credentials until the bootstrap process exits
    local parent_pid="$$"
    (
        while kill -0 "$parent_pid" 2>/dev/null; do
            sudo -n true 2>/dev/null
            sleep 50
        done
    ) &
}

apt_update() {
    log_info "Refreshing APT package metadata"
    as_root env DEBIAN_FRONTEND=noninteractive apt-get "${APT_LOCK_WAIT[@]}" update
    APT_METADATA_STALE=0
}

# installs packages without recommends, refreshing metadata first only when something changed
# since the last refresh. In simulate mode apt resolves the packages and stops, which is enough to
# prove every name exists for this release and architecture
apt_install() {
    if (( $# == 0 )); then
        return 0
    fi

    if (( APT_METADATA_STALE )); then
        apt_update
    fi

    local -a flags=("${APT_LOCK_WAIT[@]}" -y --no-install-recommends)
    if is_simulate_mode; then
        flags+=(--simulate)
    fi

    as_root env DEBIAN_FRONTEND=noninteractive apt-get install "${flags[@]}" "$@"
}

# adding a repository needs curl and gpg before anything else exists. They are installed for real
# even in simulate mode, because a minimal image (or a CI container) has neither and the base
# stage only resolves packages there
ensure_repository_prerequisites() {
    if command -v curl >/dev/null 2>&1 && command -v gpg >/dev/null 2>&1; then
        return 0
    fi

    log_info "Installing curl, gnupg and CA certificates for vendor repositories"
    if (( APT_METADATA_STALE )); then
        apt_update
    fi
    as_root env DEBIAN_FRONTEND=noninteractive apt-get "${APT_LOCK_WAIT[@]}" install -y --no-install-recommends \
        ca-certificates curl gnupg
}

# adds a vendor APT repository with its signing key in its own keyring, so the key is trusted for
# that one repository only rather than for every package source on the system
#   $1 short name for the keyring and list file
#   $2 URL of the signing key, armoured or binary
#   $3 everything after "deb [arch=... signed-by=...]"
add_apt_repository_with_key() {
    local name="$1"
    local key_url="$2"
    local repository="$3"
    local keyring="${BOOTSTRAP_KEYRING_DIR}/${name}.gpg"
    local list_file="/etc/apt/sources.list.d/${name}.list"

    if is_test_mode; then
        log_info "Skipping the ${name} APT repository in test mode"
        return 0
    fi

    ensure_repository_prerequisites

    log_info "Adding the ${name} APT repository"
    as_root mkdir -p -m 755 "$BOOTSTRAP_KEYRING_DIR"

    # vendors ship either text-armoured or binary keys and apt wants binary, so only armoured keys
    # go through gpg --dearmor
    local key_file
    key_file="$(download "$key_url")"
    if grep -q -- '-----BEGIN PGP PUBLIC KEY BLOCK-----' "$key_file"; then
        gpg --dearmor < "$key_file" | as_root tee "$keyring" >/dev/null
    else
        as_root tee "$keyring" < "$key_file" >/dev/null
    fi
    rm -f "$key_file"
    as_root chmod go+r "$keyring"

    printf 'deb [arch=%s signed-by=%s] %s\n' "$PLATFORM_ARCH" "$keyring" "$repository" \
        | as_root tee "$list_file" >/dev/null

    APT_METADATA_STALE=1
}

# downloads a URL to a new temporary file and prints its path; the caller removes it
download() {
    local url="$1"
    local target

    target="$(mktemp)"
    curl -fsSL "$url" -o "$target"
    printf '%s\n' "$target"
}

# latest release tag of a GitHub repository, used for tools that Ubuntu does not package on every
# supported release
latest_github_tag() {
    local repository="$1"

    curl -fsSL "https://api.github.com/repos/${repository}/releases/latest" | jq -r '.tag_name'
}

# installs one binary from a release archive into ~/.local/bin, for tools Ubuntu does not package.
# The archive layout differs between projects (some nest the binary in a folder), so the binary is
# found by name wherever it sits
#   $1 archive URL (.tar.gz or .tar.xz)
#   $2 binary name inside the archive
install_release_binary() {
    local url="$1"
    local binary="$2"
    local archive
    local extract_dir
    local found

    archive="$(download "$url")"
    extract_dir="$(mktemp -d)"
    tar -xf "$archive" -C "$extract_dir"

    found="$(find "$extract_dir" -type f -name "$binary" -perm -u+x | head -n 1)"
    if [[ -z "$found" ]]; then
        log_error "No ${binary} binary found in ${url}"
        rm -rf "$extract_dir" "$archive"
        return 1
    fi

    mkdir -p "${HOME}/.local/bin"
    install -m 755 "$found" "${HOME}/.local/bin/${binary}"
    rm -rf "$extract_dir" "$archive"

    export PATH="${HOME}/.local/bin:$PATH"
}

# checks that every command given is on PATH and names each missing one before failing, so one
# run shows everything that is wrong rather than only the first problem
#   $1 label for the messages
#   $@ commands to look for
verify_commands() {
    local label="$1"
    shift
    local command_name
    local missing=0

    for command_name in "$@"
    do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            log_error "${label} command is unavailable: ${command_name}"
            missing=1
        fi
    done

    if (( missing )); then
        return 1
    fi

    log_success "${label} verified successfully"
}

run_stage() {
    local stage_name="$1"
    local stage_path="$2"

    if [[ ! -x "$stage_path" ]]; then
        log_error "Stage is missing or not executable: $stage_path"
        return 1
    fi

    log_info "Running stage: $stage_name"
    # shellcheck disable=SC1090
    source "$stage_path"
    printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$stage_name" >> "${BOOTSTRAP_STATE_DIR}/stages.log"
    log_success "Completed stage: $stage_name"
}
