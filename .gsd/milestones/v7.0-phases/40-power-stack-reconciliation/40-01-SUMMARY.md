---
phase: 40
plan: 01
subsystem: power-management
tags: [tlp, udev, runtime-pm, intel-pstate, rapl, thermald, fastboot, watchdog]
requires:
  - phase: 39
    provides: static guard-suite pattern wired into the aggregate runner
provides:
  - AC-aware CPU performance cap that is re-applied on power-source change
  - single runtime-PM owner (TLP) with udev scoped to eMMC host + dock
  - power-stack static guard suite scripts/test_power_stack.sh
affects:
  - patches/power
  - patches/fastboot
  - patches/thermal
  - packaging/debian
tech-stack:
  added: []
  patterns:
    - one-writer-per-knob reconciliation
    - static PASS/FAIL guard suite wired into the aggregate runner
key-files:
  created:
    - scripts/test_power_stack.sh
  modified:
    - tools/lenovo-d330-power-tune.sh
    - patches/power/etc/udev/rules.d/95-lenovo-d330-power.rules
    - patches/power/etc/tlp.d/50-lenovo-d330.conf
    - patches/fastboot/etc/default/grub.d/52-lenovo-d330-fastboot.cfg
    - tools/d330-fastboot-tune.sh
    - CHANGES_AUDIT.md
    - scripts/test_boot_speed.sh
    - patches/thermal/etc/thermald/thermal-conf.xml
    - tools/d330-thermal-tune.sh
    - packaging/debian/control
    - scripts/test_storage_cellular.sh
decisions:
  - key: AC re-run mechanism
    choice: SUBSYSTEM=="power_supply" ACTION=="change" udev rule restarting lenovo-d330-power.service
    why: lifts the AC perf cap without a reboot, and keeps the writer count at one
  - key: runtime-PM ownership split
    choice: TLP owns PCI/USB/I2C/sound; udev owns eMMC host (mmc) + dock (17ef) only
    why: two writers on the same power/control knob silently discard TLP's AC/DC policy
  - key: sub-minimum GPU frequency
    choice: drop INTEL_GPU_MIN_FREQ_ON_AC/BAT=100 rather than clamp
    why: 100 MHz is below the Gemini Lake GT minimum (~300 MHz), so the write is rejected every AC event
  - key: thermald precedence
    choice: thermald is the runtime owner; d330-thermal-tune.sh is the fallback when thermald is absent
    why: avoids two writers on the RAPL PL1/PL2 knobs
metrics:
  duration: ~2m
  completed: 2026-10-08
status: complete
---

# Phase 40 Plan 01: Power Stack Reconciliation Summary

Reconciled the D330 power stack to one writer per knob: the CPU performance cap is
now AC-aware and re-applied on power-source change, TLP is the sole runtime-PM
owner with udev scoped to the controllers it does not touch, the rejected
sub-minimum GPU frequency is gone, `nowatchdog` is replaced with
`softlockup_panic=1`, and the thermald/RAPL precedence and numeric handling are
explicit. A new static guard suite (`scripts/test_power_stack.sh`, 12 cases) is
wired into the aggregate runner.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | AC-aware CPU perf cap + re-run on AC change | `b418cc9` | tools/lenovo-d330-power-tune.sh, patches/power/etc/udev/rules.d/95-lenovo-d330-power.rules |
| 2 | Single runtime-PM owner (TLP) + scoped udev | `81b9326` | patches/power/etc/tlp.d/50-lenovo-d330.conf |
| 3 | TLP GPU frequency fix | `7b158aa` | patches/power/etc/tlp.d/50-lenovo-d330.conf |
| 4 | fastboot nowatchdog + claim correction | `cb47836` | patches/fastboot/etc/default/grub.d/52-lenovo-d330-fastboot.cfg, tools/d330-fastboot-tune.sh, CHANGES_AUDIT.md, scripts/test_boot_speed.sh |
| 5 | thermald type + precedence + numeric guard + Recommends | `e2dd16f` | patches/thermal/etc/thermald/thermal-conf.xml, tools/d330-thermal-tune.sh, packaging/debian/control |
| 6 | power-stack static guard suite + aggregate wiring | `6572825` | scripts/test_power_stack.sh (new), scripts/test_storage_cellular.sh |

## What Changed

- **Task 1 — AC-aware cap.** `tools/lenovo-d330-power-tune.sh` reads the
  `power_supply` AC state and writes `intel_pstate/max_perf_pct` from a branch
  (100 on AC, 75 on battery); it is idempotent. Removed the script's broad
  `power/control` runtime-PM loop, which raced TLP. Added a
  `SUBSYSTEM=="power_supply"` `ACTION=="change"` udev rule that restarts
  `lenovo-d330-power.service` so plugging AC lifts the cap without a reboot.
