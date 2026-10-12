---
phase: 44
slug: community-upstream-survey-cheap-levers
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-10-12
---

# Phase 44 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | House bash guard harness (38 suites) + on-device SSH evidence capture; no new suite this phase (deliverables are docs + on-device evidence, machine-checked by plan acceptance, the ledger gate which scans docs/research, and the phase verifier) |
| **Config file** | none |
| **Quick run command** | `bash scripts/test_pitfalls_ledger.sh` (gate over the new research docs) |
| **Full suite command** | `bash scripts/test_storage_cellular.sh --dry-run` |
| **Estimated runtime** | ~60 s harness; sweep is device-bound (rtcwake windows) |

## Sampling Rate

- **After every task commit:** `bash -n` on touched scripts + ledger gate if docs/research touched
- **After plan wave:** full chained harness once (no wave-1 races this phase — single plan)
- **Device-side sampling:** every sweep step logs its command + output to the results doc; panel verdicts are user-confirmed (one structured pause)

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 44-01-T1 | 44-01 | 1 | SURVEY-02 | T-44-01 sweep tampering | Two-kernel resume test with Phase 43 protocol; evidence captured per kernel; no boot/cmdline changes | device (SSH) | sweep script run + evidence files present | ❌ created in task | ⬜ pending |
| 44-01-T2 | 44-01 | 1 | SURVEY-01 | — | Survey doc with cited URLs; unreachable sources marked, not guessed | unit (static) | ledger gate over docs/research + doc section greps | ✅ created in task | ⬜ pending |
| 44-01-T3 | 44-01 | 1 | SURVEY-03 | T-44-02 fabricated evidence | Bug report carries real trace evidence + reproducer + versions; filing handoff documented | unit (static) | doc block greps + ledger gate | ✅ created in task | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Panel lit/black verdict per sweep kernel | SURVEY-02 | Remote SSH cannot see the physical panel; registers and CRTC reads read identical on black vs working (prior sessions) | User confirms panel state per kernel test during the structured pause |
| Upstream issue submission (SURVEY-03) | SURVEY-03 | Tracker is bot-blocked for scripts; no credentials on this machine | User opens issue 6619 (or files new), pastes the prepared report |

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
