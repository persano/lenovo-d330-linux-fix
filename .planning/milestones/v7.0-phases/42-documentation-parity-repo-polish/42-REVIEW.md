---
phase: 42-documentation-parity-repo-polish
reviewed: 2026-10-08T00:00:00Z
depth: deep
files_reviewed: 20
files_reviewed_list:
  - CHANGES_AUDIT.md
  - README.md
  - docs/DISTRO_INSTALL_GUIDE.md
  - packaging/arch/PKGBUILD
  - packaging/debian/control
  - packaging/debian/rules
  - packaging/rpm/lenovo-d330-fix.spec
  - patches/acpi_override/README.md
  - patches/cellular_storage/README.md
  - patches/cellular_storage/etc/ModemManager/fcc-unlock.d/8086
  - patches/hardware_controls/etc/xdg/autostart/d330-tray.desktop
  - scripts/install_dkms.sh
  - scripts/test_doc_parity.sh
  - scripts/test_storage_cellular.sh
  - tools/d330-ctl
  - tools/d330-tablet-daemon.py
  - scripts/*.sh (mode-only sweep, 50 files)
  - tools/*.sh (mode-only sweep)
findings:
  critical: 0
  warning: 8
  info: 3
  total: 11
status: issues_found
---

# Phase 42: Code Review Report

**Reviewed:** 2026-10-08
**Depth:** deep
**Files Reviewed:** 20 (plus the 50-file mode-only sweep)
**Status:** issues_found

## Summary

Phase 42 is mostly correct where it acts. The exec-bit sweep is real: all 50
`scripts/*.sh` + `tools/*.sh` entries are `100755` in the index/HEAD, the FCC
source hook is a genuine 3491-byte CC0 script tracked `100755`, and no 0-byte
tracked blobs remain. The installer's deploy/verify/uninstall triad is consistent
on `/etc/ModemManager/fcc-unlock.d/8086:7360`, the three packagers no longer
swallow a missing source with `|| true` (remaining `|| true` are runtime
systemctl/udevadm actions), and every re-checked CHANGES_AUDIT correction matches
the code (swappiness=180, mq-deadline, enable_fbc=0, panel_orientation, C default
`power_cycle_delay_ms=600`, earlyoom prefer/avoid, 36 test guards, d330-ctl
subcommands, zram-size). The run under WSL bash: doc-parity 17/0, installer
symmetry 17/0.

The defects are parity/robustness gaps: two declared optional dependency names do
not exist in any distro, the packagers ship the "development-only" tools the audit
says are not installed, two docs still tell maintainers to use the colon filename
that would silently break the FCC install, the new parity guard protects a
different file than the audit claim it names, and the extensionless installed
tools were skipped by the exec-bit sweep and ship 0644 in deb/rpm.

## Critical Issues

None.

## Warnings

### WR-01: Declared optional dependency `librnnoise-ladspa` / `rnnoise-ladspa` does not exist

**File:** `packaging/debian/control:12`, `packaging/rpm/lenovo-d330-fix.spec:19`, `packaging/arch/PKGBUILD:15`
**Issue:** All three packagers declare the RNNoise LADSPA plugin as an optional
dependency, but the package name is fabricated. Debian/Ubuntu (all suites,
all sections) ship only `librnnoise-dev`/`librnnoise0`, and neither provides
`librnnoise_ladspa.so`. Arch `extra/rnnoise` ships only `librnnoise.so*` (no
LADSPA plugin), and `rnnoise-ladspa` is not in extra or AUR. A nonexistent
`Recommends`/`Suggests`/`optdepends` yields lintian errors and an apt
"not installable" notice; on Arch the optdepend can never be satisfied.
**Fix:** Drop the fake name and document the real situation (the plugin is not
distro-packaged; build/install it manually), e.g. remove
`librnnoise-ladspa`/`rnnoise-ladspa` from the three lists, or replace with the
real library package plus a README note that the LADSPA `.so` must be supplied
by the user (matching the filter-chain `nofail`).

### WR-02: Packagers install the "Development-only tools (not installed)"

**File:** `packaging/debian/rules:8`, `packaging/rpm/lenovo-d330-fix.spec:41`, `packaging/arch/PKGBUILD:23`, `CHANGES_AUDIT.md:452`
**Issue:** The audit added in this phase states `tools/d330-acpi-override.sh` and
`tools/d330-pen-config.sh` are "Development-only tools (not installed)". All
three packagers copy/install the whole `tools/d330-*` glob, so those two helpers
are deployed to `/usr/local/bin` by every distro package. The doc claim and the
packages contradict each other.
**Fix:** Either exclude the two dev helpers from each packager's glob (and keep
the audit text), or reword the audit to say "not installed by `install_dkms.sh`"
and accept that packages ship them.

### WR-03: Stale `8086:7360` source path in `patches/cellular_storage/README.md`

**File:** `patches/cellular_storage/README.md:6`
**Issue:** The file hierarchy still lists the tracked path as
`etc/ModemManager/fcc-unlock.d/8086:7360`. That file does not exist in the repo;
the tracked hook is `.../8086`. This is the exact drift the phase set out to
reconcile, and `patches/acpi_override/README.md` was updated while this one was
missed.
**Fix:** Change the entry to `etc/ModemManager/fcc-unlock.d/8086` and note it is
installed as `8086:7360` (same wording as `CHANGES_AUDIT.md:217`).

### WR-04: Hook header tells maintainers to rename the file, which silently disables the install

**File:** `patches/cellular_storage/etc/ModemManager/fcc-unlock.d/8086:5`, `scripts/install_dkms.sh:404`
**Issue:** The hook header still says "On a POSIX checkout rename to `8086:7360`
(see ROADMAP N2)". If followed, `install_dkms.sh`'s
`[ -f ".../fcc-unlock.d/8086" ]` no longer matches and the whole block is
skipped with no `else`/warning, so the FCC unlock hook is silently never
deployed. The new install code and the old comment encode opposite rules.
**Fix:** Delete/replace the header note (state that the source stays `8086` and
the installer copies it to the colon name), and add an `else log_warn` on the
`do_install` block so a missing source fails visibly.

### WR-05: Doc-parity guard checks `enable_fbc=0` in a different file than the audit claim

**File:** `scripts/test_doc_parity.sh:106` (audit claim at `CHANGES_AUDIT.md:34,37`)
**Issue:** `CHANGES_AUDIT.md` §2.1 attributes `enable_fbc=0` to
`patches/dkms/etc/modprobe.d/lenovo-d330-i915.conf`, but check 3 greps only
`patches/boot_orientation/etc/default/grub.d/50-lenovo-d330-boot.cfg` and the
audit string. If the modprobe conf drifts back to `enable_fbc=1`, the guard stays
green while the audit claim is false, defeating the guard's purpose.
**Fix:** Add the modprobe conf to a `MODPROBE_I915` variable and assert
`i915.enable_fbc=0`/`i915.enable_psr=0` there too (check 3).

### WR-06: Guard does not verify the headline FCC install target

**File:** `scripts/test_doc_parity.sh` (checks 1-12; no FCC assertion)
**Issue:** The phase's headline fix (installer copies `8086` to
`/etc/ModemManager/fcc-unlock.d/8086:7360`, per `CHANGES_AUDIT.md:217,426`) is
not checked by the parity guard. A regression back to copying to `8086`, or a
mismatch between the manifest and the `cp` target, passes 17/0. This is the
largest non-vacuity hole in an otherwise useful guard.
**Fix:** Add a check that `scripts/install_dkms.sh` contains the
`fcc-unlock.d/8086` source and the `/etc/ModemManager/fcc-unlock.d/8086:7360`
deploy/remove target, and that the manifest lists the colon path.

### WR-07: Extensionless/Python installed tools remain 0644 and ship non-executable in deb/rpm

**File:** `tools/d330-ctl` (tracked 100644), `tools/d330-tray.py`, `tools/d330-tablet-daemon.py`, `tools/d330-auto-hibernate.py`, `tools/d330-backlight-pwm.py`, `tools/d330-sensor-filter.py`
**Issue:** The exec-bit sweep covered only `*.sh`, but `tools/d330-ctl` is a
shebang script installed as the `/usr/local/bin/d330-ctl` CLI. `install_dkms.sh`
chmods it, so source installs work, but `packaging/debian/rules:8` and
`packaging/rpm/...:41` `cp` preserve 0644 and only chmod
`d330-auto-hibernate`; `dh_fixperms` does not normalize `/usr/local/bin` (only
`usr/bin`/`usr/sbin`/bin/sbin), so the packages ship `/usr/local/bin/d330-ctl`
(and the other Python tools) non-executable. Note the two dev-only helpers the
packagers do not need are now 0755 while the tools they do run are 0644.
**Fix:** Track the installed executables (`tools/d330-ctl` at minimum) as
`100755`, or add explicit `chmod 755` for each installed tool in
`debian/rules`/`%install` (and rename `d330-tray.py`/`d330-tablet-daemon.py` to
their ExecStart/desktop names).

### WR-08: Guard's 0-byte check reads the worktree, not the index

**File:** `scripts/test_doc_parity.sh:194-199`
**Issue:** The loop skips any tracked path absent from the worktree
(`[ -e "$f" ] || continue`). A 0-byte tracked blob that has been deleted or not
checked out (e.g. `AUDIT_PROMPT.md` is currently deleted in the worktree) passes
the check, so "no 0-byte tracked files" is not actually proven.
**Fix:** Iterate the index and sizes, e.g.
`git ls-files -s | while read -r mode hash stage path; do [ "$(git cat-file -s "$hash")" -eq 0 ] && ...; done`.

## Info

### IN-01: Guard's GTK/AppIndicator check only greps the literal `GTK3`

**File:** `scripts/test_doc_parity.sh:153`
**Issue:** The `--probe`/header text promises "no GTK3 / AppIndicator tray
claim", but the audit side only greps `GTK3`. An audit claim of "uses
AppIndicator" or "GTK" (without the `3`) passes. The code-side `gi`/`Gtk` regex is
adequate.
**Fix:** Add `grep -qi 'appindicator'` (and optionally `GTK`) to the audit side
of check 7.

### IN-02: Guard counts `ls` output for the test-script tally

**File:** `scripts/test_doc_parity.sh:166` (`ls scripts/test_*.sh | wc -l`)
**Issue:** Parsing `ls` output is fragile (filenames with newlines, no-match
behavior under `pipefail`). Not currently exploitable, but there is no reason to
shell out when the path list is already available via `git ls-files`.
**Fix:** `test_count="$(git ls-files 'scripts/test_*.sh' | wc -l)"`.

### IN-03: `chmod +x` on the FCC target is redundant but harmless

**File:** `scripts/install_dkms.sh:406`
**Issue:** The source hook is tracked `100755`, so `cp` already preserves the
exec bit; the explicit `chmod +x` is defensive only. No change required; noted
for completeness since the audit's permission claim (`0755`) is met either way.

---

_Reviewed: 2026-10-08_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: deep_
