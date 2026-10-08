#!/usr/bin/env python3
"""
Lenovo IdeaPad D330-10IGL Critical Low-Battery Auto-Hibernate Daemon
Monitors battery capacity and safely suspends to disk at <5% to prevent data loss.
"""

import sys
import os
import subprocess
import time

CRITICAL_THRESHOLD_PERCENT = 5

# Env seams: tests substitute fixture files; production behavior is unchanged
# when these are unset (defaults are the real system paths).
D330_PROC_SWAPS = os.environ.get("D330_PROC_SWAPS", "/proc/swaps")
D330_SYS_POWER = os.environ.get("D330_SYS_POWER", "/sys/power")
D330_PROC_CMDLINE = os.environ.get("D330_PROC_CMDLINE", "/proc/cmdline")
D330_POWER_SUPPLY_DIR = os.environ.get("D330_POWER_SUPPLY_DIR", "/sys/class/power_supply")

def find_battery():
    base = D330_POWER_SUPPLY_DIR
    if not os.path.isdir(base):
        return None
    for item in os.listdir(base):
        if item.startswith("BAT"):
            return os.path.join(base, item)
    return None

def get_battery_info():
    bat = find_battery()
    if not bat:
        return None, None
    cap_file = os.path.join(bat, "capacity")
    status_file = os.path.join(bat, "status")

    cap = None
    status = "Unknown"
    if os.path.exists(cap_file):
        with open(cap_file) as f:
            cap = int(f.read().strip())
    if os.path.exists(status_file):
        with open(status_file) as f:
            status = f.read().strip()
    return cap, status

def read_proc_swaps():
    """Parse the (env-seamed) active swap table. A missing file (non-Linux dev
    shell), an empty file, or malformed rows never raise: they are skipped and
    the result degrades to an empty table (fail closed to "no swap present")."""
    try:
        with open(D330_PROC_SWAPS) as f:
            lines = f.read().splitlines()
    except OSError:
        return []
    entries = []
    for line in lines:
        fields = line.split()
        if not fields or fields[0] == "Filename":
            continue
        if len(fields) < 5:
            continue
        try:
            size = int(fields[2])
            used = int(fields[3])
            priority = int(fields[4])
        except ValueError:
            continue
        entries.append({
            "path": fields[0],
            "type": fields[1],
            "size": size,
            "used": used,
            "priority": priority,
        })
    return entries

def classify_swap(entry):
    """zram when the path is /dev/zram* (the exact rule systemd uses in
    hibernate-util.c); otherwise map the kernel's type column to disk/file."""
    path = entry["path"]
    if path.startswith("/dev/") and os.path.basename(path).startswith("zram"):
        return "zram"
    if entry["type"] == "partition":
        return "disk"
    if entry["type"] == "file":
        return "file"
    return entry["type"]

def has_non_zram_swap(entries):
    return any(classify_swap(entry) != "zram" for entry in entries)

def hibernation_offered():
    """The kernel only lists 'disk' in /sys/power/state when hibernation is
    actually available (CONFIG_HIBERNATION, no lockdown/nohibernate)."""
    try:
        with open(os.path.join(D330_SYS_POWER, "state")) as f:
            return "disk" in f.read().split()
    except OSError:
        return False

def resume_configured():
    """/sys/power/resume is 0:0 when no resume device is set, unless the
    kernel cmdline carries a resume= token (set at boot)."""
    try:
        with open(os.path.join(D330_SYS_POWER, "resume")) as f:
            if f.read().strip() != "0:0":
                return True
    except OSError:
        pass
    try:
        with open(D330_PROC_CMDLINE) as f:
            tokens = f.read().split()
    except OSError:
        return False
    return any(tok.startswith("resume=") for tok in tokens)

def readiness(entries):
    """(ready, reason) from the same parse the report prints (one source of
    truth). Refusal priority when multiple checks fail: kernel -> resume -> swap."""
    if not hibernation_offered():
        return False, "hibernation not offered by kernel"
    if not resume_configured():
        return False, "resume not configured"
    if not entries:
        return False, "no swap present"
    if not has_non_zram_swap(entries):
        return False, "only zram swap present"
    return True, None

def print_swap_report(entries, ready, reason):
    """Success criterion 2: one row per swap area, then exactly one verdict line."""
    for entry in entries:
        kind = classify_swap(entry)
        print(f"[SWAP] path={entry['path']} type={kind} size={entry['size']} "
              f"used={entry['used']} priority={entry['priority']}")
    if ready:
        print("hibernate readiness: READY")
    else:
        print(f"hibernate readiness: NOT-READY ({reason})")

def run_power_action(verb):
    """sync + sleep verb in list form; the verb's return code is captured and
    propagated (audit N5: it used to be discarded)."""
    subprocess.run(["sync"])
    result = subprocess.run(["systemctl", verb])
    rc = result.returncode
    if rc != 0:
        print(f"[ERROR] systemctl {verb} failed (rc={rc})")
        return rc if rc > 0 else 1
    return 0

def check_and_hibernate(dry_run=False):
    entries = read_proc_swaps()
    ready, reason = readiness(entries)
    print_swap_report(entries, ready, reason)

    cap, status = get_battery_info()
    if cap is None:
        print("[INFO] No battery power supply detected in current environment.")
        return 0

    print(f"Battery: {cap}% ({status}) - Critical threshold: {CRITICAL_THRESHOLD_PERCENT}%")

    if cap <= CRITICAL_THRESHOLD_PERCENT and status.lower() == "discharging":
        print(f"[CRITICAL] Battery at {cap}%! Initiating system hibernate...")
        if not ready:
            print(f"[ERROR] hibernate skipped: {reason}")
            if dry_run:
                print("[DRY-RUN] sync && systemctl suspend (skipped in dry run)")
                return 0
            return run_power_action("suspend")
        if dry_run:
            print("[DRY-RUN] sync && systemctl hibernate (skipped in dry run)")
            return 0
        return run_power_action("hibernate")
    else:
        print("[OK] Battery level safe.")
        return 0

def main():
    dry_run = "--dry-run" in sys.argv
    return check_and_hibernate(dry_run=dry_run)

if __name__ == "__main__":
    sys.exit(main())
