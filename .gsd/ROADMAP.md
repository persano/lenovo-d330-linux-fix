# ROADMAP: Lenovo D330-10IGL Linux Parity Project

## Milestone 1: Display & Power Parity (v1.0) - [COMPLETED]

*Archived to [`.gsd/milestones/v1.0-ROADMAP.md`](milestones/v1.0-ROADMAP.md)*

- [x] Phase 0: Project & Repository Setup (`7e4b76e`)
- [x] Phase 1: Community Research & Prior Art Ingestion (`a60bdf1`)
- [x] Phase 2: Official Lenovo Windows Driver Baseline Acquisition (`c489f88`)
- [x] Phase 3: Hardware Telemetry & ACPI Extraction (`d09d0c3`)
- [x] Phase 4: Differential Analysis & Reverse Engineering (`d5f20bc`)
- [x] Phase 5: Patch Generation & DKMS Delivery (`7c313fb`)

---

## Milestone 2: Peripheral Parity & Tablet Usability (v2.0) - [COMPLETED]

*Archived to [`.gsd/milestones/v2.0-ROADMAP.md`](milestones/v2.0-ROADMAP.md)*

- [x] Phase 6: Touchscreen & Active Pen Calibration (`4126a9a`)
- [x] Phase 7: Detachable Dock & Tablet Mode Daemon (`bb7b4c5`)
- [x] Phase 8: Audio & Microphone UCM Profiles (`b2cb1e7`)
- [x] Phase 9: Battery Life & Power Governors (`1858351`)

---

## Milestone 3: Vision, Ergonomics & Multimedia (v3.0) - [COMPLETED]

*Archived to [`.gsd/milestones/v3.0-ROADMAP.md`](milestones/v3.0-ROADMAP.md)*

- [x] Phase 10: Intel IPU3 Dual Camera Pipeline
- [x] Phase 11: 4GB RAM & 64GB eMMC Storage Optimization
- [x] Phase 12: Audio Refinements (Dolby DSP Curve & Anti-Pop Jack Delay)
- [x] Phase 13: Lenovo Hardware Controls (`ideapad_laptop` VPC2004)
- [x] Phase 14: Display Ergonomics (Backlight PWM Anti-Flicker & ICC Profile)

---

## Milestone 4: Connectivity, Firmware & System Boot (v4.0) - [COMPLETED]

*Archived to [`.gsd/milestones/v4.0-ROADMAP.md`](milestones/v4.0-ROADMAP.md)*

- [x] Phase 15: Early Bootloader, Console & Plymouth Orientation
- [x] Phase 16: ACPI DSDT Clean Initrd Override
- [x] Phase 17: Sensor Hysteresis & Ambient Light Sensor (ALS) Auto-Dimming
- [x] Phase 18: Touchpad & Active Pen Gestures Tuning
- [x] Phase 19: MicroSD Storage Expansion & Modular Cellular LTE
- [x] Phase 20: Critical Low-Battery Auto-Hibernate Daemon

---

## Milestone 5: CI/CD & Remastered Live ISO Distribution (v5.0) - [COMPLETED]

*Archived to [`.gsd/milestones/v5.0-ROADMAP.md`](milestones/v5.0-ROADMAP.md)*

- [x] Phase 21: Native Distribution Packaging (.deb, .rpm, PKGBUILD)
- [x] Phase 22: Automated Live ISO Remaster Build Harness
- [x] Phase 23: GitHub Actions CI/CD Release Pipeline

---

## Milestone 6: System Resilience, Performance & Usability Polish (v6.0) - [COMPLETED]

*Archived to [`.gsd/milestones/v6.0-ROADMAP.md`](milestones/v6.0-ROADMAP.md)*

- [x] Phase 24: Intel VA-API Hardware Video Acceleration (iHD / Firefox / Chromium)
- [x] Phase 25: Fanless Thermal Tuning & RAPL Power Limits (PL1 5.0W, PL2 8.0W, thermald)
- [x] Phase 26: Out-Of-Memory Prevention (earlyoom on 4GB RAM)
- [x] Phase 27: Tablet Mode OSK Auto-Summon & Long-Press Right-Click
- [x] Phase 28: PipeWire RNNoise Neural AI Microphone Denoising
- [x] Phase 29: Wi-Fi & Bluetooth Coexistence & S2idle Sleep Stability
- [x] Phase 30: Fast Boot Optimization for eMMC Storage
- [x] Phase 31: Desktop GUI System Tray Hardware Applet (`d330-tray.py`)

---

## [ACTIVE] Milestone 7: v7.0 Pre-Deployment Audit Remediation

