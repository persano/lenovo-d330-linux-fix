# Phase 41: Test Harness Trustworthiness - Context

**Gathered:** 2026-10-08 | **Status:** Ready (auto-accepted; slim pipeline)

<domain>
Audit M12/N8: a failing check must be able to fail the run. Today most `test_*.sh` exit 0 no matter what and their `--dry-run` modes validate nothing. Scope: the ~27 `scripts/test_*.sh`, `scripts/build_live_iso.sh`, plus a new `scripts/test_harness_trust.sh` meta-guard. (Several scripts were already made honest in phases 36–40: `test_sensor_als.sh`, `test_tray_applet.sh`, `test_display_ergonomics.sh`, `test_mic_rnnoise.sh`, `test_wireless_coex.sh`, `test_resume_loop.sh` arithmetic.)
</domain>

<decisions>
- **Failure counter**: every test script must track failures and `exit` non-zero when any check fails; remove `cmd || true` followed by unconditional `log_ok`.
- **No live mutation without `--apply`**: the four scripts that mutate the system (`test_thermals.sh` RAPL, `test_boot_speed.sh` mask wait-online, `test_battery_power.sh` sysfs writes, `test_memory_storage.sh` `fstrim -av`) must only do so behind an explicit `--apply`.
- **Parser/arith fixes**: `((passed++))` under `set -e` -> `passed=$((passed+1))`; consume documented arg values (`--stress N`, `--cycle-test N`); call real daemon flags (`--dry-run --simulate-*`).
- **No false OK**: don't print `[OK]` for a path that does not exist (the `fcc-unlock.d/8086:7360` case); a missing subject must fail.
- **CWD anchoring**: adopt the `SCRIPT_DIR` pattern (`SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`) so scripts resolve `tools/`/`patches/` regardless of CWD; default log output to `/tmp` (not `docs/dumps/`).
- **build_live_iso.sh --dry-run**: must actually check xorriso/ISO/paths and fail if missing, not echo a hardcoded manifest; `test_iso_integrity.sh` must inherit that.
- **SC1 meta-test**: `scripts/test_harness_trust.sh` mutates at least 5 representative `test_*.sh` subjects (break the config/module they check) and asserts each script exits non-zero, restoring after.
- **SC2 static guard**: assert no `test_*.sh` performs a system mutation outside `--apply`.
- **the agent's Discretion**: exact failure-counter style, which 5+ scripts the meta-test mutates, SCRIPT_DIR helper duplication vs shared source.
</decisions>

<code_context>
- `test_resume_loop.sh:83,110,113` `((failed++))`/`((passed++))` under `set -e` abort cycle 1; logs into `docs/dumps/` (`:19,55`).
- `test_tablet_osk.sh:81,84` calls nonexistent `--test-laptop`/`--test-tablet`.
- `test_battery_power.sh:28,41`/`test_dock_switching.sh:30,45` `--stress N`/`--cycle-test N` unconsumed -> `*)` exit 1.
- Live mutations: `test_thermals.sh:66`, `test_boot_speed.sh:64`, `test_battery_power.sh:53`, `test_memory_storage.sh:128`.
- Always-green pattern in: `test_auto_hibernate.sh:55-56`, `test_hardware_controls.sh:53-54`, `test_iso_integrity.sh:76,84`, `test_cameras.sh:115-120`, `test_audio_profiles.sh:88-109`, `test_distro_packaging.sh:69-84`, `test_ci_workflows.sh:72-74`, `test_oom_protection.sh:62`, `test_touch_calibration.sh:93-141`, `test_acpi_cleanliness.sh:85-86` (the 36–40 trio already fixed).
- `test_distro_packaging.sh:20-40`/`test_ci_workflows.sh:26` parse MODE and never read it. `test_hardware_controls.sh:62-67` `--test-toggle` only status. `test_storage_cellular.sh:54,77-79` false `[OK]` + `--test-microsd` alias.
- `scripts/build_live_iso.sh:62-76` + `test_iso_integrity.sh:54` no-op dry-run.
- SC1/SC2 machine-checkable; a live on-device mutation test is not needed.
</code_context>

<canonical_refs>
- `.planning/ROADMAP.md` `### Phase 41:` (goal, SC1-2, full component list with file:line, Audit M12/N8)
- `.planning/phases/37-noop-tools-pwm-sensor-filter/37-01-PLAN.md` and `38/39/40` plans (honesty + guard-suite patterns)
</canonical_refs>

<deferred>
- Running the full suite on the D330; CI integration beyond static guards.
</deferred>
