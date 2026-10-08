---
phase: 40-power-stack-reconciliation
verified: 2026-10-08T19:38:24Z
status: human_needed
score: 1/4 must-haves verified
behavior_unverified: 3
overrides_applied: 0
re_verification: false
behavior_unverified_items:
  - truth: "SC1: tlp-stat -s and /sys/class/powercap agree after AC hot-plug (hardware)"
    test: "On the D330: capture `sudo tlp-stat -s` and `cat /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw` (and constraint_1) on AC; unplug AC, wait ~5 s, replug; re-capture both."
    expected: "tlp-stat -s power source matches /sys/class/power_supply/*/online at every step; RAPL constraint values are unchanged (one writer) and no TLP rejected-write line appears."
    why_human: "Requires the physical D330, its mains adapter and the intel-rapl powercap driver; cannot be exercised on a Windows/WSL host."
  - truth: "SC2: no TLP error lines in the journal across a full AC/battery cycle (hardware)"
    test: "On the D330: `journalctl -b --no-pager | grep -iE 'tlp.*(error|fail|reject)'`; then run a full cycle (AC -> battery 2-3 min -> AC 2-3 min) and re-run the grep plus `sudo tlp-stat -s`."
    expected: "No TLP error/rejected-write lines across the cycle; power-source transitions clean."
    why_human: "Requires journald on the target device across a real AC/battery cycle with the adapter physically present."
  - truth: "SC3: boot bench reproduced and documented (hardware/boot)"
    test: "On the D330: `systemd-analyze`, `systemd-analyze blame | head -20`, `systemd-analyze critical-chain`, and `systemctl is-enabled NetworkManager-wait-online.service` after install + reboot."
    expected: "Boot bench reproduced and written into CHANGES_AUDIT.md §7.7; wait-online services masked (the real boot win), no watchdog attribution."
    why_human: "`systemd-analyze` boot timings require an actual boot of the installed system."
human_verification:
  - test: "SC1 — AC hot-plug agreement. On the D330: record `sudo tlp-stat -s` and `cat /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw` on AC and on battery; unplug, wait 5 s, replug, re-record. Also `cat /sys/devices/system/cpu/intel_pstate/max_perf_pct` before/after the replug."
    expected: "tlp-stat -s and the powercap/RAPL values (and the AC/battery state in /sys/class/power_supply) agree at each step; `max_perf_pct` returns to 100 on AC replug via the udev re-run; no rejected TLP write."
    why_human: "Hardware + powercap driver only."
  - test: "SC2 — clean journal across a full AC/battery cycle. On the D330: `journalctl -b --no-pager | grep -iE 'tlp.*(error|fail|reject)'` before and after a full AC -> battery -> AC cycle."
    expected: "Zero TLP error/rejected lines across the cycle."
    why_human: "Requires a real device journal across a physical cycle."
  - test: "SC3 — boot bench. On the D330: `systemd-analyze`, `systemd-analyze blame`, `systemd-analyze critical-chain`, `systemctl is-enabled NetworkManager-wait-online.service`."
    expected: "Boot numbers reproduced and documented in CHANGES_AUDIT.md §7.7; wait-online masked; the '12 s from watchdog' claim is gone."
    why_human: "Boot timings only observable on a real boot."
---

# Phase 40: Power Stack Reconciliation Verification Report

**Phase Goal:** One writer per knob — TLP, udev, `lenovo-d330-power-tune.sh`, thermald and RAPL must not fight.
**Verified:** 2026-10-08T19:38:24Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1 | SC1: `tlp-stat -s` and `/sys/class/powercap` agree after AC hot-plug (hardware) | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Requires the physical D330 + powercap driver; not runnable on this host. See Human Verification. |
| 2 | SC2: no TLP error lines in the journal across a full AC/battery cycle (hardware) | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Requires a real boot/journal across a physical cycle. See Human Verification. |
| 3 | SC3: boot bench reproduced and documented (hardware/boot) | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `systemd-analyze` needs an actual boot. See Human Verification. |
| 4 | One writer per knob: no udev rule and TLP both drive runtime PM; the CPU perf cap is AC-aware; no rejected TLP GPU freq; no `nowatchdog`; thermal numeric guard present | ✓ VERIFIED | Code inspection + `scripts/test_power_stack.sh` 12/0 + non-vacuity mutation (11/1, rc=1). Details below. |

