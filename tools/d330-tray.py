#!/usr/bin/env python3
"""
Lenovo IdeaPad D330-10IGL hardware status helper (d330-tray)
Dependency-free stdlib notification/status helper:
- Reports battery conservation (60% charge limit) state via `--status`
- Sends a `notify-send` desktop notification when autostarted
No GTK, no AppIndicator, no interactive tray menu.
"""

import sys
import os
import subprocess

def run_cmd(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True).strip()
    except Exception:
        return ""

def get_battery_conservation_state():
    """Return 'enabled', 'disabled', or 'unknown' when the state is unreadable."""
    out = run_cmd("d330-ctl battery status 2>/dev/null")
    if "ENABLED" in out:
        return "enabled"
    if "DISABLED" in out:
        return "disabled"
    return "unknown"

def main():
    if "--status" in sys.argv:
        state = get_battery_conservation_state()
        cons = {
            "enabled": "Enabled (60%)",
            "disabled": "Disabled (100%)",
            "unknown": "Unknown (d330-ctl unavailable or conservation node not detected)",
        }[state]
        print("=== D330 Tray Applet Status ===")
        print(f"  - Battery Conservation: {cons}")
        return

    print("=== Lenovo IdeaPad D330 Tray Applet Initialized ===")
    print("Status helper active: run 'd330-tray --status' for battery conservation state.")
    # In headless / test CLI, print capabilities and exit cleanly
    if not os.environ.get("DISPLAY") and not os.environ.get("WAYLAND_DISPLAY"):
        print("[INFO] Headless environment. Exiting tray loop.")
        return

    # In GUI session, can use zenity / desktop notification if appindicator not present
    run_cmd("notify-send 'Lenovo D330' 'Hardware Control Tray active' -i preferences-system 2>/dev/null || true")

if __name__ == "__main__":
    main()
