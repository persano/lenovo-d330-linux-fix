---
phase: 36-desktop-session-wiring
verified: 2026-10-08T16:33:13Z
status: human_needed
score: 4/5 must-haves verified
behavior_unverified: 1
overrides_applied: 0
re_verification: false
gaps:
  - truth: "SC2: on the D330, dock/undock visibly toggles orientation + OSK in a live GNOME session"
    status: partial
    reason: "Hardware-only success criterion. No physical Lenovo D330 is available to this verifier, so live GNOME dock/undock behaviour cannot be exercised. The supporting wiring (systemd user unit, session-env inheritance, honest success/failure logging) is present and statically/behaviourally verified, but the on-device outcome is unproven."
    artifacts:
      - path: "patches/dock/usr/lib/systemd/user/d330-tablet-daemon.service"
        issue: "Unit correct, but its runtime effect on a live GNOME session is untested."
      - path: "tools/d330-tablet-daemon.py"
        issue: "Rotation/OSK commands verified only in a headless (no-session) path; a real graphical session was never run."
    missing:
      - "On-device proof on a physical Lenovo D330: detaching the dock auto-rotates the panel and raises the OSK; re-attaching restores landscape and hides the OSK; `set_laptop_mode`/`set_tablet_mode` journal lines do NOT claim success when the desktop calls failed."
behavior_unverified_items:
  - truth: "SC2: live GNOME dock/undock toggles orientation + OSK (and mode success is only logged when the desktop commands applied)"
    test: "On a physical D330 in a graphical GNOME session: `systemctl --user is-enabled d330-tablet-daemon.service` (expect enabled) and `systemctl --user status d330-tablet-daemon` (expect active); detach the keyboard dock; re-attach it; then read the journal lines for set_laptop_mode/set_tablet_mode."
    expected: "Detach -> panel auto-rotates and the on-screen keyboard appears; re-attach -> rotation returns to landscape and the OSK disappears; success is logged only when the desktop commands (gsettings/xrandr/…) return 0, otherwise an honest [WARNING]."
    why_human: "Requires physical D330 hardware + a live GNOME session; presence/wiring checks and headless runs cannot exercise the actual rotation/OSK state transition."
human_verification:
  - test: "SC2 live GNOME dock/undock on a physical Lenovo D330"
    expected: "Detach auto-rotates + raises OSK; re-attach restores landscape + hides OSK; `systemctl --user is-enabled d330-tablet-daemon.service` -> enabled, status -> active; no tray Exec error in journal; mode journal lines never claim success when desktop calls failed."
    why_human: "Hardware-only (SC2 explicitly marked HARDWARE)."
---

# Phase 36: Desktop Session Wiring — Tray Applet & Tablet Daemon Verification Report

**Phase Goal:** Both user-facing helpers must run in the user's graphical session, not as a context-less root system service.
**Verified:** 2026-10-08T16:33:13Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| - | ----- | ------ | -------- |
| 1 | SC1: `scripts/test_tray_applet.sh` fails when the tray binary/autostart Exec name is wrong | ✓ VERIFIED | `bash scripts/test_tray_applet.sh` -> `passed=9 failed=0 / RESULT: PASS`, exit 0. Mutation: set `Exec=/usr/local/bin/d330-tray.py` -> harness exit **1**; restored via `git checkout --` -> `Exec=/usr/local/bin/d330-tray`. |
| 2 | SC2: on the D330, dock/undock visibly toggles orientation + OSK in a live GNOME session | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Hardware. User unit + session env inheritance wired; headless `--simulate-dock`/`--simulate-undock` log the honest `[WARNING] … some settings did not apply` (not success). Live GNOME outcome untested — see Human Verification. |
| 3 | The tray autostart Exec resolves to the name the installer deploys, and no cwd-relative `tools/d330-` fallback remains in `tools/d330-tray.py` | ✓ VERIFIED | `d330-tray.desktop:5` `Exec=/usr/local/bin/d330-tray`; `install_dkms.sh:494-495` `cp …/tools/d330-tray.py /usr/local/bin/d330-tray`; `git grep -n "tools/d330-" -- tools` -> none. |
| 4 | The tablet daemon runs as a systemd user unit in the desktop session, enabled via `systemctl --global enable`, deployed/verified/uninstalled symmetrically, shipped by all three packagers | ✓ VERIFIED | `patches/dock/usr/lib/systemd/user/d330-tablet-daemon.service` (WantedBy=default.target, Wants=/PartOf=/After=graphical-session.target); legacy `patches/dock/etc/systemd/system/d330-tablet-daemon.service` absent; `install_dkms.sh:535-537` global-enable guarded, `:870-873` global-disable guarded, `:1003-1026` `unit-user-enabled` verify kind; deb postinst:14 + rpm spec:52 global enable; debian/rules:25-26, rpm:44/68, arch PKGBUILD:34-35 copy to `/usr/lib/systemd/user/`. Symmetry suite `passed=17 failed=0`. |
| 5 | Mode-transition success is logged only when the desktop commands actually succeeded; the dead loop is gone | ✓ VERIFIED | `tools/d330-tablet-daemon.py` `apply_commands()` + `report_mode_result()` (`:144-150`) log success only when `failed` empty; headless run (no DISPLAY/Wayland) emitted `[WARNING] … did not apply …; failed: …` for both modes; `git grep -n "sw_file" -- tools` -> none. |

