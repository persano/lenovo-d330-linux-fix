---
phase: 39-udev-hwdb-wireless-correctness
plan: "01"
subsystem: infra
tags: [udev, hwdb, modprobe, rtw88, rtl8821ce, dmi, xrandr, d330]

requires:
  - phase: 29-wireless-coexistence
    provides: wireless modprobe conf + wifi resume hook (corrected here)
  - phase: 34-display-resume-fix
    provides: d330-refresh-screen.sh (corrected here)

provides:
  - "corrected Realtek-only wireless modprobe conf (no Intel options)"
  - "hwdb entries matching on the space-free DMI product code (pn82H0 / pn81MD / pn81H3)"
  - "case-insensitive sensor udev globs; dead/no-op udev properties removed"
  - "wifi resume hook that only bounces a wedged link"
  - "rotation-preserving d330-refresh-screen.sh with the no-op DPMS branch dropped"
  - "SC3: test_wireless_coex.sh fails on a wrong module name; test_udev_hwdb_match.sh static guard suite"

affects: [40, 41, 42]

actuals:
  tokens: 17667
  tasks: 5
  commits: 5

tech-stack:
  added: []
  patterns:
    - "Static udev/hwdb match-string guard suite (PASS/FAIL, non-zero on failure)"
    - "Mutation-proven module-name assertion (SC3) for the wireless conf"

key-files:
  created:
    - scripts/test_udev_hwdb_match.sh
  modified:
    - patches/wireless/etc/modprobe.d/lenovo-d330-wireless.conf
    - patches/wireless/etc/systemd/system-sleep/lenovo-d330-wifi-resume.sh
    - patches/dkms/etc/udev/hwdb.d/61-lenovo-d330-sensor.hwdb
    - patches/touchscreen/etc/udev/hwdb.d/62-lenovo-d330-touchscreen.hwdb
    - patches/sensors/etc/udev/rules.d/87-lenovo-d330-sensors.rules
    - patches/hardware_controls/etc/udev/rules.d/88-lenovo-d330-hardware.rules
    - patches/audio_dsp/etc/udev/rules.d/91-lenovo-d330-headset-jack.rules
    - patches/touchscreen/etc/udev/rules.d/90-lenovo-d330-touchscreen.rules
    - tools/d330-refresh-screen.sh
    - scripts/test_wireless_coex.sh
    - scripts/test_storage_cellular.sh
    - CHANGES_AUDIT.md
    - patches/hardware_controls/README.md

key-decisions:
  - "Emit both `rtl8821ce` and `rtw88_8821ce` module spellings; keep only real in-tree rtw88 params (disable_lps_deep, disable_aspm); drop fwlps/ips"
  - "Remove all Intel iwlwifi/iwlmvm options: the D330 has no Intel wireless"
  - "Match hwdb/udev on DMI pn82H0 (IGL) and pn81MD/pn81H3 (IGM); the pvr product string carries a space and never matched"
  - "udev cannot chmod sysfs platform attrs: drop MODE/GROUP and document root/pkexec requirement"
  - "Wi-Fi resume only bounces a wedged link (carrier check), preserving active sessions"
  - "d330-refresh-screen preserves the current xrandr rotation and drops the no-op /sys/class/drm dpms cycle with an honest log"

patterns-established:
  - "Guard suites wire into scripts/test_storage_cellular.sh --dry-run and its bash -n loop"
  - "SC3 proven by mutation: flip the module name, expect the test to fail, restore via git checkout"

requirements-completed: []