- **Task 2 — single runtime-PM owner.** `95-lenovo-d330-power.rules` dropped the
  broad per-class `power/control` rules for PCI/PCIe, USB, I2C and the audio DSP
  (TLP's turf via `RUNTIME_PM_ON_AC`/`ON_BAT`). It now keeps only the eMMC host
  (`mmc`) and the dock (`17ef:*`, which TLP's `USB_DENYLIST` excludes), two
  `power/control` lines total. `50-lenovo-d330.conf` documents the ownership
  split.
- **Task 3 — GPU freq.** Dropped `INTEL_GPU_MIN_FREQ_ON_AC/BAT=100` (below the
  GLK GT minimum, rejected on every AC event). Kept `MAX 650` / `BOOST 700` /
  `BAT 500` with a source comment (Intel ARK / `gt_max_freq_mhz`).
- **Task 4 — watchdog.** `52-lenovo-d330-fastboot.cfg` no longer passes
  `nowatchdog`; it now passes `softlockup_panic=1` and keeps
  `no_timer_check quiet loglevel=3 rd.systemd.show_status=auto`. `CHANGES_AUDIT.md`
  §7.7 no longer credits a "12 seconds from watchdog" saving; the win is
  attributed to `NetworkManager-wait-online` masking and left honestly
  unquantified.
- **Task 5 — thermald/RAPL.** `thermal-conf.xml` zone `<Type>` is now
  `x86_pkg_temp` (matches the real sysfs zone). `d330-thermal-tune.sh` guards
  `pl1`/`pl2` with `[[ "$pl1" =~ ^[0-9]+$ ]]` before `$((pl1 / 1000000))`, and
  documents itself as the fallback when thermald is absent. `packaging/debian/control`
  Recommends `thermald`.
- **Task 6 — guard suite.** New `scripts/test_power_stack.sh` (12 static cases,
  PASS/FAIL, non-zero on failure) asserting the AC-aware cap, the `power_supply`
  re-run rule, the scoped udev runtime-PM rule, TLP ownership, no rejected GPU
  freq, no `nowatchdog` + `softlockup_panic=1`, the thermal numeric guard, the
  `x86_pkg_temp` zone type and the debian Recommends. Wired into
  `scripts/test_storage_cellular.sh` aggregate + `bash -n` loop; chmod +x applied.

## Verification Results

| Gate | Result |
|------|--------|
| `bash scripts/test_power_stack.sh` | passed=12 failed=0, rc 0 |
| `bash scripts/test_storage_cellular.sh --dry-run` | rc 0 (includes power-stack 12/0) |
| `bash -n` touched scripts | OK (6/6) |
| `test_installer_symmetry.sh` | 17/0 |
| `test_hibernate_guards.sh` | 21/0 |
| `test_display_fix_guards.sh` | 10/0 |
| `test_microsd_guards.sh` | 26/0 |
| `test_noop_guards.sh` | 5/0 |
| `test_udev_hwdb_match.sh` | 10/0 |
| `test_audio_dsp.sh --dry-run` | 17/0 |

Inline `bash -c` verifies were exercised for each task and passed; the one
command-substitution quirk under the PowerShell harness (`$(...)` is expanded
before bash) is why task verifies were re-run through a temp `.sh`, where they
behave correctly.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Removed the script's broad runtime-PM writer**
- **Found during:** Task 1
- **Issue:** `tools/lenovo-d330-power-tune.sh` wrote `power/control=auto` across
  all PCI devices and `mmcblk0`, making it a second runtime-PM writer alongside
  TLP — the exact knob conflict this phase reconciles.
- **Fix:** Dropped section 5; runtime PM is now owned by TLP (PCI/USB/I2C/sound)
  and the scoped udev rule (eMMC host, dock). Documented in the script header.
- **Files modified:** tools/lenovo-d330-power-tune.sh
- **Commit:** `b418cc9`

**2. [Rule 1 - Bug] Stale `nowatchdog` echo in test_boot_speed.sh**
- **Found during:** Task 4
- **Issue:** `scripts/test_boot_speed.sh --dry-run` printed
  `Kernel cmdline: nowatchdog ...`, which removing the parameter made a lie.
- **Fix:** Echo now reads `softlockup_panic=1 no_timer_check quiet loglevel=3`.
- **Files modified:** scripts/test_boot_speed.sh
- **Commit:** `cb47836`

### Scope notes

- No deletions expected or made.
- `docs/research/EMMC_FASTBOOT_TUNING.md` still describes the old
  watchdog-disabling rationale. It is a historical research artifact, not shipped
  config, and was out of the plan's file scope; left untouched.

## Deferred / Hardware

- SC1/SC2/SC3 are hardware/boot-bound and remain overridable:
  `tlp-stat -s` vs `/sys/class/powercap` agreement after AC hot-plug, a clean
  journal across a full AC/battery cycle, and a boot bench (`systemd-analyze
  critical-chain`). Not executable in this (Windows) environment.
- Executable bit on `scripts/test_power_stack.sh` is present in the working tree;
  the repo has `core.fileMode=false` and existing scripts are tracked as 100644,
  so no mode change is recorded (consistent with the rest of `scripts/`).

## Self-Check: PASSED

- Created files exist: `scripts/test_power_stack.sh` (verified by `bash -n` and a
  green run).
- Commits exist in history: `b418cc9`, `81b9326`, `7b158aa`, `cb47836`,
  `e2dd16f`, `6572825`.
