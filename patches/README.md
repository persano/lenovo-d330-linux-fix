# Lenovo IdeaPad D330-10IGL Display & Power Parity Patches

This directory contains the patches, out-of-tree DKMS module, and configuration templates to fix display resume failure on the **Lenovo IdeaPad D330-10IGL** (Type 82H0 / Intel Gemini Lake Refresh UHD 600) and related D330 series platforms.

---

## Deliverables Summary

1. **Kernel Patch (`d330_display_resume_fix.patch`)**:
   - Upstream-targeted unified patch for the Linux DRM subsystem.
   - Stops `drivers/gpu/drm/i915/display/skl_universal_plane.c` from advertising render-compressed (CCS) modifiers on the D330 (`82H0`) via a DMI check. The panel is natively portrait, so userspace scans out rotated 90/270 degrees; `skl_plane_check_fb()` rejects a CCS framebuffer combined with that rotation, which makes every resume atomic commit fail with `-EINVAL` and leaves the display black. Without CCS advertised, userspace falls back to a Y-tiled surface and the commit succeeds.
   - This fixes only the plane-level rejection. A separate DSI panel power/sequencing issue on resume is still open; see `docs/research/DISPLAY_RESUME_CCS_MODIFIER.md`.

2. **Standalone DKMS Package (`dkms/lenovo-d330-fix/`)**:
   - Out-of-tree kernel module (`lenovo_d330_fix.ko`) for distribution kernels (Ubuntu, Mint, Debian, Arch, Fedora).
   - Verifies the DMI platform match and prints honest suspend/resume breadcrumbs (banner only).
   - Does NOT enforce a TCON discharge delay: there is no PM notifier event between panel power-off and panel power-on, so the module cannot clamp PPS timing. The 600 ms clamp is delivered by the optional kernel patch (Option 2).
   - `power_cycle_delay_ms` is retained as a no-op for compatibility only; changing it has no effect.

3. **System Configuration Profiles**:
   - `dkms/etc/modprobe.d/lenovo-d330-i915.conf`: Disables PSR and FBC on Gemini Lake Refresh UHD 600 to prevent package C-state pipe lockups.
   - `dkms/etc/udev/hwdb.d/61-lenovo-d330-sensor.hwdb`: Calibrates Bosch `BOSC0200` accelerometer mount matrix (`0, 1, 0; -1, 0, 0; 0, 0, 1`) to match logical orientation.
   - `dkms/etc/systemd/system/`: the echo-only DKMS resume service unit was removed in phase 34 (it only logged connector status, no real recovery; display resume is handled by i915 params + the optional kernel clamp patch).

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