coverage:
  - id: D1
    description: "Wireless modprobe conf names only Realtek modules (rtl8821ce + rtw88_8821ce), no Intel options, no unconfirmed params"
    verification:
      - kind: unit
        ref: "bash -c 'grep -q \"options rtw88_8821ce\" ... && ! grep -qE \"iwlwifi|iwlmvm\" ... && echo WIRELESS-CONF-OK'"
        status: pass
    human_judgment: false
  - id: D2
    description: "hwdb sensor/touchscreen entries match on the space-free DMI product code (pn82H0, pn81MD, pn81H3)"
    verification:
      - kind: unit
        ref: "scripts/test_udev_hwdb_match.sh (pn82H0 assert; no pvrLenovoideapad)"
        status: pass
    human_judgment: false
  - id: D3
    description: "udev rules use case-insensitive sensor globs; MODE/GROUP, SOUND_INITIALIZED and WL_OUTPUT removed"
    verification:
      - kind: unit
        ref: "scripts/test_udev_hwdb_match.sh (globs, no MODE=/GROUP=, no dead properties)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Wi-Fi resume hook only bounces a wedged link; refresh-screen preserves rotation and drops the no-op DPMS branch"
    verification:
      - kind: unit
        ref: "bash -n both scripts; ! grep basename \"$iface\"; grep carrier"
        status: pass
    human_judgment: false
  - id: D5
    description: "SC3: test_wireless_coex.sh exits non-zero on a wrong module name (mutation-proven)"
    verification:
      - kind: unit
        ref: "SC3 mutation run: sed rtw88_8821ce->WRONGMOD_8821ce; --dry-run must fail; restore; SC3-OK"
        status: pass
    human_judgment: false
  - id: D6
    description: "SC1 (udevadm test on hardware) and SC2 (modprobe -s rtw88_8821ce) on the real D330"
    verification: []
    human_judgment: true
    rationale: "No D330 hardware and no rtw88 module in this environment; host-bound override, re-run at sign-off"

duration: 12min
completed: 2026-10-08
status: complete
---

# Phase 39 Plan 01: udev / hwdb / Wireless Match Correctness Summary

**Wireless conf corrected to Realtek-only, hwdb/udev match strings fixed to real DMI/HID forms, no-op udev properties removed, and a mutation-proven SC3 test suite added.**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-10-08T18:06:57Z
- **Completed:** 2026-10-08T18:16:10Z
- **Tasks:** 5/5
- **Files modified:** 14 (1 created)

## Accomplishments

- `lenovo-d330-wireless.conf` now emits both `options rtl8821ce ant_sel=2` and `options rtw88_8821ce ant_sel=2`, keeps only real in-tree rtw88 params, and drops the dead Intel block; CHANGES_AUDIT §7.6 corrected.
- hwdb entries (61/62) now match the space-free DMI product code (`pn82H0`, `pn81MD`, `pn81H3`); no `pvrLenovoideapad*` pattern remains anywhere in `patches/`.
- Sensor udev globs made case-insensitive (`[Bb][Oo][Ss][Cc]0200` / `[Aa][Cc][Pp][Ii]0008`); the sysfs no-op `MODE`/`GROUP` and the dead `SOUND_INITIALIZED` / `WL_OUTPUT` properties removed, with the root/pkexec requirement documented.
- Wi-Fi resume only bounces a wedged link (carrier check); refresh-screen preserves the current rotation and no longer fakes a kernel DPMS cycle.
- New `scripts/test_udev_hwdb_match.sh` (9/0) and a mutation-proven SC3 module-name assertion in `test_wireless_coex.sh`; both wired into the aggregate runner and its `bash -n` loop.

## Task Commits

Each task was committed atomically (via `gsd-tools query commit`):

1. **Task 1: Wireless modprobe conf (module names + Intel removal)** - `903b5f4` (fix)
2. **Task 2: hwdb DMI patterns -> space-free form** - `dcf4398` (fix)
3. **Task 3: udev rule match-string + dead-property fixes** - `34daaac` (fix)
4. **Task 4: Wi-Fi resume hook + refresh-screen rotation/DPMS** - `4dbb046` (fix)
5. **Task 5: SC3 wireless test + static match suite** - `f4dde1e` (test)

**Plan metadata:** see the final `docs(39-01)` bookkeeping commit.

## Verify Results (raw)

| Gate | Result |
|------|--------|
| Task 1 `grep` block | `WIRELESS-CONF-OK` |
| Task 2 `grep` block | `HWDB-OK` |
| Task 3 `grep` block | `UDEV-RULES-OK` |
| Task 4 `bash -n` + grep | `SLEEP-REFRESH-OK` |
| `scripts/test_udev_hwdb_match.sh` | `passed=9 failed=0` |
| SC3 mutation run | `SC3-OK` |
| `scripts/test_wireless_coex.sh --dry-run` | `[DRY-RUN] Verification complete.` (rc 0) |
| `scripts/test_storage_cellular.sh --dry-run` | `[OK] dry-run verification complete` (rc 0) |
| `scripts/test_installer_symmetry.sh` | `passed=17 failed=0` |
| `scripts/test_hibernate_guards.sh` | `passed=21 failed=0` |
| `scripts/test_display_fix_guards.sh` | `passed=10 failed=0` |
| `scripts/test_microsd_guards.sh` | `passed=26 failed=0` |
| `scripts/test_noop_guards.sh` | `passed=5 failed=0` |
| `scripts/test_audio_dsp.sh --dry-run` | `passed=17 failed=0` |

