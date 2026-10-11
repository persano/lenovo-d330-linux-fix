# DSI S3 resume trace analysis (Lenovo IdeaPad D330-10IGL, 82H0)

Status: **open.** This records the on-device `i915_reg_rw` tracing done to find
why the DSI panel comes back lit but black after S3 on the D330. It narrows the
failure to i915's resume path for the DSI encoder, and it records one patch that
was tried and disproven. The separate CCS-modifier fix (which makes the atomic
commit succeed) is in `docs/research/DISPLAY_RESUME_CCS_MODIFIER.md`.

Test machine: Kubuntu 26.04, kernel `7.0.0-38-generic`, stock i915 module
(`srcversion CE56CFE46EED334FE7C0674`), unless noted. The shipping kernel
`7.0.14-d330-fix` carries the CCS fix; the DSI experiments are built against the
`7.0.0-38-generic` tree at `~/d330-kernel/linux-7.0.0`.

## Method

ftrace `events/i915/i915_reg_rw`, filtered to the display register ranges:

```
(reg >= 0x6b000  && reg < 0x6c000)    /* DSI ports A..C, INTR, DEVICE_READY, MIPI_CTRL */
(reg >= 0x160000 && reg < 0x164000)   /* BXT/GLK DSI PHY */
(reg >= 0x46000  && reg < 0x47000)    /* CDCLK, DSI PLL, DE PLL */
(reg >= 0xc7200  && reg < 0xc7400)    /* legacy PPS */
(reg >= 0x138000 && reg < 0x139000)   /* BXT_P_CR_GT_DISP_PWRON / MIPIO_RST_CTRL */
```

plus the `intel_pipe_enable` and `intel_pipe_disable` tracepoints. The trace
shows the task/pid and timestamp of every access, so the ordering and the thread
that issues each write are both visible. The machine is suspended with an RTC
wake (`rtcwake -m no -s 45` then `systemctl suspend`), and the trace spans the
suspend and the resume.

Scripts and captures on the tablet: `/home/santiago/cap.sh`, `cap2.sh`,
`noc2.sh`; traces `/home/santiago/reg_resume_inst.txt` (resume, compositor
running), `reg_reload2.txt` (working reload), `reg_resume_noc.txt` (resume, no
compositor).

## Result 1: the working reload is one clean, single-threaded sequence

A PCI unbind and bind of `0000:00:02.0` re-inits the panel. The trace is 21
writes from one thread (`sh`, the process that writes to `bind`, because the
probe runs synchronously in that context), spanning about 1 ms. Order:

```
0x138090=8  0x162024=8080e480  0x162028=8080e480  0x162070=33cb0443     /* PHY: MIPIO reset assert, DPHY port A */
0x138090=9  0x138090=b                                                /* PHY: MIPIO release */
0x163024=8080e480  0x163028=8080e480  0x163070=33cb0443  0x163198=ffffff  0x1631a0=30008003   /* DPHY port C */
0x6b004=40000000  0x6b048=41  0x6b0c0=20000  0x6b06c=2805  0x6b06c=1005          /* DSI core: INTR clear */
0x6b000=5  0x6b104=1  0x6b104=40000000                                /* DEVICE_READY, MIPI_CTRL */
0x46080=40000000  0x46000=f0009c                                      /* DSI PLL, CDCLK */
```

So the reload programs the **PHY first**, then the DSI core, then the PLL and
CDCLK. It does not rewrite the clock gating or chicken registers, and it does
not touch the DSI PLL ratios.

## Result 2: the resume with a compositor churns enable and teardown

With KWin running, the same filter shows the DSI init split across five threads
and interleaved with a teardown. Ordered summary:

```
t=66.98  kwin_wayland   : 0x6b004 0x6b048 0x6b0c0 0x6b06c 0x6b000=5 0x6b104 0x46080=40000000 0x46000=f0009c   /* DSI unprepare, PLL off, CDCLK, driven by the suspend */
t=66.68                intel_pipe_disable (pipe A)                                                             /* suspend */
t=68.21  kworker/u8:2  : 0x138090=8  DPHY A  0x138090=9  0x138090=b  DPHY C  0x163198  0x1631a0                /* full clean PHY init, matches the reload */
t=68.30  kworker/u8:15 : 0x138090=9  0x138090=8  0x138090=0  0x46070=0  0x46000=0x300024                     /* teardown: MIPIO reset, DE PLL off, CDCLK change */
t=68.87  kworker/u8:19 : 0x46408=0x20  then the full PHY init again  then 0x46430 0x46530 0x46530            /* re-init plus clock gating */
t=68.88  kworker/1:2   : 0x4653c=0x4000  0x4653c=0
```

The enable and teardown alternate, the init runs on more than one worker, and
the net result is a black panel. This matches the earlier observation of a
split, duplicated DSI init on resume.