- [x] Phase 32: Data-Loss & Boot Safety Guards (Audit C1, C2) (completed 2026-10-08)
- [ ] Phase 33: Low-Battery Hibernate Feasibility (Audit C3)
- [ ] Phase 34: Deliver the Actual PPS / Display Resume Fix (Audit C4)
- [ ] Phase 35: Installer & Uninstaller Symmetry (Audit M1, M2, M11, N6)
- [ ] Phase 36: Desktop Session Wiring — Tray Applet & Tablet Daemon (Audit M3, M6)
- [ ] Phase 37: No-Op Tools Made Real or Removed — PWM & Sensor Filter (Audit M4, M5)
- [ ] Phase 38: PipeWire DSP Activation (Audit M7)
- [ ] Phase 39: udev / hwdb / Wireless Match Correctness (Audit M8, M9, M10, M15, M16)
- [ ] Phase 40: Power Stack Reconciliation (Audit M13, M14)
- [ ] Phase 41: Test Harness Trustworthiness (Audit M12, N8)
- [ ] Phase 42: Documentation Parity & Repository Polish (Audit M17, N1–N5, N7, N9, N10)

### Phase 32: Data-Loss & Boot Safety Guards

**Goal**: Eliminate the two paths that can destroy the eMMC root filesystem or hang systemd at boot.
**Depends on**: Nothing (first phase of Milestone 7)
**Success Criteria** (what must be TRUE):

  1. `--format` on a device with a mounted partition aborts before any write
  2. fstab line parses under `systemd-analyze verify`
  3. `--dry-run` prints the guard outcomes.

**Plans**: 3/3 plans executed

Plans:
**Wave 1**

- [x] 32-01-PLAN.md — Explicit device selection and the pre-write guard chain (audit C1), plus the PATH-shim guard suite

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 32-02-PLAN.md — fstab boot safety: locked nofail options, verify-before-append, rollback trap, duplicate refusal (audit C2)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 32-03-PLAN.md — Honest `--mount-home` stub, success-line gating, harness Wave 0 integration

- **Audit Ref**: C1, C2.
- **Components**:
  * `tools/d330-microsd-setup.sh:55-66` — stop auto-substituting `TARGET_DEV` to "any non-`mmcblk0` device"; require explicit `--device /dev/...`.
  * `tools/d330-microsd-setup.sh:88-99` — add three guards before `parted`/`mkfs`: (a) `lsblk -nr -o MOUNTPOINT` must be empty, (b) `findmnt -n -o SOURCE /` must not be a prefix of `TARGET_DEV`, (c) interactive `type yes` confirmation. Remove `-F` from `mkfs.ext4` after (a) is in place.
  * `tools/d330-microsd-setup.sh:95` — replace `sleep 1` with `partprobe "$TARGET_DEV"; udevadm settle`.
  * `tools/d330-microsd-setup.sh:111-112` — fstab entry gains `nofail,x-systemd.device-timeout=10s`.
  * `tools/d330-microsd-setup.sh:124-127` — `--mount-home` is a stub that prints "Storage expansion task complete"; either implement or exit non-zero with a clear "not implemented".

### Phase 33: Low-Battery Hibernate Feasibility

**Goal**: Make the 5% emergency hibernate actually able to complete, or degrade safely instead of silently failing.
**Depends on**: Phase 32
**Success Criteria** (what must be TRUE):

  1. `systemctl hibernate` on the target returns 0 with a resume device present
  2. `d330-auto-hibernate --dry-run` reports the swap situation
  3. service is `enabled` after `--install`.

**Plans**: 3/3 plans executed

Plans:
**Wave 1**

- [x] 33-01-PLAN.md — Daemon honest degradation: swap-situation report, refuse-and-degrade on zram-only, ExecStart fix, fixture guard suite

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 33-02-PLAN.md — Disk-backed resume swap: swapfile unit + resume cmdline template, installer activation with mkconfig verify, enablement ×3, uninstall symmetry

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 33-03-PLAN.md — Subsystem README + docs anchors, on-device acceptance of SC1/SC2/SC3 with R1 initramfs evidence (deferred-to-UAT)

