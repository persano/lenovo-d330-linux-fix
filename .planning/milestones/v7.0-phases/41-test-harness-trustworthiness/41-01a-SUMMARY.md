---
phase: 41
plan: "01a"
subsystem: test-harness
tags: [test-harness, trustworthiness, bash, wsl, phase41]
requires: []
provides:
  - "harness scripts that can actually fail (non-zero on failed check / missing subject)"
  - "system mutations gated behind --apply"
  - "parser/arith fixes (no ((x++)) abort, --stress/--cycle-test values consumed)"
  - "MODE dispatch + honest --test-toggle / fcc-unlock paths"
affects:
  - scripts/test_*.sh
tech-stack:
  added: []
  patterns:
    - "FAILED counter + explicit exit 1 on any failed check"
    - "--apply gate for every system mutation"
key-files:
  created: []
  modified:
    - scripts/test_resume_loop.sh
    - scripts/test_tablet_osk.sh
    - scripts/test_battery_power.sh
    - scripts/test_dock_switching.sh
    - scripts/test_memory_storage.sh
    - scripts/test_auto_hibernate.sh
    - scripts/test_hardware_controls.sh
    - scripts/test_iso_integrity.sh
    - scripts/test_cameras.sh
    - scripts/test_audio_profiles.sh
    - scripts/test_distro_packaging.sh
    - scripts/test_ci_workflows.sh
    - scripts/test_oom_protection.sh
    - scripts/test_touch_calibration.sh
    - scripts/test_acpi_cleanliness.sh
    - scripts/test_storage_cellular.sh
decisions:
  - "Task 3/4 overlapping scripts (hardware_controls, distro_packaging, ci_workflows) committed in the Task 4 commit: gsd-tools commit stages whole files, no hunk-level split available."
  - "test_storage_cellular --test-microsd kept as an honest, --help-documented alias of --probe (plan permits either distinct test or honest alias)."
metrics:
  duration: "~55 min"
  completed: "2026-10-08"
  tasks: 4
  commits: 4
status: complete
---

# Phase 41 Plan 01a: Test Harness Trustworthiness (Tasks 1-4) Summary

WSL bash 5.2 (`/usr/bin/python3`) was the canonical interpreter for every verify and gate.
Real failure counters, `--apply` mutation gates, and parser fixes turn the `test_*.sh`
harness from always-green into something that fails when its subject is broken.

This SUMMARY covers **Tasks 1-4 only**; Tasks 5-7 (SCRIPT_DIR anchoring, ISO dry-run
honesty, SC1/SC2 meta-guard + aggregate wiring) are pending and are handled by a later
executor. It is named `41-01a-SUMMARY.md` to avoid clashing with that executor's
`41-01-SUMMARY.md`.

## Tasks

### Task 1 - Parser + arithmetic (commit 9e164ca)
- `test_resume_loop.sh`: default log path moved off `docs/dumps/` to `/tmp`;
  `passed=$((passed + 1))` / `failed=$((failed + 1))` already replaced the
  `set -e`-aborting `((x++))` form.
- `test_tablet_osk.sh`: daemon calls now use real flags
  `--dry-run --simulate-dock` / `--dry-run --simulate-undock` (were nonexistent
  `--test-laptop` / `--test-tablet`).
- `test_battery_power.sh`: `--stress N` value is now consumed and validated
  (`^[0-9]+$`), no longer falls through to `*)` exit 1.
- `test_dock_switching.sh`: `--cycle-test N` value is now consumed and validated.

### Task 2 - Mutation gating behind --apply (commit 9cb426d)
- `test_battery_power.sh`: `--tune` is read-only unless `--apply` is given;
  `--apply` added to parsing and `show_help`.
- `test_memory_storage.sh`: `--trim` (fstrim), `--stress-zram`, `--stress-emmc`
  all require `--apply`; without it they print what they WOULD do. `--apply`
  documented in `show_help`.
- `test_thermals.sh` / `test_boot_speed.sh`: already gated (probe path runs the
  tool without `--apply`, apply path passes `--apply`); left unchanged and
  confirmed read-only by default.

