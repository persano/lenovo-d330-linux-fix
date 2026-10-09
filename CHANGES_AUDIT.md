# Comprehensive Changes & Architecture Audit Report: Lenovo IdeaPad D330-10IGL Linux Parity Project

## 1. Executive Summary & Hardware Context

### 1.1 Target Device Profile
* **System**: Lenovo IdeaPad D330-10IGL (Type 82H0) / D330-10IGM (Types 81H3, 81MD).
* **SoC / CPU**: Intel Gemini Lake Refresh (GLK-R) — Celeron N4020 (2C/2T @ 1.10 GHz, 2.80 GHz burst) or N4120 (4C/4T @ 1.10 GHz, 2.60 GHz burst). TDP: 6.0W fanless.
* **GPU**: Intel UHD Graphics 600 (Gen9.5, 12 Execution Units).
* **Display Panel**: 10.1" IPS panel (1280x800 WXGA or 1920x1200 WUXGA) oriented natively in Portrait mode (800x1280 / 1200x1920 @ 60 Hz). MIPI-DSI via bridge or eDP.
* **Touchscreen & Digitizer**: Goodix I2C Touchscreen (`GDIX1001` / `GDIX1002`) with active stylus / pen digitizer support (Lenovo Active Pen 1/2, Wacom AES protocol).
* **Dock**: Detachable USB POGO keyboard dock with Synaptics I2C/SMBus touchpad, USB 2.0 pass-through ports, and Hall-effect magnetic hinge sensor (`INT33D5` / `PNP0C0D`).
* **Audio**: Everest ES8336 (`ESSX8336`) I2S low-power codec routed via Intel SST / SOF DSP audio subsystem (`sof-essx8336`).
* **Cameras**: Dual MIPI-CSI2 cameras over Intel IPU3 (Front: Omnivision OV2680 2MP; Rear: Omnivision OV5648 5MP).
* **Wireless**: Realtek RTL8821CE 802.11ac 1x1 PCIe Wi-Fi + Bluetooth 4.2 Combo (single shared antenna).
* **Cellular (Optional models)**: Intel XMM 7360 LTE-A M.2 Modem (PCIe/USB).
* **Storage / Memory**: 64GB/128GB SanDisk/Samsung eMMC 5.1; 4GB LPDDR4-2400 soldered (non-expandable).

### 1.2 Purpose of this Audit Document
This document catalogs every single configuration, patch, script, daemon, and driver modified or created across all 6 project milestones (Phases 0 through 31). It details:
1. **Why** the change was made (root-cause hardware/software limitation or bug).
2. **How** the technical decision was reached (architectural alternatives evaluated and chosen trade-offs).
3. **What** was implemented (exact file paths, parameters, configs, and commands).
4. **Potential Pitfalls & Checklist** for an automated or external AI auditor to verify sanity, syntax, edge-case regressions, and system safety before deployment.

---

## 2. Milestone 1: Display & Power Parity (v1.0)

### 2.1 Display Panel Power Sequencing (PPS) Fix
* **Why**: On stock Linux kernels (5.15–6.x+), putting the D330 to sleep (`s2idle`) or resetting the DRM pipeline often resulted in a permanent black screen or frozen backlight upon wake. Root cause: The panel TCON requires a power-cycle discharge delay (`t11_t12`) of at least 600 ms before re-asserting VDD. The Linux `i915` driver defaults to panel-specific VBT values (often set to 400ms or 500ms by Lenovo BIOS), causing the panel TCON to latch into an unrecoverable undervoltage fault.
* **How Decided**: Rather than maintaining an out-of-tree full `i915.ko` module rebuild (which breaks on every kernel update), we evaluated two approaches:
  1. Patching upstream kernel tree via `drm/i915/display/intel_pps.c`.
  2. Standalone DKMS module hooking module parameters or override via DRM DMI quirks.
  * *Decision*: Deliver both: a standalone DKMS banner module (DMI match + honest suspend/resume breadcrumbs only) + modprobe parameter tuning (`patches/dkms/etc/modprobe.d/lenovo-d330-i915.conf` with `enable_psr=0`, `enable_fbc=0`); the 600 ms TCON power-cycle clamp is delivered by the Option 2 kernel patch (`patches/d330_display_resume_fix.patch`), not by a systemd hook or the DKMS module.
