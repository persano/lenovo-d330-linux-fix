# ACPI DSDT Clean Initrd Override for Lenovo IdeaPad D330-10IGL

Provides ASL table patch, compilation tool, and GRUB loader configuration to eliminate the `\_SB.PCI0.RP04` `AE_ALREADY_EXISTS` kernel boot error.

## File Hierarchy
- `dsdt_override.asl`: Source ASL table defining clean `RP04` device.
- `etc/default/grub.d/51-lenovo-d330-acpi-override.cfg`: GRUB hook for `/boot/acpi-override.cpio`.
- `tools/d330-acpi-override.sh`: Packaging script for early CPIO archive.
