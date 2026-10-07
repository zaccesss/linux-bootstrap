# Bootstrap

`bootstrap.sh` checks the platform, asks for the sudo password once, then runs each stage in
order. Every stage can be re-run safely: apt skips installed packages and each installer looks for
an existing copy first.

## Layout

| Path | Contents |
| --- | --- |
| `bootstrap.sh` | Entry point and option parsing (`--with`, `--extras-only`, `--list`, `--help`) |
| `lib/logging.sh` | `[INFO]`, `[ OK ]`, `[WARN]` and `[ERROR]` output and the error handler |
| `lib/common.sh` | Run modes, `as_root`, apt wrappers, vendor repositories, downloads and command checks |
| `lib/platform.sh` | Release, architecture, environment and virtualisation detection |
| `lib/*.sh` | One file per stage with its package list, installers and final command check |
| `lib/optional.sh` | The registry of optional extras and their installers |
| `stages/` | One small script per stage, run in numeric order |

## Stages

| Order | Stage | What it does |
| --- | --- | --- |
| 00 | Base | Build tools, Python with venv and pipx, Git, archive tools, gpg and the headers that pip, gem and cargo builds commonly need |
| 10 | Language toolchains | Ubuntu packages for C, C++, the JVM languages, .NET, Go, Haskell, Elixir, Ruby, PHP and Lua. Node.js through nvm, Rust through rustup, Swift through swiftly and Zig from ziglang.org on 24.04 |
| 20 | Embedded tooling | ARM Cortex-M and AVR toolchains, OpenOCD, HDL tools and serial consoles. PlatformIO and Arduino CLI in the user's home. Adds the user to `dialout` for serial ports |
| 30 | Cloud and DevOps | Docker and Compose, Ansible, Terraform and kubectl from their vendors' repositories and AWS CLI v2. Adds the user to `docker` |
| 40 | CLI productivity | zsh, Neovim, tmux, the modern replacements for ls, cat, find and grep, git helpers and media converters |
| 45 | Developer tools | PDF and image utilities, psql, starship, uv and ruff, typst, lychee and trivy |
| 50 | Git integration | GitHub CLI from GitHub's repository, safe Git defaults and `~/.ssh` with 700 permissions |
| 60 | Environment | WSL systemd and browser support. Guest integration for QEMU desktop VMs |

After the stages, any extras named with `--with` are installed. See
[docs/optional-extras.md](../docs/optional-extras.md).

## What the bootstrap never does

- It never creates SSH keys, signs in to GitHub or sets the Git identity. `gh auth login` and the
  dotfiles handle those.
- It never edits shell profiles. Installers that offer to (nvm, uv, starship) are told not to, so
  the dotfiles stay the single owner of `PATH` and aliases.
- It never removes packages.

## Run modes

| Mode | Set with | Behaviour |
| --- | --- | --- |
| Normal | Nothing | Installs everything for real |
| Simulate | `LINUX_BOOTSTRAP_SIMULATE=1` | Adds vendor repositories for real, resolves every package without installing and skips external installers. CI uses it in clean containers |
| Test | `LINUX_BOOTSTRAP_TEST_MODE=1` | apt-get and sudo are stubs from the test suite. Nothing touches the network or the machine |

## Command checks

Each stage that installs tools ends by checking that its commands are on `PATH`, naming every
missing one before it fails. The commands are declared once per stage as a readonly array next to
its package list (`LANGUAGE_COMMANDS`, `EMBEDDED_COMMANDS`, `CLOUD_COMMANDS`, `CLI_COMMANDS`,
`DEVTOOLS_COMMANDS` and `INTEGRATION_COMMANDS`). The test suite runs every check against stub
commands built from those arrays.

## State

Each completed stage is appended with a timestamp to `~/.local/state/linux-bootstrap/stages.log`.
