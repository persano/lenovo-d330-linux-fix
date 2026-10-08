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
- **Milestone 3: Vision, Ergonomics & Multimedia (v3.0)**: Intel IPU3 dual CSI-2 camera pipeline with libcamera 3A tuning & v4l2loopback bridge, 3GB zstd ZRAM swap & eMMC queue optimization, PipeWire speaker DSP acoustic filter-chain & anti-pop DAC delay, VPC2004 battery conservation & Fn-lock CLI (`tools/d330-ctl`), 1000Hz PWM backlight frequency scaling, DRRS, and calibrated sRGB D65 ICC profile.
- **Milestone 4: Connectivity, Firmware & System Boot (v4.0)**: Early bootloader fbcon landscape rotation, Plymouth initramfs hook, emergency refresh hotkey (`tools/d330-refresh-screen.sh`), clean early CPIO ACPI DSDT override (`/boot/acpi-override.cpio`), sensor debounce & ALS smoothing daemon (`tools/d330-sensor-filter.py`), touchpad gesture & Active Pen barrel tuning, automated MicroSD GPT expansion (`tools/d330-microsd-setup.sh`), Intel XMM 7360 LTE modem FCC unlock, and low-battery auto-hibernate daemon (`tools/d330-auto-hibernate.py`).
- **Milestone 5: CI/CD & Remastered Live ISO Distribution (v5.0)**: Native distro packages (`.deb`, `.rpm`, `PKGBUILD`), automated Live ISO remaster build harness (`scripts/build_live_iso.sh`), and GitHub Actions release CI/CD pipeline (`.github/workflows/`).
- **Milestone 6: System Resilience, Performance & Usability Polish (v6.0)**: Intel VA-API hardware decode environment and browser prefs, fanless thermal RAPL limits (PL1 5.0W / PL2 8.0W) with thermald curve, earlyoom low-RAM watchdog, tablet OSK auto-summon & long-press right-click, PipeWire RNNoise neural microphone filter-chain, RTL8821CE single-antenna Wi-Fi/BT coexistence & s2idle resume hook, eMMC fast boot tuning (~9s boot), and GTK3 desktop system tray hardware applet (`tools/d330-tray.py`).

## Project Status: Pre-Deployment Audit Remediation (v7.0) in progress
Hardware parity and usability work through v6.0 shipped, but an external pre-deployment audit returned `BLOCKED BY CRITICAL DEFECTS` (4 Critical, 17 Moderate, 11 Minor). Milestone 7 remediates phases 32 → 42 before public ISO builds.

### Key Decisions (Milestone 7)
- **Phase 32**: `tools/d330-microsd-setup.sh` now requires an explicit `--device`, runs three ordered pre-write guards (mountpoints → root-device → typed yes) before any `parted`/`mkfs` write, refuses both root-device directions, and drops the `mkfs -F` force flag and the fixed `sleep 1` (audit C1).
- **Phase 32**: `--mount-data` writes only the locked `noatime,lazytime,commit=60,nofail,x-systemd.device-timeout=10s 0 2` line, proven by `findmnt --verify` before append, with an idempotent EXIT-trap rollback on failed mount and honest duplicate/legacy refusal (audit C2). `D330_FSTAB` is the test seam; `--mount-home` is an explicit non-zero stub.
- **Phase 32**: Verification accepted two hardware-dependent items under documented VERIFICATION overrides (no D330/tablet in the dev environment); physical confirmation of the mounted-target abort and on-target fstab boot behavior is tracked in `.planning/STATE.md` for deployment sign-off.

---
*Last updated: 2026-10-08 after Phase 32*
