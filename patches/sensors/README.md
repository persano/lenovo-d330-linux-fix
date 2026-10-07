# Sensor Hysteresis & Ambient Light Sensor Patches for Lenovo IdeaPad D330-10IGL

Provides IIO udev classification rules, smoothing filter daemon, and systemd background service.

## File Hierarchy
- `etc/udev/rules.d/87-lenovo-d330-sensors.rules`: IIO classification tags.
- `etc/systemd/system/d330-sensor-filter.service`: Sensor filter service unit.
- `tools/d330-sensor-filter.py`: Python daemon implementing hysteresis and EMA filters.
