---
phase: 36-desktop-session-wiring
reviewed: 2026-10-08
reviewer: gsd-code-reviewer (diff 761f40e..HEAD + working tree)
status: all findings fixed (see 36-REVIEW-FIX.md)
---

# Phase 36 Code Review

| # | Sev | Location | Finding | Status |
|---|-----|----------|---------|--------|
| 1 | CRITICAL | `packaging/debian/rules:22`, `packaging/rpm/lenovo-d330-fix.spec:40`, `packaging/arch/PKGBUILD:30` | Packagers only copy `etc/systemd/system/*.service`; the new user unit is never installed, so `systemctl --global enable d330-tablet-daemon.service` in postinst/%post finds nothing and packaged installs ship a daemon that never runs. | FIXED 142742b |
| 2 | HIGH | `tools/d330-tablet-daemon.py:150,177` | Cinnamon `gsettings` calls lack `|| true` and that schema is absent on GNOME/KDE, so the "success" branch was unreachable and every transition falsely warned. | FIXED 0181e49 |
| 3 | MEDIUM | `patches/dock/etc/udev/rules.d/85-lenovo-d330-dock.rules:6-7` | System udev manager ignores `SYSTEMD_USER_WANTS`; root `RUN+=` simulate triggers have no session env and always fail. | FIXED 5e1e5f5 |
| 4 | MEDIUM | `patches/dock/usr/lib/systemd/user/d330-tablet-daemon.service:4` | `After=graphical-session.target` without `Wants=`/`PartOf=` does not order before the session env import. | FIXED 045f967 |
| 5 | MEDIUM | `scripts/test_tray_applet.sh:47,105`, `scripts/test_installer_symmetry.sh` | `--dry-run` exited 0 unconditionally; no case asserted packagers ship the user unit -> CRITICAL #1 passed all suites green. | FIXED 1fa6181 (suite 16→17) |
| 6 | MEDIUM | `scripts/install_dkms.sh:867` | do_uninstall `systemctl --global disable` lacked the `command -v systemctl && [ -d /run/systemd/system ]` guard used by install/verify. | FIXED c22ff56 |
| 7 | LOW | `docs/research/DESKTOP_TRAY_APPLET.md:10`, `d330-tray.desktop:Comment`, `tools/d330-tray.py:22,25-33` | False GTK/AppIndicator claim; `Comment` advertised a menu that does not exist; `--status` reported "Disabled" when state unknown; dead misleading success-printing functions. | FIXED e65e43b |

Clean categories reported by the reviewer: installer/`--verify`/uninstall symmetry for `unit-user`/`unit-user-enabled` kinds; shell/Python portability and `set -euo pipefail` handling in the modified files; no leftover shipped references to the retired system-unit path.