**Score:** 1/4 truths verified (3 present, behavior-unverified)

The "one writer per knob" truth was falsified-attempted and held:
- `tools/lenovo-d330-power-tune.sh` detects mains by `type == "Mains"` over `/sys/class/power_supply/*`, defaults `IS_ON_AC=0` (fail-safe to battery), resets from the aggregate, and writes `max_perf_pct` from a 100/75 branch. It writes **no** `power/control`, EPP or governor.
- `patches/power/etc/udev/rules.d/95-lenovo-d330-power.rules` has **no** PCI `power/control` writer; it covers i2c/sound/mmc/usb only, plus a Mains-filtered `power_supply ACTION=="change"` re-run rule (`/usr/bin/systemctl --no-block restart lenovo-d330-power.service`).
- Repo-wide, the only PCI `power/control` writer is the device-scoped IPU3 camera exception (`92-lenovo-d330-camera.rules:21`, `ATTR{vendor}=="0x8086", ATTR{device}=="0x31a8"`) — explicitly justified.
- `50-lenovo-d330.conf` has no `INTEL_GPU_MIN_FREQ_ON_AC=100`, keeps MAX 650 / BOOST 700 with a source comment, and keeps `RUNTIME_PM_ON_AC=on` as the TLP runtime-PM declaration.
- `52-lenovo-d330-fastboot.cfg` cmdline has `softlockup_panic=1 panic=10` and **no** `nowatchdog`.
- `d330-thermal-tune.sh` numeric-guards `pl1`, `pl2` **and** thermal-zone `temp`; `thermal-conf.xml` uses `<Type>x86_pkg_temp</Type>`; `d330-thermal.service` is gated on thermald absent; debian control `Recommends: ... thermald`.

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `scripts/test_power_stack.sh` | static single-writer / AC-aware / nowatchdog / numeric-guard suite | ✓ VERIFIED | 170 lines, 12 cases, wired into `test_storage_cellular.sh` aggregate; non-vacuous (mutation probe 11/1). |
| `tools/lenovo-d330-power-tune.sh` | AC-aware cap, no runtime-PM/EPP/governor writes | ✓ VERIFIED | Mains-by-type detection, `MAX_PERF=100/75`, only `max_perf_pct` written. |
| `patches/power/etc/udev/rules.d/95-lenovo-d330-power.rules` | Mains-filtered re-run rule; no broad PCI `power/control` | ✓ VERIFIED | 4 scoped `power/control` rules (i2c/sound/mmc/usb) + Mains-filtered change rule; no pci. |
| `patches/power/etc/tlp.d/50-lenovo-d330.conf` | no `MIN_FREQ=100`; `RUNTIME_PM_ON_AC`; MAX/BOOST documented | ✓ VERIFIED | All four GPU MIN lines dropped; MAX 650/BOOST 700 + ARK source comment. |
| `patches/fastboot/etc/default/grub.d/52-lenovo-d330-fastboot.cfg` | `softlockup_panic=1` + `panic=10`, no `nowatchdog` | ✓ VERIFIED | Line 7 cmdline: `softlockup_panic=1 panic=10 no_timer_check quiet loglevel=3 rd.systemd.show_status=auto`. |
| `tools/d330-thermal-tune.sh` | numeric guards for pl1/pl2 and temp; fallback-only doc | ✓ VERIFIED | `[[ "$pl1" =~ ^[0-9]+$ ]]`, `[[ "$pl2" ... ]]`, `[[ "$temp" ... ]]`. |
| `patches/thermal/etc/thermald/thermal-conf.xml` | real sysfs zone type | ✓ VERIFIED | `<Type>x86_pkg_temp</Type>` (Zone and both SensorTypes). |
| `patches/thermal/etc/systemd/system/d330-thermal.service` | gated on thermald absent | ✓ VERIFIED | `ExecCondition=/bin/sh -c '! systemctl is-active --quiet thermald'`; ExecStart aligned to install path. |
| `packaging/debian/control` | Recommends thermald | ✓ VERIFIED | Line 12: `Recommends: iio-sensor-proxy, v4l2loopback-dkms, thermald`. |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `tools/lenovo-d330-power-tune.sh` | `95-lenovo-d330-power.rules` `power_supply` rule | re-run on AC change | ✓ WIRED | Script comment + rule restart `lenovo-d330-power.service`; guard asserts `IS_ON_AC=0`/`"Mains"`/branch/`$MAX_PERF`. |
| `95-lenovo-d330-power.rules` | TLP (`50-lenovo-d330.conf`) | udev scoped to non-TLP classes | ✓ WIRED | No pci writer in 95; repo-wide PCI writers device-scoped; TLP declares `RUNTIME_PM_ON_AC`. |
| `95-lenovo-d330-power.rules` | `lenovo-d330-power.service` | `systemctl restart` | ✓ WIRED | Service exists (`patches/power/etc/systemd/system/`), installed + enabled by `install_dkms.sh:533-534,564`. |
| installer manifest | deployed rules/configs | `install_dkms.sh` manifest | ✓ WIRED | 95 rules (`:384-385`), TLP drop-in (`:744-745`), fastboot cfg (`:445-446`), thermal unit (`:543-544`) all deployed. |
| `d330-thermal.service` ExecStart | `tools/d330-thermal-tune.sh` | `/usr/local/bin/d330-thermal-tune` | ✓ WIRED | Installer copies `.sh` to `/usr/local/bin/d330-thermal-tune` (`:508-510`); unit ExecStart matches. |

