# Lenovo IdeaPad D330-10IGL Linux Display & Power Parity Fix

[![License: GPL v2](https://img.shields.io/badge/License-GPL%20v2-blue.svg)](patches/dkms/lenovo-d330-fix/lenovo_d330_fix.c)
[![Hardware: Lenovo D330-10IGL](https://img.shields.io/badge/Hardware-Lenovo%20D330--10IGL%20(82H0)-green.svg)](docs/windows_analysis/RESUME_SEQUENCE.md)
[![SoC: Intel Gemini Lake Refresh](https://img.shields.io/badge/SoC-Intel%20Gemini%20Lake%20Refresh-orange.svg)](docs/research/COMMUNITY_FINDINGS.md)

Production-grade Linux display resume fix, panel power sequencing (PPS) quirk, and orientation calibration for the **Lenovo IdeaPad D330-10IGL** (Machine Type `82H0`, Intel Celeron N4020 / N4120, Intel UHD Graphics 600) and related D330-10IGM models (`81H3`, `81MD`).

---

## The Problem

Under standard Linux distributions (Ubuntu, Debian, Linux Mint, Fedora, Arch), the Lenovo IdeaPad D330-10IGL experiences severe display failure:
1. **Resume Black Screen / Latch-up**: Upon waking from suspend (`S3` or Modern Standby `S0ix`), the display panel remains permanently dark with zero backlight.
2. **Prior Workarounds Were Destructive**: Previous community fixes masked systemd sleep targets (`systemctl mask sleep.target ...`), preventing power savings and causing battery drain and overheating in bags.
3. **Missing DMI Orientation Quirks**: The portrait-native 800x1280 (or 1200x1920) panel lacked kernel DMI matching for Type `82H0`.

---

## Root Cause Discovered

Reverse engineering of the official Lenovo Windows 10 driver baseline (`igdkmd64.sys`) and comparison against the Linux kernel `intel_pps.c` driver revealed:
- **TCON Charge Dissipation ($t_{11}\text{-}t_{12}$)**: The internal panel Timing Controller requires a mandatory minimum power-down duration of **500 ms** before $V_{\text{DD}}$ can be safely re-asserted.
- **Windows Enforces 500 ms**: The Windows OEM INF programs `PanelPowerCycleDelay = 500 ms`.
- **Linux Defaults to 200 ms**: Linux `intel_pps.c` fell back to 200 ms, triggering electrical latch-up in the TCON during rapid suspend/resume.
- **Gemini Lake PSR Lockup**: Hardware Panel Self-Refresh (PSR) causes Gen9 display pipe lockups upon exiting package C-states.

---

## Solution Deliverables

| Deliverable | Path | Description |
| :--- | :--- | :--- |
| **Unified Kernel Patch** | [`patches/d330_display_resume_fix.patch`](patches/d330_display_resume_fix.patch) | Mainline patch for `drm_panel_orientation_quirks.c`, `intel_quirks.c`, and `intel_pps.c` enforcing $\ge 600\text{ ms}$ PPS cycle delay. |
| **Standalone DKMS Module** | [`patches/dkms/lenovo-d330-fix/`](patches/dkms/lenovo-d330-fix/) | Out-of-tree kernel module (`lenovo_d330_fix.ko`) that prints a DMI-matched banner/breadcrumb; it does NOT enforce TCON discharge timing — the Option 2 kernel clamp patch delivers that. |
| **Touchscreen & Touchpad Calibration** | [`patches/touchscreen/`](patches/touchscreen/) & [`patches/touchpad_pen/`](patches/touchpad_pen/) | Goodix I2C touch matrix (identity on Wayland, where the compositor applies the panel orientation; the 90-deg transform is X11-only), libinput model quirks for palm/pressure, Active Pen thresholds, and sleep unbind/bind recovery hook. |
| **Tablet Mode Daemon** | [`patches/dock/`](patches/dock/) & [`tools/d330-tablet-daemon.py`](tools/d330-tablet-daemon.py) | Intel HID switch handler managing orientation lock, touchpad gate, and virtual keyboard on dock/undock. |
| **Audio UCM2 Profiles** | [`patches/audio/ucm2/`](patches/audio/ucm2/) | ALSA UCM2 profiles fixing SOF DSP audio routing, headphone jack auto-mute, and internal digital microphones. |
| **RNNoise Mic Denoiser** | [`scripts/build_rnnoise_ladspa.sh`](scripts/build_rnnoise_ladspa.sh) | Builds `librnnoise_ladspa.so` from pinned source so the PipeWire AI mic denoiser works where no distro package ships the plugin. |
| **Battery & Power Tuning** | [`patches/power/`](patches/power/) & [`tools/lenovo-d330-power-tune.sh`](tools/lenovo-d330-power-tune.sh) | Fanless 6W Intel P-State/EPP tuning, TLP presets, and runtime PM doubling battery runtime. |
| **Hardware DB Rules** | [`patches/dkms/etc/udev/hwdb.d/`](patches/dkms/etc/udev/hwdb.d/) | Bosch `BOSC0200` accelerometer mount matrix calibration (`0, 1, 0; -1, 0, 0; 0, 0, 1`). |
| **Modprobe Config** | [`patches/dkms/etc/modprobe.d/`](patches/dkms/etc/modprobe.d/) | `i915 enable_psr=0 enable_fbc=0` to eliminate GLK pipe freeze. |
| **ChromeOS Patches** | [`patches/chromeos/`](patches/chromeos/) | Kernel patches for `chromeos-5.15` and `chromeos-6.6`+ branches. |
| **Android-x86 / Bliss OS** | [`patches/android/`](patches/android/) | Kernel patches (5.15 & 6.6) and sensor HAL matrix configs for Android. |
| **Distro Install Guide** | [`docs/DISTRO_INSTALL_GUIDE.md`](docs/DISTRO_INSTALL_GUIDE.md) | Guide for Ubuntu/Mint .deb rebuilds, Fedora RPMs, Arch PKGBUILD, and ISO modification. Step-by-step **Kubuntu 26.04 / Wayland** walkthrough in [`docs/KUBUNTU_INSTALL_STEPS.md`](docs/KUBUNTU_INSTALL_STEPS.md). |
| **Automated Installer** | [`scripts/install_dkms.sh`](scripts/install_dkms.sh) | Zero-friction installation (`--install`, `--uninstall`, `--verify`, `--dry-run`, `--with-rnnoise`). |
| **Diagnostic Test Suite** | [`scripts/`](scripts/) | Test harnesses for resume loop, touch calibration, dock switching, audio, and battery telemetry. |
| **Differential RE Suite** | [`tools/`](tools/) | Static driver analyzer, Ghidra export script, and PPS timing model. |


---

## Installation Guide

### Option 1: Standalone DKMS (Recommended for Stock Kernels)

On your target Lenovo D330 tablet running Linux:

```bash
# Clone the repository
git clone https://github.com/persano/lenovo-d330-linux-fix.git
cd lenovo-d330-linux-fix

# Run automated installer
sudo ./scripts/install_dkms.sh --install
```

Reboot the tablet. Option 1 installs an out-of-tree DKMS module that verifies
the DMI platform match and prints a breadcrumb in `dmesg`, together with the
`i915 enable_psr=0 enable_fbc=0` parameters and the
`fbcon=rotate:1 video=efifb:nobgrt` orientation / logo fixes. It does
**not include** the 600 ms panel power-cycle clamp: no PM notifier event runs
between panel power-off and panel power-on, so the module cannot enforce TCON
discharge timing.

### Option 2: Apply the Kernel Clamp Patch (For Custom / Distribution Kernels)

Option 2 applies `patches/d330_display_resume_fix.patch` to a kernel source
tree; this is what delivers the in-driver PPS power-cycle clamp, automated via
the installer:

```bash
# --kernel-src points at your kernel source tree. The installer dry-runs the
# patch first and warns (never fails) on a context mismatch.
sudo ./scripts/install_dkms.sh --install --kernel-src /usr/src/linux
```

The patch is gated by `patch -p1 --dry-run`. On stock mainline kernels the hunk
context typically does not match, so the installer prints a `[WARN]` and skips
the apply; the clamp must then be adapted and applied manually, and the kernel
rebuilt and rebooted before it takes effect. Option 1 alone does not fix a
latch-up panel.

---

## Verifying the Fix

Run the automated sleep/wake test suite:

```bash
sudo ./scripts/test_resume_loop.sh --cycles 5 --sleep 10
```

Inspect driver actions in `dmesg`:

```bash
dmesg | grep lenovo_d330_fix
```

---

## Repository Structure

```text
├── .github/              # CI workflows and harness-trust checks
├── .gsd/                 # GSD autonomous state management & worklogs
├── docs/
│   ├── DISTRO_INSTALL_GUIDE.md  # Ubuntu/Mint, Fedora, Arch and ISO guidance
│   ├── KUBUNTU_INSTALL_STEPS.md # Step-by-step Kubuntu 26.04 / Wayland walkthrough
│   ├── research/        # Prior art and community findings analysis
│   ├── dumps/           # Hardware extraction procedures & dump archives
│   └── windows_analysis/# igdkmd64.sys vs i915 differential analysis
├── drivers_base/        # Official Lenovo Windows driver baseline references
├── packaging/           # Debian, Arch and RPM packaging metadata
│   ├── debian/          # dpkg-buildpackage rules & control
│   ├── arch/            # PKGBUILD
│   └── rpm/             # lenovo-d330-fix.spec
├── patches/
│   ├── d330_display_resume_fix.patch  # Unified DRM kernel patch
│   ├── chromeos/        # ChromeOS kernel 5.15 & 6.6 patches
│   ├── android/         # Android-x86 / Bliss OS kernel patches & HAL configs
│   └── dkms/            # Standalone out-of-tree DKMS package & configs
├── scripts/
│   ├── acquire_lenovo_drivers.sh      # Downloader for Lenovo OEM drivers
│   ├── extract_telemetry.sh           # ACPI/VBT/EDID telemetry collection
│   ├── install_dkms.sh                # Automated DKMS installation harness
│   └── test_*.sh        # Test harnesses (resume, touch, dock, audio, battery...)
└── tools/
    ├── analyze_igdkmd64.py            # PE/COFF driver & INF parser
    ├── compare_pps_timings.py         # PPS timing state machine model
    └── ghidra_export_power_callbacks.py # Ghidra headless callback exporter
```

The test harnesses are trusted to fail loudly: `scripts/test_harness_trust.sh`
(Phase 41) deliberately breaks the subject of representative suites and asserts a
non-zero exit, so a green run means the checks actually executed rather than
silently passing. Development-only helpers (`tools/d330-acpi-override.sh`,
`tools/d330-pen-config.sh`) are diagnostics and are **not** installed by
`install_dkms.sh`.
