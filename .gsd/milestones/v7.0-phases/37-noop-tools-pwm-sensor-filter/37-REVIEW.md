---
phase: 37-noop-tools-pwm-sensor-filter
reviewed: 2026-10-08T00:00:00Z
depth: deep
files_reviewed: 13
files_reviewed_list:
  - CHANGES_AUDIT.md
  - docs/research/DISPLAY_ERGONOMICS_PWM_ICC.md
  - packaging/debian/postinst
  - packaging/rpm/lenovo-d330-fix.spec
  - patches/display_ergonomics/README.md
  - patches/display_ergonomics/etc/systemd/system/lenovo-d330-backlight-pwm.service
  - scripts/install_dkms.sh
  - scripts/test_display_ergonomics.sh
  - scripts/test_installer_symmetry.sh
  - scripts/test_noop_guards.sh
  - scripts/test_sensor_als.sh
  - tools/d330-backlight-pwm.py
  - tools/d330-sensor-filter.py
findings:
  critical: 1
  warning: 8
  info: 3
  total: 12
status: issues_found
---

# Phase 37: Code Review Report

**Reviewed:** 2026-10-08
**Depth:** deep
**Files Reviewed:** 13
**Status:** issues_found

## Summary

Phase 37 replaces three dishonest success paths: the PWM tool, the sensor daemon, and the harnesses that masked failures. The service retirement is clean at the artifact level, and the sensor daemon's liveness/termination contract is correct. However, the headline PWM honesty change is self-defeating: `read_register()` parses the wrong token from `intel_reg`'s real output, so the tool can never print `[OK]` and, worse, writes a target derived from the register *address* into the live PWM register. Several new harnesses also pass vacuously or claim coverage they do not have, which is exactly the failure class this phase set out to eliminate.

## Critical Issues

### CR-01: `read_register()` parses the register address, not its value

**File:** `tools/d330-backlight-pwm.py:77-83`
**Issue:** `intel_reg read` emits `name (0xADDR): 0xVALUE` for MMIO registers without an offset (`dump_regval()` in intel-gpu-tools `tools/intel_reg.c`). The parser takes the **first** `0x` token, which is the register address in parentheses, not the value. Consequences: (a) `before` and `after` both resolve to the address, so `after != before` is never true and the tool prints `[FAIL]`/exits 1 on every real host — it can never verify its own write; (b) because `before` is actually the address, `target = (before & ~0xFFFF) | divider` derives `0x000c0000` upper bits and writes that garbage into the real PWM register before failing; (c) the "register not present, try the next" skip is effectively dead whenever the register is readable. The no-op guard cannot catch this because it only tests the no-`intel_reg` path.
**Fix:**
```python
import re
_VAL_RE = re.compile(r"0x([0-9a-fA-F]+)")
def read_register(tool, address):
    ...
    matches = _VAL_RE.findall(proc.stdout.split(":")[-1]) or _VAL_RE.findall(proc.stdout)
    if not matches:
        return None
    try:
        return int(matches[-1], 16)
    except ValueError:
        return None
```
Parse the value after the last `:` separator (falling back to the last hex token) and never write unless a plausible value was parsed.

## Warnings

### WR-01: Second PWM register entry is mislabeled and points at the duty register

**File:** `tools/d330-backlight-pwm.py:26`
**Issue:** `("BXT_BLC_PWM_FREQ1", 0xC8258)` is wrong. Per kernel `intel_backlight_regs.h`: `_BXT_BLC_PWM_FREQ1 = 0xC8254` and `_BXT_BLC_PWM_DUTY1 = 0xC8258`. 0xC8254 is already probed as the first entry (`BLC_PWM_PCH_CTL2`/BXT FREQ1); 0xC8258 is the **duty** register. If the first register were skipped, the divider would be written into the duty register, corrupting brightness.
**Fix:** Drop the second entry (the address is already covered) or use the true `FREQ1` (0xC8254) and never target 0xC8258. Update the comment to cite the correct register names.

### WR-02: Sensor dry-run never exercises the new ALS fallback it claims to test

**File:** `scripts/test_sensor_als.sh:59-65`
**Issue:** The fake tree creates a single IIO device named `bosc0200`. `find_iio_devices()` classifies with `if ... elif`, so only `devs["accel"]` is set and `devs["als"]` stays `None`. The `in_illuminance_input` fallback added in this phase is never executed, yet the script prints it as verified. (The same single-device tree in `test_noop_guards.sh` is acceptable there because it only asserts liveness.)
**Fix:** Add a second device directory whose `name` matches the ALS pattern, e.g. `iio:device1` with `name=acpi0008` and `in_illuminance_input=200`.

### WR-03: `--apply` no-intel_reg guard leaks the host PATH and can perform a real MMIO write

**File:** `scripts/test_noop_guards.sh:70-72`
**Issue:** `PATH="$PYDIR"` only excludes `intel_reg` if it is not co-located with `python3`. On Debian/Ubuntu both live in `/usr/bin`, so on a developer or target machine the guard invokes the real `intel_reg` and attempts a register write. The test is therefore non-hermetic and has side effects on the host.
**Fix:** Point PATH at a fresh empty temp dir (`empty="$(mktemp -d)"; PATH="$empty" "$PY3" ...`) or set `D330_INTEL_REG=/nonexistent-intel_reg` for the run so the tool is guaranteed to skip.