## Files Created/Modified

- `patches/wireless/etc/modprobe.d/lenovo-d330-wireless.conf` - Realtek-only, both module spellings, real in-tree params.
- `patches/wireless/etc/systemd/system-sleep/lenovo-d330-wifi-resume.sh` - carrier-gated reconnect; dead var removed.
- `patches/dkms/etc/udev/hwdb.d/61-lenovo-d330-sensor.hwdb` - pn82H0 / pn81MD / pn81H3 entries.
- `patches/touchscreen/etc/udev/hwdb.d/62-lenovo-d330-touchscreen.hwdb` - pn82H0 / pn81MD / pn81H3 entries.
- `patches/sensors/etc/udev/rules.d/87-lenovo-d330-sensors.rules` - case-insensitive globs.
- `patches/hardware_controls/etc/udev/rules.d/88-lenovo-d330-hardware.rules` - no-op MODE/GROUP removed, root note.
- `patches/audio_dsp/etc/udev/rules.d/91-lenovo-d330-headset-jack.rules` - dead SOUND_INITIALIZED rule removed.
- `patches/touchscreen/etc/udev/rules.d/90-lenovo-d330-touchscreen.rules` - dead WL_OUTPUT property removed.
- `tools/d330-refresh-screen.sh` - rotation preserved; DPMS branch dropped with honest log.
- `scripts/test_wireless_coex.sh` - module-name assertion + non-vacuous `--dry-run` (SC3).
- `scripts/test_udev_hwdb_match.sh` - new static match-string guard suite.
- `scripts/test_storage_cellular.sh` - wires both new checks into the aggregate runner + `bash -n` loop.
- `CHANGES_AUDIT.md` - §7.6 corrected (Realtek-only, honest params).
- `patches/hardware_controls/README.md` - documents the root/pkexec requirement.

## Decisions Made

- Kept `rtw88_core disable_lps_deep=y` and `rtw88_pci disable_aspm=y`: both are real in-tree rtw88 module parameters kept as the plan allowed.
- Dropped the `/sys/class/drm/*/dpms` cycle rather than implementing a DRM modeset: the node is a no-op on modern i915; a userspace modeset already runs via `wlr-randr`/`xrandr` when a session exists.
- `test_wireless_coex.sh --dry-run` validates every configured module name against an allow-list AND requires the in-tree `rtw88_8821ce` name, so the mutation is caught even though the `rtl8821ce` line survives.

## Deviations from Plan

- **Rule 3 - Blocking, cosmetic:** hwdb comments initially contained the literal substring `pvrLenovoideapad`, which tripped the task's own `! grep -rq pvrLenovoideapad patches/` guard. Reworded the comments (Task 2); no functional change.
- **Antenna-select regex corrected:** the first draft of the `--dry-run` ant_sel check used `(rtw88_)?8821ce`, which cannot match `rtl8821ce`; changed to `(rtl8821ce|rtw88_8821ce)`. Caught before commit (Task 5).

## Issues Encountered

- `bash -c '<multi-statement>'` from pwsh silently lost shell variable assignments (`x=abc; echo $x` printed empty); all verify blocks were run from temp `.sh` files as the task rules prescribe.

## Out-of-Scope Discovery (logged, not fixed)

- `patches/power/etc/modprobe.d/lenovo-d330-power.conf` still configures `options iwlwifi ...` (and `patches/power/README.md` lists it). The D330 has no Intel wireless, so this is the same class of defect as Task 1 but outside this plan's file scope. Recorded in `deferred-items.md`.

## Known Stubs

None.

## Threat Flags

None - config/docs/test changes only; no new network, auth, file-access or schema surface.

## Next Phase Readiness

- SC3 is machine-proven; SC1 (`udevadm test`) and SC2 (`modprobe -s rtw88_8821ce`) remain host-bound overrides to re-run on the D330 at sign-off.
- The wireless/power conf Intel-option defect in `patches/power/` should be picked up by a later phase (audit M-series).

---

*Phase: 39-udev-hwdb-wireless-correctness*
*Completed: 2026-10-08*

## Self-Check: PASSED

- `39-01-SUMMARY.md` exists; `scripts/test_udev_hwdb_match.sh` exists.
- Commits present: 903b5f4, dcf4398, 34daaac, 4dbb046, f4dde1e.
