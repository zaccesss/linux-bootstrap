# Dual boot: Ubuntu next to Windows

This guide installs Ubuntu 26.04 LTS next to an existing Windows 11 install on one laptop, so the
machine asks which system to start each time it boots. It was written for a Lenovo laptop. The
Lenovo-specific keys and settings are marked; everything else applies to any UEFI PC.

> [!CAUTION]
> Changing partitions can lose data if something goes wrong. Do not skip the backup and recovery
> key steps. Keep the laptop on mains power for the whole process.

## What you need

- A USB stick of 8 GB or more. It will be wiped.
- At least 100 GB of free space on the Windows drive (150 GB or more is comfortable).
- About an hour, with mains power connected.

## 1. Prepare Windows

1. **Back up** anything that is not already in OneDrive or another cloud service.
2. **Save the BitLocker recovery key.** Open <https://account.microsoft.com/devices/recoverykey> on
   another device. Alternatively run `manage-bde -protectors -get C:` in an administrator terminal
   and write the 48-digit key down somewhere off the laptop. Firmware changes can trigger a
   BitLocker prompt. Without this key the Windows drive cannot be unlocked.
3. **Suspend BitLocker** for the install: Settings, Privacy and security, Device encryption (or
   Control Panel, BitLocker Drive Encryption), then *Suspend protection*. It resumes on its own
   after a later restart.
4. **Turn off Fast Startup**: Control Panel, Power Options, *Choose what the power buttons do*,
   *Change settings that are currently unavailable*, untick *Turn on fast startup*. Fast Startup
   leaves the Windows drive half-locked, which stops Ubuntu reading it and can corrupt files.
5. **Check the firmware mode**: run `msinfo32` and confirm *BIOS Mode* says **UEFI**. Every recent
   Lenovo does. If it says Legacy, stop and get help before going further.

## 2. Make room for Ubuntu

1. Press `Win+X` and open **Disk Management**.
2. Right-click the `C:` partition, choose **Shrink Volume** and enter the space for Ubuntu in MB
   (153600 MB is 150 GB).
3. Leave the new space as **Unallocated**. Do not format it; the Ubuntu installer uses it.

## 3. Create the installer USB

1. Download the **Ubuntu 26.04 LTS Desktop** image (amd64) from <https://ubuntu.com/download/desktop>.
2. Write it to the USB stick with [Rufus](https://rufus.ie) (partition scheme **GPT**, target
   system **UEFI**) or [balenaEtcher](https://etcher.balena.io).

## 4. Boot from the USB

1. Shut the laptop down fully (Start, Power, Shut down).
2. **Lenovo:** press `F12` (or `Fn+F12`) straight after pressing the power button to open the boot
   menu. On IdeaPad and Yoga models with a pinhole **Novo** button, press it with a paperclip while
   the laptop is off and choose *Boot Menu*.
3. Choose the USB stick.

> [!IMPORTANT]
> **Lenovo Secured-core laptops** (2022 and later) block Ubuntu's signed bootloader by default and
> show a security violation instead of the installer. Enter the firmware setup with `F2` (or
> `Fn+F2`) and open **Security**, then **Secure Boot**. Switch on **Allow Microsoft 3rd Party UEFI
> CA** and leave Secure Boot itself switched on.

## 5. Install Ubuntu

1. Choose **Try or Install Ubuntu**, then **Install Ubuntu**.
2. Connect to Wi-Fi when asked and tick **Install third-party software** for graphics and Wi-Fi
   drivers.
3. At the disk step choose **Install Ubuntu alongside Windows Boot Manager**. If that option is
   missing, choose manual partitioning and select the unallocated space. Never select or format
   the existing Windows partitions.
4. Pick the username and computer name, finish the install and remove the USB when asked.

## 6. After the first boot

1. The **GRUB** menu now appears at every start: Ubuntu is the first entry and Windows Boot Manager
   starts Windows.
2. **Fix the clock.** Windows stores local time in the hardware clock and Ubuntu stores UTC, so
   each system moves the clock by an hour after the other runs. In Ubuntu run:

   ```bash
   timedatectl set-local-rtc 1 --adjust-system-clock
   ```

3. Start Windows once and confirm BitLocker is protecting the drive again.

## 7. Run the bootstrap

In Ubuntu, open a terminal and follow the [Quickstart](../README.md#quickstart). For the full
desktop setup:

```bash
./bootstrap/bootstrap.sh --with kicad,android
```

Log out and back in at the end so the docker and dialout group changes apply.
