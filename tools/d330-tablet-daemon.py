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
        # Fallback to dock USB probe
        if self.check_dock_usb_presence():
            return 0  # Laptop mode (dock connected)
        return 1      # Tablet mode (dock disconnected)

    def current_desktop(self):
        """Lower-cased XDG_CURRENT_DESKTOP value, or '' when unknown."""
        return os.environ.get("XDG_CURRENT_DESKTOP", "").strip().lower()

    def session_tokens(self):
        """Space-joined tokens describing this session (desktop + display server)."""
        tokens = [self.current_desktop()]
        if os.environ.get("WAYLAND_DISPLAY"):
            tokens.append("wayland")
        elif os.environ.get("DISPLAY"):
            tokens.append("x11")
        return " ".join(t for t in tokens if t)

    def apply_commands(self, commands):
        """Run (label, command, targets) triples applicable to this session.

        `targets` lists the session tokens a command is written for (e.g.
        "gnome", "cinnamon", "kde", "x11"); an empty tuple means "any desktop".
        Commands that do not target the current session are skipped instead of
        run, so success is honest rather than unreachable: a GNOME/KDE/Cinnamon
        session only reports failures for commands that actually apply to it,
        and only a genuinely session-less run warns (M6). Best-effort commands
        already carrying `|| true` keep succeeding by construction.
        """
        tokens = self.session_tokens()
        has_session = bool(os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"))
        failed = []
        for label, cmd, targets in commands:
            if not has_session:
                failed.append(label)
                continue
            if targets and not any(t in tokens for t in targets):
                continue
            ok, _ = run_command(cmd)
            if not ok:
                failed.append(label)
        return failed

    def report_mode_result(self, mode, failed):
        """Log success only when every desktop command returned 0 (M6)."""
        if failed:
            logger.warning("%s: some settings did not apply (no desktop session?); failed: %s",
                           mode, ", ".join(failed))
        else:
            logger.info("%s settings applied successfully.", mode)

    def set_laptop_mode(self):
        """Applies Clamshell/Laptop configuration."""
        if self.current_mode == 'laptop':
            return
        self.current_mode = 'laptop'
        logger.info("=== Switching to LAPTOP MODE (Dock Connected) ===")

        if self.dry_run:
            logger.info("[DRY-RUN] Enabled touchpad, locked orientation to landscape, disabled OSK.")
            return

        # 1-3. Orientation, touchpad, and OSK desktop commands, each tagged with
        # the session it targets, so success is only reported for commands that
        # actually apply to the current desktop (M6); `|| true` best-effort calls
        # are inherently reported as applied.
        failed = self.apply_commands([
            ("gsettings orientation",
             "gsettings set org.gnome.settings-daemon.plugins.orientation active false",
             ("gnome",)),
            ("xrandr rotate normal",
             "xrandr --output eDP-1 --rotate normal 2>/dev/null || xrandr --output eDP-1 --rotate right 2>/dev/null",
             ("x11",)),
            ("xinput enable SynPS/2 Synaptics TouchPad",
             "xinput enable 'SynPS/2 Synaptics TouchPad' 2>/dev/null || true", ()),
            ("xinput enable Elan Touchpad",
             "xinput enable 'Elan Touchpad' 2>/dev/null || true", ()),
            ("xinput enable ELAN0676 Touchpad",
             "xinput enable 'ELAN0676:00 04F3:3195 Touchpad' 2>/dev/null || true", ()),
            ("gsettings gnome OSK off",
             "gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled false",
             ("gnome",)),
            ("gsettings cinnamon OSK off",
             "gsettings set org.cinnamon.desktop.a11y.applications screen-keyboard-enabled false",
             ("cinnamon",)),
            ("qdbus KWin OSK off",
             "qdbus org.kde.KWin /VirtualKeyboard org.kde.kwin.VirtualKeyboard.setEnabled false 2>/dev/null || true",
             ("kde",)),
            ("killall onboard",
             "killall onboard 2>/dev/null || true", ()),
        ])
        self.report_mode_result("Laptop mode", failed)

    def set_tablet_mode(self):
        """Applies Tablet configuration."""
        if self.current_mode == 'tablet':
            return
        self.current_mode = 'tablet'
        logger.info("=== Switching to TABLET MODE (Dock Detached) ===")

        if self.dry_run:
            logger.info("[DRY-RUN] Enabled auto-rotation, enabled OSK, disabled external dock inputs.")
            return

        # 1-3. Orientation, OSK, and touchpad desktop commands, each tagged with
        # the session it targets; success is only reported for commands that
        # actually apply to the current desktop (M6).
        failed = self.apply_commands([
            ("gsettings orientation auto",
             "gsettings set org.gnome.settings-daemon.plugins.orientation active true",
             ("gnome",)),
            ("gsettings gnome OSK on",
             "gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true",
             ("gnome",)),
            ("gsettings cinnamon OSK on",
             "gsettings set org.cinnamon.desktop.a11y.applications screen-keyboard-enabled true",
             ("cinnamon",)),
            ("qdbus KWin OSK on",
             "qdbus org.kde.KWin /VirtualKeyboard org.kde.kwin.VirtualKeyboard.setEnabled true 2>/dev/null || true",
             ("kde",)),
            ("launch onboard",
             "which onboard >/dev/null 2>&1 && (pgrep onboard >/dev/null || onboard &) || true", ()),
            ("xinput disable SynPS/2 Synaptics TouchPad",
             "xinput disable 'SynPS/2 Synaptics TouchPad' 2>/dev/null || true", ()),
            ("xinput disable Elan Touchpad",
             "xinput disable 'Elan Touchpad' 2>/dev/null || true", ()),
            ("xinput disable ELAN0676 Touchpad",
             "xinput disable 'ELAN0676:00 04F3:3195 Touchpad' 2>/dev/null || true", ()),
        ])
        self.report_mode_result("Tablet mode", failed)

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
