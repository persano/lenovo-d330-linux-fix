# MicroSD & Cellular LTE Patches for Lenovo IdeaPad D330-10IGL

Provides a ModemManager FCC unlock hook and udev rules for the Intel XMM 7360 LTE modem.

## File Hierarchy
- `etc/ModemManager/fcc-unlock.d/8086`: ModemManager FCC unlock script (tracked without the colon; the installer copies it to `/etc/ModemManager/fcc-unlock.d/8086:7360`).
- `etc/modprobe.d/lenovo-d330-cellular.conf`: Placeholder config for iosm / xmm7360 (no parameters; both autoload).
- `etc/udev/rules.d/78-lenovo-d330-cellular.rules`: udev rules for modem auto-detection.
