# Kubuntu Install Steps for the Lenovo IdeaPad D330-10IGL

> **v11.0 shortcut:** `sudo ./scripts/d330-full-setup.sh` now automates this
> whole guide (deps → parity stack → patched kernel → verification), with
> `--dry-run`, backups before every boot-file touch, and a printed manual
> fallback per step. The steps below remain the manual path and the
> reference for what the script does.

A copy-paste procedure to bring a fresh **Kubuntu 26.04** install on the D330
(`82H0`, `81MD`, `81H3`) to full parity, including the screen-resume fix,
touch/touchpad under **Wayland**, and the RNNoise mic denoiser.

This is the walkthrough version of `docs/DISTRO_INSTALL_GUIDE.md`; that file
covers the other distros and the ISO-remaster path.

---

## What this gets you

- `patches/d330_display_resume_fix.patch`: the real fix, a DMI-gated (`82H0`)
  stop of render-compressed (CCS) modifier advertisement in
  `drivers/gpu/drm/i915/display/skl_universal_plane.c`, so a rotated 90/270
  scanout falls back to a Y-tiled surface and the resume commit succeeds.
- The standalone DKMS module, modprobe `i915.enable_psr=0 enable_fbc=0`, boot
  orientation, udev/hwdb, libinput quirks, systemd units, TLP/thermal/zram,
  PipeWire DSP and the RNNoise mic denoiser.

What the installer does **not** do: apply the kernel patch. That has to be in
your booted kernel (Option A or B below). The DKMS module is only a DMI-matched
diagnostic banner.

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
sudo apt install -y iio-sensor-proxy v4l2loopback-dkms thermald earlyoom systemd-zram-generator \
  vainfo libglib2.0-bin tlp pipewire libinput-tools python3
```

`cmake` + `git` are for the RNNoise build; the rest satisfy the package's
runtime recommendations. On Ubuntu/Debian the zram package is
`systemd-zram-generator` (not `zram-generator`); there is no `librnnoise0` — the
denoiser plugin is built from source in step 3.

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

## 4. Apply the display fix

The fix stops i915 advertising CCS on `82H0` in
`drivers/gpu/drm/i915/display/skl_universal_plane.c`. Pick one option.

### Option A (recommended on the tablet): download the prebuilt kernel

The D330 takes hours to compile a kernel. Build it once in GitHub Actions and
install the resulting `.deb`. First note your values:

```bash
uname -r          # your kernel version, e.g. 7.0.0-38-generic
lsb_release -cs   # your Ubuntu codename, e.g. questing
```

1. On GitHub open **Actions** → **Build Patched Kernel (.deb)** → **Run
   workflow**, and enter those two values.
2. When the run finishes (~40 min), open the release tagged
   `kernel-<your uname -r>` and download `linux-image-*-d330-fix_*.deb` and
   `linux-headers-*-d330-fix_*.deb` (also stored as the `kernel-deb` artifact).
3. Install and update GRUB:
   ```bash
   sudo apt install -y ./linux-image-*-d330-fix_*.deb ./linux-headers-*-d330-fix_*.deb
   sudo update-grub
   ```
4. The kernel is unsigned, so the Secure Boot caveat in step 0 applies. The
   version is tied to that exact `uname -r`; after a kernel update, re-run the
   workflow. Continue at **step 5**.

### Option B: build the kernel on the machine

This puts the fix directly in the booted kernel. Run it from a scratch
directory and use absolute paths: `apt source` extracts the kernel tree next to
wherever you are, so a relative `../lenovo-d330-linux-fix/...` patch path
normally points at nothing and `patch` fails to find the file.

```bash
# Set these two paths for your machine.
REPO="$HOME/lenovo-d330-linux-fix"   # where you cloned this repository
WORK="$HOME/d330-kernel"             # scratch dir for the kernel source
mkdir -p "$WORK" && cd "$WORK"
```

```bash
# 4a. enable source package repositories, then refresh
sudo sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
sudo apt update
```

```bash
# 4a2. install the kernel build toolchain. Kubuntu ships none of it by
# default, and the `apt build-dep` in 4b below does not always succeed; run
# this first so the build works either way.
sudo apt install -y build-essential dpkg-dev debhelper fakeroot dh-python \
    libssl-dev libdw-dev bc flex bison rsync libelf-dev dwarves cpio zstd
