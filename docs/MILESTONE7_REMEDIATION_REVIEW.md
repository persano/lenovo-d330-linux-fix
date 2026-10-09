# Milestone 7 (v7.0) Remediation Review

This document is a handoff for external review. It lists the defects found in the Lenovo
IdeaPad D330-10IGL Linux parity project, why each mattered, what I changed, how I changed it,
and how I verified the change. It is written so a reviewer (for example, Gemini) can check the
claims against the repository without re-reading every phase plan.

## 1. How to review this

- Every claim below names the file(s) and, where useful, the line or symbol to inspect.
- Every fix has a corresponding guard test under `scripts/test_*.sh`. Run the aggregate to see
  all of them:
  ```
  wsl bash -lc 'cd "/mnt/d/Documentos/Programming projects/lenovo-d330-linux-screen-fix" && bash scripts/test_storage_cellular.sh --dry-run'
  ```
  On a Linux or WSL host this runs real `bash -n` gates plus the full set of guard suites.
- The authoritative per-phase detail lives in the archived planning artifacts:
  `.planning/milestones/v7.0-phases/<phase>/` (PLAN, SUMMARY, REVIEW, REVIEW-FIX, VERIFICATION, UAT).
- The milestone-level result is `.planning/milestones/v7.0-MILESTONE-AUDIT.md`.
- Commit history: `git log --oneline` (the `v7.0` tag points at the archive commit).

The starting point was an external pre-deployment audit that returned the verdict
`BLOCKED BY CRITICAL DEFECTS` with 4 Critical, 17 Moderate and 11 Minor findings. Milestone 7
spans phases 32 to 42 and remediates all of them, plus one cross-phase packaging gap that the
milestone audit found later.

## 2. Per-phase defects, causes, and fixes

Each entry follows: **Wrong** (observable defect), **Why** (impact), **Fix** (what changed),
**How** (mechanism), **Verified** (guard and evidence).

### Phase 32: MicroSD data-loss and boot safety (audit C1, C2)

- **Wrong:** `tools/d330-microsd-setup.sh --format` could erase the root disk. It had no mount
  check, used `mkfs -F`, and substituted a device automatically. Separately, `--mount-data`
  wrote an `/etc/fstab` line without `nofail`, so an absent card dropped the machine into an
  emergency shell at boot.
- **Why:** Either path can destroy the root filesystem or make the system unbootable.
- **Fix:** Require an explicit `--device`. Run three ordered pre-write guards (mountpoint check,
  bidirectional root-device refusal, typed confirmation) before the first `parted` or `mkfs`
  write. Drop the force flag and the fixed `sleep 1`, add `partprobe` and `udevadm settle`.
  `--mount-data` now writes only the locked line
  `noatime,lazytime,commit=60,nofail,x-systemd.device-timeout=10s 0 2`, proven by `findmnt --verify`
  before the append, with an `EXIT`-trap rollback on a failed mount. `--mount-home` is an honest
  non-zero stub.
- **How:** A single writer function builds the fstab line, a rollback function truncates it on
  failure, and the guard chain returns non-zero before any destructive syscall.
- **Verified:** `scripts/test_microsd_guards.sh` (26 cases, including a `parted` canary that
  proves the abort happens before the first write). Physical confirmation on a real card is
  deferred (see section 4).

### Phase 33: Low-battery hibernate could not complete (audit C3)

- **Wrong:** The auto-hibernate daemon targeted a 3 GB zram swap, which has no valid resume
  device, so hibernation could not actually resume.
- **Why:** The low-battery safety net was cosmetic, the machine would lose state on a critical
  battery event.
- **Fix:** Add a disk-backed `/var/swapfile` oneshot unit (RAM-sized, clamped 4 to 8 GB, with a
  free-space guard). Render the `resume=` and `resume_offset=` kernel command line at install
  time with `mkconfig` verification and a locked manual-step fallback. The daemon now refuses and
  degrades with an explicit `[ERROR]` when no non-zram swap exists, instead of claiming success.
- **How:** A unit file plus a render step in `scripts/install_dkms.sh`; the daemon reads swap
  state through an environment seam so it is testable without hardware.
- **Verified:** `scripts/test_hibernate_guards.sh` (21 cases). The real hibernate round trip is
  deferred (section 4).

