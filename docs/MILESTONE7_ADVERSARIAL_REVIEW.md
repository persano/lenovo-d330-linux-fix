# Adversarial Review: Lenovo D330 Milestone 7 Remediation (v7.0)

Review performed directly against repository files, system configurations, and WSL execution environment.

---

## 1. Findings by Subsystem & Severity

### Finding 1: MicroSD root detection bypass via LUKS, LVM, or symlinks
- **Location:** `tools/d330-microsd-setup.sh:114-135` (`guard_not_root_device`)
- **Severity:** HIGH
- **Problem & Scenario:** `guard_not_root_device` uses naive string prefix matching (`case "$ROOT_SRC" in "$TARGET_DEV"*)`). Neither `$ROOT_SRC` nor `$TARGET_DEV` passed through `realpath`. If root is mounted from LUKS container (`/dev/mapper/rootvg-root` or `/dev/dm-0`), symlink (`/dev/disk/by-id/...`), or device mapper, string matching returns false. Operator running `--format --device /dev/mmcblk0` or symlink passes guards and wipes root disk.
- **Proposed Change:** Canonicalize all paths with `realpath` and compare parent block device names:
  ```bash
  guard_not_root_device() {
      local ROOT_SRC REAL_ROOT REAL_TARGET
      ROOT_SRC=$(findmnt -n -o SOURCE / 2>/dev/null) || return 1
      REAL_ROOT=$(realpath "$ROOT_SRC" 2>/dev/null || echo "$ROOT_SRC")
      REAL_TARGET=$(realpath "$TARGET_DEV" 2>/dev/null || echo "$TARGET_DEV")

      # Resolve parent disk for partition nodes
      local ROOT_DISK TARGET_DISK
      ROOT_DISK=$(lsblk -no PKNAME "$REAL_ROOT" 2>/dev/null || basename "$REAL_ROOT")
      TARGET_DISK=$(lsblk -no PKNAME "$REAL_TARGET" 2>/dev/null || basename "$REAL_TARGET")

      if [ "$REAL_ROOT" = "$REAL_TARGET" ] || [ "$ROOT_DISK" = "$TARGET_DISK" ] || \
         [[ "$REAL_ROOT" == "$REAL_TARGET"* ]] || [[ "$REAL_TARGET" == "$REAL_ROOT"* ]]; then
          log_err "[GUARD] root-device: FAIL (target matches root: root=$REAL_ROOT target=$REAL_TARGET)"
          return 1
      fi
      log_ok "[GUARD] root-device: PASS (root=$REAL_ROOT target=$REAL_TARGET)"
  }
  ```
- **Judgment:** Partially agree. Defect real, but path matching incomplete; fails on standard encrypted/mapped setups.

---

### Finding 2: Tablet daemon user unit fails to start due to `Nice=-5`
- **Location:** `patches/dock/usr/lib/systemd/user/d330-tablet-daemon.service:15`
- **Severity:** HIGH
- **Problem & Scenario:** Phase 36 moved tablet daemon from root system unit to unprivileged systemd user unit (`/usr/lib/systemd/user/`), but retained `Nice=-5`. Unprivileged user processes lack `CAP_SYS_NICE`. When systemd user manager executes unit, `setpriority()` fails with `EPERM`/`EACCES`. Systemd aborts spawn with error `Failed at step NICE spawning ...: Operation not permitted`. Unit enters crash restart loop and gets disabled by rate limiter.
- **Proposed Change:** Remove `Nice=-5` from user unit:
  ```ini
  [Service]
  Type=simple
  ExecStart=/usr/local/bin/d330-tablet-daemon --daemon
  Restart=always
  RestartSec=3
  StandardOutput=journal
  StandardError=journal
  ```
- **Judgment:** Disagree with implementation. Moving to user unit without dropping root scheduling privileges breaks unit execution completely.

---