**Score:** 4/5 truths verified (1 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `patches/dock/usr/lib/systemd/user/d330-tablet-daemon.service` | user unit, `WantedBy=default.target` | ✓ VERIFIED | 18-line file; `After=/Wants=/PartOf=graphical-session.target`; `ExecStart=/usr/local/bin/d330-tablet-daemon --daemon`. |
| `scripts/test_tray_applet.sh` | SC1 regression harness | ✓ VERIFIED | 9 checks, exits non-zero on any failure; proven to catch a wrong Exec name. |
| `scripts/install_dkms.sh` | user-unit deploy + `systemctl --global enable` + uninstall + `--verify` kind | ✓ VERIFIED | manifest `unit-user`[:139]/`unit-user-enabled`[:154]; install[:507-537]; uninstall[:904]/[:870-873]; verify[:1003-1026],[:1079-1088]. |
| `tools/d330-tray.py` | installed-name-only helper, no cwd fallback | ✓ VERIFIED | stdlib only; `run_cmd("d330-ctl …")`; tri-state status; no GTK/AppIndicator. |
| `tools/d330-tablet-daemon.py` | dead loop removed, honest failure logging | ✓ VERIFIED | No `sw_file` loop; success gated on command results. |
| `packaging/debian/postinst`, `packaging/rpm/lenovo-d330-fix.spec`, `packaging/debian/rules`, `packaging/arch/PKGBUILD` | global enable + ship user unit | ✓ VERIFIED | All three packagers copy the unit to `/usr/lib/systemd/user/`; deb/rpm enable it globally. |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `patches/hardware_controls/etc/xdg/autostart/d330-tray.desktop` | `tools/d330-tray.py` | installer deploys to `/usr/local/bin/d330-tray` | ✓ WIRED | `Exec=/usr/local/bin/d330-tray` == deployed path from `install_dkms.sh:494-495`. |
| `scripts/install_dkms.sh` | `patches/dock/usr/lib/systemd/user/d330-tablet-daemon.service` | `cp` + `systemctl --global enable d330-tablet-daemon` | ✓ WIRED | `install_dkms.sh:508-509` copies; `:536` enables globally under a systemd-user guard. |
| `packaging/*` | user unit at `/usr/lib/systemd/user/` | packager install steps | ✓ WIRED | debian/rules:26, rpm:44, PKGBUILD:35; symmetry suite `user-unit-packaged` passes. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| SC1 harness green | `bash scripts/test_tray_applet.sh` | `passed=9 failed=0`, exit 0 | ✓ PASS |
| SC1 harness catches wrong Exec (mutation) | `sed Exec=…tray.py` + rerun | exit 1; restored | ✓ PASS |
| Installer symmetry | `bash scripts/test_installer_symmetry.sh` | `passed=17 failed=0` | ✓ PASS |
| Hibernate guards | `bash scripts/test_hibernate_guards.sh` | `passed=21 failed=0` | ✓ PASS |
| Display-fix guards | `bash scripts/test_display_fix_guards.sh` | `passed=10 failed=0` | ✓ PASS |
| MicroSD guards | `bash scripts/test_microsd_guards.sh` | `passed=26 failed=0` | ✓ PASS |
| Installer syntax | `bash -n scripts/install_dkms.sh` | exit 0 | ✓ PASS |
| Daemon CLI | `python3 tools/d330-tablet-daemon.py --status` / `--dry-run --simulate-dock` / `--dry-run --simulate-undock` | all exit 0 | ✓ PASS |
| Honest failure logging (headless) | `env -u DISPLAY -u WAYLAND_DISPLAY python3 … --simulate-dock` | `[WARNING] … did not apply …; failed: gsettings orientation, xrandr …` (no success line) | ✓ PASS |

### Probe Execution

Not applicable. Phase 36 declares no `scripts/*/tests/probe-*.sh` probes; SC1 is exercised via `test_tray_applet.sh` above.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| M3 | 36-01-PLAN | tray autostart Exec resolves to deployed binary; docs stop claiming GTK | ✓ SATISFIED | Exec fixed; `git grep -riq "GTK3 status icon\|StatusNotifier / XEmbed" CHANGES_AUDIT.md` -> no match; tray.py comments/README updated. |
| M6 | 36-01-PLAN | tablet daemon runs in the user session, honest logging, dead code removed | ✓ SATISFIED | User unit + global enable + guarded uninstall; `apply_commands`/`report_mode_result`; dead loop gone. |
| N7 | 36-01-PLAN | desktop entry hygiene (Icon / autostart) | ✓ SATISFIED | `Comment` matches notification helper; `X-GNOME-Autostart-enabled` retained (still valid); note: `Icon=preferences-system` retained, not flagged. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| — | — | No `TBD`/`FIXME`/`XXX` in any Phase-36-modified file | — | Clean. No stub returns in the modified helpers; tray `--status` has real tri-state logic. |

### Human Verification Required

#### 1. SC2 — Live GNOME dock/undock on a physical Lenovo D330

**Test:**
1. On a physical D330, build/install per README (`sudo ./scripts/install_dkms.sh --build --install`), reboot, log into GNOME as the desktop user.
2. `systemctl --user is-enabled d330-tablet-daemon.service` and `systemctl --user status d330-tablet-daemon`.
3. Detach the keyboard dock, then re-attach it.
4. Read the journal for the `set_laptop_mode`/`set_tablet_mode` lines and check the tray autostart started with no `Exec` error.

**Expected:** is-enabled -> `enabled`; status -> active. Detach -> panel auto-rotates to portrait and the on-screen keyboard appears. Re-attach -> rotation returns to landscape and the OSK disappears. The autostart tray helper starts with no Exec error. Mode journal lines claim success only when the desktop commands returned 0; otherwise an honest `[WARNING]` naming the failed commands.

**Why human:** Physical D330 hardware + a live GNOME session are required; the rotation/OSK state transition cannot be reproduced in this environment (headless runs deliberately warn instead of applying).

### Gaps Summary

All machine-verifiable must-haves pass: the SC1 harness genuinely fails on a wrong tray Exec name (mutation proven), the tray autostart resolves to the deployed `/usr/local/bin/d330-tray` with no cwd-relative fallbacks, the tablet daemon is a proper systemd **user** unit enabled with `systemctl --global enable` and shipped by all three packagers with matching deploy/verify/uninstall, the dead loop is gone, and mode success is logged only when the desktop commands succeed.

The single remaining gap is **SC2**, which the roadmap explicitly marks as hardware-only: a live GNOME dock/undock on a physical D330. It is counted under `behavior_unverified` and listed in `gaps` + `human_verification` with exact on-device steps. This is not a code defect; it is an unverifiable-in-CI success criterion.

---

_Verified: 2026-10-08T16:33:13Z_
_Verifier: the agent (gsd-verifier)_
