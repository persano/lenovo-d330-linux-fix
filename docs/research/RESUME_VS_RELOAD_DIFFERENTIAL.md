<!-- planner-discipline-allow: intel_pps.c -->
<!-- planner-discipline-allow: i915.enable_psr=0 -->
<!-- planner-discipline-allow: i915.enable_fbc=0 -->
<!-- planner-discipline-allow: bl_power -->
<!-- planner-discipline-allow: intel_dsi_post_disable -->

# Resume vs Reload Differential (ROOT-01 answer)

Status: phase 45, task 45-01-T4. Date 2026-10-12 (local UTC-3). Kernel `7.0.14-d330-fix`,
device `santiago-D330` (82H0). Raw artifacts in `docs/dumps/re_kit/` (checksummed):
`diff_armR_*` (S3 resume-black arm), `diff_armL_*` (first unbind/bind arm),
`diff_armL2_trace_*.txt` (repeat arm with 4 KB ftrace buffer), `diff42.out`, `diffL2.out`.

## Question

ROOT-01: what does the working recovery (full i915 unbind/bind reload) do that the failing
S3 resume does not do for the DSI panel?

## Method

Same as phase 44 (detached root script + `rtcwake -m mem -s 35`, outputs under /tmp,
collected over SSH). ftrace `function_graph` on 150 filtered functions:
`intel_pps_* intel_dsi_* vlv_dsi_* intel_backlight_* mipi_dsi_*` (from
`/sys/kernel/tracing/set_ftrace_filter`). Arms run in one detached script:

- **Arm R**: sysfs snapshot → trace on → `rtcwake -m mem -s 35` → trace off → copy trace +
  sysfs + dmesg.
- **Arm L / L2**: fresh trace → `unbind 0000:00:02.0` → 3 s → `bind` → trace off → copy +
  sysfs + dmesg. (L2 adds a 4 KB buffer and a mid-arm copy; earlier arm L used the default
  buffer and produced a shorter trace.)

Limitations recorded honestly: (1) `trace_marker` writes failed with I/O error at bind time
in L2, so the bind position inside the trace is not marked; (2) probe-side encoder-enable
function entries (`vlv_dsi_init`, `intel_dsi_pre_enable`, `intel_pps_on`,
`intel_backlight_register`) did not appear in any reload trace even though the probe
completed (dmesg: `Initialized i915 ... fb0` within the traced window) and the panel lit.
The disable-path and sequence-exec entries did appear, and the panel outcome is proven by
sysfs+dmesg, so the differential conclusion below does not depend on the missing entries.

## Arm R (S3 resume) — measured

Trace (`diff_armR_trace.txt`, 801 B, complete file):

```
0)  6.697 us    |  intel_pps_vdd_off_sync [i915]();
1)  5.424 us    |  intel_pps_unlock_regs_wa [i915]();
1)  5.349 us    |  intel_pps_unlock_regs_wa [i915]();
1)  1.587 us    |  intel_pps_encoder_reset [i915]();
1)  3.650 us    |  intel_dsi_get_hw_state [i915]();
1)  2.046 us    |  intel_dsi_get_hw_state [i915]();
1)  1.648 us    |  intel_pps_vdd_on [i915]();
1)  2.011 us    |  intel_pps_vdd_off [i915]();
```

Absent on resume: `intel_dsi_pre_enable`, `intel_dsi_post_disable`, `intel_dsi_disable`,
`intel_dsi_vbt_exec_sequence`, `mipi_dsi_dcs_write_buffer`, `intel_backlight_*` — i.e. the
entire DSI encoder enable path.

Sysfs post-resume (`diff42.out`): `intel_backlight/brightness = 640`,
`max_brightness = 640`, `bl_power = 4` (FB_BLANK_POWERDOWN), DSI-1
`enabled = disabled`, `status = connected`, `dpms = Off`.

dmesg: clean resume, `lenovo_d330_fix` logged "System resumed after 1957 ms; TCON timing is
not enforced by this module (see Option 2 kernel patch)" (`diff_armR_dmesg.txt`).

## Arm L/L2 (unbind/bind reload) — measured

Teardown trace (`diff_armL2_trace_4s.txt`):