- **Audit Ref**: C3, M2 (partial).
- **Components**:
  * `tools/d330-auto-hibernate.py:47-48` — add `has_non_zram_swap()` reading `/proc/swaps`; refuse `systemctl hibernate` when only zram exists, fall back to `sync` + `systemctl suspend`, log `[ERROR]` explaining why.
  * New: disk-backed resume swap. Choose one in Phase 33 planning: a 4 GB `/var/swapfile` unit (`swapfile.service`-style oneshot) shipped as a new `patches/power_hibernate/` asset, **or** an explicit documented decision that hibernate is unsupported on this device and the daemon must be removed rather than left as a false safety net.
  * `patches/power_hibernate/etc/systemd/system/d330-auto-hibernate.service:4` — `Type=oneshot` for a checker that exits promptly is correct; confirm and document. If a long-running monitor is chosen instead, switch to `Type=simple`.
  * `scripts/install_dkms.sh:281-284` + `packaging/debian/postinst` + `packaging/rpm/lenovo-d330-fix.spec %post` — `systemctl enable d330-auto-hibernate.service` (currently copied, never enabled).
  * `patches/power_hibernate/etc/udev/rules.d/99-lenovo-d330-battery-critical.rules:4` — `ATTR{capacity}=="[0-5]"` is a udev glob (single char 0-5) and is correct; add a comment so it is not "fixed" into a regex later.

### Phase 34: Deliver the Actual PPS / Display Resume Fix

**Goal**: The recommended install path must produce the 600 ms panel power-cycle clamp and the DMI orientation quirk it advertises, or stop advertising them.
**Depends on**: Phase 33
**Success Criteria** (what must be TRUE):

  1. `dmesg | grep lenovo_d330_fix` shows a DMI match on hardware
  2. `scripts/test_resume_loop.sh` passes 5 cycles
  3. README claims match observed behaviour.

**Plans**: TBD

- **Audit Ref**: C4, N3, M17 (partial).
- **Components**:
  * `scripts/install_dkms.sh` — new optional `--kernel-src /usr/src/linux` step applying `patches/d330_display_resume_fix.patch` with `patch -p1 --dry-run` first; warn (do not fail) when the hunk context does not match the running kernel.
  * `patches/dkms/lenovo-d330-fix/lenovo_d330_fix.c:97-118` — current `PM_POST_SUSPEND` handler sleeps *after* the panel is re-energised and only when elapsed < 600 ms (never true in practice). Either move the delay to `PM_SUSPEND_PREPARE`/pre-modeset where it can affect TCON sequencing, or reduce the module to an honest DMI-matched banner + `dmesg` breadcrumb and document it as such.
  * `patches/dkms/etc/systemd/system/lenovo-d330-resume.service:9` — `ExecStart` only `echo`s connector status. Either implement a real recovery (DRM connector detect + forced modeset) or delete the unit and its enable/disable pair.
  * `README.md:54-67` — "Option 1 ... Suspend and resume will now work reliably" must state exactly what Option 1 does (`i915 enable_psr=0 enable_fbc=0` + DKMS module) and that the PPS clamp needs Option 2.
  * `patches/boot_orientation/etc/default/grub.d/50-lenovo-d330-boot.cfg:7` — `video=efifb:nobgrt` is not a documented `efifb` option; remove it. `CHANGES_AUDIT.md` §2.2 claims `video=eDP-1:panel_orientation=right_side_up` / `video=DSI-1:...` are shipped — they are not; either add them or correct the doc.
  * `patches/dkms/lenovo-d330-fix/Makefile`, `dkms.conf` — add `BUILT_MODULE_LOCATION[0]="."` and a `MAKE_MATCH[0]` guard.

### Phase 35: Installer & Uninstaller Symmetry

**Goal**: `--install` and `--uninstall` must be exact inverses, and deployed configuration must actually take effect.
**Depends on**: Phase 34
**Success Criteria** (what must be TRUE):

  1. install → uninstall → `find /etc /usr/local/bin /usr/share/alsa -name '*d330*' -o -name 'lenovo-d330*'` returns empty
  2. `systemctl is-enabled` on all 9 units returns `enabled` after install.

**Plans**: TBD

