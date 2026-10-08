# ACPI DSDT Clean Initrd Override for Lenovo IdeaPad D330-10IGL

Provides ASL table patch, compilation tool, and GRUB loader configuration to eliminate the `\_SB.PCI0.RP04` `AE_ALREADY_EXISTS` kernel boot error.

## Development-only artifacts

This override is a **development artifact**, not a fully-installed feature. The
installer ships only the guarded GRUB snippet; it never compiles or installs the
ASL/CPIO:

- `dsdt_override.asl` is a source sketch and is **never compiled** by
  `install_dkms.sh`. Build it manually with `iasl` if you intend to use it.
- `tools/d330-acpi-override.sh` is a manual packaging helper (requires `iasl`);
  it is not deployed to `/usr/local/bin`.
- `etc/default/grub.d/51-lenovo-d330-acpi-override.cfg` is the only installed
  piece, and it is guarded: it sets `GRUB_EARLY_INITRD_LINUX_CUSTOM` **only when
  `/boot/acpi-override.cpio` already exists**, so the installer is a no-op until
  you build that archive yourself.

## File Hierarchy
- `dsdt_override.asl`: Source ASL table defining clean `RP04` device (dev-only; never compiled by the installer).
- `etc/default/grub.d/51-lenovo-d330-acpi-override.cfg`: GRUB hook for `/boot/acpi-override.cpio` (installed; guarded on the archive's presence).
- `tools/d330-acpi-override.sh`: Packaging script for early CPIO archive (dev-only; not installed).
