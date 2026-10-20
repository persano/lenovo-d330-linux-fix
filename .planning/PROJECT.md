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

- **Milestone 8: Reverse-Engineer & Fix the D330 Resume Black Screen (v8.0, shipped 2026-10-13)**: GOP driver + two-VBT handoff decoded; resume-vs-reload differential (kernel display state byte-identical working-vs-broken — failure below the kernel model); 29-row binding disproven-lever ledger with machine gate; rebind "recovery" myth-busted (only a reboot restores the panel); 3 deployed fix candidates falsified; honest closure (NO_CLEAN_FIX_PROOF.md). Bug NOT fixed.
- **Milestone 9: Actually Fix the D330 Resume Black Screen (v9.0, shipped 2026-10-16)**: DSI MMIO truth (X=Y working vs X=Z held-broken contrast, `dsi_mmio_diff.sh` + evidence guards); 3 DMI-gated candidates (fresh-state, panel power cycle, MIPIO reset) CI-built + deployed + falsified with machine evidence (ledger rows 30-32); reload-workaround premise corrected (never restored an image — recovery = reboot only); 65-artifact re-kit + upstream handoff. Fix proven unreachable from every kernel path tested.
- **Milestone 10: Crack the Panel (v10.0, closed 2026-10-19)**: DCS ID-read instrument (TCON stays unknown; I2C sideband ruled out); keep-hot ladder E1/E3 falsified with machine evidence (ledger rows 30-33); purchase declined, Phases 52/53 retired unexecuted; then the upstream GLK reset-order fixup (issue #13225) adapted (sha F97F4E87) and validated **10/10 S3 resumes + all boots eyes-on** — ledger row 34, NO_CLEAN_FIX_PROOF §9 overturns the "no clean fix" verdict.
- **Milestone 11: Ship the Fix (v11.0, shipped 2026-10-19)**: Release `v11.0` (14 assets — patched kernel debs, DKMS `.deb`/`.rpm`/`.pkg.tar.zst`, one-script installer `scripts/d330-full-setup.sh`, Ubuntu/ChromeOS/Android patch sets); GLK fixup + CCS quirk in the booted reference-device kernel; source-verified GLK patches generated against real `chromeos-6.6`/`chromeos-5.15`/AOSP `android15-6.6`/`android13-5.15` trees (`git apply --check` clean).

## Current Milestone: v12.0 Boot the Other OSes

**Goal:** Build the GLK-patched kernels for BlissOS and ChromeOS on GitHub Actions CI and prove they work on the real D330 — both OSes booted from USB (internal disk untouched), display + suspend/resume verified eyes-on.

**Target features:**
- Phase 57: CI build of the patched BlissOS kernel (BlissRoms `kernel_common`, GLK + CCS patches applied, `bzImage` artifact).
- Phase 58: BlissOS boot test on the D330 from USB — display lit, panel orientation correct, S3/s2idle resume eyes-on.
- Phase 59: CI build of the patched ChromeOS kernel (`chromeos-6.6` via depot_tools/shallow checkout; runner-disk risk acknowledged, fallback = documented honest stop, never a fake artifact).
- Phase 60: ChromeOS boot test on the D330 from USB — same verification matrix.

**Research:** `.planning/research/` — none new; tree sources already fetched (2026-10-19) and patches source-verified in v11.0.

## Project Status: Milestone 12 (v12.0) started — requirements + roadmap definition; v11.0 shipped (fix live in release v11.0)

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

### Key Decisions (Milestone 10)
- **Phase 50**: The software DCS read path is dead on the D330 panel — `echo 2` ID reads returned `ret=4 avail=0 data=00 00 00` in 3 runs across both arms (X=Y ×2, X=Z ×1). No TCON identity from the kernel; the Phase 51 E3 DCS discriminator is falsified as designed, and wire-level identification (Phase 53) is the remaining path. Verdict: `docs/research/TCON_IDENTIFICATION.md`.
- **Phase 50**: No panel-TCON I2C sideband exists (zero i2c-core transfers during the instrument run; wake trace only Goodix + one misc write); PMIC-by-name on bus 6 not confirmed (bus 6 = gmbus dpb). I2C claims are kernel-era-window-scoped — GOP pre-kernel activity needs Phase 53.

### Key Decisions (Milestone 12)
- **Phase 59**: The v11.0 "verified clean" claim for `patches/chromeos/d330_chromeos_6.6.patch` was **false** — the patch was corrupt (bad hunk count) and anchored to a post-`intel_display`-refactor tree that `chromeos-6.6` is not. Caught by the plan's local pre-verify (red log `.git/phase59-task1-gate-initial.log`), re-adapted against real tip `a534360e` (kernel 6.6.147); per-file adaptation record in `patches/chromeos/README.md`. No hunk deleted, no force-apply.
- **Phase 59**: Checkout is a shallow single-branch `git clone` of `chromiumos/third_party/kernel @ chromeos-6.6`, **not** the full depot_tools platform tree (ROADMAP's parenthetical said depot_tools) — satisfies the criterion's "freshly fetched shallow chromeos-6.6 checkout" without the runner-disk blowout. Flagged in workflow header + README for morning review.
- **Phase 59**: Upload hardening applied to **both** CI workflows (review IN-01/IN-02): explicit `if: success()` + `if-no-files-found: error` — honest-stop (BLIS-02/CHRM-02) enforced structurally, not by convention.
- **Phase 57**: The ROADMAP's "BlissRoms `kernel_common`" is stale (2023, max 6.3) — the live BlissOS x86 kernel tree is `android-generic/kernel_common`; Phase 57 builds from `hm/crimson` (6.6.129, tip 447ff151) matching the 6.6 patch pair. Recorded here per milestone-audit requirement.
- **Phase 57**: `patches/android/d330_android_x86_6.6.patch` needed crimson adaptation (wrong hunk-header counts + pre-`intel_display`-refactor API); GLK patch applied clean. Adaptations documented per file/hunk in `patches/android/README.md` §2; no hunk deleted, no `--3way`/`-f`.
- **Phase 57**: Two CI-only lessons baked into `build-blissos-kernel.yml`: (1) crimson's `drivers/kernelsu` is a submodule symlink — shallow clone must `git submodule update --init --depth 1` or configure dies; (2) crimson's defconfig sets `CONFIG_WERROR=y` — must `scripts/config --disable WERROR` for the runner's gcc (clang-vs-gcc warning deltas). Live-validated: run 39365529173 green, artifact `blissos-kernel` hashes 3/3 match, both red runs published 0 artifacts (BLIS-02 live-proven).
- **Phase 57**: `phase.complete` enforces the verification digest — workflow fixes after a verifier run stale the report; the verifier must be re-run (not just the status field edited) before completion.

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-10-20 after Phases 57 + 59 complete*
