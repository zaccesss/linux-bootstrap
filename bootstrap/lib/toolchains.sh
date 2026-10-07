#!/usr/bin/env bash
#
# language and build toolchains. Most come from Ubuntu's archive; Node.js, Rust and Swift use their
# official version managers so a project can pin its own version. Zig falls back to the
# official release on Ubuntu 24.04, which does not package it.

readonly LANGUAGE_PACKAGES=(
    # C and C++: two compilers, two debuggers and the usual analysis helpers
    clang
    lldb
    gdb
    valgrind
    ccache
    nasm

    # JVM languages
    openjdk-25-jdk
    maven
    gradle
    kotlin
    scala
    clojure
    leiningen

    # libraries swiftly checks for before it will use a Swift toolchain
    gnupg2
    libz3-dev

    # everything else
    cabal-install
    dotnet-sdk-10.0
    elixir
    erlang
    ghc
    golang-go
    lua5.4
    luarocks
    php-cli
    ruby-full
    rustup
)

# packaged only from Ubuntu 26.04; 24.04 gets the official release instead (see install_zig)
readonly LANGUAGE_PACKAGES_26_04=(
    zig
)

# prefixed with BOOTSTRAP_ because nvm.sh uses NVM_VERSION internally: a readonly variable of that
# name stops nvm from working at all
readonly BOOTSTRAP_NVM_VERSION="0.40.8"
readonly NODE_MAJOR_VERSION="26"
readonly SWIFTLY_VERSION="1.2.0"
readonly SWIFT_VERSION="6.4"

# installs into the user's home so the official tarball never collides with an apt package later
readonly ZIG_INSTALL_ROOT="${HOME}/.local/share/zig"

install_language_packages() {
    local -a packages=("${LANGUAGE_PACKAGES[@]}")

    if is_release "26.04"; then
        packages+=("${LANGUAGE_PACKAGES_26_04[@]}")
    fi

    log_info "Installing language and build packages"
    apt_install "${packages[@]}"
}

# nvm.sh reads unset variables and returns non-zero from its own internal checks. Relaxing set -e
# alone is not enough: the bootstrap's ERR trap is inherited into functions (set -E) and would
# turn those internal checks into a failed run, so the trap is lifted too while nvm is in use.
# Callers must call restore_strict_mode when done
load_nvm() {
    trap - ERR
    set +eEu
    # shellcheck disable=SC1091
    source "${NVM_DIR:-${HOME}/.nvm}/nvm.sh"
}

restore_strict_mode() {
    set -eEu
    trap 'handle_error "$LINENO" "$BASH_COMMAND" "$?"' ERR
}

install_nvm_toolchain() {
    local nvm_dir="${NVM_DIR:-${HOME}/.nvm}"
    local installer

    export NVM_DIR="$nvm_dir"

    if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
        installer="$(download "https://raw.githubusercontent.com/nvm-sh/nvm/v${BOOTSTRAP_NVM_VERSION}/install.sh")"
        # PROFILE=/dev/null stops the installer editing shell profiles; dotfiles own those
        PROFILE=/dev/null NVM_DIR="$NVM_DIR" bash "$installer"
        rm -f "$installer"
    fi

    # an interrupted run (Ctrl+C mid-download) leaves nvm's lock behind. The next run then
    # waits ten minutes for an install that no longer exists. nvm gives up waiting after those ten
    # minutes, so a lock older than 15 is certainly stale
    if [[ -d "$NVM_DIR/.cache/locks" ]]; then
        find "$NVM_DIR/.cache/locks" -mindepth 1 -maxdepth 1 -mmin +15 -exec rm -rf {} +
    fi

    load_nvm
    nvm install "$NODE_MAJOR_VERSION"
    nvm alias default "$NODE_MAJOR_VERSION"
    restore_strict_mode
}

install_rust_toolchain() {
    export PATH="${HOME}/.cargo/bin:$PATH"

    if ! command -v rustup >/dev/null 2>&1; then
        log_error "rustup was not installed"
        return 1
    fi

    # a no-op when stable is already the default, so re-runs only pick up new releases
    rustup default stable
    rustup update stable
}