### Phase 34: The PPS / display-resume fix was not delivered, and the module overclaimed (audit C4)

- **Wrong:** The advertised 600 ms panel power-sequencing clamp was not implemented, and the DKMS
  module described enforcement it did not perform.
- **Why:** Users trusted a fix for the screen-freeze-on-resume bug that did not exist, and could
  not tell that it was missing.
- **Fix:** Reduce the module to an honest DMI banner (research showed no notifier event exists
  between panel-off and panel-on, so a notifier sleep would add zero discharge time). Delete the
  echo-only resume service and every reference to it. Add an optional `--kernel-src` clamp-patch
  step that runs dry first and warns instead of failing. Keep `video=efifb:nobgrt` and add
  `panel_orientation` tokens to the grub config. Correct the README and `CHANGES_AUDIT.md` claims.
- **How:** The module logs a breadcrumb only; the optional clamp is a separate, explicitly gated
  step; the resume-logic arithmetic was fixed under `set -e`.
- **Verified:** `scripts/test_display_fix_guards.sh` (10 cases) and a `--simulate 5/5` resume loop
  run. The real `dmesg` banner and 5 suspend/resume cycles are deferred (section 4).

### Phase 35: Installer and uninstaller were asymmetric (audit M1, M2, M11, N6)

- **Wrong:** Install and uninstall did not deploy or remove the same artifact set. GRUB was
  regenerated on one path only. Unit enablement differed between the installer, the `.deb` and
  the `.rpm`. Removal of drop-ins and state files was incomplete.
- **Why:** Uninstalling left the system in an inconsistent state, and reinstalling could not
  recover it.
- **Fix:** A single `deploy_manifest()` drives install, uninstall and a new
  `--verify [--root] [--removed]` command. GRUB is regenerated on both paths. The rescue shell
  supports `--uninstall` and `--verify`. All nine shipped units are enabled identically in
  `install_dkms.sh`, the debian `postinst` and the rpm `%post`. Optional removal blocks log named
  warnings when a package is absent.
- **How:** One manifest table is the single source of truth; `--verify` walks it and reports any
  drift; `.gitattributes` pins `*.sh` to `eol=lf` so WSL scripts do not break on CRLF.
- **Verified:** `scripts/test_installer_symmetry.sh` (17 cases). The real install sweep is
  deferred (section 4).

### Phase 36: Desktop session wiring (audit M3, M6, N7)

- **Wrong:** The tray autostart pointed at a binary that was never created. The tablet daemon ran
  as a context-less root system unit, so every session command silently did nothing. The docs
  claimed a GTK applet that did not exist.
- **Why:** The tray never started, and dock/undock handling could not work.
- **Fix:** Point the desktop `Exec` at `/usr/local/bin/d330-tray`. Move the tablet daemon to a
  systemd **user** unit at `/usr/lib/systemd/user/d330-tablet-daemon.service`, with
  `WantedBy=default.target` and `Wants/PartOf=graphical-session.target`, enabled through
  `systemctl --global enable` and shipped by all three packagers. Downgrade the false GTK claims
  to the honest standard-library notification helper. Add manifest kinds `unit-user` and
  `unit-user-enabled`.
- **How:** The unit inherits the graphical session environment, and the installer, the verify
  path and the uninstall path all understand the user-unit kinds.
- **Verified:** `scripts/test_tray_applet.sh` (9 cases) exits non-zero on a wrong `Exec`
  (mutation-proven), plus `scripts/test_installer_symmetry.sh` (17). Live GNOME dock/undock is
  deferred (section 4).

### Phase 37: No-op PWM and sensor tools (audit M4, M5, M17)

- **Wrong:** `tools/d330-backlight-pwm.py --apply` printed `[OK]` after only checking that a
  sysfs directory existed, and a `Type=oneshot` boot service faked a 1000 Hz PWM apply.
  `tools/d330-sensor-filter.py` exited after a fixed one-second loop, so its `Restart=on-failure`
  unit died permanently while the accelerometer claim (15 degree deadband) was never implemented.
