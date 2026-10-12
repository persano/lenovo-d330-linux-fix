# On-Device Kernel Sweep Evidence (Two-Bootable-Kernel S3 Cycle)

- Phase: 44 (community upstream survey, cheap levers), Task 1
- Date: 2026-10-12 (local UTC-3)
- Device: Lenovo IdeaPad D330-10IGL, DMI product name `82H0`, hostname `santiago-D330`
- Question: does the resume black screen reproduce on both bootable kernels
  (`7.0.14-d330-fix` and `7.0.0-38-generic`), isolating a kernel-axis good/bad pair?

## Method

- Suspend/resume driven remotely over SSH with `rtcwake -m mem -s 30` inside a
  root shell script started detached (`setsid`), so the SSH drop during S3 could
  not kill the capture. Outputs collected from `/tmp/sweep_armA.out` and
  `/tmp/sweep_armB.out` after reconnect.
- Captured per arm: `uname -a`, DMI product name, boot id, `/proc/cmdline`,
  DSI DRM sysfs state before and after, `dmesg` tail, D330-marked kernel lines,
  `journalctl -k` tail.
- Method deviation from the plan: no explicit `systemd-inhibit` session was
  used; the remote script drove the suspend directly and no human input
  occurred during the arms. Recorded here because the plan specified an
  inhibited span.
- Panel verdicts: user was asked to watch the physical panel and report
  immediately after each resume. See "Panel verdict reliability" below.

## Environment facts discovered (needed to reproduce)

- The device has exactly two bootable kernels in `/boot`:
  `vmlinuz-7.0.14-d330-fix` (Oct 10 build, Ubuntu 7.0.0-38.38 base + v7.0.14)
  and `vmlinuz-7.0.0-38-generic` (Sep 4 build, Ubuntu 7.0.0-38.38 base).
  The difference between the two arms is therefore only the applied stable
  queue (v7.0.1..v7.0.14) on top of the same Ubuntu base.
- Kubuntu uses a custom GRUB environment mechanism: `grub.cfg` loads an
  embedded environment block from raw LBA 512-513 of the btrfs root partition
  (`env_block=512+1`), in addition to `/boot/grub/grubenv`. `grub-reboot` with
  submenu entry ids did not produce a working `next_entry` on this device;
  the value written was truncated at the submenu id. Working approach: write
  `next_entry=1>2` (numeric submenu path) directly into both stores.
- The eMMC renumbers between boots (`/dev/mmcblk0p2` on some boots,
  `/dev/mmcblk1p2` on others, no SD card present). Any script touching the
  root partition must resolve `/dev/disk/by-uuid/0f0c0e64-b874-41d2-b6cf-b51bb4e3941b`.
- One-time configuration change, user-approved before the sweep, fully
  reverted after: `/etc/default/grub` `GRUB_DEFAULT="1>0"` -> `saved` for the
  two kernel switches, then back to `"1>0"` with `update-grub` re-run and both
  GRUB env stores cleared to header-only. Stray files created by shell
  redirect bugs during the env edits were removed.

## Arm A: 7.0.14-d330-fix (bad-kernel candidate)

- Suspend 14:48:11, resume 14:48:45 local (S3, deep; RTC wake after ~33 s).
- Boot id: `1dab22b9-162a-4f96-a62f-3c0f8de9d043`.
- Kernel command line (as booted):
  `BOOT_IMAGE=/@/boot/vmlinuz-7.0.14-d330-fix root=UUID=0f0c0e64-b874-41d2-b6cf-b51bb4e3941b ro rootflags=subvol=@ quiet splash fbcon=rotate:1 video=efifb:nobgrt video=DSI-1:panel_orientation=right_side_up video=eDP-1:panel_orientation=right_side_up i915.enable_psr=0 i915.enable_fbc=0 no_timer_check quiet loglevel=3 rd.systemd.show_status=auto resume=UUID=139495fd-8753-43f0-8f15-c8f53818fcf2`
- DSI sysfs before suspend: `card1-DSI-1: status=connected enabled=disabled dpms=Off`
- DSI sysfs after resume: `card1-DSI-1: status=connected enabled=disabled dpms=Off`
- Confound: the panel was already powered off before the suspend (screen had
  timed out; `dpms=Off` pre-suspend). Arm A did not test resume-from-lit-panel.
