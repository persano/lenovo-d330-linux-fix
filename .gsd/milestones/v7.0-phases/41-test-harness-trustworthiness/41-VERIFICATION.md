---
phase: 41-test-harness-trustworthiness
verified: 2026-10-08T21:06:30Z
status: passed
score: 3/3 observable truths verified (SC1, SC2, and the --dry-run-validates-substance goal clause)
behavior_unverified: 0
overrides_applied: 0
re_verification: false
gaps: []
deferred:
  - truth: "Full test_*.sh suite exercised on physical D330 hardware (bare-hardware probe paths)"
    addressed_in: "on-device UAT / later milestone"
    evidence: "41-CONTEXT.md <deferred>: 'Running the full suite on the D330; CI integration beyond static guards.' Hardware-dependent probes (test_touch_calibration.sh default, test_mic_rnnoise.sh --probe) correctly exit non-zero on a non-D330 host; this is expected, not a harness defect."
---

# Phase 41: Test Harness Trustworthiness Verification Report

**Phase Goal:** A failing check must be able to fail the run. Today 23 of 27 `test_*.sh` exit 0 no matter what, and 22 of 23 `--dry-run` modes validate nothing.
**Verified:** 2026-10-08T21:06:30Z
**Status:** passed
**Re-verification:** No — initial verification

**Interpreter:** WSL bash 5.2 (`/usr/bin/python3` present). Git-Bash results were ignored as instructed. All raw output below is from WSL.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1 | SC1: `scripts/test_*.sh` returns non-zero when its subject is deliberately broken (mutation on at least 5 scripts) | ✓ VERIFIED | `bash scripts/test_harness_trust.sh` → `summary: passed=9 failed=0`, `RESULT: PASS`, rc=0. Five SC1 cases drive a broken subject and assert non-zero (audio-dsp, wireless-coex, udev-hwdb-match, power-stack, tray-applet). Independently re-proven below (3 subjects, manual mutation). |
| 2 | SC2: no `test_*` mutates the system without `--apply` | ✓ VERIFIED | Static scan reports exactly the 4 mutating scripts gated (`test_boot_speed.sh`, `test_hardware_controls.sh`, `test_memory_storage.sh`, `test_thermals.sh`); all other `test_*.sh` clean. Two negative controls turn the guard RED. `--apply` gates confirmed in all 4 mutating scripts. |
| 3 | Goal clause: a failing check can fail the run, and `--dry-run` modes validate real substance | ✓ VERIFIED | Every `test_*.sh` carries `exit 1` + `FAILED` counters (see table). `build_live_iso.sh --dry-run` rc=1 with `[ERR] missing required ISO tool: xorriso`, rc=0 with a stubbed xorriso on PATH (real validation, not a hardcoded manifest). `test_iso_integrity.sh --dry-run` inherits it. |

**Score:** 3/3 observable truths verified (0 present-behavior-unverified)

### Independently Re-proved SC1 (non-vacuity)

I broke the subjects myself (not via the meta-guard), ran the relevant script, restored with `git checkout --`, and confirmed the tree clean and byte-identical to backup:

| Subject mutated | Command | Intact rc | Broken rc | Restore |
| --- | --- | --- | --- | --- |
| `patches/audio_dsp/.../pipewire.conf.d/50-lenovo-d330-speaker-dsp.conf` (`label = bq_highpass`→`bq_bogus`) | `bash scripts/test_audio_dsp.sh --dry-run` | 0 | **1** (`Speaker DSP structure: passed=16 failed=1`, `[FAIL] Speaker DSP graph validation failed.`) | TREE-CLEAN, BYTES-MATCH-BACKUP |
| `patches/dkms/etc/udev/hwdb.d/61-lenovo-d330-sensor.hwdb` (`pn82H0`→`pnXX00`) | `bash scripts/test_udev_hwdb_match.sh` | 0 | **1** (`udev/hwdb match guard summary: passed=9 failed=1`) | TREE-CLEAN, BYTES-MATCH-BACKUP |
| `patches/hardware_controls/etc/xdg/autostart/d330-tray.desktop` (`Exec=`→bogus) | `bash scripts/test_tray_applet.sh` | 0 | **1** (`Tray applet checks: passed=8 failed=1`, `RESULT: FAIL`) | TREE-CLEAN, BYTES-MATCH-BACKUP |

