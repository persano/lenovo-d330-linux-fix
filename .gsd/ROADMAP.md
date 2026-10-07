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

## Milestone 2: Peripheral Parity & Tablet Usability (v2.0) - [ACTIVE]

### Phase 6: Touchscreen & Active Pen Calibration
- [ ] Add udev libinput calibration matrix for D330 touch digitizer (`GDIX1001`)
- [ ] Add X11 coordinate transformation matrix configuration (`50-touchscreen-d330.conf`)
- [ ] Implement I2C touch controller unbind/rebind sleep resume stabilization hook
- [ ] Create DMI quirk patch for `touchscreen_dmi.c` / `goodix.c`
- [ ] Configure palm rejection and stylus pressure thresholds for Lenovo Active Pen
- [ ] Verify touch accuracy, multi-touch gestures, and wake recovery

### Phase 7: Detachable Dock & Tablet Mode Daemon
- [ ] Analyze ACPI Hall effect hinge sensor / keyboard dock events (`INT33D5`)
- [ ] Build lightweight tablet mode event handler daemon (`d330-tablet-daemon`)
- [ ] Implement dock auto-switching: force landscape & enable touchpad on dock; auto-rotate & enable on-screen keyboard on undock
- [ ] Package systemd service and installer integration
- [ ] Verify hotplug detach and re-attach cycles

### Phase 8: Audio & Microphone UCM Profiles
- [ ] Identify audio codec and routing topology (Intel SST / SOF + ALC269/ES8316)
- [ ] Author ALSA Use Case Manager (UCM2) profile for Lenovo D330
- [ ] Fix headphone jack auto-mute and internal microphone input gain
- [ ] Package UCM2 files into installation harness
- [ ] Verify audio playback, headphone switching, and mic capture

### Phase 9: Battery Life & Power Governors
- [ ] Configure Intel P-State / EPP energy performance preference profiles for 6W Celeron
- [ ] Author TLP / power-profiles-daemon configuration template
- [ ] Optimize eMMC and USB autosuspend runtime power management
- [ ] Verify battery runtime and thermal headroom under stress
