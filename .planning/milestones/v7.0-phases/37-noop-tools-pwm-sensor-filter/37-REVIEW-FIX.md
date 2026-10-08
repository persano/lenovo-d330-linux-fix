---
phase: 37-noop-tools-pwm-sensor-filter
fixed_at: 2026-10-08T17:11:50+00:00
review_path: .planning/phases/37-noop-tools-pwm-sensor-filter/37-REVIEW.md
iteration: 1
findings_in_scope: 12
fixed: 12
skipped: 0
status: all_fixed
---

# Phase 37: Code Review Fix Report

**Fixed at:** 2026-10-08T17:11:50+00:00
**Source review:** `.planning/phases/37-noop-tools-pwm-sensor-filter/37-REVIEW.md`
**Iteration:** 1
**Isolation:** all edits and commits were made in the **main checkout** (WSL2 bash over `/mnt/d/...`), not a worktree; untracked phase artifacts live only in the main tree.

**Summary:**
- Findings in scope: 12
- Fixed: 12
- Skipped: 0

## Finding → Fix → Commit

| Finding | Severity | Files modified | Commit |
|---------|----------|----------------|--------|
| CR-01 | Critical | `tools/d330-backlight-pwm.py` | `ded6148` |
| WR-01 | Warning | `tools/d330-backlight-pwm.py` | `ded6148` |
| WR-07 | Warning | `tools/d330-backlight-pwm.py` | `ded6148` |
| IN-02 | Info | `tools/d330-backlight-pwm.py` | `ded6148` |
| WR-02 | Warning | `scripts/test_sensor_als.sh` | `a40c3d5` |
| WR-04 | Warning | `scripts/test_sensor_als.sh` | `a40c3d5` |
| WR-05 | Warning | `patches/sensors/etc/systemd/system/d330-sensor-filter.service` | `a74413c` |
| WR-03 | Warning | `scripts/test_noop_guards.sh` | `73182ce` |
| WR-06 | Warning | `scripts/test_noop_guards.sh` | `73182ce` |
| WR-08 | Warning | `scripts/install_dkms.sh` | `070a7f2` |
| IN-01 | Info | `scripts/install_dkms.sh` | `070a7f2` |
| IN-03 | Info | `scripts/test_storage_cellular.sh` | `ac6c1e1` |

## Fixed Issues

### CR-01: `read_register()` parsed the register address, not its value

**Files modified:** `tools/d330-backlight-pwm.py`
**Commit:** `ded6148`
**Applied fix:** Added `_VAL_RE = re.compile(r"0x([0-9a-fA-F]+)")` and rewrote `read_register()` to parse only the text **after the last `:`** of `intel_reg`'s `name (0xADDR): 0xVALUE` output (falling back to the whole line only when there is no `:` at all). It now returns `None` whenever no hex value parses, so `apply_pwm_tuning()` refuses to write (`[FAIL]` + non-zero) and a target can never be derived from the address.
**Verification:** the new no-op guard stub (WR-06) feeds the real `name (0xADDR): 0xVALUE` format and asserts the `[OK]`/`[FAIL]` delta behavior end-to-end — the exact failure this finding described.
**Requires human verification:** the finding is a logic correction (parser semantics); the delta harness proves the parse+write+verify path, but confirm on the target hardware that `intel_reg read 0xC8254` emits the assumed format.

### WR-01 + WR-07: PWM register table pointed at the duty register; field comment/width wrong

**Files modified:** `tools/d330-backlight-pwm.py`
**Commit:** `ded6148`
**Applied fix:** Dropped the bogus `("BXT_BLC_PWM_FREQ1", 0xC8258)` entry — `0xC8258` is `_BXT_BLC_PWM_DUTY1` (brightness). The table now targets a single register, `("BXT_BLC_PWM_FREQ1", 0xC8254)`, scoped explicitly to the Gemini-Lake/BXT layout where the divider is the low 16-bit field. Comments now cite the kernel `intel_backlight_regs.h` names and state that the low-16-bit divider field applies to BXT FREQ1 (not the PCH `CTL2` bits 31:17 layout).
**Verification:** `python3 -c "import ast; ast.parse(...)"` OK; delta stub proves the write/read path.

### WR-02 + WR-04: sensor dry-run never exercised the ALS fallback and asserted nothing

**Files modified:** `scripts/test_sensor_als.sh`
**Commit:** `a40c3d5`
**Applied fix:** The fake tree now creates two devices: `iio:device0` (`bosc0200`, accel only) and `iio:device1` (`acpi0008`, `in_illuminance_input` only), so `find_iio_devices()` sets `devs["als"]` and the illuminance fallback runs. Output is captured and asserted with `grep -q 'rotation decision'` and `grep -q 'ALS: Raw='`; either miss is a hard `[FAIL]` + non-zero.
**Verification:** `bash scripts/test_sensor_als.sh --dry-run` → rc 0, prints both `rotation decision` and `ALS: Raw=200.0 lux -> Smoothed=...`.

