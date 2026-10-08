# Roadmap: Lenovo D330-10IGL Linux Parity Project

## Milestones

- ✅ **v1.0 Display & Power Parity** — Phases 0-5 (shipped)
- ✅ **v2.0 Peripheral Parity & Tablet Usability** — Phases 6-9 (shipped)
- ✅ **v3.0 Vision, Ergonomics & Multimedia** — Phases 10-14 (shipped)
- ✅ **v4.0 Connectivity, Firmware & System Boot** — Phases 15-20 (shipped)
- ✅ **v5.0 CI/CD & Remastered Live ISO Distribution** — Phases 21-23 (shipped)
- ✅ **v6.0 System Resilience, Performance & Usability Polish** — Phases 24-31 (shipped)
- ✅ **v7.0 Pre-Deployment Audit Remediation** — Phases 32-42 (shipped 2026-10-08)

## Phases

<details>
<summary>✅ v1.0 Display & Power Parity (Phases 0-5) — SHIPPED</summary>

Full detail archived to [`milestones/v1.0-ROADMAP.md`](milestones/v1.0-ROADMAP.md).

- [x] Phase 0: Project & Repository Setup (`7e4b76e`)
- [x] Phase 1: Community Research & Prior Art Ingestion (`a60bdf1`)
- [x] Phase 2: Official Lenovo Windows Driver Baseline Acquisition (`c489f88`)
- [x] Phase 3: Hardware Telemetry & ACPI Extraction (`d09d0c3`)
- [x] Phase 4: Differential Analysis & Reverse Engineering (`d5f20bc`)
- [x] Phase 5: Patch Generation & DKMS Delivery (`7c313fb`)

</details>

<details>
<summary>✅ v2.0 Peripheral Parity & Tablet Usability (Phases 6-9) — SHIPPED</summary>

Full detail archived to [`milestones/v2.0-ROADMAP.md`](milestones/v2.0-ROADMAP.md).

- [x] Phase 6: Touchscreen & Active Pen Calibration (`4126a9a`)
- [x] Phase 7: Detachable Dock & Tablet Mode Daemon (`bb7b4c5`)
- [x] Phase 8: Audio & Microphone UCM Profiles (`b2cb1e7`)
- [x] Phase 9: Battery Life & Power Governors (`1858351`)

</details>

<details>
<summary>✅ v3.0 Vision, Ergonomics & Multimedia (Phases 10-14) — SHIPPED</summary>

Full detail archived to [`milestones/v3.0-ROADMAP.md`](milestones/v3.0-ROADMAP.md).

- [x] Phase 10: Intel IPU3 Dual Camera Pipeline
- [x] Phase 11: 4GB RAM & 64GB eMMC Storage Optimization
- [x] Phase 12: Audio Refinements (Dolby DSP Curve & Anti-Pop Jack Delay)
- [x] Phase 13: Lenovo Hardware Controls (`ideapad_laptop` VPC2004)
- [x] Phase 14: Display Ergonomics (Backlight PWM Anti-Flicker & ICC Profile)

</details>

<details>
<summary>✅ v4.0 Connectivity, Firmware & System Boot (Phases 15-20) — SHIPPED</summary>

Full detail archived to [`milestones/v4.0-ROADMAP.md`](milestones/v4.0-ROADMAP.md).

- [x] Phase 15: Early Bootloader, Console & Plymouth Orientation
- [x] Phase 16: ACPI DSDT Clean Initrd Override
- [x] Phase 17: Sensor Hysteresis & Ambient Light Sensor (ALS) Auto-Dimming
- [x] Phase 18: Touchpad & Active Pen Gestures Tuning
- [x] Phase 19: MicroSD Storage Expansion & Modular Cellular LTE
- [x] Phase 20: Critical Low-Battery Auto-Hibernate Daemon

</details>

<details>
<summary>✅ v5.0 CI/CD & Remastered Live ISO Distribution (Phases 21-23) — SHIPPED</summary>

Full detail archived to [`milestones/v5.0-ROADMAP.md`](milestones/v5.0-ROADMAP.md).

