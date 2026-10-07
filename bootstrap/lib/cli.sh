#!/usr/bin/env bash
#
# terminal tools used every day: a modern editor and shell, better replacements for ls, cat, find
# and grep, git helpers and media converters. Ubuntu renames two of them to avoid clashes (bat is
# batcat and fd is fdfind); the dotfiles alias them back.

readonly CLI_PACKAGES=(
    # shells, editors and multiplexers
    zsh
    neovim
    vim
    tmux
    screen

    # file and text navigation
    bat
    eza
    fd-find
    fzf
    ripgrep
    tree
    zoxide

    # system monitors
    btop
    htop

    # git helpers (git-delta provides the delta pager)
    git-delta

    # media conversion, handy for docs, screenshots and lab recordings
    imagemagick
    ffmpeg
)

# packaged only from Ubuntu 26.04; 24.04 gets the official release instead (see install_lazygit)
readonly CLI_PACKAGES_26_04=(
    lazygit
)

install_cli_packages() {
    local -a packages=("${CLI_PACKAGES[@]}")

    if is_release "26.04"; then
        packages+=("${CLI_PACKAGES_26_04[@]}")
    fi

    log_info "Installing CLI productivity utilities"
    apt_install "${packages[@]}"
}

# lazygit on 24.04: the latest GitHub release, installed into ~/.local/bin
install_lazygit() {
    local tag
    local asset_arch

    if is_release "26.04" || command -v lazygit >/dev/null 2>&1; then
        return 0
    fi

    tag="$(latest_github_tag jesseduffield/lazygit)"
    # lazygit names its arm64 build "arm64" but its Intel build "x86_64"
    case "$PLATFORM_ARCH" in
        arm64) asset_arch="arm64" ;;
        amd64) asset_arch="x86_64" ;;
    esac

    log_info "Installing lazygit ${tag} from GitHub"
    install_release_binary \
        "https://github.com/jesseduffield/lazygit/releases/download/${tag}/lazygit_${tag#v}_linux_${asset_arch}.tar.gz" \
        lazygit
}

# commands the final check expects on PATH. The test suite reads this list, so keep it in step
# with the packages above
readonly CLI_COMMANDS=(
    zsh
    nvim
    vim
    tmux
    screen
    batcat
    eza
    fdfind
    fzf
    rg
    tree
    zoxide
    btop
    htop
    delta
    lazygit
    identify
    ffmpeg
)

verify_cli_tooling() {
    verify_commands "CLI productivity" "${CLI_COMMANDS[@]}"
}

install_cli_tooling() {
    install_cli_packages

    if ! external_installers_enabled; then
        log_info "Skipping external CLI installers in test or simulate mode"
        return 0
    fi

    install_lazygit
    verify_cli_tooling
}
