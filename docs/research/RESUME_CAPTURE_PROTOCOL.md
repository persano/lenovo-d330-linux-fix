# D330 Black-Resume Capture Protocol & Off-Device Safety Kit Runbook

## Overview

This runbook defines how to capture a black-resume event on the Lenovo
IdeaPad D330-10IGL (Type 82H0) without corrupting the evidence, and how to stage
the off-device safety kit (golden kernel module, live USB, firmware dumps,
checksummed source tree) before any kernel experiment. It exists because the
previous on-device sessions produced captures that were too short and too
easily invalidated by desktop idle blanking; the protocol below pins the
window, the inhibit hold, the suspend mechanism, and the rollback path.

The two research sources this protocol is built on:

- `docs/research/DSI_RESUME_TRACE_ANALYSIS.md` — ftrace methodology, register
  ranges, tracing rules, capture-window finding.
- `docs/research/DISPLAY_RESUME_CCS_MODIFIER.md` — cold-boot vs resume
  behavior, golden-module build/deploy pipeline, GOP extraction, rtcwake.

---

## Prerequisites

On the D330 (or the Linux build host):

```bash
sudo apt update && sudo apt install -y \
    util-linux \
    coreutils \
    zstd \
    binutils \
    intel-gpu-tools \
    acpica-tools
```

- `util-linux` provides `rtcwake` and `systemd-inhibit`.
- `coreutils` provides `sha256sum` (kit integrity).
- `zstd` + `binutils` are used by the golden-module pipeline.
- `intel-gpu-tools` + `acpica-tools` support the VBT/ACPI dump extraction
  (same tool set as `docs/dumps/README.md`).
- The live-ISO toolchain (`xorriso`, `unsquashfs`, `mksquashfs`) is needed only
  at live-USB build time on the build machine; `scripts/build_live_iso.sh
  --dry-run` validates it (see kit staging below).

Root is required on the device for ftrace, rtcwake, module replacement, and
journalctl kernel excerpts.

---

## Protocol: two arms only

Every capture run records ONE of exactly two arms:

1. **Black resume** — suspend, resume normally (no intervention), capture while
   the panel is still black. This is the failure state.
2. **Working reload** — after a black resume, run the proven unbind/bind reload
   (`echo 0000:00:02.0 > /sys/bus/pci/drivers/i915/unbind` followed by the
   matching `bind` into the same path) and capture through the recovery. This
   is the working control arm.

**NO cold-boot control arm.** Cold boot works because UEFI GOP leaves the
display initialized and i915 fast-boots without ever running the DSI init
sequence (`DISPLAY_RESUME_CCS_MODIFIER.md:107-110`: cold boot logs neither
`post_disable` during suspend nor `pre_enable` during resume), so it is not a
valid control for the resume path. The resume path DOES re-run DSI init; the
working control is the unbind/bind reload (`DISPLAY_RESUME_CCS_MODIFIER.md:111-112`).

### Suspend without lid interaction

Suspend with `rtcwake -m mem -s N` (choose N to cover the capture window;
`DISPLAY_RESUME_CCS_MODIFIER.md:307`). This avoids lid/dock side effects. For
trace spans that must cover the whole suspend-plus-resume cycle in one ftrace
session, the prior on-device method was `rtcwake -m no -s 45` followed by
`systemctl suspend` (`DSI_RESUME_TRACE_ANALYSIS.md:24-29`).

### Hold the idle-inhibit for the entire test

Wrap every test in `systemd-inhibit --what=idle <command>` and keep it held
through the whole capture. Desktop idle blanking turns the CRTC off within
seconds of resume, and CRTC reads taken minutes after resume are flaky
(`enable=yes` on some runs, `enable=no` on others) —
`DSI_RESUME_TRACE_ANALYSIS.md:106-109`. An uninhibited capture measures the
compositor's blanking, not the panel failure.

### Capture window: at least 18 seconds on BOTH arms

The capture window must be at least 18 seconds on both arms. A 6-second
capture made the panel power sequence look truncated at `INIT_OTP`; a full
18-second window shows the sequence completing through `DISPLAY_ON` and
`BACKLIGHT_ON` (`DSI_RESUME_TRACE_ANALYSIS.md:172-174`). Do not ship any
capture shorter than this.

### Capture set per arm

