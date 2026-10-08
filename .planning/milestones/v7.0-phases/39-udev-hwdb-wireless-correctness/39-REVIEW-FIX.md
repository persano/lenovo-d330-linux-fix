---
phase: 39
fixed_at: 2026-10-08T18:44:44Z
review_path: Phase 39 code review (findings supplied to the fix run)
iteration: 1
findings_in_scope: 6
fixed: 6
skipped: 0
status: all_fixed
---

# Phase 39: Code Review Fix Report

**Fixed at:** 2026-10-08T18:44:44Z
**Source review:** Phase 39 code review findings
**Iteration:** 1

**Summary:**
- Findings in scope: 6
- Fixed: 6
- Skipped: 0
- Commit tool: `gsd-tools commit` (the installed build exposes `commit`, not the `query commit` alias)

## Fixed Issues

### CR-01 (CRITICAL): d330-refresh-screen.sh rotation parse + false success

**File:** `tools/d330-refresh-screen.sh:30,34-35,45-54`
**Commit:** `e5dcb71`

**Applied fix:**
- The `CUR_ROT` awk now strips parentheses before testing
  (`r=$i; gsub(/[()]/,"",r); if (r ~ /^(normal|left|right|inverted)$/) { print r; exit }`),
  so a `normal` display no longer resolves to `left` and a refresh no longer
  rotates 90 degrees.
- Both `xrandr --current` command substitutions are now `|| true`-guarded, so
  `set -e` cannot abort before the guarded `--off`.
- When neither the wlr-randr nor the xrandr path ran, the tool now logs the
  honest diagnostic and `exit 1` instead of logging "complete" and exiting 0
  having changed nothing.
- The DPMS comment now states the sysfs node is read-only / writes are rejected
  (`DEVICE_ATTR_RO(dpms)` since <=5.15, per Phase 34 research) instead of
  claiming it merely does not drive a modeset.

### WR-01 (HIGH): power modprobe conf targeted absent modules

**File:** `patches/power/etc/modprobe.d/lenovo-d330-power.conf:1-14`
**Commit:** `8ba71c1`

**Applied fix:**
- Removed `options iwlwifi power_save=1 d0i3_disable=0 uapsd_disable=0` (the
  D330 has no Intel Wi-Fi).
- Removed `options pcie_aspm policy=powersave` (`pcie_aspm` is a kernel boot
  parameter, not a loadable module) and left a comment pointing at the
  `pcie_aspm=powersave` kernel cmdline.
- Kept only real in-tree i915 params: `options i915 enable_fbc=0 enable_psr=0`.
  Dropped `enable_rc6`, which the reviewer flagged and I confirmed is absent from
  the i915 module parameter table in v6.1, v6.6 and master (`i915_params.c`).

### WR-02 (HIGH): udev/hwdb guard only checked one conf and one product code

**File:** `scripts/test_udev_hwdb_match.sh:1-160`
**Commit:** `3b6860b`

**Applied fix:**
- Check (7) now iterates EVERY `patches/*/etc/modprobe.d/*.conf`, extracts each
  `options <module>` name, and fails on blocklisted non-module / absent-hardware
  names (`pcie_aspm iwlwifi iwlmvm`); it also fails if no options are found.
  Full module existence is a host-bound check (SC2) and is not asserted here.
- Check (2) now asserts all three product codes (`pn82H0`, `pn81MD`, `pn81H3`)
  in both the sensor and touchscreen hwdb files, not just `pn82H0`.
- Check (8) asserts the wireless conf configures the in-tree `rtw88_core`
  helper (the in-tree driver name check was moved off `rtw88_8821ce`).

### WR-03 (MEDIUM): inert hwdb lookup keys

**Files:** `patches/touchscreen/etc/udev/hwdb.d/62-lenovo-d330-touchscreen.hwdb`,
`patches/touchpad_pen/etc/udev/hwdb.d/63-lenovo-d330-touchpad-pen.hwdb`
**Commit:** `0ee0b58`