- [x] Phase 21: Native Distribution Packaging (.deb, .rpm, PKGBUILD)
- [x] Phase 22: Automated Live ISO Remaster Build Harness
- [x] Phase 23: GitHub Actions CI/CD Release Pipeline

</details>

<details>
<summary>✅ v6.0 System Resilience, Performance & Usability Polish (Phases 24-31) — SHIPPED</summary>

Full detail archived to [`milestones/v6.0-ROADMAP.md`](milestones/v6.0-ROADMAP.md).

- [x] Phase 24: Intel VA-API Hardware Video Acceleration (iHD / Firefox / Chromium)
- [x] Phase 25: Fanless Thermal Tuning & RAPL Power Limits (PL1 5.0W, PL2 8.0W, thermald)
- [x] Phase 26: Out-Of-Memory Prevention (earlyoom on 4GB RAM)
- [x] Phase 27: Tablet Mode OSK Auto-Summon & Long-Press Right-Click
- [x] Phase 28: PipeWire RNNoise Neural AI Microphone Denoising
- [x] Phase 29: Wi-Fi & Bluetooth Coexistence & S2idle Sleep Stability
- [x] Phase 30: Fast Boot Optimization for eMMC Storage
- [x] Phase 31: Desktop GUI System Tray Hardware Applet (`d330-tray.py`)

</details>

<details>
<summary>✅ v7.0 Pre-Deployment Audit Remediation (Phases 32-42) — SHIPPED 2026-10-08</summary>

Full detail archived to [`milestones/v7.0-ROADMAP.md`](milestones/v7.0-ROADMAP.md).
Audit report: [`milestones/v7.0-MILESTONE-AUDIT.md`](milestones/v7.0-MILESTONE-AUDIT.md).

- [x] Phase 32: Data-Loss & Boot Safety Guards (Audit C1, C2) (completed 2026-10-08)
- [x] Phase 33: Low-Battery Hibernate Feasibility (Audit C3) (completed 2026-10-08)
- [x] Phase 34: Deliver the Actual PPS / Display Resume Fix (Audit C4) (completed 2026-10-08)
- [x] Phase 35: Installer & Uninstaller Symmetry (Audit M1, M2, M11, N6) (completed 2026-10-08)
- [x] Phase 36: Desktop Session Wiring - Tray Applet & Tablet Daemon (Audit M3, M6) (completed 2026-10-08)
- [x] Phase 37: No-Op Tools Made Real or Removed - PWM & Sensor Filter (Audit M4, M5) (completed 2026-10-08)
- [x] Phase 38: PipeWire DSP Activation (Audit M7) (completed 2026-10-08)
- [x] Phase 39: udev / hwdb / Wireless Match Correctness (Audit M8, M9, M10, M15, M16) (completed 2026-10-08)
- [x] Phase 40: Power Stack Reconciliation (Audit M13, M14) (completed 2026-10-08)
- [x] Phase 41: Test Harness Trustworthiness (Audit M12, N8) (completed 2026-10-08)
- [x] Phase 42: Documentation Parity & Repository Polish (Audit M17, N1-N5, N7, N9, N10) (completed 2026-10-08)

</details>

---

## Project Status: Milestones 1-7 Complete (Phases 0-42)

Milestones 1-6 (Phases 0-31) executed, tested, and archived. Milestone 7 (Phases 32-42)
remediated all 4 Critical, 17 Moderate and 11 Minor findings of the external pre-deployment
audit (`BLOCKED BY CRITICAL DEFECTS`), plus one cross-phase packaging integration gap found by
the milestone audit. All 11 phases verified; hardware-in-the-loop, daemon and package-build
success criteria are covered by documented per-phase verification overrides to re-run on a
D330 unit at deployment sign-off. The live-installer path (`sudo ./scripts/install_dkms.sh`) is
consistent end-to-end; the `.deb`/`.rpm`/PKGBUILD packagers and the CI `.deb` build install the
same suffix-free tool names the shipped systemd units execute.
