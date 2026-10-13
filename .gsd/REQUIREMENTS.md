# Requirements: Lenovo IdeaPad D330-10IGL Linux Display & Power Parity Project

**Defined:** 2026-10-12
**Milestone:** v8.0 Reverse-Engineer & Fix the D330 Resume Black Screen
**Core Value:** full hardware parity + screen-freeze fix for the Lenovo D330-10IGL.

## v1 Requirements

Requirements for milestone v8.0. Each maps to exactly one roadmap phase (Phases 43-46).

### Guardrails & Safety

- [x] **GUARD-01**: The disproven levers (22 on-device rows plus community/upstream dead ends) are consolidated into one binding ledger every phase plan must respect
- [x] **GUARD-02**: A machine-checkable test fails if a phase plan or the repo re-proposes a banned lever as a fix
- [x] **GUARD-03**: Safe on-device test protocol (black-resume vs working-reload control, full-window captures) plus off-device golden `i915.ko` and live-USB recovery are staged before any kernel experiment

### Seamless Recovery Baseline

- [x] **RECOV-01**: After resume on `82H0` the display is automatically restored with no user action (DMI-gated, time-bounded i915 unbind/bind plus display-manager restart)
- [x] **RECOV-02**: Recovery ships through the installer and all three packagers plus the CI `.deb`, installed/uninstalled symmetrically via the deploy manifest
- [x] **RECOV-03**: Recovery is idempotent, disable-able via a manifest-tracked state file, and does not fight the real fix when both are present

### Community & Upstream Survey

- [x] **SURVEY-01**: A documented survey of upstream/community state (i915 GitLab, lore, ChromeOS, distro forums) confirms whether GLK DSI resume is a fixed regression anywhere
- [x] **SURVEY-02**: The test kernel is checked against known GLK DSI fixes (e.g. `615c8ec48621`) and a mainline sweep yields a good/bad kernel pair if one exists
- [x] **SURVEY-03**: A correctly-formed i915 bug report (trace plus reproducer) is filed or updated on the upstream tracker

### Windows Behavior RE

- [ ] **WRE-01**: REA+Ghidra wired to GLM 5.3 Flash, able to decompile `igdkmd64.sys` (and the GOP image) with cited file+address+bytes evidence
- [ ] **WRE-02**: The Windows D3-D0 / display-power callback and GOP panel-init path are documented, with the resume behaviors i915 lacks
- [ ] **WRE-03**: The VBT is decoded to confirm the DSI link config (single/dual-link, ports, MIPI sequence version)

### Resume Root-Cause & Fix

- [ ] **ROOT-01**: An on-device differential proves what the reload does that resume does not (DSI teardown / readout state provenance), with instrumentation evidence
- [ ] **ROOT-02**: A DMI-gated (`82H0`) i915 change makes resume power the panel without a full reload, verified on-device
- [ ] **ROOT-03**: The backlight-after-resume bug is fixed so the panel returns at the user's brightness with no manual write
- [ ] **ROOT-04**: If no clean resume fix is achievable, that is proven with evidence and the milestone closes on the packaged recovery, not a non-fix

### Verification & Delivery

- [ ] **VERIFY-01**: On-device acceptance: display is lit, upright at 270 deg, correct backlight across 10+ consecutive suspend/resume cycles with no manual action
- [ ] **VERIFY-02**: No regression to cold boot, the CCS/rotation fix, touch/audio, or the existing v1-v7 tool suites
- [ ] **VERIFY-03**: Any real fix is shaped as an upstreamable i915 DMI quirk (`intel_quirks.c`) and submitted only if ROOT-02 landed

## v2 Requirements

Deferred to a future milestone. Tracked but not in the current roadmap.

### Upstream & Ports

- **PORT-01**: Port any proven fix to ChromeOS (`chromeos-5.15`/`6.6`) and Android-x86 branches
- **PORT-02**: Compositor-side (KWin) never-disable experiment as a diagnostic
- **PORT-03**: DSI power-cycle wait hardening if a timing dependency surfaces

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Panel orientation quirks for 82H0 | Already upstream/shipped |
| CCS + 90/270 rotation rejection | Fixed in the prior milestone |
| Other D330 variants (81H3/81MD) | Different hardware; 82H0 only |
| Real Windows install on the D330 | Binary-only RE for now; install later if needed |
| Compositor-side KWin never-disable as a product fix | Diagnostic only; no-compositor resume is also black |
| Flashing any BIOS | Bricking risk; GOP path is extractable from the current dump |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| GUARD-01 | Phase 43 | Complete |
| GUARD-02 | Phase 43 | Complete |
| GUARD-03 | Phase 43 | Complete |
| RECOV-01 | Phase 43 | Complete |
| RECOV-02 | Phase 43 | Complete |
| RECOV-03 | Phase 43 | Complete |
| SURVEY-01 | Phase 44 | Complete |
| SURVEY-02 | Phase 44 | Complete |
| SURVEY-03 | Phase 44 | Complete |
| WRE-01 | Phase 45 | Pending |
| WRE-02 | Phase 45 | Pending |
| WRE-03 | Phase 45 | Pending |
| ROOT-01 | Phase 45 | Pending |
| ROOT-02 | Phase 45 | Pending |
| ROOT-03 | Phase 45 | Pending |
| ROOT-04 | Phase 45 | Pending |
| VERIFY-01 | Phase 46 | Pending |
| VERIFY-02 | Phase 46 | Pending |
| VERIFY-03 | Phase 46 | Pending |

**Coverage:**

- v1 requirements: 19 total
- Mapped to phases: 19
- Unmapped: 0

---
*Requirements defined: 2026-10-12*
*Last updated: 2026-10-12 after v8.0 roadmap creation (Phases 43-46; 19/19 mapped, 0 unmapped)*
