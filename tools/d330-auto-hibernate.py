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

def find_battery():
    base = "/sys/class/power_supply"
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
    
    cap = int(open(cap_file).read().strip()) if os.path.exists(cap_file) else None
    status = open(status_file).read().strip() if os.path.exists(status_file) else "Unknown"
    return cap, status

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
            subprocess.run(["systemctl", "hibernate"])
    else:
        print("[OK] Battery level safe.")

def main():
    dry_run = "--dry-run" in sys.argv
    check_and_hibernate(dry_run=dry_run)

if __name__ == "__main__":
    main()
