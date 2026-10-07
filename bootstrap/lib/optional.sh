#!/usr/bin/env bash
#
# opt-in extras. None of these install by default; pick them with --with, for example
#   ./bootstrap/bootstrap.sh --with kicad,android
# and list them with --list. They live here rather than in a text file so that adding one later is
# a single command instead of copying steps out of documentation.
#
# each entry is "name|description|scope", where scope is "any" or "desktop". Desktop-only extras
# are skipped with a warning on WSL, servers and containers, where a GUI app would be useless.

readonly OPTIONAL_TOOLS=(
    "warp|Warp terminal|desktop"
    "blender|Blender 3D creation suite|desktop"
    "kicad|KiCad PCB and schematic design|desktop"
    "stm32|ST-Link tools for STM32 boards (STM32CubeIDE itself needs an ST account download)|any"
    "android|adb and fastboot for Android devices|any"
    "gcloud|Google Cloud CLI|any"
    "azure|Azure CLI|any"
    "flutter|Flutter SDK with Linux desktop build dependencies|any"
    "ardupilot|ArduPilot source with its SITL simulator prerequisites|any"
    "powershell|PowerShell 7 (pwsh) for scripts shared with Windows|any"
    "vercel|Vercel CLI, installed with the Node.js from the default stages|any"
    "extra-languages|Racket, SBCL (Common Lisp), R and Ada (GNAT)|any"
    "gamedev|SDL2 and SFML development libraries|any"
    "chinese-input|Pinyin and Cangjie input methods for IBus|desktop"
    "configs|Shell profile, prompt and tool configs from a dotfiles repository and config repositories, linked into place|any"
    "mac-keys|Mac-style shortcuts (Cmd+C, Cmd+V and so on) and natural scrolling, for a VM on a Mac|desktop"
)

readonly TOOLS_DIR="${HOME}/dev/tools"

optional_field() {
    local entry="$1"
    local field="$2"

    cut -d'|' -f"$field" <<< "$entry"
}

find_optional_entry() {
    local name="$1"
    local entry

    for entry in "${OPTIONAL_TOOLS[@]}"
    do
        if [[ "$(optional_field "$entry" 1)" == "$name" ]]; then
            printf '%s\n' "$entry"
            return 0
        fi
    done

    return 1
}

list_optional_tools() {
    local entry

    printf 'Optional extras (install with --with name,name):\n\n'
    for entry in "${OPTIONAL_TOOLS[@]}"
    do
        printf '  %-16s %s%s\n' \
            "$(optional_field "$entry" 1)" \
            "$(optional_field "$entry" 2)" \
            "$( [[ "$(optional_field "$entry" 3)" == "desktop" ]] && printf ' [desktop only]')"
    done
}

# fails before any stage runs when a requested name does not exist, so a typo never costs a
# half-finished run
validate_optional_tools() {
    local name

    for name in "$@"
    do
        if ! find_optional_entry "$name" >/dev/null; then
            log_error "Unknown optional extra: ${name}. Run with --list to see them all"
            return 1
        fi
    done
}

optional_warp() {
    add_apt_repository_with_key \
        "warp" \
        "https://releases.warp.dev/linux/keys/warp.asc" \
        "https://releases.warp.dev/linux/deb stable main"
    apt_install warp-terminal
}

optional_blender() {
    apt_install blender
}

optional_kicad() {
    apt_install kicad
}

optional_stm32() {
    apt_install stlink-tools
    log_info "STM32CubeIDE and STM32CubeProgrammer need an ST account: download them from st.com if a project needs them"
}

optional_android() {
    apt_install adb fastboot
}

optional_gcloud() {
    add_apt_repository_with_key \
        "google-cloud-sdk" \
        "https://packages.cloud.google.com/apt/doc/apt-key.gpg" \
        "https://packages.cloud.google.com/apt cloud-sdk main"
    apt_install google-cloud-cli
}

optional_azure() {
    add_apt_repository_with_key \
        "azure-cli" \
        "https://packages.microsoft.com/keys/microsoft.asc" \
        "https://packages.microsoft.com/repos/azure-cli/ ${PLATFORM_CODENAME} main"
    apt_install azure-cli
}

