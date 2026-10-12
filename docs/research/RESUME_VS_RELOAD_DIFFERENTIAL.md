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
