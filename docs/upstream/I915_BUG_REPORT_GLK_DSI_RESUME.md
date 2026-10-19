# drm/i915 GLK DSI: panel stays black after S3 resume on Lenovo IdeaPad D330-10IGL (82H0)

> **FILED as https://gitlab.freedesktop.org/drm/i915/kernel/-/work_items/17401**
> (2026-10-18, with triage note + evidence comment and 4 privacy-scanned
> attachments). The fix turned out to already exist upstream: issue #13225
> (open) carries the GLK reset-order fixup patch, validated on this second
> unit 10/10 eyes-on (2026-10-19, ledger row 34; shipped in release v11.0).
> #17401 is a likely duplicate of #13225 once the fixup lands. This file is
> kept as the record of the original report text.

Original paste-and-submit text below. (Historical note: it referenced issue
6619 as a possible match; 6619 turned out to be a different bug class and was
closed by its author's own efifb DMI quirk.)

## Subject

Gemini Lake Refresh (GLK-R) MIPI-DSI panel does not come back after S3
resume — kernel logs are clean, only a full i915 PCI re-init recovers the
panel.

## Hardware

- Lenovo IdeaPad D330-10IGL (machine type 82H0)
- CPU: Celeron N4020 (Gemini Lake Refresh)
- GPU: Intel UHD Graphics 600 (GLK-R), MIPI-DSI internal panel (portrait
  800x1280, `video=DSI-1:panel_orientation=right_side_up` in cmdline)
- Firmware: stock Lenovo (DMI product name `82H0`)

## Kernel

- Primary test kernel: `7.0.14-d330-fix` — Ubuntu 7.0.0-38.38-generic base
  with v7.0.14 applied (built 2026-10-10).
  `Linux version 7.0.14-d330-fix ... (Ubuntu 7.0.0-38.38-generic 7.0.14)`
- Also booted for comparison: `7.0.0-38-generic` (same Ubuntu base without
  the stable queue). Kernel-side resume logs carry the identical clean
  signature on both.
- Failure observed across multiple prior sessions on this machine family of
  kernels; boot is always fine, the failure is specific to resume.

## Reproducer

```
# as root; no lid interaction, S3 (deep) sleep
rtcwake -m mem -s 30
# wait ~35 s; the machine resumes over RTC
```

Expected: after resume the internal DSI panel stays black. The machine is
fully alive: SSH keeps working, the desktop session keeps running, Wi-Fi/BT/
USB re-initialize normally. Only the panel is gone.

The only recovery that has ever worked on this device is a full i915
re-init:

```
echo 0000:00:02.0 > /sys/bus/pci/drivers/i915/unbind
sleep 2
echo 0000:00:02.0 > /sys/bus/pci/drivers/i915/bind
```

`modprobe -r i915` cannot unload (module in use); a bare PCI reset
(`/sys/bus/pci/devices/0000:00:02.0/reset`) powers the panel off completely
and does not recover; `remove` + `rescan` does not recover and hung the box
once.

## Command line

```
BOOT_IMAGE=/@/boot/vmlinuz-7.0.14-d330-fix root=UUID=0f0c0e64-b874-41d2-b6cf-b51bb4e3941b ro rootflags=subvol=@ quiet splash fbcon=rotate:1 video=efifb:nobgrt video=DSI-1:panel_orientation=right_side_up video=eDP-1:panel_orientation=right_side_up i915.enable_psr=0 i915.enable_fbc=0 no_timer_check quiet loglevel=3 rd.systemd.show_status=auto resume=UUID=139495fd-8753-43f0-8f15-c8f53818fcf2
```

PSR and FBC are already disabled (`i915.enable_psr=0 i915.enable_fbc=0`),
so this is not the PSR/FBC pipe-hang class.

## Observed evidence (from the on-device sweep, 2026-10-12)

Suspend at 14:48:11, resume 14:48:45 local, S3 deep. Full resume sequence in
`journalctl -k` is textbook-clean:

```
kernel: PM: suspend entry (deep)
kernel: ACPI: PM: Preparing to enter system sleep state S3
kernel: ACPI: PM: Waking up from system sleep state S3
kernel: intel-hid INT33D5:00: unknown event 0xca
kernel: ACPI: EC: interrupt unblocked
kernel: iwlwifi 0000:02:00.0: RF_KILL bit toggled to enable radio.
kernel: usb 1-7: reset full-speed USB device number 5 using xhci_hcd
kernel: Restarting tasks: Done
kernel: [lenovo_d330_fix] System resumed after 2283 ms; TCON timing is not enforced by this module (see Option 2 kernel patch).
kernel: PM: suspend exit
```

- No DSI or i915 error/warning lines at resume. The failure is invisible in
  kernel logs.
- DSI connector sysfs around the cycle:
  - `card1-DSI-1: status=connected enabled=disabled dpms=Off` (before suspend;
    panel had already timed off, and it stays that way after resume)
  - A second cycle from a lit panel on the stock base kernel showed
    `status=connected enabled=enabled dpms=On` preserved across resume in
    sysfs, with the panel still not coming back per the operator.
- One out-of-tree banner module (`lenovo_d330_fix`, DMI-matched platform
  notice, taints the kernel) is installed; it only logs and does not touch
  DSI/TCON state — noted here so the taint is not a surprise.

## What we ruled out

- `615c8ec48621f5c157fef3633d6e4be81d7a370f` ("drm/i915/dsi: Don't set/read
  the DSI C clock divider on GLK"): present in both kernels (first in v6.18;
  device tree has `has_dsic_clock` at `vlv_dsi_pll.c:266`) and it is a
  fastset cleanup, not a resume fix.
- PSR/FBC: already disabled on the command line.
- Community masks (`systemctl mask sleep.target ...`) and X11 refresh hacks
  are workarounds for the same symptom seen on other D330s; they avoid the
  suspend entirely and do not fix resume.

## Ask

- Guidance on which GLK DSI resume path to instrument first
  (VBT GPIO rail toggle vs PPS timing vs DPHY re-init), or a known-good
  commit to compare against.
- Happy to bisect the stable range, capture with `no_console_suspend=1`,
  or run a specific debug patch; the device is reachable over SSH and the
  reproducer is a 35-second cycle.

## Context

The same symptom class was acknowledged upstream as still unaddressed in
Aug 2026 ("TTY switching and suspend/resume can also leave the internal
panel blank... not addressed by this patch", intel-gfx, Jinman Ma, DSI
command-mode patch v2). This report adds a GLK-R tablet data point with a
one-command reproducer.
