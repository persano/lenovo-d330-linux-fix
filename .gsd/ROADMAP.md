# Roadmap: Lenovo D330-10IGL Linux Parity Project

## Milestones

- ✅ **v1.0 Display & Power Parity** — Phases 0-5 (shipped)
- ✅ **v2.0 Peripheral Parity & Tablet Usability** — Phases 6-9 (shipped)
- ✅ **v3.0 Vision, Ergonomics & Multimedia** — Phases 10-14 (shipped)
- ✅ **v4.0 Connectivity, Firmware & System Boot** — Phases 15-20 (shipped)
- ✅ **v5.0 CI/CD & Remastered Live ISO Distribution** — Phases 21-23 (shipped)
- ✅ **v6.0 System Resilience, Performance & Usability Polish** — Phases 24-31 (shipped)
- ✅ **v7.0 Pre-Deployment Audit Remediation** — Phases 32-42 (shipped 2026-10-08)
- ✅ **v8.0 Reverse-Engineer & Fix the D330 Resume Black Screen** — Phases 43-46 (shipped 2026-10-13: RE + differential + honest closure; **bug NOT fixed** — the fix hunt continues in v9.0)
- 🚧 **v9.0 Actually Fix the D330 Resume Black Screen** — Phases 47-49 (in progress)

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

### 🚧 v8.0 Reverse-Engineer & Fix the D330 Resume Black Screen (In Progress)

**Milestone Goal:** Resume on the D330-10IGL (`82H0`) leaves the panel black while every
host register is byte-identical to a working state; crack it on the current test kernel
(Ubuntu `7.0.0-38-generic`) with a research + deep-RE push on real hardware, falling back
to a packaged seamless automatic recovery if no clean resume fix is achievable.

**Phase Ordering Rationale:** the seamless recovery lands first (Phase 43) because it is
provably correct today and independent of the reverse-engineering outcome, guaranteeing a
shippable milestone; the safety kit and banned-lever gate must exist before any device
experiment on a tablet with no serial console; the cheap upstream/mainline survey (Phase 44)
runs before the costly RE and bisect (Phase 45); verification and any upstream submission
close the milestone (Phase 46).

**Phases:**

- [x] **Phase 43: Guardrails, Ledger & Safe Recovery Baseline** - Turn the disproven-lever list into a machine-checkable gate, stage the on-device safety kit, and ship the packaged, manifest-symmetric seamless recovery (completed 2026-10-12)
- [x] **Phase 44: Community & Upstream Survey + Cheap Levers** - Confirm whether upstream already fixes GLK DSI resume, sweep mainline for a good/bad kernel pair, and file the i915 bug (completed 2026-10-12)
- [x] **Phase 45: Windows/GOP Binary RE + On-Device Resume-vs-Probe Differential** - RE `igdkmd64.sys`/GOP and run the on-device resume-vs-reload differential to land a DMI-gated fix (or prove none is achievable) — outcome: ROOT-04 honest closure, no clean fix proven (completed 2026-10-13)
- [x] **Phase 46: Verification, Delivery & Upstream (conditional)** - Prove the observable bar and no-regression on-device, and submit upstream only if a real fix landed — outcome: upstream clause skipped (condition failed: no clean resume fix landed, ROOT-04), verification + handoff package delivered (completed 2026-10-13)

### Phase 43: Guardrails, Ledger & Safe Recovery Baseline

**Goal**: Everything is safe and shippable before any risky kernel experiment — the banned-lever ledger is a machine-checkable gate, the on-device safety kit is staged, and the proven seamless recovery is hardened, packaged and manifest-symmetric.
**Depends on**: Nothing (first phase of Milestone 8)
**Requirements**: GUARD-01, GUARD-02, GUARD-03, RECOV-01, RECOV-02, RECOV-03
**Success Criteria** (what must be TRUE):

  1. `docs/research/RESUME_FIX_LEDGER.md` consolidates all 22 on-device-disproven levers plus community/upstream dead ends, and `scripts/test_pitfalls_ledger.sh` exits non-zero when a phase plan re-proposes a banned lever as a fix
  2. The safety kit (golden `i915.ko.zst` with checksum, live USB, current VBT/GOP dump, checksummed tablet source tree) is staged off-device, and the black-resume-vs-working-reload capture protocol (no cold-boot control, `systemd-inhibit`, full ≥18 s window) is documented
  3. After resume on `82H0` the display is automatically restored with no user action — a DMI-gated, `timeout`-bounded i915 unbind/bind plus display-manager restart
  4. The recovery ships through the installer and all three packagers plus the CI `.deb`, is installed/uninstalled symmetrically via the deploy manifest, is idempotent, is disable-able via a manifest-tracked state file, and does not fight the real fix when both are present

**Plans**: 4/4 plans executed

Plans:
**Wave 1**

- [x] 43-01-PLAN.md — Banned-lever ledger + machine gate (GUARD-01, GUARD-02)
- [x] 43-02-PLAN.md — Recovery hook hardening + guard cases (RECOV-01, RECOV-03)
- [x] 43-03-PLAN.md — Packagers + CI ship the hook; state-file manifest symmetry (RECOV-02, RECOV-03)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 43-04-PLAN.md — Safety kit prep/verify + capture protocol doc (GUARD-03)