install_swift_toolchain() {
    if is_translated_x86; then
        log_warn "Skipping Swift: its tools need AVX instructions that Apple's x86 translation does not provide. Real x86 hardware is unaffected"
        return 0
    fi

    local swiftly_dir="${SWIFTLY_HOME_DIR:-${HOME}/.local/share/swiftly}"
    local archive
    local extract_dir

    export SWIFTLY_HOME_DIR="$swiftly_dir"
    export SWIFTLY_BIN_DIR="${SWIFTLY_BIN_DIR:-${swiftly_dir}/bin}"

    if [[ ! -x "$SWIFTLY_BIN_DIR/swiftly" ]]; then
        archive="$(download "https://download.swift.org/swiftly/linux/swiftly-${SWIFTLY_VERSION}-${PLATFORM_MACHINE}.tar.gz")"
        extract_dir="$(mktemp -d)"
        tar -xzf "$archive" -C "$extract_dir"
        # --assume-yes answers swiftly's own prompts (installing its system dependencies)
        "$extract_dir/swiftly" init --quiet-shell-followup --assume-yes --skip-install
        rm -rf "$extract_dir" "$archive"
    fi

    export PATH="$SWIFTLY_BIN_DIR:$PATH"
    # run from the home folder: swiftly records the selected version in a .swift-version file in
    # the current directory, which would otherwise land in whatever folder the bootstrap ran from
    (cd "$HOME" && "$SWIFTLY_BIN_DIR/swiftly" install --use --assume-yes "$SWIFT_VERSION")
}

# Zig on 24.04: the newest stable release from ziglang.org, linked into ~/.local/bin
install_zig() {
    local version
    local tarball_url
    local archive

    if is_release "26.04" || command -v zig >/dev/null 2>&1; then
        return 0
    fi

    version="$(curl -fsSL https://ziglang.org/download/index.json \
        | jq -r 'keys - ["master"] | sort_by(split(".") | map(tonumber)) | last')"
    tarball_url="$(curl -fsSL https://ziglang.org/download/index.json \
        | jq -r --arg v "$version" --arg target "${PLATFORM_MACHINE}-linux" '.[$v][$target].tarball')"

    log_info "Installing Zig ${version} from ziglang.org"
    archive="$(download "$tarball_url")"
    mkdir -p "$ZIG_INSTALL_ROOT/$version" "${HOME}/.local/bin"
    tar -xJf "$archive" -C "$ZIG_INSTALL_ROOT/$version" --strip-components=1
    ln -sfn "$ZIG_INSTALL_ROOT/$version/zig" "${HOME}/.local/bin/zig"
    rm -f "$archive"

    export PATH="${HOME}/.local/bin:$PATH"
}

# commands the final check expects on PATH. The test suite reads this list, so keep it in step
# with the packages and installers above
readonly LANGUAGE_COMMANDS=(
    clang
    lldb
    gdb
    valgrind
    ccache
    nasm
    node
    npm
    go
    rustc
    cargo
    java
    mvn
    gradle
    dotnet
    ruby
    php
    lua5.4
    luarocks
    erl
    elixir
    kotlinc
    scala
    ghc
    cabal
    zig
    clojure
    lein
    swift
)

verify_language_toolchains() {
    local -a commands=()
    local command_name

    for command_name in "${LANGUAGE_COMMANDS[@]}"
    do
        # swift is skipped under Rosetta translation (see install_swift_toolchain)
        if [[ "$command_name" == "swift" ]] && is_translated_x86; then
            continue
        fi
        commands+=("$command_name")
    done

    verify_commands "Language toolchain" "${commands[@]}"
}

install_language_toolchains() {
    install_language_packages

    if ! external_installers_enabled; then
        log_info "Skipping external toolchain installers in test or simulate mode"
        return 0
    fi

    install_nvm_toolchain
    install_rust_toolchain
    install_swift_toolchain
    install_zig
    verify_language_toolchains
}