- **Audit Ref**: M1, M2, M11, N6.
- **Components**:
  * `scripts/install_dkms.sh` — run `update-grub` (fallback `grub-mkconfig -o /boot/grub/grub.cfg`) after touching `etc/default/grub.d/` in **both** `do_install()` and `do_uninstall()`; currently 0 hits for `update-grub`/`grub-mkconfig` in the file.
  * `scripts/install_dkms.sh:470` — `check_prerequisites()` runs before dispatch, so `--uninstall` hard-fails without `dkms`/`make`/`gcc`. Skip build-tool checks for `--uninstall`; skip the `EUID` check for `--uninstall` too (rescue-shell use).
  * `scripts/install_dkms.sh:286-293` — enable all deployed units: add `d330-auto-hibernate.service`, `lenovo-d330-camera-loopback.service` (7 of 9 enabled today). Mirror in `packaging/debian/postinst` (6 today) and the RPM `%post` (3 today).
  * `scripts/install_dkms.sh:399` — `rm -rf /etc/systemd/system/earlyoom.service.d` deletes foreign drop-ins; replace with `rm -f .../d330-override.conf` + `rmdir ... || true`.
  * `scripts/install_dkms.sh` uninstall block — add `rm -f /etc/d330-hardware-state.json` (written by `d330-hardware-state.service` `ExecStop`, never removed), `systemctl unmask systemd-networkd-wait-online.service NetworkManager-wait-online.service`, and the `dracut -f` branch that install has but uninstall lacks.
  * `scripts/install_dkms.sh:213,318,322` — silent `[ -d /etc/thermald ]`, `[ -d /etc/tlp.d ]`, `[ -d /usr/share/color/icc ]` skips; log a `WARN` naming the missing package.
  * `scripts/install_dkms.sh` — add a `--verify` mode that diffs deployed paths against the manifest so symmetry is machine-checked, not eyeballed.

### Phase 36: Desktop Session Wiring — Tray Applet & Tablet Daemon

**Goal**: Both user-facing helpers must run in the user's graphical session, not as a context-less root system service.
**Depends on**: Phase 35
**Success Criteria** (what must be TRUE):

  1. `scripts/test_tray_applet.sh` fails when the binary name is wrong
  2. dock/undock visibly toggles orientation + OSK in a live GNOME session.

**Plans**: TBD

- **Audit Ref**: M3, M6, N7.
- **Components**:
  * `patches/hardware_controls/etc/xdg/autostart/d330-tray.desktop:5` — `Exec=/usr/local/bin/d330-tray.py` does not exist; installer deploys `/usr/local/bin/d330-tray` (`scripts/install_dkms.sh:258-260`). Fix path.
  * `tools/d330-tray.py` — currently imports no GTK and only prints + `notify-send` (`:42-50`). Implement a real StatusNotifier/AppIndicator menu (conservation, Fn-lock, rotation lock, screen refresh) or downgrade `CHANGES_AUDIT.md` §7.8 to "notification helper".
  * `patches/dock/etc/systemd/system/d330-tablet-daemon.service` — no `User=`, no `DISPLAY`, no `DBUS_SESSION_BUS_ADDRESS`; every `gsettings`/`xinput`/`xrandr`/`qdbus` call in `tools/d330-tablet-daemon.py:120-160` fails silently. Move to a user unit (`default.target`) or add `Environment=DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%U/bus` plus `User=`.
  * `tools/d330-tablet-daemon.py:101-102` — dead loop (`for sw_file in ...: pass`); `:45-49` `run_command` swallows failures so `:134/:162` log "settings applied successfully" unconditionally. Propagate failure into the log.
  * `tools/d330-tray.py:22,28,32` — cwd-relative `tools/d330-ctl` / `tools/d330-refresh-screen.sh` fallbacks; resolve against the installed `/usr/local/bin` names only.
  * `patches/hardware_controls/etc/xdg/autostart/d330-tray.desktop` — generic `Icon=preferences-system`, redundant `X-GNOME-Autostart-enabled` (N7).

### Phase 37: No-Op Tools Made Real or Removed — PWM & Sensor Filter

**Goal**: Stop reporting success for operations that perform no write.
**Depends on**: Phase 36
**Success Criteria** (what must be TRUE):

  1. `systemctl status d330-sensor-filter` stays `active (running)` for > 60 s
  2. `--apply` for PWM reports a verifiable register delta or is removed.

**Plans**: TBD

- **Audit Ref**: M4, M5, M17 (partial).
- **Components**:
  * `tools/d330-backlight-pwm.py:35-43` — `apply_pwm_tuning()` only checks `/sys/class/backlight/<x>` exists and prints `[OK]`. Implement real GMCH/PCH `BLC_PWM_CTL` divider programming (via `intel_reg` or DRM property), **or** delete `patches/display_ergonomics/etc/systemd/system/lenovo-d330-backlight-pwm.service` and correct `CHANGES_AUDIT.md` §4.5.
  * `tools/d330-sensor-filter.py:54` — `for _ in range(5)` with `time.sleep(0.2)` exits after 1 s, rc 0; `d330-sensor-filter.service` is `Type=simple` + `Restart=on-failure` so the unit goes dead permanently. Replace with a `while True` loop.
  * `tools/d330-sensor-filter.py` — never reads `in_accel_{x,y,z}_raw` and never signals a rotation decision; implement the 15-degree deadband + 400 ms hysteresis claimed in `CHANGES_AUDIT.md` §5.3, or drop the accelerometer claim and keep only ALS smoothing.
  * `tools/d330-sensor-filter.py:56` — `in_illuminance_raw` does not exist on many ALS devices; fall back to `in_illuminance_input`.
  * `scripts/test_display_ergonomics.sh:67,89` and `scripts/test_sensor_als.sh:55-56` — currently `\|\| true` + unconditional `log_ok`; must assert on real state.