- Kernel log resume excerpt (clean; no DSI/i915 errors):
  - `ACPI: PM: Waking up from system sleep state S3`
  - `[lenovo_d330_fix][DEBUG] System preparing for sleep. Recorded suspend timestamp.`
  - `[lenovo_d330_fix] System resumed after 2283 ms; TCON timing is not enforced by this module (see Option 2 kernel patch).`
  - `PM: suspend exit`
- Module state: `lenovo_d330_fix` loaded (v1.0.0), matched platform, no errors.

## Arm B: 7.0.0-38-generic (baseline candidate)

- Booted via GRUB one-shot `next_entry=1>2` (numeric path; see environment
  facts). Suspend 15:34:20, resume 15:34:54 local (S3, deep).
- Boot id: `6d78e1b2-d901-402f-a3f2-f55e18acb28e`.
- Kernel command line (as booted):
  `BOOT_IMAGE=/@/boot/vmlinuz-7.0.0-38-generic root=UUID=0f0c0e64-b874-41d2-b6cf-b51bb4e3941b ro rootflags=subvol=@ quiet splash fbcon=rotate:1 video=efifb:nobgrt video=DSI-1:panel_orientation=right_side_up video=eDP-1:panel_orientation=right_side_up i915.enable_psr=0 i915.enable_fbc=0 no_timer_check quiet loglevel=3 rd.systemd.show_status=auto resume=UUID=139495fd-8753-43f0-8f15-c8f53818fcf2`
- DSI sysfs before suspend: `card1-DSI-1: status=connected enabled=enabled dpms=On`
- DSI sysfs after resume: `card1-DSI-1: status=connected enabled=enabled dpms=On`
- Kernel log resume excerpt (clean; no DSI/i915 errors):
  - `ACPI: PM: Waking up from system sleep state S3`
  - `[lenovo_d330_fix][DEBUG] System preparing for sleep. Recorded suspend timestamp.`
  - `[lenovo_d330_fix] System resumed after 3021 ms; TCON timing is not enforced by this module (see Option 2 kernel patch).`
  - `PM: suspend exit`
- Module state: `lenovo_d330_fix` loaded (v1.0.0) on this kernel too, matched
  platform, no errors.

## Panel verdict reliability

- Arm A, answered immediately after the test: "Panel stayed BLACK".
- Arm B, answered immediately after the test: "Panel came back LIT".
- Later the same session the user retracted the distinction ("they both turned
  on fine, the issue is on the resume, both black but lit"), then stated they
  were not looking at the device continuously and could not remember what
  either arm showed.
- A re-test was offered with a precise three-state vocabulary (content visible
  / black glow with backlight / fully dark); the user declined (not watching
  the device).
- Conclusion: the per-arm panel verdicts are UNRELIABLE. A kernel-axis
  good/bad pair is NOT established by this sweep. The two immediate answers
  are recorded as claims, not measurements.

## Conclusion

- Kernel logs are clean on BOTH arms and carry the identical signature: normal
  ACPI S3 wake sequence, `lenovo_d330_fix` resume banner, no DSI/i915
  errors. This matches the known failure signature from the ledger (the
  resume black screen is invisible in kernel logs).
- The sweep did NOT isolate a kernel-axis differentiator between
  `7.0.0-38-generic` and `7.0.14-d330-fix`. The panel-side result is
  unreliable (see above), and the arm A run had the pre-suspend `dpms=Off`
  confound, so even the sysfs delta between arms is not attributable to the
  kernel version.
- Any upstream bug report must therefore describe the failure against
  `7.0.14-d330-fix` with the ledger's established signature (panel black after
  resume, backlight state unmeasured, kernel logs clean, recovery via
  documented reload only), and must NOT claim a kernel-version regression
  pair.
- The automatic resume recovery hook is not installed on this device (0
  `d330-display` entries in `/usr/lib/systemd/system-sleep/`), so all resumes
  during the sweep ran with the stock recovery absent, as planned.
