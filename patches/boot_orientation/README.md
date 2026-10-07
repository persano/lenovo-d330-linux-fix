# Bootloader & Console Orientation Patches for Lenovo IdeaPad D330-10IGL

Provides GRUB configuration snippet, initramfs Plymouth hook, and emergency screen refresh utility.

## File Hierarchy
- `etc/default/grub.d/50-lenovo-d330-boot.cfg`: GRUB command line for `fbcon=rotate:1`.
- `usr/share/initramfs-tools/hooks/lenovo-d330-plymouth`: Initramfs hook for Plymouth orientation.
- `tools/d330-refresh-screen.sh`: Emergency display output reset script.
