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
- **Milestone 7: Pre-Deployment Audit Remediation (v7.0)**: Remediated all 4 Critical, 17 Moderate and 11 Minor findings of the external pre-deployment audit (`BLOCKED BY CRITICAL DEFECTS`): data-loss/boot safety guards (explicit `--device`, pre-write guards, safe fstab), physically-completable hibernate (disk swapfile + resume cmdline), the real PPS/display-resume module (honest DMI banner, real `--kernel-src` clamp), manifest-driven installer/uninstaller symmetry, desktop-session wiring (suffix-free tool names, systemd **user** unit for the tablet daemon), real (or removed) PWM/sensor tools, activated PipeWire DSP filter-chains, corrected udev/hwdb/wireless matches and power-stack ownership, a trustworthy 36-script test harness, and documentation/packaging parity (exec bits, FCC hook, fail-loud packagers, `test_doc_parity.sh`). Plus one cross-phase packaging integration gap (packagers shipped `.py`/`.sh` tool names the units don't execute) found by the milestone audit and fixed.

## Project Status: Milestone 7 (v7.0) complete — Phases 0-42 shipped
Hardware parity and usability work through v6.0 shipped; Milestone 7 (Phases 32-42) remediated the entire external pre-deployment audit plus one cross-phase packaging gap found by the milestone audit. All 11 phases verified. Machine-checkable success criteria are green in the dev environment; hardware-in-the-loop, daemon, and real package-build criteria are covered by documented per-phase verification overrides to re-run on a D330 unit at deployment sign-off.

## Context
- Repo is a shell + Python + packaging + DKMS-patch project; the live installer (`sudo ./scripts/install_dkms.sh`) is the primary deployment path and is consistent end-to-end. The `.deb`/`.rpm`/PKGBUILD packagers and the CI `.deb` build mirror the installer's suffix-free `/usr/local/bin` tool names so shipped+enabled systemd units execute correctly.
- Test harness is 36 `scripts/test_*.sh` guards wired into `scripts/test_storage_cellular.sh` plus a `bash -n` loop; `scripts/test_harness_trust.sh` meta-guards that suites fail and that mutations require `--apply`.
- Known tech debt (see `.planning/v7.0-MILESTONE-AUDIT.md`): `exec-optional` manifest kind verifies existence not `+x`; a stale `apt install librnnoise-ladspa` message; packagers ship a documented subset of configs; a few installer `--dry-run`/optional-skip UX gaps. Nyquist `VALIDATION.md` files predate `status:` (`/gsd-validate-phase` to reconcile).

### Key Decisions (Milestone 7)
- **Phase 32**: `tools/d330-microsd-setup.sh` now requires an explicit `--device`, runs three ordered pre-write guards (mountpoints → root-device → typed yes) before any `parted`/`mkfs` write, refuses both root-device directions, and drops the `mkfs -F` force flag and the fixed `sleep 1` (audit C1).
- **Phase 32**: `--mount-data` writes only the locked `noatime,lazytime,commit=60,nofail,x-systemd.device-timeout=10s 0 2` line, proven by `findmnt --verify` before append, with an idempotent EXIT-trap rollback on failed mount and honest duplicate/legacy refusal (audit C2). `D330_FSTAB` is the test seam; `--mount-home` is an explicit non-zero stub.
- **Phases 33-34**: Hibernate made physically completable (disk-backed swapfile unit + install-time-rendered `resume=` cmdline with `mkconfig` verify); the real PPS/display-resume module shipped with an honest DMI banner and a dry-run-gated `--kernel-src` clamp step (C3/C4).
- **Phases 35-36**: Installer/uninstaller symmetry via a manifest (`deploy_manifest()` + `--verify`); desktop session wiring with suffix-free tool names and a systemd **user** unit for the tablet daemon enabled with `systemctl --global enable` (M1/M2/M3/M6/M11/N6/N7).
- **Phases 37-40**: No-op PWM boot service removed, sensor filter/`--apply` made real; PipeWire DSP fragments relocated to `pipewire.conf.d/` with valid inlined graphs; udev/hwdb/wireless matches corrected to real DMI/HID forms and Realtek-only; power stack reduced to one writer per knob (M4/M5/M7/M8/M9/M10/M13/M14/M15/M16).
- **Phases 41-42**: 36-script test harness made trustworthy (failure counters, `--apply` gating, mutation meta-guard); documentation/packaging parity (`100755` exec bits, FCC hook shipped as the `8086:7360` target, fail-loud packagers, no 0-byte tracked files, `scripts/test_doc_parity.sh`) (M12/M17/N1-N5/N8-N10).
- **Milestone audit**: Fixed a cross-phase packaging gap — all three packagers + the CI `.deb` now install the same suffix-free tool names the shipped units `Exec`, ship the tray autostart, and the CI build no longer `cp ... || true` (commit `5e4948b`).

---
*Last updated: 2026-10-08 after v7.0 milestone*
