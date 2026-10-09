# Distribution-Specific Kernel Replacement & Installer Customization Guide

This guide outlines the workflows we will execute once you choose your target distribution (Linux Mint, Ubuntu, Debian, Fedora, Arch, ChromeOS Flex, or Android-x86/Bliss OS).

> For a copy-paste walkthrough on a fresh **Kubuntu 26.04** install (Wayland,
> touch/touchpad, RNNoise), see [`KUBUNTU_INSTALL_STEPS.md`](KUBUNTU_INSTALL_STEPS.md).

---

## Strategy A: Overwrite Kernel on an Already Installed System

When you have installed a distro on the tablet and want to patch its active kernel:

### 1. Via Standalone DKMS Module (Zero Kernel Recompilation)
Works on all distributions with kernel headers:
```bash
sudo ./scripts/install_dkms.sh --install
```
The DKMS `lenovo_d330_fix.ko` module is a DMI-matched diagnostic banner; it does not enforce the discharge delay. modprobe disables PSR/FBC, and the 600 ms clamp comes from the Option 2 kernel patch (`patches/d330_display_resume_fix.patch`).

### 2. Building Patched Kernel `.deb` (Ubuntu / Linux Mint / Debian)
We will compile patched kernel packages (`linux-image-*.deb` and `linux-headers-*.deb`). Run this in a scratch directory, not inside the repo, and reference the patch by absolute path:
```bash
# 1. Fetch the UNSIGNED kernel source (the running image is often a signed
#    wrapper whose source tree has no drivers/)
WORK="$HOME/d330-kernel"; mkdir -p "$WORK" && cd "$WORK"
SRC_PKG="$(dpkg-query -W -f='${Source}' "linux-image-unsigned-$(uname -r)" 2>/dev/null | awk '{print $1}')"
case "$SRC_PKG" in ""|*signed*) SRC_PKG=linux ;; esac
sudo apt build-dep -y "$SRC_PKG"
apt source "$SRC_PKG"
SRC_DIR="$(ls -d "${SRC_PKG}"-*/ 2>/dev/null | head -1)"
[ -n "$SRC_DIR" ] || echo ">>> no ${SRC_PKG}-* source dir; check the apt source output above"
cd "$SRC_DIR"

# 2. Apply patch (dry-run first; a clean dry-run is required before building)
patch -p1 --dry-run < /path/to/lenovo-d330-linux-screen-fix/patches/d330_display_resume_fix.patch
patch -p1           < /path/to/lenovo-d330-linux-screen-fix/patches/d330_display_resume_fix.patch

# 3. Fast compile .deb packages
make bindeb-pkg -j$(nproc) LOCALVERSION=-d330-fix

# 4. Install over active system
sudo dpkg -i ../linux-image-*-d330-fix_*.deb ../linux-headers-*-d330-fix_*.deb
sudo update-grub
```
The detailed walkthrough, including how to verify the patch actually landed in the source tree before building, is in [`KUBUNTU_INSTALL_STEPS.md`](KUBUNTU_INSTALL_STEPS.md) step 4.

### 3. Building Patched Kernel on Fedora / RHEL
Using `kernel-install` or custom RPM:
```bash
dnf download --source kernel
rpm2cpio kernel-*.src.rpm | cpio -idmv
# Place d330_display_resume_fix.patch in SPECS/SOURCES and build rpm
rpmbuild -bb kernel.spec --without debug --without debuginfo
sudo dnf install ~/rpmbuild/RPMS/x86_64/kernel-*.rpm
```

### 4. Building Patched Kernel on Arch Linux
Using custom PKGBUILD:
```bash
asp checkout linux
cd linux/trunk
# Add d330_display_resume_fix.patch to THIS distribution-kernel PKGBUILD's
# prepare() step. It does not belong in this repository's
# packaging/arch/PKGBUILD, which only ships configs/tools and never builds a kernel.
makepkg -s -i
```

---

## Strategy B: Modifying the Installation ISO Media

If you want the installer itself to boot with the display fix pre-applied:

### 1. Simple Bootloader Edit on Live USB
Before booting the live USB installer on the D330 tablet:
1. Plug USB into another computer.
2. Open `boot/grub/grub.cfg` or `EFI/BOOT/grub.cfg` on the USB drive.
3. Append kernel boot parameters:
   ```text
   i915.enable_psr=0 i915.enable_fbc=0 fbcon=nodefer video=efifb:nobgrt
   ```
This prevents screen blackout and inverted orientation during the installer session.

### 2. Automated ISO Remastering (Ubuntu / Debian / Mint)
We will unpack the ISO squashfs, replace the kernel/modules with our patched build, and rebuild the bootable ISO using `xorriso`.