### Task 3 - Failure counters (commit 69d3cce + portions of b268cab)
- `test_auto_hibernate.sh`, `test_iso_integrity.sh`, `test_cameras.sh`,
  `test_audio_profiles.sh`, `test_oom_protection.sh`, `test_touch_calibration.sh`,
  `test_acpi_cleanliness.sh` (commit 69d3cce).
- `test_hardware_controls.sh`, `test_distro_packaging.sh`, `test_ci_workflows.sh`
  (commit b268cab, bundled with their Task 4 changes).
- Removed `cmd || true` + unconditional `log_ok`/`exit 0`; missing subject
  (tool/binary/module/path/daemon) now increments `FAILED` and prints `[FAIL]`;
  each script exits 1 when `FAILED > 0`. `--dry-run` paths that legitimately
  validate repo artefacts stay green (`test_touch_calibration.sh --dry-run`,
  `test_distro_packaging.sh --dry-run`).

### Task 4 - MODE / toggle / storage (commit b268cab)
- `test_distro_packaging.sh`: parsed `MODE` is now consumed - `--probe` checks
  file presence + fields, `--dry-run` validates metadata syntax, both fail real.
- `test_ci_workflows.sh`: parsed `MODE` consumed - `--probe` strict,
  `--dry-run` tolerates the optional `name:` but both require `on:`/`jobs:` and
  exit non-zero on structural failure.
- `test_hardware_controls.sh`: `--test-toggle` only reports read-only without
  `--apply`; with `--apply` + root it snapshots `conservation_mode`, writes 1,
  restores the original, and verifies both, exiting 1 on any mismatch.
- `test_storage_cellular.sh`: removed the fabricated
  `fcc-unlock.d/8086:7360` path; the real `fcc-unlock.d/*` hooks are resolved
  and reported (`[OK]` non-empty / `[INFO]` empty / `[FAIL]` absent).
  `--test-microsd` is an honest, `--help`-documented alias of `--probe`.

## Deviations from Plan

- **Task 2 scope note:** `test_thermals.sh` and `test_boot_speed.sh` were already
  `--apply`-gated by an earlier phase, so no edits were required; only
  `test_battery_power.sh` and `test_memory_storage.sh` changed.
- **Commit granularity (Rule 3 - tooling):** three scripts
  (`test_hardware_controls.sh`, `test_distro_packaging.sh`,
  `test_ci_workflows.sh`) carry both Task 3 and Task 4 edits. `gsd-tools query
  commit --files` stages whole files, so hunk-level splitting was not possible;
  those files shipped in the Task 4 commit (b268cab) with Task 3's counters, and
  the Task 3 commit carries the 7 files whose changes were Task 3-only.

## Known Stubs

None.

## Threat Flags

None - test-harness only; no new network/auth/file-trust surface. Mutations are
now gated behind `--apply`, reducing surface.

## Verification (all run under WSL bash 5.2)

- Task 1 verify: `PARSER-OK` + simulate/parse behaviour checks `VERIFY1-PASS`.
- Task 2 verify: `APPLY-GATES-OK` + read-only preview behaviour `VERIFY2-PASS`.
- Task 3 verify: `FAILURE-COUNTERS-OK` + positive/negative behaviour `VERIFY3-PASS`.
- Task 4 verify: `MODE-TOGGLE-OK` + aggregate `test_storage_cellular.sh --dry-run`
  rc 0, `VERIFY4-PASS`.
- Final gates: installer 17/0, hibernate 21/0, display 10/0, microsd 26/0,
  noop 5/0, udev 10/0, power 12/0, audio 17/0, rnnoise 7/0, `bash -n` all changed
  scripts OK, `FINAL-GATES: PASS`.

## Commits

1. `9e164ca` fix(41): parser/arith fixes in resume/dock/battery/tablet-osk harnesses
2. `9cb426d` fix(41): gate battery/memory mutations behind --apply
3. `69d3cce` test(41): real failure counters in 7 harness scripts
4. `b268cab` fix(41): MODE dispatch, --test-toggle --apply gate, honest FCC/microsd paths

## Self-Check: PASSED

- Files exist: all 16 modified scripts verified by `bash -n` and behaviour runs.
- Commits exist: 9e164ca, 9cb426d, 69d3cce, b268cab (see `git log`).
- Gates: `FINAL-GATES: PASS`.
