# Linux on a Mac

Apple Silicon Macs cannot install Linux directly beside macOS (Asahi Linux covers older M-series
chips only), so Linux runs in a lightweight virtual machine. There are two good ways to do it.

## OrbStack (recommended)

[OrbStack](https://orbstack.dev) runs Linux machines and Docker with very little memory and disk.
Machines start in seconds, share the Mac's home folder and appear as `name.orb.local` on the
network. It replaces Docker Desktop too.

1. Install it with `brew install --cask orbstack`, then open OrbStack once to finish setup.
2. Create a machine from OrbStack's window or from a terminal:

   ```bash
   orb create ubuntu:resolute ubuntu
   ```

3. Open a shell in it with `orb` (or `ssh orb`) and follow the
   [Quickstart](../README.md#quickstart).

The machine counts as a server to the bootstrap, so desktop-only extras are skipped. GUI apps such
as KiCad and VS Code run better natively on macOS anyway.

> [!NOTE]
> An OrbStack machine has no desktop: it is a terminal, opened from OrbStack's Terminal tab, with
> `orb` or with `ssh orb`. For a graphical Ubuntu desktop see [UTM with a full desktop](#utm-with-a-full-desktop).

### Shell profile, Git and GitHub

After the bootstrap, `./bootstrap/bootstrap.sh --extras-only --with configs` links a shell profile and
tool configs into the machine (see the README's [Your own configuration](../README.md#your-own-configuration)).
Then set your Git identity in `~/.gitconfig` and sign in with `gh auth login --git-protocol ssh`.

OrbStack passes the Mac's SSH agent into the machine, so `ssh -T git@github.com` works straight
away with the keys already loaded on the Mac.

## UTM with a full desktop

For a complete Ubuntu desktop, use [UTM](https://mac.getutm.app) with **Apple Virtualization**
selected. QEMU emulation, the other choice, is much slower. Install Ubuntu 26.04 Desktop for ARM64,
then run the bootstrap with the Mac-style keys extra:

```bash
./bootstrap/bootstrap.sh --with mac-keys
```

This switches on natural scrolling and installs [Toshy](https://github.com/RedBearAK/toshy), which
makes `Cmd+C`, `Cmd+V`, `Cmd+Tab` and the other Mac shortcuts behave as they do on macOS. Toshy's
installer asks questions on purpose (including a code to type back), so stay at the keyboard while
it runs, then log out and back in.

> [!NOTE]
> A desktop VM keeps its whole disk in one large file on the Mac. Give it the smallest disk that
> fits the work and move it to an external SSD if space gets tight.
