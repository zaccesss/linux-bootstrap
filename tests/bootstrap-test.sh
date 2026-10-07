#!/usr/bin/env bash
#
# offline tests for the bootstrap. apt-get and sudo are replaced with stubs that log what they were
# asked to do. Platform detection is pointed at fixture files, so every supported and
# unsupported platform is exercised on one machine without installing anything. CI's package job
# covers the other half: that every package really exists on every release and architecture.

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly BOOTSTRAP="$REPO_ROOT/bootstrap/bootstrap.sh"
WORK_DIR="$(mktemp -d)"
readonly WORK_DIR
trap 'rm -rf "$WORK_DIR"' EXIT

TESTS_RUN=0

pass() {
    TESTS_RUN=$((TESTS_RUN + 1))
    printf 'ok %d - %s\n' "$TESTS_RUN" "$1"
}

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

assert_file() {
    [[ -f "$1" ]] || fail "missing file: $1"
}

assert_executable() {
    [[ -x "$1" ]] || fail "not executable: $1"
}

assert_contains() {
    local expected="$1"
    local actual="$2"
    local label="${3:-output}"

    [[ "$actual" == *"$expected"* ]] || fail "${label} should contain: ${expected}"
}

assert_not_contains() {
    local unexpected="$1"
    local actual="$2"
    local label="${3:-output}"

    [[ "$actual" != *"$unexpected"* ]] || fail "${label} should not contain: ${unexpected}"
}

# ---------------------------------------------------------------------------------------------
# stubs and fixtures
# ---------------------------------------------------------------------------------------------

STUB_DIR="$WORK_DIR/bin"
mkdir -p "$STUB_DIR"

# sudo runs the command as the current user; apt-get only records its arguments
cat > "$STUB_DIR/sudo" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-n" ]]; then shift; fi
exec "$@"
EOF
cat > "$STUB_DIR/apt-get" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$BOOTSTRAP_TEST_APT_LOG"
EOF
chmod +x "$STUB_DIR/sudo" "$STUB_DIR/apt-get"

write_os_release() {
    local path="$1" id="$2" version="$3" codename="$4"
    printf 'ID=%s\nVERSION_ID="%s"\nVERSION_CODENAME=%s\n' "$id" "$version" "$codename" > "$path"
}

write_os_release "$WORK_DIR/noble" ubuntu 24.04 noble
write_os_release "$WORK_DIR/resolute" ubuntu 26.04 resolute
write_os_release "$WORK_DIR/jammy" ubuntu 22.04 jammy
write_os_release "$WORK_DIR/debian" debian 13 trixie

# one log for every run: run_bootstrap is usually called inside $( ), so a path chosen inside it
# would be lost in the subshell. Each run empties the file first
readonly APT_LOG="$WORK_DIR/apt.log"

# runs the bootstrap in test mode on a chosen platform, recording apt calls in $APT_LOG
#   $1 os-release fixture  $2 architecture  $3 environment  $@ bootstrap arguments
run_bootstrap() {
    local release="$1" arch="$2" env="$3"
    shift 3

    : > "$APT_LOG"

    PATH="$STUB_DIR:$PATH" \
    HOME="$WORK_DIR/home" \
    BOOTSTRAP_TEST_APT_LOG="$APT_LOG" \
    LINUX_BOOTSTRAP_TEST_MODE=1 \
    LINUX_BOOTSTRAP_OS_RELEASE="$release" \
    LINUX_BOOTSTRAP_ARCH="$arch" \
    LINUX_BOOTSTRAP_ENV="$env" \
    LINUX_BOOTSTRAP_VIRT="${LINUX_BOOTSTRAP_VIRT:-none}" \
    LINUX_BOOTSTRAP_WSL_CONF="$WORK_DIR/wsl.conf" \
        "$BOOTSTRAP" "$@"
}

mkdir -p "$WORK_DIR/home"

# ---------------------------------------------------------------------------------------------
# structure
# ---------------------------------------------------------------------------------------------

assert_executable "$BOOTSTRAP"
for lib in logging common platform packages toolchains embedded cloud cli devtools integration environment optional; do
    assert_file "$REPO_ROOT/bootstrap/lib/${lib}.sh"
done
for stage in 00-base 10-language-toolchains 20-embedded-tooling 30-cloud-devops 40-cli-productivity \
    45-developer-tools 50-git-integration 60-environment; do
    assert_executable "$REPO_ROOT/bootstrap/stages/${stage}.sh"
done
pass "every library and stage is present and every stage is executable"

# ---------------------------------------------------------------------------------------------
# arguments
# ---------------------------------------------------------------------------------------------

help_output="$("$BOOTSTRAP" --help)"
assert_contains "--with a,b,c" "$help_output" "--help"
pass "--help describes the options"

list_output="$("$BOOTSTRAP" --list)"
for extra in warp blender kicad stm32 android gcloud azure flutter ardupilot powershell vercel \
    extra-languages gamedev chinese-input configs mac-keys; do
    assert_contains "  ${extra} " "$list_output" "--list"
done
pass "--list names every optional extra"