### Phase 38: PipeWire DSP Activation

**Goal**: Speaker EQ and RNNoise mic must load in the running PipeWire daemon with valid graph definitions.
**Depends on**: Phase 37
**Success Criteria** (what must be TRUE):

  1. `pw-dump | grep -E 'd330_speaker_dsp|rnnoise_source_d330'` shows both nodes loaded after a daemon restart
  2. removing `librnnoise_ladspa.so` produces a non-zero test result.

**Plans**: TBD

- **Audit Ref**: M7.
- **Components**:
  * Deploy target: `scripts/install_dkms.sh:306-313` copies to `/etc/pipewire/filter-chain.conf.d/`. PipeWire's own docs state `filter-chain.conf.d` fragments are consumed only by `pipewire -c filter-chain.conf`; to run inside the server they must be under `pipewire.conf.d/`. Move both files (and the matching uninstall lines `:416-417`).
  * `patches/audio_dsp/etc/pipewire/filter-chain.conf.d/50-lenovo-d330-speaker-dsp.conf:6,19,32` — `label = biquad` is not a valid builtin label (valid: `bq_lowpass`, `bq_highpass`, `bq_peaking`, ...); `"Type" = "Highpass"` / `"Peaking"` is not a control (biquads expose `Freq`, `Q`, `Gain` only).
  * Same file `:43-50` — `label = limiter` does not exist among builtin filters; replace with `noisegate`/`clamp` or remove.
  * Same file — 4 nodes with no `links`, no `inputs`, `outputs`; PipeWire only omits links for single-filter graphs. Split to one node per file or declare links explicitly.
  * Routing: the sink is a standalone `media.class = "Audio/Sink"` (`:65`), so EQ is never applied to the hardware speaker unless manually routed. Decide: wireplumber `wireplumber.conf.d` link to the ES8336 sink, or drop the "colors only the speakers" claim in `CHANGES_AUDIT.md` §4.3.
  * `patches/audio_dsp/.../51-lenovo-d330-rnnoise-mic.conf:11-14` — `"VAD Grace Period (ms)"` and `"Retroactive VAD Grace (ms)"` do not exist in older `librnnoise_ladspa.so` builds; tolerate their absence (separate file per version or a documented package dependency on `rnnoise-ladspa`).
  * `scripts/test_mic_rnnoise.sh:46,65` — `--dry-run` is echo-only and the missing-plugin path only prints `[INFO]` then exits 0; must fail.

### Phase 39: udev / hwdb / Wireless Match Correctness

**Goal**: Every udev rule and hwdb entry must match real device strings on the target, and every modprobe option must land on a module that exists.
**Depends on**: Phase 38
**Success Criteria** (what must be TRUE):

  1. `udevadm test` output on hardware shows each rule matching
  2. `modprobe -s rtw88_8821ce` reflects the intended parameters
  3. `scripts/test_wireless_coex.sh` fails when the module name is wrong.

**Plans**: TBD

