# Upstream Handoff: D330-10IGL (Gemini Lake) MIPI-DSI panel black after S3 — filing package

<!-- planner-discipline-allow: bl_power -->
<!-- planner-discipline-allow: rebind -->
<!-- planner-discipline-allow: PMIC -->
<!-- planner-discipline-allow: panel power-cycle -->
<!-- planner-discipline-allow: MIPI_SEQ_INIT_OTP -->

Purpose: everything a maintainer (or you, filing by hand per the phase 44 decision) needs
to reproduce, evidence, and reason about this bug. Machine evidence first, honest outcome
stated. **Do not commit credentials; this file contains none.**

## Machine

- Lenovo IdeaPad D330-10IGL, DMI product `82H0` (DMI: LENOVO 82H0/LNVNB161216, BIOS
  G0CN12WW 12/19/2022)
- Gemini Lake Refresh: Celeron N4020, UHD Graphics 600; MIPI-DSI panel 800x1280
  (card1-DSI-1), GPIOs 144 (power) / 145 (backlight) / 160 (reset/OTP) per VBT block 53
- Ubuntu resolute-era userspace, kernel 7.0.0-38.38 base (upstream 7.0.14) with a small
  DMI-gated CCS patch unrelated to this bug (kept separate)

## Symptom

Suspend (S3 `deep` — and also `s2idle`) → resume: backlight returns, desktop session
survives, sysfs reports the connector enabled (`dpms=On`, `bl_power=0`, brightness
restored), `i915_display_info` shows pipe B `enable=yes active=yes mode="800x1280"
port_clock=80000` with planes assigned — and the **panel shows no image** (lit but black).
The display pipeline cannot be recovered by: the i915 unbind/bind reload (restores sysfs,
not the image), a fresh compositor (SDDM restart), KScreen DPMS cycles, a second
suspend/resume, or an atomic full encoder cycle forced post-resume. **Only a full reboot
restores the panel.**

## What we proved (evidence)

1. **Kernel state is byte-identical working vs broken**: `i915_display_info` captured on
   the same boot pair differs only in the cursor plane's framebuffer; everything else —
   pipe, clocks, planes, connector — identical. The failure is below the kernel's
   software model.
2. **The VBT sequences run and are not enough**: ftrace shows the resume path running the
   complete block-53 cycle (POWER_ON ~1 ms GPIO 144, INIT_OTP 50 ms GPIO 160 toggling,
   DISPLAY_ON 152 ms DCS 0x11→0x29) plus `intel_backlight_enable`; the panel still shows
   nothing.
3. **The boot-time success depends on the GOP firmware**: the GOP driver
   (`gop_driver_dc90d1e2.efi`) runs its own panel init from the same VBT before ExitBootServices;
   the kernel's later replay of the same sequences does not reproduce the result. Two VBTs
   exist (SPI copy "BROXTON" BDB 206 without block 53; runtime OpRegion copy "GEMINILAKE"
   BDB 212 with block 53 — the kernel uses the runtime one).
4. **Disproven levers (29)**: PPS/TCON timing clamps, D-PHY retuning, forced register
   batches (MIPI/CDCLK/chicken), panel power-cycle re-sends, keep-panel-powered
   early-returns, PMIC-I2C theories, s2idle/deep switches, power-well disables, backlight
   toggles, re-probe/rebind recoveries, and more — each with its disproof in
   docs/research/RESUME_FIX_LEDGER.md.
5. **Not PMIC on I2C bus 6**: no Linux I2C client exists there and the GOP binary has no
   I2C/PMIC MMIO or strings.

## Artifacts

- `docs/research/NO_CLEAN_FIX_PROOF.md` — full iteration closure (3 deployed, eyes-on
  tested candidates: deferred atomic full cycle, post-resume re-probe, s2idle — all
  failed with the panel still imageless)
- `docs/research/GOP_DSI_RE_FINDINGS.md` — GOP RE (22,080 B driver, VBT handoff at
  OpRegion +0x3ba/+0x3c2, block-53 sequence table decoded)
- `docs/research/RESUME_VS_RELOAD_DIFFERENTIAL.md` — suspend/off vs reload vs probe
  differential with traces
- `docs/dumps/re_kit/` — checksummed kit: GOP binary, SPI dump, VBT decodes, ftrace
  traces, displayinfo pair + diff

## Ask for upstream

Which part of the boot-time GOP panel bring-up the kernel's resume path fails to
replicate on GLK DSI — and what instrumentation you would want added (e.g. a
GLK-DSI-capable `i915_dsi_info` debugfs dump of the transcoder/DPHY registers at boot
vs post-resume) to close the gap. We could not find it within 5 iterations
(NO_CLEAN_FIX_PROOF.md); the display-state registers we could see are identical.

## Filing note (for the user)

File at https://gitlab.freedesktop.org/drm/i915/kernel/-/issues with: this file's
machine/symptom/evidence sections, `dmesg` from a failing resume,
`/sys/kernel/debug/dri/*/i915_display_info` boot + post-resume pair, and the ftrace
resume trace. Attach the kit's `broken_displayinfo.txt`/`boot_displayinfo.txt`/diff.
Remove any personal info before submitting.

