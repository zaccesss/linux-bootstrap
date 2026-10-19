#!/usr/bin/env bash
#
# embedded and electronics tooling: ARM Cortex-M and AVR cross-compilers with their debuggers, an
# open-source FPGA/HDL flow, plus PlatformIO and Arduino CLI, which manage their own board
# packages under the user's home

readonly EMBEDDED_PACKAGES=(
    # ARM Cortex-M (STM32, nRF, RP2040 and similar)
    gcc-arm-none-eabi
    binutils-arm-none-eabi
    libnewlib-arm-none-eabi
    gdb-multiarch
    openocd

    # AVR (ATmega, as used in Arduino Uno and university labs)
    gcc-avr
    binutils-avr
    avr-libc
    avrdude

    # HDL simulation and synthesis
    ghdl
    gtkwave
    yosys

    # serial consoles for talking to boards
    minicom
    picocom
)

install_embedded_packages() {
    log_info "Installing embedded and electronics packages"
    apt_install "${EMBEDDED_PACKAGES[@]}"
}

install_platformio() {
    local installer
    local pio_dir="${PLATFORMIO_CORE_DIR:-${HOME}/.platformio}"

    export PLATFORMIO_CORE_DIR="$pio_dir"

    if [[ -x "$PLATFORMIO_CORE_DIR/penv/bin/pio" ]]; then
        "$PLATFORMIO_CORE_DIR/penv/bin/python" -m pip install --upgrade platformio
    else
        # the official installer builds PlatformIO its own virtual environment, keeping it away
        # from the system Python
        installer="$(download https://raw.githubusercontent.com/platformio/platformio-core-installer/master/get-platformio.py)"
        python3 "$installer"
        rm -f "$installer"
    fi

    export PATH="$PLATFORMIO_CORE_DIR/penv/bin:$PATH"
}

# a released version is pinned and checked against the release's own checksums file, rather than
# piping the install script from the master branch, so every machine gets the same verified build
readonly ARDUINO_CLI_VERSION="1.5.1"

install_arduino_cli() {
    local bin_dir="${HOME}/.local/bin"
    local base_url="https://github.com/arduino/arduino-cli/releases/download/v${ARDUINO_CLI_VERSION}"
    local asset
    local work_dir

    mkdir -p "$bin_dir"
    export PATH="$bin_dir:$PATH"

    if command -v arduino-cli >/dev/null 2>&1 \
        && arduino-cli version 2>/dev/null | grep -q "Version: ${ARDUINO_CLI_VERSION} "; then
        return 0
    fi

    case "$PLATFORM_ARCH" in
        amd64) asset="arduino-cli_${ARDUINO_CLI_VERSION}_Linux_64bit.tar.gz" ;;
        arm64) asset="arduino-cli_${ARDUINO_CLI_VERSION}_Linux_ARM64.tar.gz" ;;
    esac

    work_dir="$(mktemp -d)"
    curl -fsSL "${base_url}/${asset}" -o "${work_dir}/${asset}"
    curl -fsSL "${base_url}/${ARDUINO_CLI_VERSION}-checksums.txt" -o "${work_dir}/checksums.txt"
    if ! (cd "$work_dir" && grep "  ${asset}\$" checksums.txt | sha256sum --check --status); then
        log_error "Arduino CLI ${ARDUINO_CLI_VERSION} failed its checksum check"
        rm -rf "$work_dir"
        return 1
    fi

    tar -xzf "${work_dir}/${asset}" -C "$work_dir" arduino-cli
    install -m 0755 "${work_dir}/arduino-cli" "${bin_dir}/arduino-cli"
    rm -rf "$work_dir"
}

# Arduino CLI ships with no board packages, so an Uno or any other AVR board cannot compile until
# the AVR core is added
install_arduino_avr_core() {
    if ! command -v arduino-cli >/dev/null 2>&1; then
        return 0
    fi

    arduino-cli core update-index && arduino-cli core install arduino:avr
}

# serial ports belong to the dialout group, so without it every upload to a board needs sudo
grant_serial_access() {
    if is_test_mode || is_simulate_mode || id -nG "$USER" | grep -qw dialout; then
        return 0
    fi

    as_root usermod -aG dialout "$USER"
    log_warn "Added ${USER} to the dialout group for serial ports; log out and back in for it to apply"
}

# commands the final check expects on PATH. The test suite reads this list, so keep it in step
# with the packages above
readonly EMBEDDED_COMMANDS=(
    arm-none-eabi-gcc
    arm-none-eabi-objcopy
    gdb-multiarch
    openocd
    avr-gcc
    avr-objcopy
    avrdude
    ghdl
    gtkwave
    yosys
    minicom
    picocom
    pio
    arduino-cli
)

verify_embedded_tooling() {
    verify_commands "Embedded tooling" "${EMBEDDED_COMMANDS[@]}"
}

install_embedded_tooling() {
    install_embedded_packages
    grant_serial_access

    if ! external_installers_enabled; then
        log_info "Skipping external embedded tool installers in test or simulate mode"
        return 0
    fi

    install_platformio
    install_arduino_cli
    install_arduino_avr_core
    verify_embedded_tooling
}
