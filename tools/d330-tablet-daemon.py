#!/usr/bin/env python3
"""
d330-tablet-daemon.py
Lenovo IdeaPad D330 Detachable Keyboard Dock & Tablet Mode Management Daemon.

Monitors Intel HID Event Filter (INT33D5 / intel-hid / intel_vbtn) and USB/I2C
dock connection states. Automates display rotation locking, touchpad enablement,
and on-screen virtual keyboard (OSK) toggling across dock/undock transitions.
"""

import os
import sys
import glob
import time
import struct
import signal
import select
import logging
import argparse
import subprocess

# Linux input event constants
EV_SYN = 0x00
EV_SW  = 0x05
SW_TABLET_MODE = 0x01
SW_LID = 0x00

# input_event format: time_sec (ulong), time_usec (ulong), type (ushort), code (ushort), value (int)
# In 64-bit Linux: 'qqHHi' (16 + 8 bytes = 24 bytes)
EVENT_FORMAT_64 = 'qqHHi'
EVENT_SIZE_64 = struct.calcsize(EVENT_FORMAT_64)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] lenovo-d330-dock: %(message)s'
)
logger = logging.getLogger("d330-dock")


def run_command(cmd, ignore_error=True):
    """Executes a shell command cleanly without raising unhandled exceptions."""
    try:
        res = subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=False)
        return res.returncode == 0, res.stdout.strip()
    except Exception as e:
        if not ignore_error:
            raise
        logger.debug(f"Command '{cmd}' failed: {e}")
        return False, ""


class D330TabletDaemon:
    def __init__(self, dry_run=False):
        self.dry_run = dry_run
        self.running = True
        self.current_mode = None  # 'laptop' or 'tablet'
        self.event_fds = {}

    def find_switch_devices(self):
        """Scans /dev/input/event* for devices supporting SW_TABLET_MODE."""
        switch_devs = []
        for evpath in glob.glob('/dev/input/event*'):
            try:
                # Interrogate sysfs device capabilities
                dev_num = os.path.basename(evpath)
                sw_caps_path = f"/sys/class/input/{dev_num}/device/capabilities/sw"
                name_path = f"/sys/class/input/{dev_num}/device/name"
                dev_name = "Unknown"
                if os.path.exists(name_path):
                    with open(name_path, 'r') as f:
                        dev_name = f.read().strip()

                if os.path.exists(sw_caps_path):
                    with open(sw_caps_path, 'r') as f:
                        sw_mask_hex = f.read().strip()
                        # SW_TABLET_MODE bit is 0x02 (1 << 1)
                        if sw_mask_hex:
                            sw_mask = int(sw_mask_hex, 16)
                            if sw_mask & (1 << SW_TABLET_MODE):
                                logger.info(f"Detected Tablet Switch Device: {evpath} ({dev_name})")
                                switch_devs.append(evpath)
            except Exception as e:
                logger.debug(f"Error interrogating {evpath}: {e}")
        return switch_devs

    def check_dock_usb_presence(self):
        """Checks sysfs USB devices for presence of Lenovo keyboard dock."""
        # Lenovo Keyboard Dock USB Vendor ID: 17ef (Lenovo)
        for uevent in glob.glob('/sys/bus/usb/devices/*/uevent'):
            try:
                with open(uevent, 'r') as f:
                    content = f.read()
                    if "PRODUCT=17ef/" in content or "Lenovo" in content:
                        return True
            except Exception:
                pass
        return False

    def query_sysfs_tablet_mode(self):
        """Queries sysfs for initial tablet-mode state."""
        for sw_file in glob.glob('/sys/class/input/input*/device/properties'):
            pass
        # Fallback to dock USB probe
        if self.check_dock_usb_presence():
            return 0  # Laptop mode (dock connected)
        return 1      # Tablet mode (dock disconnected)

    def set_laptop_mode(self):
        """Applies Clamshell/Laptop configuration."""
        if self.current_mode == 'laptop':
            return
        self.current_mode = 'laptop'
        logger.info("=== Switching to LAPTOP MODE (Dock Connected) ===")

        if self.dry_run:
            logger.info("[DRY-RUN] Enabled touchpad, locked orientation to landscape, disabled OSK.")
            return

        # 1. Lock display orientation to normal landscape
        run_command("gsettings set org.gnome.settings-daemon.plugins.orientation active false")
        run_command("xrandr --output eDP-1 --rotate normal 2>/dev/null || xrandr --output eDP-1 --rotate right 2>/dev/null")

        # 2. Enable physical touchpad / trackpoint
        run_command("xinput enable 'SynPS/2 Synaptics TouchPad' 2>/dev/null || true")
        run_command("xinput enable 'Elan Touchpad' 2>/dev/null || true")
        run_command("xinput enable 'ELAN0676:00 04F3:3195 Touchpad' 2>/dev/null || true")

        # 3. Disable On-Screen Keyboard (OSK)
        run_command("gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled false")
        run_command("gsettings set org.cinnamon.desktop.a11y.applications screen-keyboard-enabled false")
        run_command("killall onboard 2>/dev/null || true")

        logger.info("Laptop mode settings applied successfully.")

    def set_tablet_mode(self):
        """Applies Tablet configuration."""
        if self.current_mode == 'tablet':
            return
        self.current_mode = 'tablet'
        logger.info("=== Switching to TABLET MODE (Dock Detached) ===")

        if self.dry_run:
            logger.info("[DRY-RUN] Enabled auto-rotation, enabled OSK, disabled external dock inputs.")
            return

        # 1. Enable automatic accelerometer orientation via iio-sensor-proxy
        run_command("gsettings set org.gnome.settings-daemon.plugins.orientation active true")

        # 2. Enable On-Screen Keyboard (OSK)
        run_command("gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true")
        run_command("gsettings set org.cinnamon.desktop.a11y.applications screen-keyboard-enabled true")

        # 3. Ignore or suppress residual dock touchpad inputs
        run_command("xinput disable 'SynPS/2 Synaptics TouchPad' 2>/dev/null || true")
        run_command("xinput disable 'Elan Touchpad' 2>/dev/null || true")
        run_command("xinput disable 'ELAN0676:00 04F3:3195 Touchpad' 2>/dev/null || true")

        logger.info("Tablet mode settings applied successfully.")

    def run(self):
        """Main event loop monitoring switch events."""
        logger.info("Starting D330 Tablet Daemon event loop...")
        devices = self.find_switch_devices()

        fds = []
        fd_to_path = {}
        for dev_path in devices:
            try:
                fd = os.open(dev_path, os.O_RDONLY | os.O_NONBLOCK)
                fds.append(fd)
                fd_to_path[fd] = dev_path
            except Exception as e:
                logger.warning(f"Could not open device {dev_path}: {e}")

        # Set initial mode
        initial_state = self.query_sysfs_tablet_mode()
        if initial_state == 0:
            self.set_laptop_mode()
        else:
            self.set_tablet_mode()

        last_dock_check = time.time()

        while self.running:
            # Poll switch event fds with 1s timeout
            if fds:
                rlist, _, _ = select.select(fds, [], [], 1.0)
                for fd in rlist:
                    try:
                        data = os.read(fd, EVENT_SIZE_64 * 16)
                        for i in range(0, len(data), EVENT_SIZE_64):
                            chunk = data[i:i + EVENT_SIZE_64]
                            if len(chunk) < EVENT_SIZE_64:
                                continue
                            sec, usec, ev_type, ev_code, ev_value = struct.unpack(EVENT_FORMAT_64, chunk)
                            if ev_type == EV_SW and ev_code == SW_TABLET_MODE:
                                logger.info(f"Received SW_TABLET_MODE event: value={ev_value}")
                                if ev_value == 1:
                                    self.set_tablet_mode()
                                else:
                                    self.set_laptop_mode()
                    except Exception as e:
                        logger.error(f"Error reading event fd: {e}")

            # Periodic heartbeat check on USB dock presence in case ACPI event was dropped
            now = time.time()
            if now - last_dock_check >= 3.0:
                last_dock_check = now
                dock_present = self.check_dock_usb_presence()
                if dock_present and self.current_mode != 'laptop':
                    logger.info("Dock USB detected without ACPI event - syncing to laptop mode")
                    self.set_laptop_mode()
                elif not dock_present and self.current_mode != 'tablet' and not fds:
                    logger.info("Dock USB disconnected - syncing to tablet mode")
                    self.set_tablet_mode()

            time.sleep(0.05)

        for fd in fds:
            try:
                os.close(fd)
            except Exception:
                pass