### Data-Flow Trace (Level 4)

Mostly static config; the one runtime chain traced:

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `95-...power.rules` change rule → `lenovo-d330-power.service` → `lenovo-d330-power-tune.sh` | `IS_ON_AC` / `MAX_PERF` | `/sys/class/power_supply/*/type` + `/online` | Yes — real sysfs read, branch selects 100/75, written to `intel_pstate/max_perf_pct` | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| power-stack guard | `bash scripts/test_power_stack.sh` | passed=12 failed=0 (rc 0) | ✓ PASS |
| aggregate dry-run (runs power stack + others) | `bash scripts/test_storage_cellular.sh --dry-run` | rc 0 (power stack 12/0 inside) | ✓ PASS |
| guard non-vacuity | mutate `52-...fastboot.cfg` real `softlockup_panic=1 panic=10` tokens (comment kept) then run guard | passed=11 failed=1, rc 1; restored (git content diff empty) | ✓ PASS |
| installer symmetry | `bash scripts/test_installer_symmetry.sh` | 17/0 (rc 0) | ✓ PASS |
| hibernate guards | `bash scripts/test_hibernate_guards.sh` | 21/0 (rc 0) | ✓ PASS |
| display-fix guards | `bash scripts/test_display_fix_guards.sh` | 10/0 (rc 0) | ✓ PASS |
| microsd guards | `bash scripts/test_microsd_guards.sh` | 26/0 (rc 0) | ✓ PASS |
| no-op guards | `bash scripts/test_noop_guards.sh` | 5/0 (rc 0) | ✓ PASS |
| udev/hwdb match | `bash scripts/test_udev_hwdb_match.sh` | 10/0 (rc 0) | ✓ PASS |
| audio DSP | `bash scripts/test_audio_dsp.sh --dry-run` | 17/0 (rc 0) | ✓ PASS |
| mic RNNoise | `bash scripts/test_mic_rnnoise.sh --dry-run` | 7/0 (rc 0) | ✓ PASS |
| shell syntax | `bash -n` on touched scripts + all `scripts/*.sh` `tools/*.sh` | 0 syntax errors | ✓ PASS |

### Probe Execution

No `scripts/*/tests/probe-*.sh` probes are declared by this phase; Step 7c applies to migration/tooling probe harnesses. The phase's runnable artifact is the static guard suite, exercised above. **SKIPPED (no phase-declared probes).**

### Requirements Coverage

