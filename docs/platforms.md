# Platforms

## Supported releases and architectures

| | Ubuntu 24.04 LTS (noble) | Ubuntu 26.04 LTS (resolute) |
| --- | --- | --- |
| ARM64 | Supported | Supported |
| x86_64 | Supported | Supported |

Only long-term support releases are supported. Interim releases (25.04, 25.10) lose support after
nine months, too soon for a machine meant to last. To try another release anyway, set
`LINUX_BOOTSTRAP_ALLOW_UNSUPPORTED=1`; the bootstrap warns and carries on.

Debian, Fedora, Arch and other distributions are refused: package names and repositories differ
too much for one script to cover them well.

## Differences between the releases

The bootstrap installs the same tools on both releases. Where Ubuntu 24.04 does not package a
tool, it comes from the tool's official release instead:

| Tool | Ubuntu 24.04 | Ubuntu 26.04 |
| --- | --- | --- |
| Zig | Official release from ziglang.org into `~/.local/share/zig` | Ubuntu package |
| lazygit | GitHub release into `~/.local/bin` | Ubuntu package |
| starship | Official installer into `~/.local/bin` | Official installer into `~/.local/bin` (Ubuntu's package is too old for the shared prompt config) |
| wslu (WSL only) | Ubuntu package | Not packaged; set `BROWSER=explorer.exe` instead |

## Environments

The bootstrap works out where it is running before any stage starts:

| Environment | Detected by | What changes |
| --- | --- | --- |
| WSL | `microsoft` in `/proc/version` | systemd switched on in `/etc/wsl.conf`, wslu on 24.04, desktop-only extras skipped |
| Container | `/.dockerenv`, `/run/.containerenv` or `systemd-detect-virt --container` | Desktop-only extras skipped |
| Desktop | A graphical session or the `ubuntu-desktop-minimal` package | QEMU guest agent and SPICE clipboard helper inside QEMU or KVM VMs |
| Server | Anything else, including OrbStack machines | Desktop-only extras skipped |

## Vendor repositories

These tools are not in Ubuntu's archive, so their makers' own APT repositories are added, each
with its signing key in its own keyring under `/etc/apt/keyrings`:

| Repository | Packages |
| --- | --- |
| HashiCorp | terraform |
| Kubernetes (current stable minor version) | kubectl |
| GitHub CLI | gh |
| Aqua Security | trivy |
| Google Cloud (`gcloud` extra) | google-cloud-cli |
| Microsoft (`azure` extra) | azure-cli |
| Warp (`warp` extra) | warp-terminal |

The AWS CLI comes from AWS's own v2 installer, because Ubuntu either does not package it or ships
the retired v1.

## How support is checked

The CI **packages** job runs the whole bootstrap, every optional extra included, in clean Ubuntu
24.04 and 26.04 containers on both ARM64 and x86_64 runners. It adds the vendor repositories for
real and asks apt to resolve every package, so a package that is renamed or dropped on any
supported platform fails the pull request rather than a real install.
