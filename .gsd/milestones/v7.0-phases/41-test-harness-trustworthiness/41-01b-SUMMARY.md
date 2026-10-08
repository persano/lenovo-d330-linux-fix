---
phase: 41
plan: "01b"
subsystem: test-harness
tags: [test-harness, trustworthiness, bash, wsl, phase41, sc1, sc2, iso]
requires: []
provides:
  - "CWD-anchored harness scripts (work from repo root and scripts/)"
  - "build_live_iso.sh --dry-run real prerequisite validation (xorriso, paths, output parent, payload)"
  - "test_harness_trust.sh meta-guard (SC1 mutation, SC2 static --apply gate scan)"
affects:
  - scripts/test_*.sh
  - scripts/build_live_iso.sh
  - scripts/test_iso_integrity.sh
  - scripts/test_storage_cellular.sh
tech-stack:
  added:
    - "scripts/test_harness_trust.sh"
  patterns:
    - "SCRIPT_DIR repo-root anchor + cd for CWD independence"
    - "byte-exact snapshot restore in meta-guard (git-diff neutral to CRLF noise)"
    - "command-position-only static mutation scan (quotes/comments/heredoc prose excluded)"
key-files:
  created:
    - scripts/test_harness_trust.sh
  modified:
    - scripts/test_battery_power.sh
    - scripts/test_dock_switching.sh
    - scripts/test_thermals.sh
    - scripts/test_boot_speed.sh
    - scripts/test_memory_storage.sh
    - scripts/test_auto_hibernate.sh
    - scripts/test_hardware_controls.sh
    - scripts/test_cameras.sh
    - scripts/test_audio_profiles.sh
    - scripts/test_distro_packaging.sh
    - scripts/test_ci_workflows.sh
    - scripts/test_oom_protection.sh
    - scripts/test_touch_calibration.sh
    - scripts/test_acpi_cleanliness.sh
    - scripts/test_storage_cellular.sh
    - scripts/build_live_iso.sh
    - scripts/test_iso_integrity.sh
decisions:
  - "Task 5 anchor uses the requested SCRIPT_DIR=repo-root form plus cd; existing two-var anchors are reused (test_resume_loop.sh unchanged, test_storage_cellular.sh dry-run block kept)."
  - "Meta-guard restores mutated subjects from a byte-exact snapshot and checks cmp, because WSL git reports a pre-existing CRLF/LF disagreement on the fastboot cfg and would otherwise flag a clean restore."
  - "SC2 scans command-position invocations only; quoted assertion literals and heredoc help text are stripped so 'grep -q systemctl enable ...' and 'Validate the modprobe conf' are not counted as mutations."
metrics:
  duration: "~45 min"
  completed: "2026-10-08"
  tasks: 3
  commits: 3
status: complete
---

# Phase 41 Plan 01b: Test Harness Trustworthiness (Tasks 5-7) Summary

Tasks 5-7 make the `test_*.sh` harness CWD-independent, make the ISO dry-run
honest, and add a meta-guard that proves a broken subject actually fails a
script. WSL bash 5.2 was the canonical interpreter for every verify and gate.

This covers **Tasks 5-7 only**; Tasks 1-4 are in `41-01a-SUMMARY.md`.

## Tasks

### Task 5 - CWD anchoring (commit db505a8)

Added `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"` (repo root)
plus `cd "$SCRIPT_DIR"` to the harness scripts and routed their `tools/`,
`patches/`, and `packaging/` references through `"$SCRIPT_DIR/..."`:

- `test_battery_power.sh`, `test_dock_switching.sh`, `test_thermals.sh`,
  `test_boot_speed.sh`, `test_memory_storage.sh`, `test_auto_hibernate.sh`,
  `test_hardware_controls.sh`, `test_cameras.sh`, `test_audio_profiles.sh`,
  `test_distro_packaging.sh`, `test_ci_workflows.sh`, `test_oom_protection.sh`,
  `test_touch_calibration.sh`, `test_acpi_cleanliness.sh`,
  `test_storage_cellular.sh`.

`test_resume_loop.sh` was already anchored (`SCRIPT_DIR`/`REPO_ROOT` + `/tmp`
log) and references no `tools/`/`patches/` paths, so it was reused unchanged.
Each edited script was run from both the repo root and `scripts/` with the same
exit code (all rc 0 for the dry-run modes).

### Task 6 - ISO honesty (commit 1d080ff)

- `build_live_iso.sh --dry-run` now validates real prerequisites and exits
  non-zero with a specific `[ERR]` per failure: `xorriso`/`unsquashfs`/
  `mksquashfs` presence, an optional `--base-iso` file, the output parent
  directory, the injection source paths, and the `tools/d330-*` payload. The
  hardcoded fake manifest and the "validated successfully" line are gone.
- `test_iso_integrity.sh --dry-run` now anchors and runs the real build dry-run,
  failing non-zero when its prerequisites are unmet.

