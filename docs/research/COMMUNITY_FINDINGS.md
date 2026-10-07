# Community Research & Prior Art Ingestion: Lenovo IdeaPad D330-10IGL

## 1. Executive Summary
The Lenovo IdeaPad D330 (specifically the Gemini Lake Refresh 10IGL variant, Machine Type 82H0) suffers from severe display initialization and resume failure under Linux:
- **Primary Failure**: Upon entering suspend/sleep (`S3` / `S0ix`), the display pipeline fails to recover, resulting in permanent black screen / backlight failure or hard lockup.
- **Secondary Failure**: The internal display panel is natively portrait-oriented (800x1280 or 1200x1920 tablet panel) requiring hardware/DRM rotation quirks and accelerometer coordinate calibration.
- **Community Response**: Until now, community efforts (e.g. `lucasgabmoreno/linuxmint_lenovod330`) have relied on destructive workarounds: completely masking systemd sleep targets, disabling power management, and executing brute-force X11 `xrandr` reset scripts upon user keypress or orientation change.

---

## 2. Ingested Community Repository Analysis: `lucasgabmoreno/linuxmint_lenovod330`

### 2.1 Hardware Variants Cataloged
| Machine Type | Model | Processor | GPU | Native Resolution | Storage | RAM |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **81H3** | D330-10IGM | Pentium Silver N5000 | Intel UHD 605 | 1920x1200 (FHD portrait) | 128 GB eMMC | 4 GB |
| **81MD** | D330-10IGM | Celeron N4000 | Intel UHD 600 | 800x1280 (HD portrait) | 64 GB eMMC | 4 GB |
| **82H0** | D330-10IGL | Celeron N4020 / N4120 | Intel UHD 600/605 | 800x1280 (HD portrait) | 64/128 GB eMMC | 4/8 GB |

*Key Distinction*: The `82H0` is Gemini Lake Refresh (GLK-R) with stepping/firmware differences from the earlier `81H3`/`81MD` (GLK). Upstream kernel quirks frequently addressed `81H3`/`81MD` while leaving `82H0` partially unconfigured.

---

### 2.2 Brute-Force X11 Display Reset (`lenovod330-refreshscreen.sh`)
The community script attempts to recover from panel blackouts by interrogating X11 output parameters via `xrandr` and cycling display state:

```bash
#!/bin/bash
BRIGHT=$(echo $(xrandr --verbose | grep 'Brightness') | awk -F " " '{print $2; exit}')
GAMMA=$(echo $(xrandr --verbose | grep 'Gamma') | awk -F " " '{print $2; exit}')
DNAME=$(xrandr --listmonitors | sed -ne 's/ .* //gp')
MODE=$(echo $(xrandr | grep '*') | awk -F " " '{print $1; exit}')
RATE=$(echo $(xrandr | grep '*') | awk -F " " '{print $2; exit}' | sed 's/\*+//')
ROT=$(xrandr --query --verbose | grep "$DNAME" | cut -d ' ' -f 6)

xrandr --output $DNAME --off
xrandr --output $DNAME --mode $MODE --rotate $ROT
xrandr --output $DNAME --rate $RATE --gamma $GAMMA --brightness $BRIGHT
```

#### Analysis & Reverse Engineering Insight
- The script forces a CRTC power cycle via DRM/X11 (`--off` followed by `--mode $MODE`).
- This confirms that when the screen goes black, the GPU pipe / timing controller may still respond to a full modeset request, but the automatic kernel power transition (`D3hot`/`D3cold` -> `D0`) failed to complete panel power sequence (PPS) timing or re-enable the backlight PWM/eDP/DSI bridge.
- Limitations: Only works in X11 (fails on Wayland, Plymouth, and early console). Cannot wake a kernel that failed S0ix or dropped into unrecoverable pipe freeze.

---

### 2.3 Sleep Target Masking Workarounds
Because suspend resume resulted in an unrecoverable black screen, the prior art disabled all Linux power-saving states:
```bash
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```
Additionally, desktop environment sleep triggers were disabled via GSettings:
```bash
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-battery-timeout 0
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.cinnamon.settings-daemon.plugins.power lid-close-battery-action 'nothing'
gsettings set org.cinnamon.settings-daemon.plugins.power lid-close-ac-action 'nothing'
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-display-ac 0
gsettings set org.cinnamon.settings-daemon.plugins.power sleep-display-battery 0
```
*Impact*: The device can never enter sleep, causing severe battery drain and thermal buildup when closed or idle in a bag.

---

### 2.4 Kernel Boot Parameters & Driver Flags
The community identified several GRUB cmdline options:
```text
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 fbcon=nodefer video=efifb:nobgrt"
```
Recommended DRM options from Bugzilla / community:
- `video=efifb:nobgrt`: Prevents EFI framebuffer from inheriting BGRT (Boot Graphics Resource Table) boot logo bitmap corrupted across non-standard rotation handoffs.
- `fbcon=nodefer`: Forces early framebuffer console binding to prevent race condition during DRM driver handoff.
- `i915.enable_psr=0`: Disables Panel Self Refresh. On Intel GLK UHD 600, PSR state machine transitions often hang the display pipe on resume.
- `i915.enable_fbc=0`: Disables Framebuffer Compression, preventing visual corruption on unaligned portrait panel framebuffers.
- `i915.enable_dpcd_backlight=0`: Forces standard PWM or ACPI backlight control instead of eDP DPCD AUX channel backlight commands.