## Result 3: the resume with no compositor does nothing at all

With `systemctl stop sddm` and only the kernel console on the GPU (`fgconsole`
1), the CRTC reads `enable=yes, active=yes`, mode `800x1280`, pipe live, and the
panel shows the console.

After an S3 resume in that state:

- the trace buffer is **empty** (`entries-in-buffer/entries-written: 0/0`), so
  i915 issued **no** DSI or pipe register writes at all;
- `0x6b000=1`, `0x46070=0xc0000000`, `0x138090=0`, and the CRTC still reads
  `enable=yes, active=yes`;
- the panel is black anyway.

So without a compositor the driver decides the DSI encoder is still enabled
(the registers kept their values across suspend), skips re-init, and leaves a
dead link in place. This is the cleanest signal: the failure needs the DSI link
to be reinitialised on resume, and the current readout path does not do it.

## Ruled out by these traces

- **CDCLK is not the cause.** `i915_cdclk_info` reports `Current CD clock
  frequency: 158400 kHz` both in the working console state and after the failing
  resume. Only the register encoding differs (`0x300278` before, `0xb0013b`
  after), and the DE PLL reads back enabled (`0xc0000000`). Forcing a VT switch
  and an fb blank/unblank left `0x46000` unchanged.
- **`0x138090` is not an enabled/disabled marker.** It reads `0` in the working
  console state and `0xb` after the working reload, so no simple value
  distinguishes working from broken.
- **The differing registers are not DSI PLL math.** `0x46530`, `0x4653c`,
  `0x46430`, `0x46070`, `0x46408` are `GEN9_CLKGATE_DIS_0`, `GEN9_CLKGATE_DIS_4`,
  `GEN8_CHICKEN_DCPR_1`, `BXT_DE_PLL_ENABLE`, `HSW_NDE_RSTWRN_OPT`.
- **A CRTC reading taken minutes after resume is not meaningful.** The CRTC
  state after resume is flaky (`enable=yes` on some runs, `enable=no` on
  others), and KDE idle screen blanking turns the CRTC off. Any test must hold
  `systemd-inhibit --what=idle` or read within seconds of the resume.

## Disproven patch: DSI panel power cycle on resume

A DMI-gated (`DMI_PRODUCT_NAME` `82H0`) patch was added at the top of
`intel_dsi_pre_enable()` in `vlv_dsi.c`, before `intel_dsi_wait_panel_power_cycle()`:

```c
if (dmi_match(DMI_PRODUCT_NAME, "82H0")) {
        intel_dsi_vbt_exec_sequence(intel_dsi, MIPI_SEQ_ASSERT_RESET);
        intel_dsi_vbt_exec_sequence(intel_dsi, MIPI_SEQ_POWER_OFF);
        intel_dsi->panel_power_off_time = ktime_get_boottime();
}
```

It built clean, and the DMI gate matches on device (`/sys/class/dmi/id/product_name`
is `82H0`). It did **not** fix the panel, and it made the resume worse: the early
DCS sequences transmit over a DSI link that is not ready, the modeset fails, and
the CRTC is left disabled (`enable=no`). The patch file was deleted and the CI
wiring was restored. The premise was also weak: the suspend side already runs
`BACKLIGHT_OFF`, `DISPLAY_OFF`, `ASSERT_RESET`, `POWER_OFF`, and the resume side
runs the matching power-on, so the panel already power-cycles across
suspend/resume.

## Update: `pr_err` marker tracing (built against 7.0.0-38, rounds 1-3)

`drm.debug`/dyndbg turned out to be a dead end for this: writes to
`/sys/module/drm/parameters/debug` are accepted (readback confirms) but the
trace buffer holds **zero** `[drm:...]` lines (only the boot `[drm]` banner), and
`dynamic_debug/control` has only 2 `i915` sites and **0** in `vlv_dsi`, so
i915's `drm_dbg_kms()` output never lands. Unconditional `pr_err` markers
compiled into the module are the only way to see the call path; rebuilt into the
`7.0.0-38` tree and captured from `dmesg` across a full suspend/resume and
against a working reload.

### The resume call path: i915's own resume does not call `pre_enable`

Markers at the top of `intel_dsi_pre_enable()`, `intel_dsi_post_disable()`,
`__intel_display_driver_resume()` and `intel_modeset_setup_hw_state()` show:

- suspend: `intel_display_driver_suspend` -> `intel_dsi_post_disable` (panel off);
- resume: `__intel_display_driver_resume` -> `intel_modeset_setup_hw_state` run on
  `kworker/u8` but do **not** reach `intel_dsi_pre_enable()`;
- ~3 s later the DSI re-enable runs, driven by **`kwin_wayland`** (its modeset
  commit), not by i915's resume.

