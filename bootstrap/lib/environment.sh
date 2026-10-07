#!/usr/bin/env bash
#
# settings that depend on where Ubuntu is running rather than on what is being developed: WSL on
# Windows, a desktop VM or a real desktop install. Servers and containers need none of this.

readonly WSL_CONF="${LINUX_BOOTSTRAP_WSL_CONF:-/etc/wsl.conf}"

# QEMU-based VMs (UTM's QEMU backend, GNOME Boxes, virt-manager) need these for the host to see the
# guest's IP address, share the clipboard and resize the display with the window. Apple's own
# Virtualization framework has its own integration and needs neither
readonly VM_GUEST_PACKAGES=(
    qemu-guest-agent
    spice-vdagent
)

# wslu provides wslview, which opens links and files in Windows' default browser. Ubuntu 26.04
# no longer packages it, so there the BROWSER variable is pointed at Windows instead
readonly WSL_PACKAGES_24_04=(
    wslu
)

# WSL only starts systemd when wsl.conf asks for it. Docker, snaps and user services all need
# systemd running
enable_wsl_systemd() {
    if grep -qs '^[[:space:]]*systemd[[:space:]]*=[[:space:]]*true' "$WSL_CONF"; then
        log_info "systemd is already enabled in ${WSL_CONF}"
        return 0
    fi

    if is_simulate_mode; then
        return 0
    fi

    log_info "Enabling systemd in ${WSL_CONF}"
    if grep -qs '^\[boot\]' "$WSL_CONF"; then
        as_root sed -i '/^\[boot\]/a systemd=true' "$WSL_CONF"
    else
        printf '\n[boot]\nsystemd=true\n' | as_root tee -a "$WSL_CONF" >/dev/null
    fi

    log_warn "Restart WSL for systemd to start: run 'wsl --shutdown' in Windows, then reopen Ubuntu"
}

configure_wsl() {
    log_info "Configuring WSL"

    if is_release "24.04"; then
        apt_install "${WSL_PACKAGES_24_04[@]}"
    else
        log_info "wslu is not packaged on Ubuntu ${PLATFORM_RELEASE}; set BROWSER=explorer.exe in your shell profile to open links in Windows"
    fi

    enable_wsl_systemd
}

configure_vm_guest() {
    case "$PLATFORM_VIRT" in
        qemu|kvm)
            log_info "Installing QEMU guest integration for the ${PLATFORM_VIRT} virtual machine"
            apt_install "${VM_GUEST_PACKAGES[@]}"
            ;;
        *)
            log_info "No guest integration needed for virtualisation: ${PLATFORM_VIRT}"
            ;;
    esac
}

configure_environment() {
    # simulate mode resolves every branch so CI checks each package list exists
    if is_simulate_mode; then
        apt_install "${VM_GUEST_PACKAGES[@]}"
        if is_release "24.04"; then
            apt_install "${WSL_PACKAGES_24_04[@]}"
        fi
        return 0
    fi

    case "$PLATFORM_ENV" in
        wsl) configure_wsl ;;
        desktop) configure_vm_guest ;;
        *) log_info "No environment-specific setup for ${PLATFORM_ENV}" ;;
    esac
}
