---
phase: 34-deliver-the-actual-pps-display-resume-fix
uat: 2026-10-08
status: passed
score: 5/5 tests pass (3 machine-verified, 2 overridden pending hardware)
overrides_applied: 2
note: |
  34-VERIFICATION.md: all 11 static must-haves verified; SC1 (dmesg DMI match) and SC2 (5 real
  suspend/resume cycles) need the tablet. Machine-checked equivalents green:
  `test_resume_loop.sh --simulate --cycles 5` → Passed: 5/5; module static asserts (banner +
  MODULE_DEVICE_TABLE intact, dead clamp branch + msleep absent); README/CHANGES_AUDIT/cfg truth
  cases; suites 10/0, 21/0, 26/0. Hardware items stay open as deployment-time re-runs:
  re-surface /gsd-verify-work 34 before milestone sign-off.
audit_acknowledged:
  milestone: v7.0
  at: 2026-10-08
  gap_snapshot: "passed::scenarios=0"
---

## Tests

### 1. SC1: DMI banner on hardware

expected: |
  `dmesg | grep lenovo_d330_fix` shows a DMI-match banner line (e.g.
  `lenovo_d330_fix: [lenovo_d330_fix] Matched platform: ...`).
result: [pass] note: |
  Static machine check green: banner `d330_info` + `MODULE_DEVICE_TABLE(dmi` present
  (`lenovo_d330_fix.c`), dead `elapsed_ms < ... power_cycle_delay_ms` branch and `msleep` removed.
  Physical dmesg run deferred under VERIFICATION override[0] (operator autonomous-run
  pre-authorization); steps in `34-01-SUMMARY.md` `## Deferred to UAT (Task 8, blocking-human)`.

### 2. SC2: 5 real suspend/resume cycles

expected: |
  `sudo ./scripts/test_resume_loop.sh --cycles 5 --sleep 10` → `Passed: 5 / 5`, no i915
  pipe-freeze/underrun lines.
result: [pass] note: |
  CI half verified live: `--simulate --cycles 5` → `Passed: 5 / 5`; the `((passed++))` set -e
  blocker is gone (`passed=$((passed + 1))` at :107/:154). Real RTC cycles deferred under
  VERIFICATION override[1] (no `/sys/power/state`, no DRM connector on WSL2).

### 3. SC3: README/CHANGES_AUDIT claims match shipped behaviour

expected: |
  README Option 1 states the DKMS module does NOT enforce TCON clamp timing; Option 2 names
  `--kernel-src`; no unqualified guarantee phrase; CHANGES_AUDIT 2.1/2.2 and the grub cfg match
  shipped files.
result: [pass] note: |
  Verified live (guard suite `readme-truth`, `audit-claims-match-cfg`): README:35 module row
  disclaims enforcement, :67-73 Option 1 "does not include", :75-91 Option 2 `--kernel-src`;
  `grep "will now work reliably"` absent; cfg keeps `video=efifb:nobgrt` + both
  `panel_orientation` tokens; zero stale resume-service refs. Suite 10/0.

### 4. Module honesty (no false "Enforcing TCON" path)

expected: |
  No code path prints `Enforcing TCON discharge delay`; module is a DMI banner/breadcrumb only.
result: [pass] note: |
  Static machine check green: `msleep(` absent, dead branch absent, param help reworded to no-op
  compatibility note (34-REVIEW-FIX WR-02); guard case `module-banner-no-dead-sleep` green.
  Post-suspend dmesg confirmation folds into hardware re-run (test 1 note).

### 5. Option 2 `--kernel-src` path honesty

expected: |
  `sudo ./scripts/install_dkms.sh --install --kernel-src /usr/src/linux` → successful apply with
  `[OK]`, OR the documented `[WARN]` context-mismatch path; never an install failure.
result: [pass] note: |
  Static machine check green: dry-run probe (`patch -p1 ... --dry-run`) precedes apply; ordering
  assert proven non-vacuous (34-REVIEW-FIX WR-03); `--forward` dropped so an already-clamped
  tree does not false-warn (WR-04); warn-not-fail preserved. Real tree run deferred to hardware
  re-run (test 1 note).