- **Why:** Two subsystems reported success for work they never performed.
- **Fix:** Make PWM apply honest: require an `intel_reg` read-back delta before printing `[OK]`,
  otherwise print `[SKIP]` or `[FAIL]` and exit non-zero. The parser reads the value after the
  last `:` and targets `BXT_BLC_PWM_FREQ1` / `0xC8254` only. Delete the no-op PWM boot service
  (enabled units drop from 9 to 8). Rewrite the sensor filter as a `while True` daemon with clean
  `SIGTERM`/`SIGINT` handling, a `--cycles` / `--once` test hook, a `D330_IIO_BASE` seam, a real
  accelerometer deadband with hysteresis, and an `in_illuminance_raw` to `in_illuminance_input`
  fallback.
- **How:** Both tools now derive their success from an actual state change; the guards assert the
  no-false-success property.
- **Verified:** `scripts/test_noop_guards.sh` (5 cases, including a 62 second liveness run),
  wired into the aggregate runner.

### Phase 38: PipeWire DSP config was dead (audit M7)

- **Wrong:** The DSP fragments were deployed to `filter-chain.conf.d/`, which is only read by
  `pipewire -c filter-chain.conf` and never by the running server. They also contained invalid
  constructs (`label = biquad`, invalid `"Type"` controls, a nonexistent `limiter`, no `links`),
  and the two files shared a `filter_chain.nodes` variable that clobbered each other.
- **Why:** The speaker DSP and RNNoise microphone filter never loaded.
- **Fix:** Move both fragments to `etc/pipewire/pipewire.conf.d/` and rewrite them as valid
  inlined graphs (`bq_highpass`, `bq_peaking`, the builtin `clamp`, with explicit links naming the
  declared nodes). Give the RNNoise module `flags = [ nofail ]` and log a warning when the
  optional plugin is missing. Remove the false-success test masks so the microphone guard fails
  closed when the plugin is absent (`D330_LADSPA_DIRS` seam). Add a shared
  `scripts/lib_conf_check.sh` helper. Downgrade the audit's routing claim to the honest
  virtual-sink description. Ship the fragments from all three packagers.
- **How:** The fragments now deploy into the path the running daemon reads, with a structural
  check that validates the graph shape.
- **Verified:** `scripts/test_audio_dsp.sh --dry-run` (17) and `scripts/test_mic_rnnoise.sh
  --dry-run` (7). Live `pw-dump` is deferred (section 4).

### Phase 39: udev, hwdb and wireless did not match the target (audit M8, M9, M10, M15, M16)

- **Wrong:** The hwdb DMI patterns used a space-stripped form (`pvrLenovoideapadD330-*`) that can
  never match the real `pvrLenovo ideapad D330-*` modalias. Sensor udev globs were case-sensitive
  against `BOSC0200` and `ACPI0008`. `MODE` and `GROUP` were set on read-only sysfs attributes
  (no-ops). `ENV{SOUND_INITIALIZED}` and `ENV{WL_OUTPUT}` were dead. The wifi resume hook bounced
  the radio unconditionally, dropping VPN and SSH sessions on every wake. The refresh-screen tool
  force-rotated 90 degrees and reported success while changing nothing. `options rtl8821ce`,
  `iwlwifi` and `pcie_aspm` targeted absent modules or non-module parameters.
- **Why:** The rules silently did nothing, and the resume hook caused real connectivity loss.
- **Fix:** Use space-free `pn82H0` / `pn81MD` / `pn81H3` hwdb keys plus `evdev:` touchscreen keys.
  Use case-insensitive `[Bb][Oo][Ss][Cc]0200` and `[Aa][Cc][Pp][Ii]0008` globs. Remove the no-op
  and dead properties and document the root / `pkexec` requirement. Make the resume hook bounce
  only an enabled-but-wedged link. Make refresh-screen preserve the current rotation and exit
  non-zero when no display path ran. Restrict the wireless config to real modules
  (`rtw88_core`, `rtw88_pci`; `ant_sel` only on the out-of-tree `rtl8821ce`; drop all Intel and
  `pcie_aspm` options).
- **How:** A new guard scans every `options` line in the tree and asserts each module is real.
- **Verified:** `scripts/test_udev_hwdb_match.sh` (10 cases, scanning all 22 modprobe options and
  asserting every product code). On-device `udevadm test` / `modprobe -s` is deferred (section 4).