- **Audit Ref**: M8, M9, M10, M15, M16.
- **Components**:
  * `patches/wireless/etc/modprobe.d/lenovo-d330-wireless.conf:6` — `options rtl8821ce ...` matches neither in-tree `rtw88_8821ce` nor out-of-tree `8821ce` (both names listed in `CHANGES_AUDIT.md` §7.6). Emit both spellings; drop `fwlps`/`ips` unless confirmed as in-tree params.
  * Same file `:11-12` — `bt_coex_active` / `power_scheme` are set on `iwlwifi`/`iwlmvm`, hardware the D330 does not have. Real-Realtek BT coexistence is therefore unconfigured despite §7.6 claiming it.
  * `patches/dkms/etc/udev/hwdb.d/61-lenovo-d330-sensor.hwdb:8,16` and `patches/touchscreen/etc/udev/hwdb.d/62-...hwdb:5,11` — patterns use `pvrLenovoideapadD330-10IGL` (spaces stripped) while `/sys/class/dmi/id/modalias` carries `pvrLenovo ideapad D330-10IGL`. Verify with `udevadm test` and correct. The space-free `pn82H0:*` entry (`61:12`) is the safe form — make all entries use it.
  * `patches/sensors/etc/udev/rules.d/87-...rules:7,11` — `ATTR{name}=="*bosc0200*"` / `*acpi0008*` are case-sensitive globs against ACPI HIDs `BOSC0200` / `ACPI0008`; both likely never match. Use `*[Bb][Oo][Ss][Cc]0200*` or uppercase.
  * `patches/hardware_controls/etc/udev/rules.d/88-...rules:4-5` — `MODE`/`GROUP` on a sysfs attribute has no effect (udev only rewrites devtmpfs nodes); non-root `d330-ctl` still gets `EACCES`. Replace with a `uaccess`/`TAG` mechanism or a `sudoers` drop-in, or document that root/`pkexec` is required.
  * `patches/wireless/etc/systemd/system-sleep/lenovo-d330-wifi-resume.sh` — `nmcli radio wifi off; sleep 0.2; nmcli radio wifi on` on every wake forces a 2-3 s disconnect (drops VPN/ssh/sync). Replace with carrier/link check, only bounce when the interface is actually wedged; drop dead `dev=$(basename ...)` (`:15`).
  * `tools/d330-refresh-screen.sh:34` — hardcoded `xrandr --output "$OUTPUT" --auto --rotate right` forces a rotation that may double the current one; read current rotation first.
  * `tools/d330-refresh-screen.sh:42-49` — `/sys/class/drm/*/dpms` writes are a no-op on modern i915; verify and replace with `drm` modeset or drop.
  * `patches/audio_dsp/etc/udev/rules.d/91-...rules:8` — `ENV{SOUND_INITIALIZED}="1"` is set only during udev processing and is consumed by nothing; remove or wire up.
  * `patches/touchscreen/etc/udev/rules.d/90-...rules:12,18` — `ENV{WL_OUTPUT}="eDP-1"` is not a libinput or udev property; remove.

### Phase 40: Power Stack Reconciliation

**Goal**: One writer per knob — TLP, udev, `lenovo-d330-power-tune.sh`, thermald and RAPL must not fight.
**Depends on**: Phase 39
**Success Criteria** (what must be TRUE):

  1. `tlp-stat -s` and `/sys/class/powercap` agree after AC hot-plug
  2. no TLP error lines in the journal across a full AC/battery cycle
  3. boot bench reproduced and documented.

**Plans**: TBD

- **Audit Ref**: M13, M14.
- **Components**:
  * `tools/lenovo-d330-power-tune.sh:43-45` — writes `intel_pstate/max_perf_pct=75` on battery from a boot-time oneshot, so a 75% CPU cap survives plugging in AC until reboot. Re-run on AC change (udev rule or TLP hook) or remove the cap.
  * `patches/power/etc/udev/rules.d/95-...rules:3-15` forces `power/control=auto` on every PCI/MMC/USB/I2C/sound device while TLP sets `RUNTIME_PM_ON_AC=on` (`patches/power/etc/tlp.d/50-lenovo-d330.conf:16`) — two writers, permanent flapping. Pick TLP as the single owner; reduce the udev rule to devices TLP does not manage (eMMC host, dock).
  * `patches/power/etc/tlp.d/50-lenovo-d330.conf:24-25` — `INTEL_GPU_MIN_FREQ_ON_AC=100` is below the GLK minimum GT frequency (300 MHz); TLP logs a rejected write on every AC event. Correct or remove. Re-validate `INTEL_GPU_MAX_FREQ_ON_AC=650` / `BOOST=700` against `/sys/class/drm/card0/gt_max_freq_mhz`.
  * `patches/fastboot/etc/default/grub.d/52-lenovo-d330-fastboot.cfg:4` — `nowatchdog` disables NMI/softlockup detection on the exact device whose premise is display pipe lockups. Remove it, or replace with `softlockup_panic=1` so a hang self-recovers instead of going silent.
  * `tools/d330-fastboot-tune.sh:31-32` — masking `NetworkManager-wait-online` is the real boot-time win; verify the actual saving (`systemd-analyze critical-chain`) and correct the "12 seconds from watchdog" claim in `CHANGES_AUDIT.md` §7.7.
  * `patches/thermal/etc/thermald/thermal-conf.xml:11` — `<Type>cpu</Type>` must be validated against the sysfs zone `type` on hardware (expected `x86_pkg_temp`); if it does not match, thermald silently ignores the whole profile while `d330-thermal.service` still reports OK.
  * `tools/d330-thermal-tune.sh` — PL1/PL2 are written once at boot while thermald re-writes them at runtime; define precedence (thermald wins, script is the fallback when `thermald` is absent) and add `thermald` to `packaging/debian/control` `Recommends`.
  * `tools/d330-thermal-tune.sh:21-22` — `$((pl1 / 1000000))` with `pl1="N/A"` silently evaluates to `0`; guard with a numeric regex (N11).