### Phase 44: Community & Upstream Survey + Cheap Levers

**Goal**: Settle the cheap, high-leverage questions first — does upstream already fix this, does a known GLK DSI commit change the resume path, and is there a good/bad kernel pair — before any costly bisect or RE.
**Depends on**: Phase 43
**Requirements**: SURVEY-01, SURVEY-02, SURVEY-03
**Success Criteria** (what must be TRUE):

  1. A documented survey of upstream/community state (i915 GitLab, lore, ChromeOS, distro forums) states whether GLK DSI resume is a fixed regression anywhere
  2. The test kernel is checked against known GLK DSI fixes (`615c8ec48621`) and a mainline sweep yields a good/bad kernel pair if one exists
  3. A correctly-formed i915 bug report (trace plus reproducer) is filed or updated on the upstream tracker

**Plans**: TBD

- [x] 44-01-PLAN.md

### Phase 45: Windows / GOP Binary RE + On-Device Resume-vs-Probe Differential

**Goal**: Answer "what does probe do that resume does not?" with both independent inputs — static RE of the vendor Windows/GOP path and the dynamic on-device resume-vs-reload differential — then land a DMI-gated fix, or prove no clean fix is achievable.
**Depends on**: Phase 44
**Requirements**: WRE-01, WRE-02, WRE-03, ROOT-01, ROOT-02, ROOT-03, ROOT-04
**Success Criteria** (what must be TRUE):

  1. REA+Ghidra (GLM 5.3 Flash) decompiles `igdkmd64.sys` and the GOP image with cited file+address+bytes evidence, and the VBT is decoded confirming the DSI link config (single/dual-link, ports, MIPI sequence version)
  2. The Windows D3→D0 / display-power callback and GOP panel-init path are documented, listing the resume behaviors i915 lacks
  3. An on-device differential proves what the reload does that resume does not (DSI teardown / readout-state provenance), with instrumentation evidence
  4. A DMI-gated (`82H0`) i915 change makes resume power the panel without a full reload, verified on-device, and the backlight returns at the user's brightness with no manual write
  5. If no clean resume fix is achievable, that is proven with evidence and the milestone closes on the packaged recovery, not a non-fix

**Plans**: TBD

- [x] 45-01-PLAN.md
- [x] 45-02-PLAN.md

### Phase 46: Verification, Delivery & Upstream (conditional)

**Goal**: Prove the observable bar and no regressions on real hardware, and deliver through the honest channel — upstream only if a real fix landed.
**Depends on**: Phase 45
**Requirements**: VERIFY-01, VERIFY-02, VERIFY-03
**Success Criteria** (what must be TRUE):

  1. On-device acceptance: the display is lit, upright at 270 deg, with correct backlight across 10+ consecutive suspend/resume cycles with no manual action
  2. No regression to cold boot, the CCS/rotation fix, touch/audio, or the existing v1-v7 tool suites
  3. Any real fix is shaped as an upstreamable i915 DMI quirk (`intel_quirks.c`) and submitted only if ROOT-02 landed

**Plans**: TBD

- [x] 46-01-PLAN.md

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 43. Guardrails, Ledger & Safe Recovery Baseline | 4/4 | Complete    | 2026-10-12 |
| 44. Community & Upstream Survey + Cheap Levers | 1/1 | Complete    | 2026-10-12 |
| 45. Windows/GOP Binary RE + On-Device Resume-vs-Probe Differential | 2/2 | Complete (ROOT-04 honest closure)| 2026-10-13 |
| 46. Verification, Delivery & Upstream (conditional) | 1/1 | Complete (upstream clause skipped — condition failed)| 2026-10-13 |
| 47. DSI MMIO Truth (Boot vs Resume Hardware Register Diff) | 0/0 | Not started | - |
| 48. Clean DMI-Gated Fix (MMIO-Guided) | 0/0 | Not started | - |
| 49. Delivery, No-Regression & Closure | 0/0 | Not started | - |

---

### 🚧 v9.0 Actually Fix the D330 Resume Black Screen (In Progress)

**Milestone Goal:** v8.0 promised a fix and did not ship one. It shipped the map instead:
the GOP boot-time panel init, the two-VBT handoff, 29 disproven levers, and the decisive
fact that the kernel's display state is byte-identical working-vs-broken. v9.0 goes below
the kernel's model: capture the hardware-level DSI/DPHY register truth (boot vs resume),
name the mechanism, and land a clean DMI-gated (`82H0`) kernel fix. No upstream
dependency — we are the only people working on this.

**Process rules (v8.0 lessons, binding):** the user triggers every suspend/resume
themselves and reports the verdict in their own time; no SSH-triggered test ever requires
the user's eyes; machine evidence (traces, register dumps) runs every cycle; one test per
session, scheduled with the user. Never attribute a failed test to the user.

