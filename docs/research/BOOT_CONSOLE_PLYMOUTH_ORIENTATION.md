# Research: Early Bootloader, Console & Plymouth Orientation on Lenovo D330-10IGL

## 1. The Early Boot Rotation Problem
The Lenovo IdeaPad D330-10IGL uses a tablet panel with native hardware portrait scan direction (800x1280 or 1200x1920).
When the machine powers on:
1. **UEFI GOP / BIOS Logo**: UEFI firmware displays Lenovo logo rotated 90 degrees counter-clockwise (on its side).
2. **GRUB Bootloader**: Renders sideways unless explicitly configured with landscape fonts and GOP modes.
3. **Early Kernel Messages (`fbcon`)**: During the first 3-5 seconds of kernel init before `i915` DRM driver loads, text is written sideways.
4. **Plymouth Boot Splash**: Distorted or sideways unless orientation quirks are embedded in the early initramfs.

## 2. Solution Architecture
1. **GRUB Config (`50-lenovo-d330-boot.cfg`)**:
   - `fbcon=rotate:1`: Rotates Linux console 90 degrees clockwise immediately upon framebuffer initialization.
   - `video=efifb:nobgrt`: Prevents the distorted BGRT UEFI boot logo from persisting onto the screen.
   - Sets optimal GOP mode `1280x800`.
2. **Initramfs Hook (`lenovo-d330-plymouth`)**:
   - Copies udev rules and sensor database into initramfs so Plymouth acquires the panel orientation before rootfs mount.
3. **Emergency Refresh Script (`tools/d330-refresh-screen.sh`)**:
   - If a user encounters an unexpected blank screen due to mode-setting race, invoking this tool or pressing an assigned hotkey cycles Wayland/X11/DRM display pipelines and restores output.