- `journalctl -k` kernel excerpt covering the suspend/resume cycle.
- `dmesg` at the end of the window.
- The ftrace capture over the five display register ranges (see Tracing rules)
  with the `intel_pipe_enable` / `intel_pipe_disable` tracepoints
  (`DSI_RESUME_TRACE_ANALYSIS.md:19-23`).
- Prior-art pointers from the earlier on-device sessions (not vendored into
  this repo): capture scripts `cap.sh`, `cap2.sh`, `noc2.sh` and traces
  `reg_resume_inst.txt` (resume, compositor running), `reg_reload2.txt`
  (working reload), `reg_resume_noc.txt` (resume, no compositor) —
  (`DSI_RESUME_TRACE_ANALYSIS.md:32-35`).

---

## Tracing rules

Only unconditional `pr_err` markers prefixed `D330` produce usable output.
`drm.debug`/`dyndbg` is a verified dead end on this kernel: writes to
`/sys/module/drm/parameters/debug` are accepted but the trace buffer holds zero
`[drm:...]` lines, and `dynamic_debug/control` has only 2 i915 sites and 0 in
`vlv_dsi` (`DSI_RESUME_TRACE_ANALYSIS.md:134-142`). Do not budget capture time
around dynamic debug.

The five ftrace MMIO filter ranges (`DSI_RESUME_TRACE_ANALYSIS.md:19-23`):

```text
(reg >= 0x6b000  && reg < 0x6c000)    /* DSI ports A..C, INTR, DEVICE_READY, MIPI_CTRL */
(reg >= 0x160000 && reg < 0x164000)   /* BXT/GLK DSI PHY */
(reg >= 0x46000  && reg < 0x47000)    /* CDCLK, DSI PLL, DE PLL */
(reg >= 0xc7200  && reg < 0xc7400)    /* legacy PPS */
(reg >= 0x138000 && reg < 0x139000)   /* BXT_P_CR_GT_DISP_PWRON / MIPIO_RST_CTRL */
```

---

## Golden-module rollback pipeline

The verbatim pipeline for building, shipping, and rolling back an
experimental i915 module (`DISPLAY_RESUME_CCS_MODIFIER.md:303-306`):

```text
build:    make -j2 M=drivers/gpu/drm/i915 modules
strip:    strip --strip-debug <built i915.ko>
pack:     zstd -19 i915.ko
deploy:   cp i915.ko.zst /lib/modules/7.0.0-38-generic/kernel/drivers/gpu/drm/i915/i915.ko.zst
depmod:   depmod -a
initramfs: update-initramfs -u
reboot
```

Rollback: restore the golden (pre-experiment) `i915.ko.zst` file over the
deployed path and repeat `depmod -a`, `update-initramfs -u`, reboot. Never
deploy an experimental module before the golden copy is registered in the kit
manifest and verified (next section).

---

## Off-device kit staging

The kit lives in `docs/dumps/safety_kit/` with ONE integrity anchor,
`MANIFEST.sha256`. Artifacts are gitignored; the manifest stays committable.
Each artifact is registered and verified with `scripts/prepare_safety_kit.sh`:

1. **Golden `i915.ko.zst`** — the stock module from the target kernel, built by
   the pipeline above WITHOUT experiment patches; register it first:

   ```bash
   cp i915.ko.zst docs/dumps/safety_kit/
   scripts/prepare_safety_kit.sh --register i915.ko.zst
   ```

2. **Live ISO** — built with `scripts/build_live_iso.sh`; the kit-staging
   dry-run runs that script's own `--dry-run` and reports the result
   informationally (the ISO toolchain is validated at build time on the build
   machine, not as a kit-side failure). Register the finished image.

3. **VBT dump** — produced by `scripts/extract_telemetry.sh`, which stages the
   raw `vbt/i915_vbt.bin` and its decode under
   `docs/dumps/telemetry_<TIMESTAMP>/` (`docs/dumps/README.md:69-71`). Register
   both files.

4. **GOP extract** — carved from the BIOS flash-descriptor dump `bios.bin`
   using the `uefi_firmware` Python parser (parse the flash descriptor, walk
   the FV/FFS, dump the `IntelGopDriver` compressed section, carve the
   `MZ`/PE32+); `DISPLAY_RESUME_CCS_MODIFIER.md:211-228` (reference dump
   sha256 `74947A176B2973B5E944D98C479BA11369AEE55EFC76E67C8AE87DE58A7F7C4B`).

