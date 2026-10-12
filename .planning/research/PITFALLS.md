# Pitfalls Research

**Domain:** Reverse-engineering and fixing a Gemini Lake (i915) MIPI-DSI S3-resume black screen on the Lenovo IdeaPad D330-10IGL (82H0), using Ghidra + REA + GLM 5.3 Flash on real hardware.
**Researched:** 2026-10-12
**Confidence:** HIGH for the do-not-retry ledger and safety traps (on-device, reproduced, some cross-checked upstream); MEDIUM for the RE-specific pitfalls (category-level, not yet hit on this project); MEDIUM for the upstream survey (I could reach dri-devel/lists.freedesktop.org but not the i915 GitLab tracker directly).

---

## How To Use This Document

Two deliverables here:

1. **The Do-Not-Retry Ledger**, every theory this project already disproved on-device, plus the community/upstream dead ends. The milestone must not re-propose any row as a fix. If a phase plan contains a ledger item as an implementation step, the plan is wrong.
2. **Warning sign → prevention → phase** for the traps that *will* bite during v8.0 (regression, safety, RE technique).

The open bug, for reference: after resume the DSI panel powers up, the full cold MIPI sequence runs unmodified, every host register is byte-identical to a working state, and the panel stays black. Only a full i915 PCI unbind/bind reload recovers it. The control that matters is **black resume vs working reload**, never cold boot (cold boot never runs the DSI path at all, i915 fast-boots on the GOP's init).

### Recommended v8.0 phase legend

The roadmap is not written yet. This document maps pitfalls to these recommended phases; renumber freely, keep the ordering.

| Ref | Working phase name | Job |
|-----|--------------------|-----|
| P43 | Guardrails & Do-Not-Retry Ledger | Codify the ledger, safe test protocol, golden module + live-USB recovery, backup the current flash/VBT dumps. |
| P44 | Community & Upstream Survey | Confirm nothing upstream fixes this; harvest error signatures and platform neighbours; file the i915 bug correctly. |
| P45 | Windows / GOP Binary RE | RE `igdkmd64.sys` + `IntelGopDriver` + VBT/ACPI with Ghidra + REA; find the resume-path difference. |
| P46 | Deep RE of the i915 Resume Path | `__intel_display_driver_resume` commit vs the reload's full probe / `intel_modeset_setup_hw_state`. |
| P47 | Fix Delivery & Fallback Recovery | Ship the driver patch/module or the seamless recovery; make the reload invisible if a clean resume fix is impossible. |
| P48 | Regression & Deployment Verification | Prove no regression on cold boot, touch, audio, and the existing shipped tools. |

---

## Critical Pitfalls

### Pitfall 1: Re-treading a disproven lever (no ledger discipline)

**What goes wrong:**
A new milestone (or a fresh agent/model) reads the symptom "DSI panel black after resume, registers byte-identical" and, with no memory of the prior work, proposes one of the dozen-plus theories this project already killed: a PPS timing clamp, a D-PHY retune, force the GOP's PPS, keep the panel powered, `glk_cold_boot=0`, `drm.debug` tracing, a bare PCI reset. Each consumes real hardware time and, worse, some make the box worse (Pitfalls 2–5).

**Why it happens:**
The disproven list lives in three prose research docs (`DISPLAY_RESUME_CCS_MODIFIER.md`, `DSI_RESUME_TRACE_ANALYSIS.md`, `COMMUNITY_FINDINGS.md`), not as a machine-checkable gate. The prior milestone's own `COMMUNITY_FINDINGS.md` still carries a "Root Cause Hypotheses" section whose PPS/backlight/S0ix ideas are already contradicted by the trace work (they are marked superseded, but they read like live options).

**How to avoid:**
- Make the ledger (below) the single source of truth and add it as a **blocking review gate** on every v8.0 phase plan: any step that matches a ledger row must cite new on-device evidence that invalidates the original disproof, or be rejected.
- Rewrite `COMMUNITY_FINDINGS.md` §4 so the superseded hypotheses are visibly struck, not just footnoted.
- Encode the ledger as a test (`scripts/test_pitfalls_ledger.sh` style) that greps phase plans for the banned levers. Precedent exists: the repo already has a trustworthy 36-script harness and a doc-parity guard.

**Warning signs:**
A phase plan or `RESEARCH`/`PLAN` doc contains any of: `panel_power_cycle_delay`, `exit_zero_cnt`, "force the GOP PPS", `MIMI_SEQ_POWER_OFF` in `pre_enable`, `glk_cold_boot`, "the resume skips the PHY reset", "keep the panel powered", "disable_protect", `/sys/.../reset`.

**Phase to address:**
P43 (create the gate), enforced at every later phase.

---

### Pitfall 2: A probe-style full display-core init trips the `assert_dmc_loaded` WARNING

**What goes wrong:**
Wanting to "do what the reload does", a patch forces a probe-style full init at resume, `intel_power_domains_init_hw(display, false)` on `82H0` in `intel_display_power.c`. Instead of a panel, this repeatedly emits `WARNING: display/intel_dmc.c:701 at assert_dmc_loaded+0x29b/0x470` and leaves the panel black. Upstream confirms the warning class is real: `assert_dmc_loaded()` observes parsed-but-not-yet-uploaded DMC state during async firmware load and fires a probe-time race WARNING (intel-gfx `[PATCH v3] drm/i915/dmc: fix assert_dmc_loaded WARN during async firmware load`, May 2026; Ubuntu SRU describes the same "~20% WARNING on ADL-N warm boot" race). It is not a firmware-upload failure and not a fix.

**Why it happens:**
`intel_power_domains_init_hw(display, false)` is the probe-time path; at resume the DMC is not guaranteed loaded at the moment the display core early-inits, so the assert is hit. The reload (probe) runs later in module init when DMC is up, so it does not hit it.

**How to avoid:**
- Do **not** force `intel_power_domains_init_hw(display, false)` on `82H0`. The display core and power wells are already torn down and re-initialised on every S3 (`bxt_display_core_uninit()` + `bxt_enable_dc9()` on suspend; `bxt_disable_dc9()` + `intel_power_domains_init_hw(true)` on resume). "The resume does not reset the PHY/power well" is false and is already disproven.
- If an experiment genuinely needs the probe-time path, gate it behind DMI **and** ensure the DMC is loaded first (wait on the firmware load), and keep it on a throwaway kernel with a live-USB recovery.
- Treat the WARNING as a red flag, not noise: if it appears, the experiment has left the supported path.

**Warning signs:**
`dmesg` shows `intel_dmc.c:701` / `assert_dmc_loaded` right after resume, with no panel. The phase claims "re-run probe init on resume" as the fix.

**Phase to address:**
P46 (deep resume-path RE), this is the exact trap a "make resume look like probe" fix falls into.

---

### Pitfall 3: Bare PCI reset / hot-remove bricks the box

**What goes wrong:**
Two related, both already observed on this hardware:
- Bare PCI reset, `echo 1 > /sys/bus/pci/devices/0000:00:02.0/reset`, does **not** recover the panel and makes it worse (panel fully off). A function-level reset of the IGD can hang the box.
- Hot-remove + rescan, `echo 1 > .../0000:00:02.0/remove` then a rescan, does **not** recover and **left the box hung**.

The only recovery that has ever worked is the i915 **unbind/bind** reload (`echo 0000:00:02.0 > .../i915/unbind; echo 0000:00:02.0 > .../i915/bind`).

**Why it happens:**
"Reset the device" sounds more surgical than unbind/bind, so it is the natural first attempt. But i915's PCI `.shutdown`/`.remove` and the IGD FLR touch the display/OpRegion and audio side in an order that is not safe at runtime; a bare reset can leave the device in D3 with no re-init.

**How to avoid:**
- Never hot-remove the GPU. Never issue a bare `/reset` on `0000:00:02.0`.
- Standardise on unbind/bind as the only recovery, and only from a context that can survive it (the shipped `scripts/d330-display-reload.sh` / sleep hook).
- Keep the recovery path itself reversible: a live USB and a known-good module always available before any device-level experiment.

**Warning signs:**
Any plan step that runs `echo 1 > .../reset` or `.../remove`. Any session without a live USB and a golden i915 module staged.

**Phase to address:**
P43 (ban it in the protocol), P47 (only unbind/bind ships).

---

### Pitfall 4: Flashing `G0CN14WW` (BROXTON VBT) wipes the MIPI sequence block

**What goes wrong:**
The newer `G0CN14WW` BIOS dump carries a VBT signed `$VBT BROXTON` with **no MIPI sequence block and no GPIO 144/145/160 anywhere**. The installed `G0CN12WW` VBT (`$VBT GEMINILAKE`) is the one that has the block (GPIO 144 power / 145 backlight / 160 reset/OTP, DCS `11/29/28/10`). Flashing `G0CN14WW` on Linux would remove the very sequence the driver executes and can brick/unboot the tablet; it is a Windows-path change, not a Linux fix.

**Why it happens:**
"Update the BIOS" is a common troubleshooting reflex, and G0CN14WW is *newer*. But the project's whole understanding of the panel power path is built on the GEMINILAKE VBT; the BROXTON VBT is a different platform profile.

**How to avoid:**
- Hard rule: **do not flash any BIOS on this unit.** Work only with binaries already extracted from the current flash (the `bios.bin` sha256 `7494…7C4B` dump and its `IntelGopDriver`).
- Before any firmware experiment, record the loaded VBT signature (`$VBT GEMINILAKE`) and confirm GPIO 144/145/160 are present in the block.
- If a future phase decides a BIOS update is required, that is a separate, explicitly-approved milestone with a known-good ROM backup and external flashing hardware, not a v8.0 step.

**Warning signs:**
A step that flashes, or extracts a VBT whose sig is `$VBT BROXTON`, or a VBT with no GPIO 144/145/160.

**Phase to address:**
P43 (ban), P45 (use the extracted GEMINILAKE VBT as the RE input only).

---

### Pitfall 5: Losing the only working recovery (bad module swap / source-tree confusion)

**What goes wrong:**
The on-device loop is: build `vlv_dsi.c` in `~/d330-kernel/linux-7.0.0` (a **tarball, no git**), `make -j2 M=drivers/gpu/drm/i915 modules`, `strip --strip-debug`, `zstd -19`, overwrite `/lib/modules/7.0.0-38-generic/.../i915.ko.zst`, `depmod -a`, `update-initramfs -u`, reboot. A wrong or half-built module overwrites the working driver; because the panel is DSI and cold boot depends on the GOP, a bad module can leave the box with no usable display and no way to fix it from the same device. `modprobe -r i915` is already blocked ("in use", ~28 refs), so in-place recovery is limited to unbind/bind. The stock source is only kept as `vlv_dsi.c.orig` next to the modified file.

**Why it happens:**
Incremental module-overwrite is the only practical loop and it is destructive. The source tree has no version control, so "restore the stock file" depends on a manual `.orig` copy.

**How to avoid:**
- Stage every experimental module under a distinct name/version and keep a **golden** `i915.ko.zst` (the clean `7.0.14-d330-fix` / `7.0.0-38-generic` build) copied off-device before any swap.
- Keep a live USB bootable, and record the exact commands to restore the golden module from it.
- Put the tablet source tree under git (or at minimum checksum `vlv_dsi.c.orig` and the stock tree) so "restore stock" is a command, not a memory.
- Record the built module `srcversion` (the clean one is `CE56CFE46EED334FE7C0674`) so you know which module is loaded.

**Warning signs:**
A rebuild with no golden-module backup staged; a session that overwrote `i915.ko.zst` before confirming the previous module still booted; no live USB in reach.

**Phase to address:**
P43 (golden module + live USB + git), enforced through P46–P47.

### Pitfall 6: Trusting the decompiler and the LLM as ground truth

**What goes wrong:**
Ghidra (or REA/Hopper/IDA) output plus a GLM 5.3 Flash narrative produces a confident, plausible RE story that is wrong. Classic modes: the decompiler recovers a wrong type for an MMIO access and silently folds a `base+offset` register into an opaque constant; inlined helpers are not recognised; jump tables mis-decode; `mov` to memory vs register is misread. The model then *explains* the wrong disassembly and a phase gets built on it. This is the highest-probability way v8.0 burns a whole phase on a phantom.

**Why it happens:**
`igdkmd64.sys` is large, stripped, and has no PDB; `IntelGopDriver` is a small PE32+ DXE driver but MMIO is written as literal addresses. Decompiled output is persuasive at a glance, and an LLM asked "what does this do?" will always answer.

**How to avoid:**
- Every RE claim must cite a **file + address + raw bytes**, and every register constant must be resolved against a trusted reference (`drivers/gpu/drm/i915/i915_reg.h`, Intel PRM, the Linux `vlv_dsi.c`/`intel_dsi_vbt.c` this project already knows).
- Prefer the **disassembler** for MMIO writes; use the decompiler for control flow only, and mark decompiler output as untrusted by default.
- Cross-check with a second engine (Ghidra **and** capstone/objdump via REA, or Hopper), the project already used capstone on the GOP.
- Annotate the DSI register bases (`0x6b000`, `0x6b800`, `0x6c000`, `0x162000`, `0x163000`, `0x138090`, `0xc7200`, `0x46000`) in the Ghidra project so `base+offset` reads are visible instead of folded.
- Forbid an LLM-authored RE conclusion from entering a phase plan without a raw-byte citation.

**Warning signs:**
An RE finding with no address; a "register" number that does not appear in `i915_reg.h`; a claim that the Windows driver does something the Linux DSI path has no analogue for, with no disassembly screenshot/bytes; two engines disagreeing and nobody noticing.

**Phase to address:**
P45 (Windows/GOP RE), P46 (resume-path RE), both must adopt the citation rule.

---

### Pitfall 7: Mis-attributing the GOP legacy PPS path as the missing step

**What goes wrong:**
`IntelGopDriver` writes the **legacy PPS** at `0xC7200`/`0xC7300` (`PP_CONTROL |= 8` `EDP_FORCE_VDD`, stall, then `|= 4` `EDP_BLC_ENABLE`). A natural RE conclusion is "the GOP powers the panel through the PPS and i915 never touches it, so replay the GOP's PPS writes". This is a dead end and is already disproven: that block is the **legacy eDP PPS**, not the DSI panel path; the PPS reads identical (`0x2`) cold vs resume; i915 ignores it; the GOP has no I2C/PMIC MMIO and no PMIC strings; and the actual panel power is the **VBT MIPI sequence** driving GPIO 144/145/160, which i915 *does* run.

**Why it happens:**
The PPS is the most eye-catching MMIO the GOP touches, and it is easy to conflate "eDP panel power sequencing" with "this DSI panel's power". They are different mechanisms on GLK.

**How to avoid:**
- Keep the two paths explicitly separate in the RE notes: legacy eDP PPS (`0xC7200`) is a red herring for this panel; the DSI VBT MIPI sequence (GPIO 144/145/160, DCS `11/29/28/10`) is the real one.
- Before proposing any GOP-sourced register write as a fix, re-read the cold/resume register diff: every host register is already identical, so no GOP-sourced *value* is missing.
- Record the PPS-identical evidence in the plan so the ledger gate can enforce it.

**Warning signs:**
A plan step "replay the GOP PPS / `PP_CONTROL` writes at resume"; a hypothesis that GOP uses a PMIC/i2c bus 6 (disproven: no Linux I2C client on bus 6, no GOP I2C/PMIC MMIO).

**Phase to address:**
P45 (GOP RE), P46 (resume-path RE).

---

### Pitfall 8: Wrong control experiment and phantom register evidence

**What goes wrong:**
Two evidence-integrity traps that produce false conclusions:
- Comparing **cold boot vs resume**. Cold boot never runs the DSI path (i915 fast-boots on GOP init), so a cold/resume register diff mixes "what the GOP did" with "what resume did". The correct control is **black resume vs working reload**.
- Reading CRTC state **minutes after resume**. The CRTC state is flaky after resume (`enable=yes` on some runs, `enable=no` on others), and KDE idle screen blanking turns the CRTC off. A reading taken without `systemd-inhibit --what=idle` (or read within seconds) is not evidence. The same trace work already had to correct a 6 s capture that made the sequence look truncated (it completes through `DISPLAY_ON`/`BACKLIGHT_ON` in an 18 s window).

**Why it happens:**
Cold boot is the easy diff and looks authoritative; the flaky CRTC readout is a moving target that rewards whoever reads first.

**How to avoid:**
- Standardise the protocol: black resume as the failing arm, working reload as the control arm; never present a cold-boot diff as the failing state.
- Always `systemd-inhibit --what=idle` (or read within seconds of resume); record the read latency with every register/CRTC capture.
- Take whole-window captures (the DSI sequence needs ~18 s to complete) and diff programmatically, not by eye.

**Warning signs:**
A "registers differ" table whose baseline is cold boot; CRTC dumps with no timestamp/inhibit noted; a conclusion drawn from a single short trace.

**Phase to address:**
P43 (protocol), P46 (the differential RE itself).

---

### Pitfall 9: Firmware extraction false positives and the wrong VBT binary

**What goes wrong:**
`binwalk`/`unblob` signature carving on a BIOS image produces bogus hits (nested LZMA, UEFI FFS sections mis-carved) and misses compressed FFS sections; and picking the wrong VBT (e.g. a `$VBT BROXTON` block from another region) poisons every downstream conclusion. The project's working method is deterministic instead of heuristic: parse the flash descriptor, walk the FV/FFS, dump the `IntelGopDriver` compressed section, carve the `MZ`/PE32+, then capstone. `IntelGopDriver` is a **PE32+** image, ~89 KB.

**Why it happens:**
Carving is one command and gives immediate output; it is tempting to skip the descriptor/FFS walk. And multiple VBT-looking blobs exist in a Lenovo image.

**How to avoid:**
- Use the FFS-aware path (`UEFITool` or the `uefi_firmware` Python flow already documented), not raw binwalk carving, for the GOP; if you use binwalk/unblob, require the carved blob to parse as PE32+ and to contain the `Intel(R) GOP Driver` / `MIPI` strings before trusting it.
- Verify the VBT signature (`$VBT GEMINILAKE`) and the presence of GPIO 144/145/160 before using it.
- Record the source image and sha256 (`bios.bin` = `74947A176B2973B5E944D98C479BA11369AEE55EFC76E67C8AE87DE58A7F7C4B`) with every extracted artefact.
- Note that firmware modules may be **TE (Terse Executable)**, which Ghidra does not auto-load; convert TE→PE or load with a fixed base and verify the entry point (see RE table).

**Warning signs:**
An extracted "driver" that does not parse as PE32+; a VBT sig that is not GEMINILAKE; Ghidra refusing to auto-analyse a section (likely TE); no sha256 provenance on the artefact.

**Phase to address:**
P45 (Windows/GOP RE).

---

## The Do-Not-Retry Ledger

**Binding.** Every row was tried (or exhausted) on this hardware, or is a named upstream/community dead end. Do not re-propose a row as a fix in v8.0. A phase plan may only revisit a row if it cites **new** on-device evidence that invalidates the original disproof.

### Disproven on-device (host register / quirk / state)

| # | Lever | Why it is dead | Evidence | Ban until |
|---|-------|----------------|----------|-----------|
| D1 | PPS / TCON power-cycle timing clamp (`intel_pps.c`), `panel_power_cycle_delay` | Wrong subsystem (legacy **eDP** PPS); VBT already reports a 500 ms cycle; legacy PPS `0xc7204` reads identical (`0x2`) cold vs resume; i915's GLK-DSI path never touches it | `DISPLAY_RESUME_CCS_MODIFIER.md` | New evidence PPS differs resume vs reload |
| D2 | D-PHY `exit_zero_cnt` quirk; `HS_TX_TIMEOUT` retuning | No effect; registers forced live on the black state, panel stayed black | `DISPLAY_RESUME_CCS_MODIFIER.md` |, |
| D3 | DSI-SoC register mismatch vs GOP (force the full cold register diff live) | The full cold/resume diff was written live with no effect | `DISPLAY_RESUME_CCS_MODIFIER.md` §"Exhaustive register comparison" |, |
| D4 | `CDCLK_CTL` (`0x46000`) and DSI-PHY (`0x160018`) value mismatch | Written live on the black state, no effect; `i915_cdclk_info` reports `158400 kHz` both | `DISPLAY_RESUME_CCS_MODIFIER.md`; `DSI_RESUME_TRACE_ANALYSIS.md` |, |
| D5 | DCS re-send after video enable | No effect | `DISPLAY_RESUME_CCS_MODIFIER.md` |, |
| D6 | DSI regulator / MIPI-IO power (`0x138090`/`0x160020`/`0x160054`/`0x46080`/`0x161000`), `BXT_P_DSI_REGULATOR_CFG` bit15 | `broxton`-only block in `vlv_dsi.c` is skipped on GLK, does not stick | `DISPLAY_RESUME_CCS_MODIFIER.md` |, |
| D7 | Suspend depth (`deep` S3 vs `s2idle`) | Both resume black | `DISPLAY_RESUME_CCS_MODIFIER.md` |, |
| D8 | "Keep the panel powered across suspend" (early-return from `intel_dsi_post_disable`) | Still black, the panel does not survive S3 even when i915 leaves it alone | `DISPLAY_RESUME_CCS_MODIFIER.md` |, |
| D9 | A PMIC on I2C bus 6 that GOP programs and i915 does not | No Linux I2C client on bus 6; GOP has no I2C/PMIC MMIO or string | `DISPLAY_RESUME_CCS_MODIFIER.md` |, |
| D10 | `modprobe -r i915` after resume | Blocked, module "in use" (~28 refs); superseded by unbind/bind | `DISPLAY_RESUME_CCS_MODIFIER.md` |, |
| D11 | `glk_cold_boot` ordering forced to `0` on `82H0` | Correlate, not cause; resume still black; only host diff from reload | `DISPLAY_RESUME_CCS_MODIFIER.md`; `DSI_RESUME_TRACE_ANALYSIS.md` |, |
| D12 | Forcing probe-style full display-core init (`intel_power_domains_init_hw(display, false)`) | Trips `intel_dmc.c:701 assert_dmc_loaded` WARNING, no panel; core already power-cycled by S3 | `DISPLAY_RESUME_CCS_MODIFIER.md`; `DSI_RESUME_TRACE_ANALYSIS.md`; upstream DMC patch |, |
| D13 | `drm.debug` / dyndbg tracing of the i915 display path | Writes accepted, **zero** `[drm:...]` lines land; `dynamic_debug/control` has no `vlv_dsi` sites | `DISPLAY_RESUME_CCS_MODIFIER.md`; `DSI_RESUME_TRACE_ANALYSIS.md` |, |
| D14 | Bare PCI reset (`echo 1 > .../0000:00:02.0/reset`) | Does not recover; makes the panel worse (fully off) | `DISPLAY_RESUME_CCS_MODIFIER.md` |, (permanent; see Pitfall 3) |
| D15 | PCI remove + rescan of `0000:00:02.0` | Does not recover; left the box hung | `DISPLAY_RESUME_CCS_MODIFIER.md` |, (permanent; see Pitfall 3) |
| D16 | DSI panel power-cycle patch in `pre_enable` (`ASSERT_RESET` + `POWER_OFF` before `wait_panel_power_cycle`) | Made it worse: DCS over a not-ready link, modeset fails, CRTC left disabled (`enable=no`); patch deleted | `DSI_RESUME_TRACE_ANALYSIS.md` §"Disproven patch" |, |
| D17 | `msleep(300)` after `MIPI_SEQ_POWER_ON` | No effect | `DISPLAY_RESUME_CCS_MODIFIER.md` |, |
| D18 | "The resume fastsets and skips the modeset / never runs `pre_enable`" | False: `post_disable` runs on suspend, `pre_enable` on resume (compositor-driven); cold boot runs neither | `DISPLAY_RESUME_CCS_MODIFIER.md`; `DSI_RESUME_TRACE_ANALYSIS.md` |, |
| D19 | "The resume does not reset the PHY / power well" | False: full `bxt_display_core_uninit`/`bxt_enable_dc9` → `bxt_disable_dc9`/init on every S3 | `DSI_RESUME_TRACE_ANALYSIS.md` |, |
| D20 | "i915 has no panel-power/backlight GPIO on GLK, so it cannot be the panel path" | False: `intel_dsi->gpio_panel` is NULL, but the VBT MIPI sequence drives GPIO 144/145/160 identically resume vs reload | `DSI_RESUME_TRACE_ANALYSIS.md` |, |
| D21 | KWin re-applying the rotation after resume | Does not bring the image back | `DISPLAY_RESUME_CCS_MODIFIER.md` |, |
| D22 | CCS-modifier rejection as the *resume* cause | CCS rejection was real but a **separate, fixed** bug; the resume-black persists after the fix | `DISPLAY_RESUME_CCS_MODIFIER.md` §Cause 1 |, (already fixed; do not re-fix) |

### Superseded pre-tracing hypotheses (community, not on-device-disproven)

These come from `COMMUNITY_FINDINGS.md` §4 and the community repo. They are not fixes for the DSI path and were written before tracing. Treat as dead unless a phase produces new evidence.

| # | Community lever | Status / why it does not apply |
|---|-----------------|-------------------------------|
| C1 | Mask `sleep.target` / `suspend.target` etc. | Workaround, not a fix; causes battery drain/thermal (v6.0 already replaced this class of hack). |
| C2 | X11 `xrandr --off` + re-mode reset script (`lenovod330-refreshscreen.sh`) | X11-only (fails on Wayland/Plymouth/early console); a full modeset, which is exactly the path already shown insufficient. |
| C3 | `video=efifb:nobgrt`, `fbcon=nodefer` | Boot-logo/fbcon tuning; unrelated to the DSI resume link; no evidence it changes resume. |
| C4 | `i915.enable_psr=0`, `i915.enable_fbc=0` | PSR/FBC are **eDP** features; a DSI panel does not negotiate PSR. Conceptually inapplicable; not on-device-tested, so do not claim it as the fix. |
| C5 | `i915.enable_dpcd_backlight=0` | eDP DPCD backlight; this panel is DSI with VBT GPIO 145 backlight. Inapplicable. |
| C6 | "S0ix Modern Standby vs S3 mismatch" | Covered by D7 (both depths black). |
| C7 | ACPI namespace clashes (`\_SB.PCI0.RP04` `AE_ALREADY_EXISTS`) cause the resume failure | The PCI unbind/bind reload fixes the panel with **no** ACPI change; the iGPU's DSI path is not `RP04`. Not the cause of the black resume. |
| C8 | Panel PPS `t11_t12` too short / backlight-before-VDD ordering | Superseded by D1 + the full MIPI-sequence trace (backlight enable is part of the correct dispatched sequence). |

### Community / upstream dead ends (investigated, will not yield the fix)

| # | Source | What it is | Why it is a dead end here |
|---|--------|-----------|---------------------------|
| U1 | dri-devel, `[BUG] Lenovo D330-10IGL: Blank screen issues with DSI display on Gemini Lake` (Lucas Moreno, 2025-09-04; Jani Nikula reply 2025-09-09) | The exact hardware reported upstream: blank on boot, **failure to resume from suspend on both X11 and Wayland**, blank on rotation (X11). | Jani Nikula did **not** engage with the bug; he asked for it to be filed in the i915 GitLab tracker. No upstream fix resulted. Do not expect upstream to hold the answer; file correctly (P44) but proceed independently. |
| U2 | freedesktop bug 101205 `[i915] [BYT] Blank screen on DSI panel` | Bay Trail DSI blank screen. | Different platform (BYT `vlv_dsi` SoC DSI, not GLK); not this code path. |
| U3 | `dascenci/n100-dsi-blackscreen-fix` | Alder Lake N100 DSI blackscreen at boot (minilaptops); uses VBT/panel-timing style fixes (`hback porch < 16 pixels`). | Different platform; the *pattern* (VBT/panel timing) is informative, but the D330 resume bug is not a boot-time timing rejection. |
| U4 | `ansulev/meteor-lake-suspend-fix`, `i915-suspend-fix` (Creatomat) | Meteor Lake eDP PSR2 wedges the PHY on resume; fixes via `i915.enable_psr=0` / `enable_psr2_sel_fetch=0`; Creatomat ships a systemd **sleep hook** that reloads/round-trips the driver. | PSR is eDP, not DSI (C4). The Creatomat hook corroborates only that the community's last resort for "panel dead after resume" is a driver reload, the same class as our fallback. |
| U5 | Red Hat bugzilla 1506879 "Restoring old state failed with -22", 2127540 i915 suspend/resume failure | Generic i915 resume failures. | Our atomic commit **succeeds** (`skl_plane_check` errors `0`); not the same signature. Useful only as a contrast. |
| U6 | intel-gfx `[PATCH v3] drm/i915/dmc: fix assert_dmc_loaded WARN during async firmware load` (May 2026); Ubuntu SRU ADL-N warm-boot WARNING | Confirms `intel_dmc.c` `assert_dmc_loaded` fires as a probe-time race during async DMC firmware load. | Confirms D12 is a known warning class, **not** a fix. Pulling in this upstream patch does not make the DSI panel resume. |
| U7 | CVE-2026-31540 (i915 NULL-pointer deref on suspend when required firmware is missing) | A missing i915 firmware + suspend triggers an unchecked call. | Not the D330 bug, but a reminder: keep DMC/GuC firmware present and matching the module; do not test with firmware stripped. |

## RE-Specific Pitfalls (Ghidra + REA + GLM 5.3 Flash)

| # | Pitfall | Warning sign | Prevention | Phase |
|---|---------|--------------|------------|-------|
| R1 | **Decompiler false positives / LLM hallucination.** Wrong types, folded `base+offset` MMIO, unrecognised inlines, mis-decoded jump tables. The model then explains the wrong output confidently. | A "finding" with no raw address/bytes; a register that is not in `i915_reg.h`; two engines disagreeing. | Cite file+address+bytes for every claim; resolve constants against `i915_reg.h`/PRM; disassembler for MMIO, decompiler for control flow; cross-check with a second engine; block RE claims from phase plans without citations. | P45, P46 |
| R2 | **Mis-attributing the legacy GOP PPS path** (`0xC7200`) as the missing power step. | Plan says "replay `PP_CONTROL`/GOP PPS at resume"; talks about a bus-6 PMIC. | Keep eDP PPS and the DSI VBT GPIO path separate; re-read the identical register diff first (D1, D3). | P45, P46 |
| R3 | **Firmware extraction false positives** (binwalk/unblob carve garbage; miss compressed FFS). | Carved blob is not PE32+ or lacks `Intel(R) GOP Driver`/`MIPI`; no sha256 provenance. | Use the flash-descriptor → FV/FFS → `uefi_firmware`/UEFITool flow; validate the PE; pin the source image sha256. | P45 |
| R4 | **Wrong / stale VBT binary.** A `$VBT BROXTON` block (or a different region's VBT) has no MIPI sequence and no GPIO 144/145/160. | VBT sig ≠ `$VBT GEMINILAKE`; GPIO 144/145/160 absent. | Always verify sig + GPIO presence before use; RE against the GEMINILAKE VBT from the current flash only. | P45 |
| R5 | **Confusing legacy PPS `0xC7200` with the DSI VBT path.** | Same as R2. | Document the two register blocks side by side in the RE notes. | P45, P46 |
| R6 | **Ghidra will not auto-load TE images / wrong load base.** UEFI firmware modules may be Terse Executables, not PE. | Ghidra fails to auto-analyse a section; entry point looks bogus. | Convert TE→PE or load with a fixed base; verify entry + a known string; for the GOP, the carved `MZ`/PE32+ path already works with capstone. | P45 |
| R7 | **Assuming the Windows `.sys` mirrors the Linux DSI structure.** `igdkmd64.sys` is stripped, no PDB; the GLK DSI encoder may be in a separate module or reachable only via the GOP at boot. | A hypothesis that the `.sys` contains a named `intel_dsi_pre_enable` equivalent with no evidence. | Use strings + MMIO-address cross-referencing (`0x6b000`, `0x162000`, `0xc7200`) to locate candidate functions (REA helps); treat structure guesses as unproven. | P45 |
| R8 | **Scope explosion.** RE of a very large stripped `.sys` can eat the milestone with no deliverable. | Phase tasks with no stop condition; "analyse the whole driver". | Bound the RE: specific MMIO addresses + the resume-path call graph; time-box; the GOP is small (~89 KB) and should be done first. | P45 |
| R9 | **Wrong base register window for old-vs-new register offsets.** GLK vs Broxton vs SKL share names; `vlv_dsi.c` skips `broxton`-only blocks on GLK. | Patching a register that "does not stick" (D6); using a BXT-only define on GLK. | Always confirm the platform guard (`IS_GEMINILAKE`/`IS_BROXTON`) before treating a register as live. | P46 |
| R10 | **Treating a decompiler constant as a register when it is a pointer/loop bound.** | The proposed "register" changes with a local variable. | Validate by tracing reads/writes across the function; confirm it hits the MMIO access primitive. | P45, P46 |

### RE evidence-integrity rules (adopt in P45 and keep through P48)

- Never present a register value as evidence unless it came from a raw MMIO read (`intel_reg read --count=<decimal> <base>`) or a `i915_reg_rw` ftrace line, with the range and tool recorded.
- Never present a decompiled control-flow claim without the address and either raw bytes or a second engine's agreement.
- Record the source hash for every binary (`bios.bin` = `7494…7C4B`; GOP PE32+; any carved section).
- Record the loaded module `srcversion` and the exact kernel/`uname -r` for every experiment.

---

## Technical Debt Patterns

| Shortcut | Immediate benefit | Long-term cost | When acceptable |
|----------|-------------------|----------------|-----------------|
| Ship the i915 unbind/bind reload (sleep hook + `scripts/d330-display-reload.sh`) as the "fix" | Restores the panel on every resume | Dirty: `i915_pci_remove` → `drm_mode_config_cleanup` warns on the compositor's framebuffer; DRM re-registers on a **new card node**; not a kernel fix; breaks "invisible recovery" until the compositor is restarted | Acceptable **only** as the documented fallback while a real fix is pursued (PROJECT.md explicitly allows it as the bar if a clean fix is impossible). Must not be described as a driver fix. |
| Overwrite the installed `i915.ko.zst` for every experiment | Fast on-device loop | One bad module = unbootable panel; only a live USB recovers | Acceptable with a golden module staged off-device and a live USB present (P43). Never without. |
| Keep `vlv_dsi.c` stock only as `vlv_dsi.c.orig` in an untracked tarball tree | No git setup | "Restore stock" depends on a manual copy; easy to lose the baseline | Never in v8.0, put the tree under git or checksum it first (Pitfall 5). |
| Compare against cold boot because it is convenient | One command | Poisoned baseline (cold boot never runs the DSI path) | Never (Pitfall 8). |
| Test with a short trace window | Fast capture | Truncated DSI sequence looks like a bug (already caused one wrong conclusion) | Never, capture the full ~18 s window (Pitfall 8). |

## Integration Gotchas

| Integration | Common mistake | Correct approach |
|-------------|----------------|------------------|
| systemd `system-sleep` hook (auto-reload) | Reloading while the compositor holds the framebuffer leaves the FB warning and a new card node, breaking KWin | Stop/restart the compositor around the reload, or accept and document the warning; keep the hook DMI-gated to `82H0`. |
| KWin Wayland modeset | Assuming i915's own resume re-inits the DSI encoder, it does not; the compositor's commit does it ~3 s later | Design any resume-path experiment around the compositor commit; test the no-compositor case separately (`systemctl stop sddm`, console on the GPU). |
| `intel_reg` tool | `--count=N` takes **decimal**; `intel_reg dump` mis-decodes GLK pipe regs as `0`; writes go to **stderr** | Pass decimal counts; dump each range explicitly by base+count; capture stderr. |
| `drm.debug` / dyndbg | Expecting `[drm:...]` lines, they never land on this box (D13) | Use unconditional `pr_err` markers compiled into the module; remove them before shipping. |
| i915 firmware (DMC/GuC) | Testing with firmware stripped/missing → can crash on suspend (CVE-2026-31540) | Keep matching firmware in `/lib/firmware/i915`; verify it loads before suspend tests. |
| VBT/BIOS | Flashing a newer BIOS to "refresh the VBT" | Never flash; extract and read the current GEMINILAKE VBT only (Pitfall 4). |

## "Looks Done But Isn't" Checklist

- [ ] **Ledger enforced:** every v8.0 phase plan is grepped against the Do-Not-Retry Ledger; no banned lever appears without new evidence.
- [ ] **Control arm correct:** all "registers differ" evidence uses black resume vs working reload, never cold boot.
- [ ] **Capture window complete:** DSI sequence captured over the full window (≥18 s), not truncated.
- [ ] **CRTC readout valid:** read within seconds of resume or under `systemd-inhibit --what=idle`, with the latency recorded.
- [ ] **Safety kit present:** live USB + golden `i915.ko.zst` + current VBT/GOP dump, staged before any device experiment.
- [ ] **No bare reset / hot-remove:** the only device recovery used is i915 unbind/bind.
- [ ] **No BIOS flash:** the loaded VBT is confirmed `$VBT GEMINILAKE` with GPIO 144/145/160; nothing was flashed.
- [ ] **RE citations:** every RE claim carries file+address+bytes, cross-checked against `i915_reg.h`/PRM and where possible a second engine.
- [ ] **Fallback honest:** if the reload ships, it is labelled a recovery, not a fix, and the compositor/card-node side effects are documented.
- [ ] **No regression:** cold boot, touch (Goodix + wake-reset hook), audio, and the shipped v1–v7 tools still work after the change.

## Recovery Strategies

| Pitfall | Recovery cost | Recovery steps |
|---------|---------------|----------------|
| Re-trod a disproven lever | LOW–HIGH (hardware time) | Revert the experimental module to the golden build; record the re-confirmation in the ledger; tighten the gate. |
| `assert_dmc_loaded` WARNING (D12) | LOW | Revert the patch; the core is already power-cycled by S3, do not force probe init. |
| Bare reset / hot-remove hung the box | HIGH | Power-cycle the tablet; if PCI is wedged, cold boot from the live USB and restore the golden module. Never retry the reset. |
| Bad module overwrote the working driver | HIGH | Boot live USB, restore the golden `i915.ko.zst`, `depmod -a`, `update-initramfs -u`, reboot. |
| Accidental BIOS flash (Pitfall 4) | HIGH (possibly brick) | External flash of the known-good ROM backup; do not attempt on-device recovery. (Prevented by the no-flash rule.) |
| Wrong-control conclusion (Pitfall 8) | MEDIUM | Re-run with the reload as control under inhibit; discard the cold-boot diff. |
| Phantom RE finding (Pitfall 6) | MEDIUM | Re-derive from raw bytes; cross-check a second engine; annotate register bases. |
| Dirty reload broke KWin (card node) | LOW–MEDIUM | Restart the compositor; accept the new card node; document it; keep the hook DMI-gated. |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention phase | Verification |
|---------|------------------|--------------|
| Ledger re-tread (P1) | P43 | Ledger test greps phase plans; zero banned levers with no new evidence |
| `assert_dmc_loaded` probe-init (P2) | P46 | `dmesg` after resume has no `intel_dmc.c:701` WARNING |
| PCI reset / hot-remove (P3) | P43, P47 | Protocol doc + hook use unbind/bind only; box survives each experiment |
| BIOS `G0CN14WW` flash (P4) | P43, P45 | Loaded VBT sig `$VBT GEMINILAKE` with GPIO 144/145/160; no flash performed |
| Losing recovery / bad module (P5) | P43 → P47 | Golden module + live USB staged; `srcversion` recorded per experiment |
| Decompiler/LLM false positive (P6) | P45, P46 | Every RE claim has file+address+bytes; second-engine cross-check |
| GOP legacy PPS mis-attribution (P7) | P45, P46 | No PPS-replay step; eDP PPS vs DSI VBT documented separately |
| Wrong control / phantom evidence (P8) | P43, P46 | Reload is the control arm; captures ≥18 s; inhibit recorded |
| Firmware extraction / wrong VBT (P9) | P45 | Carved artefact parses as PE32+; VBT sig + GPIO verified; sha256 pinned |
| RE-specific R1–R10 | P45, P46 | Adopt the RE evidence-integrity rules; review gate on RE claims |
| Dirty reload shipped as a fix | P47, P48 | Fallback labelled a recovery; compositor/card-node effects documented and tested |
| Regression in shipped features | P48 | Cold boot + touch + audio + v1–v7 tool smoke tests pass |

## Sources

**Project docs (primary, on-device evidence):**
- `docs/research/DISPLAY_RESUME_CCS_MODIFIER.md` (canonical disproven-theories list, VBT/flash warning, GOP RE, reload fallback)
- `docs/research/DSI_RESUME_TRACE_ANALYSIS.md` (`i915_reg_rw` trace, `pr_err` markers, control/method caveats)
- `docs/research/COMMUNITY_FINDINGS.md` (prior art, superseded hypotheses, ACPI/boot-param community flags)
- `.planning/PROJECT.md` (v8.0 goal and scope)

**Upstream / community (web):**
- dri-devel: `[BUG] Lenovo D330-10IGL: Blank screen issues with DSI display on Gemini Lake`, Lucas Moreno, 2025-09-04 (`lists.freedesktop.org/archives/dri-devel/2025-September/523851.html`); Jani Nikula reply, 2025-09-09 (`.../524205.html`), filed, no fix; redirected to the i915 tracker. (Confidence: HIGH.)
- Intel docs: `How to File i915 and xe Bugs` (`drm.pages.freedesktop.org/intel-docs/how-to-file-i915-bugs.html`), the correct track is the drm/i915 GitLab issue tracker, with `drm.debug=0xe log_buf_len=4M ignore_loglevel` + full dmesg. `How to Debug Suspend-Resume Issues` and `How to Dump Registers` are placeholders pointing at Intel developer docs. (Confidence: HIGH.)
- intel-gfx: `[PATCH v3] drm/i915/dmc: fix assert_dmc_loaded WARN during async firmware load`, May 2026 (`lists.freedesktop.org/archives/intel-gfx/2026-May/390843.html`); Ubuntu kernel-team SRU describing the ~20% ADL-N warm-boot WARNING race (`lists.ubuntu.com/archives/kernel-team/2026-August/171336.html`), corroborates D12. (Confidence: MEDIUM, secondary sources.)
- freedesktop bug 101205 `[i915] [BYT] Blank screen on DSI panel` (different platform). Red Hat bugzilla 1506879 / 2127540 (contrasting generic resume failures). (Confidence: MEDIUM.)
- GitHub: `dascenci/n100-dsi-blackscreen-fix` (Alder Lake), `Creatomat/i915-suspend-fix`, `ansulev/meteor-lake-suspend-fix` (Meteor Lake PSR2), neighbour platforms, not this code path. (Confidence: MEDIUM.)
- CVE-2026-31540 (i915 NULL-pointer deref on suspend with missing firmware), keep firmware present. (Confidence: LOW–MEDIUM, secondary.)

---
*Pitfalls research for: Lenovo IdeaPad D330-10IGL (82H0, GLK/i915) DSI resume black screen, v8.0 deep-RE milestone*
*Researched: 2026-10-12*
