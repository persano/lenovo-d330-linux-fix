# Lenovo IdeaPad D330: Detachable Dock & Tablet Mode Architecture

## 1. Hardware Architecture & Problem Analysis

The Lenovo IdeaPad D330 (Types `82H0`, `81H3`, `81MD`) features a magnetic detachable keyboard base with an integrated touchpad and USB expansion ports.

### Detachment Detection Vectors
1. **ACPI Intel HID Event Filter (`INT33D5`)**:
   - Exposed to Linux via `intel-hid` and `intel_vbtn` kernel modules.
   - Generates switch events on `/dev/input/event*`:
     * Event code `EV_SW` (`0x05`)
     * Switch `SW_TABLET_MODE` (`0x01`): `0` = Clamshell/Docked, `1` = Detached/Tablet.
2. **USB Subsystem Hotplug**:
   - The dock exposes a Lenovo USB Vendor ID (`17ef`).
   - Insertion triggers USB device enumeration; detachment triggers sysfs removal events.
3. **Desktop Environment Friction**:
   - Linux desktop environments (GNOME, Cinnamon, XFCE, KDE) frequently fail to link ACPI tablet mode switch events to:
     * Disabling physical touchpad to prevent phantom touches across undock.
     * Restoring or locking landscape orientation for laptop typing.
     * Enabling the on-screen virtual keyboard (OSK) when detached in tablet mode.

---

## 2. Daemon Design (`d330-tablet-daemon`)

The daemon (`tools/d330-tablet-daemon.py`) provides hybrid event listening:
- **Primary**: Direct asynchronous `select()` event loop polling `/dev/input/event*` devices advertising `SW_TABLET_MODE` capabilities via sysfs bitmap (`/sys/class/input/event*/device/capabilities/sw`).
- **Secondary**: Periodic heartbeat and udev trigger detecting physical USB connectivity (`PRODUCT=17ef/*`).

### State Machine Actions
| State | Trigger | Orientation | Touchpad | On-Screen Keyboard |
| :--- | :--- | :--- | :--- | :--- |
| **Laptop Mode** | `SW_TABLET_MODE = 0` / Dock attached | Locked to Landscape | Enabled (`xinput enable`) | Disabled |
| **Tablet Mode** | `SW_TABLET_MODE = 1` / Dock detached | Auto-rotate via `iio-sensor-proxy` | Disabled / Ignored | Enabled (`screen-keyboard-enabled true`) |

---

## 3. Systemd and Udev Integration

- Service unit: `patches/dock/usr/lib/systemd/user/d330-tablet-daemon.service` (systemd user unit; enabled with `systemctl --global enable`)
- Udev rule: `patches/dock/etc/udev/rules.d/85-lenovo-d330-dock.rules`
  * Captures USB hotplug events and triggers daemon state synchronization.
  * Tags Intel HID switch devices for systemd activation.

---

## 4. Verification

Execute the test suite:
```bash
# Query current dock hardware status
bash scripts/test_dock_switching.sh --status

# Simulate laptop / tablet transitions
bash scripts/test_dock_switching.sh --test-laptop
bash scripts/test_dock_switching.sh --test-tablet

# Automated state cycle test
bash scripts/test_dock_switching.sh --cycle-test 3
```
