# WSL2: Ubuntu on Windows

WSL2 runs a real Ubuntu kernel inside Windows, with near-native speed and the Windows files and
GPU available. It suits a Windows PC that also needs Linux tools without rebooting into another
system.

## 1. Install WSL and Ubuntu

1. Open **Terminal** as administrator (right-click Start, *Terminal (Admin)*).
2. See which Ubuntu releases are offered:

   ```powershell
   wsl --list --online
   ```

3. Install Ubuntu 26.04 LTS (use `Ubuntu-24.04` instead if 26.04 is not listed yet):

   ```powershell
   wsl --install -d Ubuntu-26.04
   ```

4. Restart if Windows asks, then open **Ubuntu** from the Start menu and choose a username and
   password. The password is what `sudo` asks for later.
5. Keep WSL itself current from time to time:

   ```powershell
   wsl --update
   ```

## 2. Run the bootstrap

Inside Ubuntu, follow the [Quickstart](../README.md#quickstart). The bootstrap recognises WSL and:

- switches on **systemd** in `/etc/wsl.conf`, which Docker and user services need
- installs `wslu` on 24.04 so links open in the Windows browser (on 26.04 it explains the
  `BROWSER=explorer.exe` setting instead)
- skips desktop-only extras such as KiCad and Blender, which belong on Windows itself

When it finishes, restart WSL so systemd starts. In PowerShell:

```powershell
wsl --shutdown
```

Then open Ubuntu again.

## 3. Everyday tips

> [!TIP]
> Keep code inside Ubuntu (for example `~/dev`), not under `/mnt/c`. Files on the Windows drive
> are reached through a translation layer and builds there run many times slower.

- **VS Code:** install the *WSL* extension in Windows, then run `code .` in an Ubuntu folder.
- **Docker:** the bootstrap installs Docker inside Ubuntu. Docker Desktop for Windows is not needed;
  running both leads to two separate sets of containers.
- **NVIDIA GPU:** CUDA works through the normal Windows driver. Do not install an NVIDIA driver
  inside Ubuntu.
- **Memory limit:** WSL takes up to half the PC's memory. To cap it, create
  `%UserProfile%\.wslconfig` in Windows with:

  ```ini
  [wsl2]
  memory=8GB
  ```

  and run `wsl --shutdown` for it to apply.