### WR-05: sensor unit `ExecStart` could not resolve under the repo installer

**Files modified:** `patches/sensors/etc/systemd/system/d330-sensor-filter.service`
**Commit:** `a74413c`
**Applied fix:** `ExecStart=/usr/local/bin/d330-sensor-filter --monitor` now matches the installed name (manifest `:132`, `cp` at `:474-476`, uninstall `rm` at `:838`). Re-checked install/manifest/uninstall/unit all agree on the suffix-free name.

### WR-03 + WR-06: non-hermetic PATH guard, and untested read-back delta

**Files modified:** `scripts/test_noop_guards.sh`
**Commit:** `73182ce`
**Applied fix:**
- (b) now uses a fresh empty `mktemp -d` dir as the **sole** `PATH` (`python3` invoked by absolute path), so no real `intel_reg` can ever be found/run.
- (d) adds a stub `intel_reg` (first on `PATH`) that emits the real `name (0xADDR): 0xVALUE` format. It stores the written value unless `D330_STUB_IGNORE_WRITE=1`. Case `(d1)` asserts `[OK]` + rc 0 on a delta; `(d2)` asserts `[FAIL]` + non-zero when the register does not change. This exercises the CR-01 parser and the M4 delta logic that previously shipped untested.
**Verification:** `bash scripts/test_noop_guards.sh` → `passed=5 failed=0` (includes `pwm-readback-delta-ok rc=0` and `pwm-readback-no-delta-fail rc=1`).
**Requires human verification (guard-a reconciliation):** WR-08's exact-name delete necessarily names the retired unit in the installer, which made the old bare-substring guard (a) fail. Guard (a) now matches only a **deployed manifest path** (`/etc/systemd/system/lenovo-d330-backlight-pwm.service` followed by whitespace/EOL), so the `find ... -name 'lenovo-d330-backlight-pwm.service' -delete` migration line (a removal, not a deploy) no longer trips it, while a resurrected deploy reference still fails. This is a deliberate condition change — review it.

### WR-08: uninstall retirement used a wildcard delete over `/etc/systemd/system`

**Files modified:** `scripts/install_dkms.sh`
**Commit:** `070a7f2`
**Applied fix:** `find /etc/systemd/system -maxdepth 2 -name '*backlight-pwm*.service' -delete` → `-name 'lenovo-d330-backlight-pwm.service' -delete`, so only the installer-owned basename can match.

### IN-01: stale DRIFT census in verify comment

**Files modified:** `scripts/install_dkms.sh`
**Commit:** `070a7f2`
**Applied fix:** Comment changed from "9 false DRIFTs" to "8 false DRIFTs".

### IN-02: unguarded sysfs reads in `--probe`

**Files modified:** `tools/d330-backlight-pwm.py`
**Commit:** `ded6148`
**Applied fix:** Added `_read_sysfs()` (wraps `open().read()` in `try/except OSError → "N/A"`) and used it for `brightness`/`max_brightness`, so a read error cannot abort `--probe` under `set -e`.

### IN-03: no-op guard suite not wired into any runner

**Files modified:** `scripts/test_storage_cellular.sh`
**Commit:** `ac6c1e1`
**Applied fix:** The aggregate `scripts/test_storage_cellular.sh --dry-run` (which already invokes `test_microsd_guards.sh`, `test_display_fix_guards.sh`, `test_hibernate_guards.sh`, `test_installer_symmetry.sh`) now also `bash -n`-checks and invokes `scripts/test_noop_guards.sh`.

## Verification / Gates

Run from the repo root under WSL2. Raw gate lines:

```
GATE bash-n rc=0
GATE sensor-dry-run rc=0
GATE none-path-apply rc=127
GATE test_installer_symmetry rc=0   (passed=17 failed=0)
GATE test_hibernate_guards rc=0     (passed=21 failed=0)
GATE test_display_fix_guards rc=0   (passed=10 failed=0)
GATE test_microsd_guards rc=0       (passed=26 failed=0)
GATE test_noop_guards rc=0          (passed=5 failed=0)
```

Notes:
- `bash -n scripts/install_dkms.sh scripts/test_noop_guards.sh scripts/test_sensor_als.sh scripts/test_display_ergonomics.sh` → rc 0.
- The literal gate `bash -c 'PATH=/nonexistent python3 tools/d330-backlight-pwm.py --apply; echo rc=$?'` returns `rc=127` with `python3: command not found` on this WSL host: `PATH=/nonexistent` removes `python3` itself, so the tool never runs (no `[OK]`, non-zero — the honesty intent holds). The equivalent that actually reaches the tool — empty temp `PATH` with `/usr/bin/python3` called by absolute path — prints `[SKIP] intel_reg not available; no PWM register written.` and returns **rc 2**, matching the guard's `pwm-no-false-success (rc=2)` case.
- `scripts/test_display_ergonomics.sh --test-pwm` is intentionally non-zero on hosts without `intel_reg` and was not part of the required green set.

---

_Fixed: 2026-10-08T17:11:50+00:00_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_
