---
phase: 40-power-stack-reconciliation
reviewed: 2026-10-08T00:00:00Z
depth: deep
files_reviewed: 12
files_reviewed_list:
  - CHANGES_AUDIT.md
  - packaging/debian/control
  - patches/fastboot/etc/default/grub.d/52-lenovo-d330-fastboot.cfg
  - patches/power/etc/tlp.d/50-lenovo-d330.conf
  - patches/power/etc/udev/rules.d/95-lenovo-d330-power.rules
  - patches/thermal/etc/thermald/thermal-conf.xml
  - scripts/test_boot_speed.sh
  - scripts/test_power_stack.sh
  - scripts/test_storage_cellular.sh
  - tools/d330-fastboot-tune.sh
  - tools/d330-thermal-tune.sh
  - tools/lenovo-d330-power-tune.sh
findings:
  critical: 0
  high: 1
  medium: 7
  low: 5
  warning: 8
  info: 5
  total: 13
status: issues_found
---

# Phase 40: Code Review Report

**Reviewed:** 2026-10-08
**Depth:** deep
**Files Reviewed:** 12
**Status:** issues_found

## Summary

Phase 40 sets out to make the power stack one-writer-per-knob. The mechanical parts are
mostly correct: the `softlockup_panic=1` substitution is a valid kernel parameter and the
other GRUB params are intact; the thermald `<Type>x86_pkg_temp</Type>` matches a real intel
`x86_pkg_temp` sysfs zone and the pl1/pl2 numeric guard is correct under `set -e`; the udev
`power_supply` rule will not loop because the script it re-runs never writes a power_supply
attribute; and `lenovo-d330-power.service` (which the rule restarts) does exist.

The reconciliation itself is incomplete and, in places, asserted rather than true. The
dropped `i2c`/`sound` runtime-PM rules are now owned by nobody (TLP's `RUNTIME_PM_ON_AC` is
PCI-only), the "TLP is the single PCI owner" claim is contradicted by a pre-existing camera
rule, the new `power_supply` rule is unfiltered and coexists with TLP's own power-supply
handler, and the static guard suite passes vacuously on the watchdog assertion (the string
it greps for is present in a comment). The AC-state detection defaults to "on AC" and uses
case-sensitive name globs, so the battery cap silently fails to apply if the adapter node is
named anything else.

## High

### HI-01: Dropped i2c/sound runtime-PM rules leave those knobs unmanaged

**File:** `patches/power/etc/udev/rules.d/95-lenovo-d330-power.rules:10-14`
**Issue:** The rule file now claims TLP owns "PCI/PCIe, USB, I2C, Intel audio DSP" and deletes
the `SUBSYSTEM=="i2c"` and `SUBSYSTEM=="sound"` `power/control` rules. TLP's
`RUNTIME_PM_ON_AC`/`ON_BAT` only drives runtime PM for PCI devices; TLP does not set
`power/control` on i2c-client or sound-class devices (`SOUND_POWER_SAVE_*` is a different
knob writing `snd_hda_intel/parameters/power_save`). Those devices therefore now have no
runtime-PM writer at all, which is a silent battery/power regression and breaks the "one
writer per knob" invariant by leaving a knob with zero writers.
**Fix:** Retain narrowly scoped `i2c`/`sound` rules (or document the exact sysfs node TLP
covers and prove parity in the guard suite). Do not delete a rule on the strength of a
comment claim.

## Medium

### ME-01: "TLP is the single PCI runtime-PM owner" is false; guard never checks other rule files

**File:** `patches/power/etc/udev/rules.d/95-lenovo-d330-power.rules:5-7`
**Issue:** `patches/camera/etc/udev/rules.d/92-lenovo-d330-camera.rules:17` still writes
`ACTION=="add", SUBSYSTEM=="pci", ATTR{power/control}="auto"` for 8086:31a8, so two writers
touch PCI runtime PM. `scripts/test_power_stack.sh:78-87` only inspects the 95 file, so the
guard reports "no pci" while the contradicting rule exists.
**Fix:** Either scope/justify the camera PCI rule (e.g. exempt the IPU3 function explicitly)
and document it, or extend the guard to scan every `patches/**/udev/rules.d/*.rules` for
`power/control` on TLP-managed classes.

