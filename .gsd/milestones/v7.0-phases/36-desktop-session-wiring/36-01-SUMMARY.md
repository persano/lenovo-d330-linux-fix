---
phase: 36
plan: 01
subsystem: desktop-session-wiring
tags: [tray, tablet-daemon, systemd-user-unit, installer, sc1]
requires: []
provides:
  - "systemd user unit for the tablet daemon (WantedBy=default.target)"
  - "SC1 tray-wiring regression harness"
  - "installer manifest kind unit-user / unit-user-enabled + verify support"
affects: [42-changes-audit-doc-parity, packaging]
tech-stack:
  added: []
  patterns:
    - "systemctl --global enable for a global systemd user unit"
    - "deploy_manifest kind unit-user / runtime kind unit-user-enabled"
key-files:
  created:
    - patches/dock/usr/lib/systemd/user/d330-tablet-daemon.service
  modified:
    - patches/hardware_controls/etc/xdg/autostart/d330-tray.desktop
    - tools/d330-tray.py
    - tools/d330-tablet-daemon.py
    - scripts/install_dkms.sh
    - scripts/test_tray_applet.sh
    - scripts/test_installer_symmetry.sh
    - packaging/debian/postinst
    - packaging/rpm/lenovo-d330-fix.spec
    - CHANGES_AUDIT.md
  deleted:
    - patches/dock/etc/systemd/system/d330-tablet-daemon.service
decisions:
  - "Tray docstring/docs downgraded to stdlib notification/status helper; no GTK/AppIndicator dependency added"
  - "Tablet daemon runs as a systemd USER unit enabled via systemctl --global enable (session env inherited)"
  - "Daemon reports success only when the desktop commands return 0; otherwise an honest [WARNING] names the failures"
deferred_commit: true
status: complete
metrics:
  tasks: 6
  commits: 7
  completed: 2026-10-08
---

# Phase 36 Plan 01: Desktop Session Wiring — Tray Applet & Tablet Daemon Summary

Tray autostart `Exec` now resolves to the deployed `/usr/local/bin/d330-tray`; the tray
helper resolves installed command names only and its docs stop claiming GTK; the tablet
daemon is a systemd **user** unit enabled with `systemctl --global enable`, deployed /
verified / uninstalled symmetrically through a new `unit-user` manifest kind; its dead loop
is gone and it no longer logs false success. A hardened `scripts/test_tray_applet.sh`
proves SC1 (wrong Exec name => non-zero) plus user-unit/dead-fallback static checks.

Tasks 1-6 (all `<task type="auto">`) executed. **Task 7 (`checkpoint:human-verify`, live
GNOME dock/undock, hardware) was skipped** — `autonomous: false`, needs a physical D330.

## Task commits

| Task | Commit | Subject |
| :--- | :--- | :--- |
| 1 | `ec76748` | `fix(36): tray autostart Exec + installed-name fallbacks` |
| 2 | `c86877c` | `docs(36): correct tray GTK claims and tablet unit table row` |
| 3 | `cf618ac` | `refactor(36): tablet daemon as systemd user unit, installer/verify parity` |
| 3 | `a1de569` | `refactor(36): drop legacy tablet system unit file` (deletion, see Deviation 2) |
| 4 | `f62b1c7` | `fix(36): tablet daemon honest logging, drop dead loop` |
| 5 | `7e70fa3` | `fix(36): packaging enables tablet daemon as global user unit` |
| 6 | `b89d88f` | `test(36): SC1 hardening + user-unit static checks` |

## What was built

- **Task 1** — `d330-tray.desktop:Exec=/usr/local/bin/d330-tray` (was `…/d330-tray.py`);
  `tools/d330-tray.py` drops every cwd-relative `tools/d330-ctl` / `tools/d330-refresh-screen.sh`
  fallback and uses the installed names `d330-ctl` / `d330-refresh-screen`. `--status` and the
  headless guard untouched.
