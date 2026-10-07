# Display Ergonomics Patches for Lenovo IdeaPad D330-10IGL

Provides backlight PWM anti-flicker frequency scaling, Intel Dynamic Refresh Rate Switching (DRRS), and calibrated sRGB D65 ICC color profile.

## File Hierarchy
- `etc/modprobe.d/lenovo-d330-display-pwm.conf`: DRRS activation parameter.
- `etc/systemd/system/lenovo-d330-backlight-pwm.service`: Anti-flicker service.
- `color/icc/Lenovo-D330-sRGB-D65.icc`: Calibrated sRGB D65 color profile.
