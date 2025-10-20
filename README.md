# RK3318 TV Box -> Armbian Flash Guide

Quickly turn an RK3318/RK3328 TV box into a Linux mini PC. This guide collects the tools and commands tested while installing Armbian directly on the internal eMMC.

---

## Hardware & Prerequisites

- Box based on Rockchip SoC RK3318 / RK3328 with a USB OTG port.
- Straight USB-A ↔ USB-A cable and the box’s original power supply.
- PC running Debian/Ubuntu (we used Debian 13). All commands require `sudo`.
- Access to the reset button (often hidden in the AV jack) to enter MaskROM.

---

## File Checklist

| File | Suggested Path | Notes |
| --- | --- | --- |
| Armbian image | `Armbian_community_25.11.0-trunk.334_Rk3318-box_trixie_current_6.12.53_minimal.img.xz` | Download the latest community release from <https://github.com/armbian/community/releases>. |
| Rockchip loader | `rkbin/rk3328_loader_v1.21.250.bin` | Generated with `boot_merger` from the official `rockchip-linux/rkbin` repo. Other loaders (for example `rk3318_loader_v*.bin`) may be required for picky boxes. |
| Custom loader | `MiniLoaderAll.bin` | Copy of the loader that worked in the previous session. |
| rkdeveloptool (modified) | `rkdeveloptool-new` | Binary compiled from Rockchip sources with extra logs (`InitializeUsb: ...`). |
| Support script | `run_rk.sh` | Shortcut command to load the loader with sudo. |

---

## PC Setup (One-Time)

```bash
sudo apt update
sudo apt install build-essential cmake libusb-1.0-0-dev git xz-utils curl

# rkdeveloptool sources
git clone https://github.com/rockchip-linux/rkdeveloptool.git /tmp/rkdeveloptool-src
cd /tmp/rkdeveloptool-src
./autogen.sh
./configure
make -j"$(nproc)"
cp rkdeveloptool ~/rkdeveloptool-new

# rkbin repo (for official loaders)
git clone https://github.com/rockchip-linux/rkbin.git ~/rkbin
cd ~/rkbin
tools/boot_merger RKBOOT/RK3328MINIALL.ini   # generates rk3328_loader_v1.21.250.bin
```

Download and verify the Armbian image:

```bash
cd ~
wget https://github.com/armbian/community/releases/download/.../Armbian_...img.xz
wget https://github.com/armbian/community/releases/download/.../Armbian_...img.xz.sha
sha256sum -c Armbian_...img.xz.sha
xz -dk Armbian_...img.xz   # extract the ~1.5 GB .img
```

---

## Put the Box in MaskROM

1. Power off the box and connect the USB-A ↔ USB-A cable between the box’s OTG port and the PC.
2. Plug in the power supply while holding the reset button (inside the AV hole).
3. Release the reset after 3–4 s. Check from the PC:
   - `lsusb | grep 2207:320c` -> should show `RK3328 in Mask ROM mode`.
   - `rkdeveloptool ld` -> should print `Maskrom`.

If it does not appear:
- Try the other USB port on the box.
- Make sure you are using the PC’s direct USB 2.0 port.
- Repeat while holding the reset button longer.

---

## Flashing Procedure

> All commands from here on must run with elevated privileges. 

1. **Load the loader** (only if the device is in MaskROM):

   ```bash
   sudo /home/$USER/rkdeveloptool-new db /home/$USER/rkbin/rk3328_loader_v1.21.250.bin
   ```

   - Expected output: `Downloading bootloader...` -> return to prompt with `succeeded`.
   - If it hangs:
     - Check for a stuck process (`pgrep -fl rkdeveloptool`) and kill it (`sudo kill <PID>`).
     - Power the box with the original adapter in addition to USB.
     - Try an alternative loader (for example `MiniLoaderAll.bin` from the community).

2. **Verify the connection to the loader**:

   ```bash
   rkdeveloptool-new ld     # should now report “Loader”
   sudo rkdeveloptool-new rfi
   ```

   Typical output:

   ```
   Flash Info:
       Manufacturer: SAMSUNG, value=00
       Flash Size: 59640 MB
       ...
   ```

3. **Write the Armbian image to the eMMC**:

   ```bash
   sudo rkdeveloptool-new wl 0 /home/$USER/Armbian_community_...img
   ```

   Wait for “Write LBA from file (100%)”. Do not disconnect anything until the prompt returns.

4. **Reboot the box**:

   ```bash
   sudo rkdeveloptool-new rd
   ```

   Unplug and plug the power again; the box now boots Armbian from the eMMC.

---

## Armbian Post-Install

Run these steps at first login:

1. Create an unprivileged user and give it sudo:

   ```bash
   adduser <new_user>
   usermod -aG sudo <new_user>
   passwd -l root          # optional: lock root login
   ```

2. Configure the box:

   ```bash
   sudo rk3318-config      # select DTB, Wi-Fi/Bluetooth, LEDs
   sudo apt update && sudo apt upgrade
   ```

3. (Optional) Install a lightweight desktop environment:

   ```bash
   sudo apt install --no-install-recommends lxde-core xorg lightdm
   sudo systemctl enable lightdm
   sudo reboot
   ```

4. To use it as a wake-on-LAN gateway:

   ```bash
   sudo apt install tailscale etherwake
   sudo tailscale up            # authenticate from the browser
   sudo etherwake -i eth0 AA:BB:CC:DD:EE:FF
   ```

---

## Quick Troubleshooting

- **`Creating Comm Object failed` / `libusb_claim_interface failed: -6`**  
  -> Close the lingering `rkdeveloptool` process (`sudo kill <PID>`), reconnect the box in MaskROM, and try again.

- **`The device does not support this operation! (usbType=0x2, required mask=0x1)`**  
  -> The box is already in Loader mode (not MaskROM). Go straight to “Write image” or force MaskROM with reset + power.

- **`Downloading bootloader...` stuck**  
  -> Common issue with an incompatible loader or unstable power. Switch loaders (for example ones shared on the Armbian forum by *jock*), make sure both power and USB are connected, and verify the OTG cable.

- **libusb output `detach kernel driver result: -5`**  
  -> Just a warning (no driver to detach); you can ignore it.

---

## Things to Keep for Future Flashes

- Tested `rkdeveloptool-new` binary (with extra messages).
- Loaders that worked (`rk3328_loader_v1.21.250.bin`, `MiniLoaderAll.bin`, any modified versions).
- Scripts or notes on how to enter MaskROM for the various models.
- Post-install steps (user creation, `rk3318-config`, essential packages).
- Optional: backups of configured Armbian installations (with `rkdeveloptool rl` / `dd`) so they can be cloned quickly.

Happy hacking!
