---
phase: 34-deliver-the-actual-pps-display-resume-fix
fixed_at: 2026-10-08T14:45:00Z
review_path: .planning/phases/34-deliver-the-actual-pps-display-resume-fix/34-REVIEW.md
iteration: 1
findings_in_scope: 9
fixed: 9
skipped: 0
status: all_fixed
---

# Phase 34: Code Review Fix Report

**Fixed at:** 2026-10-08T14:45:00Z
**Source review:** `.planning/phases/34-deliver-the-actual-pps-display-resume-fix/34-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 9 (1 Critical, 6 Warning, 2 Info — `fix_scope: all`)
- Fixed: 9
- Skipped: 0

## Fixed Issues

### CR-01: README still claims the DKMS module enforces TCON discharge

**Files modified:** `README.md`
**Commit:** `f0aa35b`
**Applied fix:** Reworded the Standalone DKMS Module deliverable row to "prints a DMI-matched banner/breadcrumb; it does NOT enforce TCON discharge timing — the Option 2 kernel clamp patch delivers that." Removes the T-34-03 false-advertising root cause.

### WR-01: CHANGES_AUDIT 2.1 still claims clamp + resume hook that no longer exist

**Files modified:** `CHANGES_AUDIT.md`
**Commit:** `f034468`
**Applied fix:** Rewrote §2.1 How-Decided/What-Done: the module is now described as a DMI banner + honest breadcrumbs only, the deleted systemd resume hook reference is gone, and the 600 ms clamp is attributed to the Option 2 kernel patch.

### WR-02: dead `power_cycle_delay_ms` param still advertises enforcement

**Files modified:** `patches/dkms/lenovo-d330-fix/lenovo_d330_fix.c`
**Commit:** `ed0ef59`
**Applied fix:** Reworded `MODULE_PARM_DESC` and added a comment to state the parameter is a no-op retained only for compatibility; it does not enforce any delay. The variable stays referenced (compiles clean) and the file still contains `d330_info`, so the guard suite's module case passes.

### WR-03: `kernel-src-dryrun-first` ordering assertion is vacuous

**Files modified:** `scripts/test_display_fix_guards.sh`
**Commit:** `f1a06e8`
**Applied fix:** `fixed: requires human verification` (assertion logic). The case now matches the probe on a line starting with `patch` that carries `--dry-run`, and the real apply on a `patch` line without `--dry-run`, then compares those two line numbers. Proven non-vacuous: with the two lines swapped in a temporary copy the case fails (dry=137 >= apply=121); on the shipped file it passes (dry=121 < apply=137).

### WR-04: `--forward` dry-run misreports an already-applied clamp

**Files modified:** `scripts/install_dkms.sh`
**Commit:** `24ae0fe`
**Applied fix:** `fixed: requires human verification` (control-flow logic). Dropped `--forward` from the clamp-patch dry-run probe so an already-clamped tree no longer trips the `[WARN] clamp is NOT delivered` false negative. The warn-not-fail posture is unchanged.

### WR-05: `readme-truth` cannot catch the surviving false claim

**Files modified:** `scripts/test_display_fix_guards.sh`
**Commit:** `cbf0a83`
**Applied fix:** Added asserts that the DKMS-module deliverable row must explicitly state it does NOT enforce TCON timing AND must not contain the old positive-advertising phrasings. Proven non-vacuous: the pre-CR-01 row fails the new check, the reworded row passes.

### IN-01: zero-ref sweep skips patches/README.md, which keeps the unit literal

**Files modified:** `patches/README.md`
**Commit:** `8d6ed66`
**Applied fix:** Removed the contiguous `lenovo-d330-resume.service` literal (now "the echo-only DKMS resume service unit was removed in phase 34"). While in the same file, corrected the adjacent DKMS-package bullets that also falsely advertised enforcement and `power_cycle_delay_ms` tuning, to match the banner-only truth.

### IN-02: CLI arg values not validated in test_resume_loop.sh

**Files modified:** `scripts/test_resume_loop.sh`
**Commit:** `6e25aea`
**Applied fix:** `fixed: requires human verification` (arg-parsing logic). Added `require_arg` (presence + reject flag-as-value) and `require_uint` (`^[0-9]+$`) guards for `--cycles/--sleep/--wake/--log`; missing/invalid values print usage and exit 1. A trailing flag no longer aborts on unbound `$2`, and a non-numeric `--cycles` no longer silently runs 0 cycles and exits 0.

## Verification

Gates were run inside **WSL (Ubuntu, Linux)** against the worktree, because the intended gate runner is a Linux shell. The Windows checkout is `core.autocrlf=true` (index/blobs are LF, working tree CRLF); CRLF made WSL bash choke on scripts and made 2 hibernate cases (`execstart-matches-install-path`, `type-oneshot-kept`) fail spuriously. After stripping CR from the worktree text files (content-neutral for git, index already LF), all gates pass.

Raw gate tails:

```
#### scripts/test_display_fix_guards.sh
  [OK] module-banner-no-dead-sleep
  [OK] resume-service-deleted-zero-refs
  [OK] kernel-src-dryrun-first
  [OK] nobgrt-kept
  [OK] panel-orientation-present
  [OK] audit-claims-match-cfg
  [OK] dkms-build-guards
  [OK] resume-loop-arithmetic-fixed
  [OK] resume-loop-simulate-5
  [OK] readme-truth
 Guard suite summary: passed=10 failed=0
 rc=0

#### scripts/test_resume_loop.sh --simulate --cycles 5
 Test Summary: Passed: 5 / 5, Failed: 0 / 5
 rc=0

#### scripts/test_hibernate_guards.sh
  [OK] execstart-matches-install-path
  [OK] type-oneshot-kept
 ...
 Guard suite summary: passed=21 failed=0
 rc=0

#### scripts/test_storage_cellular.sh --dry-run
 ... Guard suite summary: passed=26 failed=0
 [OK] dry-run verification complete
 rc=0

#### bash -n on touched scripts
 bash -n scripts/install_dkms.sh rc=0
 bash -n scripts/test_resume_loop.sh rc=0
 bash -n scripts/test_display_fix_guards.sh rc=0
```

---

_Fixed: 2026-10-08T14:45:00Z_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_