optional_flutter() {
    # what `flutter doctor` asks for to build Linux desktop apps
    apt_install clang cmake ninja-build pkg-config libgtk-3-dev mesa-utils

    if ! external_installers_enabled; then
        return 0
    fi

    if [[ -d "$TOOLS_DIR/flutter/.git" ]]; then
        git -C "$TOOLS_DIR/flutter" pull --ff-only
    else
        mkdir -p "$TOOLS_DIR"
        git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$TOOLS_DIR/flutter"
    fi

    log_info "Add ${TOOLS_DIR}/flutter/bin to PATH in your shell profile, then run flutter doctor"
}

# ArduPilot's installer checks the Ubuntu codename. A release it does not list yet (26.04 when
# this was written) is added to the newest group it knows. The python3-argparse package that
# newer releases dropped is swapped for the standard library package that replaced it
patch_ardupilot_installer() {
    local installer="$1"

    if grep -q "'${PLATFORM_CODENAME}'" "$installer"; then
        return 0
    fi

    log_warn "ArduPilot's installer does not know Ubuntu ${PLATFORM_CODENAME} yet; patching a local copy"
    sed -i "s/\[ \${RELEASE_CODENAME} == 'questing' \] ||/[ \${RELEASE_CODENAME} == 'questing' ] ||\n     [ \${RELEASE_CODENAME} == '${PLATFORM_CODENAME}' ] ||/" "$installer"
    sed -i 's/SITL_PKGS+=" python3-argparse"/SITL_PKGS+=" libpython3-stdlib"/' "$installer"
}

optional_ardupilot() {
    if ! external_installers_enabled; then
        log_info "Skipping the ArduPilot checkout in test or simulate mode"
        return 0
    fi

    local ardupilot_dir="$TOOLS_DIR/ardupilot"

    if [[ -d "$ardupilot_dir/.git" ]]; then
        git -C "$ardupilot_dir" pull --ff-only
    else
        mkdir -p "$TOOLS_DIR"
        git clone --recurse-submodules https://github.com/ArduPilot/ardupilot.git "$ardupilot_dir"
    fi

    patch_ardupilot_installer "$ardupilot_dir/Tools/environment_install/install-prereqs-ubuntu.sh"
    (cd "$ardupilot_dir" && Tools/environment_install/install-prereqs-ubuntu.sh -y)
    log_info "Open a new terminal, then run sim_vehicle.py from ${ardupilot_dir} to start SITL"
}

# Microsoft's APT repository only carries x64 builds, so the official tarball is used on both
# architectures for one consistent install
optional_powershell() {
    if ! external_installers_enabled; then
        return 0
    fi

    local tag
    local version
    local asset_arch
    local install_dir
    local archive

    tag="$(latest_github_tag PowerShell/PowerShell)"
    version="${tag#v}"
    case "$PLATFORM_ARCH" in
        arm64) asset_arch="arm64" ;;
        amd64) asset_arch="x64" ;;
    esac

    install_dir="${HOME}/.local/share/powershell/${version}"
    archive="$(download "https://github.com/PowerShell/PowerShell/releases/download/${tag}/powershell-${version}-linux-${asset_arch}.tar.gz")"
    mkdir -p "$install_dir" "${HOME}/.local/bin"
    tar -xzf "$archive" -C "$install_dir"
    chmod +x "$install_dir/pwsh"
    ln -sfn "$install_dir/pwsh" "${HOME}/.local/bin/pwsh"
    rm -f "$archive"
}

optional_vercel() {
    if ! external_installers_enabled; then
        return 0
    fi

    # nvm is not on PATH in a fresh shell until the dotfiles load it, so it is loaded here
    load_nvm
    npm install --global vercel
    restore_strict_mode
}

optional_extra_languages() {
    apt_install racket sbcl r-base gnat gprbuild
}

optional_gamedev() {
    apt_install \
        libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev \
        libsfml-dev libcsfml-dev
}

optional_chinese_input() {
    apt_install ibus-libpinyin ibus-table-cangjie5
    log_info "Add the input sources in Settings, Keyboard, Input Sources"
}