### Finding 3: WiFi resume hook ignores carrier status and bounces active connection
- **Location:** `patches/wireless/etc/systemd/system-sleep/lenovo-d330-wifi-resume.sh:13-44`
- **Severity:** HIGH
- **Problem & Scenario:** Report claims hook bounces radio "only on enabled-but-wedged link". Script reads `carrier` and `operstate` (lines 13-14), prints them, and NEVER checks them. If `radio_enabled=1`, script unconditionally executes `nmcli device connect "$ifname"`. If interface already connected or negotiating on wake, `nmcli device connect` fails non-zero. Script enters failure branch: executes `nmcli radio wifi off`, sleeps, `nmcli radio wifi on`. Drops active SSH/VPN sessions on wake—exact bug claimed fixed.
- **Proposed Change:** Gate reconnection strictly on down state (`carrier == 0` or `operstate != "up"`):
  ```sh
  if [ "$radio_enabled" -ne 1 ]; then
      echo "[d330-wifi-resume] $ifname: Wi-Fi radio disabled/blocked; not reconnecting."
      break
  fi

  # Skip reconnect if link carrier already up
  if [ "$carrier" = "1" ] && [ "$operstate" = "up" ]; then
      echo "[d330-wifi-resume] $ifname: link already operational; skipping bounce."
      break
  fi

  # Device present but link wedged
  if command -v nmcli >/dev/null 2>&1; then
      if ! nmcli device connect "$ifname" >/dev/null 2>&1; then
          nmcli radio wifi off >/dev/null 2>&1 || true
          sleep 0.2
          nmcli radio wifi on >/dev/null 2>&1 || true
      fi
  fi
  ```
- **Judgment:** Disagree. Fix incomplete; diagnostic variables read but omitted from control flow.

---

### Finding 4: Sensor filter daemon is pure stdout logger with no system actuation
- **Location:** `tools/d330-sensor-filter.py:129-152`
- **Severity:** MEDIUM
- **Problem & Scenario:** Report claims "Rewrite the sensor filter as a while True daemon... with a real accelerometer deadband with hysteresis". Daemon calculates angle, checks 15-degree delta, and executes only: `print(f"Accel: tilt={angle:.1f} deg ... -> rotation decision")`. It never interacts with `iio-sensor-proxy`, D-Bus, display server, or sysfs. Daemon runs permanently at 5 Hz poll loop consuming CPU on 6W fanless tablet without rotating screen or adjusting brightness.
- **Proposed Change:** Either emit rotation to desktop session via D-Bus / `xrandr` / `wlr-randr`, or document honesty status as debug utility and retire background service from `multi-user.target`.
- **Judgment:** Partially agree. Infinite loop fixes service exit crash, but tool remains no-op theater.

---

### Finding 5: Backlight PWM tool is non-idempotent; fails on repeated apply
- **Location:** `tools/d330-backlight-pwm.py:145-150`
- **Severity:** MEDIUM
- **Problem & Scenario:** Script requires read-back difference (`after != before`). If `--apply` runs on system where target divider already set (second boot, resume hook, manual repeat), `after == before`. Tool outputs `[FAIL] PWM register unchanged ...` and exits 1. Harness test `pwm-readback-no-delta-fail` codifies this bug by demanding failure code 1.
- **Proposed Change:** Detect when register already matches target divider and exit 0:
  ```python
  if after == target:
      if before == target:
          print(f"[OK] PWM {name}: already at target divider (0x{after:08X})")
      else:
          print(f"[OK] PWM {name}: 0x{before:08X} -> 0x{after:08X}")
      return
  ```
- **Judgment:** Disagree with design. Over-zealous anti-false-positive check broke basic Unix idempotency.

---

### Finding 6: PipeWire speaker DSP filter graph lacks channel port connections
- **Location:** `patches/audio_dsp/etc/pipewire/pipewire.conf.d/50-lenovo-d330-speaker-dsp.conf:17-60`
- **Severity:** MEDIUM
- **Problem & Scenario:** Config declares stereo sink (`audio.channels = 2`, `audio.position = [ FL FR ]`), but `filter.graph` contains single mono pipeline (`eq_hp -> eq_mid -> eq_air -> limit`). Crucially, `filter.graph` defines no `inputs = [ ... ]` and no `outputs = [ ... ]` arrays. PipeWire `module-filter-chain` cannot map 2 stereo capture channels and 2 playback channels to single unmapped mono pipeline. Module fails to link or downmixes incorrectly.
- **Proposed Change:** Define explicit `inputs` and `outputs` arrays in `filter.graph` or split into left/right processing paths:
  ```spa-json
  filter.graph = {
      nodes = [
          { type = builtin name = eq_hp label = bq_highpass control = { "Freq" = 130.0 "Q" = 0.707 } }
          { type = builtin name = eq_mid label = bq_peaking control = { "Freq" = 2800.0 "Q" = 1.2 "Gain" = 3.5 } }
          { type = builtin name = eq_air label = bq_peaking control = { "Freq" = 8000.0 "Q" = 1.0 "Gain" = 2.0 } }
          { type = builtin name = limit label = clamp control = { "Min" = -0.8414 "Max" = 0.8414 } }
      ]
      links = [
          { output = "eq_hp:Out"  input = "eq_mid:In" }
          { output = "eq_mid:Out" input = "eq_air:In" }
          { output = "eq_air:Out" input = "limit:In" }
      ]
      inputs  = [ "eq_hp:In" ]
      outputs = [ "limit:Out" ]
  }
  ```
