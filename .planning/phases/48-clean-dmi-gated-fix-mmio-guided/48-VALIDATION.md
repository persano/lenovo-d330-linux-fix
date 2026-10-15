---
phase: 48
slug: clean-dmi-gated-fix-mmio-guided
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-10-14
---

# Phase 48 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash test harness (`scripts/test_*.sh`, POSIX sh, exit-code based) |
| **Config file** | none — existing scripts are the framework |
| **Quick run command** | `bash scripts/test_pitfalls_ledger.sh` |
| **Full suite command** | `bash scripts/test_pitfalls_ledger.sh && bash scripts/test_dsi_mmio_evidence.sh && bash scripts/test_dsi_mmio_evidence.sh --fixtures && bash scripts/prepare_safety_kit.sh --verify` |
| **Estimated runtime** | ~10-30 seconds (machine gates; kernel build is CI, ~40-90 min) |

---

## Sampling Rate

- **After every task commit:** `bash scripts/test_pitfalls_ledger.sh`
- **After every plan wave:** full suite command
- **Per fix iteration (device):** deploy discipline (rollback sha-verified retained FIRST) → boot dump → user suspend/resume → verdict → at-wake dump → `scripts/dsi_mmio_diff.sh`
- **Justified latency exceptions:** CI-built kernel delivery is the CI pipeline itself (~40-90 min/run; locked by D-01 heritage); on-device sessions are human-paced by v9.0 rules. Per-commit machine feedback stays on the ledger gate.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 48-01-01 | 01 | 1 | FIX-01 | — | DMI-gated only; no banned lever re-proposal | static/source | `grep -c 'dmi_match' patch` + CI grep anchors + ledger gate | ❌ W0 | ⬜ pending |
| 48-01-02 | 01 | 1 | FIX-02 | — | patch applies + CI builds .deb artifact | static/source | CI run success + grep-proof step + artifact sha256 | ❌ W0 | ⬜ pending |
| 48-02-01 | 02 | 1 | FIX-02 | — | rollback retained+verified BEFORE every deploy | unit | device-side sha256 checks in deploy script/log | ❌ W0 | ⬜ pending |
| 48-02-02 | 02 | 2 | FIX-01, FIX-02 | — | user-triggered suspend/resume; eyes-on verdict; at-wake dump evidence; failures ledgered | manual | See Manual-Only table | N/A | ⬜ pending |
| 48-03-01 | 03 | 2 | FIX-01, FIX-02 | — | kit registration + guard chain green each iteration | unit | `prepare_safety_kit.sh --verify` + full suite | ✅ exists | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] CI grep anchors for the new fix patch (DMI gate string) added with the patch task
- [ ] Deploy discipline documented/staged before the first device session

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Panel shows desktop image after user-triggered resume | FIX-01 | Eyes-on is the only valid visibility proof (ledger row: sysfs never counts) | User: suspend via their chosen trigger; on wake report image/black in their own time |
| Per-iteration session verdicts | FIX-01, FIX-02 | One test per session, user-paced | Each iteration: one suspend/resume session; verdict + (if black) at-wake dump for the ledger |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency documented (CI exceptions justified)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
