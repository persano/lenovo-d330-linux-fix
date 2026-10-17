---
phase: "50"
slug: "tcon-identification-dcs-id-read-instrument-software-only"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-16"
---

# Phase 50 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash gate scripts (repo convention; no unit-test framework for kernel patches) |
| **Config file** | none — scripts are self-contained with `--selftest`/`--fixtures` modes |
| **Quick run command** | `bash scripts/dsi_mmio_diff.sh --selftest && bash scripts/test_dsi_mmio_evidence.sh && bash scripts/test_pitfalls_ledger.sh` |
| **Full suite command** | same three gates (they are the gates) |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bash scripts/dsi_mmio_diff.sh --selftest && bash scripts/test_dsi_mmio_evidence.sh && bash scripts/test_pitfalls_ledger.sh`
- **After every plan wave:** Run same + `git apply --check` of the extended patch against a clean tree if available
- **Before `/gsd-verify-work`:** Full suite green + CI kernel built, deployed with rollback retained, both device sessions complete, all artifacts registered, `prepare_safety_kit.sh --verify` exits 0
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 50-xx (echo-2 section) | TBD | 1 | TCON-01 | — | N/A | static gate | `bash scripts/dsi_mmio_diff.sh --selftest` (new fixtures) + `bash scripts/test_dsi_mmio_evidence.sh` | ❌ Wave 0 | ⬜ pending |
| 50-xx (CI kernel) | TBD | 1 | TCON-01 | — | N/A | CI proof | `gh workflow run build-kernel.yml` + grep-proof step in workflow | ❌ Wave 0 | ⬜ pending |
| 50-xx (ID captures) | TBD | 1 | TCON-02 | — | N/A | device session | `bash scripts/prepare_safety_kit.sh --verify --kit-dir docs/dumps/re_kit` after registration | ❌ Wave 0 | ⬜ pending |
| 50-xx (I2C sweep) | TBD | 1 | TCON-03 | — | N/A | device session | `sudo scripts/tcon_i2c_sweep.sh` exit 0 + sha in manifest | ❌ Wave 0 | ⬜ pending |
| 50-xx (§6 label) | TBD | 1 | TCON-04 | — | N/A | static gate | `bash scripts/test_dsi_mmio_evidence.sh` | ❌ Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/dsi_mmio_diff.sh` selftest fixtures for the `# DCS ID READ` section (present-both / present-one-arm / SKIP annotation)
- [ ] `scripts/tcon_i2c_sweep.sh` — new file (skeleton in RESEARCH.md)
- [ ] `scripts/capture_dsi_dumps.sh` echo-2 mode + contract comment update
- [ ] CI workflow grep-proofs for the new symbols

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Black-resume (X=Z) ID-read arm | TCON-02 | Requires physical device suspend/resume with eyes-on at the wake window | One user-authorized device session: suspend, wake, run echo-2 capture before/after GOP re-init, register in kit manifest |
| Eyes-on panel state (X=Y vs X=Z) | TCON-02 | Human observation of panel image | Observe panel after boot (expect image) and after S3 resume (expect black), record in session log |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