if run_bootstrap "$WORK_DIR/noble" arm64 server --with not-a-real-extra >/dev/null 2>&1; then
    fail "an unknown extra should stop the run"
fi
pass "an unknown extra stops the run before any stage"

if run_bootstrap "$WORK_DIR/noble" arm64 server --extras-only >/dev/null 2>&1; then
    fail "--extras-only without --with should fail"
fi
pass "--extras-only needs --with"

# ---------------------------------------------------------------------------------------------
# platform detection
# ---------------------------------------------------------------------------------------------

for unsupported in jammy debian; do
    if run_bootstrap "$WORK_DIR/$unsupported" arm64 server >/dev/null 2>&1; then
        fail "${unsupported} should be refused"
    fi
done
pass "Ubuntu 22.04 and Debian are refused"

if run_bootstrap "$WORK_DIR/noble" riscv64 server >/dev/null 2>&1; then
    fail "riscv64 should be refused"
fi
pass "unsupported architectures are refused"

output="$(LINUX_BOOTSTRAP_ALLOW_UNSUPPORTED=1 run_bootstrap "$WORK_DIR/jammy" amd64 server 2>&1)"
assert_contains "not a supported release" "$output"
pass "LINUX_BOOTSTRAP_ALLOW_UNSUPPORTED lets an unlisted release continue with a warning"

# ---------------------------------------------------------------------------------------------
# full default runs on each release and architecture
# ---------------------------------------------------------------------------------------------

output="$(run_bootstrap "$WORK_DIR/noble" amd64 server)"
apt_log="$(cat "$APT_LOG")"
assert_contains "Platform detected: Ubuntu 24.04 (noble) amd64, server" "$output"
assert_contains "Linux Bootstrap foundation completed" "$output"
for stage in base language-toolchains embedded-tooling cloud-devops cli-productivity developer-tools \
    git-integration environment; do
    assert_contains "Completed stage: ${stage}" "$output"
done
for package in build-essential python3-venv clang openjdk-25-jdk dotnet-sdk-10.0 rustup gcc-avr \
    gcc-arm-none-eabi terraform kubectl docker-compose-v2 neovim git-delta ripgrep trivy gh; do
    assert_contains " ${package}" "$apt_log" "24.04 apt log"
done
assert_not_contains " zig" "$apt_log" "24.04 apt log"
assert_not_contains " lazygit" "$apt_log" "24.04 apt log"
assert_not_contains " starship" "$apt_log" "24.04 apt log"
pass "24.04 x86_64 installs every default stage and leaves zig, lazygit and starship to their installers"

output="$(run_bootstrap "$WORK_DIR/resolute" arm64 server)"
apt_log="$(cat "$APT_LOG")"
assert_contains "Platform detected: Ubuntu 26.04 (resolute) arm64, server" "$output"
for package in zig lazygit; do
    assert_contains " ${package}" "$apt_log" "26.04 apt log"
done
assert_not_contains " starship" "$apt_log" "26.04 apt log"
pass "26.04 ARM64 installs zig and lazygit from Ubuntu's archive and leaves starship to its installer"

output="$(run_bootstrap "$WORK_DIR/resolute" arm64 server)"
assert_contains "Linux Bootstrap foundation completed" "$output"
pass "a second run on the same machine succeeds"

[[ -f "$WORK_DIR/home/.local/state/linux-bootstrap/stages.log" ]] || fail "stages.log was not written"
pass "completed stages are recorded in the state directory"

# ---------------------------------------------------------------------------------------------
# environments
# ---------------------------------------------------------------------------------------------

: > "$WORK_DIR/wsl.conf"
output="$(run_bootstrap "$WORK_DIR/noble" amd64 wsl 2>&1)"
apt_log="$(cat "$APT_LOG")"
assert_contains " wslu" "$apt_log" "WSL apt log"
assert_contains "systemd=true" "$(cat "$WORK_DIR/wsl.conf")" "wsl.conf"
assert_contains "wsl --shutdown" "$output"
pass "WSL on 24.04 gets wslu and systemd switched on in wsl.conf"

output="$(run_bootstrap "$WORK_DIR/noble" amd64 wsl 2>&1)"
[[ "$(grep -c 'systemd=true' "$WORK_DIR/wsl.conf")" -eq 1 ]] || fail "systemd=true was added twice"
pass "a second WSL run leaves wsl.conf as it is"

output="$(run_bootstrap "$WORK_DIR/resolute" amd64 wsl 2>&1)"
apt_log="$(cat "$APT_LOG")"
assert_not_contains " wslu" "$apt_log" "26.04 WSL apt log"
assert_contains "BROWSER=explorer.exe" "$output"
pass "WSL on 26.04 explains the browser fallback instead of installing wslu"

output="$(LINUX_BOOTSTRAP_VIRT=qemu run_bootstrap "$WORK_DIR/resolute" arm64 desktop 2>&1)"
apt_log="$(cat "$APT_LOG")"
assert_contains " spice-vdagent" "$apt_log" "QEMU desktop apt log"
assert_contains " qemu-guest-agent" "$apt_log" "QEMU desktop apt log"
pass "a desktop VM on QEMU gets the guest agent and clipboard helper"