```

```bash
# 4b. fetch the UNSIGNED kernel source. The running kernel image is often the
# signed wrapper (Source: linux-signed-*), whose source tree has no drivers/;
# the real kernel source package sits behind linux-image-unsigned-*, or is
# 'linux' itself.
SRC_PKG="$(dpkg-query -W -f='${Source}' "linux-image-unsigned-$(uname -r)" 2>/dev/null | awk '{print $1}')"
case "$SRC_PKG" in ""|*signed*) SRC_PKG=linux ;; esac
echo "kernel source package: $SRC_PKG"
sudo apt build-dep -y "$SRC_PKG"
apt source "$SRC_PKG"
SRC_DIR="$(ls -d "${SRC_PKG}"-*/ 2>/dev/null | head -1)"
[ -n "$SRC_DIR" ] || echo ">>> no ${SRC_PKG}-* source dir; check the apt source output above"
cd "$SRC_DIR"
```

```bash
# 4c. gate the patch, apply it, then PROVE it landed before you build
PATCH="$REPO/patches/d330_display_resume_fix.patch"
patch -p1 --dry-run --batch < "$PATCH" || echo ">>> DO NOT BUILD: patch does not apply cleanly; see below"

patch -p1 --batch < "$PATCH"

# Both greps must print a hit. If they do not, the kernel will NOT contain the
# fix even though it is still named -d330-fix.
grep -n 'Lenovo IdeaPad D330-10IGL' drivers/gpu/drm/i915/display/skl_universal_plane.c
grep -n '82H0' drivers/gpu/drm/i915/display/skl_universal_plane.c
```

- **Dry-run fails (context mismatch on a very new kernel):** do **not** build.
  `patch` leaves the rejected hunks in a `.rej` file next to the target. Open
  `drivers/gpu/drm/i915/display/skl_universal_plane.c`, add
  `#include <linux/dmi.h>` if it is missing, and at the top of
  `skl_plane_format_mod_supported()` add the early return
  `if (dmi_match(DMI_PRODUCT_NAME, "82H0") && intel_fb_is_ccs_modifier(modifier)) return false;`
  (kernels before ~6.0 call the helper `is_ccs_modifier()`). Then re-run the two
  greps above.
- **`cd: too many arguments` (step 4b):** the `${SRC_PKG}-*` glob matched more
  than one extracted tree. Run `ls -d */` in `$WORK` and `cd` into the freshly
  extracted `${SRC_PKG}-*` directory by name.
- **`include/config/auto.conf.cmd: No such file or directory` / Makefile
  `Error 1`/`Error 2` (step 4d):** the tree has no `.config`. Run
  `cp "/boot/config-$(uname -r)" .config && make olddefconfig` before
  `make bindeb-pkg`.
- **`security/apparmor/Kconfig:... warning: multi-line strings not supported`
  during `make olddefconfig`:** benign Kconfig parser warning from Ubuntu's
  AppArmor patch. It is not fatal; ignore it and continue the build.

```bash
# 4d. seed .config from the running kernel, then build and install.
# bindeb-pkg needs a CONFIGURED tree; without .config it dies with
# "include/config/auto.conf.cmd: No such file or directory" (Makefile Error 1/2).
cp "/boot/config-$(uname -r)" .config
make olddefconfig
make -j"$(nproc)" bindeb-pkg LOCALVERSION=-d330-fix
ls -lh ../linux-image-*-d330-fix_*.deb ../linux-headers-*-d330-fix_*.deb
sudo dpkg -i ../linux-image-*-d330-fix_*.deb ../linux-headers-*-d330-fix_*.deb
sudo update-grub
```

The build toolchain is installed in step 4a2, so `apt build-dep` failing in
step 4b is not fatal. If a package is still reported missing, re-run the 4a2
`apt install` line.

## 5. Reboot

```bash
sudo reboot
```

Select the `-d330-fix` kernel in the GRUB menu if it is not chosen by default.

## 6. Verify

The installer runs under `set -euo pipefail` and stops at the first fatal step,
so confirm it reached its final step and returned to the prompt before checking
the pieces below.

**Installer completed / DKMS module built:**
```bash
dkms status -m lenovo-d330-fix -v 1.0.0
# expect: lenovo-d330-fix/1.0.0, <kernel>, x86_64: installed
```