### Phase 41: Test Harness Trustworthiness

**Goal**: A failing check must be able to fail the run. Today 23 of 27 `test_*.sh` exit 0 no matter what, and 22 of 23 `--dry-run` modes validate nothing.
**Depends on**: Phase 40
**Success Criteria** (what must be TRUE):

  1. `scripts/test_*.sh` returns non-zero when its subject is deliberately broken (mutation test on at least 5 scripts)
  2. no `test_*` mutates the system without `--apply`.

**Plans**: TBD

- **Audit Ref**: M12, N8.
- **Components**:
  * `scripts/test_resume_loop.sh:83,110,113` — `((failed++))` / `((passed++))` under `set -euo pipefail` abort the script on cycle 1 (verified: rc=1, summary at `:119` never prints). Use `passed=$((passed + 1))`.
  * `scripts/test_tablet_osk.sh:81,84` — calls `--test-laptop` / `--test-tablet`; `tools/d330-tablet-daemon.py:235-236` defines only `--simulate-dock` / `--simulate-undock` → argparse rc=2. Use `--dry-run --simulate-*`.
  * `scripts/test_battery_power.sh:28,41` and `scripts/test_dock_switching.sh:30,45` — `--stress N` / `--cycle-test N` document a value the parser never consumes, so `N` hits the `*)` branch and exits 1. Parse the value.
  * Live mutation hidden in `test_*`: `scripts/test_thermals.sh:66` (writes RAPL), `scripts/test_boot_speed.sh:64` (permanently masks `NetworkManager-wait-online`), `scripts/test_battery_power.sh:53` (4 sysfs writes), `scripts/test_memory_storage.sh:128` (`fstrim -av`). Gate all four behind an explicit `--apply`.
  * Always-green assertion pattern `cmd || true` followed by unconditional `log_ok` + `exit 0`: `test_auto_hibernate.sh:55-56`, `test_hardware_controls.sh:53-54`, `test_sensor_als.sh:55-56`, `test_tray_applet.sh:48-49`, `test_display_ergonomics.sh:67`, `test_iso_integrity.sh:76,84`, `test_cameras.sh:115-120`, `test_audio_profiles.sh:88-109`, `test_distro_packaging.sh:69-84`, `test_ci_workflows.sh:72-74`, `test_oom_protection.sh:62`, `test_mic_rnnoise.sh:65`, `test_wireless_coex.sh:56-60`, `test_touch_calibration.sh:93-141`, `test_acpi_cleanliness.sh:85-86`. Track a failure counter and exit non-zero.
  * `scripts/test_distro_packaging.sh:20-40` and `scripts/test_ci_workflows.sh:26` — `--probe`/`--dry-run` parse into `MODE` and never read it.
  * `scripts/test_hardware_controls.sh:62-67` — `--test-toggle` claims toggle + restore but only runs `d330-ctl battery status`.
  * `scripts/test_storage_cellular.sh:54,77-79` — prints the non-existent path `fcc-unlock.d/8086:7360` as `[OK]`; `--test-microsd` is a byte-identical alias of `--probe`.
  * `scripts/test_resume_loop.sh:19,55` — writes logs into `docs/dumps/` (dirties the repo); default to `/tmp` (N8).
  * CWD anchoring: most scripts resolve `tools/` and `patches/` paths relative to CWD and break when run from `scripts/`; adopt the `SCRIPT_DIR` pattern used by `test_resume_loop.sh:17-18`.
  * `scripts/build_live_iso.sh:62-76` — `--dry-run` echoes a hardcoded manifest and prints "validated successfully" without checking xorriso/ISO/paths; `test_iso_integrity.sh:54` inherits the no-op.

### Phase 42: Documentation Parity & Repository Polish

**Goal**: Every claim in `CHANGES_AUDIT.md`, `README.md` and the packaging recipes matches the code, and the repo is clean for release.
**Depends on**: Phase 41
**Success Criteria** (what must be TRUE):

  1. `grep -n` audit of `CHANGES_AUDIT.md` vs code returns zero mismatches for the list above
  2. `dpkg-buildpackage`/`makepkg`/`rpmbuild` fail on a deliberately broken copy step
  3. repo has no 0-byte tracked files and no `100644` shell scripts.

