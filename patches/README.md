# Lenovo IdeaPad D330-10IGL Display & Power Parity Patches

This directory contains the patches, out-of-tree DKMS module, and configuration templates to fix display resume failure on the **Lenovo IdeaPad D330-10IGL** (Type 82H0 / Intel Gemini Lake Refresh UHD 600) and related D330 series platforms.

---

## Deliverables Summary

1. **Kernel Patch (`d330_display_resume_fix.patch`)**:
   - Upstream-targeted unified patch for the Linux DRM subsystem.
   - Adds DMI table entry for Type `82H0` to `drivers/gpu/drm/drm_panel_orientation_quirks.c`.
   - Introduces `QUIRK_INCREASE_PPS_CYCLE_DELAY` in `drivers/gpu/drm/i915/display/intel_quirks.c`.
   - Clamps minimum `panel_power_cycle_delay` to $\ge 600\text{ ms}$ in `drivers/gpu/drm/i915/display/intel_pps.c` to prevent timing controller (TCON) electrical latch-up.

2. **Standalone DKMS Package (`dkms/lenovo-d330-fix/`)**:
   - Out-of-tree kernel module (`lenovo_d330_fix.ko`) for distribution kernels (Ubuntu, Mint, Debian, Arch, Fedora).
   - Hooks kernel PM notifications via `register_pm_notifier()`.
   - Tracks suspend elapsed time and enforces a 600 ms power cycle discharge delay upon wake before subsequent display reactivation.
   - Provides runtime parameter tuning via `modprobe lenovo_d330_fix power_cycle_delay_ms=600`.

3. **System Configuration Profiles**:
   - `dkms/etc/modprobe.d/lenovo-d330-i915.conf`: Disables PSR and FBC on Gemini Lake Refresh UHD 600 to prevent package C-state pipe lockups.
   - `dkms/etc/udev/hwdb.d/61-lenovo-d330-sensor.hwdb`: Calibrates Bosch `BOSC0200` accelerometer mount matrix (`0, 1, 0; -1, 0, 0; 0, 0, 1`) to match logical orientation.
   - `dkms/etc/systemd/system/lenovo-d330-resume.service`: removed in phase 34 (echo-only unit, no real recovery; display resume is handled by i915 params + the optional kernel clamp patch).

4. **Automation Scripts**:
   - `scripts/install_dkms.sh`: Automated installer and uninstaller (`--install`, `--uninstall`, `--dry-run`).
   - `scripts/test_resume_loop.sh`: Repeated RTC-wake stress tester (`rtcwake -m mem -s 10`).

---

## Quick Start Installation (DKMS Mode)

Run the autonomous installer on the target Lenovo D330 tablet:

```bash
sudo ./scripts/install_dkms.sh --install
```

To dry-run and verify prerequisite packages without making changes:

```bash
sudo ./scripts/install_dkms.sh --dry-run
```

To test display resume reliability with 5 automated sleep/wake cycles:

```bash
sudo ./scripts/test_resume_loop.sh --cycles 5 --sleep 10
```

To remove the fix and restore system default behavior:

```bash
sudo ./scripts/install_dkms.sh --uninstall
```

---

## Applying the Kernel Patch Directly

If building a custom kernel or packaging a distribution kernel from source:

```bash
cd /path/to/linux-source
git apply /path/to/lenovo-d330-linux-screen-fix/patches/d330_display_resume_fix.patch
make -j$(nproc)
sudo make modules_install && sudo make install
```