**Phase Ordering Rationale:** the hardware-register diff (Phase 47) must come first —
three v8.0 candidates failed because every kernel-visible state was already identical;
the only unknown lives below the kernel's model. The fix (Phase 48) is then
MMIO-guided — replicating the GOP's boot-time panel init in the resume path or restoring
the differing registers — with the user-triggered eyes-on protocol and the ≤5-iteration
budget. Delivery (Phase 49) proves the observable bar and closes honestly either way.

**Phases:**

- [ ] **Phase 47: DSI MMIO Truth (Boot vs Resume Hardware Register Diff)** - Capture the DSI/DPHY transcoder register state the kernel tooling cannot show (CI-built dump patch or devcoredump), diff working-boot vs broken-resume, and name the mechanism (`docs/research/DSI_MMIO_DIFF.md`) (MMIO-01, MMIO-02)
- [ ] **Phase 48: Clean DMI-Gated Fix (MMIO-Guided)** - Land a clean `82H0`-gated kernel fix that makes the panel show an image after resume, verified eyes-on by the user plus machine evidence; ≤5 iterations or an updated honest closure (FIX-01, FIX-02, FIX-03)
- [ ] **Phase 49: Delivery, No-Regression & Closure** - Prove the observable bar across 3+ user-triggered resume cycles, keep the guard chain green, and close the milestone honestly (DONE-01, DONE-02)

### Phase 47: DSI MMIO Truth (Boot vs Resume Hardware Register Diff)

**Goal**: Get below the kernel's software model — capture the DSI/DPHY/transcoder hardware register state that v8.0 could not see, on both a working fresh boot and a broken resume, and name the differing mechanism.
**Depends on**: Nothing (first phase of Milestone 9; v8.0's NO_CLEAN_FIX_PROOF.md future-work list is the direct input)
**Requirements**: MMIO-01, MMIO-02
**Success Criteria** (what must be TRUE):

  1. A register dump covering the DSI/DPHY/transcoder block exists for BOTH states (working boot, broken resume), captured on-device with the CI-built kernel or dump tooling, checksummed and registered in the RE kit manifest
  2. `docs/research/DSI_MMIO_DIFF.md` records the diff, excludes volatile/irrelevant registers with reasons, and names the mechanism as a testable claim (which hardware state the GOP sets that the resume path does not)
  3. Every claim is machine-evidenced; the ledger gate stays green

**Plans**: TBD

### Phase 48: Clean DMI-Gated Fix (MMIO-Guided)

**Goal**: Land the actual fix: a DMI-gated (`82H0`) kernel change that makes the panel show an image after resume, guided by the Phase 47 mechanism — replicating the GOP's boot-time panel init in the resume path or restoring the differing hardware state.
**Depends on**: Phase 47
**Requirements**: FIX-01, FIX-02, FIX-03
**Success Criteria** (what must be TRUE):

  1. The fix is built by CI, deployed with the known-good rollback `.deb` retained first, and DMI-gated to `82H0`
  2. The user triggers every suspend/resume test themselves and reports the verdict in their own time; the panel shows the desktop image (not just sysfs state) after resume
  3. ≤5 fix iterations; on failure the honest-closure document is updated with a v9.0 section — never a fake fix; every attempt is ledger-recorded

**Plans**: TBD

### Phase 49: Delivery, No-Regression & Closure

**Goal**: Prove the observable bar on real hardware and close the milestone honestly — fix shipped and proven, or mechanism documented as unreachable with a concrete next instrument.
**Depends on**: Phase 48
**Requirements**: DONE-01, DONE-02
**Success Criteria** (what must be TRUE):

  1. After the fix (if landed): the desktop is visible and usable across 3+ consecutive user-triggered suspend/resume cycles with no manual action
  2. The full guard harness chain is green at close; the ledger reflects the final truth (new disproven rows appended if the fix failed again)
  3. The upstream post is optional and never blocks anything

**Plans**: TBD

---

## Project Status: Milestones 1-7 Complete (Phases 0-42); Milestone 8 (Phases 43-46) Planning

Milestone 8 (v8.0) maps its 19 v1 requirements (GUARD-01..03, RECOV-01..03, SURVEY-01..03,
WRE-01..03, ROOT-01..04, VERIFY-01..03) to four phases, 43-46, with the load-bearing ordering
above: a provably-correct, packaged seamless recovery ships first, the banned-lever gate and
on-device safety kit exist before any kernel experiment, and the costly Windows/GOP RE plus the
root-cause differential land only after the cheap upstream survey.

Milestones 1-6 (Phases 0-31) executed, tested, and archived. Milestone 7 (Phases 32-42)
remediated all 4 Critical, 17 Moderate and 11 Minor findings of the external pre-deployment
audit (`BLOCKED BY CRITICAL DEFECTS`), plus one cross-phase packaging integration gap found by
the milestone audit. All 11 phases verified; hardware-in-the-loop, daemon and package-build
success criteria are covered by documented per-phase verification overrides to re-run on a
D330 unit at deployment sign-off. The live-installer path (`sudo ./scripts/install_dkms.sh`) is
consistent end-to-end; the `.deb`/`.rpm`/PKGBUILD packagers and the CI `.deb` build install the
same suffix-free tool names the shipped systemd units execute.
