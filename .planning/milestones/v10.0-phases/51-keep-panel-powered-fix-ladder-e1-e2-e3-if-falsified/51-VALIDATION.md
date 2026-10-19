---
phase: "51"
slug: "keep-panel-powered-fix-ladder-e1-e2-e3-if-falsified"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-17"
---

# Phase 51 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | bash gate scripts (repo convention; no unit-test framework for kernel patches) |
| **Config file** | none — scripts are self-contained with `--selftest`/`--fixtures` modes |
| **Quick run command** | `bash scripts/dsi_mmio_diff.sh --selftest && bash scripts/test_dsi_mmio_evidence.sh && bash scripts/test_pitfalls_ledger.sh` |
| **Full suite command** | same three gates + `bash scripts/prepare_safety_kit.sh --verify --kit-dir docs/dumps/re_kit` at phase gate |
| **Estimated runtime** | ~30 seconds |
| **Expected green counts** | selftest 52/0 · evidence 7/0 · ledger 4/0 |

---

## Sampling Rate

- **After every task commit:** the three-gate quick command (~30 s)
- **After every wave merge:** same gates + `git apply --check` of the patch against the apply-stack order (or rely on the CI apply step when no local tree)
- **Before `/gsd-verify-work`:** all gates green + CI run green + one completed device session per rung with kit `--verify` exit 0
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 51-xx (flag infra) | TBD | 1 | KEEP-01 | — | N/A | CI grep-proof | `gh run view <run> --json status,conclusion` + workflow greps | ❌ Wave 0 | ⬜ pending |
| 51-xx (E1 skips) | TBD | 1 | KEEP-02 | — | N/A | static gate + device session | gates above; on-device dump pair + marker capture + kit `--verify` | ❌ Wave 0 | ⬜ pending |
| 51-xx (E2 wake) | TBD | 2 | KEEP-03 | — | N/A | static gate + device session | `dsi_mmio_diff.sh` on the 4 s dump + eyes-on verdict | ❌ Wave 0 | ⬜ pending |
| 51-xx (lazy E3) | TBD | 2 | KEEP-04 | — | N/A | manual-only (conditional) | kit `--verify` exit 0 + ledger row — built only if E1 falsifies | ❌ Wave 0 | ⬜ pending |
| 51-xx (honest verdict) | TBD | 2 | KEEP-05 | — | N/A | static gate | `bash scripts/test_pitfalls_ledger.sh` (rows parse) | ❌ Wave 0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `patches/d330_dsi_keep_hot.patch` (final name per plan) — self-contained E1 helper + two-flag design + skip markers
- [ ] `.github/workflows/build-kernel.yml` — drop the two falsified applies (rows 31/32), add grep-proofs for new symbols/markers
- [ ] `scripts/capture_dsi_dumps.sh` — new resume arms for the ~0-1 s / ~4 s pair (naming + contract comment in same change)
- [ ] X=Y operational-set check (6-register literal) — `dsi_mmio_diff.sh` extension with selftest fixture, or pinned runbook grep one-liner
- [ ] ftrace/dmesg marker capture runbook block (enable → suspend → collect → disable, 18 s window)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| E1 suspend-side skip (eyes-on + ftrace) | KEEP-02 | Requires physical device suspend/wake with user present | One authorized session: deploy, arm markers, suspend, wake, collect dump pair + marker log, eyes-on panel verdict |
| E2 wake image (X=Y set + eyes-on) | KEEP-03 | Human observation of panel image after resume | Same session discipline; X=Y operational-set literals in the ~4 s dump + eyes-on image check; 5 user-triggered cycles on success |
| Battery cost quantification | KEEP-03/04 | On-device power measurement | Success-path only: 15-min S3 keep-hot ON vs OFF, battery % + upower deltas |
| E3 discriminator (conditional) | KEEP-04 | Built only if E1 falsifies; on-device | Pre-INIT_OTP DCS read (informative) + X=Y set dump + GPIO-144/ftrace rail evidence; ledger row |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
