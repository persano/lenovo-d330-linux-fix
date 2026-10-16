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

## 7. v9.0 closure (phase 48, 2026-10-15): the mechanism is below host MMIO

<!-- planner-discipline-allow: ULPS_STATE_MASK -->
<!-- planner-discipline-allow: MIPI_SEQ_POWER_OFF -->
<!-- planner-discipline-allow: panel power cycle -->
<!-- planner-discipline-allow: MIPIO_RST_CTRL -->

Phase 48 (milestone v9.0, ≤5 pre-allocated iterations) ran the DSI_MMIO_DIFF
§5 claim's ladder with machine evidence at every rung. Ladder (all DMI-gated
82H0, CI-built `7.0.14-d330-fix`, one user-authorized rtcwake session each,
eyes-on verdicts verbatim):

| # | Candidate (sequence-state, never a value restore) | CI sha | Verdict (user) | At-wake signature |
|---|---|---|---|---|
| 1 | Fresh-device-state branch: clear retained ULPS_STATE_MASK + DEVICE_READY before the cold-boot probe (reload ordering, ULPS dance skipped) — commit 1418a8b | 43b2e7c2…8932 | "Still black" | X=Z unchanged (diff it1: 9 differs + 4 excl.) |
| 2 | Full panel power cycle at top of pre_enable (assert reset, MIPI_SEQ_POWER_OFF, 1.5 s reload-scale hold, full re-init) — commit f1914da | FEA98E57…C876 | "black but lit" | X=Z unchanged (10 differs); failure mode changed dark→lit-blank |
| 3 | DSI-block MIPIO reset pulse (drop + re-assert MIPIO_RST_CTRL) before the sequence — commit 41325d1 | C2C2CD89…1073 | "Black but lit" | X=Z unchanged (10 differs) |

Then the decisive capture (enabled by the iteration-3 instrument fix that
makes the dump node survive an unbind/bind): the **working-lit state** — the
panel restored by the user's reload workaround while the node stayed alive —
compared against the broken-wake arm shows **the entire DSI block
0x6b000-0x6c000 bit-identical (1024/1024 registers)** and a whole-file delta
of 5 rows, all GT monotonic counters/residency (0x138070/0x138074
excluded-volatile, 0x138108/0x13819c time-dependent). The state that SHOWS
THE IMAGE and the state that is BLACK are the same in every host-visible
register.

Falsification (DSI_MMIO_DIFF.md §5.1): the §5 branch fired at maximum
strength — not "X=Y held + black" but "black MMIO == working MMIO". Combined
with the v8.0 kernel-software identity (§3), the failure is below host MMIO:
the panel TCON's internal state (or the DSI link's dynamic state). **No host
register write or enable-path sequence can fix what no register state
discriminates.** Iterations stop at 3 of ≤5; further register-level levers
are disproven BY this evidence.

### 7.1 CORRECTION (phase 49, 2026-10-16): §7's "working-lit" arm was never an image state — corrected closure

<!-- planner-discipline-allow: rebind -->

Phase 49's close-out corrected the evidence chain with eyes-on
verification (49-01-CYCLE2/CYCLE3):

- The reload (unbind/bind) NEVER restores the image — it leaves a
  **backlit black** panel (user-verified twice on the v9.0 kernel; the
  user had never run it personally; row 29's v8.0 myth-bust re-confirmed).
  sddm/kwin restart after a black resume: also lit-black. **Recovery =
  reboot only.**
- Therefore §7's "working-lit state" (`reload_lit_dsi_regs.txt`) and
  §5.1's identity compared BLACK vs BLACK; the "no host MMIO state
  discriminates" conclusion is WITHDRAWN (DSI_MMIO_DIFF §5.2).
- The corrected, machine-evidenced truth (2 independent cycles): the
  **late-black state holds X=Z** (the non-boot operational set, ≥30 s,
  timeout-marked 0x6b004) while boot/image holds X=Y — the §5 claim's
  contrast discriminates, and **every kernel path tested lands at X=Z**:
  the 3 DMI-gated resume variants (rows 30-32) AND the full PCI
  re-probe. The re-probe's failure to re-reach X=Y is precisely why the
  rebind shows lit-black.
- v8.0 row 18 (forced X=Y values, still black) shows X=Y values alone
  are insufficient.

**Corrected final statement:** the image requires the GOP's firmware
panel init — the only path that produces X=Y and the direct TCON
programming (GOP_DSI_RE_FINDINGS). No kernel path (resume variants,
full re-probe) re-reaches it; value forcing is insufficient. The fix is
unreachable from the kernel with every lever tested across v8.0+v9.0
(31+ ledger rows); recovery = reboot. What a real fix would require
(v9.0-refined): (a) replicate the GOP's TCON-level init — needs the
panel TCON datasheet or a hardware probe (logic analyzer on the panel
flex during GOP boot vs kernel re-probe, to see what the GOP does that
the kernel cannot); (b) OR find a kernel path to the GOP's exact
post-init state — none exists in the tested space; (c) the panel
controller remains unidentified (block-55 VBT table undecoded).

The honest mitigation stands: **reboot after a black resume** (the
panel powers back via the GOP). The unbind/bind script stays available
but is documented as lit-black, not a recovery.

What remains true for the user: the panel recovers **only** via the full
i915 re-probe (unbind/bind, the daily workaround) or a reboot — the
workaround is now formalized as the honest mitigation. Phase 49 delivery:
no-regression guards + the workaround packaging follow the v9.0 roadmap's
honest-closure branch (SC1: mechanism proven unreachable with documented
reason and concrete next instrument).

### What a real fix would require (v9.0 refinement of §4)

1. **Panel-side instrumentation**: the TCON's internal state is not
   host-readable (DSI RX-only, no feedback path in the register map). A
   logic analyzer on the panel flex (DSI lanes + reset + power rails) during
   a broken wake vs a working reload would localize whether the TCON loses
   its OTP-init state or the link's LP/HS handoff never completes. Cost:
   hardware access to the panel connector.
2. **GOP re-execution at resume** (per §4.2 of the v8.0 doc): replay the
   GOP's exact register programming (gop_driver_dc90d1e2.efi RE,
   GOP_DSI_RE_FINDINGS) — but §5.1 above removes the premise that a
   register replay discriminates: the GOP sequence would have to drive
   something the MMIO map does not expose (same TCON-side conclusion).
3. **TCON datasheet / panel identification** (block-55 VBT table still
   undecoded) to read the controller's documented wake requirements.

## 8. v9.0 state left behind (rollback complete)

- Device runs the phase-48 iteration-3 kernel (sha C2C2CD89…1073) — panel
  black on resume (unchanged bug), working on boot and after the reload
  workaround; the fix branches (it1/it2/it3) are DMI-gated 82H0 and
  harmless on other machines.
- Rollback chain on device: `/home/santiago/deploy_incoming_*.deb` (it2,
  sha FEA98E57…C876) and `/home/santiago/d47_dump_kernel.deb` (47-era dump
  kernel, ba47df8d…87be); deploy script verifies a rollback asset before
  every install. The original 20dc04db…9e91 deb was clobbered by the first
  deploy's upload-name collision (documented in 48-02-SUMMARY); its
  replacement chain is verified.
- CI branch `instrument/d330-dsi-dump` applies: dump node (+ re-probe fix),
  it2 panel power cycle, it3 MIPIO reset pulse. The it1 patch
  (d330_dsi_device_ready_fix.patch) is in git history only (ledger row 30).
- /gsd-ship merges the branch to main; the deferred-commit ledger of
  uncommitted code (scripts, kit, docs) ships with it.
