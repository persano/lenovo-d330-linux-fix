# CONTEXT: Hardware Telemetry, Constraints & Hypothesis Tree

## Target Hardware Specifications
- **Model**: Lenovo IdeaPad D330-10IGL
- **Machine Type**: 82H0
- **Processor**: Intel Celeron N4020 / N4120 (Gemini Lake Refresh)
- **Graphics**: Intel UHD Graphics 600
- **Panel Interface**: MIPI-DSI / eDP (Portrait native panel, typically 800x1280 or 1200x1920)
- **Orientation Matrix**: Right-up portrait default orientation requiring 90 or 270 degree rotation
- **Sensor ACPI ID**: `BOSC0200` (Bosch accelerometer)
- **Mode Switch**: Hall sensor / detachable keyboard dock

## Hypothesis Tree: Display Resume Failure
1. **Hypothesis 1 (Panel Power Sequencing Timing)**: Linux `i915` PPS (Panel Power Sequencing) delays (`power_down_delay`, `backlight_off_delay`, `reset_delay`) do not match vendor panel requirements. When transitioning from D3 to D0, panel power rails are cut or pulsed too fast without meeting minimum off-time (`t11_t12`).
2. **Hypothesis 2 (MIPI-DSI VBT / GPIO Rail Toggle)**: Panel power enable pin handled via ACPI GPIO (`GPO0` / `GPO1`) or PMIC rail is not properly toggled on resume because DMI quirk is absent in `intel_dsi_vbt.c` / `intel_panel.c`.
3. **Hypothesis 3 (PSR / FBC State Machine Lockup)**: Panel Self Refresh (PSR) or Framebuffer Compression (FBC) causes GPU pipe hang upon waking up from DC6 / package C-states.
4. **Hypothesis 4 (GOP / VBT Handover)**: EFI GOP sets display state that the kernel framebuffer inherits, but on resume without firmware intervention, `i915` re-initializes transmitter in mode unaccepted by panel bridge IC or timing controller (TCON).
