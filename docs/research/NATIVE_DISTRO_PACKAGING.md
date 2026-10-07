# Research: Native Distribution Packaging on Lenovo D330-10IGL

Provides native package recipes across major Linux package managers:
1. **Debian / Ubuntu / Linux Mint (.deb)**:
   - Built via `dpkg-buildpackage -us -uc -b` using standard debhelper 13.
   - Deploys udev rules, sysctl, systemd services, and triggers `update-initramfs`.
2. **Fedora / openSUSE / RHEL (.rpm)**:
   - Built via `rpmbuild -ba packaging/rpm/lenovo-d330-fix.spec`.
   - Post-install script executes `systemd-hwdb update` and enables core units.
3. **Arch Linux / Manjaro (PKGBUILD)**:
   - Built via `makepkg -si`.
   - Native Arch packaging format integrating smoothly with pacman and AUR.