Post-test `git status --porcelain` for the three subjects: empty. **SC1 is non-vacuous.**

### Independently Re-proved SC2 (non-vacuity)

| Control | Action | Result |
| --- | --- | --- |
| Ungated mutator | Added temporary `scripts/test_bogus_tmp.sh` containing bare `systemctl restart totally-bogus.service` | meta-guard rc=1, `[FAIL] SC2 test_bogus_tmp.sh: mutation(s) systemctl present with no --apply gate`; temp file removed |
| Real gate neutralised | Replaced `if [[ "$APPLY" -ne 1 ]]; then` with `if [[ "0" -ne 1 ]]; then` in `test_hardware_controls.sh` | meta-guard rc=1, `[FAIL] SC2 test_hardware_controls.sh: mutation(s) sysfs-write($node) present with no --apply gate`; restored, `git diff` clean |

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `scripts/test_harness_trust.sh` | SC1 mutation + SC2 static scan meta-guard | ✓ VERIFIED | 296 lines; `set -uo pipefail`; `SCRIPT_DIR`/`REPO_ROOT` anchor + `cd`; snapshot/restore trap; SC1 baseline-before-mutation check; SC1 5 subjects; SC2 command-position scan with sysfs-taint tracking, broadened vocabulary, delegated-`--apply` follow; prints PASS/FAIL and `exit 1` on failure |
| `scripts/build_live_iso.sh` | `--dry-run` validates real prerequisites | ✓ VERIFIED | Checks `xorriso`/`unsquashfs`/`mksquashfs`, `--base-iso` file, output parent existence **and writability**, source paths, `tools/d330-*` payload; `dry_failed` counter gates the exit |
| `scripts/test_iso_integrity.sh` | inherits the ISO dry-run honesty | ✓ VERIFIED | Anchored; runs `build_live_iso.sh --dry-run` and fails when prerequisites unmet |
| 20+ `test_*.sh` failure counters | `FAILED` counter + `exit 1` | ✓ VERIFIED | See counter table; no `cmd \|\| true` + unconditional success anti-pattern remains (only best-effort cleanup / optional-tool / dmesg-grep `\|\| true` uses remain) |
| `--apply` gates | 4 mutating scripts | ✓ VERIFIED | `test_thermals.sh` (MODE=apply via `--apply`), `test_boot_speed.sh` (MODE=apply via `--apply`), `test_battery_power.sh` (`APPLY=1` via `--apply`; `--tune` reads-only without it), `test_memory_storage.sh` (`APPLY` gates `--stress-zram`/`--stress-emmc`/`--trim`) |
| `SCRIPT_DIR` anchors | CWD independence | ✓ VERIFIED (30/35) / ⚠️ NOTE | 30 of 35 `test_*.sh` anchor via `SCRIPT_DIR`. 5 do not: `test_boot_orientation.sh`, `test_display_ergonomics.sh`, `test_gestures_pen.sh`, `test_sensor_als.sh`, `test_vaapi.sh` (all pre-existing, none modified by Phase 41). See Anti-Patterns. |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `scripts/test_storage_cellular.sh` | `scripts/test_harness_trust.sh` | aggregate invocation | ✓ WIRED | line 144 `bash scripts/test_harness_trust.sh`; line 64 also includes it in the `bash -n` loop |
| `scripts/test_harness_trust.sh` | 5 subject files | `sc1_case` sed mutation + restore | ✓ WIRED | audio_dsp conf, wireless conf, hwdb, fastboot cfg, tray `.desktop`; baseline rc==0 required, mutation non-no-op, restore byte-exact `cmp` |
| `scripts/test_harness_trust.sh` | every `scripts/test_*.sh` | SC2 static scan loop | ✓ WIRED | `for script in "$REPO_ROOT"/scripts/test_*.sh`; skips itself |

### Data-Flow Trace (Level 4)

