# Lenovo VPC2004 Hardware Controls for Lenovo IdeaPad D330-10IGL

Provides systemd persistence services and CLI management for battery conservation mode and Fn-lock.

## File Hierarchy
- `etc/systemd/system/d330-hardware-state.service`: State save/restore service.
- `etc/udev/rules.d/88-lenovo-d330-hardware.rules`: Documents that the platform nodes require root (no non-root udev rule applies).

## Permissions

`conservation_mode` and `fn_lock` are platform sysfs attributes owned by the
`ideapad_laptop` driver. udev cannot change the ownership or mode of sysfs
attributes, so there is no non-root `plugdev` path to them: toggling these
nodes requires root. Run `d330-ctl` (or the underlying state service) with
`sudo`, or via `pkexec`, when changing conservation mode or Fn-lock.
