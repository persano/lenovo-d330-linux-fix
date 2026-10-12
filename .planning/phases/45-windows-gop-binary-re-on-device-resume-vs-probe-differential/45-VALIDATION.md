---
phase: 45
slug: windows-gop-binary-re-on-device-resume-vs-probe-differential
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-10-12
---

# Phase 45 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | House bash guard harness (38 suites, +1 new this phase = 39) + on-device SSH evidence capture + host-side RE tooling (Ghidra headless) |
| **Config file** | none |
| **Quick run command** | `bash scripts/test_re_diff_evidence.sh` (new) + `bash scripts/test_pitfalls_ledger.sh` |
| **Full suite command** | `bash scripts/test_storage_cellular.sh --dry-run` |
| **Estimated runtime** | ~70 s harness; RE passes and differential are device/host-bound |

## Sampling Rate

- **After every task commit:** `bash -n` on touched scripts + ledger gate if docs/research touched + new evidence suite
- **After plan wave:** full chained harness once per plan
- **Device-side sampling:** every differential arm logs verbatim commands + outputs to the results doc; panel state read from registers/sysfs (backlight level), never from user eyes (Phase 44 lesson)

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 45-01-T1 | 45-01 | 1 | WRE-01 (inputs) | T-45-01 binary substitution | sha256-verified Lenovo downloads + read-only SPI dump; kit manifest | unit (kit) | prepare_safety_kit.sh --verify + hash greps | ❌ created in task | ⬜ pending |
| 45-01-T2 | 45-01 | 1 | WRE-01, WRE-02 | T-45-02 fabricated RE | Cited file+address+bytes findings; Ghidra headless artifacts kept in kit | unit (static) | evidence suite RE-citation greps | ❌ created in task | ⬜ pending |
| 45-01-T3 | 45-01 | 1 | WRE-03 | T-45-02 fabricated RE | intel_vbt_decode output recorded verbatim (DSI link config, MIPI seq version) | device (SSH) | decode output greps in evidence doc | ❌ created in task | ⬜ pending |
| 45-01-T4 | 45-01 | 1 | ROOT-01 | T-45-01 sweep tampering | Two-arm differential with ftrace/MMIO/backlight evidence, ≥18 s windows, rtcwake | device (SSH) | evidence suite arm-structure greps + chain | ❌ created in task | ⬜ pending |
| 45-02-T1 | 45-02 | 2 | ROOT-02, ROOT-03 | T-45-03 false-fix claim | DMI-gated fix built in CI, deployed, register-verified on-device (backlight returns without reload) | device (SSH) | per-iteration rtcwake + sysfs assertions logged in evidence doc | ❌ created in task | ⬜ pending |
| 45-02-T2 | 45-02 | 2 | ROOT-04 (conditional) | T-45-03 false-fix claim | If no fix: 5-iteration evidence + ROOT-04 proof doc; if fix: D330_REAL_FIX=1 marker step | unit (static) | evidence greps + chain | ❌ created in task | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Day-to-day UX confirmation after a landed fix | ROOT-02 (secondary) | The user's perception of daily usability is outside machine observation | After a landed fix: user uses the tablet normally across some suspend/resumes; NOT acceptance evidence — registers are |

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 60s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved — plan-checker iteration 1 issues fixed (ledger markers, --kit-dir, runnable chain command, per-candidate ledger cross-check, hook-absence branch, concrete CI dispatch/patch-carry/deploy loop with known-good .deb retention); gate passed=4 failed=0; all 6 tasks machine-verified.