Not applicable — shell test harnesses; there is no rendered/persisted data flow. The equivalent trace is command → real subject file → non-zero exit, verified above.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| SC1 meta-guard green | `bash scripts/test_harness_trust.sh` | `passed=9 failed=0`, RESULT: PASS, rc=0 | ✓ PASS |
| SC1 non-vacuous (audio DSP) | mutate 50-speaker-dsp.conf → `test_audio_dsp.sh --dry-run` | rc=1, `failed=1`, tree restored | ✓ PASS |
| SC1 non-vacuous (udev hwdb) | mutate 61-sensor.hwdb → `test_udev_hwdb_match.sh` | rc=1, tree restored | ✓ PASS |
| SC1 non-vacuous (tray) | mutate d330-tray.desktop → `test_tray_applet.sh` | rc=1, tree restored | ✓ PASS |
| SC2 flags ungated mutation | temp `test_bogus_tmp.sh` `systemctl restart` | meta-guard rc=1, `[FAIL] ... no --apply gate` | ✓ PASS |
| SC2 flags neutralised real gate | `test_hardware_controls.sh` APPLY guard removed | meta-guard rc=1, `[FAIL] ... sysfs-write($node)` | ✓ PASS |
| ISO dry-run validates prereqs (negative) | `build_live_iso.sh --dry-run` | rc=1, `[ERR] missing required ISO tool: xorriso (install: apt install xorriso squashfs-tools)` | ✓ PASS |
| ISO dry-run validates prereqs (positive) | stub `xorriso`/`unsquashfs`/`mksquashfs` on PATH → `build_live_iso.sh --dry-run` | rc=0, `[OK] [DRY-RUN] Remaster prerequisites validated` | ✓ PASS |
| Installer symmetry suite | `test_installer_symmetry.sh` | `passed=17 failed=0`, rc=0 | ✓ PASS |
| Hibernate guard suite | `test_hibernate_guards.sh` | `passed=21 failed=0`, rc=0 | ✓ PASS |
| Display-fix guard suite | `test_display_fix_guards.sh` | `passed=10 failed=0`, rc=0 | ✓ PASS |
| MicroSD guard suite | `test_microsd_guards.sh` | `passed=26 failed=0`, rc=0 | ✓ PASS |
| No-op guard suite | `test_noop_guards.sh` | `passed=5 failed=0`, rc=0 | ✓ PASS |
| udev/hwdb match guard | `test_udev_hwdb_match.sh` | `passed=10 failed=0`, rc=0 | ✓ PASS |
| Power-stack guard | `test_power_stack.sh` | `passed=12 failed=0`, rc=0 | ✓ PASS |
| Audio DSP dry-run | `test_audio_dsp.sh --dry-run` | `Speaker DSP structure: passed=17 failed=0`, rc=0 | ✓ PASS |
| RNNoise dry-run | `test_mic_rnnoise.sh --dry-run` | `RNNoise structure: passed=7 failed=0`, rc=0 | ✓ PASS |
| Storage/cellular aggregate dry-run | `test_storage_cellular.sh --dry-run` | rc=0, `[OK] dry-run verification complete` (incl. real FCC hook + Cellular Rules file) | ✓ PASS |
| Syntax | `bash -n` over all `scripts/*.sh` | 0 failures across 40 scripts | ✓ PASS |

### Probe Execution

Not applicable — no `scripts/*/tests/probe-*.sh` exist in this repo. Step 7c probes: none declared.

### Requirements Coverage

No `REQUIREMENTS.md` in this project (SC-based phase; `41-VALIDATION.md` confirms "no REQUIREMENTS.md → SC-based frontmatter"). Roadmap contract = SC1 + SC2, both satisfied. No orphaned requirements.

### Failure-counter inventory (grep `exit 1` / `FAILED`)