**Display fix (the important one):** the CCS fix is silent at runtime, so it
does not show up in `dmesg`. A rebuilt kernel named `-d330-fix` is not proof it
is in; the check is that step 4c's source greps hit and that the failing commit
is gone.
```bash
uname -r                                             # must end in -d330-fix
cat /sys/class/dmi/id/product_name                   # the patch matches "82H0"
dmesg | grep -iE 'RC support only|skl_plane_check'   # expect NO output
dmesg | grep lenovo_d330_fix                         # DKMS banner module (Option 1)
sudo ./scripts/test_resume_loop.sh --cycles 5 --sleep 10
```
Before the fix the atomic commit fails and `dmesg` (with `drm.debug` on) shows
`RC support only with 0/180 degree rotation`; after the fix that line is gone.
If it is still there, the kernel booted without the patch: go back to step 4 and
make sure the two greps printed hits before the build.

**Touchscreen / touchpad:**
```bash
sudo ./scripts/test_touch_calibration.sh
```

**RNNoise denoiser:**
```bash
scripts/test_mic_rnnoise.sh --probe
# expect: [OK] Found plugin: /usr/lib/ladspa/librnnoise_ladspa.so
wpctl status | grep -i "Lenovo D330 Clean"
```

## 7. Wayland finishing touches