- **Task 2** — `CHANGES_AUDIT.md` §7.8, the tray artifact-table row, the test-suite line and
  the tablet-unit inventory row now describe a stdlib notification/status helper (no
  GTK/AppIndicator/StatusNotifier). `README.md` advertised no GTK tray, so no change.
- **Task 3** — added `patches/dock/usr/lib/systemd/user/d330-tablet-daemon.service`
  (`After=graphical-session.target`, `WantedBy=default.target`), deleted the system unit;
  `install_dkms.sh`: manifest `/usr/lib/systemd/user/d330-tablet-daemon.service\tunit-user`
  and `d330-tablet-daemon.service\tunit-user-enabled`; `do_install` copies to
  `/usr/lib/systemd/user/` + `systemctl --global enable` with an honest `log_warn` fallback;
  `do_uninstall` does `systemctl --global disable` + `rm` the user unit (and a path-free
  `find` migration cleanup); `do_verify` gained `unit-user` (present=>OK/absent=>DRIFT) and
  `unit-user-enabled` (symlink check under `/etc/systemd/user/default.target.wants/`, SKIP
  for `--root != /` or no systemd).
- **Task 4** — removed the dead `for sw_file …: pass` loop; added `apply_commands()` /
  `report_mode_result()` so `set_laptop_mode` / `set_tablet_mode` log
  `… settings applied successfully.` only when the desktop commands return 0, else
  `[WARNING] … some settings did not apply (no desktop session?); failed: …`.
- **Task 5** — `packaging/debian/postinst` and `packaging/rpm/lenovo-d330-fix.spec` now run
  `systemctl --global enable d330-tablet-daemon.service` (`|| true`); other units' enables
  unchanged.
- **Task 6** — `scripts/test_tray_applet.sh` rewrote its probe into 9 real checks and exits
  non-zero on any failure: derives the installer's deployed binary and asserts it equals the
  desktop `Exec` (SC1), asserts no `tools/d330-` fallback in `tray.py`, the user unit +
  `WantedBy=default.target`, no legacy system unit file, no system-unit path in the installer,
  the presence of `systemctl --global enable d330-tablet-daemon`, and a clean `--status`.
  `--dry-run` retained.

## Verification (observed)

All gates run from the repo root under WSL bash (`bash` resolves to WSL on this host).

- `bash scripts/test_tray_applet.sh` -> `Tray applet checks: passed=9 failed=0` / `RESULT: PASS` (rc 0).
- SC1 mutation check (`sed Exec=/usr/local/bin/d330-tray -> …/d330-tray.py`, rerun) -> harness
  exits non-zero -> `SC1-OK`; desktop file restored (`git checkout --`), `git status` clean for it.
- `bash -n scripts/install_dkms.sh` -> clean (rc 0).
- `bash scripts/test_installer_symmetry.sh` -> `passed=16 failed=0`.
- `bash scripts/test_hibernate_guards.sh` -> `passed=21 failed=0`.
- `bash scripts/test_display_fix_guards.sh` -> `passed=10 failed=0`.
- `bash scripts/test_microsd_guards.sh` -> `passed=26 failed=0`.
- `python3 tools/d330-tablet-daemon.py --status` rc 0; `--dry-run --simulate-dock` rc 0;
  `--dry-run --simulate-undock` rc 0.
- Honest-logging evidence (no session): `--simulate-dock` (no `--dry-run`) logged
  `[WARNING] lenovo-d330-dock: Laptop mode: some settings did not apply (no desktop session?);
  failed: gsettings orientation, xrandr rotate normal, gsettings cinnamon OSK off`.
- `grep -c '/etc/systemd/system/d330-tablet-daemon.service' scripts/install_dkms.sh` -> 0;
  legacy unit file absent; user unit file present.
