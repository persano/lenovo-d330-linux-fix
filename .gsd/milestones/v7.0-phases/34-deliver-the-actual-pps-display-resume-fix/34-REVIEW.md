---
phase: 34-deliver-the-actual-pps-display-resume-fix
reviewed: 2026-10-08T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - patches/dkms/lenovo-d330-fix/lenovo_d330_fix.c
  - patches/dkms/lenovo-d330-fix/dkms.conf
  - patches/boot_orientation/etc/default/grub.d/50-lenovo-d330-boot.cfg
  - scripts/install_dkms.sh
  - scripts/test_resume_loop.sh
  - scripts/test_display_fix_guards.sh
  - scripts/test_storage_cellular.sh
  - README.md
  - CHANGES_AUDIT.md
findings:
  critical: 1
  warning: 6
  info: 2
  total: 9
status: issues_found
---

# Phase 34: Code Review Report

**Depth:** standard | **Files Reviewed:** 9 | **Status:** issues_found

## Summary

Reviewed the Phase 34 delivery (`0b1e437..HEAD`). The C module correctly drops the
dead `msleep` clamp branch while keeping DMI/banner; the `--kernel-src` step is
quoted, eval-free, and dry-runs before applying; `dkms.conf` regexes are valid ERE
and `BUILD_EXCLUSIVE_KERNEL` does not refuse supported 5.15-5.99/6.x kernels;
`bash -n` and the guard suites pass locally (guard suite 10/0, resume loop --simulate
5/5, storage --dry-run 26/0/10/0/21/0). Remaining defects are truth claims that
survive the "honest banner" pass and two tests that assert less than they appear to.

## Critical Issues

### CR-01: README still claims the DKMS module enforces TCON discharge

**File:** `README.md:35`
**Issue:** The deliverables table says the standalone DKMS module is
"hooking kernel PM events to enforce safe TCON discharge without rebuilding
kernel". This is false and directly contradicts README:67-73, the module NOTE
(ly:21), and CHANGES_AUDIT:38. This is exactly the T-34-03 (high) false-advertising
root cause the phase was chartered to remove.
**Fix:** Reword to "prints a DMI-matched banner/breadcrumb; does NOT enforce TCON
timing (the Option 2 kernel patch does)".

## Warnings

### WR-01: CHANGES_AUDIT 2.1 still claims clamp + resume hook that no longer exist

**File:** `CHANGES_AUDIT.md:34` (and `:36`)
**Issue:** Line 34 still describes "a systemd resume hook that forces TCON discharge
sequencing" (unit deleted) and line 36 still says the DKMS module + dkms.conf
"clamp PPS delay" (module does not). 2.2 was corrected but 2.1 was not, so the audit
still misstates shipped behaviour.
**Fix:** Update 2.1 How-Decided/What-Done to state the module is a DMI banner only
and the clamp is delivered by the Option 2 patch.

### WR-02: dead `power_cycle_delay_ms` param still advertises enforcement

**File:** `patches/dkms/lenovo-d330-fix/lenovo_d330_fix.c:43`
**Issue:** `MODULE_PARM_DESC(power_cycle_delay_ms, "Enforced panel power cycle
discharge delay in ms")` no longer matches code; no path reads the variable, so the
param is dead while its help text tells users it enforces timing.
**Fix:** Delete the param (and line 41-42) or reword the description to state it is a
no-op retained only for compatibility.

### WR-03: `kernel-src-dryrun-first` ordering assertion is vacuous

**File:** `scripts/test_display_fix_guards.sh:131-137`
**Issue:** `dry` takes the first `--dry-run` match, which is the usage text at
install_dkms.sh:38, and `apply` takes the first `patch -p1 -d .* <` match, which is
the dry-run probe itself at :118. `dry(38) < apply(118)` always holds, so a real
reorder of dry-run vs real-apply can never fail this case.
**Fix:** Match the probe specifically on the same line as `--dry-run` and the real
apply on a line *without* `--dry-run`, then compare those two line numbers.

### WR-04: `--forward` dry-run misreports an already-applied clamp

**File:** `scripts/install_dkms.sh:118`
**Issue:** `patch --dry-run --forward` returns non-zero when the patch appears
already applied ("Skipping patch"), so a user whose tree already carries the clamp
gets `[WARN] ... clamp is NOT delivered` — a false negative.
**Fix:** Drop `--forward` from the dry-run probe (or parse the "previously applied"
message and report it as already-applied rather than not-applicable).

### WR-05: `readme-truth` cannot catch the surviving false claim

**File:** `scripts/test_display_fix_guards.sh:203-216`
**Issue:** The case only checks absence of "will now work reliably" and presence of
"does not include"; it passes while README:35 still claims module enforcement, so SC3
truth is only partially enforced.
**Fix:** Also assert README (and the module table) do not claim the module enforces
TCON/clamp timing.

## Info

### IN-01: zero-ref sweep skips patches/README.md, which keeps the unit literal

**File:** `patches/README.md:24` (and `scripts/test_display_fix_guards.sh:114-118`)
**Issue:** The deleted unit path literal survives in patches/README.md (annotated
"removed in phase 34"), and neither the plan's nor the suite's zero-reference sweep
scans that file. Commit 49bc93c ("remove stale resume-service reference") leaves the
contiguous literal.
**Fix:** Drop the path literal or add patches/README.md to the sweep.

### IN-02: CLI arg values not validated in test_resume_loop.sh

**File:** `scripts/test_resume_loop.sh:45-48`
**Issue:** `--cycles/--sleep/--wake/--log` consume `$2` blindly; a trailing flag
aborts with an unbound-variable error under `set -u`, and a non-numeric `--cycles`
silently yields 0 cycles and exit 0.
**Fix:** Guard `$2` presence and validate numerics, printing usage + exit 2.

## Clean Classes

- Security: no eval, no unquoted `--kernel-src` expansion, dry-run precedes apply, writes only under `-d "$kernel_src"` — clean.
- Correctness (C module): dead branch removed, banner/DMI intact, `power_cycle_delay_ms`/`last_suspend_time` still referenced so no compiler warning — clean.
- Correctness (dkms.conf / grub cfg): ERE regexes valid, supported 5.15-5.99/6.x accepted, `video=efifb:nobgrt` kept with both `panel_orientation` tokens — clean.
- Integration: installer.suite delegation, `bash -n` loop wiring, deleted service refs in scripts/packaging/audit — clean.

---

_Reviewed: 2026-10-08_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
