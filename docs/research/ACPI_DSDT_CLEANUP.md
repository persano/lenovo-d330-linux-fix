# Research: ACPI DSDT Clean Initrd Override on Lenovo D330-10IGL

## 1. Root Cause: Duplicate `\_SB.PCI0.RP04`
On the Lenovo IdeaPad D330-10IGL (Type 82H0 / 81MD), the OEM UEFI BIOS firmware presents two ACPI tables defining the exact same PCI Root Port 4 device object:
- Primary DSDT (Differentiated System Description Table)
- Secondary SSDT (Secondary System Description Table)

When the Linux kernel ACPICA subsystem boots and parses system tables:
```
ACPI Error: [RP04] Namespace lookup failure, AE_ALREADY_EXISTS (20220331/dswload2-326)
ACPI Error: 1 table load failures, 12 successful (20220331/tbxfload-215)
```
While Linux continues booting, this causes:
- Failure to parse power management methods (`_PS0`, `_PS3`) on downstream PCI devices attached to RP04 (such as the SD card reader or LTE modem).
- Unnecessary kernel error logging on every boot.

## 2. Solution: Early CPIO Initrd Override
The Linux kernel supports overriding ACPI tables at boot time without modifying motherboard UEFI BIOS firmware via an uncompressed CPIO archive prepended to the initramfs (`kernel/firmware/acpi/dsdt.aml`).

1. `patches/acpi_override/dsdt_override.asl` contains the clean, authoritative definition of `RP04`.
2. `tools/d330-acpi-override.sh` compiles this with `iasl` into `dsdt.aml` and builds `/boot/acpi-override.cpio`.
3. `51-lenovo-d330-acpi-override.cfg` configures GRUB to load `/boot/acpi-override.cpio` as an early initrd.
4. ACPICA detects the override table, replaces the flawed OEM table, and boots cleanly with zero namespace collisions.
