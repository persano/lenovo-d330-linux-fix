# Detachable Keyboard Dock & Tablet Mode Daemon

This directory packages system integration files for the Lenovo IdeaPad D330 detachable keyboard dock (`INT33D5` / USB `17ef`).

## Contents

- `usr/lib/systemd/user/d330-tablet-daemon.service`: Systemd **user** service unit running `d330-tablet-daemon` in the desktop session (enabled globally via `systemctl --global enable`).
- `etc/udev/rules.d/85-lenovo-d330-dock.rules`: Udev rules tracking dock USB connection/disconnection and Intel HID switches.

The daemon implementation resides in `tools/d330-tablet-daemon.py` and is tested via `scripts/test_dock_switching.sh`.
