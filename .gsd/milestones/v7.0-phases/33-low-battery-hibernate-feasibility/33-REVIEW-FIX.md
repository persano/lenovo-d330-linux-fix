---
phase: 33
fixed_at: 2026-10-08T09:17:19-03:00
review_path: inline findings (delivered by the /gsd-code-review orchestrator; no 33-REVIEW.md file exists in the repo)
iteration: 1
findings_in_scope: 9
fixed: 9
skipped: 0
status: all_fixed
---

# Phase 33: Code Review Fix Report

**Fixed at:** 2026-10-08T09:17:19-03:00
**Source review:** inline findings from /gsd-code-review (CR-01, WR-01..WR-03, IN-01..IN-05)
**Iteration:** 1

**Summary:**
- Findings in scope: 9
- Fixed: 9
- Skipped: 0

All work happened in the isolated worktree `.claude/worktrees/rf-33-11660-1791459654`
on branch `gsd-reviewfix/33-11660-1791459654`, one atomic commit per finding.

## Fixed Issues

### CR-01: Packages enable the service but ship the daemon with a .py suffix

**Files modified:** `packaging/rpm/lenovo-d330-fix.spec`, `packaging/debian/rules`, `scripts/test_hibernate_guards.sh`
**Commit:** 9f6b2b3
**Applied fix:** `%install` and `override_dh_auto_install` now `mv` the copied `d330-auto-hibernate.py` to the suffix-free `d330-auto-hibernate` and `chmod 755` it, matching `ExecStart=/usr/local/bin/d330-auto-hibernate`. `case_execstart_matches_install_path` asserts all four lines (new `DEBIAN_RULES` variable, whole-line `-Fx` greps).
**Verification:** tier 1 re-read + tier 2 (`bash -n`, guard suite 21/0).

### WR-01: systemd eats the swapfile unit WARN numbers

**Files modified:** `patches/power_hibernate/etc/systemd/system/d330-swapfile.service`, `scripts/test_hibernate_guards.sh`
**Commit:** d09fcd4
**Applied fix:** `${NEED}`/`${AVAIL}` in ExecStart became `$${NEED}`/`$${AVAIL}`, so systemd passes `${NEED}`/`${AVAIL}` to `/bin/sh`. Checked against systemd source (`replace_env_argv` runs with `flags=0`, so only `${...}` and `$$` are processed; bare `$SIZE_MB` and `$((...))` pass through untouched). `case_swapfile_unit_static` did not grep the old form; two assertions for the doubled forms were added.
**Verification:** tier 1 re-read + tier 2 (guard suite 21/0).

### WR-02: grub.cfg verification only greps for the resume_offset= presence

**Files modified:** `scripts/install_dkms.sh`
**Commit:** d7ea9f5
**Applied fix:** the verification now requires `grep -qF "resume=UUID=${ROOT_UUID}"` AND `grep -qF "resume_offset=${RESUME_OFFSET}"` in `$GRUB_CFG`, so a stale config with an old UUID or offset fails into the locked manual-step branch. The failure warning prints the expected rendered values.
**Verification:** tier 1 re-read + tier 2 (`bash -n`, guard suite 21/0). Status: **fixed: requires human verification** (condition change, not executable by the gates; confirm on a real install).

### WR-03: fstab append can glue onto a file with no trailing newline

**Files modified:** `scripts/install_dkms.sh`
**Commit:** 6727457
**Applied fix:** before `echo "$FSTAB_SWAP_LINE" >> /etc/fstab`, a guard adds a newline only when the file is non-empty and its last byte is not a newline (`[ -s /etc/fstab ] && [ -n "$(tail -c1 /etc/fstab)" ]` inside an `if`, safe under `set -e`).
**Verification:** tier 1 re-read + tier 2 (`bash -n`) + behavioral harness: no-newline case, newline case, empty case all correct.

### IN-01: uninstall fstab removal is unanchored and drops the file when all lines match

**Files modified:** `scripts/install_dkms.sh`, `scripts/test_hibernate_guards.sh`
**Commit:** 23d858d
**Applied fix:** guard changed to `grep -qxF`, removal changed to `grep -v -xF` (kept as `grep -v -xF` so the existing `case_uninstall_symmetry` regex still matches). `grep -v` rc is captured: rc 0 or 1 (all lines removed, valid empty fstab) installs the temp file, rc >= 2 leaves the original untouched. Two assertions added to `case_uninstall_symmetry`.
**Verification:** tier 1 re-read + tier 2 (`bash -n`, guard suite 21/0) + behavioral harness: exact-middle removal, comment kept, all-lines-removed, no-trailing-newline, no-match untouched, all pass.

### IN-02: unguarded int() on battery capacity

**Files modified:** `tools/d330-auto-hibernate.py`
**Commit:** 8d33293
**Applied fix:** the `int()` read is wrapped in `try/except ValueError` setting `cap = None`, which flows into the existing `[INFO] No battery power supply detected` path.
**Verification:** tier 1 re-read + tier 2 (`py_compile`) + behavioral run with a garbage capacity fixture: rc 0, no traceback, INFO path taken.

