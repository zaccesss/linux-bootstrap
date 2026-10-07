#!/usr/bin/env bash
#
# Git, GitHub CLI and SSH. The bootstrap prepares the tools and safe defaults but never creates
# credentials or signs in: keys, gh auth and personal git identity stay with the user and their
# dotfiles.

readonly INTEGRATION_STATE_DIR="${BOOTSTRAP_STATE_DIR}/integration"

# Ubuntu's own gh package lags well behind, so GitHub's official APT repository is used instead
add_github_cli_repository() {
    if command -v gh >/dev/null 2>&1; then
        log_info "GitHub CLI is already installed"
        return 0
    fi

    add_apt_repository_with_key \
        "github-cli" \
        "https://cli.github.com/packages/githubcli-archive-keyring.gpg" \
        "https://cli.github.com/packages stable main"
}

install_github_cli() {
    add_github_cli_repository

    log_info "Installing the GitHub CLI"
    apt_install gh
}

initialise_git_integration() {
    mkdir -p "$INTEGRATION_STATE_DIR"

    # defaults only; user.name, user.email and signing come from the dotfiles
    if command -v git >/dev/null 2>&1; then
        git config --global init.defaultBranch main
        git config --global fetch.prune true
        git config --global pull.ff only
    fi

    # ssh refuses keys kept in a group- or world-readable folder; the final check expects it too
    mkdir -p "${HOME}/.ssh"
    chmod 700 "${HOME}/.ssh"

    printf '%s\n' "Git and GitHub integration initialised" > "$INTEGRATION_STATE_DIR/status"
    log_success "Git and GitHub integration initialised successfully"
}

# commands the final check expects on PATH. The test suite reads this list, so keep it in step
# with the packages above
readonly INTEGRATION_COMMANDS=(
    git
    gh
    ssh
)

verify_git_integration() {
    verify_commands "Integration" "${INTEGRATION_COMMANDS[@]}"

    if [[ ! -d "${HOME}/.ssh" ]]; then
        log_error "SSH directory is unavailable: ${HOME}/.ssh"
        return 1
    fi
}

install_git_integration() {
    install_github_cli
    initialise_git_integration

    if ! external_installers_enabled; then
        log_info "Skipping the integration check in test or simulate mode"
        return 0
    fi

    verify_git_integration
}
