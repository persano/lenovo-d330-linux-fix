# Phase 33: Low-Battery Hibernate Feasibility - Pattern Map

**Mapped:** 2026-10-08
**Files analyzed:** 11 (5 new, 6 modify)
**Analogs found:** 11 / 11

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `tools/d330-auto-hibernate.py` (modify) | daemon/script | event-driven (udev oneshot) | `tools/d330-auto-hibernate.py` (self) + guard posture from `tools/d330-microsd-setup.sh` | exact (self-modify; posture analog = phase 32) |
| `patches/power_hibernate/etc/systemd/system/d330-auto-hibernate.service` (modify) | config (unit) | event-driven | same file (self) + `patches/sensors/etc/systemd/system/d330-sensor-filter.service` | exact (self-modify) |
| NEW `patches/power_hibernate/etc/systemd/system/d330-swapfile.service` (name per discretion) | config (unit) | file-I/O (idempotent swapfile creation) | `patches/power_hibernate/etc/systemd/system/d330-auto-hibernate.service` + `patches/dkms/etc/systemd/system/lenovo-d330-resume.service` (oneshot form) | role-match |
| NEW `patches/power_hibernate/etc/default/grub.d/53-lenovo-d330-resume.cfg` (install-time rendered template) | config | file-I/O (cmdline injection) | `patches/boot_orientation/etc/default/grub.d/50-lenovo-d330-boot.cfg` | exact |
| `scripts/install_dkms.sh` (modify: enable line, unit copy, resume activation step, uninstall symmetry) | installer script | file-I/O / batch | same file (self) — grub.d block `:186-194`, service copy `:279-284`, enable block `:286-294`, uninstall `:409/:427-438` | exact (self-modify) |
| `packaging/debian/postinst` (modify: enable) | installer/packaging | file-I/O | same file (self), enable block `:11-18` | exact (self-modify) |
| `packaging/rpm/lenovo-d330-fix.spec` (modify: %post enable) | installer/packaging | file-I/O | same file (self), %post `:38-44` | exact (self-modify) |
| `patches/power_hibernate/etc/udev/rules.d/99-lenovo-d330-battery-critical.rules` (comment only) | config (udev rule) | event-driven | same file (self) | exact (self-modify) |
| `patches/power_hibernate/README.md` (docs) | docs | — | same file (self) | exact (self-modify) |
| NEW `scripts/test_hibernate_guards.sh` | test | unit/fixture-driven | `scripts/test_microsd_guards.sh` (phase 32, 26-case suite) | exact |
| `scripts/test_storage_cellular.sh` (modify: delegate new suite) | test harness | delegation | same file (self), delegate pattern `:59-70` | exact (self-modify) |

**Wave 0 gaps called out by RESEARCH:** new suite + fixtures, env seam in `tools/d330-auto-hibernate.py`, delegate line in `scripts/test_storage_cellular.sh`.

## Pattern Assignments

### `tools/d330-auto-hibernate.py` (daemon/script, event-driven)

**Analog:** the file itself (57 lines) + phase-32 guard posture from `tools/d330-microsd-setup.sh`

**Current structure** (lines 1-10, imports are stdlib-only — keep it that way):
```python
#!/usr/bin/env python3
"""
Lenovo IdeaPad D330-10IGL Critical Low-Battery Auto-Hibernate Daemon
Monitors battery capacity and safely suspends to disk at <5% to prevent data loss.
"""

import sys
import os
import subprocess
import time
```

**Core pattern to modify** (lines 34-50) — the silent-failure line is `:48`, no rc check:
```python
def check_and_hibernate(dry_run=False):
    cap, status = get_battery_info()
    if cap is None:
        print("[INFO] No battery power supply detected in current environment.")
        return

    print(f"Battery: {cap}% ({status}) - Critical threshold: {CRITICAL_THRESHOLD_PERCENT}%")

    if cap <= CRITICAL_THRESHOLD_PERCENT and status.lower() == "discharging":
        print(f"[CRITICAL] Battery at {cap}%! Initiating system hibernate...")
        if dry_run:
            print("[DRY-RUN] sync && systemctl hibernate (skipped in dry run)")
        else:
            os.system("sync")
            subprocess.run(["systemctl", "hibernate"])   # :48 — return discarded (audit N5)
    else:
        print("[OK] Battery level safe.")
```

