---
gsd_state_version: 1.0
milestone: v7.0
milestone_name: Pre-Deployment Audit Remediation
current_phase: 37
current_phase_name: No-Op Tools Made Real or Removed — PWM & Sensor Filter
status: planning
stopped_at: Phase 36 complete, ready to plan Phase 37
last_updated: "2026-10-08T16:35:20.334Z"
last_activity: 2026-10-08
last_activity_desc: Phase 36 complete, transitioned to Phase 37
state_head: 9a3ca00b1ca9d810a1db3bffe506fdfce367b947
progress:
  total_phases: 11
  completed_phases: 5
  total_plans: 9
  completed_plans: 9
  percent: 45
---

# STATE: Project Execution State

- **Active Milestone**: Milestone 7 — Pre-Deployment Audit Remediation (v7.0), Phases 32–42
- **Active Phase**: Phase 37: No-Op Tools Made Real or Removed — PWM & Sensor Filter (Audit M4, M5)
- **Status**: Executing. Phases 32–36 complete (5/11 phases). Original audit verdict: `BLOCKED BY CRITICAL DEFECTS` (4 Critical, 17 Moderate, 11 Minor) — remediation underway in phases 32 → 42.
- **Blockers**:
  * [RESOLVED — Phase 32] C1 — `tools/d330-microsd-setup.sh --format` can mkfs the root disk (no mount check, `-F`, auto device substitution). Fixed: explicit `--device`, three ordered pre-write guards, no force flag, `partprobe`+`settle`; suite 26/0.
  * [RESOLVED — Phase 32] C2 — `--mount-data` writes an fstab entry without `nofail` → emergency shell when the card is absent. Fixed: locked `nofail,x-systemd.device-timeout=10s` options, verify-before-append, rollback trap; suite 26/0.
  * [RESOLVED — Phase 33] C3 — low-battery auto-hibernate had only a 3 GB zram swap → no valid resume device, safety net could not work. Fixed: disk-backed `/var/swapfile` oneshot unit (RAM-sized 4–8 GB clamp, free-space guard), fail-closed resume activation ladder (`resume=`+`resume_offset=`, honest manual-step exit), daemon refuse+degrade with `[ERROR]` when non-zram swap absent, enable sites ×3, ExecStart/package-name alignment; suite 21/0 + 26/0. Hardware round trip deferred (see PENDING DEPLOY).
  * [RESOLVED — Phase 34] C4 — the 600 ms PPS clamp was not delivered and the module advertised enforcement it did not perform. Fixed: module reduced to an honest DMI banner/breadcrumb (research proved no notifier event exists between panel-off/on), echo-only resume service deleted with all refs, optional `--kernel-src` clamp-patch step (dry-run first, warn-not-fail), grub cfg keeps `video=efifb:nobgrt` + adds `panel_orientation` tokens, dkms.conf build guards, README/CHANGES_AUDIT truth-fix, resume-loop set -e arithmetic fixed (--simulate 5/5). Suites 10/0 + 21/0 + 26/0. Hardware dmesg + real 5-cycle deferred (see PENDING DEPLOY).
  * [RESOLVED — Phase 35] M1/M2/M11/N6 — installer/uninstaller asymmetry. Fixed: single deploy manifest driving install/uninstall/`--verify [--root] [--removed]`, GRUB regen both paths, rescue-shell `--uninstall`/`--verify` (prereq+EUID skipped for install only), all 9 shipped units enabled at install_dkms.sh/deb/rpm, narrow earlyoom drop-in removal, named missing-package WARNs, uninstall gaps closed (state json, unmask wait-online ×2, dracut), `[WARN]` de-duplicated, best-effort removals with honest non-root warning, `.gitattributes *.sh eol=lf`. Suites 16/0 + 21/0 + 10/0 + 26/0. Hardware install→find / is-enabled deferred (see PENDING DEPLOY).
  * [RESOLVED — Phase 36] M3/M6/N7 — tray autostart pointed at a never-created binary and the tablet daemon ran as a context-less root system unit (all session commands silently no-op'd), with docs claiming a GTK app that does not exist. Fixed: desktop `Exec` -> `/usr/local/bin/d330-tray`, tray cwd-relative fallbacks removed, false GTK/AppIndicator claims downgraded to the honest stdlib notification/status helper; daemon converted to a systemd **user** unit (`/usr/lib/systemd/user/`, `WantedBy=default.target` + `Wants/PartOf=graphical-session.target`), enabled via `systemctl --global enable` at install + deb + rpm + shipped by all 3 packagers, install/`--verify`/uninstall manifest kinds `unit-user`/`unit-user-enabled`, dead loop removed, mode success logged only for desktop-applicable commands (headless run logs `[WARNING]`), dead udev triggers dropped. SC1: `test_tray_applet.sh` now exits non-zero on a wrong Exec (mutation-proven). Suites 9/0 + 17/0 + 21/0 + 10/0 + 26/0. Live GNOME dock/undock deferred (see PENDING DEPLOY).
  * [PENDING DEPLOY] Phase 32 UAT items 1–2 — physical mounted-target abort on a real MicroSD and on-target `/etc/fstab` + absent-card boot on the D330 — were deferred under documented VERIFICATION overrides (no hardware in this environment). Machine-checked equivalents are green (suite 26/0). Re-run on the tablet at sign-off: `/gsd-verify-work 32`.
  * [PENDING DEPLOY] Phase 33 UAT tests 1–2 — `systemctl hibernate` → power-cycle → resume round trip, and on-device `systemctl is-enabled` ×2 after a real install — deferred under documented VERIFICATION overrides (no hardware). Machine-checked equivalents green (probe: dry-run report, zram-only refusal, ready-path hibernate invocation; suites 21/0 + 26/0). Re-run on the tablet at sign-off: `/gsd-verify-work 33` (7-step sequence in `33-03-SUMMARY.md`).
  * [PENDING DEPLOY] Phase 34 UAT tests 1–2 — `dmesg | grep lenovo_d330_fix` DMI banner and 5 real suspend/resume cycles on the D330 — deferred under documented VERIFICATION overrides. Machine-checked equivalents green (`--simulate` 5/5; module static asserts; suites 10/0 + 21/0 + 26/0). Re-run at sign-off: `/gsd-verify-work 34`.
  * [PENDING DEPLOY] Phase 35 UAT tests 1–2 — real install→`find /etc /usr/local/bin /usr/share/alsa` empty sweep and `systemctl is-enabled` ×9 after a real install — deferred under documented VERIFICATION overrides (no systemd target). Machine-checked equivalents green (`--verify --removed` round trip, 9-unit enable parity; suites 16/0 + 21/0 + 10/0 + 26/0). Re-run at sign-off: `/gsd-verify-work 35`.
  * [PENDING DEPLOY] Phase 36 UAT test 1 — live GNOME dock/undock on the D330 (panel auto-rotate + OSK on detach, landscape + OSK hide on attach; `systemctl --user` unit active) — deferred under a documented VERIFICATION override (no hardware/live session). Machine-checked equivalents green (user-unit shape + packager deploy + enable parity; tray harness 9/0 with SC1 mutation catch; suites 17/0 + 21/0 + 10/0 + 26/0). Re-run at sign-off: `/gsd-verify-work 36`.
- **Next Immediate Action**: Plan/execute Phase 37 (no-op tools: make `d330-backlight-pwm` / `d330-sensor-filter` real or remove them, per Audit M4/M5) before 38–42.

## Archived Milestones

- [x] **Milestone 1: Display & Power Parity (v1.0)** - All Phases 0-5 Completed & Shipped
- [x] **Milestone 2: Peripheral Parity & Tablet Usability (v2.0)** - All Phases 6-9 Completed & Shipped
- [x] **Milestone 3: Vision, Ergonomics & Multimedia (v3.0)** - All Phases 10-14 Completed & Shipped
- [x] **Milestone 4: Connectivity, Firmware & System Boot (v4.0)** - All Phases 15-20 Completed & Shipped
- [x] **Milestone 5: CI/CD & Remastered Live ISO Distribution (v5.0)** - All Phases 21-23 Completed & Shipped
- [x] **Milestone 6: System Resilience, Performance & Usability Polish (v6.0)** - All Phases 24-31 Completed & Shipped

## Active Milestone

- [ ] **Milestone 7: Pre-Deployment Audit Remediation (v7.0)** - Phases 32-42 Not Started (see `.gsd/milestones/v7.0-ROADMAP.md`)

## Current Position

Phase: 37 — No-Op Tools Made Real or Removed — PWM & Sensor Filter
Plan: Not started
Status: Ready to plan
Last activity: 2026-10-08 — Phase 36 complete, transitioned to Phase 37

## Performance Metrics

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 33 P33-03 | 20min | 1 tasks | 3 files |
| Phase 34 P34-01 | 25min | 7 tasks | 13 files |

## Decisions

- [Phase ?]: 33-03: README documents Secure Boot/lockdown degradation as owner decision, never an instruction to weaken security (R3)
- [Phase ?]: 33-03: R1 probe commands + round-trip-only-proof rule embedded verbatim in README Known Limits so the unverified initramfs swap-file resume stays visible
- [Phase ?]: 33-03: requirements SC1-3 left unmarked (on-device proof deferred to UAT); marking now would claim unproven success (T-33-04)
- [Phase ?]: 34-01: PM handler is option (b) honest DMI banner; research Q1 proves no notifier event between panel-off/on so a notifier sleep adds zero TCON discharge time
- [Phase ?]: 34-01: video=efifb:nobgrt KEPT (research 3a disproved removal premise; parsed by efifb_setup)
- [Phase ?]: 34-01: echo-only resume service deleted with zero stale refs; enabled-unit census 9->8 (Phase 35 recount)
- [Phase ?]: 34-01: SC1/SC2 left hardware-gated (Task 8 UAT); only SC3 machine-verified this phase

## Session

**Last session:** 2026-10-08T14:28:40.277Z
**Stopped at:** Phase 36 complete, ready to plan Phase 37
**Resume file:** None