No `.planning/REQUIREMENTS.md` exists; the phase contract is the ROADMAP SC1-SC3 + the plan's static "one writer per knob" truth. All three ROADMAP SCs map to hardware/boot verification (rows 1-3); the static invariant (row 4) is satisfied.

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| SC1 (ROADMAP) | 40-01-PLAN | tlp-stat vs powercap agree after AC hot-plug | ? NEEDS HUMAN | Hardware-only. |
| SC2 (ROADMAP) | 40-01-PLAN | no TLP errors across AC/battery cycle | ? NEEDS HUMAN | Hardware-only. |
| SC3 (ROADMAP) | 40-01-PLAN | boot bench reproduced/documented | ? NEEDS HUMAN | Boot-only. |
| Static one-writer | 40-01-PLAN | one writer per knob | ✓ SATISFIED | Guard 12/0 + non-vacuity probe + independent grep. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `patches/power/etc/udev/rules.d/95-lenovo-d330-power.rules` | 28 | Dock rule matches all Lenovo USB (`idVendor==17ef`) and pins `power/control="on"` | ⚠️ Warning (known, skipped LO-01) | A Lenovo USB mouse/receiver pinned out of autosuspend. Not a two-writer conflict; TLP `USB_DENYLIST="17ef:*"` already excludes these from autosuspend. Fix needs the physical dock's USB product/interface ID (`lsusb -v` on hardware). |
| `docs/research/EMMC_FASTBOOT_TUNING.md` | 11 | Stale `nowatchdog` rationale in a historical research doc | ℹ️ Info | Not shipped config; SUMMARY declares it out-of-scope. No shipped grub config carries `nowatchdog` (independently grepped). |

No debt markers (`TBD`/`FIXME`/`XXX`) found in any phase-modified file.

### Human Verification Required

#### 1. SC1 — AC hot-plug agreement (tlp-stat vs /sys/class/powercap)

**Test:** On the D330 with the package installed:
```
sudo tlp-stat -s
cat /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw
cat /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_1_power_limit_uw
cat /sys/devices/system/cpu/intel_pstate/max_perf_pct
cat /sys/class/power_supply/*/online          # and /type
# now unplug AC, wait ~5 s, plug it back in, repeat the reads
```
**Expected:** `tlp-stat -s` power source agrees with `/sys/class/power_supply`; RAPL constraint values unchanged; after AC replug `max_perf_pct` returns to 100 (udev re-run) with no rejected TLP write.
**Why human:** Requires the physical device, mains adapter and the intel-rapl driver.

#### 2. SC2 — clean journal across a full AC/battery cycle

**Test:** On the D330:
```
journalctl -b --no-pager | grep -iE 'tlp.*(error|fail|reject)'
# unplug AC, run on battery 2-3 min, replug, run 2-3 min, then:
journalctl -b --no-pager | grep -iE 'tlp.*(error|fail|reject)'
sudo tlp-stat -s
```
**Expected:** No TLP error/rejected-write lines across the cycle.
**Why human:** Requires a real device journal across a physical AC/battery cycle.

#### 3. SC3 — boot bench reproduced and documented

**Test:** On the D330 after install + reboot:
```
systemd-analyze
systemd-analyze blame | head -20
systemd-analyze critical-chain
systemctl is-enabled NetworkManager-wait-online.service
```
**Expected:** Boot bench reproduced and recorded into `CHANGES_AUDIT.md` §7.7; wait-online services masked (the real boot win); no watchdog attribution.
**Why human:** `systemd-analyze` timings require an actual boot of the installed system.

### Gaps Summary

No static/software gaps. All machine-checkable artifacts exist, are substantive, wired, and the single-writer guard suite is green (12/0) and provably non-vacuous (mutation → 11/1). The three ROADMAP success criteria (SC1, SC2, SC3) are hardware/boot-bound and cannot be exercised on this Windows/WSL host; they are recorded as behavior-unverified and routed to on-device verification. One known low-severity limitation (dock USB overmatch, LO-01) is carried as a warning with a hardware-dependent follow-up.

---

_Verified: 2026-10-08T19:38:24Z_
_Verifier: the agent (gsd-verifier)_