| Script | `exit 1` hits | `FAILED`/counter hits | Script | `exit 1` hits | `FAILED`/counter hits |
| ------ | --- | --- | ------ | --- | --- |
| test_acpi_cleanliness.sh | 2 | 5 | test_mic_rnnoise.sh | 2 | 0 |
| test_audio_dsp.sh | 1 | 0 | test_microsd_guards.sh | 5 | 1 |
| test_audio_profiles.sh | 2 | 11 | test_noop_guards.sh | 2 | 1 |
| test_auto_hibernate.sh | 3 | 8 | test_oom_protection.sh | 2 | 5 |
| test_battery_power.sh | 4 | 0 | test_power_stack.sh | 1 | 1 |
| test_boot_orientation.sh | 1 | 0 | test_resume_loop.sh | 4 | 2 |
| test_boot_speed.sh | 1 | 0 | test_sensor_als.sh | 3 | 0 |
| test_cameras.sh | 2 | 10 | test_storage_cellular.sh | 7 | 0 |
| test_ci_workflows.sh | 1 | 0 | test_tablet_osk.sh | 1 | 0 |
| test_display_ergonomics.sh | 1 | 0 | test_thermals.sh | 1 | 0 |
| test_display_fix_guards.sh | 2 | 2 | test_touch_calibration.sh | 3 | 18 |
| test_distro_packaging.sh | 2 | 4 | test_tray_applet.sh | 3 | 4 |
| test_dock_switching.sh | 4 | 5 | test_udev_hwdb_match.sh | 1 | 1 |
| test_gestures_pen.sh | 1 | 0 | test_vaapi.sh | 1 | 0 |
| test_harness_trust.sh | 1 | 1 | test_wireless_coex.sh | 4 | 1 |
| test_hibernate_guards.sh | 3 | 1 | test_iso_integrity.sh | 5 | 4 |
| test_installer_symmetry.sh | 2 | 1 | test_memory_storage.sh | 3 | 0 |

Parser/arith fixes confirmed: `test_resume_loop.sh` log path is `/tmp/resume_test_*.log` (not `docs/dumps/`); `test_battery_power.sh --stress N` and `test_dock_switching.sh --cycle-test N` validate `^[0-9]+$` and consume the value; `test_tablet_osk.sh` calls `tools/d330-tablet-daemon.py --dry-run --simulate-dock|--simulate-undock` (both flags exist in the daemon argparse).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `scripts/test_sensor_als.sh` | 69, 106 | `tools/d330-sensor-filter.py` referenced CWD-relative; no `SCRIPT_DIR` anchor | ⚠️ Warning | `--dry-run` works from repo root (rc=0) but returns rc=2 from `scripts/`. Pre-existing and **not modified by Phase 41**; does not affect SC1/SC2. |
| `scripts/test_boot_orientation.sh`, `test_display_ergonomics.sh`, `test_gestures_pen.sh`, `test_vaapi.sh` | various | `tools/` refs CWD-relative, no `SCRIPT_DIR` anchor | ℹ️ Info | Their `--dry-run` paths do not invoke `tools/`, so they still pass from `scripts/`; probe paths would break. Pre-existing, outside Phase 41's modified set. |
| `scripts/test_hardware_controls.sh` | 85-86 | `python3 ... battery status \|\| true` then `exit 0` | ℹ️ Info | Inside the read-only `--test-toggle`-without-`--apply` branch; informational by design, not a false OK for a broken subject. |
| `scripts/test_battery_power.sh` | 157-159 | `kill ... \|\| true` / `wait ... \|\| true` | ℹ️ Info | Process cleanup in the `--stress` path, not an assertion; not the always-green anti-pattern. |

No debt markers (`TBD`/`FIXME`/`XXX`) in any Phase-41-modified file — `XXXXXX` hits were `mktemp` templates only. No placeholder/no-op return stubs.

### Deferred Items

| # | Item | Addressed In | Evidence |
| - | ---- | ------------ | -------- |
| 1 | Full suite on physical D330 (bare-hardware probe paths) | on-device UAT / later milestone | `41-CONTEXT.md <deferred>`; hardware probes exit non-zero on a non-D330 host by design |

### Gaps Summary

No gaps. SC1 and SC2 — the complete roadmap success-criteria contract for this phase — are machine-verified and independently re-proven non-vacuous. The goal clause (`--dry-run` validates real substance) holds for the ISO dry-run, and every `test_*.sh` now tracks failures and exits non-zero. The only residual (5 pre-existing scripts lacking `SCRIPT_DIR`, of which `test_sensor_als.sh --dry-run` demonstrably breaks from `scripts/`) is outside the phase's modified set and does not affect either success criterion; it is recorded as an advisory Warning above, not a blocking gap. Hardware-bound probe paths are deferred to on-device UAT.

---

_Verified: 2026-10-08T21:06:30Z_
_Verifier: the agent (gsd-verifier)_