### Phase 40: Power stack had multiple writers per knob (audit M13, M14)

- **Wrong:** `lenovo-d330-power-tune.sh` wrote a boot-only CPU cap and a broad `power/control=auto`
  loop racing TLP. A udev rule forced `power/control` on PCI, USB, I2C and sound devices that TLP
  already manages. TLP set a sub-minimum `INTEL_GPU_MIN_FREQ_ON_AC=100` that the driver rejected on
  every AC event. `nowatchdog` disabled the lockup detection the device needs. thermald's zone
  `<Type>cpu</Type>` did not match the sysfs zone, and `d330-thermal-tune.sh` computed
  `$((pl1 / 1000000))` on a non-numeric `N/A`.
- **Why:** Knobs flapped between writers, the GPU frequency write was rejected, and lockup
  detection was off.
- **Fix:** Make the CPU performance cap AC-aware (100 on mains, 75 on battery) and re-apply it
  from a `SUBSYSTEM=="power_supply"` `ACTION=="change"` rule. Reduce udev to the eMMC host and the
  dock (two `power/control` lines) and make TLP the sole runtime-PM owner. Drop the sub-minimum
  GPU minimum, document the GLK maximum (650) and boost (700). Remove `nowatchdog` and leave the
  kernel watchdog defaults (a later review dropped the short-lived `softlockup_panic=1 panic=10`
  because a transient boot soft lockup would panic and auto-reboot). Point thermald at
  `x86_pkg_temp`, add numeric guards for
  PL1, PL2 and temperature, add an `ExecCondition` fallback, and declare thermald in debian
  `Recommends`.
- **How:** One writer per knob; the perf cap is re-applied on power-source change; the thermal
  script validates its inputs before using them.
- **Verified:** `scripts/test_power_stack.sh` (12 cases, non-vacuous, with a repo-wide
  `power/control` scan). On-device `tlp-stat` / powercap checks are deferred (section 4).

### Phase 41: Test harness could not fail (audit M12, N8)

- **Wrong:** 23 of the then-27 `test_*.sh` scripts exited zero no matter what, and their
  `--dry-run` modes validated nothing.
- **Why:** The suite gave false confidence. A broken feature would still show green.
- **Fix:** Add failure counters and non-zero exits across the always-green scripts, removing
  `cmd || true` and unconditional success. Gate live mutations behind `--apply` (thermals,
  boot_speed, battery_power, memory_storage). Fix parser and arithmetic bugs (`((x++))` under
  `set -e`, `--stress N` and `--cycle-test N` consuming their values, real daemon `--simulate-*`
  flags). Remove false `[OK]` output for missing subjects (cellular rules and FCC hook,
  tablet-osk daemon status, hardware toggle). Add `SCRIPT_DIR` CWD anchors. Make
  `build_live_iso.sh --dry-run` validate real prerequisites and make `test_iso_integrity.sh`
  inherit them. Add a meta-guard.
- **How:** `scripts/test_harness_trust.sh` (9 cases) has two parts. SC1 mutates five subjects and
  proves the suite fails (with an intact-baseline guard). SC2 statically scans for any mutation
  that is not gated behind `--apply`.
- **Verified:** All guard suites green through the aggregate runner.

### Phase 42: Repository and documentation were not release-clean (audit M17, N1 to N5, N7, N9, N10)

- **Wrong:** 50 shell scripts were tracked `100644` even though the README says to run
  `sudo ./scripts/install_dkms.sh`. The FCC unlock hook was an empty blob whose colon name had
  been lost, so the installer never matched it. `CHANGES_AUDIT.md` carried wrong values (the FBC
  setting, swappiness and scheduler, the `touch-mode` subcommand, the 1000 Hz PWM claim, the
  earlyoom prefer list, the 15 second PL2 window, `--avoid` versus `--ignore`, the wireless
  module, the tray description, the test count, and `power_cycle_delay_ms`). There was dead code
  and unclosed resource handles. The packagers piped every `cp` into `|| true`.
- **Why:** The repo contradicted itself, a shipped hook was empty, and a packaging build could
  succeed with an empty package.
