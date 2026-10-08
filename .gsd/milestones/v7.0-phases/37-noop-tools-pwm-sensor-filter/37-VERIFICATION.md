---
phase: 37-noop-tools-pwm-sensor-filter
verified: 2026-10-08T17:16:17Z
status: passed
score: 3/3 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification: false
gaps: []
---

# Phase 37: No-Op Tools Made Real or Removed — PWM & Sensor Filter — Verification Report

**Phase Goal:** Stop reporting success for operations that perform no write.
**Verified:** 2026-10-08T17:16:17Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | SC1: `d330-sensor-filter` does not exit on its own; with a sensor source present it runs indefinitely (proven: a >60 s run does not terminate) | ✓ VERIFIED | Behavioral test passed: `bash scripts/test_noop_guards.sh` case (c) runs `timeout 62 python3 tools/d330-sensor-filter.py --monitor` against a fake `bosc0200` IIO tree and observes `timeout` kill it: `[OK] sensor-filter-alive->60s (timeout rc=124)`. Code: `tools/d330-sensor-filter.py:121` `while running:`; `--monitor` (no `--cycles`) never sets a bound; SIGTERM/SIGINT handlers at `:113-114` exit 0 (independently observed `TERM_RC=0`, `INT_RC=0`); `--once`/`--cycles 3` terminate rc 0 (`ONCE_RC=0`, `CYCLES_RC=0`). |
| 2 | SC2: `d330-backlight-pwm.py --apply` reports a verifiable register delta OR the no-op operation is removed | ✓ VERIFIED | Both halves proven. Honest apply: stub `intel_reg` that changes the value -> `[OK] PWM BXT_BLC_PWM_FREQ1: 0x... -> 0x...` rc 0 (`pwm-readback-delta-ok`); stub that ignores the write -> `[FAIL]` rc 1 (`pwm-readback-no-delta-fail`); empty-PATH (no `intel_reg`) -> `[SKIP] intel_reg not available; no PWM register written.` rc 2, no `[OK]`. Removal: `patches/display_ergonomics/etc/systemd/system/lenovo-d330-backlight-pwm.service` absent (`Test-Path` False), no deploy/manifest/packager reference remains. |
| 3 | No tool/harness prints `[OK]`/"verified successfully" for an operation that performed no write | ✓ VERIFIED | `scripts/test_display_ergonomics.sh --test-pwm` propagates the tool rc and prints `[FAIL] PWM apply did not verify a register write (rc=2); no success claimed.` (rc 2). `scripts/test_sensor_als.sh --dry-run` captures real output and greps for `rotation decision` + `ALS: Raw=` (no `\|\| true`). `scripts/test_noop_guards.sh` summary `passed=5 failed=0` rc 0. No unconditional `[OK]` path in either tool. |

