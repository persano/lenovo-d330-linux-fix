# Research: ACPI `\_SB.PCI0.RP04` Duplicate Objects on Lenovo D330-10IGL

**Status: measured on hardware, conclusion is DO NOT OVERRIDE.** The earlier
plan in this file was tested end to end on the D330 and both routes were
rejected for cause. See section 4.

## 1. The actual defect

Every boot logs 18 duplicated objects under PCI root port 4, two kernel lines
each, 36 lines total:

```
ACPI BIOS Error (bug): Failure creating named object [\_SB.PCI0.RP04.PCA4], AE_ALREADY_EXISTS (20251212/dswload2-326)
ACPI Error: AE_ALREADY_EXISTS, During name lookup/catalog (20251212/psobject-220)
```

Objects: `PCA4 SLOT RSTG PWRG WAKG SCLK WKEN LNRD UPRD _S0W _DSW PXP _PR0
_PR3 _S3D _S3W _S4D _S4W`.

Decompiling the live tables shows the cause. The DSDT defines RP04 twice over:

- `Device (RP04)` with `_ADR 0x00130000`
- `Scope (_SB.PCI0.RP04)` carrying 19 members
- `Scope (_SB.PCI0.RP04.PXSX)` with the port's own methods

and `SSDT4` carries a second `Scope (\_SB.PCI0.RP04)` with 18 members of the
same names. DSDT loads first, so ACPICA keeps the DSDT versions and skips
every SSDT4 copy. `HDAH` was never among them, the earlier note claiming so
was wrong.

Member comparison (this is what makes the errors benign):

| | members |
|---|---|
| SSDT4 scope | `PCA4 SLOT RSTG PWRG WAKG SCLK WKEN LNRD UPRD _S0W _DSW PXP _PR0 _PR3 _S3D _S3W _S4D _S4W` (18) |
| DSDT scope | the same 18 plus `WGUR` |
| SSDT4-only | **none** |

The firmware ships a working set either way. The only thing lost is log
noise, and `RP04._INI` and the port's power resources run fine on the DSDT
copies.

## 2. Kernel override mechanics (verified in 7.0 source)

`drivers/acpi/tables.c`:

- `acpi_table_upgrade()` walks the *uncompressed* early cpio at
  `initrd_start` looking for the literal path `kernel/firmware/acpi/`, and
  requires `file.size == table->length` plus a valid checksum.
- `acpi_table_initrd_override()` accepts an initrd table only on
  **signature + oem_id + oem_table_id** all matching, **and**
  `initrd oem_revision > firmware oem_revision`.
- `security_locked_down(LOCKDOWN_ACPI_TABLES)` disables it entirely.

`CONFIG_ACPI_TABLE_UPGRADE=y`, Secure Boot disabled, lockdown `[none]` on the
D330, so the mechanism itself is available.

## 3. The GRUB hook had a real bug

`GRUB_EARLY_INITRD_LINUX_CUSTOM` must hold a **bare file name**, not a path.
`grub.d/10_linux` does:

```sh
initrd_early=
for i in ${GRUB_EARLY_INITRD_LINUX_STOCK} ${GRUB_EARLY_INITRD_LINUX_CUSTOM}; do
    if test -e "${dirname}/${i}" ; then initrd_early="${initrd_early} ${i}"; fi
done
```

`dirname` is the kernel directory on the boot filesystem (`/@/boot` here), so
the old absolute path was tested against `/@/boot//boot/acpi-override.cpio`,
never matched, and `update-grub` silently emitted no early initrd. Fixed in
`patches/acpi_override/etc/default/grub.d/51-lenovo-d330-acpi-override.cfg`.

## 4. Both override routes were tried and rejected

Built with a binary patch rather than `iasl`: the Scope item was located by
decoding PkgLength and the NameString, removed, then the table length and
checksum were recomputed. Everything outside the removed item is
byte-identical by construction, so these tests isolate the effect of the
removal itself.

**Route A, replace SSDT4. Measured on hardware: made it much worse.**
All ten firmware SSDTs share `oem_id=LENOVO` and `oem_table_id=CB-01   `, so
the kernel's ID match replaced **all ten** with the one patched table, which
then loaded ten times:

```
ACPI: SSDT ACPI table found in initrd [kernel/firmware/acpi/ssdt4.aml][0x314a]
ACPI: Table Upgrade: override [SSDT-LENOVO-CB-01   ]
```

`AE_ALREADY_EXISTS` went from 36 to **521**, duplicating `XHC.RHUB.SS0x`,
`USBC`, `SDPR` and more. The eMMC also renumbered `mmcblk0` to `mmcblk1`.
There is no way to name one SSDT when ten share the IDs, so this route is
closed.

**Route B, replace the DSDT. Measured on hardware: also worse.**
The DSDT has a unique signature, so targeting works, and `AE_ALREADY_EXISTS`
did drop to 0. But `WGUR` and the `PCIA` field unit exist only in the DSDT
scope, and dropping them broke the surviving methods at runtime:

```
ACPI BIOS Error (bug): Could not resolve symbol [\PCIA], AE_NOT_FOUND   (x8)
ACPI BIOS Error (bug): Could not resolve symbol [\PWRG], AE_NOT_FOUND
ACPI BIOS Error (bug): Could not resolve symbol [\SCLK], AE_NOT_FOUND
ACPI BIOS Error (bug): Could not resolve symbol [\WAKG], AE_NOT_FOUND
ACPI BIOS Error (bug): Could not resolve symbol [\LNRD], AE_NOT_FOUND
ACPI Error: Aborting method \_SB.PCI0.RP04._INI due to previous error (AE_NOT_FOUND)
```

Trading 36 cosmetic lines for real namespace breakage on the SD/LTE root port
is a bad trade. Reverted, verified back at 36 `AE_ALREADY_EXISTS` and 0
`AE_NOT_FOUND`.

## 5. Do not build `dsdt_override.asl`

It is a 15-line sketch declaring only `Device (RP04)`. Packed as
`kernel/firmware/acpi/dsdt.aml` it **replaces the whole DSDT** (54771 bytes,
13205 lines, EC, battery, every PCI scope). It has never been compiled, and
building it as written would gut the ACPI namespace. The GRUB snippet stays
guarded on `/boot/acpi-override.cpio`, which the installer never creates.

## 6. Reproducing a patch

```sh
# header: sig, length@4, oem_revision@24
od -A n -t x1 -N 36 /sys/firmware/acpi/tables/DSDT
# Scope item = opcode 0x10, then PkgLength, then the NameString
# (MultiNamePrefix 0x2F + count for a three-segment path, not dots)
# after removal: length@4 = new size, checksum@9 so all bytes sum to 0
python3 patch.py   # see /home/santiago/acpi-ovr on the device
```
