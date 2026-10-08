#!/usr/bin/env python3
"""
Lenovo IdeaPad D330-10IGL Sensor Debounce & Ambient Light Smoothing Daemon
- Accelerometer (BOSC0200): applies a 15-degree hysteresis deadband plus a
  debounce window before emitting a rotation decision.
- Ambient Light Sensor (ACPI0008): applies Exponential Moving Average (EMA)
  smoothing, reading `in_illuminance_raw` with fallbacks.

Liveness contract: `--monitor` runs indefinitely (the shipped
d330-sensor-filter.service is `Type=simple` with `Restart=on-failure`, so a
process that exits after a fixed number of iterations was permanently dead).
`--cycles N` / `--once` exist only as test hooks so the suite can bound a run.
"""

import math
import os
import signal
import sys
import time

ACCEL_DEBOUNCE_SEC = 0.5
HYSTERESIS_DEG = 15.0
ALS_ALPHA = 0.15  # EMA smoothing factor
POLL_INTERVAL_SEC = 0.2

# Test seam: point the filter at a fake sysfs tree in tests. Defaults to the
# real IIO base; evaluated once at process start.
DEFAULT_IIO_BASE = "/sys/bus/iio/devices"


def iio_base():
    return os.environ.get("D330_IIO_BASE", DEFAULT_IIO_BASE)


def find_iio_devices():
    devices = {"accel": None, "als": None}
    base = iio_base()
    if not os.path.isdir(base):
        return devices
    for d in sorted(os.listdir(base)):
        d_path = os.path.join(base, d)
        name_path = os.path.join(d_path, "name")
        if not os.path.isfile(name_path):
            continue
        try:
            with open(name_path, "r") as f:
                name = f.read().strip().lower()
        except OSError:
            continue
        if any(k in name for k in ["bosc0200", "accel"]):
            devices["accel"] = d_path
        elif any(k in name for k in ["acpi0008", "als", "light"]):
            devices["als"] = d_path
    return devices


def read_iio_val(path):
    if not path or not os.path.exists(path):
        return None
    try:
        with open(path, "r") as f:
            return float(f.read().strip())
    except (OSError, ValueError):
        return None


def find_als_node(device):
    """Prefer in_illuminance_raw, then in_illuminance_input, then in_intensity_*."""
    for candidate in ("in_illuminance_raw", "in_illuminance_input"):
        path = os.path.join(device, candidate)
        if os.path.exists(path):
            return path
    try:
        for entry in sorted(os.listdir(device)):
            if entry.startswith("in_intensity") and entry.endswith("_raw"):
                return os.path.join(device, entry)
    except OSError:
        pass
    return None


def read_accel_tilt(device):
    """Return the tilt angle (degrees off vertical) from the raw accel axes."""
    axes = []
    for axis in ("x", "y", "z"):
        val = read_iio_val(os.path.join(device, f"in_accel_{axis}_raw"))
        if val is None:
            return None
        axes.append(val)
    x, y, z = axes
    norm = math.sqrt(x * x + y * y + z * z)
    if norm == 0.0:
        return 0.0
    return math.degrees(math.acos(max(-1.0, min(1.0, z / norm))))


def monitor_sensors(cycles=None):
    devs = find_iio_devices()
    print("=== D330 Sensor Debounce & ALS Monitor ===")
    print(f"Accelerometer Device: {devs['accel'] or 'Not found'}")
    print(f"Ambient Light Sensor: {devs['als'] or 'Not found'}")

    if not devs["accel"] and not devs["als"]:
        print("[INFO] No active IIO sensors detected in current environment.")
        return 0

    running = True

    def _stop(_signum, _frame):
        nonlocal running
        running = False

    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)

    smoothed_lux = None
    last_angle = None
    last_decision_time = 0.0
    count = 0

    while running:
        if cycles is not None and count >= cycles:
            break
        count += 1

        # Accelerometer: emit a rotation decision only when the tilt crosses the
        # hysteresis deadband and the debounce interval has elapsed -- no
        # duplicate decisions while the reading stays inside the deadband.
        if devs["accel"]:
            angle = read_accel_tilt(devs["accel"])
            if angle is not None:
                now = time.monotonic()
                crossed = last_angle is None or abs(angle - last_angle) >= HYSTERESIS_DEG
                if crossed and (now - last_decision_time) >= ACCEL_DEBOUNCE_SEC:
                    print(f"Accel: tilt={angle:.1f} deg (>|{HYSTERESIS_DEG:.0f}| deg) -> rotation decision")
                    last_angle = angle
                    last_decision_time = now

        # Ambient light: EMA smoothing with raw/input/intensity fallbacks.
        if devs["als"]:
            node = find_als_node(devs["als"])
            raw_lux = read_iio_val(node)
            if raw_lux is not None:
                if smoothed_lux is None:
                    smoothed_lux = raw_lux
                else:
                    smoothed_lux = (ALS_ALPHA * raw_lux) + ((1.0 - ALS_ALPHA) * smoothed_lux)
                print(f"ALS: Raw={raw_lux:.1f} lux -> Smoothed={smoothed_lux:.1f} lux")

        if cycles is not None and count >= cycles:
            break
        time.sleep(POLL_INTERVAL_SEC)

    return 0


def main():
    args = sys.argv[1:]
    cycles = None

    if "--once" in args:
        cycles = 1
    if "--cycles" in args:
        idx = args.index("--cycles")
        if idx + 1 >= len(args):
            print("[FAIL] --cycles requires an integer argument")
            sys.exit(2)
        try:
            cycles = int(args[idx + 1])
        except ValueError:
            print("[FAIL] --cycles requires an integer argument")
            sys.exit(2)
        if cycles < 0:
            print("[FAIL] --cycles must be non-negative")
            sys.exit(2)

    if "--monitor" in args or cycles is not None:
        sys.exit(monitor_sensors(cycles))

    devs = find_iio_devices()
    print(f"D330 Sensors: Accel={bool(devs['accel'])}, ALS={bool(devs['als'])}")


if __name__ == "__main__":
    main()