---

### 2.5 Accelerometer & Sensor Calibration (`BOSC0200`)
The device uses a Bosch accelerometer (`BOSC0200` ACPI ID). On portrait-native panels, sensor coordinates must match display coordinates:
```ini
# /etc/udev/hwdb.d/61-sensor-local.hwdb

# IdeaPad D330-10IGM (both 81H3 and 81MD)
sensor:modalias:acpi:BOSC0200*:dmi:*:svnLENOVO:*:pvrLenovoideapadD330-10IGM:*
 ACCEL_MOUNT_MATRIX=0, 1, 0; -1, 0, 0; 0, 0, 1

# IdeaPad D330-10IGL (82H0)
sensor:modalias:acpi:BOSC0200*:dmi:*:svnLENOVO:*:pvrLenovoideapadD330-10IGL:*
 ACCEL_MOUNT_MATRIX=0, 1, 0; -1, 0, 0; 0, 0, 1
```
Mount matrix orientation:
- Swaps X and Y axes with inverted polarity (`[0, 1, 0; -1, 0, 0; 0, 0, 1]`) to translate physical portrait mounting to logical landscape orientation when the tablet is held normally.

---

### 2.6 ACPI Table Namespace Clashes (`ACPI.md`)
Dmesg analysis revealed severe ACPI namespace evaluation errors:
```text
[    0.283866] ACPI BIOS Error (bug): Failure creating named object [\_SB.PCI0.RP04.PCA4], AE_ALREADY_EXISTS (20190816/dswload2-326)
[    0.283924] ACPI Error: AE_ALREADY_EXISTS, During name lookup/catalog (20190816/psobject-220)
[    0.283939] ACPI BIOS Error (bug): Failure creating named object [\_SB.PCI0.RP04.SLOT], AE_ALREADY_EXISTS (20190816/dswload2-326)
...
[    0.284222] ACPI BIOS Error (bug): Failure creating named object [\_SB.PCI0.RP04._S0W], AE_ALREADY_EXISTS
[    0.284278] ACPI BIOS Error (bug): Failure creating named object [\_SB.PCI0.RP04.PXP], AE_ALREADY_EXISTS
[    0.284308] ACPI BIOS Error (bug): Failure creating named object [\_SB.PCI0.RP04._PR0], AE_ALREADY_EXISTS
[    0.284345] ACPI BIOS Error (bug): Failure creating named object [\_SB.PCI0.RP04._PR3], AE_ALREADY_EXISTS
[    0.284386] ACPI BIOS Error (bug): Failure creating named object [\_SB.PCI0.RP04._S3D], AE_ALREADY_EXISTS
```
#### Analysis
- `\_SB.PCI0.RP04` defines power resources (`_PR0`, `_PR3`) and sleep wake capabilities (`_S0W`, `_S3D`, `_S3W`).
- A secondary SSDT table attempts to redefine objects already instantiated in DSDT, causing ACPICA interpreter failure (`AE_ALREADY_EXISTS`).
- When power resources fail to parse during kernel boot, the Linux PCI and ACPI power management subsystems fail to correctly execute power transitions (`_PS0`, `_PS3`) on PCI root ports and connected endpoints during S3/S0ix suspend and resume.

---

## 3. Upstream Linux Kernel Status (`drm_panel_orientation_quirks.c`)
In upstream Linux (`drivers/gpu/drm/drm_panel_orientation_quirks.c`):
- `D330-10IGM` (`81H3`, `81MD`) has quirks for `lcd1200x1920_rightside_up` and `lcd800x1280_rightside_up`.
- `D330-10IGL` (`82H0`) often lacks explicit matching in older/LTS kernels, or has mismatched DMI strings (e.g. `Lenovo ideapad D330-10IGL` vs `Lenovo ideapad D330-10IGL-82H0`).
- Furthermore, orientation quirks only fix userspace orientation; they do **not** fix the underlying panel power cycle timing (`panel_power_cycle_delay`) or MIPI DSI / eDP reset sequencing after suspend.

## 4. Root Cause Hypotheses for Engineering Phase
1. **Panel Power Cycle Timing Delay (t11_t12)**: The LCD timing controller requires a mandatory minimum power-off delay (typically 500ms) before re-applying VDD. Linux `i915` defaults or VBT values may be too short (e.g. 200ms), causing TCON lockup on fast resume.
2. **Backlight PWM / GPIO Enable Sequencing**: Windows driver (`igdkmd64.sys`) controls backlight enable via GPIO lines or specific PWM sequences before VDD or in strict coordination with panel reset. Linux i915 may sequence backlight enable prior to stable panel link training.
3. **Intel S0ix Modern Standby vs S3**: Lenovo BIOS defaults to Modern Standby (PEP / S0ix). Linux kernel suspend defaults may trigger partial S3 / S0ix mismatch, leaving the display controller rails unpowered upon resume.
