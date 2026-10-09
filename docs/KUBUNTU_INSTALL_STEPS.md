# Kubuntu Install Steps for the Lenovo IdeaPad D330-10IGL

A copy-paste procedure to bring a fresh **Kubuntu 26.04** install on the D330
(`82H0`, `81MD`, `81H3`) to full parity, including the screen latch-up fix,
touch/touchpad under **Wayland**, and the RNNoise mic denoiser.

This is the walkthrough version of `docs/DISTRO_INSTALL_GUIDE.md`; that file
covers the other distros and the ISO-remaster path.

---

## What this gets you

- `patches/d330_display_resume_fix.patch`: the real fix, a 600 ms TCON
  power-sequence clamp in `drivers/gpu/drm/i915/display/intel_pps.c`.
- The standalone DKMS module, modprobe `i915.enable_psr=0 enable_fbc=0`, boot
  orientation, udev/hwdb, libinput quirks, systemd units, TLP/thermal/zram,
  PipeWire DSP and the RNNoise mic denoiser.

What the installer does **not** do: enforce the 600 ms clamp. That requires the
kernel patch. The DKMS module is only a DMI-matched diagnostic banner.

---

## 0. Before you start

- UEFI setup: **disable Secure Boot**. The DKMS module and any rebuilt kernel are
  unsigned and will not load with Secure Boot enforced.
- Keep a live USB around in case the rebuilt kernel will not boot; the stock
  kernel stays in GRUB as a fallback.

## 1. Update and install dependencies

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y dkms build-essential "linux-headers-$(uname -r)" git cmake
sudo apt install -y iio-sensor-proxy v4l2loopback-dkms thermald earlyoom zram-generator \
  librnnoise0 vainfo libglib2.0-bin tlp pipewire libinput-tools python3
```

`cmake` + `git` are for the RNNoise build; the rest satisfy the package's
runtime recommendations.

## 2. Get the repository

```bash
git clone https://github.com/persano/lenovo-d330-linux-fix.git
cd lenovo-d330-linux-fix
```

The released code is tagged `v7.1.0`; the default branch carries the same code
plus documentation. Stay on the default branch to read this file, or
`git checkout v7.1.0` if you pinned the release.

## 3. Run the installer

```bash
sudo ./scripts/install_dkms.sh --install --dry-run   # preview, changes nothing
sudo ./scripts/install_dkms.sh --install --with-rnnoise
```

`--with-rnnoise` builds `librnnoise_ladspa.so` from pinned source
(`werman/noise-suppression-for-voice` v1.21, SHA-256 verified). Drop the flag if
you have no network during install; you can build it later with
`scripts/build_rnnoise_ladspa.sh --install`.

## 4. Apply the display fix and rebuild the kernel

This is the step that actually stops the panel latching dark after suspend.

```bash
# 4a. enable source package repositories (Kubuntu 24.04+ uses the deb822 format)
sudo sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
sudo apt update
sudo apt build-dep -y linux

# 4b. fetch the kernel source for the running kernel
apt source linux-image-unsigned-$(uname -r)
# If that package name 404s, list candidates and pick the matching one:
#   apt-cache search '^linux.*source' ; apt source linux            (or linux-hwe-6.x)
cd linux-*/
```

```bash
# 4c. gate the patch BEFORE applying it
patch -p1 --dry-run < ../lenovo-d330-linux-fix/patches/d330_display_resume_fix.patch
```

- **Clean dry-run:** apply it.
  ```bash
  patch -p1 < ../lenovo-d330-linux-fix/patches/d330_display_resume_fix.patch
  ```
- **Rejects (expected on a very new kernel):** open
  `drivers/gpu/drm/i915/display/intel_pps.c` and adapt the hunk by hand so the
  panel power-cycle path enforces a delay of at least 600 ms, then continue.

```bash
# 4d. build and install
make -j"$(nproc)" bindeb-pkg LOCALVERSION=-d330-fix
sudo dpkg -i ../linux-image-*-d330-fix_*.deb ../linux-headers-*-d330-fix_*.deb
sudo update-grub
```

## 5. Reboot

```bash
sudo reboot
```

Select the `-d330-fix` kernel in the GRUB menu if it is not chosen by default.

## 6. Verify

```bash
dmesg | grep lenovo_d330_fix
sudo ./scripts/test_resume_loop.sh --cycles 5 --sleep 10
sudo ./scripts/test_touch_calibration.sh
scripts/test_mic_rnnoise.sh --probe
```

## 7. Wayland finishing touches

- Confirm the session: `echo $XDG_SESSION_TYPE` should print `wayland`.
- Touch alignment is automatic (udev `LIBINPUT_CALIBRATION_MATRIX`). Palm and
  pressure thresholds come from `/usr/share/libinput/60-lenovo-d330.quirks`,
  which libinput reads on Wayland too.
- Set **tap-to-click, natural scrolling and clickfinger** in System Settings >
  Input Devices. The X11 file `60-lenovo-d330-touchpad-pen.conf` is ignored on
  Wayland; those are compositor preferences.
- Enable the on-screen keyboard in System Settings > Virtual Keyboard.
- Select the denoised microphone:
  ```bash
  wpctl status
  wpctl set-default <id-of-"Lenovo D330 Clean Microphone">
  ```

---

## Notes and troubleshooting

- **Kernel updates:** any `apt upgrade` that replaces the kernel drops the clamp.
  Rebuild the patched kernel or pin the working version. The DKMS module itself
  is rebuilt automatically by DKMS.
- **No touchscreen calibration:** check
  `/usr/share/libinput/60-lenovo-d330.quirks` and
  `/etc/udev/rules.d/90-lenovo-d330-touchscreen.rules` exist, then
  `sudo udevadm control --reload && sudo udevadm trigger`.
- **RNNoise source missing in `wpctl status`:** the plugin is optional
  (`flags = [ nofail ]`). Run `scripts/build_rnnoise_ladspa.sh --install`, then
  `systemctl --user restart pipewire pipewire-pulse`.
- **Screen still dark after resume:** the patched kernel is not the one running.
  Check `uname -r` ends in `-d330-fix`.
- **Uninstall everything:** `sudo ./scripts/install_dkms.sh --uninstall`
  (removes configs, units and the deployed files listed in the manifest).
