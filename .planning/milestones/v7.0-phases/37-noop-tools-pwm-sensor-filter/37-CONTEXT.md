# Phase 37: No-Op Tools Made Real or Removed - PWM & Sensor Filter - Context

**Gathered:** 2026-10-08
**Status:** Ready for planning (auto-accepted; slim pipeline)

<domain>
## Phase Boundary

Audit M4/M5/M17: stop reporting success for operations that perform no write. Scope: `tools/d330-backlight-pwm.py`, `tools/d330-sensor-filter.py`, `patches/display_ergonomics/etc/systemd/system/lenovo-d330-backlight-pwm.service`, `patches/sensors/etc/systemd/system/d330-sensor-filter.service`, `scripts/install_dkms.sh`, `scripts/test_display_ergonomics.sh`, `scripts/test_sensor_als.sh`, packaging, `CHANGES_AUDIT.md` §4.5/§5.3.
</domain>

<decisions>
## Implementation Decisions

### PWM (M4) - sanctioned removal path
- Delete `patches/display_ergonomics/etc/systemd/system/lenovo-d330-backlight-pwm.service` (a `Type=oneshot` boot unit that ran a no-op and reported success). Remove it from the manifest unit/`unit-enabled` lists, install copy, `systemctl enable`, uninstall (enabled units 9 -> 8), and the 3 packagers.
- Rewrite `apply_pwm_tuning()` to be honest: only attempt a REAL write via `intel_reg` (read `BLC_PWM_PCH_CTL2`/`BXT_BLC_PWM_FREQ1` before, compute the divider for the target, write, read back); print `[OK] ... <before> -> <after>` ONLY when the read-back differs. If `intel_reg` is absent or the write cannot be verified, print an explicit `[SKIP]`/`[FAIL]` and exit non-zero. No unconditional `[OK]`.
- Correct `CHANGES_AUDIT.md` §4.5 to state the boot service was removed and the utility only programs a real register when `intel_reg` is available.

### Sensor filter (M5)
- Replace the finite `for _ in range(5)` loop (exits ~1 s, unit dies under `Restart=on-failure`) with a `while True` loop; handle SIGTERM/SIGINT and exit 0. Add a `--cycles N`/`--once` mode for tests.
- Implement the accelerometer 15-degree deadband + hysteresis claimed in CHANGES_AUDIT §5.3: read `in_accel_{x,y,z}_raw`, compute tilt, emit a rotation decision only when the deadband is crossed and held for the debounce interval; log decisions. Add a `D330_IIO_BASE` env seam so tests can point at fake sysfs.
- `in_illuminance_raw` fallback to `in_illuminance_input` when the raw node is absent.

### Tests
- `scripts/test_display_ergonomics.sh`: remove `|| true` + unconditional success; `--test-pwm` must propagate the tool's rc (a no-op/failed apply must be non-zero). Dry-run must not claim verified when nothing was verified.
- `scripts/test_sensor_als.sh`: drive `d330-sensor-filter.py` against a fake IIO tree (`D330_IIO_BASE`) with `--cycles`, assert the deadband/hysteresis behavior and the illuminance fallback, and fail on non-zero. No `|| true` masking.
- Add `scripts/test_noop_guards.sh` (machine-checkable honesty harness) asserting: the PWM boot service is gone from tree+manifest; `--apply` never exits 0 without a verified delta (run against a PATH without intel_reg); the sensor filter loops >1 cycle under `--cycles 3`.

### the agent's Discretion
- Exact intel_reg register names/opcodes, WARN wording, whether `--once` or `--cycles` is the test hook.
</decisions>

<code_context>
## Existing Code Insights

- `tools/d330-backlight-pwm.py:35-43` `apply_pwm_tuning()` only checks the sysfs dir exists and prints `[OK]` (no write). `check_flicker_status` is read-only.
- `tools/d330-sensor-filter.py:54` finite `for _ in range(5): ... time.sleep(0.2)` (exits ~1 s, rc 0). `:56` reads only `in_illuminance_raw`. `find_iio_devices():17-32` matches accel/als by name. No accel read/decision anywhere.
- `patches/sensors/.../d330-sensor-filter.service`: `Type=simple`, `Restart=on-failure`, `ExecStart=... --monitor`.
- `patches/display_ergonomics/.../lenovo-d330-backlight-pwm.service`: `Type=oneshot`, `ExecStart=... --apply`, `RemainAfterExit=yes`.
- Manifest: `:143` `/etc/systemd/system/lenovo-d330-backlight-pwm.service unit`, `:158` `... unit-enabled`; sensor `:144`,`:159`. Install copy `:516-519`, enable `:544-545`, uninstall `:878-879`, removed-check `:909-910`.
- `scripts/test_display_ergonomics.sh:67,89` and `scripts/test_sensor_als.sh:55-56`: `|| true` + unconditional "verified".
- CHANGES_AUDIT `§4.5` (:160-170) PWM claims; `§5.3` (:197-203) accel 15-deg/hysteresis + ALS claims.
</code_context>

<canonical_refs>
## Canonical Refs
- `.planning/ROADMAP.md` `### Phase 37:` (goal, SC1 sensor-filter active >60 s, SC2 `--apply` verifiable delta or removed; components; Audit M4/M5/M17)
- `.planning/phases/36-desktop-session-wiring/36-01-PLAN.md` (manifest/`--verify`/suite patterns to reuse)
</canonical_refs>

<deferred>
## Deferred Ideas
- Actual backlight PWM reprogramming as a shipped boot service (needs intel_reg + verified register map on VLV/GML); documented instead.
- iio-sensor-proxy D-Bus integration for rotation (out of scope).
</deferred>