### IN-03: fs-block-vs-page guard passes when both commands fail (0=0)

**Files modified:** `scripts/install_dkms.sh`, `scripts/test_hibernate_guards.sh`
**Commit:** bc5e57a
**Applied fix:** both values must match `^[1-9][0-9]*$` before equality can set `OFFSET_UNITS_OK=true`; zero or non-numeric values fail closed into the manual-step branch. The warning text now says "invalid or unequal". One assertion added to `case_installer_activation_step`.
**Verification:** tier 1 re-read + tier 2 (`bash -n`, guard suite 21/0) + condition harness: 0/0 false, 4096/4096 true, 4096/512 false, abc/abc false, empty false, 0/4096 false.

### IN-04: no rc-propagation coverage for run_power_action (audit N5)

**Files modified:** `tools/d330-auto-hibernate.py`, `scripts/test_hibernate_guards.sh`
**Commit:** 3af09df
**Applied fix:** new env seam `D330_SYSTEMCTL` (default `systemctl`) used as the binary in `subprocess.run([D330_SYSTEMCTL, verb])` (list form kept). New case `rc-propagates` runs the daemon without `--dry-run` against a stub that records the verb and exits 7, then asserts non-zero daemon rc, the `[ERROR] systemctl hibernate failed (rc=7)` line, no traceback, and verb `hibernate`. Header and usage counts updated 20 -> 21.
**Verification:** tier 1 re-read + tier 2 (`py_compile`, `bash -n`, guard suite 21/0 including the new case).

### IN-05: uninstall removes the resume snippet but never re-runs mkconfig

**Files modified:** `scripts/install_dkms.sh`
**Commit:** 6620482
**Applied fix:** presence of `/etc/default/grub.d/53-lenovo-d330-resume.cfg` is captured before its removal; when it was present, the refresh block re-runs the same detection ladder as install (`update-grub` -> `grub2-mkconfig -o /boot/grub2/grub.cfg` -> `grub-mkconfig -o /boot/grub/grub.cfg`), each guarded with `|| true` and honest log lines, plus a `[WARN]` when no tool exists. Duplicated instead of extracted because the install ladder is wired into the fail-closed manual-step exit; the addition is 19 lines, under the 30-line skip threshold, so the finding was not skipped.
**Verification:** tier 1 re-read + tier 2 (`bash -n`, guard suite 21/0). Status: **fixed: requires human verification** (uninstall flow is not executed by the gates; confirm on a real uninstall).

## Skipped Issues

None.

## Gate results

Gates ran **inside the isolated worktree** (the same tree the fixes were committed
from), so the numbers are reproducible from `gsd-reviewfix/33-11660-1791459654`
before teardown. Raw tail:

```
=== 1. hibernate guard suite ===
  [OK] zram-only-refuse
  ... (21 cases) ...
  [OK] rc-propagates

==========================================================
 Guard suite summary: passed=21 failed=0
==========================================================
GATE_RC_HIBERNATE=0
=== 2. storage/cellular dry-run ===
 Guard suite summary: passed=26 failed=0
[OK] dry-run verification complete
GATE_RC_STORAGE=0
=== 3. py_compile daemon ===
GATE_RC_PYCOMPILE=0
=== 4. bash -n syntax (per file) ===
GATE_RC_BASHN_INSTALLER=0
GATE_RC_BASHN_HIBERNATE=0
GATE_RC_BASHN_STORAGE=0
=== 5. ExecStart grep consistency ===
12:ExecStart=/usr/local/bin/d330-auto-hibernate
GATE_RC_EXECSTART=0
244:            cp "${REPO_ROOT}/tools/d330-auto-hibernate.py" /usr/local/bin/d330-auto-hibernate && \
GATE_RC_INSTALLCOPY=0
35:mv %{buildroot}/usr/local/bin/d330-auto-hibernate.py %{buildroot}/usr/local/bin/d330-auto-hibernate
GATE_RC_SPECMV=0
36:chmod 755 %{buildroot}/usr/local/bin/d330-auto-hibernate
GATE_RC_SPECCHMOD=0
11:	mv debian/lenovo-d330-fix/usr/local/bin/d330-auto-hibernate.py debian/lenovo-d330-fix/usr/local/bin/d330-auto-hibernate
GATE_RC_RULESMV=0
12:	chmod 755 debian/lenovo-d330-fix/usr/local/bin/d330-auto-hibernate
GATE_RC_RULESCHMOD=0
=== GATE DONE ===
```

All gate return codes are 0; `failed=0` holds for both suites.

## Notes for the reviewer

- Commit messages follow `fix(33): {ID} {description}`. The WR-01 subject line
  got shell-mangled by pwsh quoting (git shows it as `escape \\$\/\$\\`) but the
  commit content and prefix are correct; it was left unamended on purpose.
- `scripts/build_live_iso.sh` still copies `tools/d330-*` without the
  suffix-free rename (same class as CR-01, outside the finding's file list).
  Recorded here so phase 35 packaging work can pick it up.

---

_Fixed: 2026-10-08T09:17:19-03:00_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_