**Env-seam pattern to add** (RESEARCH Q6.2 — tests drive fixtures through env vars, no root):
```python
PROC_SWAPS = os.environ.get("D330_PROC_SWAPS", "/proc/swaps")
SYS_POWER = os.environ.get("D330_SYS_POWER", "/sys/power")
```

**Guard/emit posture (phase 32, copy markers verbatim):** from `tools/d330-microsd-setup.sh:85-104` — each guard prints exactly one `[GUARD] ...: PASS|FAIL` line; fail path calls `log_err` with the reason before returning non-zero:
```bash
log_err "[GUARD] mountpoints: FAIL (mounted at: $line)"      # d330-microsd-setup.sh:100
log_ok  "[GUARD] mountpoints: PASS (no mounted partitions on $TARGET_DEV)"  # :104
```
Map to python: `[ERROR] hibernate skipped: only zram swap present ...` + `sync` + `systemctl suspend` with rc captured (locked in CONTEXT); `--dry-run` prints swap table + `[DRY-RUN]` action line. Fix the two unclosed `open()` calls at `:30-31` while touching the file. Threshold logic (`CRITICAL_THRESHOLD_PERCENT = 5`, discharging) untouched.

**Validation:** parse `/proc/swaps` defensively (skip header, tolerate malformed lines, never crash) — RESEARCH Security Domain V5.

---

### `patches/power_hibernate/etc/systemd/system/d330-auto-hibernate.service` (config, event-driven)

**Analog:** same file (self) — full current content (10 lines):
```ini
[Unit]
Description=Lenovo IdeaPad D330 Low Battery Hibernate Daemon
After=power-profiles-daemon.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/d330-auto-hibernate.py    # ← MISMATCH: installer ships no .py suffix

[Install]
WantedBy=multi-user.target
```

**Fix:** `ExecStart=/usr/local/bin/d330-auto-hibernate` (install path is the contract — `scripts/install_dkms.sh:243-245` copies to `/usr/local/bin/d330-auto-hibernate`, no extension). Keep `Type=oneshot` (RESEARCH Q5 proved `SYSTEMD_WANTS` re-fires per udev event for finished oneshots; `Type=simple` would break re-fire). Add a comment in the unit citing the re-fire rationale (discretion).