- **Judgment:** Partially agree. Moving files to `pipewire.conf.d` correct, but graph definition incomplete for stereo sink.

---

### Finding 7: Distribution packaging violates FHS and distro policies
- **Location:** `packaging/debian/rules:9`, `packaging/rpm/lenovo-d330-fix.spec:34`, `packaging/arch/PKGBUILD:23`
- **Severity:** MEDIUM
- **Problem & Scenario:**
  1. All packagers install binaries into `/usr/local/bin`. Direct violation of Debian Policy (§9.1.2), Fedora Packaging Guidelines, and Arch Standards. Distro packages must install to `/usr/bin`.
  2. Arch `PKGBUILD` defines `post_install()` directly inside `PKGBUILD`. `makepkg` ignores `post_install()` in `PKGBUILD`; pacman hooks require external `.install` script declared via `install=lenovo-d330-fix.install`.
  3. `packaging/debian/changelog`, `packaging/rpm/lenovo-d330-fix.spec`, `PKGBUILD`, and CI workflow `.github/workflows/build-packages.yml:38` all hardcode version `5.0.0-1` instead of `7.0.0`.
  4. Packagers depend on `dkms` but install no DKMS source or config under `/usr/src`.
- **Proposed Change:** Target `/usr/bin`, move Arch hook to `.install`, synchronize version numbers to `7.0.0`:
  ```bash
  # in debian/rules, spec, PKGBUILD:
  mkdir -p $(DESTDIR)/usr/bin
  # change install target to /usr/bin and update unit ExecStart paths
  ```
- **Judgment:** Disagree. Package files are unmaintained shims with basic packaging syntax errors.

---

### Finding 8: `softlockup_panic=1 panic=10` introduces boot loop risk
- **Location:** `patches/fastboot/etc/default/grub.d/52-lenovo-d330-fastboot.cfg:7`
- **Severity:** MEDIUM
- **Problem & Scenario:** To fix `nowatchdog`, fastboot config sets `softlockup_panic=1 panic=10`. Fanless Intel Gemini Lake tablet (N4000/N4100/N5000) under heavy boot load (e.g., initial swapfile creation on eMMC or earlyoom pressure) can trigger temporary soft lockup warnings. Forcing kernel panic plus automatic reboot causes infinite boot reboot loop.
- **Proposed Change:** Drop `softlockup_panic=1` and `panic=10`. Let watchdog log stack traces without kernel panic:
  ```cfg
  GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT} no_timer_check quiet loglevel=3 rd.systemd.show_status=auto"
  ```
- **Judgment:** Disagree. Extreme overreaction to `nowatchdog` audit finding.

---

### Finding 9: Guard tests provide false confidence via vacuous assertions
- **Location:** `scripts/test_udev_hwdb_match.sh:118-124`, `scripts/test_harness_trust.sh:260-267`, `scripts/test_doc_parity.sh:183-189`
- **Severity:** LOW
- **Problem & Scenario:**
  1. `test_udev_hwdb_match.sh` logs "all shipped modprobe options name real modules (22 checked)". It only checks that options do not match 3 blocked words (`pcie_aspm iwlwifi iwlmvm`). Any fabricated module name passes.
  2. `test_harness_trust.sh` SC2 checks that `--apply)` and `APPLY` string appear in file before mutation line. Does not verify whether mutation sits inside conditional block.
  3. `test_doc_parity.sh` matches bare strings in markdown files (e.g. `grep -qi 'removed' "$AUDIT"`).
- **Proposed Change:** In `test_udev_hwdb_match.sh`, validate module names against kernel modules index (`modinfo` or `/lib/modules/$(uname -r)/modules.builtin` / `modules.dep`).
- **Judgment:** Partially agree. Test suite improved over previous state, but assertions overclaim semantic coverage.

---

