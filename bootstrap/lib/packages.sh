#!/usr/bin/env bash
#
# the base stage: everything later stages rely on (compilers, Python, git, archive tools, gpg for
# vendor repositories) plus the build headers most language package managers need to compile
# native extensions

readonly BASE_PACKAGES=(
    # build basics
    build-essential
    cmake
    ninja-build
    pkg-config
    autoconf
    automake
    libtool

    # fetching, archives and repository keys
    ca-certificates
    curl
    wget
    gnupg
    lsb-release
    software-properties-common
    rsync
    unzip
    zip
    xz-utils

    # version control
    git
    git-lfs
    openssh-client

    # Python, with venv and pipx so tools never get installed into the system Python
    python3
    python3-dev
    python3-pip
    python3-venv
    pipx

    # headers that pip, gem, cargo and npm builds commonly need
    libssl-dev
    libffi-dev
    zlib1g-dev
    libcurl4-openssl-dev
    libxml2-dev
    libxslt1-dev

    # data and scripting helpers
    jq
    yq
    gawk
    shellcheck
)

install_base_packages() {
    log_info "Installing base Ubuntu packages"
    apt_install "${BASE_PACKAGES[@]}"
}
