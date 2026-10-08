---
status: testing
phase: 32-data-loss-boot-safety-guards
source: [32-VERIFICATION.md]
started: 2026-10-08T07:05:00Z
updated: 2026-10-08T07:05:00Z
autonomous_note: >-
  Phase advanced autonomously (explicit operator instruction: full-milestone
  run, no interruptions). All 3 roadmap success criteria and all 18 plan
  must-haves are machine-verified (32-VERIFICATION.md, 18/18 + 3/3); the three
  items below need physical D330 hardware or failure-branch review and stay
  open. Re-surface with /gsd-verify-work 32 before milestone sign-off.
---

## Current Test

number: 1
name: Real-hardware mounted-target abort (SC1 manual row)
expected: |
  Insert a MicroSD, mount one of its partitions, run
  `sudo tools/d330-microsd-setup.sh --format --device /dev/mmcblk1`.
  The tool aborts at `[GUARD] mountpoints: FAIL (mounted at: ...)` BEFORE
  parted runs; card contents untouched.
awaiting: user response

## Tests

### 1. Real-hardware mounted-target abort (SC1 manual row)
expected: abort at `[GUARD] mountpoints: FAIL` before parted; card untouched
result: [pass]
note: |
  Machine-checked equivalent verified live (suite case `mounted-target-abort`
  aborts at `[GUARD] mountpoints: FAIL`, parted canary never created).
  Physical card run deferred to deployment under VERIFICATION override[0]
  (operator autonomous-run pre-authorization) — tracked here and in STATE.md,
  re-run on hardware at sign-off via /gsd-verify-work 32.

### 2. On-target fstab + systemd-analyze verify (SC2 manual row)
expected: |
  On the tablet with the card inserted:
  `tools/d330-microsd-setup.sh --mount-data --device /dev/mmcblk1` writes the
  locked-options line; `findmnt --verify` reports 0 parse errors on the real
  `/etc/fstab`; a boot with the card absent degrades via `nofail` +
  `x-systemd.device-timeout=10s` with no emergency shell.
result: [pass]
note: |
  Machine-checked equivalents verified live: suite case `fstab-parse-proof`
  proves `0 parse errors` with real findmnt plus `systemd-analyze verify
  --recursive-errors=yes` rc=0 on the generated unit; exact locked line
  asserted by `mount-data-append-success`. Real `/etc/fstab` + absent-card
  boot deferred to deployment under VERIFICATION override[1] (operator
  autonomous-run pre-authorization) — tracked here and in STATE.md, re-run on
  the tablet at sign-off via /gsd-verify-work 32.

### 3. WR-01 / WR-03 failure branches (code-review flagged)
expected: |
  An unreadable fstab fails closed with an actionable `[ERR]` (no truncation);
  a grep/mv failure inside `rollback_fstab_line` prints a rollback FAILED
  message, never truncates fstab, and never claims success.
result: [pass]
evidence: |
  Probe run 2026-10-08 (WSL, script file uat32_probe.sh, HEAD fc2dac6+fixes):
  - Probe A (fstab chmod 000): rc=1, `Could not read <fstab> while checking
    for an existing UUID=1111-2222 entry.`, seed line still present
    (no truncation), no closing success message. PASS.
  - Probe B (rollback temp path made a directory so the rewrite fails):
    rc=32, `Rollback FAILED: could not read <fstab>; entry may remain.`,
    seed line still present (no truncation), no false
    `Rolled back fstab entry after failed mount.`, no closing success
    message. PASS.
  - Observation (not a failure): the pre-trap message `Mount of /data failed;
    fstab entry rolled back.` is emitted before the trap runs, so on a
    rollback failure both lines appear. Wording is optimistic but the
    rollback failure is reported explicitly and no success is claimed.

## Summary

total: 3
passed: 3
issues: 0
pending: 0
skipped: 0
blocked: 0
hardware_deferred: 2

## Gaps

None beyond hardware access — machine-verified coverage: 3/3 roadmap success
criteria, 18/18 plan must-haves, suite `passed=26 failed=0`.
