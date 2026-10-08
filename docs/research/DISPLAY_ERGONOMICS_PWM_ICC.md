# Research: Display Ergonomics, PWM Anti-Flicker & ICC Profile on Lenovo D330-10IGL

## 1. Backlight Dimming & Pulse Width Modulation (PWM) Flicker
The Lenovo IdeaPad D330-10IGL uses a 10.1" IPS panel (typically 1280x800 WXGA or 1920x1200 FHD).
Under default Intel i915 settings:
- The backlight driver modulates LED intensity using Pulse Width Modulation (PWM) at approximately 200 Hz.
- At brightness levels below 60%, the 200 Hz stroboscopic effect induces eye strain, fatigue, and visual discomfort for sensitive users.
- The PWM clock frequency can be raised to 1000 Hz via `d330-backlight-pwm.py --apply`; the former `lenovo-d330-backlight-pwm.service` boot unit was removed in Phase 37 because it reported success without writing any register. The tool now requires `intel_reg` and only reports `[OK]` after a verified register read-back delta, otherwise it prints `[SKIP]`/`[FAIL]` and exits non-zero. At 1000 Hz the flicker becomes imperceptible to human vision and modern camera sensors.

## 2. Dynamic Refresh Rate Switching (DRRS)
Gemini Lake UHD Graphics 600 supports Intel DRRS:
- When static content (reading an e-book, document editing) is displayed for more than 1 second, the panel drops refresh rate from 60 Hz down to 48 Hz.
- When cursor movement or video playback occurs, it instantly jumps back to 60 Hz without visual tearing.
- Enabled via `options i915 enable_drrs=1`, yielding ~8% GPU display engine power reduction.

## 3. Calibrated ICC Color Profile (`Lenovo-D330-sRGB-D65.icc`)
Out-of-the-box panels often show a slight cold blue tint (color temperature ~7200K).
The provided calibrated ICC profile targets:
- Illuminant D65 (6504K neutral daylight)
- sRGB color space transfer curve (2.2 pure gamma)
- Standard monitor class profile compatible with GNOME Color, KDE KolorServer, and `colord`.
