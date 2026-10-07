# Low-Battery Auto-Hibernate Patches for Lenovo IdeaPad D330-10IGL

Provides systemd service, udev triggers, and Python daemon for graceful hibernation at critical low battery (<5%).

## File Hierarchy
- `etc/systemd/system/d330-auto-hibernate.service`: Auto-hibernate service unit.
- `etc/udev/rules.d/99-lenovo-d330-battery-critical.rules`: Udev trigger for discharging at low capacity.
- `tools/d330-auto-hibernate.py`: Python daemon script.
