# WORKLOG: Execution History & Activity Log

## [Phase 0] Setup & Repository Initialization
- Parsed master specification `GSD_PROJECT_SPEC-v3.md`.
- Configured `.gitignore` for build products, driver installers, and raw dump binaries.
- Established repository directory hierarchy: `.gsd/`, `docs/research/`, `docs/dumps/`, `docs/windows_analysis/`, `drivers_base/`, `patches/`, `scripts/`, `tools/`.
- Created GSD management state files: `PROJECT.md`, `STATE.md`, `CONTEXT.md`, `ROADMAP.md`, `WORKLOG.md`.
- Initialized git repository on branch `main`.
- Created private GitHub repository `lenovo-d330-linux-fix`.
- Committed and pushed initial setup (`7e4b76e`).

## [Phase 1] Community Research & Prior Art Ingestion
- Ingested community findings from `lucasgabmoreno/linuxmint_lenovod330` via GitHub API.
- Analyzed `lenovod330-refreshscreen.sh` X11 xrandr crtc mode cycle workaround.
- Documented systemd suspend masking (`systemctl mask sleep.target ...`) and desktop idle suppression.
- Documented kernel boot parameters: `video=efifb:nobgrt`, `fbcon=nodefer`, `i915.enable_psr=0`, `i915.enable_fbc=0`.
- Documented `BOSC0200` accelerometer mount matrix configuration in udev hwdb (`0, 1, 0; -1, 0, 0; 0, 0, 1`).
- Cataloged ACPI DSDT/SSDT root port namespace clashes on `\_SB.PCI0.RP04` (`AE_ALREADY_EXISTS`).
- Compared upstream kernel quirks (`drm_panel_orientation_quirks.c`) for 81H3, 81MD vs 82H0.
- Stored comprehensive analysis in `docs/research/COMMUNITY_FINDINGS.md`.
- Committed and pushed Phase 1 (`a60bdf1`).

## [Phase 2] Official Lenovo Windows Driver Baseline Acquisition
- Enumerated Lenovo D330-10IGL (Type 82H0) driver catalog via Lenovo Support endpoints.
- Resolved direct CDN URLs for key packages:
  * Intel VGA Driver: `https://download.lenovo.com/consumer/mobiles/3gid020fh6y37sb0.exe` (`DS545452`)
  * Intel HID Event Filter / Mode Transition: `https://download.lenovo.com/consumer/mobiles/3gid010fu8cg1sb0.exe` (`DS545445`)
  * Intel Serial-IO / GPIO Driver: `https://download.lenovo.com/consumer/mobiles/3gid010f3ffk4sb0.exe` (`DS545448`)
  * Bosch G-sensor Accelerometer: `https://download.lenovo.com/consumer/mobiles/3gid020fy96b0sb0.exe` (`DS545444`)
  * UEFI BIOS Update: `https://download.lenovo.com/consumer/mobiles/g0cn14ww.exe` (`DS545459`)
- Created `scripts/acquire_lenovo_drivers.sh` supporting automated download, unpacking (`innoextract`, `7z`, `cabextract`), and artifact inspection.
- Validated script syntax with `bash -n`.
- Committed and pushed Phase 2 (`c489f88`).

## [Phase 3] Hardware Telemetry & ACPI Extraction
- Authored `scripts/extract_telemetry.sh` with dual-mode operational support:
  * Local execution (`--local`) requiring root privileges.
  * Remote SSH execution (`--host user@ip`) with automated payload staging, remote sudo collection, tarball bundling, scp retrieval, and remote cleanup.
- Implemented automated extraction pipeline for:
  * DMI platform identifiers (`dmidecode`, `/sys/class/dmi/id/*`).
  * ACPI AML tables (`/sys/firmware/acpi/tables/*`, `acpidump`) and ASL disassembly (`iasl -d`).
  * Intel GPU VBT binary (`i915_vbt`) and automated decoding (`intel_vbt_decode`).
  * DRM connector state, modes, CRTC timings, power wells, and EDID decoding (`edid-decode`).
  * Debugfs GPIO pin allocations and IIO accelerometer mount matrix parameters.
  * System power sleep profiles (`/sys/power/mem_sleep`, `wakeup_count`).
- Created `docs/dumps/README.md` documenting prerequisite packages, invocation syntax, archive hierarchy, and reverse engineering checkpoints.
- Validated script syntax with `bash -n` and verified `--help` output.
- Committed and pushed Phase 3 (`d09d0c3`).

## [Phase 4] Differential Analysis & Reverse Engineering
- Developed `tools/analyze_igdkmd64.py` for PE/COFF header analysis, WDDM DDI callback scanning (`DxgkDdiSetPowerState`, `DxgkDdiResetDevice`), INF registry parsing, and ACPI method tracking.
- Developed `tools/ghidra_export_power_callbacks.py` for Ghidra headless decompilation and JSON export of driver power routines.
- Developed `tools/compare_pps_timings.py` modeling the panel power sequencing state machine and timing deltas between Windows OEM baseline and Linux upstream i915.
- Discovered and confirmed root cause:
  * Windows OEM INF programs `PanelPowerCycleDelay = 500 ms` to allow panel TCON charge dissipation.
  * Linux `intel_pps.c` falls back to 200 ms default, causing electrical TCON latch-up (black screen) during rapid suspend/resume.
  * Gemini Lake Refresh UHD 600 PSR state machine lockups during DC6 sleep exits.
  * Missing DMI matching for Machine Type `82H0` (`D330-10IGL`) in upstream `drm_panel_orientation_quirks.c`.
- Published comprehensive findings in `docs/windows_analysis/RESUME_SEQUENCE.md`.

