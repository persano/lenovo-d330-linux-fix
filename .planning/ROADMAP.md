# ROADMAP: Lenovo D330-10IGL Linux Parity Project

## Milestone 1: Display & Power Parity (v1.0) - [COMPLETED]
*Archived to [`.gsd/milestones/v1.0-ROADMAP.md`](milestones/v1.0-ROADMAP.md)*
- [x] Phase 0: Project & Repository Setup (`7e4b76e`)
- [x] Phase 1: Community Research & Prior Art Ingestion (`a60bdf1`)
- [x] Phase 2: Official Lenovo Windows Driver Baseline Acquisition (`c489f88`)
- [x] Phase 3: Hardware Telemetry & ACPI Extraction (`d09d0c3`)
- [x] Phase 4: Differential Analysis & Reverse Engineering (`d5f20bc`)
- [x] Phase 5: Patch Generation & DKMS Delivery (`7c313fb`)

---

## Milestone 2: Peripheral Parity & Tablet Usability (v2.0) - [COMPLETED]
*Archived to [`.gsd/milestones/v2.0-ROADMAP.md`](milestones/v2.0-ROADMAP.md)*
- [x] Phase 6: Touchscreen & Active Pen Calibration (`4126a9a`)
- [x] Phase 7: Detachable Dock & Tablet Mode Daemon (`bb7b4c5`)
- [x] Phase 8: Audio & Microphone UCM Profiles (`b2cb1e7`)
- [x] Phase 9: Battery Life & Power Governors (`1858351`)

---

## Milestone 3: Vision, Ergonomics & Multimedia (v3.0) - [COMPLETED]
*Archived to [`.gsd/milestones/v3.0-ROADMAP.md`](milestones/v3.0-ROADMAP.md)*
- [x] Phase 10: Intel IPU3 Dual Camera Pipeline
- [x] Phase 11: 4GB RAM & 64GB eMMC Storage Optimization
- [x] Phase 12: Audio Refinements (Dolby DSP Curve & Anti-Pop Jack Delay)
- [x] Phase 13: Lenovo Hardware Controls (`ideapad_laptop` VPC2004)
- [x] Phase 14: Display Ergonomics (Backlight PWM Anti-Flicker & ICC Profile)

---

## Milestone 4: Connectivity, Firmware & System Boot (v4.0) - [ACTIVE]

### Phase 15: Early Bootloader, Console & Plymouth Orientation
- [ ] Configure native landscape early framebuffer console (`fbcon=rotate:1`)
- [ ] Deploy Plymouth initramfs rotation filter hook for 800x1280 panel
- [ ] Configure GRUB touch-friendly font scaling and menu layout
- [ ] Deploy emergency screen refresh hotkey script (`tools/d330-refresh-screen.sh`)
- [ ] Create boot orientation test harness (`scripts/test_boot_orientation.sh`)

### Phase 16: ACPI DSDT Clean Initrd Override
- [ ] Decompile DSDT and secondary SSDT table declaring duplicate `\_SB.PCI0.RP04`
- [ ] Remove duplicate root port objects to eliminate `AE_ALREADY_EXISTS` kernel errors
- [ ] Package recompiled AML table into prepended early CPIO archive (`/boot/acpi-override.cpio`)
- [ ] Update initramfs / bootloader hook to load ACPI override table
- [ ] Create ACPI dmesg validation test script (`scripts/test_acpi_cleanliness.sh`)

### Phase 17: Sensor Hysteresis & Ambient Light Sensor (ALS) Auto-Dimming
- [ ] Configure accelerometer (`BOSC0200`) orientation debounce filter & hysteresis window
- [ ] Configure Ambient Light Sensor (`ACPI0008`) exponential moving average smoothing
- [ ] Integrate ALS with `iio-sensor-proxy` and D-Bus ambient light service
- [ ] Create sensor debounce and ALS verification harness (`scripts/test_sensor_als.sh`)

### Phase 18: Touchpad & Active Pen Gestures Tuning
- [ ] Configure libinput touchpad palm rejection, edge scrolling, and multi-finger tap defaults
- [ ] Map Active Pen stylus barrel buttons (eraser, secondary click) across Wayland and X11
- [ ] Configure touch gesture thresholds for 10.1" screen scaling
- [ ] Create touchpad and stylus button verification test script (`scripts/test_gestures_pen.sh`)

### Phase 19: MicroSD Storage Expansion & Modular Cellular LTE
- [ ] Deploy automated MicroSD `/home` and `/data` GPT setup utility (`tools/d330-microsd-setup.sh`)
- [ ] Package modular `xmm7360-pci` DKMS module for models equipped with LTE modem
- [ ] Configure ModemManager FCC unlock handler (`fcc-unlock.d/8086:7360`)
- [ ] Create storage and cellular detection test harness (`scripts/test_storage_cellular.sh`)

### Phase 20: Critical Low-Battery Auto-Hibernate Daemon
- [ ] Configure systemd hybrid sleep / low-battery hibernate trigger at <5% capacity
- [ ] Ensure swap partition / zram swap state machine safely suspends to disk on critical battery
- [ ] Test wake from hibernation and display state restoration
- [ ] Create low-battery hibernate validation test script (`scripts/test_auto_hibernate.sh`)

---

## Milestone 5: CI/CD & Remastered Live ISO Distribution (v5.0) - [READY]

### Phase 21: Native Distribution Packaging (.deb, .rpm, PKGBUILD)
- [ ] Author Debian / Ubuntu `.deb` packaging files for `lenovo-d330-fix`
- [ ] Author Fedora / openSUSE `.spec` packaging files for RPM builds
- [ ] Author Arch Linux `PKGBUILD` packaging recipe for AUR
- [ ] Verify package builds and dependencies across all formats (`scripts/test_distro_packaging.sh`)

### Phase 22: Automated Live ISO Remaster Build Harness
- [ ] Author `scripts/build_live_iso.sh` remaster script for Ubuntu 24.04 LTS and Linux Mint LMDE
- [ ] Extract live filesystem squashfs, inject all D330 kernel patches, DKMS, UCM2, and udev rules
- [ ] Repackage bootable hybrid UEFI/BIOS ISO image with landscape Plymouth and touch GRUB
- [ ] Create automated ISO test and validation script (`scripts/test_iso_integrity.sh`)

### Phase 23: GitHub Actions CI/CD Release Pipeline
- [ ] Create `.github/workflows/build-packages.yml` building `.deb`, `.rpm`, and DKMS on tags
- [ ] Create `.github/workflows/build-iso.yml` generating remastered bootable Live ISO artifacts
- [ ] Automate release asset uploads on semantic version tags (`v3.0`, `v4.0`, `v5.0`)
- [ ] Verify GitHub Actions workflow syntax and linters