5. **Checksummed tablet source tree** — the kernel source tarball the module
   was built from (`DISPLAY_RESUME_CCS_MODIFIER.md:301-302`: tarball, no git);
   register its sha256 line.

Then verify everything as one mandatory pre-restore step:

```bash
scripts/prepare_safety_kit.sh --verify
```

`--verify` must pass before any artifact is restored onto the device; a failed
verification aborts the runbook (tamper detection is machine-proven by
`scripts/test_safety_kit.sh`).

Live-USB step: run `scripts/build_live_iso.sh`, write the image to USB, and
verify the written image against its manifest checksum before booting the
device with it.

---

## Coexistence cross-reference

The recovery hook
`patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh`
documents two state-file variables in its header comment:
`D330_DISPLAY_RESUME=0` disables the fallback reload entirely (logged on every
resume), and `D330_REAL_FIX=1` makes the hook stand down while the Phase 45
real fix owns display restoration (contract shipped in Phase 43; the marker is
written by Phase 45). See the hook's header comment for the full wording.

---

## Rung-session block (phase 51 keep-panel-powered ladder)

One rung = one CI kernel + one user-authorized device session: deploy
(sha-verified rollback first) → suspend → wake → dump pair + marker
evidence → eyes-on verdict. This block is executed verbatim by the
session; no new script is created (marker collection is a runbook step,
not a collector).

### One-time pre-check (before spending a CI build)

Confirm the installed kernel carries no historical markers, so the E1
patch's own compiled-in skip markers are the only source (research A1,
P2):

```bash
dmesg | grep -c D330SEQ     # expected 0 on the installed echo-2 kernel
```

A non-zero count means the ad-hoc historical markers ARE present in the
installed kernel; zero means the rung kernel's compiled-in markers carry
the whole proof.

### Marker collection: dmesg-based, compiled-in markers only

Only unconditional `pr_info`/`drm_info` markers prefixed `D330` produce
output (ledger row 16 disproved drm.debug/dyndbg: writes accepted, zero
`[drm:...]` lines land). The E1 skip markers (`[D330 82H0] ...`
`drm_info` lines) therefore land in dmesg / `journalctl -k`, never in
tracefs. Collect a dmesg excerpt covering the whole cycle and archive it:

```bash
dmesg | grep 'D330 82H0' > rung_<N>_dmesg_markers.txt
```

### Two-dump sequence inside one >=18 s wake window

For a span covering the whole suspend-plus-resume cycle in one session,
use the prior on-device method (cited above):

```bash
rtcwake -m no -s 45
systemctl suspend
```

On wake (user-triggered, no lid interaction), immediately:

```bash
sudo capture_dsi_dumps.sh resumefast   # ~0-1 s post-wake, pre-KWin-commit
sudo capture_dsi_dumps.sh resumelate   # ~4 s post-wake, post-KWin-commit
```

Both captures MUST land inside the single >=18 s wake window. Never
shorten the window: a 6-second window already produced one wrong
conclusion (Capture window section above). The trigger is synchronous,
so back-to-back invocation is safe; `EBUSY` means another trigger is in
flight. The `resumelate` dump is the X=Y/X=Z discriminator; compare with:

```bash
scripts/dsi_mmio_diff.sh boot_dsi_regs.txt resumelate_dsi_regs.txt
```

The `## X=Y operational set` verdict in the diff output is the binary
criterion (design-doc fact 10 literal).

### Kit registration

Register both dumps and the marker excerpt before ending the session:

```bash
scripts/prepare_safety_kit.sh --register resumefast_dsi_regs.txt
scripts/prepare_safety_kit.sh --register resumelate_dsi_regs.txt
scripts/prepare_safety_kit.sh --register rung_<N>_dmesg_markers.txt
scripts/prepare_safety_kit.sh --verify --kit-dir docs/dumps/re_kit
```

### Success-path battery block (only after X=Y + eyes-on)

Quantify the keep-hot battery cost: one 15-min S3 with keep-hot ON vs
OFF, battery % and energy-rate deltas, recorded before and after each S3:

```bash
upower -i $(upower -e | grep BAT)
```

Fallback when upower is absent: `/sys/class/power_supply/BAT*`
(`capacity`, `energy_now`/`energy_full`, `power_now`).
