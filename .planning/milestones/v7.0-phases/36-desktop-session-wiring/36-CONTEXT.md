# Phase 36: Desktop Session Wiring — Tray Applet & Tablet Daemon - Context

**Gathered:** 2026-10-08
**Status:** Ready for planning (auto-accepted gray areas; slim pipeline)

<domain>
## Phase Boundary

Audit M3/M6/N7: both user-facing helpers must run in the user's graphical session, not as a context-less root system service, and their advertised capabilities must match reality. Scope: `patches/hardware_controls/etc/xdg/autostart/d330-tray.desktop`, `tools/d330-tray.py`, `patches/dock/etc/systemd/system/d330-tablet-daemon.service` (→ user unit), `tools/d330-tablet-daemon.py`, `scripts/install_dkms.sh`, `scripts/test_tray_applet.sh`, `packaging/*`, `CHANGES_AUDIT.md`, `README.md`. No scope beyond session wiring/truth.

</domain>

<decisions>
## Implementation Decisions

### Tray desktop entry + script (M3/N7)
- Fix `d330-tray.desktop:Exec` from `/usr/local/bin/d330-tray.py` to `/usr/local/bin/d330-tray` (the installer deploys `tools/d330-tray.py` → `/usr/local/bin/d330-tray`, no `.py`)
- `tools/d330-tray.py` contains NO GTK despite `CHANGES_AUDIT §7.8` claiming GTK3/StatusNotifier — **honesty fix (recommended): downgrade §7.8 and README to "notification helper / CLI status"**, keep the notify-send behavior, and make all internal command fallbacks resolve to installed `/usr/local/bin` names only (drop cwd-relative `tools/d330-ctl`, `tools/d330-refresh-screen.sh`)
- Do NOT add a GTK/AppIndicator dependency in this phase (deferred; needs GUI test infra)

### Tablet daemon → user session unit (M6)
- Convert `patches/dock/.../d330-tablet-daemon.service` to a **systemd user unit** installed at `/usr/lib/systemd/user/d330-tablet-daemon.service` with `WantedBy=default.target`, `After=graphical-session.target`; no `User=`/`Environment=DISPLAY=:0` hardcoding (user units inherit the session env, fixing every silent `gsettings`/`xinput`/`xrandr`/`qdbus` failure)
- Installer: deploy to that path, then `systemctl --global enable d330-tablet-daemon.service` (honest `[WARN]` if systemd-user unavailable); uninstall disables + removes. Manifest gains a `unit-user`/`unit-user-enabled` kind; `--verify` handles it (SKIP when no systemd)
- deb postinst + rpm %post: `systemctl --global enable d330-tablet-daemon.service` in place of the system enable

### Daemon correctness (M6)
- `tools/d330-tablet-daemon.py:101-102` dead loop (`for sw_file in ...: pass`) removed
- `run_command` (`:45-49`) must propagate failure so `:134`/`:162` do not log "settings applied successfully" unconditionally — log failures honestly

### Tests (SC1)
- Strengthen `scripts/test_tray_applet.sh` so it FAILS when the binary/Exec name is wrong (SC1), and add static cases: desktop Exec == installed name, no cwd-relative command fallbacks, daemon unit is a user unit with session target, CHANGES_AUDIT tray claims match the non-GTK reality

### the agent's Discretion
- Exact user-unit filename/location (`/usr/lib/systemd/user` vs `/etc/systemd/user`), WARN wording, whether notify-send remains the tray action

</decisions>

<code_context>
## Existing Code Insights

- `tray.desktop:Exec=/usr/local/bin/d330-tray.py` (wrong; installer → `/usr/local/bin/d330-tray` at `scripts/install_dkms.sh:490-492`)
- `tools/d330-tray.py` — stdlib only (`os`, `subprocess`); CLI `--status`; headless guard; `notify-send`; cwd-relative `tools/d330-ctl` / `tools/d330-refresh-screen.sh` fallbacks
- `d330-tablet-daemon.service` — system unit, `Type=simple`, no User/env, `WantedBy=graphical.target`; installer deploys to `/etc/systemd/system` (`:500-501`), enables (`:524`), uninstalls (`:850`, `:878`)
- `tools/d330-tablet-daemon.py` — dead loop `:101-102`, `run_command` swallows errors `:45-49`, false success logs `:134`/`:162`
- `scripts/test_tray_applet.sh` exists (desktop-file-validate oriented per CHANGES_AUDIT:464)
- Phase-35 manifest/`--verify` machinery is the place to register the new user-unit kind; enable parity across 3 sites is asserted by suite `enable-parity-9`
- CHANGES_AUDIT `:364-371,:444,:464` claim GTK3 for tray.py (false)

</code_context>

<canonical_refs>
## Canonical Refs

- `.planning/ROADMAP.md` — `### Phase 36:` (goal, SC1 test_tray_applet.sh fails on wrong binary name, SC2 live GNOME dock/undock, Audit Ref M3/M6/N7, component list)
- `patches/hardware_controls/etc/xdg/autostart/d330-tray.desktop`, `tools/d330-tray.py`
- `patches/dock/etc/systemd/system/d330-tablet-daemon.service`, `tools/d330-tablet-daemon.py`
- `scripts/install_dkms.sh`, `scripts/test_tray_applet.sh`
- `packaging/debian/postinst`, `packaging/rpm/lenovo-d330-fix.spec`
- `CHANGES_AUDIT.md` §7.8, `README.md`
- `.planning/phases/35-installer-uninstaller-symmetry/35-01-PLAN.md` — manifest/`--verify` machinery to extend

</canonical_refs>

<deferred>
## Deferred Ideas

- Real GTK3/AppIndicator StatusNotifier tray implementation (needs GUI test infra + deps)
- Per-user (non-global) unit enabling, polkit policy for tray pkexec actions
- Full CHANGES_AUDIT doc-parity sweep (Phase 42)
</deferred>