### WR-04: Dry-run harness asserts only the exit code, not the behavior

**File:** `scripts/test_sensor_als.sh:65-66`
**Issue:** The dry-run runs `--cycles 3` and only relies on `set -e` for pass/fail. A filter that emits no rotation decision and no ALS smoothing line still exits 0, so the harness passes vacuously.
**Fix:** Capture output (`out="$(D330_IIO_BASE=... python3 ... --cycles 3)"`), then `grep -q 'rotation decision'` and `grep -q 'ALS: Raw='` before the success message.

### WR-05: Sensor service ExecStart cannot resolve under the repo installer

**File:** `patches/sensors/etc/systemd/system/d330-sensor-filter.service:8`
**Issue:** `ExecStart=/usr/local/bin/d330-sensor-filter.py`, but `scripts/install_dkms.sh` deploys the tool as `/usr/local/bin/d330-sensor-filter` (manifest line 132; `cp` lines 474-476), and `CHANGES_AUDIT.md` documents the suffix-free path. On an install_dkms host the daemon this phase just made a real long-running process will fail to start. (Pre-existing mismatch, but Phase 37's liveness guarantee never takes effect through the repo installer.)
**Fix:** Make `ExecStart` and the deployed filename agree — either fix the unit to `/usr/local/bin/d330-sensor-filter` or install the `.py` name — and add a symmetry assertion.

### WR-06: The new write/read-back verification path is completely untested

**File:** `scripts/test_noop_guards.sh:66-78`
**Issue:** Section (b) only exercises the no-`intel_reg` `[SKIP]` branch. The new "write then verify read-back delta" logic — the actual M4 fix — has no test, which is why CR-01 shipped undetected.
**Fix:** Add a stub `intel_reg` on a temp PATH that (i) returns a fixed value for `read`, (ii) writes a different value so a delta is observed, and assert `[OK]`/rc 0; then a stub that returns the same value and assert `[FAIL]`/rc non-zero.

### WR-07: PWM register field/mask is wrong for the PCH layout

**File:** `tools/d330-backlight-pwm.py:112-113`
**Issue:** The comment claims a "low 16-bit divider field", but for `BLC_PWM_PCH_CTL2` the frequency lives in bits 31:17 (`BACKLIGHT_MODULATION_FREQ_MASK`) and bits 15:0 are the duty cycle (`BACKLIGHT_DUTY_CYCLE_MASK = 0xffff`, per kernel `intel_backlight_regs.h`). Writing the divider into the low 16 bits programs duty, not frequency, on PCH-split platforms. Only the Gemini Lake aliasing (0xC8254 = BXT FREQ1) makes the address plausible on this device.
**Fix:** Use the correct field per register (PCH: `divider << 17` under the FREQ mask; BXT FREQ: full value) or scope the code explicitly to BXT FREQ1 with a comment.

### WR-08: Uninstall retirement uses a wildcard delete over `/etc/systemd/system`

**File:** `scripts/install_dkms.sh:909`
**Issue:** `find /etc/systemd/system -maxdepth 2 -name '*backlight-pwm*.service' -delete` can remove any foreign unit matching the glob, contrary to the installer's exact-path removal convention (and the `no-broad-rm-rf`/`no-broad-ucm-rm-rf` spirit of the same suite).
**Fix:** Restrict the match to the installer-owned basename, e.g. `-name 'lenovo-d330-backlight-pwm.service' -delete`, or remove the exact retired path.

## Info

### IN-01: Stale unit census in verify comment

**File:** `scripts/install_dkms.sh:961`
**Issue:** Comment still says a chroot/container reports "9 false DRIFTs"; the census is 8 after Phase 37.
**Fix:** Change `9` to `8`.

### IN-02: Unguarded sysfs reads in probe mode

**File:** `tools/d330-backlight-pwm.py:50-51`
**Issue:** `open(...).read()` on brightness/max_brightness has no error handling; an unexpected read error raises a traceback, which under `set -e` aborts the whole `--probe` run now that `|| true` was removed.
**Fix:** Wrap in `try/except OSError` and fall back to `"N/A"`.

### IN-03: New guard suite is not wired into any runner

**File:** `scripts/test_noop_guards.sh:1`
**Issue:** The script is not referenced by any Makefile or CI workflow, so it only runs if invoked manually (consistent with sibling suites, which also have no runner).
**Fix:** Add it to an aggregate test entry point or CI job so the honesty invariants are actually enforced.

---

## Clean categories

- **Service retirement (focus 3):** manifest `unit`/`unit-enabled` lists, install copy, enable blocks, uninstall disable, RPM/deb packagers, and docs are all internally consistent at 8 units; no dangling service reference remains in tracked source.
- **Sensor daemon contract (focus 2):** `--monitor` loops indefinitely; `--cycles N`/`--once` terminate; `--cycles` argument validation rejects missing/negative/non-integer; SIGTERM/SIGINT exit cleanly with rc 0.
- **Shell hygiene (focus 5):** `set -euo pipefail` handling, quoting, `mktemp`/trap cleanup, and env-var passing (`D330_IIO_BASE`) are sound; no command-injection or quote defects found.

---

_Reviewed: 2026-10-08_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: deep_
