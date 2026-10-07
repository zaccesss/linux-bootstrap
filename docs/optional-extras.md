# Optional extras

Extras are tools that are useful on some machines but not worth installing everywhere. None of them
install by default. Pick them with `--with`:

```bash
./bootstrap/bootstrap.sh --with kicad,android               # with the default stages
./bootstrap/bootstrap.sh --extras-only --with flutter       # just the extras, on a machine already set up
./bootstrap/bootstrap.sh --list                             # every extra with a short description
```

Desktop-only extras are skipped with a warning on WSL, servers and containers.

| Extra | What it installs | Where |
| --- | --- | --- |
| `warp` | Warp terminal from Warp's APT repository | Desktop |
| `blender` | Blender | Desktop |
| `kicad` | KiCad PCB and schematic design | Desktop |
| `stm32` | `stlink-tools` for flashing and debugging STM32 boards. STM32CubeIDE and STM32CubeProgrammer need an ST account, so they are downloaded by hand from st.com | Any |
| `android` | `adb` and `fastboot` | Any |
| `gcloud` | Google Cloud CLI from Google's APT repository | Any |
| `azure` | Azure CLI from Microsoft's APT repository | Any |
| `flutter` | The Flutter SDK in `~/dev/tools/flutter` plus its Linux desktop build dependencies | Any |
| `ardupilot` | ArduPilot in `~/dev/tools/ardupilot` with its SITL simulator prerequisites | Any |
| `powershell` | PowerShell 7 (`pwsh`) from the official release | Any |
| `vercel` | The Vercel CLI through npm | Any |
| `extra-languages` | Racket, SBCL (Common Lisp), R and Ada (GNAT with gprbuild) | Any |
| `gamedev` | SDL2 and SFML development libraries | Any |
| `configs` | A shell profile, prompt and tool configs (tmux, Neovim, Git hooks, lazygit, ripgrep, plus VS Code and GNOME settings on a desktop) from public repositories, linked into place. Starting `~/.gitconfig` and `~/.ssh/config` files are copied if missing | Any |
| `chinese-input` | Pinyin and Cangjie input methods for IBus | Desktop |
| `mac-keys` | Natural scrolling and Toshy for Mac-style shortcuts in a VM on a Mac | Desktop |

## Notes on individual extras

- **configs:** repositories clone into `~/.dotfiles` (`BOOTSTRAP_CONFIG_DIR` changes it) from the GitHub user in `BOOTSTRAP_GITHUB_USER`, so pointing it at your own account uses your forks. Each file is linked rather than copied. Anything already there that is not a link moves into `~/.local/state/linux-bootstrap/backups`.
- **ardupilot:** ArduPilot's installer checks the Ubuntu codename. On a release it does not know
  yet, the bootstrap patches a local copy to treat it like the newest one it lists. ArduPilot also
  builds natively on macOS and runs under WSL2, so a Linux machine is not required for it.
- **flutter:** after installing, add `~/dev/tools/flutter/bin` to `PATH` and run `flutter doctor`.
- **mac-keys:** Toshy's installer asks questions on purpose, including a code to type back. Run it
  at the keyboard, then log out and back in. See [Linux on a Mac](linux-on-mac.md).

## Adding an extra

1. Add a line to `OPTIONAL_TOOLS` in `bootstrap/lib/optional.sh` with the name, a description and
   the scope (`any` or `desktop`).
2. Add an `optional_<name>` function (hyphens become underscores) that installs it. Use
   `apt_install` and `add_apt_repository_with_key` so simulate and test modes work. Skip downloads
   when `external_installers_enabled` is false.
3. Add it to the table above and to the `--list` assertion in `tests/bootstrap-test.sh`.

The CI packages job installs every extra in simulate mode, so a misspelt package fails there.