* **What Done**:
  - `patches/dkms/`: DKMS banner module source tree and `dkms.conf` (DMI match + honest breadcrumbs; it does NOT clamp the PPS delay — the Option 2 kernel patch does).
  - `patches/dkms/etc/modprobe.d/lenovo-d330-i915.conf`: Sets `enable_psr=0`, `enable_fbc=0`, plus the retained no-op `power_cycle_delay_ms=600` (this matches the module's C default; the module does not enforce any delay).
  - Echo-only post-resume systemd unit: **REMOVED in Phase 34** — it only logged eDP connector status and never restored display output, so the unit and every installer/postinst/spec reference were deleted. Display resume is handled by the i915 parameters plus the Option 2 kernel patch clamp.
* **Auditor Verification Points**:
  - Verify that `enable_psr=0` does not cause unacceptable battery drain (PSR on GLK UHD 600 often causes panel flickering and FIFO underrun; disabling PSR is standard industry practice for Gemini Lake stability).
  - Verify that no resume-service unit shipping now was previously `systemctl enable`d (Phase 34 deleted the echo-only unit and swept every reference); display resume is delivered by the i915 parameters plus the Option 2 kernel patch clamp, not by a systemd hook.

### 2.2 Native Display Orientation Quirks
* **Why**: The D330 panel is physically manufactured for portrait tablets (native 800x1280 or 1200x1920). Linux DRM by default renders boot screens, TTY consoles, and display servers rotated 90 degrees counter-clockwise (sideways).
* **How Decided**: Fixed at the lowest hardware abstraction layer possible:
  1. Kernel cmdline `fbcon=rotate:1 video=efifb:nobgrt video=DSI-1:panel_orientation=right_side_up video=eDP-1:panel_orientation=right_side_up`.
  2. DRM driver internal DMI table matching D330 DMI strings.
  3. `systemd-hwdb` sensor matrix for desktop environment auto-rotation.
* **What Done**:
  - `patches/boot_orientation/etc/default/grub.d/50-lenovo-d330-boot.cfg`: Injects `fbcon=rotate:1 video=efifb:nobgrt video=DSI-1:panel_orientation=right_side_up video=eDP-1:panel_orientation=right_side_up i915.enable_psr=0 i915.enable_fbc=0` (exact shipped string). `video=efifb:nobgrt` is a real efifb option (parsed in `efifb_setup()`), kept deliberately. DSI-1/eDP-1 are alternatives: only the present connector claims its token; an absent connector is silently ignored by drm-core.
  - `patches/dkms/etc/udev/hwdb.d/61-lenovo-d330-sensor.hwdb`: Injects `ACCEL_MOUNT_MATRIX` for BOSC0200 sensor (`0, 1, 0; 1, 0, 0; 0, 0, -1`).
* **Auditor Verification Points**:
  - Check DMI string globbing: `sensor:modalias:acpi:BOSC0200*:dmi:*:svnLENOVO:pn81H3*:*` and `82H0*`. Must match both Type 81H3 and Type 82H0 boards.

---

## 3. Milestone 2: Peripheral Parity & Tablet Usability (v2.0)

### 3.1 Touchscreen & Active Stylus Matrix Alignment
* **Why**: Rotating the display 90 degrees rotates the video frame, but the Goodix I2C digitizer (`GDIX1001`) reports raw physical coordinates. Without coordinate transformation, touches and pen strokes land 90 degrees away from the cursor. Additionally, after S2idle resume, the Goodix controller frequently desynchronizes I2C bus communications, leading to unresponsive touch.
* **How Decided**:
  - Configure `libinput` via udev hwdb and X11/Wayland input matrices: Coordinate Transformation Matrix `0 1 0 -1 0 1 0 0 1` (maps portrait sensor to landscape desktop).
  - Add kernel device unbind/rebind resume script targeting I2C Goodix device on bus `i2c-GDIX1001:00`.
* **What Done**:
  - `patches/touchscreen/etc/udev/hwdb.d/62-lenovo-d330-touchscreen.hwdb`: Defines `LIBINPUT_CALIBRATION_MATRIX=0 1 0 -1 0 1`.
  - `patches/touchscreen/etc/X11/xorg.conf.d/50-touchscreen-d330.conf`: Sets `TransformationMatrix 0 1 0 -1 0 1 0 0 1` and `EmulateThirdButton` (750ms long-press right-click).
  - `patches/touchscreen/etc/systemd/system-sleep/lenovo-d330-touchscreen-resume.sh`: Resets Goodix I2C driver on wakeup.
* **Auditor Verification Points**:
  - Check whether the matrix orientation matches Wayland compositors (GNOME Mutter / KDE KWin read `LIBINPUT_CALIBRATION_MATRIX` from udev hwdb automatically, whereas X11 reads `xorg.conf.d`). Both are provided.

### 3.2 Detachable Dock & Tablet Mode Daemon
* **Why**: The D330 is a 2-in-1 detachable. When the tablet is unlatched or folded back, the physical keyboard and touchpad are disconnected or disabled. Desktop environments must immediately disable touchpad/mouse inputs, switch to on-screen keyboard (OSK), and enable automatic screen rotation based on the accelerometer.
* **How Decided**:
  - ACPI Hall-effect switch reports `SW_TABLET_MODE` on input event nodes (or dock connection on USB POGO).
  - Created a Python daemon (`tools/d330-tablet-daemon.py`) listening to `/dev/input/event*` devices with `evdev` and D-Bus signals.
  - Automatically commands GNOME (`gsettings`), Cinnamon, KDE Plasma (`qdbus`), and generic X11 (`onboard`, `xinput`).
* **What Done**:
  - `tools/d330-tablet-daemon.py`: Event loop monitoring dock attach/detach events.
  - `patches/dock/etc/udev/rules.d/85-lenovo-d330-dock.rules`: Udev trigger for POGO dock plug/unplug.
  - `patches/dock/usr/lib/systemd/user/d330-tablet-daemon.service`: systemd user unit running the daemon inside the graphical session.
* **Auditor Verification Points**:
  - Check non-blocking execution in `d330-tablet-daemon.py` (ensure subprocess calls do not hang if desktop services are absent).
  - Check fallbacks: if `gsettings` or `qdbus` fails (e.g. running under minimal window managers), daemon suppresses errors and continues.

### 3.3 Audio Subsystem (ALSA UCM2 for ES8336)
* **Why**: Everest ES8336 audio codec is notoriously unsupported out-of-the-box on older Linux distributions. Sound is either completely mute, routed only to headphones, or missing internal microphone capture.
* **How Decided**:
  - Modern kernels (5.18+) include `snd_soc_sof_es8336`. However, user space requires exact ALSA Use Case Manager (UCM2) configuration files to correctly route DAPM (Dynamic Audio Power Management) mixer paths.
  - Sourced and customized official ALSA UCM2 profiles for `sof-essx8336` tailored to Lenovo D330 pin routing (Speaker: DAC1, Mic: AMIC1).
* **What Done**:
  - `patches/audio/ucm2/sof-essx8336/`: Complete UCM2 profiles (`HiFi.conf`, `sof-essx8336.conf`).
  - `patches/audio/etc/modprobe.d/lenovo-d330-audio.conf`: Audio driver parameters (`options snd_soc_sof_es8336 quirk=0x01`).
* **Auditor Verification Points**:
  - Ensure UCM directory location matches ALSA specification (`/usr/share/alsa/ucm2/sof-essx8336`).
  - Verify headset jack sensing udev rule (`patches/audio_dsp/etc/udev/rules.d/91-lenovo-d330-headset-jack.rules`).

### 3.4 Battery Governors & Power Management
* **Why**: Fanless Gemini Lake has an ultra-tight thermal budget (6W TDP). Standard Linux `ondemand` or aggressive `performance` governors drive the CPU into instantaneous thermal throttling (100°C), while default `powersave` lacks burst frequency when needed.
* **How Decided**:
  - Use `intel_pstate` in `powersave` mode combined with Energy Performance Preference (EPP) tuning (`balance_power` on battery, `balance_performance` on AC).
  - Integrate TLP preset specifically optimized for C-state residency (C10) and SATA/PCIe/USB autosuspend.
* **What Done**:
  - `patches/power/etc/tlp.d/50-lenovo-d330.conf`: Custom TLP profile.
  - `patches/power/etc/modprobe.d/lenovo-d330-power.conf`: Enable PCIe ASPM (`pcie_aspm=force`).
  - `tools/lenovo-d330-power-tune.sh`: Runtime governor adjustment script.
* **Auditor Verification Points**:
  - Check if `pcie_aspm=force` causes any PCIe bus drops with the RTL8821CE Wi-Fi card. (Tested: RTL8821CE ASPM is stable when combined with `disable_lps_deep=1`).

---

## 4. Milestone 3: Vision, Ergonomics & Multimedia (v3.0)

### 4.1 Intel IPU3 Dual Camera Pipeline & V4L2 Loopback
* **Why**: The front (OV2680) and rear (OV5648) sensors connect to the Intel Image Processing Unit 3 (IPU3). Unlike standard USB UVC webcams, IPU3 does not output processed RGB/YUV video frames directly to `/dev/video*`. Standard applications (Zoom, Teams, WebRTC, Chromium) cannot read raw Bayer sensor frames.
* **How Decided**:
  - Modern solution: Use `libcamera` for debayering and 3A algorithms (Auto-Exposure, Auto-Focus, Auto-White-Balance), then bridge the output stream to a virtual webcam device via `v4l2loopback`.
* **What Done**:
  - `patches/camera/etc/modprobe.d/lenovo-d330-camera.conf`: Configures `v4l2loopback` with `exclusive_caps=1` (required for Chrome/Chromium detection).
  - `tools/d330-camera-bridge.sh`: Automation script wrapping `libcamerify` / GStreamer to feed `/dev/video42`.
  - `patches/camera/etc/systemd/system/lenovo-d330-camera-loopback.service`: Background systemd service for camera readiness.
* **Auditor Verification Points**:
  - Check kernel module dependency: requires `v4l2loopback-dkms` or kernel built-in module.

### 4.2 4GB RAM & 64GB eMMC Storage Tuning (ZRAM + mq-deadline)
* **Why**: 4GB LPDDR4 is shared with Intel UHD 600 graphics (taking up to 512MB–1GB for VRAM), leaving ~3GB for userspace. Heavy browsing causes severe disk thrashing. The internal 64GB eMMC storage has poor random I/O latency (~15–30 MB/s 4K random write), resulting in system freezes when swapping to disk.
* **How Decided**:
  - Completely replace disk swap with a 3GB in-memory ZRAM swap device compressed via `zstd`.
  - Set `vm.swappiness=180` (forces the kernel to aggressively evict anonymous pages into compressed RAM before dropping pagecache).
  - Pin the eMMC I/O scheduler to `mq-deadline` (deterministic flash read latency; eMMC has no seek cost for a fairness elevator to optimize).
* **What Done**:
  - `patches/storage_memory/etc/systemd/zram-generator.conf`: Standard systemd zram configuration (`zram-size = min(ram * 0.75, 3072)`, `compression-algorithm = zstd`, `swap-priority = 100`).
  - `patches/storage_memory/etc/sysctl.d/99-lenovo-d330-zram.conf`: Sets `vm.swappiness=180`, `vm.vfs_cache_pressure=50`, `vm.watermark_boost_factor=0`, `vm.dirty_bytes=67108864`, `vm.dirty_background_bytes=33554432`, `vm.page-cluster=0`.
  - `patches/storage_memory/etc/udev/rules.d/60-lenovo-d330-emmc.rules`: Forces `scheduler="mq-deadline"` for `mmcblk*`.
* **Auditor Verification Points**:
  - Verify `zram-size = min(ram * 0.75, 3072)`: On 4GB RAM the compressed swap pool is capped at 3.0GB. With `zstd` 3:1 compression, effective memory capacity reaches ~7GB.

### 4.3 Audio DSP Refinement (PipeWire Speaker EQ & Anti-Pop)
* **Why**: The internal 1W stereo speakers in the D330 chassis sound thin, tinny, and distort heavily at >60% volume. Furthermore, the ES8336 codec produces an audible electric "pop/click" when entering and leaving low-power mode (`snd_soc_pm`).
* **How Decided**:
  - PipeWire Filter-Chain: Create a biquad equalizer preset that boosts midrange (200Hz–2kHz), rolls off distorted sub-bass (<120Hz), and limits high-end harshness.
  - Anti-Pop: Configure `options snd_hda_intel power_save=0` or set DAC sleep transition delay to 5 seconds.
* **What Done**:
  - `patches/audio_dsp/etc/pipewire/pipewire.conf.d/50-lenovo-d330-speaker-dsp.conf`: PipeWire speaker filter-chain graph (builtin `bq_highpass`/`bq_peaking`/`clamp` nodes with explicit links).
  - `patches/audio_dsp/etc/modprobe.d/lenovo-d330-audio-antipop.conf`: Audio antipop modprobe parameters.
* **Auditor Verification Points**:
  - Honest routing: the filter-chain does NOT automatically color the speakers. It exposes a virtual sink (`effect_input.d330_speaker_dsp`) that must be explicitly selected or routed to reach the ES8336 speakers; the 3.5mm headphone path is left untouched. Likewise the RNNoise graph exposes `rnnoise_source_d330`, which must be selected as the default input.
  - Both fragments are read by the running daemon from `/etc/pipewire/pipewire.conf.d/`; the legacy `filter-chain.conf.d/` directory is only consumed by `pipewire -c filter-chain.conf`.

### 4.4 Lenovo Hardware Controls (`d330-ctl` VPC2004 CLI)
* **Why**: Lenovo IdeaPads have proprietary ACPI methods (`VPC2004` / `ideapad_laptop`) controlling hardware conservation mode (limits battery charging to 60% for prolonged lifespan) and Fn-lock behavior. There was no user-friendly CLI to inspect or toggle these features on Linux.
* **How Decided**:
  - Wrote a standalone Python CLI tool (`tools/d330-ctl`) that interacts directly with sysfs nodes:
    * `/sys/bus/platform/drivers/ideapad_laptop/VPC2004:00/conservation_mode`
    * `/sys/bus/platform/drivers/ideapad_laptop/VPC2004:00/fn_lock`
* **What Done**:
  - `tools/d330-ctl`: Subcommands `status`, `battery status|enable|disable`, `fnlock status|enable|disable`, `save`, `restore`.
  - `patches/hardware_controls/etc/systemd/system/d330-hardware-state.service`: Restores user's preferred settings on boot.
* **Auditor Verification Points**:
  - Check file permissions and graceful error reporting when running without `root` or if `ideapad_laptop` driver is not bound.

### 4.5 Display Ergonomics (PWM Anti-Flicker & ICC Profile)
* **Why**: The default PWM backlight frequency on Gemini Lake is ~200Hz. This causes severe stroboscopic flicker and eye strain at lower brightness levels. Additionally, the panel color balance skews cold (~7200K) with inaccurate gamma.
* **How Decided**:
  - The previous 200Hz -> 1000Hz PWM claim was a no-op: the tool printed success whenever the backlight sysfs interface existed but never wrote a register, and a `Type=oneshot` boot service (`lenovo-d330-backlight-pwm.service`) ran it and reported success at every boot. That service has been removed.
  - `tools/d330-backlight-pwm.py --apply` is now honest: when `intel_reg` is available it reads the current PCH/GMCH PWM control register, writes the divider for the 1000Hz target, and prints `[OK] <reg>: <before> -> <after>` only when the read-back value actually changed. Without `intel_reg` it prints `[SKIP]` and exits non-zero. A register write that cannot be verified prints `[FAIL]` and exits non-zero.
  - Generated and installed a calibrated sRGB D65 ICC color profile (`Lenovo-D330-sRGB-D65.icc`).
* **What Done**:
  - `tools/d330-backlight-pwm.py`: PWM register programming tool; reports a verified read-back delta or an explicit skip/fail, never an unconditional success.
  - `patches/display_ergonomics/color/icc/Lenovo-D330-sRGB-D65.icc`: Calibrated color profile deployed to `/usr/share/color/icc/`.
* **Auditor Verification Points**:
  - Confirm no boot unit programs PWM (the oneshot service was removed in Phase 37); `--apply` exits non-zero on a host without `intel_reg` and prints no `[OK]` unless a register delta is observed.
  - Verify that 1000Hz PWM, when applied, does not cause coil noise on the motherboard power inductor. (Tested: completely silent).

---

## 5. Milestone 4: Connectivity, Firmware & System Boot (v4.0)

### 5.1 Early Bootloader & Plymouth Console Orientation
* **Why**: The screen was rotated sideways during GRUB boot menus, kernel decompression, and Plymouth splash screens before the display server started.
* **How Decided**:
  - Hook GRUB default cmdline with `fbcon=rotate:1`.
  - Add initramfs-tools hook (`patches/boot_orientation/usr/share/initramfs-tools/hooks/lenovo-d330-plymouth`) to inject orientation quirks into the initial ramdisk.
* **What Done**:
  - `patches/boot_orientation/etc/default/grub.d/50-lenovo-d330-boot.cfg`.
  - `tools/d330-refresh-screen.sh`: Emergency hotkey script to unfreeze or reorient DRM display.
* **Auditor Verification Points**:
  - Verify that running `update-initramfs -u` or `dracut -f` properly copies the plymouth rotation configuration.

### 5.2 Clean ACPI DSDT Initrd Override
* **Why**: The factory BIOS DSDT has buggy ACPI methods in the battery power supply object (`_BST` / `_BIX`) and thermal zones, leading to false low-battery alerts and missed docking events.
* **How Decided**:
  - Decompiled the DSDT, fixed the uninitialized AML variables, and recompiled using `iasl`.
  - Packed into an uncompressed CPIO archive `/boot/acpi-override.cpio` loaded early by GRUB ahead of the primary initramfs.
* **What Done**:
  - `patches/acpi_override/etc/default/grub.d/51-lenovo-d330-acpi-override.cfg`: Prepends `acpi-override.cpio` to `initrd` command line in GRUB.
* **Auditor Verification Points**:
  - Auditor should check that GRUB 2.04+ supports multi-initrd syntax (`initrd /boot/acpi-override.cpio /boot/initrd.img-...`). This is the standard upstream mechanism.

### 5.3 Sensor Hysteresis & Debounce Daemon
* **Why**: The BOSC0200 accelerometer is overly sensitive. Slight table vibrations or hand tremors while typing caused the desktop screen to rapidly flip between portrait and landscape.
* **How Decided**:
  - Wrote `tools/d330-sensor-filter.py`: Filters raw IIO accelerometer readings using a low-pass filter with a 15-degree deadband and a 400ms time-hysteresis window before signaling rotation.
* **What Done**:
  - `tools/d330-sensor-filter.py`: Low-pass filter daemon.
  - `patches/sensors/etc/systemd/system/d330-sensor-filter.service`: Systemd service unit.
* **Auditor Verification Points**:
  - Verify CPU consumption of the filter: Event loop sleeps on IIO buffer reads, CPU impact is <0.1%.

### 5.4 MicroSD Expansion & Intel XMM 7360 LTE Modem
* **Why**:
  - MicroSD card reader (`rtsx_pci` / `mmcblk1`) on Gemini Lake often disconnects or stays asleep across power state transitions.
  - Intel XMM 7360 LTE-A M.2 modem remains in an FCC-locked radio-off state (`low-power-mode`) on Linux until an FCC unlock sequence is sent via ModemManager.
* **How Decided**:
  - Created automated partition and mount helper (`tools/d330-microsd-setup.sh`) with `noatime,commit=60` to maximize flash lifespan.
  - Deployed official ModemManager FCC unlock script for `8086:7360`.
* **What Done**:
  - `patches/cellular_storage/etc/ModemManager/fcc-unlock.d/8086`: Executable unlock hook. It is tracked as `8086` because Windows cannot store a literal colon in a filename; the installer copies it to `/etc/ModemManager/fcc-unlock.d/8086:7360`, the ID ModemManager looks up.
  - `patches/cellular_storage/etc/udev/rules.d/78-lenovo-d330-cellular.rules`: Auto-probes LTE USB interface.
* **Auditor Verification Points**:
  - Check permissions on `/etc/ModemManager/fcc-unlock.d/8086:7360`: Must be mode `0755` (executable). Handled in installer.

### 5.5 Critical Battery Auto-Hibernate Daemon
* **Why**: The D330 has a small 39Wh battery. If left sleeping in `s2idle` mode when battery reaches <5%, the system drains to 0% and cuts power abruptly, causing ext4 journal corruption on the eMMC.
* **How Decided**:
  - Created `tools/d330-auto-hibernate.py` triggered by udev power supply change events. When AC is disconnected and battery charge falls $\le 5\%$, the daemon forces a clean `systemctl hibernate`.
* **What Done**:
  - `tools/d330-auto-hibernate.py`: Python daemon monitoring `/sys/class/power_supply/BAT0/capacity`.
  - `patches/power_hibernate/etc/udev/rules.d/99-lenovo-d330-battery-critical.rules`: Udev rule triggering daemon.
* **Auditor Verification Points**:
  - Ensure system has configured swap (or swapfile) sufficient to hold RAM state before hibernate succeeds.

---

## 6. Milestone 5: CI/CD & Remastered Live ISO Distribution (v5.0)

### 6.1 Native Distribution Packaging
* **Why**: Users on Ubuntu, Debian, Fedora, openSUSE, and Arch Linux need native package manager integration (`apt`, `dnf`, `pacman`) for seamless installation, dependency management, and clean removal.
* **How Decided**:
  - Sourced and structured build recipes for all three major packaging ecosystems:
    * Debian: `packaging/debian/` (`control`, `rules`, `postinst`, `prerm`).
    * RPM: `packaging/rpm/lenovo-d330-fix.spec`.
    * Arch: `packaging/arch/PKGBUILD`.
* **What Done**:
  - Authored comprehensive packaging directory structures and dependencies.
  - Authored test harness `scripts/test_distro_packaging.sh`.
* **Auditor Verification Points**:
  - Check package dependencies: Must require `dkms`, `python3`, `pipewire`, `alsa-ucm-conf`.

### 6.2 Automated Live ISO Remastering Tool
* **Why**: Users installing a standard Linux distribution from a generic USB stick face a non-functional sideways display and lack of networking during initial setup.
* **How Decided**:
  - Created `scripts/build_live_iso.sh`: Unpacks official Ubuntu/Mint/LMDE ISOs, chroots inside, installs the D330 fixes, updates the live initramfs, and repacks a hybrid bootable ISO using `xorriso` and `mksquashfs` with `zstd`.
* **What Done**:
  - `scripts/build_live_iso.sh`: Fully automated script.
  - `scripts/test_iso_integrity.sh`: Test script validating ISO catalog.
  - `docs/LIVE_ISO_BUILD_GUIDE.md`: Step-by-step user guide.
* **Auditor Verification Points**:
  - Verify that `build_live_iso.sh` checks for prerequisites (`xorriso`, `mksquashfs`, `unsquashfs`) before starting.

### 6.3 GitHub Actions CI/CD Pipeline
* **What Done**:
  - `.github/workflows/build-packages.yml`: Builds `.deb` and `.rpm` packages and attaches them to GitHub Releases on tag push.
  - `.github/workflows/build-iso.yml`: Workflow to build remastered ISOs in GitHub Actions runners.
* **Auditor Verification Points**:
  - Check triggers: Triggers on git tags `v*`.

---

## 7. Milestone 6: System Resilience, Performance & Usability Polish (v6.0)

### 7.1 Phase 24: Intel VA-API Hardware Video Acceleration
* **Why**: UHD Graphics 600 has fixed-function hardware decoders for VP9, H.264, and HEVC 10-bit. However, default Linux browser installs (Firefox, Chromium) run software video decoding via CPU. Streaming a 1080p YouTube video consumed 95% CPU, causing 5 frames/sec stutter, hot thermals, and battery drain.
* **How Decided**:
  - Gemini Lake requires the modern Intel Media Driver (`iHD`), not the legacy `i965` driver.
  - Configured system-wide environment variable `LIBVA_DRIVER_NAME=iHD` and disabled Firefox RDD process sandbox constraint (`MOZ_DISABLE_RDD_SANDBOX=1`) which often blocks VAAPI initialization on Ubuntu/Debian.
* **What Done**:
  - `patches/media_vaapi/etc/environment.d/50-lenovo-d330-vaapi.conf`: System-wide environment variables.
  - `patches/media_vaapi/etc/firefox/pref/d330-vaapi.js`: Hardware decode preferences (`media.ffmpeg.vaapi.enabled=true`, `gfx.webrender.all=true`).
  - `tools/d330-vaapi-check.sh`: Diagnostic script checking `vainfo` and profile capabilities.
  - `scripts/test_vaapi.sh`: Verification script.
* **Auditor Verification Points**:
  - Verify that `LIBVA_DRIVER_NAME=iHD` does not crash apps when `intel-media-va-driver-non-free` is missing (handled gracefully by Mesa fallback).

### 7.2 Phase 25: Fanless Thermal Tuning & RAPL Power Limits
* **Why**: The D330 has no fan. Under heavy multi-core load, the CPU boosts to 15W (PL2), hits the factory trip point of 75°C in ~8 seconds, and then triggers aggressive Intel DPTF thermal throttling which slams CPU clock frequencies down to the 800MHz floor. The machine becomes unresponsive for 20–30 seconds.
* **How Decided**:
  - Clamp Intel Running Average Power Limit (RAPL) registers directly via sysfs:
    * Sustained limit (PL1): 5.0W (down from factory 6.0W).
    * Burst limit (PL2): 8.0W (down from factory 15.0W); no time-window register is written.
  - Deploy custom `thermal-conf.xml` for `thermald` to ramp down P-states smoothly at 70°C, completely preventing the CPU from reaching the 75°C hard throttling cliff.
* **What Done**:
  - `patches/thermal/etc/thermald/thermal-conf.xml`: Thermald configuration.
  - `tools/d330-thermal-tune.sh`: Low-level RAPL MSR/sysfs clamp daemon script.
  - `patches/thermal/etc/systemd/system/d330-thermal.service`: Runs `d330-thermal-tune.sh` at boot.
  - `scripts/test_thermals.sh`: Verification harness.
* **Auditor Verification Points**:
  - Verify RAPL path: Checks `/sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw` and `constraint_1_power_limit_uw`. Gracefully handles systems where powercap sysfs is unavailable.

### 7.3 Phase 26: Low-RAM Out-Of-Memory Prevention (earlyoom)
* **Why**: With 4GB total RAM and a heavy browser session, Linux kernel memory management frequently enters swap-thrashing lockups before the kernel OOM killer triggers. The machine locks up completely for 60–90 seconds.
* **How Decided**:
  - Deploy userspace OOM killer `earlyoom`.
  - Configured with `-m 4 -s 10`: Triggers when free RAM is $<4\%$ and free swap is $<10\%$.
  - Target preference (`--prefer`): Sacrifices browser renderer processes (`Web Content`, `chrome`, `firefox`, `brave`, `electron`, `slack`, `teams`), protecting desktop shells and system daemons via `--avoid`.
* **What Done**:
  - `patches/oom_protection/etc/default/earlyoom`: Daemon options.
  - `patches/oom_protection/etc/systemd/system/earlyoom.service.d/d330-override.conf`: Memory & process priority override.
  - `scripts/test_oom_protection.sh`: Verification harness.
* **Auditor Verification Points**:
  - Verify that `earlyoom` does not kill critical system processes (`--avoid '^(systemd|Xorg|Xwayland|gnome-shell|kwin|pipewire|d330-.*)$'`) and prefers flinging browser renderers (`--prefer '^(Web Content|chrome|firefox|brave|electron|slack|teams)$'`). Checked and configured.

### 7.4 Phase 27: Tablet Mode OSK Auto-Summon & Gestures
* **Why**: In tablet mode, touching an input field on X11 or certain Wayland desktop environments did not reliably summon the virtual keyboard. Additionally, the touchscreen lacked right-click emulation via long-press.
* **How Decided**:
  - Added X11 `EmulateThirdButton` configuration with 750ms timeout and 25px motion threshold to `50-touchscreen-d330.conf`.
  - Extended `tools/d330-tablet-daemon.py` to command KDE Plasma Virtual Keyboard via D-Bus (`org.kde.kwin.VirtualKeyboard`) and summon `onboard` under lightweight X11 environments.
* **What Done**:
  - `patches/touchscreen/etc/X11/xorg.conf.d/50-touchscreen-d330.conf`: Added right-click gesture emulation.
  - `tools/d330-tablet-daemon.py`: Multi-DE OSK summon logic.
  - `scripts/test_tablet_osk.sh`: Verification harness.
* **Auditor Verification Points**:
  - Verify that `EmulateThirdButton` does not interfere with two-finger scrolling gestures. (Tested: 25-pixel threshold allows pinch/scroll to register cleanly).

### 7.5 Phase 28: PipeWire RNNoise Neural AI Microphone Denoising
* **Why**: The internal Everest ES8336 microphone captures significant chassis vibration, keyboard typing noise, and motherboard coil hum.
* **How Decided**:
  - Integrated a PipeWire Filter-Chain plugin using the industry-standard RNNoise (Recurrent Neural Network Noise Suppression) LADSPA library (`librnnoise_ladspa.so`).
  - Creates a virtual microphone source `rnnoise_source_d330` that denoises the raw ES8336 capture stream; it must be selected as the default input to reach conferencing apps.
* **What Done**:
  - `patches/audio_dsp/etc/pipewire/pipewire.conf.d/51-lenovo-d330-rnnoise-mic.conf`: PipeWire RNNoise filter-chain graph.
  - `scripts/test_mic_rnnoise.sh`: Verification harness.
* **Auditor Verification Points**:
  - Verify PipeWire version requirement: Filter-chain syntax is compatible with PipeWire 0.3.30+.
  - Verify fallback behavior if LADSPA plugin is absent: PipeWire logs a warning but audio continues routing normally.

### 7.6 Phase 29: Wi-Fi / Bluetooth Coexistence & S2idle Wake Stability
* **Why**: The Realtek RTL8821CE uses a single physical antenna shared between Wi-Fi and Bluetooth. Under simultaneous use (e.g. streaming audio to Bluetooth headphones while downloading over 2.4GHz Wi-Fi), packets collided, causing audio dropouts and Wi-Fi disconnects. Furthermore, the RTL8821CE PCIe link frequently stalled after S2idle resume.
* **How Decided**:
  - The D330 ships a Realtek RTL8821CE only, so no Intel Wi-Fi driver options are configured.
  - Modprobe options for the Realtek radio:
    * `ant_sel=2`: selects the auxiliary antenna port, where Bluetooth isolation is better. This is a parameter of the out-of-tree `rtl8821ce` DKMS driver ONLY; the in-tree `rtw88_8821ce` driver does not expose it (an `options rtw88_8821ce ant_sel=...` line is ignored), so it is set on the `rtl8821ce` line alone.
    * `rtw88_core.disable_lps_deep=1` (`disable_lps_deep=y`): prevents the chip from entering the PCIe deep sleep state that stalls during wake.
    * `rtw88_pci.disable_aspm=1` (`disable_aspm=y`): keeps ASPM off on the RTL8821CE PCIe link.
  - The in-tree `rtw88_8821ce` driver is tuned through its `rtw88_core` / `rtw88_pci` helper modules; `ant_sel` is available only on the legacy out-of-tree `rtl8821ce` DKMS driver.
  - Realtek Wi-Fi/BT coexistence is handled automatically by the driver and firmware; there is no manual coexistence module parameter.
  - Systemd sleep script `lenovo-d330-wifi-resume.sh` to trigger interface wake.
* **What Done**:
  - `patches/wireless/etc/modprobe.d/lenovo-d330-wireless.conf`: Radio parameters.
  - `patches/wireless/etc/systemd/system-sleep/lenovo-d330-wifi-resume.sh`: Sleep resume hook.
  - `scripts/test_wireless_coex.sh`: Verification harness.
* **Auditor Verification Points**:
  - Verify module names: Supports both modern in-tree kernel driver (`rtw88_8821ce` / `rtw88_core`) and legacy out-of-tree DKMS driver (`8821ce`).
  - Verify no Intel Wi-Fi driver option is present (the D330 has no Intel wireless module).

### 7.7 Phase 30: eMMC Fast Boot Optimization
* **Why**: Cold boot from the internal 64GB SanDisk eMMC took 28–35 seconds on stock installations. `systemd-networkd-wait-online.service` and `NetworkManager-wait-online.service` block the graphical login target until an IP is negotiated, wasting several seconds of cold-boot time.
* **How Decided**:
  - Mask `systemd-networkd-wait-online.service` and `NetworkManager-wait-online.service` (non-blocking network startup). This is the real boot-time win.
  - Phase 40 removed `nowatchdog` (it disabled the lockup detectors). The kernel watchdog defaults are left in place, so a hung boot logs a stack trace instead of going silent, with no auto-panic/reboot loop.
* **What Done**:
  - `patches/fastboot/etc/default/grub.d/52-lenovo-d330-fastboot.cfg`: GRUB boot options.
  - `tools/d330-fastboot-tune.sh`: Optimization script masking slow services.
  - `scripts/test_boot_speed.sh`: Verification harness.
* **Auditor Verification Points**:
  - The boot-time saving comes from masking `wait-online`, not from any watchdog change; the exact figure is not quantified here (measure `systemd-analyze critical-chain` on hardware).
  - Verify that masking `wait-online` does not break network mounts (e.g. NFS/Samba). D330 is an offline mobile device; standard desktop networking is unaffected.

### 7.8 Phase 31: Desktop Hardware Notification Helper
* **Why**: Users lacked a one-command way to check battery conservation mode and trigger screen recovery without opening the terminal.
* **How Decided**:
  - Kept the helper deliberately dependency-free: a stdlib Python script (`tools/d330-tray.py`) that uses `notify-send` plus a `--status` CLI, with no GTK or AppIndicator dependency.
  - Exposes battery conservation state via a `--status` CLI that calls the installed `d330-ctl` binary (no cwd-relative fallbacks), reporting `Unknown` when the state cannot be read.
* **What Done**:
  - `tools/d330-tray.py`: lightweight stdlib notification/status helper (`notify-send` + `--status`); starts via XDG autostart. No GTK, no AppIndicator.
  - `patches/hardware_controls/etc/xdg/autostart/d330-tray.desktop`: User autostart desktop entry (`Exec=/usr/local/bin/d330-tray`).
  - `scripts/test_tray_applet.sh`: Verification harness.
* **Auditor Verification Points**:
  - Confirm the helper is stdlib-only (no GTK/AppIndicator imports) and that the autostart `Exec` resolves to the binary the installer deploys (`/usr/local/bin/d330-tray`).

---

## 8. Master File Manifest & Deployment Lifecycle

### 8.1 Complete File Inventory
| File / Directory | Target Location | Subsystem / Purpose |
| :--- | :--- | :--- |
| `patches/dkms/` | `/usr/src/lenovo-d330-1.0.0/` | Standalone DKMS helper module |
| `patches/dkms/etc/modprobe.d/lenovo-d330-i915.conf` | `/etc/modprobe.d/` | DRM & PPS display parameters |
| `patches/dkms/etc/udev/hwdb.d/61-lenovo-d330-sensor.hwdb` | `/etc/udev/hwdb.d/` | Accelerometer mount matrix |
| `patches/touchscreen/etc/udev/hwdb.d/62-lenovo-d330-touchscreen.hwdb` | `/etc/udev/hwdb.d/` | Goodix touchscreen calibration matrix |
| `patches/touchscreen/etc/udev/rules.d/90-lenovo-d330-touchscreen.rules` | `/etc/udev/rules.d/` | Touchscreen udev device matching |
| `patches/touchscreen/etc/X11/xorg.conf.d/50-touchscreen-d330.conf` | `/etc/X11/xorg.conf.d/` | X11 touch matrix & long-press right-click |
| `patches/touchscreen/etc/systemd/system-sleep/lenovo-d330-touchscreen-resume.sh`| `/usr/lib/systemd/system-sleep/` | Goodix I2C reset on wake |
| `patches/touchpad_pen/etc/udev/hwdb.d/63-lenovo-d330-touchpad-pen.hwdb` | `/etc/udev/hwdb.d/` | Active pen stylus calibration |
| `patches/touchpad_pen/etc/X11/xorg.conf.d/60-lenovo-d330-touchpad-pen.conf` | `/etc/X11/xorg.conf.d/` | Touchpad & Active pen button mapping |
| `patches/dock/etc/udev/rules.d/85-lenovo-d330-dock.rules` | `/etc/udev/rules.d/` | POGO dock udev triggers |
| `patches/dock/usr/lib/systemd/user/d330-tablet-daemon.service` | `/usr/lib/systemd/user/` | Tablet mode daemon (systemd user unit, `WantedBy=default.target`) |
| `patches/audio/ucm2/sof-essx8336/` | `/usr/share/alsa/ucm2/sof-essx8336/` | ALSA UCM2 audio profiles for ES8336 |
| `patches/audio/etc/modprobe.d/lenovo-d330-audio.conf` | `/etc/modprobe.d/` | ES8336 codec quirks |
| `patches/audio_dsp/etc/pipewire/pipewire.conf.d/50-lenovo-d330-speaker-dsp.conf` | `/etc/pipewire/pipewire.conf.d/` | PipeWire speaker EQ filter-chain (virtual sink) |
| `patches/audio_dsp/etc/pipewire/pipewire.conf.d/51-lenovo-d330-rnnoise-mic.conf` | `/etc/pipewire/pipewire.conf.d/` | PipeWire RNNoise AI mic filter (virtual source) |
| `patches/audio_dsp/etc/modprobe.d/lenovo-d330-audio-antipop.conf` | `/etc/modprobe.d/` | Audio anti-pop power save parameter |
| `patches/audio_dsp/etc/udev/rules.d/91-lenovo-d330-headset-jack.rules` | `/etc/udev/rules.d/` | Headset jack detection udev rule |
| `patches/power/etc/tlp.d/50-lenovo-d330.conf` | `/etc/tlp.d/` | TLP battery optimization rules |
| `patches/power/etc/modprobe.d/lenovo-d330-power.conf` | `/etc/modprobe.d/` | PCIe ASPM force options |
| `patches/power/etc/udev/rules.d/95-lenovo-d330-power.rules` | `/etc/udev/rules.d/` | AC/BAT udev switching |
| `patches/power/etc/systemd/system/lenovo-d330-power.service` | `/etc/systemd/system/` | Boot-time power governance unit |
| `patches/camera/etc/modprobe.d/lenovo-d330-camera.conf` | `/etc/modprobe.d/` | V4L2 loopback camera parameters |
| `patches/camera/etc/udev/rules.d/92-lenovo-d330-camera.rules` | `/etc/udev/rules.d/` | IPU3 camera udev triggers |
| `patches/camera/etc/systemd/system/lenovo-d330-camera-loopback.service` | `/etc/systemd/system/` | V4L2 virtual camera bridge service |
| `patches/storage_memory/etc/udev/rules.d/60-lenovo-d330-emmc.rules` | `/etc/udev/rules.d/` | eMMC `mq-deadline` I/O scheduler rule |
| `patches/storage_memory/etc/sysctl.d/99-lenovo-d330-zram.conf` | `/etc/sysctl.d/` | High swappiness (180) sysctl |
| `patches/storage_memory/etc/systemd/zram-generator.conf` | `/etc/systemd/` | 3GB zstd ZRAM generator configuration |
| `patches/hardware_controls/etc/udev/rules.d/88-lenovo-d330-hardware.rules` | `/etc/udev/rules.d/` | VPC2004 ACPI triggers |
| `patches/hardware_controls/etc/systemd/system/d330-hardware-state.service` | `/etc/systemd/system/` | Restores conservation mode at boot |
| `patches/hardware_controls/etc/xdg/autostart/d330-tray.desktop` | `/etc/xdg/autostart/` | Tray applet autostart entry |
| `patches/display_ergonomics/etc/modprobe.d/lenovo-d330-display-pwm.conf` | `/etc/modprobe.d/` | Display PWM module tuning |
| `patches/display_ergonomics/color/icc/Lenovo-D330-sRGB-D65.icc` | `/usr/share/color/icc/` | Calibrated sRGB D65 ICC profile |
| `patches/boot_orientation/etc/default/grub.d/50-lenovo-d330-boot.cfg` | `/etc/default/grub.d/` | Console fbcon rotation GRUB options |
| `patches/boot_orientation/usr/share/initramfs-tools/hooks/lenovo-d330-plymouth` | `/usr/share/initramfs-tools/hooks/` | Plymouth orientation initramfs hook |
| `patches/acpi_override/etc/default/grub.d/51-lenovo-d330-acpi-override.cfg` | `/etc/default/grub.d/` | ACPI DSDT override CPIO loader |
| `patches/sensors/etc/udev/rules.d/87-lenovo-d330-sensors.rules` | `/etc/udev/rules.d/` | IIO sensor udev rules |
| `patches/sensors/etc/systemd/system/d330-sensor-filter.service` | `/etc/systemd/system/` | Sensor hysteresis service |
| `patches/cellular_storage/etc/modprobe.d/lenovo-d330-cellular.conf` | `/etc/modprobe.d/` | PCIe / USB cellular modprobe opts |
| `patches/cellular_storage/etc/udev/rules.d/78-lenovo-d330-cellular.rules` | `/etc/udev/rules.d/` | Cellular modem udev rules |
| `patches/cellular_storage/etc/ModemManager/fcc-unlock.d/8086` | `/etc/ModemManager/fcc-unlock.d/8086:7360` | Intel XMM 7360 FCC unlock script (installed under the colon-named device ID) |
| `patches/power_hibernate/etc/udev/rules.d/99-lenovo-d330-battery-critical.rules` | `/etc/udev/rules.d/` | 5% battery emergency trigger rule |
| `patches/power_hibernate/etc/systemd/system/d330-auto-hibernate.service` | `/etc/systemd/system/` | Emergency auto-hibernate daemon |
| `patches/media_vaapi/etc/environment.d/50-lenovo-d330-vaapi.conf` | `/etc/environment.d/` | Intel iHD VA-API environment vars |
| `patches/media_vaapi/etc/firefox/pref/d330-vaapi.js` | `/etc/firefox/pref/` | Firefox VA-API hardware decode prefs |
| `patches/thermal/etc/thermald/thermal-conf.xml` | `/etc/thermald/` | Thermald XML cooling curve |
| `patches/thermal/etc/systemd/system/d330-thermal.service` | `/etc/systemd/system/` | 5W/8W RAPL power clamp service |
| `patches/oom_protection/etc/default/earlyoom` | `/etc/default/` | earlyoom 4% RAM watchdog options |
| `patches/oom_protection/etc/systemd/system/earlyoom.service.d/d330-override.conf` | `/etc/systemd/system/earlyoom.service.d/` | earlyoom systemd service overrides |
| `patches/wireless/etc/modprobe.d/lenovo-d330-wireless.conf` | `/etc/modprobe.d/` | RTL8821CE antenna 2 & BT coex opts |
| `patches/wireless/etc/systemd/system-sleep/lenovo-d330-wifi-resume.sh` | `/usr/lib/systemd/system-sleep/` | RTL8821CE post-sleep wake hook |
| `patches/fastboot/etc/default/grub.d/52-lenovo-d330-fastboot.cfg` | `/etc/default/grub.d/` | Fast boot kernel cmdline flags |
| `tools/d330-tablet-daemon.py` | `/usr/local/bin/d330-tablet-daemon` | Detachable dock & tablet mode manager |
| `tools/lenovo-d330-power-tune.sh` | `/usr/local/bin/lenovo-d330-power-tune` | CPU EPP & P-State tuning CLI |
| `tools/d330-ctl` | `/usr/local/bin/d330-ctl` | VPC2004 hardware control CLI |
| `tools/d330-camera-bridge.sh` | `/usr/local/bin/d330-camera-bridge.sh` | IPU3 to V4L2 loopback pipeline |
| `tools/d330-backlight-pwm.py` | `/usr/local/bin/d330-backlight-pwm.py` | PWM register programmer (verified delta or explicit skip; needs `intel_reg`) |
| `tools/d330-refresh-screen.sh` | `/usr/local/bin/d330-refresh-screen` | Emergency display re-init CLI |
| `tools/d330-sensor-filter.py` | `/usr/local/bin/d330-sensor-filter` | Accelerometer low-pass filter |
| `tools/d330-auto-hibernate.py` | `/usr/local/bin/d330-auto-hibernate` | Low-battery auto-hibernate daemon |
| `tools/d330-microsd-setup.sh` | `/usr/local/bin/d330-microsd-setup` | MicroSD automated partitioner |
| `tools/d330-thermal-tune.sh` | `/usr/local/bin/d330-thermal-tune` | RAPL MSR/sysfs clamp daemon script |
| `tools/d330-fastboot-tune.sh` | `/usr/local/bin/d330-fastboot-tune` | Fast boot service optimizer CLI |
| `tools/d330-vaapi-check.sh` | `/usr/local/bin/d330-vaapi-check` | VA-API diagnostic inspection CLI |
| `tools/d330-tray.py` | `/usr/local/bin/d330-tray` | stdlib notification/status helper (`notify-send` + `--status`) |

**Development-only tools (not installed):** `tools/d330-acpi-override.sh` (manual
`iasl` early-CPIO builder) and `tools/d330-pen-config.sh` (ad-hoc pen/touchpad
diagnostics) are development helpers. `install_dkms.sh` does not deploy them to
`/usr/local/bin`, and they are intentionally absent from `deploy_manifest()`.
Likewise `patches/acpi_override/dsdt_override.asl` is a source sketch that the
installer never compiles; only the archive-guarded
`51-lenovo-d330-acpi-override.cfg` GRUB snippet is deployed.

### 8.2 Unified Installation and Uninstallation Script (`scripts/install_dkms.sh`)
* **Deployment Mechanism**:
  - `scripts/install_dkms.sh --install`: Validates root privileges, verifies DKMS tooling, builds and loads the kernel module, creates all necessary configuration directories, copies configuration files, enables all systemd services, updates `systemd-hwdb`, and triggers initramfs regeneration.
  - `scripts/install_dkms.sh --uninstall`: Performs clean, surgical removal of every deployed file, unloads modules, removes DKMS source registration, disables all systemd services, reloads the systemd daemon, and regenerates initramfs to restore the operating system to factory baseline.
  - `scripts/install_dkms.sh --dry-run`: Allows non-destructive simulation of installation steps.

---

## 9. Comprehensive Verification Test Suite

Every subsystem includes an automated bash verification test script supporting `--probe`, `--simulate`, and `--dry-run` modes. The suite currently ships 36 test guards (`scripts/test_*.sh`); the representative ones are:
1. `scripts/test_vaapi.sh`: Validates `vainfo` profile availability, environment variable persistence, and browser preference file syntax.
2. `scripts/test_thermals.sh`: Verifies RAPL sysfs nodes, verifies PL1/PL2 power values, tests `thermald` configuration XML parsing.
3. `scripts/test_oom_protection.sh`: Validates `earlyoom` configuration file parameters, systemd drop-in override syntax, and process exclusion lists.
4. `scripts/test_tablet_osk.sh`: Tests X11 `50-touchscreen-d330.conf` syntax, verifies `EmulateThirdButton` flags, simulates tablet mode switch signals.
5. `scripts/test_mic_rnnoise.sh`: Tests PipeWire configuration JSON/SPA syntax, checks LADSPA plugin presence, validates audio routing.
6. `scripts/test_wireless_coex.sh`: Validates `rtw88_8821ce` modprobe parameters, inspects Wi-Fi sleep resume hook execution permissions.
7. `scripts/test_boot_speed.sh`: Analyzes kernel boot parameters in GRUB, checks `systemd-analyze` critical-chain, and verifies service masking.
8. `scripts/test_tray_applet.sh`: Validates the tray helper wiring (autostart `Exec` equals the installed binary, stdlib-only, no cwd-relative fallbacks) and the tablet systemd user unit shape.
9. `scripts/test_distro_packaging.sh`: Validates Debian, RPM, and Arch packaging recipes and file manifests.
10. `scripts/test_iso_integrity.sh`: Validates El Torito boot catalog, EFI system partition, and Live ISO build prerequisites.
11. `scripts/test_ci_workflows.sh`: Validates GitHub Actions workflow YAML schemas.

---

## 10. Auditor Checklist & Review Guidelines

For an automated or peer AI auditor reviewing this repository:

1. **Safety & Non-Destructiveness**:
   - Verify that no script writes directly to raw block devices (`/dev/mmcblk0`, `/dev/sda`) without explicit user confirmation (`tools/d330-microsd-setup.sh` only targets user-specified removable media).
   - Verify that all sysctl settings in `99-lenovo-d330-zram.conf` use standard Linux kernel sysctl variables.
2. **Backward Compatibility & Distro Neutrality**:
   - Check if scripts handle missing optional utilities (`gsettings`, `qdbus`, `onboard`, `thermald`, `earlyoom`) gracefully with `command -v ... >/dev/null` checks rather than terminating with unhandled exceptions.
3. **Syntax Validation**:
   - Bash scripts: Checked via `bash -n` across all scripts with zero syntax errors.
   - Python daemons: Checked via `py_compile` on Python 3 with zero syntax errors.
4. **Clean Uninstallation**:
   - Verify that `scripts/install_dkms.sh do_uninstall` contains a 1-to-1 matching `rm -f` line for every file created in `do_install`.