```
0)  /* L2 UNBIND */        (trace_marker)
0)  intel_dsi_disable [i915]() { ... # 1071.122 us | intel_dsi_vbt_exec_sequence
0)    intel_backlight_disable ... intel_backlight_set_pwm_level
0)  * 24540.68 us |  }    (intel_dsi_disable total)
0)  intel_dsi_post_disable [i915]() {
0)    intel_dsi_vbt_exec_sequence { mipi_dsi_dcs_write_buffer ... @ 300267.4 us |  }
0)    intel_dsi_vbt_exec_sequence @ 101116.0 us
0)    intel_dsi_vbt_exec_sequence @ 100082.9 us
0)  @ 557091.5 us |  }
0)  intel_dsi_get_hw_state x2
... kwin worker re-enumerates connectors (get_modes / mode_valid ...)
1)  intel_backlight_device_unregister x3, intel_pps_vdd_off_sync,
1)  intel_pps_wait_power_cycle, intel_backlight_destroy x3
```

The teardown path executes VBT block-53 sequences with real DCS writes over
`intel_dsi_host_transfer` (DISPLAY_OFF = DCS `0x28` → 200 ms → `0x10` → 100 ms ≈ 300 ms,
POWER_OFF ≈ 100 ms — matches `docs/research/GOP_DSI_RE_FINDINGS.md` §2 sequence table).

Outcome (`diff42.out` post-L): panel restored — `enabled = enabled`, `dpms = On`,
`bl_power = 0`; dmesg full re-probe (`Initialized i915 1.6.0`, fbcon back). The reload
re-runs the complete DSI enable path including the block-53 GPIO/DCS sequences
(POWER_ON GPIO 144, INIT_OTP GPIO 160 toggle, DISPLAY_ON DCS `0x11`→200 ms→`0x29`,
BACKLIGHT_ON GPIO 145).

Also recorded: the unbind path emitted a kernel WARN in `drm_framebuffer_cleanup`
(pre-existing teardown quirk, non-fatal — bind succeeded right after).

## Answer (ROOT-01)

The failing S3 resume does **no DSI work at all** beyond PP bookkeeping: the connector was
disabled before suspend (`dpms Off`, idle screen-off) and after resume nothing re-atomic-
enables it — no `intel_dsi_pre_enable`, no block-53 sequences, no backlight on. The panel
stays down (`enabled=disabled`, `bl_power=4`) while the system resumes cleanly (logs clean,
module resume hook runs, network/USB/BT all fine). The unbind/bind reload works because it
re-runs the full driver probe: VBT parse, DSI link bring-up, block-53 sequences (GPIO rails
+ DCS `0x11`/`0x29`), backlight — the exact path Windows re-runs on every resume
(`INTMIPIENCODER_SetEncoderPowerState` stack, GOP_DSI_RE_FINDINGS §4).

Implication for 45-02: the fix is to make the resume path re-enable the DSI encoder (a full
modeset/re-probe of the connector), not to tune PP delays. The block-53 sequence table in
GOP_DSI_RE_FINDINGS §2 is the reference for what a correct enable replays.

<!-- planner-discipline-allow: mem_sleep -->
<!-- planner-discipline-allow: dsi-reprobe -->
<!-- planner-discipline-allow: rebind -->

## Phase 45-02: pre-iteration diagnostic (screen-ON suspend shape) and fix design

Re-run after a clean reboot (2026-10-12 21:26, kernel 7.0.14-d330-fix, KWin active,
dpms On pre-suspend). Artifacts: `docs/dumps/re_kit/diag43.out`, `diag_B_resume_trace.txt`,
`diag44.out`, `diag44_trace.txt`, `diag44_dmesg.txt`.

- With the screen ON pre-suspend, the S3 path runs the **complete VBT cycle** — traced:
  suspend side `intel_dsi_disable` (backlight-off seq) + `intel_dsi_post_disable`
  (DISPLAY_OFF ≈ 300 ms + POWER_OFF ≈ 101 ms sequences); resume side `intel_dsi_pre_enable`
  with `intel_dsi_wait_panel_power_cycle`, POWER_ON, INIT_OTP (50 ms, GPIO 160 toggles),
  DISPLAY_ON (152 ms, DCS 0x11→0x29), `intel_backlight_enable` (`diag44_trace.txt`).
- Post-resume sysfs: `enabled=enabled`, `dpms=On`, `bl_power=0`, `brightness=640` (pre-suspend
  value restored without any manual write).
- Physical observation (user, orientation only — not acceptance evidence): **"Lit but
  black"** — backlight on, no image. The kernel-side enable is electrically partial: DCS LP
  writes complete, backlight on, but the video stream does not display.
- Consequence: the failing scenario is NOT "sequences missing" (they run) and NOT "rails
  never cycle" (they cycle across suspend/resume). The difference vs the working reload is
  the **video path / encoder state**: only a full re-probe re-creates it from a quiesced
  base. This is exactly the module's own resume log hint ("TCON timing is not enforced …
  see Option 2 kernel patch").

