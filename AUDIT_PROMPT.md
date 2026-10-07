# Pre-Deployment Audit Prompt for External AI

You are a senior Linux kernel engineer, system architect, and security auditor.
Your mission is to perform a rigorous, skeptical pre-deployment audit of the repository `lenovo-d330-linux-fix` before any changes are executed on physical hardware (Lenovo IdeaPad D330-10IGL / D330-10IGM, Intel Gemini Lake N4020/N4120, fanless 6W TDP, 4GB RAM, 64GB eMMC).

---

## 1. Core Architecture & Manifest Review
- Read `CHANGES_AUDIT.md` in the repository root. This document details all 6 Milestones (Phases 0–31), explaining the exact "Why", "How", and "What" behind every patch, tool, daemon, and config.
- Read `scripts/install_dkms.sh` to understand deployment and rollback mechanisms.

---

## 2. Source Code & Configuration Inspection Scope
- **Configuration Files (`patches/`)**:
  - Modprobe configs (`patches/*/etc/modprobe.d/*.conf`)
  - Udev rules & hwdb entries (`patches/*/etc/udev/`)
  - Systemd unit services & sleep hooks (`patches/*/etc/systemd/`, `usr/lib/systemd/system-sleep/`)
  - X11 configs (`patches/*/etc/X11/xorg.conf.d/`)
  - Audio & PipeWire filter-chain configs (`patches/audio/`, `patches/audio_dsp/`)
  - Thermal, power, memory & boot configs (`patches/thermal/`, `patches/power/`, `patches/storage_memory/`, `patches/oom_protection/`, `patches/fastboot/`, `patches/media_vaapi/`)
- **Python Daemons & Shell Tools (`tools/`)**:
  - `tools/d330-tablet-daemon.py`
  - `tools/d330-tray.py`
  - `tools/d330-ctl`
  - `tools/d330-sensor-filter.py`
  - `tools/d330-auto-hibernate.py`
  - `tools/d330-thermal-tune.sh`
  - `tools/d330-fastboot-tune.sh`
  - `tools/d330-vaapi-check.sh`
- **Test Harnesses (`scripts/test_*.sh`)**:
  - All 11 verification scripts supporting `--probe`, `--simulate`, and `--dry-run`.

---

## 3. Audit Criteria

### A. Syntax & System Integrity
- Check bash syntax, shell quoting, error handling (`set -e` vs non-fatal fallbacks).
- Check Python syntax, imports, exception handling, and resource leaks (e.g. loops without sleep, unhandled D-Bus/sysfs disconnects).
- Check configuration format validity (systemd unit syntax, X11 xorg.conf syntax, udev MATCH syntax, PipeWire SPA JSON syntax).

### B. Installer / Uninstaller Symmetry & Safety
- Cross-reference `scripts/install_dkms.sh` `do_install()` against `do_uninstall()`. Does uninstall cleanly remove 100% of deployed files, services, and symlinks without leaving orphan files?
- Verify file permissions (e.g. `chmod +x` on executables and sleep hooks).
- Ensure no destructive operations or data loss risks exist on raw block devices (`/dev/mmcblk0`, `/dev/sda`).

### C. Kernel, Hardware & Performance Correctness
- **Display & DRM**: Are PPS clamp delays (600ms) and DMI rotation quirks sound? Does `enable_psr=0` prevent panel flickering without excessive power draw?
- **Thermals & RAPL**: Are PL1 (5.0W) and PL2 (8.0W) limits and `thermal-conf.xml` cooling zones valid for Gemini Lake SoC? Could they cause kernel panics or clock lockups?
- **Memory & earlyoom**: Are `vm.swappiness=150`, 3GB ZRAM (`zstd`), and earlyoom (`-m 4 -s 10`) balanced for a 4GB system? Could earlyoom kill essential desktop session daemons?
- **Wireless & Radio**: Are `rtw88_8821ce` parameters (`ant_sel=2`, `bt_coex_active=1`, `disable_lps_deep=1`) technically sound for Realtek combo chips?
- **Audio & PipeWire**: Are LADSPA RNNoise filter-chain definitions and ES8336 UCM2 mixer routing correct? What happens if `librnnoise_ladspa.so` is missing?

### D. Edge Cases, Missing Pieces & Regressions
- Are there missing prerequisites or silent assumptions?
- Are there contradictions between different subsystem settings (e.g., TLP vs thermald vs RAPL vs P-State)?

---

## 4. Expected Output Format
Deliver your findings clearly structured as:
1. **Executive Verdict**: `[APPROVED FOR HARDWARE / APPROVED WITH MINOR CAVEATS / BLOCKED BY CRITICAL DEFECTS]`
2. **Critical / Blocker Issues**: Bugs that could cause boot loops, hardware faults, data loss, or hard hangs.
3. **Moderate / Edge-Case Concerns**: Scenarios where a service might fail, conflict, or degrade user experience.
4. **Minor / Code Quality Polish**: Nitpicks, redundant lines, or cosmetic improvements.
5. **Direct Recommendations & Code Fixes**: Exact diffs or replacement lines for any identified defects.
