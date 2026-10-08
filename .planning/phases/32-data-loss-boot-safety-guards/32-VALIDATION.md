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

Environment note (measured 2026-10-07): verification runs under **WSL GNU bash 5.2.21(1)** reached through `c:\windows\system32\bash.exe` (Linux 6.18.40.1-microsoft-standard-WSL2, non-root UID 1000, user `santiago`). **Available there:** `lsblk`, `findmnt` (util-linux 2.39.3), `udevadm`, `systemd-analyze` (systemd 255, advertises `--recursive-errors=yes`), `mkfs.ext4`. **Not available:** `shellcheck`, `parted`, `partprobe` — anything needing `parted`/`partprobe` is mocked by the PATH shims or listed under Manual-Only, and no real disk is ever written (non-root, no card inserted). **Git Bash is a different shell — 5.3.15(1) — and lacks `lsblk`, `findmnt`, `udevadm` and `systemd-analyze` entirely**, so every `<automated>` block must be run with the WSL `bash` on `PATH`, never Git Bash. All `<automated>` blocks are wrapped in `bash -c '...'` so they are paste-safe from the pwsh session shell.

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
| 32-01-T1 | 32-01 | 1 | SC1, SC3 | T-32-01, T-32-02, T-32-03 | Explicit `--device` required for destructive actions; three ordered guards before the first `parted` write; no mkfs force flag; `partprobe` + `udevadm settle` instead of `sleep 1` | unit (tracer) | `bash -n tools/d330-microsd-setup.sh && bash -c '<tracer assertions>'` — full block in 32-01-PLAN Task 1 `<verify>` | `tools/d330-microsd-setup.sh` | ⬜ pending |
| 32-01-T2 | 32-01 | 1 | SC1, SC3 | T-32-01, T-32-03 | Abort-before-write proven by the parted canary under PATH shims; bidirectional root refusal; dry-run PASS/FAIL report | mocked guard test | `bash scripts/test_microsd_guards.sh` → 12 cases, `failed=0` | `scripts/test_microsd_guards.sh` | ⬜ pending |
| 32-02-T1 | 32-02 | 2 | SC2 | T-32-05, T-32-06, T-32-07, T-32-08 | Locked option string; confirm → `mkdir -p "$MOUNT_POINT"` → `findmnt --verify --tab-file` → append → mount; rollback trap on mount failure; duplicate/legacy refusal | unit | `bash -n tools/d330-microsd-setup.sh && bash -c '<mount-data assertions>'` — full block in 32-02-PLAN Task 1 `<verify>` | `tools/d330-microsd-setup.sh` | ⬜ pending |
| 32-02-T2 | 32-02 | 2 | SC2 | T-32-05, T-32-06 | Nine `mount-data-*` cases plus `fstab-parse-proof` (`0 parse errors` required; `unreachable on boot required source\|target` recorded as `[WARN]`, strict rc-0 on a resolvable source; `.mount` unit under `systemd-analyze verify`) | mocked guard test | `bash scripts/test_microsd_guards.sh` → `failed=0`, `[OK] fstab-parse-proof` | `scripts/test_microsd_guards.sh` | ⬜ pending |
| 32-03-T1 | 32-03 | 3 | SC3 | T-32-09, T-32-11 | `--mount-home` exits non-zero with `not implemented` after the locked `--device` check; exactly one success message, reachable only from genuine completion | unit | `bash -n tools/d330-microsd-setup.sh && bash -c '<stub/help assertions>'` — full block in 32-03-PLAN Task 1 `<verify>` | `tools/d330-microsd-setup.sh` | ⬜ pending |
| 32-03-T2 | 32-03 | 3 | SC1, SC2, SC3 (phase gate) | T-32-10 | Harness `--dry-run` runs real `bash -n` gates over the tool and both test scripts and delegates the guard suite; `--probe`/`--test-microsd` unchanged | unit | `bash scripts/test_storage_cellular.sh --dry-run` → `[OK] bash -n ...` ×3, `failed=0` | `scripts/test_storage_cellular.sh` | ⬜ pending |
| 32-03-T3 | 32-03 | 3 | SC1, SC2, SC3 + locks | T-32-09 | Final stub/help/completion-honesty cases and the whole phase gate green from the legacy harness | unit | `bash scripts/test_microsd_guards.sh` then the full gate chain in 32-03-PLAN `<verification>` | `scripts/test_microsd_guards.sh` | ⬜ pending |

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