- `grep global enable d330-tablet-daemon` present in both `packaging/debian/postinst` and the RPM spec.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Extended `scripts/test_installer_symmetry.sh`**
- **Found during:** Task 3.
- **Issue:** The new `unit-user` / `unit-user-enabled` manifest kinds were invisible to the
  suite's `dump_manifest` known-kind filter, so the fixture round-trip (`populate_root`) never
  created the user unit -> `--verify --root` reported a false DRIFT and `verify-clean-passes`
  failed. Moving the installer's tablet enable to `systemctl --global enable` also dropped the
  `enable-parity-9` count from 9 to 8 for `install_dkms.sh` (and later postinst/RPM).
- **Fix:** Added `unit-user|unit-user-enabled` to the known-kind regex and the relevant
  skip/populate lists, and broadened the parity regex to
  `systemctl (--global )?enable …`. Suite still 16/0 (no new case).
- **Files modified:** `scripts/test_installer_symmetry.sh` (not in the plan's Task-3
  `files_modified`; required to keep the plan's own `<verification>` green).
- **Commit:** `cf618ac`.

**2. [Rule 3 - Blocking] Task 3 needed two commits (deletion not stageable via gsd-tools `--files`)**
- **Found during:** Task 3.
- **Issue:** `gsd-tools query commit --files` deliberately skips paths that do not exist
  (gsd-core `commands.cjs` #2014), so the deleted
  `patches/dock/etc/systemd/system/d330-tablet-daemon.service` returned `nothing_to_commit`.
- **Fix:** staged the deletion with `git add` and committed it with a directory-scoped
  gsd-tools commit (`--files patches/dock`, which contained only that deletion).
- **Commit:** `a1de569`.

**3. [Rule 2 - Truthfulness] `CHANGES_AUDIT.md` stale system-unit path**
- **Found during:** final docs pass.
- **Issue:** §3.2 still listed `patches/dock/etc/systemd/system/d330-tablet-daemon.service`.
- **Fix:** repointed to the user-unit path; folded into the final docs commit.
- **Files modified:** `CHANGES_AUDIT.md`. **Commit:** final docs commit.

### Out-of-scope / deferred (not in any task `files_modified`)

- `patches/dock/README.md:7` and `docs/research/DETACHABLE_DOCK_TABLET_MODE.md:40` still
  reference the retired system-unit path. Left untouched per the execution scope; the phase
  `<verification>` bullet "no reference remains in repo" is met for the shipped code
  (`scripts/`, `CHANGES_AUDIT.md`, the unit tree) but not those two research/docs pages.
- `patches/dock/etc/udev/rules.d/85-lenovo-d330-dock.rules:6`
  (`ENV{SYSTEMD_WANTS}="d330-tablet-daemon.service"`) now names a **user** unit from the
  system udev manager, so that wants-trigger is effectively dead; the always-running user unit
  plus the rule's `RUN+="… --simulate-dock"` remain. Pre-existing and outside this phase's
  scope (udev not in `files_modified`); flagged for Task 7 / a follow-up.

## Deferred Commits

Code changes in this project are committed task-by-task as above (not deferred to ship); the
plan-level docs/bookkeeping commit is the final `docs(36)…` commit containing this SUMMARY.
All task commits are Conventional-Commits style and atomic per logical change.

## Deferred Work

**Task 7 — Live GNOME dock/undock (SC2, hardware, `checkpoint:human-verify gate="blocking"`).**
Not attempted: requires a physical Lenovo D330 with a graphical GNOME session
(`sudo ./scripts/install_dkms.sh --build --install`, reboot). Verify there:
`systemctl --user is-enabled d330-tablet-daemon.service` -> `enabled` and `status` -> active;
detaching the dock auto-rotates + raises the OSK, re-attaching restores landscape + hides it;
the autostart tray helper starts with no `Exec` error; and `set_laptop_mode`/`set_tablet_mode`
journal lines must NOT claim success when the desktop calls failed.

## Self-Check

- Files: `patches/dock/usr/lib/systemd/user/d330-tablet-daemon.service` present; legacy
  system unit absent; `scripts/test_tray_applet.sh` hardened.
- Commits: `ec76748`, `c86877c`, `cf618ac`, `a1de569`, `f62b1c7`, `7e70fa3`, `b89d88f` all in `git log`.
