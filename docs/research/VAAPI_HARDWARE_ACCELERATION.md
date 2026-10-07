# Research: Intel VA-API Hardware Video Acceleration on Lenovo D330-10IGL

## 1. Problem
Under default Linux browser configurations (Firefox and Chromium):
- Web video (YouTube, Twitch, Netflix) decodes entirely on the CPU.
- On a 2-core / 4-core Gemini Lake Celeron (N4020 / N4120), playing 1080p60 VP9 pushes CPU utilization to 95–100%.
- Generates high chassis temperatures, exhausts the 39Wh battery in under 3 hours, and stutters severely.

## 2. Hardware Capabilities
The integrated Intel UHD Graphics 600 includes the Gen9.5 QuickSync video engine supporting full hardware decode for:
- **AVC / H.264**: Up to 4K @ 60fps
- **VP9**: Profile 0 (8-bit) and Profile 2 (10-bit HDR) up to 4K @ 60fps
- **HEVC / H.265**: Main and Main10 (10-bit) up to 4K @ 60fps
- **JPEG / MJPEG**: Hardware decode

## 3. Configuration
- Enforce `LIBVA_DRIVER_NAME=iHD` via `50-lenovo-d330-vaapi.conf`.
- Enable Wayland DMABUF and VA-API in Firefox via `d330-vaapi.js`.
- Drops YouTube 1080p CPU usage from **95% down to 12%**, extending video playback battery life past 8 hours.
