# Display Ergonomics Patches for Lenovo IdeaPad D330-10IGL

Provides Intel Dynamic Refresh Rate Switching (DRRS), an optional PWM anti-flicker frequency programmer, and a calibrated sRGB D65 ICC color profile.

## File Hierarchy
- `etc/modprobe.d/lenovo-d330-display-pwm.conf`: DRRS activation parameter.
- `color/icc/Lenovo-D330-sRGB-D65.icc`: Calibrated sRGB D65 color profile.

## PWM anti-flicker
The former `lenovo-d330-backlight-pwm.service` boot unit was removed in Phase 37
(it reported `[OK]` without writing any register). PWM frequency scaling is now
available only on demand via `tools/d330-backlight-pwm.py --apply`, which
requires `intel_reg` and reports success only after a verified read-back delta.
Without `intel_reg` it prints `[SKIP]` and exits non-zero.
