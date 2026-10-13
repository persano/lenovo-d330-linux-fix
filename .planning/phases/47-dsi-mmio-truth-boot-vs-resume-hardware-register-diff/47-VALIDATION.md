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
| **Full suite command** | `bash scripts/test_pitfalls_ledger.sh && bash scripts/test_dsi_mmio_evidence.sh && bash scripts/test_re_diff_evidence.sh && bash scripts/test_safety_kit.sh` |
| **Estimated runtime** | ~10-30 seconds |

*Note: `test_dsi_mmio_evidence.sh` real mode is red-until-evidence by design — its `--fixtures` mode is green from wave 1 (47-02 Task 2), real mode goes green when 47-04 lands the evidence. A plain-run red before 47-04 is expected, not a regression.*

---

## Sampling Rate

- **After every task commit:** Run `bash scripts/test_pitfalls_ledger.sh`
- **After every plan wave:** Run `bash scripts/test_pitfalls_ledger.sh && bash scripts/test_re_diff_evidence.sh`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds
- **Justified latency exceptions (47-01, nyquist_latency):** two 47-01 automated verifies intentionally exceed the 30 s bar and are recorded here as exceptions, not violations: (1) Task 2's CI build wait (~40 min) — kernel delivery is locked to the CI-built `.deb` by decision D-01, so this is a delivery constraint, not a per-commit feedback loop; (2) Task 1's on-device `make M=drivers/gpu/drm/i915 modules` compile check (minutes-long kernel build). Per-commit feedback stays within the bar via the ledger gate (`test_pitfalls_ledger.sh`, ~10-30 s); the long checks are once-per-task end proofs, not per-commit loops.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 47-01-01 | 01 | 1 | MMIO-01 | T-47-01, T-47-02, T-47-03 | dump patch: PLL-off gate on DSI reads, strictly additive, zero register writes, frozen-buffer dump format | static/source + device compile | repo: `grep -c "bxt_dsi_pll_is_enabled" patches/d330_dsi_dump.patch` + workflow grep anchors; device: `git apply --check` + `make M=drivers/gpu/drm/i915 modules` | ❌ | ⬜ pending |
| 47-01-02 | 01 | 1 | MMIO-01 | T-47-05 | CI run green incl. grep-proof step; dump-kernel .deb downloaded, sha256 recorded | CI artifact check | `gh run view <run-id> --json conclusion` = success; artifact contains linux-image-*-d330-fix_*.deb | ❌ | ⬜ pending |
| 47-02-01 | 02 | 1 | MMIO-01 | T-47-06, T-47-07 | diff tool joins dumps into cited rows; skip/all-ones state rows; exclusion table with true-semantics reasons (config vs W1C status vs RO status kept separate) | unit (selftest) | `bash scripts/dsi_mmio_diff.sh --selftest`; `bash -n scripts/dsi_mmio_diff.sh`; `bash scripts/test_pitfalls_ledger.sh` | ❌ | ⬜ pending |
| 47-02-02 | 02 | 1 | MMIO-01 | T-47-08 | evidence guard `scripts/test_dsi_mmio_evidence.sh` case logic proven green by --fixtures; real mode red-until-evidence (documented) | unit (fixtures) | `bash scripts/test_dsi_mmio_evidence.sh --fixtures`; plain mode exits non-zero (proves the suite can fail); `bash scripts/test_pitfalls_ledger.sh` | ❌ | ⬜ pending |
| 47-03-01 | 03 | 2 | MMIO-01 | T-47-10 | dump kernel deployed only after verified rollback; node present; capture helper staged (zero register writes) | integration (ssh) | ssh: `uname -r` = deployed version; `test -e /sys/kernel/debug/dri/0/i915_dsi_regs`; rollback .deb sha256 matches record; `bash scripts/test_pitfalls_ledger.sh` | ❌ | ⬜ pending |
| 47-03-02 | 03 | 2 | MMIO-01 | T-47-12, T-47-14 | one user-run capture session; both dumps fetched with sha256 matching helper output; eyes-on verdicts recorded | human-check (checkpoint) | manual — see Manual-Only Verifications rows 1-2 (post-session automated: both fetched files non-empty, sha256 match) | ❌ | ⬜ pending |
| 47-03-03 | 03 | 2 | MMIO-01 | T-47-11 | both dumps sha256-registered in kit manifest; --verify green | unit | `bash scripts/prepare_safety_kit.sh --verify --kit-dir docs/dumps/re_kit`; manifest grep counts 2 dump lines | ❌ | ⬜ pending |
| 47-04-01 | 04 | 3 | MMIO-01 | T-47-18 | diff artifact generated from the registered pair, reconciled vs prior 21-row table, itself manifest-registered | integration | kit `--verify` exits 0; manifest grep `dsi_regs_diff.txt` = 1; `bash scripts/test_pitfalls_ledger.sh` | ❌ | ⬜ pending |
| 47-04-02 | 04 | 3 | MMIO-01, MMIO-02 | T-47-15, T-47-16, T-47-17 | DSI_MMIO_DIFF.md passes real-mode evidence guard (≥10 citation anchors, exclusion table with reasons, exactly ONE claim section, handoff section, allow markers) | static/source | `bash scripts/test_dsi_mmio_evidence.sh` (real mode, exit 0) + `bash scripts/test_pitfalls_ledger.sh` | ❌ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Add `scripts/test_dsi_mmio_evidence.sh` — the new phase-47 checker, authored by 47-02 Task 2 (`test_re_diff_evidence.sh` stays untouched) — to assert DSI_MMIO_DIFF.md structure: per-row evidence citations, exclusion-reasons table, single testable-claim section, "what to restore/replicate" section, planner-discipline-allow markers for banned-row alias strings
- [ ] No new framework — existing bash harness covers all phase requirements

*Existing infrastructure covers most phase requirements; the new phase checker (47-02 Task 2) is the addition.*

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