### Candidate cross-check (45-02-T1 step 2, against docs/research/RESUME_FIX_LEDGER.md)

| Candidate | Verdict | Reason |
|---|---|---|
| (a) Execute skipped VBT sequences at resume | **VETOED (moot)** | Not skipped: diag44 trace shows the resume path already runs all block-53 sequences. Also adjacent to ledger row 20. |
| Option 2 PPS clamp (device-tree intel_pps.c change) | **VETOED** | Ledger row 1 (PPS timing clamp disproven); the clamp was already rolled back out of the device tree — re-adding it would regress that rollback. Deviation from 45-02 step (ii) recorded. |
| (b) Force PPS/VDD rail assert order | **VETOED (moot)** | Rails already cycle in the right order across suspend/resume (traced). No ordering difference left to force. |
| (c) Restore the state the re-probe rebuilds — **deferred full DSI encoder cycle** | **PROCEED** | Post-resume (link quiesced), atomic disable-all → wait → commit duplicated state with mode_changed forced; DMI-gated to 82H0. Row 20's disproof ("early sequences over a not-ready link, modeset fails") does not cover this: our cycle runs after resume completes, through full atomic commits, and the diag traces document the ordering difference. Row 11 (keep powered) not used — we power off AND on. |

Iteration #1 = candidate (c): `patches/d330_dsi_resume_cycle.patch` (quirk
`QUIRK_DSI_RESUME_FULL_CYCLE` + DMI table entry `DMI_MATCH(DMI_PRODUCT_NAME, "82H0")` +
deferred work in `intel_display_driver.c` resume path), applied by
`.github/workflows/build-kernel.yml` together with the CCS patch
(`patches/d330_display_resume_fix.patch`). Known-good rollback
`linux-image-7.0.14-d330-fix_7.0.14-1_amd64.deb` retained before the first deploy
(sha256 `20dc04db5dab7066333e2382896af43cf50622276b9d8f62c75d3d92a2839e91`,
host copy `C:\Users\Familia\AppData\Local\Temp\opencode\rollback\`).

### Iteration log (≤5)

| # | Build | Deployed kernel | Machine evidence | Outcome |
|---|---|---|---|---|
| 1 | CI run 38329104027 (`fix/d330-dsi-resume-cycle`, both patches) | — | workflow failed at fetch (noble backport shadowing questing; suite moved to `resolute`) | superseded by rerun |
| 1r | CI run 38334925479 (`resolute`, both patches) | 7.0.14-d330-fix + QUIRK_DSI_RESUME_FULL_CYCLE | cycle traced (`intel_dsi_disable` 35 ms → `post_disable` → `pre_enable`), "encoder re-enabled", `bl_power=0 brightness=640` | **FAILED** — eyes-on: lit but black (fresh boot + 2nd resume) |
| 2 | on-device systemd oneshot `d330-dsi-reprobe.service` (rebind after suspend.target) + manual rebind test | same kernel | `reprobe done rc=0`, module reloaded; dpms stuck `Off`, pipe B `enable=no` | **FAILED** — fully black; **the rebind was never a working recovery** (45-01 T4 "panel restored" was sysfs-only) |
| 3 | s2idle resume (`mem_sleep` echo, non-persistent) | same kernel | `PM: suspend entry (s2idle)`, post-resume `bl_power=4` | **FAILED** — fully black; backlight re-enable → lit but black |
| — | KScreen DPMS cycle / `systemctl restart sddm` | same kernel | dpms stuck Off; fresh KWin pipe B disabled | **FAILED** — compositor cannot re-drive the connector |

All outcomes verified by human eyes on the panel (the user), not sysfs. Decisive
experiment: `i915_display_info` boot-vs-resumed diff shows the kernel display state
byte-identical (only the cursor plane FB differs) while the panel is dark — the failure is
below the kernel's model. Full closure in `NO_CLEAN_FIX_PROOF.md` (ROOT-04). The
known-good `7.0.14-d330-fix` was redeployed and verified; CI reverted to the CCS-only
patch application.

## v9.0 iteration 1 (fresh-branch force, 2026-10-15)

<!-- planner-discipline-allow: ULPS_STATE_MASK -->
<!-- planner-discipline-allow: panel power cycle -->
<!-- planner-discipline-allow: 0x160018 -->

Phase 47's MMIO diff (§5 of `DSI_MMIO_DIFF.md`) found the one code-visible
divergence between the always-black resume path and the always-lit reload path:
retained `MIPI_DEVICE_READY` across S3 makes `glk_dsi_device_ready()` run the
ULPS enter/exit dance (rmw `ULPS_STATE_MASK` + DEVICE_READY poke on a live
device) instead of the plain fresh-probe re-arm the reload path takes.

Iteration 1 of the v9.0 ladder (`patches/d330_dsi_device_ready_fix.patch`,
CI `7.0.14-d330-fix` sha `43b2e7c2…8932`) cleared the retained
`ULPS_STATE_MASK + DEVICE_READY` before the cold-boot probe so the whole
pre_enable matched the reload ordering. Deployed behind a verified rollback
(d47 dump kernel `ba47df8d…87be`); one user-authorized rtcwake session;
eyes-on verdict: **still black** (user, verbatim).

At-wake MMIO (wake+1 s, `docs/dumps/re_kit/dsi_regs_diff_it1.txt`) shows the
same broken operational signature as the unpatched session-2 pair (0x6b010,
0x6b044, 0x6b080/0x6b098, 0x6b088, 0x160018, 0x6b004 timeout-marked) while
0x6b000 DEVICE_READY and 0x160084 read identical to boot. Conclusion: running
the reload-identical fresh branch does not restore the image — the
retained-DEVICE_READY/ULPS divergence is falsified as the sole cause. Ledger
row 30. Next rung: full panel power cycle inside pre_enable (the only
remaining resume-vs-reload difference at the panel power domain level).

## v9.0 iterations 2-3 + falsification (2026-10-15)

<!-- planner-discipline-allow: panel power cycle -->
<!-- planner-discipline-allow: MIPI_SEQ_POWER_OFF -->
<!-- planner-discipline-allow: MIPIO_RST_CTRL -->

Iteration 2 (full panel power cycle at the top of pre_enable: assert reset +
MIPI_SEQ_POWER_OFF + 1.5 s reload-scale hold + full re-init, DMI-gated):
the failure mode CHANGED — the panel now comes up backlit-but-blank (user:
"black but lit") where every previous resume left it dark. The panel-side
power rails now behave like the reload path; the image still does not
appear. At-wake signature unchanged (10 differs rows, same broken values).

Iteration 3 (DSI-block MIPIO reset pulse — drop + re-assert MIPIO_RST_CTRL,
mimicking the power-well-cycle reset the re-probe performs): verdict
"Black but lit", signature unchanged.

**Falsification (the decisive capture):** with the iteration-3 instrument
fix (dump node survives unbind/bind), the working-lit state was captured
immediately after a reload workaround while the panel SHOWED THE IMAGE
(`docs/dumps/re_kit/reload_lit_dsi_regs.txt`). Versus the broken-wake arm:
the entire DSI block 0x6b000-0x6c000 is bit-identical (1024/1024); the
whole-file delta is 5 GT monotonic-counter/residency rows. **The MMIO state
of the image-showing panel equals the MMIO state of the black panel.**
Combined with the v8.0 software-state identity, the mechanism is below host
MMIO (panel TCON side); no register write or enable-path sequence can fix
it. Iterations stop at 3 of ≤5. Full closure: NO_CLEAN_FIX_PROOF.md §7;
DSI_MMIO_DIFF.md §5.1; ledger row 32. The reload (unbind/bind) workaround
remains the only recovery, now formalized as the honest mitigation.

### v9.0 CORRECTION (phase 49, 2026-10-16): the reload NEVER restores the image

<!-- planner-discipline-allow: panel power cycle -->
<!-- planner-discipline-allow: rebind -->

The §5.1-style claim above ("panel SHOWED THE IMAGE", "the reload
workaround remains the only recovery") is **WRONG** and is corrected by
phase 49's eyes-on close-out (49-01-CYCLE1/2/3): the user had never run
the reload themselves; eyes-on verification shows the unbind/bind leaves
a **backlit black panel** (kwin dies on unbind, the pipe is never
re-driven) — sddm restart too; **only a reboot restores the image** (it
re-runs the GOP). v8.0 row 29's myth-bust re-confirmed on the v9.0
kernel.

The corrected mechanism (machine-evidenced, 2 independent cycles): the
late-black state HOLDS X=Z while boot/image holds X=Y (the contrast
discriminates — the §5 claim was right in direction); the rebind ALSO
lands at X=Z (reload_lit == it3_resume — black vs black), which is why
it is lit-black; forced X=Y values are insufficient (row 18). The image
requires the GOP's firmware panel init, unreachable from every kernel
path tested. Corrected records: DSI_MMIO_DIFF §5.2; NO_CLEAN_FIX_PROOF
§7.1; ledger row 29 re-confirmed.