# Toshy remaps Super (the Mac's Cmd key in a VM) to behave like Cmd, per app, so Cmd+C copies in a
# terminal and a browser alike. Its installer asks questions on purpose, including a code to type
# back, so it is run interactively rather than forced
optional_mac_keys() {
    if ! external_installers_enabled; then
        return 0
    fi

    # natural scrolling: content follows the fingers, as on macOS
    gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll true
    gsettings set org.gnome.desktop.peripherals.mouse natural-scroll true

    if [[ -d "$TOOLS_DIR/toshy/.git" ]]; then
        git -C "$TOOLS_DIR/toshy" pull --ff-only
    else
        mkdir -p "$TOOLS_DIR"
        git clone --depth 1 https://github.com/RedBearAK/toshy.git "$TOOLS_DIR/toshy"
    fi

    if [[ -t 0 ]]; then
        log_info "Starting Toshy's installer; answer its questions, then log out and back in"
        (cd "$TOOLS_DIR/toshy" && ./setup_toshy.py install)
    else
        log_warn "Toshy needs a terminal to answer its questions: run ${TOOLS_DIR}/toshy/setup_toshy.py install"
    fi
}

# configuration is never part of the default stages. This extra clones a dotfiles repository and
# a set of config repositories, then links each Linux copy into place so an edit in a repository
# applies straight away. Anything already there that is not a link moves into the state folder's
# backups rather than being overwritten. The repositories default to the public ones this project
# was built alongside; point BOOTSTRAP_GITHUB_USER at your own account to use your forks
readonly CONFIG_BACKUP_DIR="${BOOTSTRAP_STATE_DIR}/backups"
readonly CONFIG_REPOS_DIR="${BOOTSTRAP_CONFIG_DIR:-${HOME}/.dotfiles}"
readonly CONFIG_GITHUB_USER="${BOOTSTRAP_GITHUB_USER:-zaccesss}"

# "repository|path inside it|where it is linked"
readonly CONFIG_LINKS=(
    "dotfiles|linux/starship.toml|${HOME}/.config/starship.toml"
    "tmux-config|tmux.conf|${HOME}/.tmux.conf"
    "neovim-config|nvim|${HOME}/.config/nvim"
    "git-hooks|linux|${HOME}/.git-hooks"
    "cli-tools-config|lazygit/config.yml|${HOME}/.config/lazygit/config.yml"
    "cli-tools-config|ripgrep/ripgreprc|${HOME}/.ripgreprc"
)

# desktop only: VS Code and the terminal run on the host for WSL and container-style machines. The
# Ptyxis palette is Ubuntu 25.10 and later's terminal; pick High Contrast in its preferences
readonly DESKTOP_CONFIG_LINKS=(
    "vscode-config|settings.json|${HOME}/.config/Code/User/settings.json"
    "vscode-config|keybindings/windows-linux.json|${HOME}/.config/Code/User/keybindings.json"
    "terminal-config|linux/ptyxis/high-contrast.palette|${HOME}/.local/share/org.gnome.Ptyxis/palettes/high-contrast.palette"
)

# these hold each person's own identity and hosts, so they are copied once as a starting point
# and never linked or overwritten
readonly CONFIG_TEMPLATES=(
    "git-config|linux/gitconfig|${HOME}/.gitconfig"
    "ssh-config|linux/config|${HOME}/.ssh/config"
)

get_config_repo() {
    local name="$1"
    local target="${CONFIG_REPOS_DIR}/${name}"

    if [[ ! -d "${target}/.git" ]]; then
        mkdir -p "$CONFIG_REPOS_DIR"
        git clone --depth 1 "https://github.com/${CONFIG_GITHUB_USER}/${name}.git" "$target"
    fi
    printf '%s\n' "$target"
}

link_config() {
    local source="$1"
    local target="$2"

    if [[ -L "$target" && "$(readlink "$target")" == "$source" ]]; then
        return 0
    fi
    if [[ -e "$target" && ! -L "$target" ]]; then
        mkdir -p "$CONFIG_BACKUP_DIR"
        mv "$target" "${CONFIG_BACKUP_DIR}/$(basename "$target")-$(date +%Y%m%d-%H%M%S)"
        log_warn "Moved the existing ${target} into ${CONFIG_BACKUP_DIR}"
    fi
    mkdir -p "$(dirname "$target")"
    ln -sfn "$source" "$target"
    log_success "Linked ${target}"
}

