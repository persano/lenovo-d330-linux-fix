---
phase: 32
slug: data-loss-boot-safety-guards
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-10-07
---

# Phase 32 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash + repo harness (`scripts/test_*.sh`) — no unit-test framework in this project |
| **Config file** | none — harness is plain shell |
| **Quick run command** | `bash -n tools/d330-microsd-setup.sh` |
| **Full suite command** | `bash scripts/test_storage_cellular.sh --dry-run` |
| **Estimated runtime** | ~2 seconds |

Environment note: verification runs on the dev machine with GNU bash 5.2 (Git Bash); `shellcheck` is **not** installed, `parted`/`lsblk`/`findmnt`/`udevadm` are **not** available — anything needing them is either mocked, exercised through `--dry-run`, or listed under Manual-Only.

---

## Sampling Rate

- **After every task commit:** `bash -n tools/d330-microsd-setup.sh && bash scripts/test_storage_cellular.sh --dry-run`
- **After every plan wave:** same as above plus `bash -n` over every `.sh` file touched in the wave
- **Before `/gsd-verify-work`:** full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| *(rows seeded per task by the planner — one row per task, automated command must be the quick or full command above or a mocked guard test)* | | | | | | | | | |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/test_storage_cellular.sh` — extend with guard tests: mounted-target abort, root-device refusal, missing `--device`, dry-run PASS/FAIL report (mocked `lsblk`/`findmnt`/`mkfs` via `PATH` shim; no real disk touched)
- [ ] `scripts/test_storage_cellular.sh --dry-run` — must actually syntax-check the tool (`bash -n`) instead of echoing only

*Existing framework covers phase requirements otherwise; no framework install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `--format` on a real MicroSD with a mounted partition aborts before any write | SC 1 | destructive, needs real hardware + inserted card | Insert card, mount a partition on it, run `sudo tools/d330-microsd-setup.sh --format --device /dev/mmcblk1`; expect abort before `parted`, card contents untouched |
| fstab line parses under `systemd-analyze verify` | SC 2 | needs systemd target device | Run `--mount-data`, then `findmnt --verify` and `systemd-analyze verify --recursive-errors=yes` on the generated `.mount` unit |
| `--dry-run` prints the guard outcomes | SC 3 | — *(automated in Wave 0: assert PASS/FAIL lines in output)* | automated |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending