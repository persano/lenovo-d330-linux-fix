---
phase: "50"
slug: "tcon-identification-dcs-id-read-instrument-software-only"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: validated
nyquist_compliant: true
wave_0_complete: true
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
| 50-01 T1 + 50-02 T2 (echo-2 section tooling) | 50-01, 50-02 | 1 | TCON-01 | T-50-05 | N/A | static gate | `bash scripts/dsi_mmio_diff.sh --selftest` (fixtures J-M for DCS section: present-both / present-one-arm / SKIP / absent-both) + `bash scripts/test_dsi_mmio_evidence.sh` | ✅ fixtures J-M live (selftest 52/0 run during this audit) | ✅ green |
| 50-01 T2 (CI kernel) | 50-01 | 1 | TCON-01 | — | N/A | CI proof | `gh run view 38974632465 --json status,conclusion` (success) + grep-proof step at build-kernel.yml:128-129 | ✅ grep-proofs live in workflow (verified this audit) | ✅ green |
| 50-04 T2/T3 (ID captures Session A, X=Y) | 50-04 | 2 | TCON-02 | T-50-11 | N/A | device session (manual-only, executed) | `bash scripts/prepare_safety_kit.sh --verify --kit-dir docs/dumps/re_kit` exit 0 (run during this audit) | ✅ tcon_boot_dsi_regs.txt + _run2 kit-registered | ✅ green |
| 50-04 T2 (I2C sweep + boot trace) | 50-04 | 2 | TCON-03 | — | N/A | device session (manual-only, executed) | sweep run exit 0 on device + sha in MANIFEST.sha256; kit `--verify` exit 0 | ✅ tcon_i2c_sweep.txt/_run2 + tcon_i2c_trace_boot/_run2 kit-registered | ✅ green |
| 50-05 T1/T2 (Session B X=Z + diff) | 50-05 | 3 | TCON-02, TCON-03 | T-50-15 | N/A | device session (manual-only, executed) | kit `--verify` exit 0; diff contains `## DCS ID READ comparison` block | ✅ tcon_resume_dsi_regs.txt + tcon_i2c_trace_resume.txt + diff kit-registered | ✅ green |
| 50-03 T1/T2 (§6 label) | 50-03 | 1 | TCON-04 | T-50-07 | N/A | static gate | `bash scripts/test_dsi_mmio_evidence.sh` (7/0) + `bash scripts/test_pitfalls_ledger.sh` (4/0), both run during this audit | ✅ §6 rows corrected, gates green | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `scripts/dsi_mmio_diff.sh` selftest fixtures for the `# DCS ID READ` section (present-both / present-one-arm / SKIP annotation) — closed by 50-02 T2 (fixtures J/K/L/M, commit 65e89cc, selftest 52/0)
- [x] `scripts/tcon_i2c_sweep.sh` — new file — closed by 50-02 T3 (commit e8d08c5, `bash -n` clean, on-device run in 50-04)
- [x] `scripts/capture_dsi_dumps.sh` echo-2 mode + contract comment update — closed by 50-02 T1 (commit 8b03ca1, boot2/resume2 arms)
- [x] CI workflow grep-proofs for the new symbols — closed by 50-01 T1 (commit 8df3c56, build-kernel.yml:128-129, resolving in green run 38974632465)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions | Executed |
|----------|-------------|------------|-------------------|----------|
| Black-resume (X=Z) ID-read arm | TCON-02 | Requires physical device suspend/resume with eyes-on at the wake window | One user-authorized device session: suspend, wake, run echo-2 capture before/after GOP re-init, register in kit manifest | ✅ 50-05 Session B (2026-10-16, one boot/suspend/wake; resume2 capture sha `da692043…3f24`; verdict verbatim in 50-05-SUMMARY) |
| Eyes-on panel state (X=Y vs X=Z) | TCON-02 | Human observation of panel image | Observe panel after boot (expect image) and after S3 resume (expect black), record in session log | ✅ 50-04 Session A (X=Y, "image visible" both runs) + 50-05 Session B (X=Z, "screen lit but black") — verdicts verbatim in SUMMARYs |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies — every task in 50-01…50-05 declared an `<automated>` verify (50-04 T2 / 50-05 T1 additionally carry blocking-human gates, both executed with eyes-on verdicts recorded)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify — 13 tasks total, all but the two documented manual-only device sessions ran static gates (~30 s) after every commit (per-plan gate records + 50-VERIFICATION.md live re-runs)
- [x] Wave 0 covers all MISSING references — 4/4 Wave 0 items closed during execution (50-01 T1, 50-02 T1/T2/T3)
- [x] No watch-mode flags
- [x] Feedback latency < 30 s — selftest/evidence/ledger gates each run in well under 30 s (re-run live during this audit: 52/0, 7/0, 4/0, kit --verify exit 0)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated 2026-10-17 (Nyquist audit: all gates re-run live and green; manual-only rows executed; Wave 0 fully closed. Non-blocking Info notes 1-3 in 50-VERIFICATION.md remain surfaced for developer decision — none fails a truth or blocks Phase 51.)
