---
phase: 37-noop-tools-pwm-sensor-filter
uat: 2026-10-08
status: passed
score: 3/3 tests pass (all machine-checked)
overrides_applied: 0
note: |
  37-VERIFICATION.md: 3/3 must-haves verified, 0 gaps. No hardware needed:
  the sensor-filter liveness is proven by a real >60 s timeout run, and the PWM
  read-back delta is proven with a stub intel_reg. Suites: noop-guards 5/0,
  sensor-als dry-run green, installer-symmetry 17/0, hibernate 21/0, display 10/0,
  microsd 26/0.
---

## Tests

### 1. SC1: sensor filter does not self-terminate
expected: |
  `d330-sensor-filter --monitor` with a sensor present keeps running past 60 s
  (does not exit after the old fixed 5-iteration loop).
result: [pass] note: |
  `test_noop_guards.sh` runs a fake-IIO `timeout 62 ... --monitor` and asserts rc=124
  (killed by timeout, i.e. still alive). Code is a `while True` loop.

### 2. SC2: PWM --apply reports a real delta or is removed
expected: |
  `--apply` prints `[OK]` only after an intel_reg read-back delta; without intel_reg it
  fails honestly; the no-op boot service is gone.
result: [pass] note: |
  Stub intel_reg: value-changing -> `[OK] ... BXT_BLC_PWM_FREQ1`, rc 0; no-delta -> `[FAIL]`,
  rc 1. Empty-PATH run -> `[SKIP] intel_reg not available`, rc 2, no `[OK]`. Parser takes the
  value after the last `:`. `lenovo-d330-backlight-pwm.service` deleted; enabled parity 8.

### 3. Core goal: no false success anywhere
expected: |
  No tool or harness prints success for a write that did not happen.
result: [pass] note: |
  `test_display_ergonomics.sh --test-pwm` propagates the tool rc (non-zero without intel_reg,
  no "verified successfully"); `test_sensor_als.sh --dry-run` asserts `rotation decision` and
  `ALS: Raw=`; both legacy `|| true` masks removed; noop-guards suite wired into the aggregate runner.