**Unit style reference** — `patches/sensors/etc/systemd/system/d330-sensor-filter.service:1-13` (long-running form, `After=` + `ConditionPathExists=` + `Restart=`):
```ini
[Unit]
Description=Lenovo IdeaPad D330 Sensor Debounce and ALS Filter Service
After=iio-sensor-proxy.service
ConditionPathExists=/sys/bus/iio/devices

[Service]
Type=simple
ExecStart=/usr/local/bin/d330-sensor-filter.py --monitor
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

---

### NEW `patches/power_hibernate/etc/systemd/system/d330-swapfile.service` (config, file-I/O)

**Analog:** `patches/dkms/etc/systemd/system/lenovo-d330-resume.service` (oneshot shape, full, 10 lines) + the hibernate service above:
```ini
[Unit]
Description=Lenovo IdeaPad D330 Post-Resume Display Stabilization
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'if [ -d /sys/class/drm/card0-eDP-1 ]; then echo "Resumed - ..."; fi'

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
```

**Unit conventions to copy:** `Type=oneshot`, `WantedBy=multi-user.target` (or the appropriate target), `Description=Lenovo IdeaPad D330 ...`. Per RESEARCH §1: `ConditionPathExists=!/var/swapfile` create path (dd + `chmod 600` + `mkswap` + activate), else ensure active; **never recreate an existing file** (R4: recreation invalidates `resume_offset`). Guarded by free-space check with loud `[WARN]` + non-zero on insufficient headroom. Name per discretion (recommend `d330-swapfile.service`).

**Deployment note:** `packaging/rpm/lenovo-d330-fix.spec:36` globs `patches/*/etc/systemd/system/*.service` → the new unit ships in the RPM automatically; only a `%post` enable line is needed. Debian/install script need an explicit copy line (below).

---

### NEW `patches/power_hibernate/etc/default/grub.d/53-lenovo-d330-resume.cfg` (config, file-I/O)

**Analog:** `patches/boot_orientation/etc/default/grub.d/50-lenovo-d330-boot.cfg` (full, 14 lines) — existing snippet style:
```bash
# GRUB bootloader configuration for Lenovo IdeaPad D330-10IGL
# Fixes early kernel console rotation (fbcon), Plymouth boot splash, and GRUB menu font

# Force fbcon rotation (rotate:1 = 90 degrees clockwise for native portrait panel)
GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT} fbcon=rotate:1 video=efifb:nobgrt i915.enable_psr=0 i915.enable_fbc=0"
```

**Pattern to copy:** append-style `GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT} ..."` — the resume snippet appends `resume=UUID=<uuid> resume_offset=<offset>` **rendered at install time with real values** (ship a template + install-time render; never hardcode machine state). RESEARCH correction: `swapon --show=OFFSET` does not exist — use `filefrag -v /var/swapfile` first-extent `physical` (systemd computes it the same way, `hibernate-util.c:247-250`).

**Copy site pattern** — `scripts/install_dkms.sh:186-194`:
```bash
# Deploy GRUB and Initramfs boot orientation and fastboot hooks
if [ -d "/etc/default/grub.d" ]; then
    [ -f "${REPO_ROOT}/patches/boot_orientation/etc/default/grub.d/50-lenovo-d330-boot.cfg" ] && \
        cp "${REPO_ROOT}/patches/boot_orientation/etc/default/grub.d/50-lenovo-d330-boot.cfg" /etc/default/grub.d/
    ...
fi
```
Phase 33 must ADD what the repo never had: run the detected mkconfig (`update-grub` → `grub2-mkconfig` → `grub-mkconfig`), then `grep -q "resume_offset=" /boot/grub/grub.cfg` to verify; no mkconfig binary + no `/etc/default/grub` → print exact required cmdline, exit non-zero (locked).

---

### `scripts/install_dkms.sh` (installer script, file-I/O)

**Analog:** the file itself — three sections to extend.

**1. Service copy block (`:279-284`) — add the new swapfile unit beside the hibernate service:**
```bash
[ -f "${REPO_ROOT}/patches/power_hibernate/etc/systemd/system/d330-auto-hibernate.service" ] && \
    cp "${REPO_ROOT}/patches/power_hibernate/etc/systemd/system/d330-auto-hibernate.service" /etc/systemd/system/
```

**2. Enable block (`:286-294`) — currently ends at `d330-thermal.service`, never enables hibernate (success criterion 3 false):**
```bash
systemctl daemon-reload || true
systemctl enable lenovo-d330-resume.service || true
systemctl enable d330-tablet-daemon.service 2>/dev/null || true
...
systemctl enable d330-sensor-filter.service 2>/dev/null || true
systemctl enable d330-thermal.service 2>/dev/null || true
log_ok "Enabled systemd background units."
```
Add: `systemctl enable d330-auto-hibernate.service 2>/dev/null || true` + the swapfile unit, before `log_ok`.

**3. Uninstall symmetry (`:409`, `:427-438`) — add the new unit to both lists:**
```bash
rm -f /usr/local/bin/d330-auto-hibernate                                    # :409
systemctl disable --now d330-auto-hibernate.service >/dev/null 2>&1 || true # :428
rm -f /etc/systemd/system/d330-auto-hibernate.service                       # :437
```

**4. Daemon install path (`:243-245`) — the contract the service file must match:**
```bash
[ -f "${REPO_ROOT}/tools/d330-auto-hibernate.py" ] && \
    cp "${REPO_ROOT}/tools/d330-auto-hibernate.py" /usr/local/bin/d330-auto-hibernate && \
    chmod +x /usr/local/bin/d330-auto-hibernate
```

**Phase 32 guard posture to reuse in the new resume-activation step:** guards fail closed with their own `[GUARD]`-style message, `[DRY-RUN]` lines instead of execution, honest success only on genuine completion. fstab verify-before-append seam lives in `tools/d330-microsd-setup.sh:361` (`FSTAB_FILE="${D330_FSTAB:-/etc/fstab}"`), `:384` (`[DRY-RUN] Append to ...`), `:422` (`already present`) — copy this shape for the `/var/swapfile none swap sw 0 0` fstab line (RESEARCH R5).

---

### `packaging/debian/postinst` (installer/packaging, file-I/O)

**Analog:** the file itself — enable block (lines 11-18), currently 6 units, no hibernate:
```sh
    # Enable background services
    systemctl daemon-reload || true
    systemctl enable lenovo-d330-resume.service 2>/dev/null || true
    systemctl enable d330-tablet-daemon.service 2>/dev/null || true
    systemctl enable lenovo-d330-power.service 2>/dev/null || true
    systemctl enable d330-hardware-state.service 2>/dev/null || true
    systemctl enable lenovo-d330-backlight-pwm.service 2>/dev/null || true
    systemctl enable d330-sensor-filter.service 2>/dev/null || true
```
Add both units after `:18`, same `2>/dev/null || true` idiom. Note `:21-23` already runs `update-initramfs -u` (RESEARCH R1 mitigation hook).

---

### `packaging/rpm/lenovo-d330-fix.spec` (installer/packaging, file-I/O)

**Analog:** the file itself — `%post` (lines 38-44), enables only 3 units:
```spec
%post
systemd-hwdb update || true
udevadm trigger || true
 systemctl daemon-reload || true
systemctl enable lenovo-d330-resume.service 2>/dev/null || true
systemctl enable d330-tablet-daemon.service 2>/dev/null || true
systemctl enable lenovo-d330-power.service 2>/dev/null || true
```
Add `systemctl enable d330-auto-hibernate.service 2>/dev/null || true` + swapfile unit after `:44`. **No `%install` change needed** — `:36` globs `patches/*/etc/systemd/system/*.service`. No `%preun` exists at all (R8) — enable-only, note gap for Phase 35.

---

### `patches/power_hibernate/etc/udev/rules.d/99-lenovo-d330-battery-critical.rules` (config, event-driven — comment only)

**Analog:** the file itself (full, 4 lines):
```udev
# Lenovo IdeaPad D330-10IGL Low Battery udev rule
# Triggers auto-hibernate service when battery discharge state updates

SUBSYSTEM=="power_supply", ATTR{type}=="Battery", ATTR{status}=="Discharging", ATTR{capacity}=="[0-5]", TAG+="systemd", ENV{SYSTEMD_WANTS}="d330-auto-hibernate.service"
```
Add a comment above line 4: `ATTR{capacity}=="[0-5]"` is a udev glob matching the single characters `0`–`5` (udev(7): "Matches any single character specified within the brackets"), correct as-is; must not be "fixed" into regex/range semantics. `TAG+="systemd"` is mandatory for `SYSTEMD_WANTS` — do not touch. No functional change.

---

### `patches/power_hibernate/README.md` (docs)

**Analog:** the file itself (subsystem install docs). Content anchors from RESEARCH: swapfile holds an unencrypted memory image after hibernate (document, don't silently ship); hibernate needs Secure Boot off or lockdown relaxed (R3); no-GRUB manual cmdline step; `filefrag` offset tooling (NOT `swapon --show=OFFSET`).

---

### NEW `scripts/test_hibernate_guards.sh` (test, unit/fixture-driven)

**Analog:** `scripts/test_microsd_guards.sh` (phase 32, 742 lines) — copy the whole skeleton.

**Header + setup (lines 1-52):**
```bash
#!/usr/bin/env bash
# ==============================================================================
# scripts/test_microsd_guards.sh
#
# PATH-shim guard suite for tools/d330-microsd-setup.sh (Phase 32, audit C1).
# ...
# Cases (26): ...
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"
```

**Usage/arg parsing (lines 29-45)** — `-h|--help` banner, unknown option → usage + exit 1. **Banner + counters (lines 47-52):**
```bash
echo "=========================================================="
echo " Lenovo D330 MicroSD Guard Suite (PATH-shim harness)      "
echo "=========================================================="

passed=0
failed=0
```

**Assertion helpers (lines 184-244)** — per-case `CASE_FAIL` accumulation, safe under `set -e`:
```bash
CASE_FAIL=0
expect_rc_eq() { if [ "$1" -ne "$2" ]; then echo "    [detail] expected rc=$2, got rc=$1"; CASE_FAIL=1; fi }
expect_rc_ne_zero() { ... }
expect_out() { if ! grep -Fq -- "$1" "$CASE_OUT"; then echo "    [detail] output missing: $1"; CASE_FAIL=1; fi }
expect_no_out() { ... }
expect_out_re() { ... }
```
Env-seam invocation style (fixture-driven, no root) — copy the per-case shape from `:268-273`:
```bash
case_mounted_target_abort() {
    local rc=0
    D330_SHIM_LSBLK_MOUNTPOINTS=/mnt/data \
    D330_SHIM_ROOT_SOURCE=/dev/mmcblk0p3 \
        PATH="$SHIM_DIR:$PATH" bash "$TOOL" --format --device "$TEST_DEV" > "$CASE_OUT" 2>&1 </dev/null || rc=$?
    expect_rc_ne_zero "$rc"
    expect_out "[GUARD] mountpoints: FAIL"
    expect_no_canary
}
```
For phase 33 the seam is `D330_PROC_SWAPS=… D330_SYS_POWER=… python3 tools/d330-auto-hibernate.py --dry-run` with fixture files (zram-only, partition, swapfile+zram, empty; fake `resume` `0:0` vs `253:0`).

**Runner + summary (lines 690-742):**
```bash
CASE_NAMES=( case_... ... )

for fn in "${CASE_NAMES[@]}"; do
    CASE_FAIL=0
    "$fn" || true
    name="${fn#case_}"
    name="${name//_/-}"
    if [ "$CASE_FAIL" -eq 0 ]; then
        echo "  [OK] $name"; passed=$((passed + 1))
    else
        echo "  [FAIL] $name"; failed=$((failed + 1)); continue
    fi
done

echo " Guard suite summary: passed=$passed failed=$failed"
if [ "$failed" -gt 0 ]; then exit 1; fi
exit 0
```

**Static-guard cases to include (RESEARCH Q6.3):** ExecStart ↔ install-path grep consistency, enable-site presence ×3 installers, udev glob comment presence, `bash -n` on touched scripts, `python3 -m py_compile tools/d330-auto-hibernate.py`. **Assert only daemon-produced markers** (`[DRY-RUN]`, `[ERROR]`, verdict lines, exit codes) — systemd/kernel refusal strings are version-dependent (v252 vs v255+, R9).

**Inline python pattern** (for py assertions without pytest — repo has no python test infra; `scripts/test_ci_workflows.sh:46-75`):
```bash
python3 - << 'EOF'
import os, sys
...
print("[FAIL] ...")
sys.exit(1)
EOF
```

---

### `scripts/test_storage_cellular.sh` (test harness, delegation)

**Analog:** the file itself — delegate block to extend (lines 59-70):
```bash
    for f in tools/d330-microsd-setup.sh scripts/test_microsd_guards.sh scripts/test_storage_cellular.sh; do
        if bash -n "$f"; then
            echo "[OK] bash -n $f"
        else
            echo "[FAIL] bash -n $f" >&2
            exit 1
        fi
    done

    # Guard suite: its non-zero exit propagates under set -e, so any failing
    # case fails this mode; its passed=N failed=M summary flows into this output.
    bash scripts/test_microsd_guards.sh
```
Add `scripts/test_hibernate_guards.sh` to the `bash -n` list and `bash scripts/test_hibernate_guards.sh` as a delegate beside line 70, same comment style.

**Keep green:** `scripts/test_auto_hibernate.sh` calls `python3 tools/d330-auto-hibernate.py --dry-run` at `:55` (`|| true` always-green, roadmap defect #311), `:72`, `:76` — new daemon output must not break it.

---

## Shared Patterns

### Guard / honest-failure posture (phase 32 carry-forward)
**Source:** `tools/d330-microsd-setup.sh:85-154` + CONTEXT canonical ref `32-CONTEXT.md`
**Apply to:** daemon, installer resume-activation step, swapfile unit logic
```bash
log_err "[GUARD] mountpoints: FAIL (mounted at: $line)"   # :100 — fail closed, own message, reason included
log_ok  "[GUARD] mountpoints: PASS (no mounted partitions on $TARGET_DEV)"  # :104
log_info "[DRY-RUN] Append to $FSTAB_FILE: $(build_fstab_line "$UUID")"     # :384 — report, don't execute
```
Python equivalents: `[ERROR] <reason>` / `[DRY-RUN] <action>` markers (locked wording only for the marker tokens).

### Service enable idiom
**Source:** `scripts/install_dkms.sh:286-294`, `packaging/debian/postinst:12-18`, `packaging/rpm/lenovo-d330-fix.spec:41-44`
**Apply to:** all three enable sites (success criterion 3)
```bash
systemctl daemon-reload || true
systemctl enable <unit>.service 2>/dev/null || true
```

### Guarded file deploy
**Source:** `scripts/install_dkms.sh:279-284` (services), `:186-194` (grub.d)
**Apply to:** new swapfile unit copy + resume snippet copy
```bash
[ -f "${REPO_ROOT}/patches/.../<asset>" ] && \
    cp "${REPO_ROOT}/patches/.../<asset>" /dest/
```

### Uninstall symmetry
**Source:** `scripts/install_dkms.sh:409` (rm binary), `:427-429` (disable --now), `:436-438` (rm unit)
**Apply to:** new swapfile unit + any new binary; recommendation R5/RESEARCH §4: leave `/var/swapfile`, `swapoff` + remove fstab line only.

### Test suite skeleton
**Source:** `scripts/test_microsd_guards.sh` (header `:1-25`, counters `:51-52`, helpers `:184-244`, runner `:719-742`)
**Apply to:** NEW `scripts/test_hibernate_guards.sh` (fixtures via env seam, static regression guards, non-zero on failure)

### Test delegation
**Source:** `scripts/test_storage_cellular.sh:59-70`
**Apply to:** wire new suite into `--dry-run` mode next to line 70

### GRUB snippet append
**Source:** `patches/boot_orientation/etc/default/grub.d/50-lenovo-d330-boot.cfg:6`
**Apply to:** NEW `53-lenovo-d330-resume.cfg`
```bash
GRUB_CMDLINE_LINUX_DEFAULT="${GRUB_CMDLINE_LINUX_DEFAULT} <append>"
```

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| NEW resume-activation installer step (mkconfig detect + verify + manual-step non-zero exit) inside `scripts/install_dkms.sh` | installer | file-I/O | Repo has **zero** `grub-mkconfig`/`update-grub` calls anywhere (RESEARCH Q2.5 grep = no hits) — no precedent; planner uses RESEARCH.md §2 (detect → run → grep-verify → else print cmdline + exit non-zero) |
| NEW env-seam fixture plumbing in `tools/d330-auto-hibernate.py` (`D330_PROC_SWAPS`/`D330_SYS_POWER`) | daemon/test seam | fixture-driven | No python test seam exists in repo; nearest shape is the `D330_FSTAB` seam in `tools/d330-microsd-setup.sh:361/391-395` (bash equivalent) + RESEARCH Q6.2 snippet |
| swapfile free-space guard + dd/mkswap creation (unit + installer) | file-I/O | batch | Never created a swapfile in repo; nearest = microsd format guards (`expect_no_canary` abort-before-write) + RESEARCH §1 commands |

## Metadata

**Analog search scope:** `scripts/`, `tools/`, `patches/power_hibernate/`, `patches/sensors/`, `patches/dkms/`, `patches/boot_orientation/`, `packaging/`
**Files scanned:** ~15 read/grepped (5 full reads of primary analogs, 4 grep passes)
**Pattern extraction date:** 2026-10-08
