# Phase 36: Desktop Session Wiring - Research

**Researched:** 2026-10-08
**Mode:** inline (slim pipeline) - targeted reads of the four artifacts + manifest machinery

## Findings (evidence)

### R1 - Tray desktop entry points at a nonexistent binary (M3)
`patches/hardware_controls/etc/xdg/autostart/d330-tray.desktop:Exec=/usr/local/bin/d330-tray.py`.
Installer deploys `tools/d330-tray.py` -> `/usr/local/bin/d330-tray` (no `.py`): `scripts/install_dkms.sh:490-492`; manifest line 134 `/usr/local/bin/d330-tray exec`. So autostart `Exec` targets a path that is never created -> tray never starts.

### R2 - tray.py is NOT GTK (M3/N7 honesty)
`tools/d330-tray.py` imports only `sys`, `os`, `subprocess`; headless guard; `--status`; one `notify-send` when a display exists. No GTK, no StatusNotifier, no menu. `CHANGES_AUDIT.md:364-371,444,464` claim "Python GTK3 status icon", "StatusNotifier/XEmbed", "~15MB RAM", and test harness "tests Python GTK3 bindings" - all false. Honest disposition: notification/status helper; downgrade the docs.

### R3 - tray.py cwd-relative fallbacks (N7)
`run_cmd("python3 tools/d330-ctl battery status ... || d330-ctl ...")`, `pkexec tools/d330-ctl ...`, `tools/d330-refresh-screen.sh ...` - the `tools/...` branch only works from the repo root, never from a session whose cwd is `~`/`/`. Installed names are `d330-ctl`, `d330-refresh-screen`. Resolve against installed names only.

### R4 - tablet daemon runs as a context-less root system unit (M6)
`patches/dock/etc/systemd/system/d330-tablet-daemon.service` is a **system** unit (`Type=simple`, `WantedBy=graphical.target`, `Nice=-5`) with no `User=`, no `DISPLAY`, no `DBUS_SESSION_BUS_ADDRESS`. Under systemd the service runs as root with an empty session env, so every `gsettings`, `xinput`, `xrandr`, `qdbus`, `onboard` call in `tools/d330-tablet-daemon.py` silently no-ops (they are wrapped `|| true`, and `run_command` swallows errors). The daemon therefore reports success while doing nothing in the user's session. Fix: systemd **user** unit at `/usr/lib/systemd/user/`, `WantedBy=default.target`, inheriting the session env; enable globally with `systemctl --global enable`.

### R5 - dead code + swallowed failures in the daemon (M6)
`tools/d330-tablet-daemon.py:101-102`: `for sw_file in glob.glob(...): pass` (dead loop, no effect). `run_command` (`:45-49`) returns `False,""` on any failure and callers ignore it, so `set_laptop_mode`/`set_tablet_mode` log "settings applied successfully" (`:134`,`:162`) unconditionally even when the desktop is unreachable.

### R6 - manifest machinery to extend
`scripts/install_dkms.sh` `deploy_manifest` uses kinds `exec|file-optional|exec-optional|dir-optional|grub-snippet|grub-snippet-optional` + a runtime section `unit-enabled` (`:150-158`, 9 units). `do_verify` optional set at `:1035`; `--removed` handling `:925-932`. Registering the user unit needs: manifest kind `unit-user-enabled`, a `do_verify` runtime check for it, install copy to `/usr/lib/systemd/user/` + `systemctl --global enable`, uninstall disable + `rm`, and an enable-parity assertion in the suite (Phase-35 pattern).

## Recommended approach
1. Fix the Exec path; make tray command fallbacks absolute installed names; downgrade docs to notification-helper truth (no new GUI deps).
2. Convert the daemon to a user unit + `systemctl --global enable`; extend the manifest/verify/uninstall/suite for the new kind.
3. Remove the dead loop; make `run_command` failures visible so the success log is truthful.
4. Strengthen `scripts/test_tray_applet.sh` so a wrong binary/Exec name fails (SC1) and assert the user-unit shape statically.
5. deb postinst + rpm %post `systemctl --global enable` parity.