def main():
    parser = argparse.ArgumentParser(description="Lenovo IdeaPad D330 Tablet Mode & Dock Daemon")
    parser.add_argument("--daemon", action="store_true", help="Run in continuous monitoring mode")
    parser.add_argument("--dry-run", action="store_true", help="Log mode transitions without applying desktop changes")
    parser.add_argument("--status", action="store_true", help="Query current dock and tablet status")
    parser.add_argument("--simulate-dock", action="store_true", help="Trigger laptop mode actions (testing)")
    parser.add_argument("--simulate-undock", action="store_true", help="Trigger tablet mode actions (testing)")

    args = parser.parse_args()
    daemon = D330TabletDaemon(dry_run=args.dry_run)

    if args.status:
        dock_usb = daemon.check_dock_usb_presence()
        sw_devs = daemon.find_switch_devices()
        print(f"Dock USB Hardware Connected : {dock_usb}")
        print(f"Intel HID Switch Event Devs : {sw_devs if sw_devs else 'None (using USB polling)'}")
        print(f"Current Evaluated Mode       : {'Laptop Mode' if dock_usb else 'Tablet Mode'}")
        return

    if args.simulate_dock:
        daemon.set_laptop_mode()
        return

    if args.simulate_undock:
        daemon.set_tablet_mode()
        return

    # Handle OS signals
    def handle_sig(sig, frame):
        logger.info("Termination signal received. Exiting daemon.")
        daemon.running = False
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_sig)
    signal.signal(signal.SIGTERM, handle_sig)

    daemon.run()


if __name__ == "__main__":
    main()