# ---------------------------------------------------------------------------------------------
# optional extras
# ---------------------------------------------------------------------------------------------

output="$(run_bootstrap "$WORK_DIR/noble" arm64 server --extras-only --with stm32,extra-languages,gamedev,android 2>&1)"
apt_log="$(cat "$APT_LOG")"
assert_not_contains "Completed stage: base" "$output"
for package in stlink-tools racket sbcl r-base gnat libsdl2-dev libsfml-dev adb fastboot; do
    assert_contains " ${package}" "$apt_log" "extras apt log"
done
pass "--extras-only installs just the chosen extras"

output="$(run_bootstrap "$WORK_DIR/noble" arm64 server --extras-only --with kicad,blender 2>&1)"
apt_log="$(cat "$APT_LOG")"
assert_contains "Skipping kicad" "$output"
assert_not_contains " kicad" "$apt_log" "server apt log"
pass "desktop-only extras are skipped on a server"

output="$(run_bootstrap "$WORK_DIR/noble" arm64 desktop --extras-only --with kicad 2>&1)"
assert_contains " kicad" "$(cat "$APT_LOG")" "desktop apt log"
pass "desktop-only extras install on a desktop"

# ---------------------------------------------------------------------------------------------
# library functions run directly
# ---------------------------------------------------------------------------------------------

(
    # shellcheck source=bootstrap/lib/logging.sh
    source "$REPO_ROOT/bootstrap/lib/logging.sh"
    # shellcheck source=bootstrap/lib/common.sh
    source "$REPO_ROOT/bootstrap/lib/common.sh"
    # shellcheck source=bootstrap/lib/platform.sh
    source "$REPO_ROOT/bootstrap/lib/platform.sh"
    # shellcheck source=bootstrap/lib/optional.sh
    source "$REPO_ROOT/bootstrap/lib/optional.sh"

    # an installer that does not know the release gets it added next to the newest one it lists
    installer="$WORK_DIR/install-prereqs-ubuntu.sh"
    cat > "$installer" <<'EOF'
        SITL_PKGS+=" python3-argparse"
     [ ${RELEASE_CODENAME} == 'questing' ] ||
     false; then
EOF
    PLATFORM_CODENAME=resolute
    patch_ardupilot_installer "$installer" 2>/dev/null
    grep -q "'resolute'" "$installer" || fail "the ArduPilot installer was not patched for resolute"
    grep -q 'libpython3-stdlib' "$installer" || fail "python3-argparse was not replaced"
    patched="$(cat "$installer")"
    patch_ardupilot_installer "$installer" 2>/dev/null
    [[ "$(cat "$installer")" == "$patched" ]] || fail "patching twice changed the installer again"
)
pass "the ArduPilot installer patch adds an unknown release once"

# every stage's final check runs against stub commands named from its declared list, so a
# misspelt or missing entry fails here without installing anything
VERIFY_DIR="$WORK_DIR/verify"
mkdir -p "$VERIFY_DIR"
(
    # shellcheck source=bootstrap/lib/logging.sh
    source "$REPO_ROOT/bootstrap/lib/logging.sh"
    # shellcheck source=bootstrap/lib/common.sh
    source "$REPO_ROOT/bootstrap/lib/common.sh"
    for lib in toolchains embedded cloud cli devtools integration; do
        # shellcheck source=/dev/null
        source "$REPO_ROOT/bootstrap/lib/${lib}.sh"
    done

    all_commands=("${LANGUAGE_COMMANDS[@]}" "${EMBEDDED_COMMANDS[@]}" "${CLOUD_COMMANDS[@]}" \
        "${CLI_COMMANDS[@]}" "${DEVTOOLS_COMMANDS[@]}" "${INTEGRATION_COMMANDS[@]}")

    for command_name in "${all_commands[@]}"; do
        # an absolute shell path, because PATH holds only these stubs while the checks run
        printf '#!/bin/sh\nexit 0\n' > "$VERIFY_DIR/$command_name"
        chmod +x "$VERIFY_DIR/$command_name"
    done

    PATH="$VERIFY_DIR" verify_language_toolchains >/dev/null
    PATH="$VERIFY_DIR" verify_embedded_tooling >/dev/null
    PATH="$VERIFY_DIR" verify_cloud_tooling >/dev/null
    PATH="$VERIFY_DIR" verify_cli_tooling >/dev/null
    PATH="$VERIFY_DIR" verify_devtools >/dev/null
    HOME="$WORK_DIR/home" PATH="$VERIFY_DIR" verify_git_integration >/dev/null

    # a check that passes with a command missing would make the run above meaningless
    rm "$VERIFY_DIR/eza"
    if PATH="$VERIFY_DIR" verify_cli_tooling 2>/dev/null; then
        fail "verify_cli_tooling passed with eza missing"
    fi
)
pass "every final command check passes with its commands present and fails with one missing"

printf '\nAll %d bootstrap tests passed.\n' "$TESTS_RUN"
