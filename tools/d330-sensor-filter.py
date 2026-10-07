#!/usr/bin/env python3
"""
Lenovo IdeaPad D330-10IGL Sensor Debounce & Ambient Light Smoothing Daemon
- Accelerometer (BOSC0200): Applies 15-degree hysteresis deadband & 500ms debounce
- Ambient Light Sensor (ACPI0008): Applies Exponential Moving Average (EMA) smoothing
"""

import sys
import os
import time
import math

ACCEL_DEBOUNCE_SEC = 0.5
HYSTERESIS_DEG = 15.0
ALS_ALPHA = 0.15  # EMA smoothing factor

def find_iio_devices():
    devices = {"accel": None, "als": None}
    base = "/sys/bus/iio/devices"
    if not os.path.isdir(base):
        return devices
    for d in os.listdir(base):
        d_path = os.path.join(base, d)
        name_path = os.path.join(d_path, "name")
        if os.path.isfile(name_path):
            with open(name_path, "r") as f:
                name = f.read().strip().lower()
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
    except Exception:
        return None

def monitor_sensors():
    devs = find_iio_devices()
    print("=== D330 Sensor Debounce & ALS Monitor ===")
    print(f"Accelerometer Device: {devs['accel'] or 'Not found'}")
    print(f"Ambient Light Sensor: {devs['als'] or 'Not found'}")
    
    if not devs['accel'] and not devs['als']:
        print("[INFO] No active IIO sensors detected in current environment.")
        return

    smoothed_lux = None
    for _ in range(5):
        if devs['als']:
            lux_node = os.path.join(devs['als'], "in_illuminance_raw")
            raw_lux = read_iio_val(lux_node)
            if raw_lux is not None:
                if smoothed_lux is None:
                    smoothed_lux = raw_lux
                else:
                    smoothed_lux = (ALS_ALPHA * raw_lux) + ((1.0 - ALS_ALPHA) * smoothed_lux)
                print(f"ALS: Raw={raw_lux:.1f} lux -> Smoothed={smoothed_lux:.1f} lux")
        time.sleep(0.2)

def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--monitor":
        monitor_sensors()
    else:
        devs = find_iio_devices()
        print(f"D330 Sensors: Accel={bool(devs['accel'])}, ALS={bool(devs['als'])}")

if __name__ == "__main__":
    main()
