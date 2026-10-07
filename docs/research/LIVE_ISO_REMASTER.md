# Research: Automated Live ISO Remastering for Lenovo D330-10IGL

## 1. Motivation
While users can manually apply patches post-installation, booting an unpatched vanilla live USB installer (Ubuntu 24.04, Linux Mint, LMDE) presents a frustrating initial experience:
- Screen is oriented sideways at 90 degrees.
- Touchscreen coordinates are inverted.
- Suspend during install freezes the panel.
- Audio outputs to "Dummy Output".
- 4GB RAM without zram risks out-of-memory lockups during ubiquity/calamares install.

## 2. Remastering Pipeline
`scripts/build_live_iso.sh` implements an automated, idempotent pipeline:
1. **Extraction**: Unpacks official ISO layout and `casper/filesystem.squashfs`.
2. **Component Injection**: Copies all D330 system configurations, udev rules, UCM2 audio topologies, zram memory swap, and control tools into the squashfs root.
3. **Initramfs Generation**: Executes `update-initramfs -u` inside the chroot environment to embed display orientation and sensor rules into the boot ramdisk.
4. **Compression**: Repacks `filesystem.squashfs` with `zstd` level 19 for maximum compression and fast live decompression.
5. **Hybrid UEFI Mastering**: Uses `xorriso` to construct a hybrid ISO bootable across both UEFI GOP 64-bit and legacy BIOS environments.
