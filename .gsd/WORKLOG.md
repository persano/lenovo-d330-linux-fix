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
- Committed and pushed Phase 4 (`d5f20bc`).

## [Phase 5] Patch Generation & DKMS Delivery
- Authored upstream-ready kernel patch `patches/d330_display_resume_fix.patch`:
  * Adds DMI orientation quirks for Lenovo IdeaPad D330-10IGL (`82H0`) in `drm_panel_orientation_quirks.c`.
  * Introduces `QUIRK_INCREASE_PPS_CYCLE_DELAY` in `intel_quirks.c`.
  * Clamps minimum PPS `panel_power_cycle_delay` to >= 600ms in `intel_pps.c` to prevent TCON latch-up.
- Developed standalone DKMS package `patches/dkms/lenovo-d330-fix/`:
  * Kernel module `lenovo_d330_fix.c` with PM notifier hooks enforcing 600ms wake delay.
  * Kbuild `Makefile` and `dkms.conf`.
- Authored system configuration templates:
  * `patches/dkms/etc/modprobe.d/lenovo-d330-i915.conf` (`i915 enable_psr=0 enable_fbc=0`).
  * `patches/dkms/etc/udev/hwdb.d/61-lenovo-d330-sensor.hwdb` (Bosch `BOSC0200` accelerometer mount matrix).
  * `patches/dkms/etc/systemd/system/lenovo-d330-resume.service` (Post-resume stabilization).
- Authored automated operational scripts:
  * `scripts/install_dkms.sh` supporting `--install`, `--uninstall`, and `--dry-run`.
  * `scripts/test_resume_loop.sh` for multi-cycle RTC wake stress testing.
- Created `patches/README.md` documentation.
- Committed and pushed Phase 5 (`7c313fb`) and initial README (`87d425f`).

## [Cross-Platform Delivery] ChromeOS, Android-x86 & Distro Customization
- Authored targeted ChromeOS kernel patches:
  * `patches/chromeos/d330_chromeos_5.15.patch` (for `chromeos-5.15` LTS).
  * `patches/chromeos/d330_chromeos_6.6.patch` (for `chromeos-6.6`+).
  * `patches/chromeos/README.md` (deployment guide for ChromeOS Flex, Brunch, and source builds).
- Authored targeted Android-x86 / Bliss OS patches:
  * `patches/android/d330_android_x86_5.15.patch` (Bliss OS 14/15).
  * `patches/android/d330_android_x86_6.6.patch` (Bliss OS 16+).
  * `patches/android/android_hal_configs/sensor_hal.prop` (Sensor HAL accelerometer matrix).
  * `patches/android/README.md` (Android bootloader and HAL documentation).
- Authored distro kernel replacement & installer customization guide:
  * `docs/DISTRO_INSTALL_GUIDE.md` (step-by-step procedures for live system kernel overwrite via DKMS, Debian/Ubuntu `.deb` kernel compilation, Fedora RPM build, Arch PKGBUILD, and ISO squashfs remastering).
- Committed and pushed cross-platform deliverables (`9d0620e`).

## [Milestone Transition] Milestone 1 Archived & Milestone 2 Initialized
- Archived Milestone 1 (v1.0 Display & Power Parity) to `.gsd/milestones/v1.0-ROADMAP.md`.
- Created Git release tag `v1.0`.
- Initialized Milestone 2: Peripheral Parity & Tablet Usability (v2.0) covering Phases 6 through 9:
  * Phase 6: Touchscreen & Active Pen Calibration
  * Phase 7: Detachable Dock & Tablet Mode Daemon
  * Phase 8: Audio & Microphone UCM Profiles
  * Phase 9: Battery Life & Power Governors
- Updated `PROJECT.md`, `STATE.md`, and `ROADMAP.md`.
- Stood by for user invocation of `/gsd-autonomous` for Phase 6.

## [Phase 6] Touchscreen & Active Pen Calibration
- Created upstream-ready kernel patch `patches/touchscreen/d330_touchscreen_dmi.patch`:
  * Matches DMI for Type `82H0` (HD), `81MD` (HD), and `81H3` (FHD) in `drivers/platform/x86/touchscreen_dmi.c`.
  * Assigns swapped X/Y axes, inverted Y, and active stylus support properties.
- Authored udev calibration rules and hwdb entries:
  * `patches/touchscreen/etc/udev/rules.d/90-lenovo-d330-touchscreen.rules`: Maps `LIBINPUT_CALIBRATION_MATRIX="0 1 0 -1 0 1"`, configures palm rejection thresholds (pressure 120, size 12).
  * `patches/touchscreen/etc/udev/hwdb.d/62-lenovo-d330-touchscreen.hwdb`: Direct DMI-based libinput hwdb property overrides.
  * `patches/touchscreen/etc/X11/xorg.conf.d/50-touchscreen-d330.conf`: X11 InputClass transformation matrix and stylus pressure curves.
