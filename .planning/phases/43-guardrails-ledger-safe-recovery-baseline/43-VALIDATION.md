---
phase: 43
slug: guardrails-ledger-safe-recovery-baseline
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-10-12
---

# Phase 43 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | House bash guard harness — 36 `scripts/test_*.sh` suites, case-function pattern, wired into `scripts/test_storage_cellular.sh` |
| **Config file** | none — pattern lives in each suite (research §Architecture Patterns, Pattern 1) |
| **Quick run command** | `bash scripts/test_pitfalls_ledger.sh` / `bash scripts/test_safety_kit.sh` / `bash scripts/test_display_fix_guards.sh` / `bash scripts/test_installer_symmetry.sh` (per touched suite) |
| **Full suite command** | `bash scripts/test_storage_cellular.sh --dry-run` plus `bash scripts/test_harness_trust.sh` |
| **Estimated runtime** | ~60 seconds (full harness) |

---

## Sampling Rate

- **After every task commit:** `bash -n` on touched scripts + the touched suite(s)
- **After every plan wave:** `bash scripts/test_storage_cellular.sh --dry-run` (full chained harness)
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 60 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| (seeded — planner fills per task) | | | GUARD-01 | T-43-01 ledger bypass | Gate prints file:line hits; allowlist per-string | unit (static) | `bash scripts/test_pitfalls_ledger.sh` | ❌ W0 | ⬜ pending |
| (seeded — planner fills per task) | | | GUARD-02 | T-43-01 ledger bypass | Non-zero on planted banned-lever fix; pristine passes | unit (fixture) | `bash scripts/test_pitfalls_ledger.sh` | ❌ W0 | ⬜ pending |
| (seeded — planner fills per task) | | | GUARD-03 | T-43-02 kit tampering | `sha256sum -c` passes pristine, fails tampered | unit (fixture) | `bash scripts/test_safety_kit.sh` | ❌ W0 | ⬜ pending |
| (seeded — planner fills per task) | | | RECOV-01 | T-43-05 resume wedge | 82H0 gate, timeout 30, no retry, DM ladder, stand-down | unit (static) | `bash scripts/test_display_fix_guards.sh` | ✅ cases new | ⬜ pending |
| (seeded — planner fills per task) | | | RECOV-02 | T-43-03 packaging drift | Hook shipped by all packagers + CI; manifest entry | unit (static+fixture) | `bash scripts/test_installer_symmetry.sh` | ✅ cases new | ⬜ pending |
| (seeded — planner fills per task) | | | RECOV-03 | T-43-04 silent disable | Idempotent; state SKIP/OK/DRIFT; `D330_REAL_FIX=1` stand-down logged | unit (fixture) | `bash scripts/test_installer_symmetry.sh` + `bash scripts/test_display_fix_guards.sh` | ✅ cases new | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/test_pitfalls_ledger.sh` — covers GUARD-01, GUARD-02 (new suite; ledger doc is its Phase-1 task input)
- [ ] `scripts/test_safety_kit.sh` — covers GUARD-03 (fixture-based; no real artifacts needed)
- [ ] `bash -n` list + suite chain in `scripts/test_storage_cellular.sh` gains both new suites
- [ ] `CHANGES_AUDIT.md` test count updated 36→38 (`test_doc_parity.sh` fails without it)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Golden `i915.ko.zst`, live USB, VBT/GOP dump staged off-device | GUARD-03 | Repo has no hardware access; runbook executes on the D330 at deployment | Follow `docs/research/RESUME_CAPTURE_PROTOCOL.md` kit staging section; verify `MANIFEST.sha256` |
| After resume on 82H0 display is automatically restored | RECOV-01 | Requires real suspend/resume cycle on the tablet | Suspend via `rtcwake -m mem`/lid, confirm panel returns after DM restart, check `journalctl -t d330-display` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