**Plans**: TBD

- **Audit Ref**: M17, N1, N2, N4, N5, N7, N9, N10.
- **Components**:
  * `git update-index --chmod=+x` on all `scripts/*.sh` and `tools/*.sh` — every one is mode `100644` while `README.md:64,83` and the usage banners say `sudo ./scripts/install_dkms.sh` (N1).
  * `patches/cellular_storage/etc/ModemManager/fcc-unlock.d/8086` — tracked as an **empty blob** (`e69de29…`) whose name lost `:7360` (colon illegal on the Windows checkout). `scripts/install_dkms.sh:149-151` looks for `8086:7360` and never matches; uninstall's `rm -f` is a no-op. Recreate on a POSIX checkout with real script content + `+x` (N2).
  * `CHANGES_AUDIT.md` contradictions to correct (M17): §2.1 `enable_fbc=1` vs actual `0`; §2.2 `panel_orientation` absent from `50-lenovo-d330-boot.cfg`; §4.2 swappiness 150 vs `99-lenovo-d330-zram.conf:6` = 180, and BFQ vs `60-lenovo-d330-emmc.rules:6` = `mq-deadline`; §4.4 `touch-mode` subcommand does not exist in `d330-ctl`; §4.5 1000 Hz PWM (Phase 37); §4.7 `code` absent from the earlyoom prefer list (`patches/oom_protection/etc/default/earlyoom:6`); §5.4 "FCC unlock script deployed" (N2); §7.2 15 s PL2 window never written; §7.3 `--avoid` only subtracts 300 from `oom_score` (it is `--ignore` that hard-protects); §7.6 `bt_coex_active` lands on `iwlwifi` (Phase 39); §7.8 GTK3 tray applet (Phase 36); §9 claims 11 test scripts — there are 27.
  * `CHANGES_AUDIT.md` §2.1/§7.x — `power_cycle_delay_ms` described as 500 ms in `lenovo_d330_fix.c:10` and 600 ms in §2.1; pick one.
  * Dead code (N4): `SW_LID` (`tools/d330-tablet-daemon.py:26`), unused `dev` (`lenovo-d330-wifi-resume.sh:15`), discarded `lsmod | grep` result (`lenovo-d330-touchscreen-resume.sh:44`), `except Exception as e: return None` shadow (`tools/d330-ctl:35`), empty loop (`tools/d330-tablet-daemon.py:101`).
  * Resource handling (N5): `tools/d330-auto-hibernate.py:30-31` unclosed `open()`; `:48` ignored `subprocess.run` return; `tools/d330-backlight-pwm.py:29-30` same pattern.
  * Unused deployables: `tools/d330-acpi-override.sh` and `tools/d330-pen-config.sh` are in the repo but not in `install_dkms.sh`'s 13-tool list and not in `CHANGES_AUDIT.md` §8.1 — deploy or document as dev-only. Same for `patches/acpi_override/dsdt_override.asl` (never compiled; `51-...cfg` is correctly guarded on `/boot/acpi-override.cpio` which nothing creates).
  * Packaging (N9): `packaging/debian/rules`, `packaging/arch/PKGBUILD`, `packaging/rpm/lenovo-d330-fix.spec` pipe every `cp` into `|| true` — a build can produce an empty package and report success. Fail loudly. `PKGBUILD` has no `prepare()` for the kernel patch `docs/DISTRO_INSTALL_GUIDE.md:51` tells users to add.
  * `packaging/debian/control` + `PKGBUILD` + spec — declare the real optional runtime deps the configs assume: `thermald`, `earlyoom`, `zram-generator`, `rnnoise-ladspa`/`ladspa-rnnoise`, `vainfo`, `gsettings`/desktop deps.
  * .desktop hygiene (N7) — `Icon=preferences-system`, redundant `X-GNOME-Autostart-enabled`.
  * `README.md` repository tree (`:94-117`) omits `docs/DISTRO_INSTALL_GUIDE.md`, `.github/`, `packaging/`, and all 27 test scripts; `README.md:46` calls them "test harnesses" without noting 23 of them currently always pass (Phase 41 fixes that).

---

## Project Status: Phases 0–31 Complete, Milestone 7 (Phases 32–42) Active

Milestones 1–6 (Phases 0–31) executed, tested, and archived. External pre-deployment audit verdict was `BLOCKED BY CRITICAL DEFECTS`; Milestone 7 remediates all 4 Critical, 17 Moderate and 11 Minor findings before any hardware deployment.