The panel init is therefore triggered by the compositor's commit after resume.
With no compositor (Result 3 above) it never runs, which is why the readout path
leaves a dead link.

### Resume runs the complete, correct cold MIPI sequence

`D330SEQ`/`D330ELEM`/`D330GPIO` markers on `intel_dsi_vbt_exec()`,
`mipi_exec_gpio()` and the `mipi_seq` ids show the resume runs the **whole**
cold batch, not a truncated one:

```
POWER_ON(10, GPIO144=1) -> DEASSERT_RESET(1) -> glk_dsi_enable_io -> prepare
  -> device_ready -> INIT_OTP(2, GPIO160 1/0/1) -> DISPLAY_ON(3) -> BACKLIGHT_ON(6, GPIO145=1)
```

Suspend runs `BACKLIGHT_OFF(7, GPIO145=0) -> DISPLAY_OFF(4) -> ASSERT_RESET(5, GPIO160=0)
-> POWER_OFF(11, GPIO144=0)`. `D330DLY`/`D330PWR` show the panel-on/off delays and
the power-cycle wait firing with their VBT values. A shorter 6 s capture made it
look like the sequence stopped mid-`INIT_OTP`; a full 18 s window shows it
completes through `DISPLAY_ON` and `BACKLIGHT_ON`.

### i915 *does* drive the panel GPIOs on GLK

The `D330GPIO` markers fire from `mipi_exec_gpio()`, which on Gemini Lake
(non-native) calls `bxt_gpio_set_value()` -> `soc_gpio_set_value()`, and show
i915 driving **GPIO 144** (power), **145** (backlight) and **160** (reset/OTP)
with the same values on both the resume and the working reload. This
**corrects** the earlier claim (in `DISPLAY_RESUME_CCS_MODIFIER.md`) that "i915
has no panel-power / backlight GPIO ... `gpio_panel`/`gpio_backlight` are always
NULL": the `intel_dsi->gpio_panel` field is indeed NULL on GLK, but the VBT
**MIPI sequence** elements drive those pins directly, and they are driven
identically on both paths.

### Reload vs resume: the only host diff is `glk_cold_boot`

| | cold_boot | `DEVICE_READY` at `glk_dsi_enable_io` | order |
| :-- | :-- | :-- | :-- |
| resume (black) | `1` | `0x0` | `prepare` -> `device_ready` |
| reload (works) | `0` | `0x5` | `device_ready` -> `prepare` |

Every MIPI sequence id, every sequence element and every GPIO value is
**identical**; `D330PLL` reads `BXT_DSI_PLL_CTL=0x132` on both. This reconfirms
the `DISPLAY_RESUME_CCS_MODIFIER.md` finding that `glk_cold_boot` is a
correlate, not the cause.

### A full display power cycle already happens on every S3

`i915_drm_suspend` -> `intel_display_power_suspend_late()` ->
`intel_power_domains_suspend()` -> `bxt_display_core_uninit()` +
`bxt_enable_dc9()`; resume -> `intel_display_power_resume_early()` ->
`bxt_disable_dc9()` + `intel_power_domains_resume()` ->
`intel_power_domains_init_hw(true)` -> `bxt_display_core_init()`. The display
core and power wells are already torn down and re-initialised across S3, so
"the resume does not reset the PHY/power well" is **false**. Forcing a
probe-style full init instead (`intel_power_domains_init_hw(display, false)` on
`82H0`) trips repeated `WARNING: display/intel_dmc.c:701 at
assert_dmc_loaded+0x29b/0x470` and no panel, so that lever is disproven too.

### Backlight is a second, separate bug

After resume the panel is left with `bl_power=4` and `actual_brightness=0`
(backlight off) while `brightness=640`; writing `brightness` re-enables it
(`actual=640`, `bl_power=0`). Forcing it on shows the panel **backlit but still
blank**, so the backlight is independent of (and not the cause of) the missing
image. Worth reporting separately.

## Current working conclusion

The host behaviour on resume is now traced end to end and is **bit-identical**
to a working state: i915 runs the full DSI power-on sequence (including
`DISPLAY_ON` and `BACKLIGHT_ON`), drives the same VBT GPIOs (144/145/160),
programs the same `BXT_DSI_PLL_CTL`, and the display core is already
power-cycled by S3. The only host difference from a working reload is
`glk_cold_boot` (and its `prepare`/`device_ready` ordering), which is a
correlate, not the cause. The panel nonetheless stays blank. The fault is below
the host register / MIPI-sequence layer -- most consistent with the panel (or
its DCS link) not surviving S3 and needing something the reload's full
probe/init path does that the resume path does not. No `vlv_dsi.c`
register/quirk patch has fixed it, and none can be expected to.