### Finding 10: DKMS module is dummy logging breadcrumb
- **Location:** `patches/dkms/lenovo-d330-fix/lenovo_d330_fix.c:110-125`
- **Severity:** LOW / ARCHITECTURAL
- **Problem & Scenario:** DKMS module named `lenovo-d330-fix` performs zero hardware configuration, registers no quirks, and sets no registers. It hooks PM notifier only to log that it does not enforce timing. Entire build/install DKMS pipeline compiles C code to print warning to `dmesg`.
- **Proposed Change:** Acknowledge in project documentation that kernel module provides no functional remediation; real display timing fix exists solely in kernel source patch (`patches/d330_display_resume_fix.patch`).
- **Judgment:** Agree with technical root cause analysis (PM notifier cannot enforce panel discharge timing), but shipping dummy DKMS module creates false maintenance overhead.

---

## 2. Decisions Agreed With

- **Phase 32:** Dropping `-F` force flag and adding `udevadm settle` / `partprobe` in `tools/d330-microsd-setup.sh`.
- **Phase 32:** Locking `fstab` mount options to `nofail,x-systemd.device-timeout=10s` to prevent emergency shell boot hangs.
- **Phase 33:** Identifying that zram swap cannot serve as hibernate resume target.
- **Phase 33:** Clamping swapfile size between 4 GB and 8 GB with free disk space check before creation.
- **Phase 34:** Removing non-functional echo-based resume service.
- **Phase 35:** Creating unified `deploy_manifest` table and adding `--verify` drift detector.
- **Phase 35:** Regenerating GRUB on both install and uninstall paths.
- **Phase 37:** Removing dead `lenovo-d330-backlight-pwm.service` boot unit.
- **Phase 38:** Moving PipeWire fragments from inert `filter-chain.conf.d` to `pipewire.conf.d`.
- **Phase 39:** Correcting hwdb DMI patterns from space-stripped keys to `pn82H0`/`pn81MD`/`pn81H3`.
- **Phase 39:** Dropping invalid sysfs `MODE`/`GROUP` assignments in hardware rules.
- **Phase 40:** Designating TLP as single owner of runtime PM and removing conflicting udev power rules.
- **Phase 40:** Correcting `INTEL_GPU_MIN_FREQ_ON_AC` to prevent driver rejection on Gemini Lake.
- **Phase 41:** Adding failure counters and removing unconditional `|| true` success masks across test harness.
- **Phase 42:** Setting git file mode `100755` on all executable shell scripts.
- **Phase 42:** Renaming ModemManager FCC unlock hook to `8086:7360` target.

---

## 3. Changes Required Before Shipping

1. **Remove `Nice=-5`** from `patches/dock/usr/lib/systemd/user/d330-tablet-daemon.service`.
2. **Fix WiFi resume hook logic** in `patches/wireless/etc/systemd/system-sleep/lenovo-d330-wifi-resume.sh` to check `$carrier` and `$operstate` before calling `nmcli device connect`.
3. **Add path canonicalization (`realpath`)** to `guard_not_root_device` in `tools/d330-microsd-setup.sh`.
4. **Fix PWM idempotency** in `tools/d330-backlight-pwm.py` so already-applied target divider returns exit code 0.
5. **Drop `softlockup_panic=1 panic=10`** from `patches/fastboot/etc/default/grub.d/52-lenovo-d330-fastboot.cfg`.
6. **Add `inputs` and `outputs` arrays** to `filter.graph` in `patches/audio_dsp/etc/pipewire/pipewire.conf.d/50-lenovo-d330-speaker-dsp.conf`.
7. **Fix packaging paths and hooks:**
   - Migrate `/usr/local/bin` to `/usr/bin` in packaging rules.
   - Move Arch install script to `lenovo-d330-fix.install`.
   - Update version strings to `7.0.0` in Debian, RPM, and Arch metadata.

---

## 4. Overall Verdict & Hardware Test Priority

**Verdict:** **NOT READY FOR UNATTENDED DEPLOYMENT (CONDITIONALLY TESTABLE WITH FIXES 1 & 2 APPLIED).**
Installer and cleanup logic significantly improved over prior milestone, but runtime crashes exist in desktop user unit (`Nice=-5`), WiFi resume hook, and package installations.

### What to test first on real hardware:
1. **Desktop session spawn:** Check `systemctl --user status d330-tablet-daemon.service` to verify process starts without `EPERM` nice-level crash.
2. **WiFi suspend/resume:** Connect over SSH, trigger sleep (`systemctl suspend`), wake tablet, verify SSH connection stays alive and radio does not bounce.
3. **Display wake test:** Verify whether panel recovers from suspend without the out-of-tree kernel PPS patch (Option 2).
4. **MicroSD guard check:** Run `d330-microsd-setup.sh --format --device /dev/mmcblk0` on live root; verify refusal.