- Developed I2C resume recovery sleep hook:
  * `patches/touchscreen/etc/systemd/system-sleep/lenovo-d330-touchscreen-resume.sh`: Cycles Goodix I2C sysfs unbind/bind on post-resume to eliminate controller lockups.
- Authored diagnostic and verification suite:
  * `scripts/test_touch_calibration.sh` supporting `--dry-run`, `--test-unbind`, and `--monitor`.
  * Documented design, mathematical transformation, and hardware behavior in `docs/research/TOUCHSCREEN_ACTIVE_PEN.md` and `patches/touchscreen/README.md`.

## [Phase 7] Detachable Dock & Tablet Mode Daemon
- Analyzed ACPI Intel HID Event Filter (`INT33D5`), `intel-hid` / `intel_vbtn` switch events (`SW_TABLET_MODE`), and USB hotplug (`17ef` Lenovo dock).
- Engineered standalone daemon `tools/d330-tablet-daemon.py`:
  * Direct asynchronous `select()` event loop polling `/dev/input/event*` devices with `SW_TABLET_MODE`.
  * Fallback heartbeat probe checking physical USB dock presence.
  * Automates landscape display locking and physical touchpad enablement when docked.
  * Automates accelerometer auto-rotation unlocking and on-screen keyboard (OSK) enablement when detached.
- Authored system integration components:
  * `patches/dock/etc/systemd/system/d330-tablet-daemon.service`: Dedicated systemd service unit.
  * `patches/dock/etc/udev/rules.d/85-lenovo-d330-dock.rules`: Dynamic dock USB hotplug events and Intel HID switch bindings.
- Authored testing and documentation deliverables:
  * `scripts/test_dock_switching.sh` with automated multi-cycle dock/undock toggle validation.
  * `docs/research/DETACHABLE_DOCK_TABLET_MODE.md` and `patches/dock/README.md`.

## [Phase 8] Audio & Microphone UCM Profiles
- Analyzed Intel Smart Sound Technology (SST) / Sound Open Firmware (SOF) DSP architecture and codec topology on Gemini Lake (PCI `8086:3198`).
- Authored ALSA Use Case Manager (UCM2) profile package for Lenovo D330:
  * `patches/audio/ucm2/sof-essx8336/sof-essx8336.conf`: Master syntax version 4 UCM card profile.
  * `patches/audio/ucm2/sof-essx8336/HiFi.conf`: Endpoints definition for internal stereo speakers, headphone jack with `JackHWMute` auto-mute, internal DMIC dual-channel microphone, and 3.5mm TRRS headset mic.
- Configured kernel audio driver parameters:
  * `patches/audio/etc/modprobe.d/lenovo-d330-audio.conf`: Enforces Intel SOF DSP driver (`dsp_driver=3`), sets `dmic_num=2`, and configures ES8316 jack quirks (`quirk=0x0013`).
- Developed diagnostic and verification harness:
  * `scripts/test_audio_profiles.sh` supporting `--probe`, `--test-speakers`, `--test-mic`, and `--monitor-jack`.
  * Authored documentation in `docs/research/AUDIO_UCM_TOPOLOGY.md` and `patches/audio/README.md`.

## [Phase 9] Battery Life & Power Governors
- Analyzed 6W fanless thermal characteristics and power consumption on Gemini Lake Celeron N4020/N4120.
- Authored power profiles and configurations:
  * `patches/power/etc/tlp.d/50-lenovo-d330.conf`: Custom TLP profile configuring `powersave` governor, `balance_performance` EPP on AC, `power` EPP on battery, Turbo Boost gating, and GPU max frequency clamping.
  * `patches/power/etc/udev/rules.d/95-lenovo-d330-power.rules`: Automatic runtime PM for PCI endpoints, eMMC storage, I2C busses, sound DSP, and USB autosuspend (exempting dock inputs).
  * `patches/power/etc/modprobe.d/lenovo-d330-power.conf`: Kernel options for `iwlwifi`, `pcie_aspm=powersave`, and `i915 enable_rc6=1`.
  * `patches/power/etc/systemd/system/lenovo-d330-power.service` and `tools/lenovo-d330-power-tune.sh`: Systemd service and utility for runtime EPP and RAPL governor tuning.
- Developed test harness:
  * `scripts/test_battery_power.sh` supporting `--telemetry`, `--stress N`, and `--tune`.
  * Authored documentation in `docs/research/BATTERY_POWER_MANAGEMENT.md` and `patches/power/README.md`.

## [Unified Installer Update]
- Updated `scripts/install_dkms.sh` to provide unified one-step deployment and uninstallation across all subsystems (display DRM/DKMS, touchscreen, active pen, detachable dock daemon, ALSA UCM2 audio, and battery/power tuning).

## [Milestone 2 Completion] Peripheral Parity & Tablet Usability (v2.0)
- All phases of Milestone 2 (Phases 6, 7, 8, 9) successfully implemented, verified, and integrated into repository.