Verified under WSL: missing `xorriso` gives `BUILD_DRYRUN=NONZERO` with
`missing required ISO tool: xorriso`; a stubbed `xorriso` on PATH gives
`POSITIVE=0`; a bad `--output` parent and a bad `--base-iso` each exit non-zero
with their specific message; `test_iso_integrity.sh --dry-run` inherits
`NONZERO` and prints `[FAIL] build_live_iso.sh --dry-run reported unmet
prerequisites.`

### Task 7 - Meta-guard (commit 59a3d9f)

New `scripts/test_harness_trust.sh` (executable):

- **SC1**: breaks the subject of five representative scripts, asserts each exits
  NON-ZERO, then restores byte-exact and asserts the tree is clean.
  - `test_audio_dsp.sh --dry-run` via `label = bq_highpass` -> `bq_bogus`
  - `test_wireless_coex.sh --dry-run` via `rtw88_core` -> `rtw88_bogus`
  - `test_udev_hwdb_match.sh` via `pn82H0` -> `pnXX00`
  - `test_power_stack.sh` via `softlockup_panic=1` -> `softlockup_panic=0`
  - `test_tray_applet.sh` via the `.desktop` `Exec=` -> a bogus binary
- **SC2**: static scan over every `scripts/test_*.sh` for mutating
  `systemctl`, `fstrim`, `modprobe`, `nmcli radio`, and `/sys` or `/proc/sys`
  writes; anything found must be gated by `--apply`.
- Prints a PASS/FAIL summary and exits non-zero on failure.
- Wired into `test_storage_cellular.sh` (aggregate invocation + `bash -n` loop).

Negative control: a temporary `test_bogus_tmp.sh` containing an ungated
`systemctl restart` made the guard exit NONZERO with
`[FAIL] SC2 test_bogus_tmp.sh: mutation(s) systemctl present with no --apply
gate`; the temp file was removed.

## Deviations from Plan

- **Task 5 scope note:** `test_resume_loop.sh` needed no edit (already anchored,
  no `tools/`/`patches/` paths). `test_storage_cellular.sh` keeps its inner
  dry-run anchor and gains a top-level anchor plus `cd`.
- **Task 7 dirty-check (Rule 3, tooling):** WSL git reports the fastboot cfg as
  modified because the working copy is CRLF while the blob is LF (pre-existing;
  Windows git shows it clean). The meta-guard therefore proves restoration with
  a byte-exact `cmp` against its own snapshot and only flags a clean-to-dirty
  transition. SC2 was narrowed to command-position matches after a first pass
  false-positived on the `test_wireless_coex.sh` help text.

## Known Stubs

None.

## Threat Flags

None. The meta-guard only mutates repo files and restores them; it adds no
network, auth, or trust-boundary surface.

## Verification (all run under WSL bash 5.2)

Raw gate lines (`/tmp/phase41_gates.log`):

```
harness-trust          rc=0  |  Harness-trust meta-guard summary: passed=6 failed=0
storage-cellular       rc=0  |  Harness-trust meta-guard summary: passed=6 failed=0
symmetry               rc=0  |  Guard suite summary: passed=17 failed=0
hibernate              rc=0  |  Guard suite summary: passed=21 failed=0
display                rc=0  |  Guard suite summary: passed=10 failed=0
microsd                rc=0  |  Guard suite summary: passed=26 failed=0
noop                   rc=0  |  No-op guard summary: passed=5 failed=0
udev-match             rc=0  |  udev/hwdb match guard summary: passed=10 failed=0
power-stack            rc=0  |  power-stack guard summary: passed=12 failed=0
audio                  rc=0  |  Speaker DSP structure: passed=17 failed=0
rnnoise                rc=0  |  RNNoise structure: passed=7 failed=0
bash -n: 0 failure(s) across 40 scripts
```

`scripts/test_harness_trust.sh` passes from both the repo root and `scripts/`.

## Commits

1. `db505a8` refactor(41): anchor tools/patches refs to script dir in 15 harness scripts (Task 5)
2. `1d080ff` fix(41): real prerequisite validation in build_live_iso --dry-run; ISO integrity inherits it (Task 6)
3. `59a3d9f` test(41): add test_harness_trust.sh SC1/SC2 meta-guard; wire into aggregate (Task 7)

## Self-Check: PASSED

- Files exist: `scripts/test_harness_trust.sh` (new), 15 anchored scripts, and
  the two ISO scripts are all present and `bash -n` clean.
- Commits exist: db505a8, 1d080ff, 59a3d9f (see `git log`).
- Gates: harness-trust 6/0, storage-cellular rc 0, symmetry 17/0, hibernate 21/0,
  display 10/0, microsd 26/0, noop 5/0, udev-match 10/0, power-stack 12/0,
  audio 17/0, rnnoise 7/0, `bash -n` 0/40.
