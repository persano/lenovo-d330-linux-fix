# PROJECT: Lenovo IdeaPad D330-10IGL Linux Parity Project

## Target Platform
- **Device**: Lenovo IdeaPad D330-10IGL (Type 82H0) & D330-10IGM (81H3, 81MD)
- **SoC**: Intel Gemini Lake Refresh (Celeron N4020 / N4120)
- **GPU**: Intel UHD Graphics 600 (GLK 12 EU)
- **Panel**: 10.1" 1280x800 / 1920x1200 MIPI-DSI / eDP tablet panel (portrait native orientation)
- **Digitizer**: Goodix I2C Touchscreen (`GDIX1001`) with Lenovo Active Pen support
- **Sensors**: BOSC0200 accelerometer / IIO sensor subsystem, Hall effect dock sensor (`INT33D5`)
- **Target OS**: Linux (Kernel 5.15 – 6.x+, ChromeOS, Android-x86)

## Shipped Milestones
- **Milestone 1: Display & Power Parity (v1.0)**: PPS $\ge 600\text{ms}$ TCON discharge clamp, DRM DMI orientation quirks, standalone DKMS module, ChromeOS & Android-x86 patches.
- **Milestone 2: Peripheral Parity & Tablet Usability (v2.0)**: Goodix I2C touchscreen libinput matrix & post-wake reset hook, Active Pen stylus profiles, detachable dock mode daemon (`tools/d330-tablet-daemon.py`), ALSA UCM2 audio profiles, 6W fanless Intel P-State/EPP governors.

## Active Roadmap: Future Milestones

### Milestone 3: Vision, Ergonomics & Multimedia (v3.0) - [ACTIVE]
1. **Phase 10: Intel IPU3 Dual Camera Pipeline**: Front 2MP + Rear 5MP camera support (`INT3472` discrete regulator, `libcamera` IPU3 IPA software 3A tuning, `v4l2loopback` virtual webcam bridge for browser/Zoom compatibility).
2. **Phase 11: 4GB RAM & 64GB eMMC Storage Optimization**: ZRAM swap with `zstd` compression, Linux VM dirty page writeback tuning, eMMC I/O scheduling to prevent flash wear and eliminate browser freeze.
3. **Phase 12: Audio Refinements (Dolby DSP Curve & Anti-Pop Jack Delay)**: PipeWire filter-chain equalizer tailored for 1W tablet speakers, ALSA DAC power ramp delay eliminating headphone pop.
4. **Phase 13: Lenovo Hardware Controls (`ideapad_laptop` VPC2004)**: Battery Conservation Mode (60% charge threshold), Fn-Lock toggle, dock base USB 2.0 power management, CLI utility `tools/d330-ctl`.
5. **Phase 14: Display Ergonomics (Backlight PWM Anti-Flicker & ICC Profile)**: 1000 Hz PWM backlight frequency scaling, calibrated sRGB D65 ICC color profile, Intel seamless DRRS 48Hz/60Hz.

### Milestone 4: Connectivity, Firmware & System Boot (v4.0)
1. **Phase 15: Early Plymouth Boot Splash & GRUB Orientation**: Native landscape console (`fbcon=rotate:1`), Plymouth initramfs rotation filter, touch-scaled GRUB bootloader.
2. **Phase 16: ACPI DSDT Clean Initrd Override**: Early cpio archive (`/boot/acpi-override.cpio`) resolving BIOS SSDT namespace duplicates on `\_SB.PCI0.RP04` (`AE_ALREADY_EXISTS`).
3. **Phase 17: Sensor Hysteresis & Ambient Light Sensor (ALS)**: Auto-rotation debounce window to prevent table jitter, ALS auto-dimming filter via `iio-sensor-proxy`.
4. **Phase 18: MicroSD Storage Expansion & Optional Cellular LTE**: Automated MicroSD `/home` GPT setup helper (`tools/d330-microsd-setup.sh`), modular auto-detected `xmm7360-pci` LTE modem driver.

### Milestone 5: CI/CD & Remastered Live ISO Distribution (v5.0)
1. **Phase 19: Automated ISO Remaster Build Harness**: Scripted rootfs/squashfs remaster pipeline for Ubuntu 24.04 and Linux Mint with all quirks and DKMS pre-baked.
2. **Phase 20: GitHub Actions CI/CD Release Pipeline**: Automated build and release workflow publishing flashable ready-to-boot Live USB `.iso` images.