**Applied fix:**
- Converted the never-composed `touchscreen:` keys to the `evdev:` form
  systemd's own rules compose:
  `evdev:name:Goodix Capacitive TouchScreen:dmi:*:svnLENOVO:pn<CODE>:*`, and
  the ACPI fallback to `evdev:name:GDIX1001*:dmi:*:svnLENOVO:*`.
- Converted the `libinput:touchpad:` / `libinput:touchscreen:` keys in the
  touchpad/pen file to `evdev:input:...` (libinput >=1.12 dropped hwdb model
  config; the `libinput:` namespace is never composed, so those entries were
  inert).
- Added comments naming the authoritative calibration path
  (`patches/touchscreen/etc/udev/rules.d/90-lenovo-d330-touchscreen.rules`,
  which sets `ENV{LIBINPUT_CALIBRATION_MATRIX}`) and the X11 touchpad/pen conf.

### WR-04 (MEDIUM): `ant_sel` on the in-tree `rtw88_8821ce` is ignored

**Files:** `patches/wireless/etc/modprobe.d/lenovo-d330-wireless.conf`,
`CHANGES_AUDIT.md` §7.6, `scripts/test_wireless_coex.sh`
**Commit:** `a3dc764`

**Applied fix:**
- Dropped `options rtw88_8821ce ant_sel=2`; `ant_sel=2` is kept only on the
  out-of-tree `rtl8821ce` line. The valid in-tree `rtw88_core`/`rtw88_pci`
  options are retained.
- Corrected `CHANGES_AUDIT.md` §7.6 to say `ant_sel` is available only on the
  legacy out-of-tree `rtl8821ce`, and that the in-tree driver is tuned through
  the `rtw88_core`/`rtw88_pci` helpers.
- In `test_wireless_coex.sh`, the `ant_sel` check/message is narrowed to the
  out-of-tree `rtl8821ce` module only, the "in-tree module" check now requires
  `rtw88_core`, and a comment records that only module NAMES are asserted, not
  option semantics.

### WR-05 (LOW): Wi-Fi resume could re-enable a user-disabled radio

**File:** `patches/wireless/etc/systemd/system-sleep/lenovo-d330-wifi-resume.sh:17-33`
**Commit:** `7bcd624`

**Applied fix:**
- Carrier 0 is now treated as ambiguous. Before any reconnect/bounce the hook
  checks the radio is actually enabled: `nmcli -t -f WIFI radio` shows
  `enabled`, or (when `nmcli` is absent) `rfkill` shows no `blocked: yes`. When
  the radio is disabled/blocked the hook logs and breaks without touching it, so
  a user-disabled radio is never re-enabled.

## Verification

All gates were run in the main checkout (no worktree; `workflow.use_worktrees`
is unset and the user directed the `gsd-tools commit` flow directly), on WSL
bash with LF line endings.

- `bash -n` on `install_dkms.sh`, `test_wireless_coex.sh`,
  `test_udev_hwdb_match.sh`, `d330-refresh-screen.sh`,
  `lenovo-d330-wifi-resume.sh` -> rc=0
- `test_udev_hwdb_match.sh` -> passed=10 failed=0 (22 modprobe options scanned)
- `test_wireless_coex.sh --dry-run` -> Verification complete, rc=0
- `test_storage_cellular.sh --dry-run` -> complete, rc=0
- SC3 mutation: `options rtw88_core` -> `WRONGMOD_core` -> `--dry-run` FAILED
  (non-zero, "[FAIL] in-tree module rtw88_core is not configured"); restored via
  `git checkout --` -> rc=0, working tree clean.
- `test_installer_symmetry.sh` -> passed=17 failed=0
- `test_hibernate_guards.sh` -> passed=21 failed=0
- `test_display_fix_guards.sh` -> passed=10 failed=0
- `test_microsd_guards.sh` -> passed=26 failed=0
- `test_noop_guards.sh` -> passed=5 failed=0
- `test_audio_dsp.sh --dry-run` -> passed=17 failed=0
- `test_mic_rnnoise.sh --dry-run` -> passed=7 failed=0

---

_Fixed: 2026-10-08T18:44:44Z_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_
