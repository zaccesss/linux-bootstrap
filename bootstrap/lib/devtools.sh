#!/usr/bin/env bash
#
# developer tools that match the Mac setup: document, PDF and image utilities, a database client,
# the starship prompt, uv and ruff for Python, typst for documents, lychee for link checking and
# trivy for security scanning. Ubuntu packages some of them; the rest come from their official
# releases so every machine runs the same current versions.

readonly DEVTOOLS_PACKAGES=(
    # history rewriting and repository surgery
    git-filter-repo

    # PDF and image work: pdftotext and friends, PDF repair and linearising, SVG to PNG, GIF
    # optimising and images as text
    poppler-utils
    qpdf
    librsvg2-bin
    gifsicle
    jp2a

    # psql for managed Postgres databases, composer for PHP projects
    postgresql-client
    composer
)

# from Aqua Security's APT repository, which serves every release under one "generic" suite
readonly DEVTOOLS_VENDOR_PACKAGES=(
    trivy
)

add_devtools_repositories() {
    add_apt_repository_with_key \
        "trivy" \
        "https://aquasecurity.github.io/trivy-repo/deb/public.key" \
        "https://aquasecurity.github.io/trivy-repo/deb generic main"
}

install_devtools_packages() {
    local -a packages=("${DEVTOOLS_PACKAGES[@]}" "${DEVTOOLS_VENDOR_PACKAGES[@]}")

    log_info "Installing developer tools"
    apt_install "${packages[@]}"
}

# starship always comes from its official installer, even where Ubuntu packages it: the shared
# prompt config uses modules that Ubuntu's older package rejects with "Unknown key" warnings.
# The installer replaces an older copy, so re-runs keep it current
install_starship() {

    local installer
    installer="$(download https://starship.rs/install.sh)"
    mkdir -p "${HOME}/.local/bin"
    sh "$installer" --yes --bin-dir "${HOME}/.local/bin"
    rm -f "$installer"
}

# uv manages Python versions, virtual environments and command-line tools; ruff is installed
# through it so both update together with `uv tool upgrade --all`
install_uv_and_ruff() {
    local installer

    if ! command -v uv >/dev/null 2>&1; then
        installer="$(download https://astral.sh/uv/install.sh)"
        # UV_NO_MODIFY_PATH stops the installer editing shell profiles; dotfiles own those
        env UV_NO_MODIFY_PATH=1 sh "$installer"
        rm -f "$installer"
    fi

    export PATH="${HOME}/.local/bin:$PATH"
    uv tool install --upgrade ruff
}

install_typst() {
    local tag

    tag="$(latest_github_tag typst/typst)"
    log_info "Installing typst ${tag} from GitHub"
    install_release_binary \
        "https://github.com/typst/typst/releases/download/${tag}/typst-${PLATFORM_MACHINE}-unknown-linux-musl.tar.xz" \
        typst
}

install_lychee() {
    local tag

    tag="$(latest_github_tag lycheeverse/lychee)"
    log_info "Installing lychee ${tag} from GitHub"
    install_release_binary \
        "https://github.com/lycheeverse/lychee/releases/download/${tag}/lychee-${PLATFORM_MACHINE}-unknown-linux-gnu.tar.gz" \
        lychee
}

# commands the final check expects on PATH. The test suite reads this list, so keep it in step
# with the packages and installers above
readonly DEVTOOLS_COMMANDS=(
    git-filter-repo
    pdftotext
    qpdf
    rsvg-convert
    gifsicle
    jp2a
    psql
    composer
    trivy
    starship
    uv
    ruff
    typst
    lychee
)

verify_devtools() {
    verify_commands "Developer tools" "${DEVTOOLS_COMMANDS[@]}"
}

install_developer_tools() {
    add_devtools_repositories
    install_devtools_packages

    if ! external_installers_enabled; then
        log_info "Skipping external developer tool installers in test or simulate mode"
        return 0
    fi

    install_starship
    install_uv_and_ruff
    install_typst
    install_lychee
    verify_devtools
}