- Confirm the session: `echo $XDG_SESSION_TYPE` should print `wayland`.
- Touch needs no calibration matrix on Wayland: the compositor already rotates
  absolute input from the panel orientation (`panel_orientation=...` in the boot
  cmdline), so the shipped `LIBINPUT_CALIBRATION_MATRIX` is the identity ("no
  extra transform"). Palm and pressure thresholds come from
  `/usr/share/libinput/60-lenovo-d330.quirks`, which libinput reads on Wayland
  too.
- Set **tap-to-click, natural scrolling and clickfinger** in System Settings >
  Input Devices. The X11 file `60-lenovo-d330-touchpad-pen.conf` is ignored on
  Wayland; those are compositor preferences.
- Enable the on-screen keyboard in System Settings > Virtual Keyboard.
- Select the denoised microphone:
  ```bash
  wpctl status
   wpctl set-default <id-of-"Lenovo D330 Clean Microphone">
   ```

## 8. Diagnose the screen fix over SSH

If the panel comes back dark after suspend/resume you cannot read the logs on the
tablet itself, so capture them from another machine over SSH. Run this on the
tablet **before** the screen test:

```bash
sudo apt install -y openssh-server
sudo systemctl enable --now ssh
mkdir -p ~/.ssh && chmod 700 ~/.ssh
curl -fsSL https://gist.github.com/persano/40255d28213dc5d6f720056c28631c4a/raw >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
ip -4 -o addr show scope global | awk '{print $2, $4}'   # note the LAN IP
```

The `curl` line authorizes a single diagnostic public key (`d330-diag`); its
private key is held by the machine doing the debugging. Remove that line from
`~/.ssh/authorized_keys` when you are done.

From the debugging machine, after a failed resume:

```bash
ssh <user>@<tablet-ip> 'uname -r; \
  sudo dmesg | grep -iE "RC support only|skl_plane_check"; \
  sudo dmesg -T | tail -300; \
  grep -H . /sys/class/drm/*/status; \
  for b in /sys/class/backlight/*; do echo "$b=$(cat $b/brightness)/$(cat $b/max_brightness)"; done'
```

To suspend the tablet and read the resume log while the panel is still dark:

```bash
ssh <user>@<tablet-ip> 'sudo systemctl suspend'      # wake with the power button
ssh <user>@<tablet-ip> 'sudo journalctl -b -k --no-pager | tail -400'
```

## 9. Recover a dark screen without rebooting

If the panel still comes back blank after a resume, the reliable recovery is a
full i915 re-init: a PCI unbind/bind of the GPU, which re-runs the panel init.

```bash
sudo ./scripts/d330-display-reload.sh
```

It is inherently dirty: the running Wayland session cannot survive the GPU
teardown (its DRM fd dies with the device), so the display manager restarts and
you log back in. That is the trade for recovering without a reboot.

The lighter `/usr/local/bin/d330-refresh-screen` only re-drives an already-live
display server (`kscreen-doctor` on KDE/KWin Wayland, `wlr-randr`, `xrandr`).
It cannot revive a panel the kernel failed to bring up, so it usually does
nothing for this failure; it is kept for the community X11 freeze case it was
written for.

Keep the deployed copies current:

```bash
cd ~/lenovo-d330-linux-fix && git pull --ff-only
sudo cp tools/d330-refresh-screen.sh /usr/local/bin/d330-refresh-screen
sudo chmod +x /usr/local/bin/d330-refresh-screen
sudo apt install -y kscreen     # provides kscreen-doctor on KDE Wayland
```

Run it and read the result (the same lines are appended to
`$XDG_RUNTIME_DIR/d330-refresh-screen.log`):

```bash
/usr/local/bin/d330-refresh-screen --hold
```

Bind it to a key: System Settings > Keyboard > Shortcuts > Add Command, with
`/usr/local/bin/d330-refresh-screen --hold`. It only re-drives a live display
server; it cannot revive a pipe the kernel failed to power on.

---

## Notes and troubleshooting

- **Kernel updates:** any `apt upgrade` that replaces the kernel drops the fix.
  Rebuild the patched kernel or pin the working version. The DKMS module itself
  is rebuilt automatically by DKMS.
- **Installer stopped at `dkms build` (e.g. "BUILD_EXCLUSIVE ... does not match
  this kernel/arch/config"):** the DKMS module refuses the running kernel. Update
  the repo (`git pull --ff-only`) first; the supported range is 5.15-9.x. Then
  re-run the installer and check `dkms status -m lenovo-d330-fix -v 1.0.0`.
- **DKMS module failed to compile on a very new kernel:** inspect
  `/var/lib/dkms/lenovo-d330-fix/1.0.0/build/make.log`. The module is a
  DMI-matched diagnostic banner; the real fix is the kernel patch, so this does
  not block the display fix.
- **Touch is inverted (180 deg) or rotated on Wayland:** a calibration matrix is
  being applied *and* the compositor is rotating input from `panel_orientation`,
  so touch is turned twice. The shipped matrix is the identity for exactly this
  reason. Check `udevadm info /dev/input/event* | grep -i LIBINPUT_CALIBRATION`
  and confirm it reads `1 0 0 0 1 0`; if an old `0 1 0 -1 0 1` is still there,
  remove it and run `sudo udevadm control --reload && sudo udevadm trigger`, then
  rebind the touchscreen (`i2c` unbind/bind, or the sleep hook). Add a rotation
  matrix only if your compositor does not rotate input; X11 keeps its
  `TransformationMatrix` in `50-touchscreen-d330.conf`.
- **No touchscreen calibration:** check
  `/usr/share/libinput/60-lenovo-d330.quirks` and
  `/etc/udev/rules.d/90-lenovo-d330-touchscreen.rules` exist, then
  `sudo udevadm control --reload && sudo udevadm trigger`.
- **RNNoise source missing in `wpctl status`:** the plugin is optional
  (`flags = [ nofail ]`). Run `scripts/build_rnnoise_ladspa.sh --install`, then
  `systemctl --user restart pipewire pipewire-pulse`.
- **`d330-swapfile.service` warning:** hibernation resume needs a swap file on
  **ext4**. On a btrfs, xfs or zfs root the unit logs a `[WARN]` and skips
  cleanly (it no longer fails), so `systemctl --failed` stays empty. Suspend
  (S2idle) still works, so this only matters if you want hibernation. On ext4,
  a free-space or `swapon` failure still fails the unit. Inspect it with
  `journalctl -u d330-swapfile.service -b`.
- **`libkmod: ... ignoring bad line starting with 'options'`:** caused by bare
  no-parameter `options <module>` lines in the shipped camera and cellular
  `modprobe.d` files, fixed in current `main`. `git pull --ff-only`, re-run the
  installer, then `sudo systemctl restart systemd-modules-load`. Find any other
  offender with `grep -rnE '^options[[:space:]]+[^[:space:]]+$' /etc/modprobe.d`.
- **`could not get modinfo from tls: exec format error`:** not from this repo.
  The running kernel and `/lib/modules` are out of sync, usually because a
  kernel package was upgraded but not rebooted. Compare `uname -r` with
  `ls /lib/modules` and reboot; if it persists,
  `sudo apt install --reinstall "linux-modules-$(uname -r)"`.
- **Screen still dark after resume, even though `uname -r` ends in `-d330-fix`:**
  either the patch is not in the booted kernel, or you hit the still-open DSI
  panel issue. A rebuild is named `-d330-fix` whether or not the diff applied,
  so confirm step 4c's two greps printed hits before the build, and that
  `/sys/class/dmi/id/product_name` is `82H0` (the patch is gated on it). The CCS
  fix is silent in `dmesg`; see `docs/research/DISPLAY_RESUME_CCS_MODIFIER.md`.
- **Recover a screen that came back dark:** run
  `sudo ./scripts/d330-display-reload.sh`; see section 9. It does a full i915
  re-init and the session restarts. `d330-refresh-screen` only re-drives a live
  display server and does not fix this.
- **Uninstall everything:** `sudo ./scripts/install_dkms.sh --uninstall`
  (removes configs, units and the deployed files listed in the manifest).
