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

## Milestone 3: Vision, Ergonomics & Multimedia (v3.0) - [ACTIVE]

### Phase 10: Intel IPU3 Dual Camera Pipeline
- [ ] Bind sensor drivers (`ov2680`/`ov5648`/`hm2056`) and `INT3472` regulator in kernel
- [ ] Author `libcamera` IPU3 IPA software 3A tuning profiles (`ov2680.yaml`, `ov5648.yaml`)
- [ ] Configure PipeWire camera portal / `v4l2loopback` virtual webcam bridge (`/dev/video0`, `/dev/video1`)
- [ ] Create camera verification and frame capture harness (`scripts/test_cameras.sh`)

### Phase 11: 4GB RAM & 64GB eMMC Storage Optimization
- [ ] Deploy ZRAM swap generator with `zstd` compression (3GB RAM swap pool)
- [ ] Tune virtual memory dirty page writeback (`sysctl.d/99-lenovo-d330-zram.conf`)
- [ ] Optimize eMMC I/O elevator and enable periodic TRIM service
- [ ] Create memory compression and eMMC stress test harness (`scripts/test_memory_storage.sh`)

### Phase 12: Audio Refinements (Dolby DSP Curve & Anti-Pop Jack Delay)
- [ ] Author PipeWire filter-chain equalizer / limiter preset for 1W tablet speakers
- [ ] Configure ALSA DAC power ramp delay in modprobe (`power_save_node_latency=1000`)
- [ ] Eliminate headphone sleep wake pop and speaker high-volume distortion
- [ ] Create audio DSP verification harness (`scripts/test_audio_dsp.sh`)

### Phase 13: Lenovo Hardware Controls (`ideapad_laptop` VPC2004)
- [ ] Implement Battery Conservation Mode toggle (60% threshold via `VPC2004:00/conservation_mode`)
- [ ] Implement top-row Fn-Lock toggle (`VPC2004:00/fn_lock`)
- [ ] Configure dock base USB 2.0 power management
- [ ] Build unified CLI control tool (`tools/d330-ctl`) and TLP integration

### Phase 14: Display Ergonomics (Backlight PWM Anti-Flicker & ICC Profile)
- [ ] Configure Intel `i915` backlight PWM frequency scaling to 1000 Hz
- [ ] Package calibrated sRGB D65 ICC color profile for 10.1" IPS panel
- [ ] Enable Intel Dynamic Refresh Rate Switching (DRRS 48Hz/60Hz)
- [ ] Create display ergonomics test harness (`scripts/test_display_ergonomics.sh`)

---

## Milestone 4: Connectivity, Firmware & System Boot (v4.0) - [PLANNED]
- [ ] Phase 15: Early Plymouth Boot Splash & GRUB Orientation (`fbcon=rotate:1`)
- [ ] Phase 16: ACPI DSDT Clean Initrd Override (`/boot/acpi-override.cpio`)
- [ ] Phase 17: Sensor Hysteresis & Ambient Light Sensor (ALS) Auto-Dimming
- [ ] Phase 18: MicroSD Storage Expansion (`tools/d330-microsd-setup.sh`) & Modular LTE (`xmm7360-pci`)

---

## Milestone 5: CI/CD & Remastered Live ISO Distribution (v5.0) - [PLANNED]
- [ ] Phase 19: Automated ISO Remaster Build Harness (Ubuntu 24.04 / Linux Mint)
- [ ] Phase 20: GitHub Actions CI/CD Release Pipeline Publishing Pre-Patched ISOs
