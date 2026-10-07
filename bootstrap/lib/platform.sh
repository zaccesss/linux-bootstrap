#!/usr/bin/env bash
#
# works out what the bootstrap is running on before any stage starts, so stages can choose the
# right packages per release and skip steps that make no sense in their environment.
#
# exported values:
#   PLATFORM_RELEASE    Ubuntu version, 24.04 or 26.04
#   PLATFORM_CODENAME   noble or resolute, used for vendor repositories
#   PLATFORM_ARCH       Debian architecture name, arm64 or amd64
#   PLATFORM_MACHINE    kernel architecture name, aarch64 or x86_64, used in vendor download URLs
#   PLATFORM_ENV        desktop, wsl, container or server
#   PLATFORM_VIRT       what systemd-detect-virt reports (apple, qemu, kvm, wsl, none and so on)

# the two current long-term support releases. Interim releases (25.04, 25.10) are left out on
# purpose: they lose support after nine months, too soon for a machine set up to last
readonly -a SUPPORTED_RELEASES=("24.04" "26.04")
readonly -a SUPPORTED_ARCHITECTURES=("arm64" "amd64")

# tests point these at fixture files to exercise every platform without needing one
readonly OS_RELEASE_FILE="${LINUX_BOOTSTRAP_OS_RELEASE:-/etc/os-release}"
readonly PROC_VERSION_FILE="${LINUX_BOOTSTRAP_PROC_VERSION:-/proc/version}"

contains() {
    local needle="$1"
    shift
    local item

    for item in "$@"
    do
        [[ "$item" == "$needle" ]] && return 0
    done

    return 1
}

detect_architecture() {
    if [[ -n "${LINUX_BOOTSTRAP_ARCH:-}" ]]; then
        printf '%s\n' "$LINUX_BOOTSTRAP_ARCH"
    elif command -v dpkg >/dev/null 2>&1; then
        dpkg --print-architecture
    else
        case "$(uname -m)" in
            aarch64) printf 'arm64\n' ;;
            x86_64) printf 'amd64\n' ;;
            *) uname -m ;;
        esac
    fi
}

detect_virtualisation() {
    if [[ -n "${LINUX_BOOTSTRAP_VIRT:-}" ]]; then
        printf '%s\n' "$LINUX_BOOTSTRAP_VIRT"
    elif command -v systemd-detect-virt >/dev/null 2>&1; then
        # exits non-zero and prints "none" on bare metal, which is a normal answer here
        systemd-detect-virt 2>/dev/null || true
    else
        printf 'none\n'
    fi
}

# WSL is checked first because a WSL distro also looks like a container to some tools. A
# desktop is only assumed when a graphical session or a desktop metapackage is actually present
detect_environment() {
    if [[ -n "${LINUX_BOOTSTRAP_ENV:-}" ]]; then
        printf '%s\n' "$LINUX_BOOTSTRAP_ENV"
    elif [[ -r "$PROC_VERSION_FILE" ]] && grep -qi microsoft "$PROC_VERSION_FILE"; then
        printf 'wsl\n'
    elif [[ -f /.dockerenv || -f /run/.containerenv ]] \
        || { command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt --container >/dev/null 2>&1; }; then
        printf 'container\n'
    elif [[ -n "${XDG_CURRENT_DESKTOP:-}" ]] \
        || dpkg-query -W -f='${Status}' ubuntu-desktop-minimal 2>/dev/null | grep -q 'install ok installed'; then
        printf 'desktop\n'
    else
        printf 'server\n'
    fi
}

require_supported_platform() {
    if [[ ! -r "$OS_RELEASE_FILE" ]]; then
        log_error "Cannot determine the operating system"
        return 1
    fi

    local ID="" VERSION_ID="" VERSION_CODENAME=""
    # shellcheck source=/dev/null
    source "$OS_RELEASE_FILE"

    if [[ "$ID" != "ubuntu" ]]; then
        log_error "Unsupported operating system: ${ID:-unknown}"
        log_error "Supported: Ubuntu ${SUPPORTED_RELEASES[*]}"
        return 1
    fi

    if ! contains "$VERSION_ID" "${SUPPORTED_RELEASES[@]}"; then
        if [[ "${LINUX_BOOTSTRAP_ALLOW_UNSUPPORTED:-0}" == "1" ]]; then
            log_warn "Ubuntu ${VERSION_ID} is not a supported release; continuing because LINUX_BOOTSTRAP_ALLOW_UNSUPPORTED=1"
        else
            log_error "Unsupported Ubuntu release: ${VERSION_ID}"
            log_error "Supported: Ubuntu ${SUPPORTED_RELEASES[*]}. Set LINUX_BOOTSTRAP_ALLOW_UNSUPPORTED=1 to try anyway"
            return 1
        fi
    fi

    PLATFORM_ARCH="$(detect_architecture)"
    if ! contains "$PLATFORM_ARCH" "${SUPPORTED_ARCHITECTURES[@]}"; then
        log_error "Unsupported architecture: ${PLATFORM_ARCH}"
        log_error "Supported: ${SUPPORTED_ARCHITECTURES[*]}"
        return 1
    fi

    case "$PLATFORM_ARCH" in
        arm64) PLATFORM_MACHINE="aarch64" ;;
        amd64) PLATFORM_MACHINE="x86_64" ;;
    esac

    PLATFORM_RELEASE="$VERSION_ID"
    PLATFORM_CODENAME="$VERSION_CODENAME"
    PLATFORM_ENV="$(detect_environment)"
    PLATFORM_VIRT="$(detect_virtualisation)"

    export PLATFORM_RELEASE PLATFORM_CODENAME PLATFORM_ARCH PLATFORM_MACHINE PLATFORM_ENV PLATFORM_VIRT

    log_success "Platform detected: Ubuntu ${PLATFORM_RELEASE} (${PLATFORM_CODENAME}) ${PLATFORM_ARCH}, ${PLATFORM_ENV}, virtualisation: ${PLATFORM_VIRT}"
}

is_release() {
    [[ "${PLATFORM_RELEASE:-}" == "$1" ]]
}

is_wsl() {
    [[ "${PLATFORM_ENV:-}" == "wsl" ]]
}

is_desktop() {
    [[ "${PLATFORM_ENV:-}" == "desktop" ]]
}

# x86_64 Ubuntu running through Apple's Rosetta translation on a Mac (OrbStack, UTM). It reports a
# "VirtualApple" CPU and lacks AVX, which a few prebuilt toolchains need. Only used to explain and
# skip those tools; real x86 hardware never matches
is_translated_x86() {
    [[ "${PLATFORM_ARCH:-}" == "amd64" ]] && grep -qs 'VirtualApple' /proc/cpuinfo
}

# desktop-only steps (GUI apps, GNOME settings, input methods) still run in simulate mode so CI
# proves their packages exist, even though CI containers have no desktop
desktop_steps_enabled() {
    is_desktop || is_simulate_mode
}
