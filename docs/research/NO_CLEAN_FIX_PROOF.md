# ROOT-04: No clean fix proven — 45-02 iteration closure evidence

<!-- planner-discipline-allow: bl_power -->
<!-- planner-discipline-allow: mem_sleep -->
<!-- planner-discipline-allow: modprobe -r -->
<!-- planner-discipline-allow: disable_all -->
<!-- planner-discipline-allow: commit_duplicated_state -->
<!-- planner-discipline-allow: dsi-reprobe -->
<!-- planner-discipline-allow: rebind -->
<!-- planner-discipline-allow: actual_brightness -->

Phase: 45-02 · Date: 2026-10-13 · Device: Lenovo IdeaPad D330-10IGL (82H0), kernel
7.0.14-d330-fix · Plan: `.planning/phases/45-.../45-02-PLAN.md` (≤5 iterations, then this
document).

Verdict: after 3 deployed, eyes-on-tested candidates plus two cheap recovery-path tests,
**no clean, in-driver fix for the resume black screen was proven**. Suspend/resume on this
device still requires a full reboot to restore the panel. This document is the honest
closure required by the plan (ROOT-04), with all machine and human evidence.

## 1. What was tried and what it showed

| # | Candidate | Delivery | Human verdict (eyes-on) | Machine evidence | Outcome |
|---|-----------|----------|--------------------------|------------------|---------|
| 1 | Deferred full DSI encoder cycle (`QUIRK_DSI_RESUME_FULL_CYCLE`, 82H0 DMI-gated): post-resume `drm_atomic_helper_duplicate_state` → `disable_all` → 2 s → `commit_duplicated_state` (mode_changed) → hotplug | CI run 38334925479 (`fix/d330-dsi-resume-cycle`, kernel `7.0.14-d330-fix`) | **Lit but black** (twice: fresh boot + 2nd resume) | ftrace shows the exact reload-shaped path (`intel_dsi_disable` 35 ms → `post_disable` → `pre_enable`); journal "D330 DSI cycle: encoder re-enabled"; `bl_power=0 brightness=640` | FAILED — the atomic cycle runs but the panel shows no image |
| 2 | Post-resume i915 re-probe (systemd oneshot after `suspend.target`: `modprobe -r lenovo_d330_fix` + rebind; falls back to sysfs unbind/bind) | on-device service `d330-dsi-reprobe.service` | **Fully black / still black** (also manual rebind test) | service ran (`reprobe done rc=0`), module reloaded, but panel dark; dpms/kscreen state stuck Off afterward | FAILED — and **myth-busted**: the module rebind was never a working recovery |
| 3 | s2idle (Modern-Standby mode, matching Windows) resume | `echo s2idle > /sys/power/mem_sleep` + `systemctl suspend` | **Fully black**, then **lit but black** after manual `bl_power=0` | `PM: suspend entry (s2idle)`; post-resume `bl_power=4` (backlight left off); re-enabling backlight shows image-less panel | FAILED — i915 tears the DSI pipeline down in s2idle too |
| — | KScreen DPMS cycle post-resume | `kscreen-doctor dpms off/on` | (state stuck) | dpms stayed `Off` despite rc=0 | FAILED — compositor cannot re-drive the connector |
| — | Fresh compositor modeset post-resume | `systemctl restart sddm` | **Still black** | new KWin instance, pipe B stayed disabled (`enable=no active=no`) | FAILED — even a brand-new session cannot re-enable the pipeline |

All candidates were verified by human eyes on the panel, per the 45-01 lesson that sysfs
state (`dpms=On`, `bl_power=0`) does not imply a visible image.

## 2. Corrected premises (changes to earlier phase conclusions)

- **45-01's "reload restores the panel" was a sysfs mirage.** The T4 differential arms
  concluded panel restoration from `dpms=On / bl_power=0` after the module rebind. Today's
  eyes-on tests show the rebind does NOT restore the visible image, in any state
  (post-resume lit-black, post-rebind, post-fresh-compositor). The only recovery that has
  ever worked, per the user (who confirmed today), is a **full reboot**.
- ROOT-01's mechanical finding still stands: the S3 resume path never re-runs the DSI
  enable path, and the rebind does. What changed: re-running the enable path (by resume,
  by atomic cycle, or by re-probe) does not produce a working panel.

## 3. The decisive experiment: kernel state is identical, panel is dead

`i915_display_info` captured on the same boot pair (files in
`docs/dumps/re_kit/boot_displayinfo.txt` / `broken_displayinfo.txt`, diff in
`displayinfo_diff.txt`):

- Working (fresh boot): pipe B `enable=yes active=yes mode="800x1280" port_clock=80000`,
  planes assigned.
- Broken (after S3 resume): **byte-identical display state** — the diff contains only the
  cursor plane's framebuffer (compositor artifact), nothing in the display pipeline.

Interpretation: the kernel's programmed state is fully consistent with "display working"
in both cases, yet the panel is dark. The failure lives **below the kernel's model**: in
the panel-side TCON/DSI link state that the GOP firmware sets at boot and the kernel
cannot reproduce at resume. This matches the module's boot-time note ("TCON timing is not
enforced by this module") and the two-VBT finding in GOP_DSI_RE_FINDINGS (the GOP runs its
own block-53 sequence timing at boot; the kernel replays the sequences but the result is
still an imageless panel).

## 4. What a real fix would require (future work)

1. **DSI MMIO-level diff** between boot (working) and resume (broken) — the DSI/DPHY
   transcoder registers are not covered by `i915_display_info` on this kernel (no
   `i915_dsi_info` debugfs node in 7.0.14); needs either a debugfs patch or a devcoredump
   capture.
2. **Replicate the GOP's full panel init** (SPI dump `gop_driver_dc90d1e2.efi` RE, per
   GOP_DSI_RE_FINDINGS) in the kernel resume path — including the GOP's direct TCON
   register programming that goes beyond the VBT sequences.
3. **Panel-side research**: identify the exact panel controller (currently unknown; the
   block-55 VBT table is undecoded) and its documented wake requirements.

## 5. State left behind (rollback complete)

- Device: known-good `7.0.14-d330-fix` redeployed and verified (no D330 DSI cycle strings
  in i915.ko, no quirk in boot log, panel On). The known-good .deb is retained at
  `C:\Users\Familia\AppData\Local\Temp\opencode\rollback\` (sha256
  `20dc04db…9e91`) and on the device at `/home/santiago/`.
- CI workflow reverted to applying only `patches/d330_display_resume_fix.patch` (CCS fix);
  `patches/d330_dsi_resume_cycle.patch` stays in the repo as a documented failed candidate.
- The on-device `d330-dsi-reprobe.service` and script were removed (they made the panel
  worse: fully black).
- `mem_sleep` default untouched (deep; s2idle test was non-persistent).

## 6. Honest ledger outcome rows (added to RESUME_FIX_LEDGER.md)

- Candidate (c) deferred atomic full cycle: **DISPROVEN** (eyes-on: lit-black).
- Candidate rebind/re-probe post-resume: **DISPROVEN + premise myth-busted** (rebind was
  never a visual recovery; only reboot is).
- s2idle mode switch: **DISPROVEN** (i915 tears down in s2idle; backlight left off).
- New disproven lever: "sysfs dpms/bl_power state == visible image" (never trust sysfs;
  eyes-on or bust).