- **Fix:** Track every `scripts/*.sh` and `tools/*.sh` (and `tools/d330-ctl`) as `100755` and add
  `chmod 755` in the packagers. Ship the FCC hook to `/etc/ModemManager/fcc-unlock.d/8086:7360`
  with a warn-on-missing branch. Reconcile every `CHANGES_AUDIT` contradiction against the code.
  Remove the dead code (`SW_LID`, an `except` shadow) and close the handles. Remove `cp ... || true`
  from all three packagers and declare the optional runtime dependencies (thermald, earlyoom,
  zram-generator, rnnoise, vainfo, desktop deps). Fix the README tree and `.desktop` hygiene. Add
  a repository-wide parity guard.
- **How:** `scripts/test_doc_parity.sh` (19 checks) reads each documentation claim and asserts it
  matches the code it describes, checks exec bits and zero-byte blobs, and is wired into the
  aggregate runner.
- **Verified:** `scripts/test_doc_parity.sh` (19), plus the code review and review-fix pass
  (see section 3). The real package build is deferred (section 4).

### Cross-phase gap found by the milestone audit (packaged installs)

- **Wrong:** The workspace installer renamed tools to suffix-free names in `/usr/local/bin`
  (`d330-sensor-filter.py` to `d330-sensor-filter`, and so on) but the `.deb`, `.rpm` and PKGBUILD
  copied `tools/d330-*` verbatim and renamed only the auto-hibernate daemon. The units they ship
  and enable reference the suffix-free names, so a packaged install enabled units whose `Exec`
  target did not exist. `lenovo-d330-power-tune.sh` was not shipped at all because the
  `tools/d330-*` glob misses the `lenovo-` prefix, and no packager shipped the tray autostart.
  The CI `.deb` build had the same mismatch and still used `cp ... || true`.
- **Why:** The primary install path was correct, but every packaged install shipped broken units.
  No single phase verification could see this, because it spans phases 36 and 42.
- **Fix:** All three packagers and the CI build now install tools under the same suffix-free
  basenames the installer uses, chmod the whole `/usr/local/bin`, ship
  `lenovo-d330-power-tune.sh`, ship the tray autostart, and the CI build no longer uses
  `cp ... || true`.
- **How:** A shared rename list maps each source file to its installed name, mirroring
  `install_dkms.sh`. The hibernate guard was updated to assert the rename in all three packagers.
- **Verified:** `test_hibernate_guards.sh` (21), `test_doc_parity.sh` (19),
  `test_installer_symmetry.sh` (17), and the aggregate runner, all green. Commit `5e4948b`.

## 3. Phase 42 code review and review-fix

After execution I ran an independent code review over the phase 42 diff and fixed the findings:

- `tools/d330-ctl` was tracked `100644` but installed as an executable command. Fixed to `100755`
  and added explicit `chmod 755` in the debian and rpm install steps.
- The declared RNNoise packages (`librnnoise-ladspa`, `rnnoise-ladspa`) do not exist. Replaced
  with the real runtime libraries and documented that the LADSPA plugin is optional and must be
  built manually.
- The packagers shipped the dev-only tools `d330-acpi-override.sh` and `d330-pen-config.sh`
  while `CHANGES_AUDIT.md` called them dev-only. Removed them from the packaged install.
- Corrected a stale path in `patches/cellular_storage/README.md`, removed a misleading "rename
  this file" note in the FCC hook header, and added a warn when the FCC source is missing.
- Hardened `scripts/test_doc_parity.sh`: also assert `enable_fbc=0` in the i915 modprobe conf,
  assert the FCC deploy, size blobs through `git cat-file`, match `AppIndicator` as well as
  `GTK3`, and count scripts through `git ls-files`.

## 4. Deferred items (documented, not skipped)

The development environment has no D330 hardware, no PipeWire daemon, no udev, no TLP and no
package toolchain. I recorded each hardware, daemon or build-only acceptance criterion as a
VERIFICATION override with a reason, and listed it in `STATE.md` for sign-off. The machine-checked
equivalent is green in every case. Re-run on a D330 with `/gsd-verify-work <N>`:

| Phase | Deferred check |
|-------|----------------|
| 32 | Physical mounted-target abort, on-target fstab and absent-card boot |
| 33 | `systemctl hibernate` round trip, on-device enable checks |
| 34 | `dmesg` DMI banner, 5 real suspend/resume cycles |
| 35 | Real install sweep, `systemctl is-enabled` for nine units |
| 36 | Live GNOME dock/undock |
| 38 | Live `pw-dump` for the DSP nodes |
| 39 | On-device `udevadm test` and `modprobe -s` |
| 40 | `tlp-stat` versus powercap agreement, clean AC/battery cycle, boot bench |
| 42 | Real `dpkg-buildpackage`, `makepkg`, `rpmbuild` failing on a broken copy step |

## 5. Commit index

Headline commits from the final phases and close:

| Commit | Description |
|--------|-------------|
| `46ad110` | chmod +x shell scripts and tools (phase 42) |
| `7f8400d` | deploy FCC unlock hook as `8086:7360` |
| `fdff32a` | remove dead code and fix resource handling |
| `a6417b8` | README tree, `.desktop` hygiene, dev-only notes |
| `efc2ec0` | 42-01 summary |
| `4d52ff7` | packagers fail loudly on a missing source, declare optional deps |
| `952a4bd` | add `test_doc_parity.sh`, wire into the storage runner |
| `247df1a` | reconcile `CHANGES_AUDIT` claims with code |
| `fe4b33e` | track the doc-parity guard as `100755` |
| `38b428f` | 42-02 summary |
| `0095cb5` | track `d330-ctl` as `100755` |
| `de97307` | chmod packaged tools, real RNNoise deps, drop dev-only tools |
| `52905bf` | correct FCC hook source path and header, warn on missing deploy |
| `6d35888` | document the RNNoise LADSPA plugin as manual and optional |
| `942d9b0` | harden the doc-parity guard |
| `ae21126` | keep the explicit daemon chmod alongside the glob |
| `f6300ed` | 42 review-fix report |
| `1321266` | phase 42 verification report |
| `05ba6ed` | UAT and verification override for the host-bound build |
| `0efe21d` | milestone audit and STATE |
| `5e4948b` | packaging Exec parity fix (cross-phase gap) |
| `0c787f0` | power README drift and deferred-item resolution |
| `4e1d136` | archive v7.0 milestone files (also tagged `v7.0`) |

Phases 32 to 41 each have their own commit series; see the phase directories under
`.planning/milestones/v7.0-phases/` and `git log`.

## 6. Known tech debt (non-blocking)

Recorded in `.planning/milestones/v7.0-MILESTONE-AUDIT.md`:

- The `exec-optional` manifest kind verifies existence, not the executable bit.
- A stale `apt install librnnoise-ladspa` message remains in `test_mic_rnnoise.sh`.
- The packagers ship a documented subset of the configuration files.
- A few installer `--dry-run` and optional-skip UX gaps (some optional blocks skip silently, and
  `--dry-run` requires build tools present).
- The Nyquist `VALIDATION.md` files predate the `status:` field, so `/gsd-validate-phase` should
  reconcile them.

## 7. Review checklist for the reviewer

Please try to falsify these claims:

1. Does `install_dkms.sh` deploy and remove exactly the same artifact set, and does `--verify`
   catch a missing required artifact? (Phase 35, `deploy_manifest`, `test_installer_symmetry.sh`.)
2. Does every shipped and enabled systemd unit's `ExecStart` resolve to a file that the installer
   and each packager actually install? (Phase 36 plus the packaging fix, `test_hibernate_guards.sh`,
   `test_doc_parity.sh`.)
3. Can the microSD tool write to the root device through any path? (Phase 32,
   `test_microsd_guards.sh`.)
4. Does any test script still exit zero on a failure, or perform a mutation without `--apply`?
   (Phase 41, `test_harness_trust.sh`.)
5. Does any guard pass while the documentation it describes is wrong, or while an installed file
   is not executable? (Phase 42, `test_doc_parity.sh`.)
6. Do the PipeWire graphs name only defined nodes and links, and does the microphone guard fail
   closed when the plugin is absent? (Phase 38, `test_audio_dsp.sh`, `test_mic_rnnoise.sh`.)
7. Are the deferred items genuinely untestable in this environment, or did any hide a machine
   checkable defect? (Section 4, phase VERIFICATION files.)
