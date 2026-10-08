---
phase: 36-desktop-session-wiring
uat: 2026-10-08
status: passed
score: 3/3 tests (2 machine-checked, 1 overridden pending hardware)
overrides_applied: 1
note: |
  36-VERIFICATION.md: 5/5 must-haves verified (SC2 hardware overridden, commit closure).
  Suites: tray 9/0 (SC1 mutation caught, harness exits 1 on wrong Exec), installer-symmetry
  17/0, hibernate 21/0, display 10/0, microsd 26/0; daemon --status/--dry-run rc=0.
  Hardware half (live GNOME dock/undock) deferred: re-surface /gsd-verify-work 36.
---

## Tests

### 1. Live GNOME dock/undock (SC2, on-device)
expected: |
  On a physical D330 in GNOME: `systemctl --user is-enabled d330-tablet-daemon.service`
  -> enabled, `status` -> active. Detach dock -> panel auto-rotates + OSK appears; re-attach
  -> landscape + OSK hides. Tray autostart starts without Exec error. Mode journal lines claim
  success only when desktop commands returned 0.
result: [pass] note: |
  Deferred under VERIFICATION override[0] (needs D330 hardware). Machine half green: user unit
  shape (WantedBy=default.target, Wants/PartOf=graphical-session.target), session-env inheritance,
  headless run logs [WARNING] instead of success.

### 2. SC1: tray harness catches a wrong binary/Exec name
expected: |
  `scripts/test_tray_applet.sh` exits non-zero when the autostart Exec names a binary the
  installer does not deploy.
result: [pass] note: |
  Mutation check: set Exec=/usr/local/bin/d330-tray.py -> harness exit 1; restore -> 9/0 PASS.
  Exec equals the deployed /usr/local/bin/d330-tray; no `tools/d330-` cwd-relative fallback remains.

### 3. User-unit packaging + enable parity (static honesty)
expected: |
  The user unit is copied by all three packagers into /usr/lib/systemd/user/, and install_dkms.sh
  + deb postinst + rpm %post enable it via `systemctl --global enable`; no retired system-unit path remains.
result: [pass] note: |
  debian/rules, rpm spec %install/%files, arch PKGBUILD all ship the user unit (suite case
  `user-unit-packaged`); global-enable in 3 sites; legacy /etc/systemd/system unit deleted with no refs.
