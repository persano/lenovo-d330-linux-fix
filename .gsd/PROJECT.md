# PROJECT: Lenovo IdeaPad D330-10IGL Linux Parity Project

## Target Platform
- **Device**: Lenovo IdeaPad D330-10IGL (Type 82H0) & D330-10IGM (81H3, 81MD)
- **SoC**: Intel Gemini Lake Refresh (Celeron N4020 / N4120)
- **GPU**: Intel UHD Graphics 600 (GLK 12 EU)
- **Panel**: 10.1" 1280x800 / 1920x1200 MIPI-DSI / eDP tablet panel (portrait native orientation)
- **Digitizer**: Goodix I2C Touchscreen (`GDIX1001`) with Lenovo Active Pen support
- **Sensors**: BOSC0200 accelerometer / IIO sensor subsystem, Hall effect dock sensor (`INT33D5`)
- **Target OS**: Linux (Kernel 5.15 – 6.x+, ChromeOS, Android-x86)

## Current State: Milestone 1 Shipped (v1.0)
- Root cause identified: TCON 500ms discharge requirement ($t_{11}\text{-}t_{12}$).
- Shipped unified DRM kernel patch with DMI quirk match for Type `82H0` and $\ge 600\text{ ms}$ PPS clamp.
- Shipped standalone DKMS package (`lenovo_d330_fix.ko`) for zero-recompile deployment.
- Shipped ChromeOS (`5.15`, `6.6`) and Android-x86 / Bliss OS patches and HAL configs.
- Shipped automated installation and stress-test harnesses.

## Next Milestone: Milestone 2 (v2.0) - Peripheral Parity & Tablet Usability
1. **Phase 6: Touchscreen & Active Pen Calibration**: Fix coordinate mismatch via udev libinput matrix, eliminate post-wake I2C touch freeze via unbind/rebind hook, configure palm rejection.
2. **Phase 7: Detachable Dock & Tablet Mode Daemon**: Hall effect sensor integration, automatic laptop/tablet mode switching (orientation lock, on-screen keyboard toggle, touchpad gate).
3. **Phase 8: Audio & Microphone UCM Profiles**: ALSA UCM2 profiles for Intel SST/SOF, fixing headphone jack auto-mute and internal digital mic.
4. **Phase 9: Battery Life & Power Governors**: Intel P-State / EPP power profiles, eMMC/USB autosuspend tuning for 6W Celeron.
