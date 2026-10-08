# Phase 37: No-Op Tools Made Real or Removed - Research

**Researched:** 2026-10-08 | **Mode:** inline (slim pipeline)

## Findings
- **R1 (M4) PWM no-op**: `tools/d330-backlight-pwm.py:apply_pwm_tuning()` prints `[OK] PWM anti-flicker frequency profile active.` whenever `/sys/class/backlight/<driver>` exists; it never writes any PWM register. `lenovo-d330-backlight-pwm.service` (oneshot, `RemainAfterExit=yes`) therefore reports a successful boot-time apply that never happened. Sanctioned fix per ROADMAP component: delete the service + correct CHANGES_AUDIT §4.5; additionally make the utility honest (only `[OK]` on a verified intel_reg read-back delta).
- **R2 (M5) sensor-filter dies after ~1s**: `for _ in range(5): time.sleep(0.2)` then `return`; `monitor_sensors()` returns, process exits 0, so `Restart=on-failure` never restarts and the unit is permanently dead. SC1 requires `active (running) > 60 s` -> `while True`.
- **R3 (M5) accel claim unrealized**: no `in_accel_*` read anywhere; `§5.3` claims 15-degree hysteresis + debounce. Implement with a `D330_IIO_BASE` seam + `--cycles/--once` test hook.
- **R4 (M5) ALS node**: only `in_illuminance_raw`; many ALS drivers expose `in_illuminance_input`. Add fallback.
- **R5 tests lie**: `test_display_ergonomics.sh:67,89` and `test_sensor_als.sh:55-56` use `|| true`/no-op and print "verified successfully" unconditionally -> they cannot fail. Rework to assert real state and propagate rc.
- **R6 manifest**: removing the PWM service touches manifest `:143`/`:158`, install `:516-517`, enable `:544`, uninstall `:878`, removed-check `:909`, and the 3 packagers; enabled-unit parity drops 9 -> 8. The phase-35/36 symmetry suite + `--verify` kinds must stay consistent.

## Recommended approach
Delete the PWM oneshot service (removal is explicitly sanctioned), make both tools truthful (real read-back delta or explicit skip/fail; infinite loop + real accel decision), and replace the lying test harnesses with machine-checkable ones (fake IIO via `D330_IIO_BASE`, no-`intel_reg` PATH case).