**Score:** 3/3 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `tools/d330-backlight-pwm.py` | Honest apply: read-back delta or explicit skip/fail | ✓ VERIFIED | `apply_pwm_tuning()` exits 2 on absent `intel_reg` (no write), 1 on unconfirmed/unchanged write, 0 only on a confirmed read-back delta. `read_register()` parses the hex value **after the last `:`** (verified: `(0xC8254): 0x00000BB8` -> `0xbb8`), returns `None` for no-value/garbage output so the caller refuses to write. `PWM_REGISTERS` targets only `("BXT_BLC_PWM_FREQ1", 0xC8254)`; never `0xC8258` (duty). |
| `tools/d330-sensor-filter.py` | Infinite loop + real accel deadband/hysteresis + `D330_IIO_BASE` seam | ✓ VERIFIED | `while running:` loop; 15° deadband (`HYSTERESIS_DEG=15.0`) + 0.5 s debounce (`ACCEL_DEBOUNCE_SEC`); reads `in_accel_{x,y,z}_raw`; ALS fallback `in_illuminance_raw` -> `in_illuminance_input` -> `in_intensity_*_raw`; `D330_IIO_BASE` seam at `:31-32`, used by `find_iio_devices()` and node paths. |
| `scripts/test_noop_guards.sh` | Honesty harness (service removed, no-false-success, >60 s liveness, delta) | ✓ VERIFIED | Exists, executable, `set -uo pipefail`, 4 checks + summary; rc 0 with `passed=5 failed=0`; wired into `scripts/test_storage_cellular.sh:91` (IN-03). |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `scripts/install_dkms.sh` | `lenovo-d330-backlight-pwm.service` | removed from manifest/install/enable/uninstall; enabled units 9 -> 8 | ✓ WIRED | No `unit`/`unit-enabled` deploy entry; install copies only the tool (`:468-470`); uninstall removes tool (`:836`) and a `find ... -name 'lenovo-d330-backlight-pwm.service' -delete` migration (`:909`, a removal). Census comment `:524-529` states 8. `grep -rn backlight-pwm packaging/` -> empty. Symmetry case `enable-parity-8` passes. |
| `scripts/test_sensor_als.sh` | `tools/d330-sensor-filter.py` | `D330_IIO_BASE` fake tree + `--cycles`, rc propagated | ✓ WIRED | `:69` `out="$(D330_IIO_BASE="$iio_tmp" python3 tools/d330-sensor-filter.py --cycles 3 2>&1)"`; asserts `rotation decision` and `ALS: Raw=`; `--dry-run` rc 0. |
| `patches/sensors/.../d330-sensor-filter.service` | `/usr/local/bin/d330-sensor-filter` | `ExecStart` matches deployed name | ✓ WIRED | Unit `ExecStart=/usr/local/bin/d330-sensor-filter --monitor`; manifest `:132` and install `cp` `:474-476` deploy the suffix-free name. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `tools/d330-backlight-pwm.py` | `before`/`after` register values | `read_register()` -> `intel_reg read` stdout | Yes (parses value token, verified against `name (0xADDR): 0xVALUE`) | ✓ FLOWING |
| `tools/d330-sensor-filter.py` | `angle`, `raw_lux` | `D330_IIO_BASE`/`/sys/bus/iio/devices` nodes | Yes (fake tree dry-run emitted `tilt=90.0 deg` + `Raw=200.0 lux`) | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| No-op guard suite (incl. >60 s liveness + delta/no-delta) | `bash scripts/test_noop_guards.sh` | `passed=5 failed=0`, rc 0 | ✓ PASS |
| Sensor filter liveness > 60 s | `timeout 62 ... --monitor` (inside suite) | rc 124 (killed, did not self-exit) | ✓ PASS |
| PWM no-false-success without `intel_reg` | `bash -c 'PATH=<emptydir> /usr/bin/python3 tools/d330-backlight-pwm.py --apply; echo rc=$?'` | `[SKIP] intel_reg not available; no PWM register written.` `rc=2`, no `[OK]` | ✓ PASS |
| Sensor dry-run (fake accel + ALS tree) | `bash scripts/test_sensor_als.sh --dry-run` | `rotation decision` + `ALS: Raw=200.0 lux -> Smoothed=...`, rc 0 | ✓ PASS |
| Display PWM test propagates rc | `bash scripts/test_display_ergonomics.sh --test-pwm` | `[FAIL] ... (rc=2); no success claimed.`, rc 2 | ✓ PASS |
| SIGTERM / SIGINT clean exit | `kill -TERM` / `kill -INT` on `--monitor` | `TERM_RC=0`, `INT_RC=0` | ✓ PASS |
| `--once` / `--cycles 3` terminate | `python3 tools/d330-sensor-filter.py --once` / `--cycles 3` | `ONCE_RC=0`, `CYCLES_RC=0` | ✓ PASS |

### Probe Execution

Not applicable — no `scripts/*/tests/probe-*.sh` probes declared or implied by this phase; the machine-checkable suite is `scripts/test_noop_guards.sh` (run above).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| Audit M4 | 37-01 | PWM no-op reporting | ✓ SATISFIED | Honest delta/skip/fail contract + no-op boot service removed |
| Audit M5 | 37-01 | Sensor filter dies after ~1 s | ✓ SATISFIED | `while running` infinite loop; >60 s liveness proven |
| Audit M17 (partial) | 37-01 | Docs match behavior (§4.5) | ✓ SATISFIED | `CHANGES_AUDIT.md` §4.5 rewritten to describe the removal + honest contract |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | No `TBD`/`FIXME`/`XXX` debt markers in phase-modified files | ℹ️ Info | Grep hits for `XXX` were only `mktemp` `XXXXXX` templates — not debt markers |

### Human Verification Required

N/A — this is a tooling/honesty phase whose acceptance criteria (no self-termination, no false-success reports) are fully machine-proven here. The only residual item is external: confirming that a real target `intel_reg read 0xC8254` emits the `name (0xADDR): 0xVALUE` format. It does not affect the goal, because any unrecognized format causes `read_register()` to return `None`, the caller refuses to write, and the tool prints `[FAIL]`/`[SKIP]` with a non-zero exit — it can never falsely report success.

### Gaps Summary

No gaps. All three must-haves are VERIFIED with fresh raw command output:
- SC1 liveness is behaviorally proven (timeout rc 124 against a real `--monitor` run).
- SC2 is proven on both branches: verifiable read-back delta (stub `[OK]` rc 0; no-delta `[FAIL]` rc 1) and removal of the no-op boot service (file absent, no deploy/manifest/packager reference, enabled parity 8).
- The core honesty goal holds across both tools and both harnesses; the previously lying `\|\| true` paths are gone.

Supporting gates also green: `test_installer_symmetry` 17/0, `test_hibernate_guards` 21/0, `test_display_fix_guards` 10/0, `test_microsd_guards` 26/0, `bash -n scripts/install_dkms.sh` rc 0.

---

_Verified: 2026-10-08T17:16:17Z_
_Verifier: the agent (gsd-verifier)_