## v9.0 addendum (2026-10-16): the fix is unreachable from the kernel — corrected closure

**OPTIONAL documentation — filed at the user's convenience; blocks nothing
(FIX-03 heritage). Nothing upstream waits on this filing.**

Phase-48's DSI register comparison (§5.1) found the entire DSI block
bit-identical (1024/1024 registers; whole-file delta = 5 GT
monotonic-counter/residency rows) between the post-reload state and the
broken resume state. Correction (phase 49): the post-reload arm was never
an image state — the reload (unbind/bind) leaves a backlit black panel
(user-verified; the inherited premise was never eyes-on-checked), so
§5.1's "no host MMIO state discriminates working from broken" compared
black vs black and is WITHDRAWN (§5.2). The corrected, machine-evidenced
contrast (2 independent user-triggered cycles; late-black arms verified
black at 30 s): the broken state HOLDS the non-boot operational register
set X=Z (0x6b010=0000b8ea, 0x6b044=0000001e, 0x6b080/0x6b098=0a051003,
0x6b088=0014000c, timeout-marked 0x6b004) while the boot/image state
holds X=Y — the host-visible contrast DOES discriminate. Every kernel
path tested lands at X=Z: the three DMI-gated (82H0) v9.0 resume variants
(ledger rows 30-32) and the full PCI re-probe (which likewise leaves the
panel backlit black). Forcing X=Y values alone is insufficient (ledger
row 18). Only the GOP's firmware boot init produces X=Y plus the direct
TCON programming the kernel cannot see or replay (GOP_DSI_RE_FINDINGS;
the DPHY 0x162000+ area reads all-ones on every arm). Re-confirmed across
3 fresh user-triggered close-out cycles on the shipped it3 kernel
(verdicts verbatim: "Black but lit" each cycle). Recovery = reboot only —
no kernel path, module reload, or compositor restart restores the image.

Pointers (corrected records): docs/research/DSI_MMIO_DIFF.md §5.2 (the
corrected contrast; §5.1 withdrawn) · docs/research/NO_CLEAN_FIX_PROOF.md
§7.1 (corrected closure) and §7 (original) ·
docs/research/RESUME_FIX_LEDGER.md rows 30-32 (the v9.0 iteration
disproofs), row 29 (manual-recovery-only rule), row 18 (value forcing
insufficient).

Next instrument (DSI_MMIO_DIFF §6; NO_CLEAN_FIX_PROOF §7.1): panel-side
probe — a logic analyzer on the panel flex (DSI lanes + reset + power
rails) during GOP boot vs kernel re-probe, to see what the GOP does that
the kernel cannot; alternatives: GOP re-execution replay, or the TCON
datasheet once the panel controller is identified (block-55 VBT table
still undecoded).

## v10.0/v11.0 addendum (2026-10-19): filed, superseded, FIXED

Everything above this line is historical. Resolution, in order:

1. **Filed**: the report was filed as a new work item,
   https://gitlab.freedesktop.org/drm/i915/kernel/-/work_items/17401
   (2026-10-18) with triage note + evidence comment + 4 privacy-scanned
   attachments. Issue 6619 (the original possible-match) was a different
   bug class and is closed. GitLab labels were impossible to set
   (community reporter role silently drops label writes) — left to
   maintainers.
2. **The fix already existed upstream**: issue
   #13225 (OPEN, same machine model) carries a GLK reset-order fixup
   patch (note 3698515) and the mechanism analysis (vsyrjala, note
   3169683: VBT "kinda borked" — empty `MIPI_SEQ_DEASSERT_RESET`, reset
   pulse GPIO 160 inside `MIPI_SEQ_INIT_OTP`, running after DSI host up;
   `vlv_fixup_mipi_sequences()` repairs this only for VLV + v1 blocks).
   The "logic analyzer on the panel flex" instrument this handoff asked
   for was never needed: the wire content was fine, the host ordered its
   own reset wrong.
3. **Validated on a second unit (this project's D330)**: the #13225 patch
   adapted to a v7.0 tree (one-line dispatch change
   `IS_GEMINILAKE(i915)` → `display->platform.geminilake`), shipped in
   `patches/d330_dsi_glk_reset_order_fixup.patch` (sha F97F4E87) inside
   kernel `7.0.14-d330-fix` (CI run 39281203672): 10/10 lit S3 resumes
   eyes-on + every boot lit. Ledger row 34; NO_CLEAN_FIX_PROOF §9
   overturns the v9.0 "no clean fix" verdict. Block 55 was meanwhile
   decoded negative (`BDB_COMPRESSION_PARAMETERS_OLD`).
4. **Shipped**: release v11.0 (2026-10-19) carries the fix to users with
   the one-script installer `scripts/d330-full-setup.sh`.
5. **Still open upstream**: confirmation comments on #13225 (second-unit
   validation) and #17401 (suggest duplicate once fixup lands) — user to
   paste manually; Akismet flags every API-posted comment from this
   account as spam.