### ME-02: Guard suite passes vacuously on the watchdog assertion

**File:** `scripts/test_power_stack.sh:114`
**Issue:** `grep -q 'softlockup_panic=1' "$FASTBOOT_CFG"` is satisfied by the descriptive
comment on `52-lenovo-d330-fastboot.cfg:2` ("replaced with softlockup_panic=1"), so removing
the real `GRUB_CMDLINE_LINUX_DEFAULT` token still passes. The same file's check (1) at lines
54-59 is pure grep and passes a script that greps the tokens but always writes `100`.
**Fix:** Match the assignment line, e.g. `grep -Eq '^GRUB_CMDLINE_LINUX_DEFAULT=.*softlockup_panic=1'`,
and add a behavioral AC test (feed a fake `/sys` or assert the branch is actually taken).

### ME-03: `softlockup_panic=1` does not self-recover

**File:** `patches/fastboot/etc/default/grub.d/52-lenovo-d330-fastboot.cfg:6`
**Issue:** `softlockup_panic=1` panics on a soft lockup, but nothing sets `panic=<seconds>`
or `kernel.panic`, so the kernel halts at the panic with no automatic reboot. The cfg comment
(line 2-4), `CHANGES_AUDIT.md:359`, and the guard message at `test_power_stack.sh:115` all
claim "a hung boot self-recovers", which is not true as configured. Combined with
`quiet loglevel=3`, the freeze is also poorly logged.
**Fix:** Add `panic=10` (and consider `pstore`/`ramoops`) if self-recovery is the goal, or
correct the claim to "panics instead of going silent".

### ME-04: AC detection assumes AC and uses case-sensitive name globs

**File:** `tools/lenovo-d330-power-tune.sh:22-28`
**Issue:** `IS_ON_AC=1` initialises to AC and only a node matching `A*`/`ADP*` with
`online == 0` flips it. An adapter exposed as e.g. `ucsi-source-psy-*`, `main-charger`, or
lowercase `ac` is never matched, so on battery the script keeps `MAX_PERF=100` and never
applies the intended 75 cap (thermal/power regression on a fanless device). Multi-node logic
also latches: the first offline node sets battery and a later online node never resets it.
`[ "$VAL" -eq 0 ]` is also an unguarded integer comparison under `set -e` if the file holds
a non-numeric value.
**Fix:** Detect by `.../type == "Mains"`, default `IS_ON_AC=0` when nothing matches, and
reset from the aggregate (e.g. `any online`).

### ME-05: Unfiltered power_supply rule churns and races TLP's handler

**File:** `patches/power/etc/udev/rules.d/95-lenovo-d330-power.rules:23`
**Issue:** The rule has no `ATTR{online}`/type filter, so every battery capacity/status
`change` event restarts `lenovo-d330-power.service`, not just AC transitions. TLP ships its
own `power_supply` handler that runs `tlp auto` on the same event, and the restarted script
also writes EPP and `scaling_governor` that TLP already owns (the script duplicates
`CPU_ENERGY_PERF_POLICY_*` / `CPU_SCALING_GOVERNOR_*`), reintroducing a second writer on
those knobs.
**Fix:** Filter to `ENV{POWER_SUPPLY_TYPE}=="Mains"` (or `ATTR{online}`) and drop EPP/governor
writes from the script so it only sets `max_perf_pct`.

### ME-06: Numeric guard is incomplete; thermal-zone temperature arithmetic is still unguarded

**File:** `tools/d330-thermal-tune.sh:44-47`
**Issue:** The phase guards `pl1`/`pl2` but line 47 still evaluates `$((temp / 1000))` on
`/sys/class/thermal/thermal_zone*/temp` with no numeric check. An empty or non-numeric value
(cat succeeds, empty file) raises an arithmetic syntax error and aborts the script under
`set -euo pipefail`. The stated fix ("guards its arithmetic") is therefore incomplete.
**Fix:** Apply the same `[[ "$temp" =~ ^[0-9]+$ ]]` guard before the division.

