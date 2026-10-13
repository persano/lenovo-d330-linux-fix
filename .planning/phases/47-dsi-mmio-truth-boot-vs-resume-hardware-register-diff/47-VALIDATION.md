---
phase: 47
slug: dsi-mmio-truth-boot-vs-resume-hardware-register-diff
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-10-13
---

# Phase 47 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash test harness (`scripts/test_*.sh`, POSIX sh, exit-code based) |
| **Config file** | none — existing scripts are the framework |
| **Quick run command** | `bash scripts/test_pitfalls_ledger.sh` (ledger gate; must stay green) |
| **Full suite command** | `bash scripts/test_pitfalls_ledger.sh && bash scripts/test_re_diff_evidence.sh && bash scripts/test_safety_kit.sh` |
| **Estimated runtime** | ~10-30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash scripts/test_pitfalls_ledger.sh`
- **After every plan wave:** Run `bash scripts/test_pitfalls_ledger.sh && bash scripts/test_re_diff_evidence.sh`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 47-01-01 | 01 | 1 | MMIO-01 | — | dump patch gates machine-hanging reads on PLL state | static/source | `grep -c "bxt_dsi_pll_is_enabled" patch` + CI build | ❌ W0 | ⬜ pending |
| 47-01-02 | 01 | 1 | MMIO-01 | — | debugfs node registered; both-state dumps produced | static/source | CI artifact check + dump file presence | ❌ W0 | ⬜ pending |
| 47-02-01 | 02 | 1 | MMIO-01 | — | dumps checksummed and registered in RE kit manifest | unit | `scripts/prepare_safety_kit.sh --verify` | ✅ | ⬜ pending |
| 47-03-01 | 02 | 1 | MMIO-01, MMIO-02 | — | DSI_MMIO_DIFF.md rows cite offset+file+line; exclusions have reasons; claim form correct; ledger-allow markers present | static/source | `bash scripts/test_re_diff_evidence.sh` + `bash scripts/test_pitfalls_ledger.sh` | ⚠ extend | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Extend `scripts/test_re_diff_evidence.sh` (or add a phase-47 checker) to assert DSI_MMIO_DIFF.md structure: per-row evidence citations, exclusion-reasons table, single testable-claim section, "what to restore/replicate" section, planner-discipline-allow markers for banned-row alias strings
- [ ] No new framework — existing bash harness covers all phase requirements

*Existing infrastructure covers most phase requirements; the doc-structure checker is the Wave 0 addition.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Working-boot dump taken with visible image | MMIO-01 | GOP handover state only exists on real hardware at boot | User: after fresh boot (desktop visible), run the dump echo command before any suspend |
| Broken-resume dump taken while panel still black, ≤18 s window | MMIO-01 | Panel-visible state is human-observable only | User: `systemd-inhibit --what=idle` held; suspend via `rtcwake -m mem`; immediately after resume, confirm panel black and run dump echo |
| Panel verdict (lit-black vs image) per state | MMIO-01 | Eyes-on proof; sysfs never trusted (ledger row) | User reports panel state per dump point in their own time |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
