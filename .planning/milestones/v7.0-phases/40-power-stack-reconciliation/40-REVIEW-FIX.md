---
phase: 40-power-stack-reconciliation
fixed_at: 2026-10-08T19:28:02Z
review_path: .planning/phases/40-power-stack-reconciliation/40-REVIEW.md
iteration: 1
findings_in_scope: 13
fixed: 12
skipped: 1
status: partial
---

# Phase 40: Code Review Fix Report

**Fixed at:** 2026-10-08T19:28:02Z
**Source review:** `.planning/phases/40-power-stack-reconciliation/40-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 13
- Fixed: 12
- Skipped: 1 (LO-01, needs physical dock USB product ID)

**Verification environment note:** all gates were run in the **main checkout** on
Windows Git Bash (`C:\Program Files\Git\bin\bash.exe`, GNU bash 5.2.21). No
worktree was used, because the task directed direct commits on `main`.

## Fixed Issues

### HI-01 (task 1): Restore scoped i2c/sound runtime-PM writers

**Files modified:** `patches/power/etc/udev/rules.d/95-lenovo-d330-power.rules`, `patches/power/etc/tlp.d/50-lenovo-d330.conf`
**Commit:** 9f89fd4, 286db1f
**Applied fix:** Re-added the `SUBSYSTEM=="i2c"` and `SUBSYSTEM=="sound"`
`ATTR{power/control}="auto"` rules (TLP's `RUNTIME_PM_ON_AC` is PCI-only and
`SOUND_POWER_SAVE_*` writes a different knob). Corrected the ownership comments
in the rules file and the TLP drop-in so they no longer claim TLP owns i2c/sound.
The guard now asserts i2c/sound/mmc/usb are present and that no pci writer
exists in the 95 file.

### ME-01 (task 2): Camera PCI rule justified and guard made repo-wide

**Files modified:** `patches/camera/etc/udev/rules.d/92-lenovo-d330-camera.rules`, `scripts/test_power_stack.sh`
**Commit:** 80450ea
**Applied fix:** Documented the 8086:31a8 rule as the single explicit,
device-scoped PCI exception (IPU3 camera IP) and extended
`test_power_stack.sh` to scan every `patches/*/etc/udev/rules.d/*.rules` for
`power/control` writers, failing if any PCI writer is not device-scoped
(`ATTR{device}`). The single-owner claim is now enforced repo-wide.

### ME-02 (task 3): Guard no longer passes vacuously on comment text

**Files modified:** `scripts/test_power_stack.sh`
**Commit:** 80450ea
**Applied fix:** The watchdog/softlockup/panic checks now match the real
`^GRUB_CMDLINE_LINUX_DEFAULT=` assignment line (comment text no longer
satisfies them). The AC-aware check matches actual assignments
(`IS_ON_AC=0`, `"Mains"`, `online=`, `MAX_PERF=100/75`, `$MAX_PERF`) rather
than bare comment words.

### ME-03 (task 4): `softlockup_panic=1` now actually self-recovers

**Files modified:** `patches/fastboot/etc/default/grub.d/52-lenovo-d330-fastboot.cfg`, `CHANGES_AUDIT.md`, `scripts/test_power_stack.sh`
**Commit:** e07b0fa, 80450ea
**Applied fix:** Added `panic=10` to the `GRUB_CMDLINE_LINUX_DEFAULT` line so a
soft-lockup panic auto-reboots after 10 s, corrected the cfg comment and the
`CHANGES_AUDIT.md:359` claim, and made the guard require both
`softlockup_panic=1` and `panic=10` as real cmdline tokens.

### ME-04 (task 5): Robust AC detection, fail-safe to battery

**Files modified:** `tools/lenovo-d330-power-tune.sh`
**Commit:** b83c4d2
**Applied fix:** Detect mains by iterating `/sys/class/power_supply/*` and
matching the node's `type == "Mains"` (no name globs), initialise
`IS_ON_AC=0` so an unknown adapter defaults to battery, reset from the
aggregate (`any online`), and guard the numeric compare with
`[[ "$online" =~ ^[0-9]+$ ]]` before `-ne 0`.

### ME-05 (task 6): Filtered power-supply rule; re-run touches only `max_perf_pct`

**Files modified:** `patches/power/etc/udev/rules.d/95-lenovo-d330-power.rules`, `tools/lenovo-d330-power-tune.sh`, `scripts/test_power_stack.sh`
**Commit:** 9f89fd4, b83c4d2, 80450ea
**Applied fix:** Added `ENV{POWER_SUPPLY_TYPE}=="Mains"` to the
`ACTION=="change"` rule so battery capacity events no longer churn the service,
and removed the EPP (`energy_perf_preference`) and `scaling_governor` writes
from the script (TLP owns `CPU_ENERGY_PERF_POLICY_*` / `CPU_SCALING_GOVERNOR_*`),
leaving only `max_perf_pct`. The guard now requires the Mains filter.

### ME-06 (task 7): Guarded thermal-zone temperature arithmetic

**Files modified:** `tools/d330-thermal-tune.sh`
**Commit:** 565730a
**Applied fix:** Applied the same `[[ "$temp" =~ ^[0-9]+$ ]]` guard before
`$((temp / 1000))` on `/sys/class/thermal/thermal_zone*/temp`, printing `N/A`
for empty/non-numeric values instead of aborting under `set -euo pipefail`.

### ME-07 (task 8): Thermal fallback gated on thermald absence

**Files modified:** `patches/thermal/etc/systemd/system/d330-thermal.service`
**Commit:** e68cbce
**Applied fix:** Added
`ExecCondition=/bin/sh -c '! systemctl is-active --quiet thermald'` so the
fallback RAPL unit runs only when thermald is not the active owner, matching the
documented precedence.

### LO-02 (task 10): Portable systemctl path in the udev rule

**Files modified:** `patches/power/etc/udev/rules.d/95-lenovo-d330-power.rules`
**Commit:** 9f89fd4
**Applied fix:** Changed `/bin/systemctl` to `/usr/bin/systemctl`.

### LO-03 (task 11): Removed invented GRUB params from the audit

**Files modified:** `CHANGES_AUDIT.md`
**Commit:** e07b0fa
**Applied fix:** Removed the `tsc=reliable` / `split_lock_mitigate=0` "kept"
claim (neither is shipped) and restated the Phase 40 watchdog change as
`softlockup_panic=1 panic=10`.

### LO-04 (task 12): Unit `ExecStart` matches the installed binary

**Files modified:** `patches/thermal/etc/systemd/system/d330-thermal.service`
**Commit:** e68cbce
**Applied fix:** Aligned `ExecStart` with the deployed name
`/usr/local/bin/d330-thermal-tune` (the installer copies it without `.sh`).

### LO-05 (task 13): Portable guard regex

**Files modified:** `scripts/test_power_stack.sh`
**Commit:** 80450ea
**Applied fix:** Replaced the GNU-grep-dependent `grep -qE '=~ *\^\[0-9\]'` with
the fixed-string check `grep -Fq '=~ ^[0-9]'`.

## Skipped Issues

### LO-01 (task 9): Dock rule matches every Lenovo USB device

**File:** `patches/power/etc/udev/rules.d/95-lenovo-d330-power.rules:19`
**Reason:** The repo identifies the dock only by USB vendor `17ef` (the tablet
daemon matches `PRODUCT=17ef/` and the hwdb matches `b*v17EFp*`); no dock
product/interface ID exists anywhere in the tree, and I could not confirm one
from public sources either. Adding a fabricated `ATTR{idProduct}` would risk the
rule not matching the real dock (behavioural regression) while still not
guaranteeing that a Lenovo mouse is excluded. TLP's `USB_DENYLIST="17ef:*"`
already excludes all Lenovo dock devices from autosuspend, so the dock pin is
partly redundant, but the rule does still pin `power/control="on"` on other
17ef peripherals. Recommended follow-up: capture `lsusb -v` on the D330 with the
dock attached and add the dock's `ATTR{idProduct}` (and/or the specific HID
interface) rather than guessing.
**Original issue:** `ATTR{idVendor}=="17ef"` matches all Lenovo USB devices and
pins `power/control="on"`, so a Lenovo mouse/receiver can never autosuspend.

---

_Fixed: 2026-10-08T19:28:02Z_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_
