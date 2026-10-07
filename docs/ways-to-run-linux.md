# Ways to run Linux

There are four ways Ubuntu runs on the machines this bootstrap targets. The bootstrap is the same in
all of them; what differs is how much of a computer you get and what it costs in disk and speed.

| Way | Machine | What you get | Disk | Guide |
| --- | --- | --- | --- | --- |
| Dual boot | A PC or laptop | The whole machine runs Ubuntu: full desktop, full speed, all hardware | A partition, usually 100 to 150 GB | [Dual boot](dual-boot.md) |
| WSL2 | A Windows PC | A real Ubuntu terminal inside Windows, no reboot | Grows as used, typically 5 to 20 GB | [WSL2](wsl2.md) |
| OrbStack machine | A Mac | A fast Ubuntu terminal that shares the Mac's files | Grows as used, typically 3 to 10 GB | [Linux on a Mac](linux-on-mac.md) |
| UTM desktop VM | A Mac | A complete Ubuntu desktop in a window | A fixed disk image, usually 40 to 80 GB | [Linux on a Mac](linux-on-mac.md#utm-with-a-full-desktop) |

## Which one to use

- **Dual boot** when a project needs real Linux on real hardware: USB devices, GPU drivers, a full
  desktop for hours at a time or performance measurements.
- **WSL2** on a Windows PC for anything terminal-based. Windows apps (VS Code, browsers, KiCad) stay
  on Windows and reach into Ubuntu.
- **OrbStack** on a Mac for anything terminal-based: Linux-only build tools, servers, containers and
  testing that a script really works on Ubuntu. It is the lightest of the four.
- **UTM** on a Mac only when a graphical Linux app is needed and dual boot is not possible. It costs
  the most disk and runs hotter than the others.

## Desktop virtual machines on each host

When a full Linux desktop is needed without dual booting, a virtual machine app runs it in a window.
On Apple Silicon every option runs ARM64 Ubuntu at close to native speed; none of them run x86
Linux quickly, so always pick the ARM64 image there.

| Host | App | Cost | Notes |
| --- | --- | --- | --- |
| Mac | [Parallels Desktop](https://www.parallels.com) | Paid subscription | The smoothest: fastest, best graphics and clipboard, one-click Ubuntu install. Also the best way to run Windows 11 on a Mac |
| Mac | [VMware Fusion Pro](https://www.vmware.com/products/desktop-hypervisor/workstation-and-fusion) | Free for personal use | Close to Parallels for Linux, less polished. Downloaded through a Broadcom account |
| Mac | [UTM](https://mac.getutm.app) | Free and open source | Good with **Apple Virtualization** selected; QEMU mode is much slower. Weaker graphics and USB passthrough |
| Windows | Hyper-V | Built into Windows Pro and Education | Quick Create offers Ubuntu directly. Shares the hypervisor WSL2 already uses |
| Windows | [VMware Workstation Pro](https://www.vmware.com/products/desktop-hypervisor/workstation-and-fusion) | Free for personal use | Best general desktop VM on Windows, with good USB support |
| Windows | [VirtualBox](https://www.virtualbox.org) | Free and open source | Works everywhere but slower than the others, especially graphics |
| Linux | [GNOME Boxes](https://apps.gnome.org/Boxes/) or virt-manager | Free and open source | KVM, the kernel's own hypervisor, so close to native speed |

For terminal-only Linux there are lighter options than a desktop VM. On a Mac that means OrbStack
or [Multipass](https://canonical.com/multipass), Canonical's own free Ubuntu VMs (also available on
Windows). On Windows it means WSL2.

> [!TIP]
> On a Mac, VMware Fusion Pro is the best free desktop option and Parallels Desktop the best
> overall. Either beats UTM for a daily Ubuntu desktop.

## How the terminal-only ways work

WSL2 and OrbStack machines have no desktop, login screen or Linux app windows. They are a Linux
system you reach through a terminal, sharing the host's network and files.

- **Opening one:** on a Mac, `orb` (or `orb -m <machine>`) in any terminal, OrbStack's Terminal
  tab or `ssh orb`. On Windows, *Ubuntu* in the Start menu or `wsl` in a terminal.
- **Editing code:** the editor stays on the host. VS Code's *WSL* extension (Windows) or *Remote SSH*
  extension with the host `orb` (Mac) opens folders inside Linux in a normal VS Code window.
- **GUI apps:** use the host's own versions. On Windows, WSLg can also show Linux GUI apps in
  Windows windows when needed.

## Files: one copy, two views

An OrbStack machine sees the Mac's home folder under `/Users/<mac user>`. Linking a folder of
repositories inside Linux to the same folder on the Mac means:

- every repository exists once on the Mac's disk and takes **no extra space** in Linux
- a change made on either side is instantly visible on the other, because it is the same file
- the Linux shell profile, tmux, Neovim and Git hooks are read from the same checkouts the Mac uses

Builds that write lots of small files (`node_modules`, Rust `target`, Python virtual environments)
are faster in a folder that lives inside Linux, such as `~/work`. Clone there when speed matters
and the project is only ever built in Linux.

WSL2 works the other way round: Windows drives appear under `/mnt/c`, but code belongs inside
Ubuntu (`~/dev`) because builds on `/mnt/c` are many times slower. Windows reaches Ubuntu's files at
`\\wsl$\Ubuntu`.

## Docker

| Host | Where containers run |
| --- | --- |
| Mac with OrbStack | OrbStack's own Docker engine. The `docker` command on the Mac and inside the machine use it; Docker Desktop is not needed |
| Windows with WSL2 | Docker installed inside Ubuntu by this bootstrap. Docker Desktop is not needed and running both creates two separate sets of containers |
| Dual boot | Docker installed by this bootstrap, like any Ubuntu machine |

## After the bootstrap

The bootstrap installs tools but never personal configuration. Each machine then links the
dotfiles and config repositories, signs in to GitHub and sets the Git identity. The exact steps for
an OrbStack machine are in [Linux on a Mac](linux-on-mac.md#shell-profile-git-and-github). The same
steps apply in WSL2 and on a dual-boot install, with SSH keys created on that machine instead of
borrowed from the Mac.
