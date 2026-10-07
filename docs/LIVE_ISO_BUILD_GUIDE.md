# Guide: Building a Remastered D330 Live ISO

Step-by-step instructions for producing a customized, out-of-the-box working Linux installer image for Lenovo IdeaPad D330-10IGL.

## Prerequisites
Install ISO remastering utilities on the host builder:
```bash
sudo apt update
sudo apt install -y xorriso squashfs-tools
```

## Step 1: Download Base Upstream ISO
Download your preferred distro ISO:
- Ubuntu 24.04 LTS Desktop (`ubuntu-24.04-desktop-amd64.iso`)
- Linux Mint LMDE 6 (`lmde-6-cinnamon-64bit.iso`)
- Linux Mint 22 (`linuxmint-22-cinnamon-64bit.iso`)

## Step 2: Run Remaster Harness
```bash
sudo scripts/build_live_iso.sh \
    --base-iso /path/to/base.iso \
    --output lenovo-d330-mint-remastered.iso
```

## Step 3: Write to USB Flash Drive
```bash
sudo dd if=lenovo-d330-mint-remastered.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

## Step 4: Boot on D330
Insert USB drive, hold `F12` on power-up to select USB boot:
- Bootloader will render in landscape.
- Touchscreen will track 1:1 with finger and Active Pen.
- Audio and Wi-Fi will operate immediately.
