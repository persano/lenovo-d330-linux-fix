# PROJECT: Lenovo IdeaPad D330-10IGL Linux Display & Power Parity

## Target Platform
- **Device**: Lenovo IdeaPad D330-10IGL (Type 82H0)
- **SoC**: Intel Gemini Lake Refresh (Celeron N4020 / N4120)
- **GPU**: Intel UHD Graphics 600 (Genoa / GLK 12 EU)
- **Panel**: 10.1" 1280x800 / 1920x1200 MIPI-DSI / eDP tablet panel (portrait native orientation)
- **Sensors**: BOSC0200 accelerometer / IIO sensor subsystem
- **Target OS**: Linux (Kernel 6.x+, standard DRM/i915 stack)

## Mission & Architecture Goals
Resolve display resume failure and orientation/power parity issues on Lenovo IdeaPad D330-10IGL under Linux:
1. Identify root cause of screen blanking / resume failure after suspend / S3 / S0ix sleep.
2. Ingest community workarounds (e.g. `lucasgabmoreno/linuxmint_lenovod330`) and extract hardware quirks.
3. Compare Windows graphics driver (`igdkmd64.sys`) power sequences (PPS, panel delays, GPIOs, DSI VBT timing) with Linux `i915` implementation.
4. Produce reproducible hardware telemetry extraction scripts for target device.
5. Deliver a production-grade DRM / kernel patch or DKMS module with DMI quirks (`82H0`).

## Definition of Done
- Panel initializes with correct orientation from boot (EFIFB/DRM) through desktop compositor.
- Suspend-to-RAM / S0ix resume restores panel backlight, DSI/eDP link, and display pipeline without freeze or blank screen.
- Accelerometer (`BOSC0200`) correctly mapped via udev hwdb.
- Clean kernel patch and DKMS packaging ready for deployment.