### ME-07: "Fallback only" thermal owner is not enforced against thermald

**File:** `tools/d330-thermal-tune.sh:4-7`
**Issue:** The header claims the script "must not run concurrently with thermald", but
`patches/thermal/etc/systemd/system/d330-thermal.service:8` runs `--apply` unconditionally at
`multi-user.target`. With thermald now in `Recommends`, both can write the RAPL constraint
knobs (two writers), the exact failure this phase is supposed to remove.
**Fix:** Add `ConditionPathExists`/`ExecCondition` that skips when
`systemctl is-active --quiet thermald`, or make thermald the hard owner and gate the unit.

## Low

### LO-01: Dock rule matches every Lenovo USB device

**File:** `patches/power/etc/udev/rules.d/95-lenovo-d330-power.rules:19`
**Issue:** `ATTR{idVendor}=="17ef"` matches all Lenovo USB devices, not only the pogo-pin
dock, and pins them `power/control="on"` (runtime PM always on), so a Lenovo mouse/receiver
can never autosuspend.
**Fix:** Also match the dock's product/interface IDs or the specific HID interface.

### LO-02: Non-portable `/bin/systemctl` path in the udev rule

**File:** `patches/power/etc/udev/rules.d/95-lenovo-d330-power.rules:23`
**Issue:** `/bin/systemctl` only resolves where usrmerge provides the `/bin -> /usr/bin`
symlink; on non-merged systems the rule silently no-ops.
**Fix:** Use `/usr/bin/systemctl`.

### LO-03: CHANGES_AUDIT claims GRUB params that do not exist

**File:** `CHANGES_AUDIT.md:359`
**Issue:** The doc says `tsc=reliable` and `split_lock_mitigate=0` are "kept", but neither
parameter appears in any shipped GRUB config (the fastboot drop-in only ever contained
`nowatchdog no_timer_check quiet loglevel=3 rd.systemd.show_status=auto`). This is an
invented value in the audit record.
**Fix:** Remove the claim or actually add the parameters.

### LO-04: Thermal service ExecStart path does not match the installed binary

**File:** `patches/thermal/etc/systemd/system/d330-thermal.service:8`
**Issue:** `ExecStart=/usr/local/bin/d330-thermal-tune.sh --apply`, but the installer copies
the tool to `/usr/local/bin/d330-thermal-tune` (`scripts/install_dkms.sh:509`). The fallback
unit cannot start, so the "fallback only" story in ME-07 is moot on current installs.
Pre-existing, but it undermines this phase's thermal-ownership guarantee.
**Fix:** Align the unit's `ExecStart` with the installed name.

### LO-05: Guard regex relies on GNU grep treating `\^` as a literal caret

**File:** `scripts/test_power_stack.sh:121`
**Issue:** `grep -qE '=~ *\^\[0-9\]'` uses `\^`, which POSIX ERE leaves undefined; GNU grep
treats it as literal `^` but other grep implementations may not, so the thermal-guard check
can silently stop matching.
**Fix:** Use a bracket-free literal or a fixed-string match on `=~ ^[0-9]`.

---

## Clean Categories

- `softlockup_panic=1` is a valid kernel boot parameter and the other GRUB params are intact (substitution itself correct).
- thermald `<Type>x86_pkg_temp</Type>` matches a real intel `x86_pkg_temp` sysfs zone type.
- The pl1/pl2 numeric guard is correct under `set -e` (inside `if`, no `errexit` trip).
- The `power_supply` udev rule cannot loop: the restarted service/script never writes a power_supply attribute.
- `lenovo-d330-power.service` referenced by the udev rule exists and is enabled by the installer/postinst.
- GPU MIN lines removed; MAX/BOOST parse-valid TLP keys, no syntax break.
- `packaging/debian/control` `Recommends: ... thermald` is well-formed.

---

_Reviewed: 2026-10-08_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: deep_