link_config_set() {
    local entry name inside target repo

    for entry in "$@"
    do
        IFS='|' read -r name inside target <<< "$entry"
        repo="$(get_config_repo "$name")"
        link_config "${repo}/${inside}" "$target"
    done
}

copy_config_templates() {
    local entry name inside target repo

    for entry in "${CONFIG_TEMPLATES[@]}"
    do
        IFS='|' read -r name inside target <<< "$entry"
        if [[ -e "$target" ]]; then
            log_info "Keeping your existing ${target}"
            continue
        fi
        repo="$(get_config_repo "$name")"
        mkdir -p "$(dirname "$target")"
        cp "${repo}/${inside}" "$target"
        log_warn "Copied a starting ${target}; edit it for your own name, email, keys and hosts"
    done
    chmod 700 "${HOME}/.ssh" 2>/dev/null || true
}

# the dotfiles' bashrc finds its topic files through DOTFILES, so ~/.bashrc is a small loader that
# sets it to wherever the repository was cloned, then hands over
write_bashrc_loader() {
    local dotfiles
    local loader
    dotfiles="$(get_config_repo dotfiles)"
    loader="export DOTFILES=\"${dotfiles}\"
source \"\${DOTFILES}/linux/bashrc\""

    if [[ -f "${HOME}/.bashrc" ]] && [[ "$(cat "${HOME}/.bashrc")" == "$loader" ]]; then
        return 0
    fi
    if [[ -e "${HOME}/.bashrc" ]]; then
        mkdir -p "$CONFIG_BACKUP_DIR"
        mv "${HOME}/.bashrc" "${CONFIG_BACKUP_DIR}/.bashrc-$(date +%Y%m%d-%H%M%S)"
        log_warn "Moved the existing ~/.bashrc into ${CONFIG_BACKUP_DIR}"
    fi
    printf '%s\n' "$loader" > "${HOME}/.bashrc"
    log_success "Wrote ~/.bashrc to load the dotfiles from ${dotfiles}"
}

optional_configs() {
    if ! external_installers_enabled; then
        log_info "Skipping the configs extra in test or simulate mode"
        return 0
    fi

    # the Git hooks hand off to Git LFS, so it must exist before they are linked or every clone and
    # checkout afterwards fails. The default stages install it, but this extra can run on its own
    apt_install git-lfs

    write_bashrc_loader
    link_config_set "${CONFIG_LINKS[@]}"
    copy_config_templates
    if desktop_steps_enabled; then
        link_config_set "${DESKTOP_CONFIG_LINKS[@]}"
    fi

    # tmux's plugins come from its own plugin manager, which the config expects in this folder
    # the plugin installer drives tmux itself, so it runs only once tmux is installed
    if [[ ! -d "${HOME}/.tmux/plugins/tpm" ]]; then
        git clone --depth 1 https://github.com/tmux-plugins/tpm "${HOME}/.tmux/plugins/tpm"
    fi
    if command -v tmux >/dev/null 2>&1; then
        "${HOME}/.tmux/plugins/tpm/bin/install_plugins" >/dev/null
    fi

    # GNOME desktop settings come from the system defaults repository
    if is_desktop; then
        bash "$(get_config_repo system-defaults)/linux/defaults.sh"
    fi

    log_info "Open a new terminal so the shell profile loads"
}

install_optional_tool() {
    local name="$1"
    local entry
    local scope

    entry="$(find_optional_entry "$name")"
    scope="$(optional_field "$entry" 3)"

    if [[ "$scope" == "desktop" ]] && ! desktop_steps_enabled; then
        log_warn "Skipping ${name}: it is a desktop app and this is a ${PLATFORM_ENV} environment"
        return 0
    fi

    log_info "Installing optional extra: ${name}"
    "optional_${name//-/_}"
    log_success "Optional extra installed: ${name}"
}

install_optional_tools() {
    local name

    for name in "$@"
    do
        install_optional_tool "$name"
    done
}
