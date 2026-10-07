# Lenovo VPC2004 Hardware Controls for Lenovo IdeaPad D330-10IGL

Provides systemd persistence services, non-root udev rules, and CLI management for battery conservation mode and Fn-lock.

## File Hierarchy
- `etc/systemd/system/d330-hardware-state.service`: State save/restore service.
- `etc/udev/rules.d/88-lenovo-d330-hardware.rules`: Non-root permissions for platform nodes.
