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
| **Standalone DKMS Module** | [`patches/dkms/lenovo-d330-fix/`](patches/dkms/lenovo-d330-fix/) | Out-of-tree kernel module (`lenovo_d330_fix.ko`) hooking kernel PM events to enforce safe TCON discharge without rebuilding kernel. |
| **Hardware DB Rules** | [`patches/dkms/etc/udev/hwdb.d/`](patches/dkms/etc/udev/hwdb.d/) | Bosch `BOSC0200` accelerometer mount matrix calibration (`0, 1, 0; -1, 0, 0; 0, 0, 1`). |
| **Modprobe Config** | [`patches/dkms/etc/modprobe.d/`](patches/dkms/etc/modprobe.d/) | `i915 enable_psr=0 enable_fbc=0` to eliminate GLK pipe freeze. |
| **Automated Installer** | [`scripts/install_dkms.sh`](scripts/install_dkms.sh) | Zero-friction installation script (`--install`, `--uninstall`, `--dry-run`). |
| **Stress Test Harness** | [`scripts/test_resume_loop.sh`](scripts/test_resume_loop.sh) | Automated multi-cycle RTC wake test loop (`rtcwake -m mem -s 10`). |
| **Telemetry Extractor** | [`scripts/extract_telemetry.sh`](scripts/extract_telemetry.sh) | Local and remote SSH hardware dump utility (ACPI, VBT, EDID, GPIO). |
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

Reboot the tablet. Suspend and resume will now work reliably.

### Option 2: Apply Kernel Patch (For Custom / Distribution Kernels)

```bash
cd /usr/src/linux
git apply /path/to/lenovo-d330-linux-fix/patches/d330_display_resume_fix.patch
```

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
├── .gsd/                 # GSD autonomous state management & worklogs
├── docs/
│   ├── research/        # Prior art and community findings analysis
│   ├── dumps/           # Hardware extraction procedures & dump archives
│   └── windows_analysis/# igdkmd64.sys vs i915 differential analysis
├── drivers_base/        # Official Lenovo Windows driver baseline references
├── patches/
│   ├── d330_display_resume_fix.patch  # Unified DRM kernel patch
│   └── dkms/            # Standalone out-of-tree DKMS package & configs
├── scripts/
│   ├── acquire_lenovo_drivers.sh      # Downloader for Lenovo OEM drivers
│   ├── extract_telemetry.sh           # ACPI/VBT/EDID telemetry collection
│   ├── install_dkms.sh                # Automated DKMS installation harness
│   └── test_resume_loop.sh            # Suspend/resume verification loop
└── tools/
    ├── analyze_igdkmd64.py            # PE/COFF driver & INF parser
    ├── compare_pps_timings.py         # PPS timing state machine model
    └── ghidra_export_power_callbacks.py # Ghidra headless callback exporter
```
