---
phase: 36
fixed_at: 2026-10-08T16:30:00Z
review_path: (inline findings from /gsd-code-review --fix prompt; no 36-REVIEW.md artifact present)
iteration: 1
findings_in_scope: 7
fixed: 7
skipped: 0
status: all_fixed
---

# Phase 36: Code Review Fix Report

**Fixed at:** 2026-10-08
**Source review:** inline findings provided to the fixer (no `36-REVIEW.md` existed)
**Iteration:** 1

**Summary:**
- Findings in scope: 7
- Fixed: 7
- Skipped: 0

## Fixed Issues

### CR-01 (CRITICAL): packaged builds did not ship the new systemd user unit

**Files modified:** `packaging/debian/rules`, `packaging/rpm/lenovo-d330-fix.spec`, `packaging/arch/PKGBUILD`
**Commit:** 142742b
**Applied fix:** Each packager now installs `patches/*/usr/lib/systemd/user/*.service`
into its package tree under `/usr/lib/systemd/user/` (deb: `mkdir -p` + `cp` in
`override_dh_auto_install`, auto-collected by `dh`; rpm: added `%install` copy and
`%files` entry; Arch: added `install -d` + `install -m 644` to `package()`). The
existing `systemctl --global enable d330-tablet-daemon.service` in deb postinst /
RPM `%post` now finds the unit. Existing system-unit copies were preserved.

### CR-02 (HIGH): tablet daemon mode "success" branch unreachable / dishonest

**Files modified:** `tools/d330-tablet-daemon.py`
**Commit:** 0181e49
**Applied fix:** `apply_commands()` now takes `(label, command, targets)` triples and
gates each desktop command on the current session tokens (`XDG_CURRENT_DESKTOP` +
`x11`/`wayland`). Commands that do not target the current desktop are skipped instead
of run, so success means "the commands applicable to the current desktop succeeded":
a normal GNOME/KDE/Cinnamon session logs success, and only a genuinely session-less
run (no `DISPLAY`/`WAYLAND_DISPLAY`) warns. `gsettings` cinnamon/GNOME commands are
tagged `cinnamon`/`gnome`, `xrandr` is tagged `x11`, already-guarded qdbus/killall/
onboard commands stay best-effort.

### WR-01 (MEDIUM): dead `SYSTEMD_USER_WANTS` + root `RUN+=` daemon triggers in udev rule

**Files modified:** `patches/dock/etc/udev/rules.d/85-lenovo-d330-dock.rules`
**Commit:** 5e1e5f5
**Applied fix:** Removed the `ENV{SYSTEMD_USER_WANTS}` assignment and both
`RUN+=".../d330-tablet-daemon --simulate-dock"` / `--simulate-undock` triggers (the
system udev manager ignores user-wants and the root `RUN+=` calls have no session
env). Kept the Intel HID switch binding rule and added a comment stating hotplug is
handled by the user unit's 3 s USB polling.

### WR-02 (MEDIUM): user unit not bound to `graphical-session.target`

**Files modified:** `patches/dock/usr/lib/systemd/user/d330-tablet-daemon.service`
**Commit:** 045f967
**Applied fix:** Added `Wants=graphical-session.target` and
`PartOf=graphical-session.target` to `[Unit]`, keeping `After=graphical-session.target`
and `WantedBy=default.target`.

### WR-03 (MEDIUM): vacuous tests

**Files modified:** `scripts/test_tray_applet.sh`, `scripts/test_installer_symmetry.sh`
**Commit:** 1fa6181
**Applied fix:** (a) `test_tray_applet.sh --dry-run` now captures the
`d330-tray.py --status` exit code and exits non-zero on failure instead of `|| true`.
(b) Added `case_user_unit_packaged` to the symmetry suite, asserting
`packaging/debian/rules`, `packaging/rpm/lenovo-d330-fix.spec` and
`packaging/arch/PKGBUILD` each reference `usr/lib/systemd/user`. The suite now runs
17 cases (was 16); still 17 passed / 0 failed.

### WR-04 (MEDIUM): uninstall `systemctl --global disable` missing systemd-user guard

**Files modified:** `scripts/install_dkms.sh`
**Commit:** c22ff56
**Applied fix:** Wrapped the uninstall-side `systemctl --global disable
d330-tablet-daemon.service` in the same
`command -v systemctl && [ -d /run/systemd/system ]` guard used by install/verify, with
an honest `log_warn` in the unavailable branch.

### IN-01 (LOW): tray/doc honesty cleanup

**Files modified:** `tools/d330-tray.py`, `patches/hardware_controls/etc/xdg/autostart/d330-tray.desktop`, `docs/research/DESKTOP_TRAY_APPLET.md`, `CHANGES_AUDIT.md`
**Commit:** e65e43b
**Applied fix:** `get_battery_conservation_state()` is now tri-state
(`enabled`/`disabled`/`unknown`) and `--status` reports "Unknown" when `d330-ctl`
is unavailable/the conservation node is not detected. Deleted the never-called
`toggle_conservation_mode()` and `emergency_refresh()` (no doc/test referenced them)
and refreshed the module docstring/init output. `DESKTOP_TRAY_APPLET.md` no longer
claims GNOME Shell/KDE/XFCE/Cinnamon tray compatibility; it now describes the stdlib
`notify-send` + `--status` helper. The `.desktop` `Comment=` matches the
notification/status helper. `CHANGES_AUDIT.md` §7.8 updated to drop the removed
screen-refresh-trigger claim.

## Verification

All gates executed on the Windows host via the Git-Bash shell (`/usr/bin/python3` 3.12.3).

| Gate | Result |
| :--- | :--- |
| `bash scripts/test_tray_applet.sh` | passed=9 failed=0 (RESULT: PASS) |
| `bash scripts/test_tray_applet.sh --dry-run` | exit 0 (probe failure now propagates) |
| `bash scripts/test_installer_symmetry.sh` | passed=17 failed=0 |
| `bash scripts/test_hibernate_guards.sh` | passed=21 failed=0 |
| `bash scripts/test_display_fix_guards.sh` | passed=10 failed=0 |
| `bash scripts/test_microsd_guards.sh` | passed=26 failed=0 |
| `bash -n scripts/install_dkms.sh` | OK |
| `bash -n scripts/test_tray_applet.sh` | OK |
| `python3 tools/d330-tablet-daemon.py --status` | exit 0 |
| `python3 tools/d330-tablet-daemon.py --dry-run --simulate-dock` | exit 0 |
| `python3 tools/d330-tablet-daemon.py --dry-run --simulate-undock` | exit 0 |

Gate runs were in the main checkout (no isolated worktree was used).

---

_Fixed: 2026-10-08_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_
