# Feature Research: i915 GLK/Broxton MIPI-DSI resume recovery (Lenovo D330-10IGL, 82H0)

**Domain:** Linux kernel display driver (i915) system-suspend/resume for a Gemini Lake (GLK) MIPI-DSI panel
**Researched:** 2026-10-12
**Confidence:** MEDIUM-HIGH for the resume-vs-reload mechanism (read from current mainline source);
MEDIUM for the avenue ranking (grounded in the on-device trace evidence in `docs/research/` + the
sources below, but not yet proven on hardware).

This file is the v8.0 "candidate fix avenues" deliverable. It is written in the FEATURES.md
schema (table stakes / differentiators / anti-features / dependencies / MVP / prioritisation)
because the downstream consumer is roadmap phase goals and success criteria.

---

## How the resume path and the reload actually differ (grounded in source)

This answers the milestone question "what state does the reload reconstruct that resume does not?"
It is the load-bearing section; every avenue below hangs off it.

### The two call chains (current mainline `torvalds/linux`, HIGH confidence)

Suspend (S3), for GLK:

```
i915_drm_suspend
  -> intel_display_driver_pm_suspend        (drm_atomic_helper_suspend() saves the SW state)
  -> intel_display_driver_pm_suspend_late
  -> intel_display_power_suspend_late
  -> intel_power_domains_suspend
       -> bxt_display_core_uninit()          (gen9_disable_dc_states, dbuf off, cdclk uninit, PW1 off)
  -> bxt_enable_dc9()                        (GLK uses DC9 for S3)
```

Resume (S3), for GLK:

```
intel_display_driver_pm_resume
  -> intel_display_power_resume_early
       -> gen9_sanitize_dc_state() ; bxt_disable_dc9()
       -> intel_power_domains_resume
            -> __intel_display_power_init_hw(display, resume=true)
                 -> bxt_display_core_init(display, resume=true)
                      -> ... -> if (resume) intel_dmc_load_program(display)   // DMC reloaded HERE
  -> __intel_display_driver_resume
       -> intel_modeset_setup_hw_state()      // readout + sanitize (SAME fn the reload uses)
       -> force crtc_state->mode_changed = true on the duplicated state
       -> drm_atomic_helper_commit_duplicated_state()
```

Reload (PCI unbind/bind):

```
i915_pci_remove
  -> intel_display_driver_remove ... intel_display_driver_remove_noirq
       -> intel_mode_config_cleanup()
  -> drm_atomic_helper_shutdown()             // FULL disable: intel_dsi_disable + intel_dsi_post_disable
                                              //   SHUTDOWN packet, glk_dsi_clear_device_ready (LP-00),
                                              //   bxt_dsi_pll_disable, VBT ASSERT_RESET + POWER_OFF
  -> intel_display_power_driver_remove()
i915_pci_probe
  -> intel_display_power_init_hw -> __intel_display_power_init_hw(resume=false) -> bxt_display_core_init
  -> intel_dmc_init() -> intel_dmc_load_program()      // DMC loaded at PROBE time
  -> intel_modeset_setup_hw_state()                    // readout + sanitize
  -> intel_initial_commit()                            // a REAL commit (not the duplicated state)
```

Both paths call `intel_modeset_setup_hw_state()`. The prior note in
`DISPLAY_RESUME_CCS_MODIFIER.md` ("resume doesn't call it, reload does") is therefore imprecise on
the current tree, but the *conclusion* survives: the two paths hand the atomic core a different
starting state.

### What the reload reconstructs that resume does not (the deltas)

1. **A completed DSI teardown before re-init.** `drm_atomic_helper_shutdown()` runs the disable half
   of the modeset on the encoder: `intel_dsi_disable()` (VBT `BACKLIGHT_OFF`, `DISPLAY_OFF`, SHUTDOWN
   packet) and `intel_dsi_post_disable()` (`glk_dsi_clear_device_ready()` → ULPS + LP-00 +
   `MIPI_DEVICE_READY=0`, `bxt_dsi_pll_disable()`, VBT `ASSERT_RESET`+`POWER_OFF`). Resume does **not**
   do this when the readout reports the encoder active — it reuses the pre-suspend state.
2. **A display-core init from `POWER_DOMAIN_INIT` on a torn-down core** (`bxt_display_core_init` run
   with `display_core_suspended=false` semantics and a fresh `intel_dmc_init`), versus resume's
   `bxt_disable_dc9()` + DC9-restored state. The display core *is* power-cycled on S3 in both cases
   (S3 uninit/DC9), so this is a state-provenance difference, not a "well was never reset" difference.
3. **A fresh encoder object with fresh VBT-derived config, committed through `intel_initial_commit()`
   rather than through `drm_atomic_helper_commit_duplicated_state()` on the duplicated pre-suspend
   state.**
4. **DMC program load timing.** Probe loads DMC during `intel_dmc_init()`; resume loads it inside
   `bxt_display_core_init(resume=true)`. Both load it. This is why the disproven "force
   `intel_power_domains_init_hw(display,false)` at resume" experiment trips
   `WARNING ... intel_dmc.c:701 assert_dmc_loaded` — `resume=false` *skips* `intel_dmc_load_program`,
   it is not a "more complete init".

### The single most diagnostic on-device fact

With no compositor running, the resume trace buffer is **empty** (`entries-written=0`) — i915 issues
**no** DSI/pipe writes at all — and the panel is black. i915's readout believes the DSI encoder is
still enabled (registers survived via DC9), so it reuses the stale state and never re-initialises the
link. That is a **readout / state-provenance** failure, not a `pre_enable()` failure. The compositor's
commit ~3 s later does reach `pre_enable` (full cold sequence, correct GPIOs) but by then the link was
re-enabled without the disable half, and the panel stays black.

### `glk_cold_boot` is correct-by-design, not the bug

`glk_cold_boot` exists precisely to make S3/S4 resume work. Commit `8a1deb329ffb`
("drm/i915/glk: Add cold boot sequence for GLK DSI", 2017-06-13, HIGH confidence):

> As per BSEPC, if device ready bit is '0' in enable IO sequence then its a cold boot/reset scenario
> eg: S3/S4 resume. If cold boot scenario detected in enable IO, then prepare port immediately. In
> normal boot scenario, prepare port after `glk_dsi_device_ready()`. Without cold boot sequence
> enabled, features like S3/S4 doesn't work.

The D330 resume hits `glk_cold_boot=1` (DEVICE_READY read `0x0`) — the *correct* S3 path. The reload
hits `0`. So `glk_cold_boot` is a correlate, confirmed by the on-device forcing experiment.

### Dual-link DSI is a real configuration here

`intel_dsi_init()` sets `intel_dsi->ports = BIT(PORT_A) | BIT(PORT_C)` whenever the VBT reports
`connector->panel.vbt.dsi.config->dual_link`. The working reload trace programs **both** D-PHY port A
(`0x1620xx`) and port C (`0x1630xx`), which strongly indicates a dual-link panel (confirm by decoding
the VBT `$VBT GEMINILAKE` block). This matters because upstream explicitly does **not** support
dual-link DSI on BXT/GLK: the revert commit `abeae421b03d` ("Revert drm/i915/bxt: Disable device ready
before shutdown command") states *"As of now, dual link is not supported and will need some rework in
the upstream code."* If the D330 is dual-link, both the enable and the disable sequences are in
under-tested territory.

---

## Feature Landscape

### Table Stakes (must ship; the milestone fails without these)

| Feature (avenue) | Why expected / necessary | Complexity | Notes |
|---------|--------------|------------|-------|
| **A. Forced DSI teardown before re-enable on GLK-DSI resume** | Every other avenue is a dead end; this reproduces the one thing the reload does that resume does not (the disable half). Directly answers the empty-trace "no writes on resume" signal. | MEDIUM | DMI-gated (`82H0`): after `intel_modeset_setup_hw_state()` on resume, drive the encoder through `intel_dsi_disable()`+`intel_dsi_post_disable()` (or at minimum `glk_dsi_clear_device_ready()` → LP-00 + `MIPI_DEVICE_READY=0` + `bxt_dsi_pll_disable()` + VBT `ASSERT_RESET`/`POWER_OFF`) so the subsequent enable is a real disable→enable. Reuses `intel_sanitize_encoder()`'s existing "resume register restoring … disable the encoder manually again" pattern — it simply does not fire for DSI because `get_hw_state`/readout reports active. |
| **B. Make the resume readout honest for the DSI encoder** | Same root as A, at the state level: force the DSI encoder/CRTC to be treated as inactive so the atomic commit performs a full modeset (not fastset). | MEDIUM | Quirk in `intel_modeset_setup_hw_state()` / `intel_sanitize_encoder()` / `intel_dsi_get_hw_state()` for `82H0`, or a DSI `encoder.sync_state` hook that clears `MIPI_DEVICE_READY`. A-only implementations may be enough; A+B is the robust form. |
| **C. Backlight resume fix (independent, second bug)** | Panel comes back **backlit-and-blank** only after manually writing `brightness`; resume leaves `bl_power=4`, `actual_brightness=0` while `brightness=640`. Without this, even a fixed link is dark. | LOW | Fix in the backlight resume path (or a `system-sleep` write of the saved brightness). Interacts with the existing `tools/d330-ctl` / PWM work from v3.0. |
| **D. Seamless automatic recovery fallback** | PROJECT.md explicitly accepts "invisible reload/compositor restart" as a valid bar. The reload is the only *proven* recovery. | MEDIUM | The shipped `system-sleep` hook already runs the reload; the gap is making it seamless (no dirty `drm_mode_config_cleanup` WARN, no card re-registration visible to the compositor). Do this **regardless** of whether A/B land. |
| **E. One consolidated "tried / disproven" ledger** | Milestone feature in PROJECT.md; prevents re-treading the disproven list below. | LOW | Merge `DISPLAY_RESUME_CCS_MODIFIER.md` + `DSI_RESUME_TRACE_ANALYSIS.md` + the new RE findings into one canonical table. |
| **F. Upstream filing + mainline test** | The bug is a known upstream gap (see below); a fix must be proposed, and a mainline kernel may already carry a partial fix. | LOW | File at `https://drm.pages.freedesktop.org/intel-docs/how-to-file-i915-bugs.html` (Jani Nikula's explicit instruction in the dri-devel thread). Test a 6.17+ kernel. |

**Upstream-open signal (MEDIUM-HIGH confidence):** the i915 CI regression list
`drivers/gpu/drm/ci/xfails/i915-glk-skips.txt` begins with
`# Suspend to RAM seems to be broken on this machine` / `.*suspend.*` — i.e. GLK S3 is a
*known-broken, deliberately-skipped* configuration upstream. This reframes the task from "our
misconfiguration" to "documented driver gap", and is the strongest justification for A/B/C.

### Differentiators (where this milestone's unique research pays off)

| Feature (avenue) | Value proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **G. Windows `igdkmd64.sys` D3→D0 differential (RE)** | The only source that can reveal a vendor step i915 omits; v8.0 already funds Ghidra/REA. | HIGH | Decompile `igdkmd64.sys` and `IntelGopDriver` to find the actual `DxgkDdiSetPowerState`/D3→D0 display callback and the DSI/PHY/PLL/panel re-init it performs. The existing `docs/windows_analysis/RESUME_SEQUENCE.md` is **superseded**; mine it only for the WDDM/GOP background (its PPS/`t11-t12` timing premise is wrong: the panel is MIPI-DSI, the VBT reports a 500 ms power cycle, and PPS reads identical cold vs resume). Treat `PanelPowerCycleDelay=500`, `FeatureTestControl=0x9240` (PSR off) as unverified legacy claims until the RE confirms them. |
| **H. Dual-link DSI teardown correction** | If the panel is dual-link, upstream's own comment says the sequences need rework; a corrected `disable` (device-ready handling + SHUTDOWN ordering) may be the missing teardown. | HIGH | Grounded in reverted commit `bbfd0b2ff32a`→`abeae421b03d`: disabling device-ready before SHUTDOWN was added to avoid a dual-link split screen and reverted because "this will cause failure in sending SHUTDOWN packet during disable". A correct GLK dual-link sequence is unfixed upstream. Depends on confirming `dual_link` from the VBT. |
| **I. Fastset/readout-mismatch fix (DSI C clock divider) + mainline verify** | Cheap, and directly targets the "bogus fastset mismatch" class that can turn resume into a no-op. | LOW | Commit `615c8ec48621` ("drm/i915/dsi: Don't set/read the DSI C clock divider on GLK", 2025-07-18): *"some firmware versions program this and some do not. In order to avoid bogus fastset mismatches…"*. Verify whether the test kernel (Ubuntu `7.0.0-38`) carries it; if not, this alone may change the resume fastset decision. |
| **J. Compositor-side "never disable the DSI output across suspend"** | Sidesteps the broken disable→enable by never entering it; low code churn. | LOW-MEDIUM | KWin/KDE config or a resume hook that keeps `outputs`/DPMS from driving an encoder off→on. Weaker than A (KWin may still force a modeset), but cheap and composable with A. |
| **K. DSI panel power-cycle wait hardening** | Belt-and-braces for the ordering; low risk. | LOW | `intel_dsi_wait_panel_power_cycle()` + `intel_dsi_shutdown()` exist (commits `f13c2a0032f0`). Only worth it if A/B expose a power-cycle timing dependency. |

### Anti-Features — disproven levers (do NOT re-tread)

Every item below is explicitly recorded as tried-and-failed in
`docs/research/DISPLAY_RESUME_CCS_MODIFIER.md` ("Disproven theories") and/or
`docs/research/DSI_RESUME_TRACE_ANALYSIS.md`, or is refuted by the source reading above. The
milestone's success criterion is that the ledger **rules these out with reasons**.

| Anti-feature (do not build) | Why it looks attractive | Why it is wrong (grounded) |
|---------|---------------|-----------------|
| PPS / TCON power-cycle timing clamp (`intel_pps.c`) | "Windows enforces 500 ms" narrative | Wrong subsystem (eDP PPS); the panel is MIPI-DSI; the VBT already reports a 500 ms power cycle and legacy PPS `0xc7204` reads **identical** cold vs resume; i915's GLK-DSI path never touches that PPS. |
| D-PHY retune / `HS_TX_TIMEOUT` / `exit_zero_cnt` | Differing registers | Registers forced live on the black state → no effect; full cold/resume register diff forced → no effect. |
| Register forcing (CDCLK `0x46000`, DSI-PHY `0x160018`, DSI block) | 21 differing registers looked suspicious | Written live on the black state, no effect; `intel_reg dump` + full diff prove no static register distinguishes working/broken. |
| "Keep the panel powered across suspend" (early-return `intel_dsi_post_disable`) | Avoids the dead-state | Still black — the panel does not survive S3 even when i915 leaves it alone. |
| Suspend depth change (S3 vs `s2idle`) | "deeper sleep is bad" | Both resume black. |
| PMIC / I2C bus 6 | GOP looked like it used a PMIC | No Linux I2C client on bus 6; GOP has no I2C/PMIC MMIO or strings. |
| Forcing `glk_cold_boot=0` | It is the only host diff | Forced on `82H0` → still black; cold-boot ordering is correct-by-design for S3/S4 (`8a1deb329ffb`). |
| "DMC probe-init" / forcing `intel_power_domains_init_hw(display,false)` | "resume init is incomplete" | Trips `assert_dmc_loaded` (`intel_dmc.c:701`) and gives no panel; `resume=false` *skips* `intel_dmc_load_program`, which resume already does via `bxt_display_core_init(resume=true)`. |
| Bare PCI reset (`echo 1 > .../reset`) | "reset the GPU" | Does not recover and makes the panel worse; device `remove`+`rescan` does not recover and hung the box. Only i915 **unbind/bind** (full remove→probe) works — do not hot-remove the GPU. |
| DCS re-send after video enable; `msleep(300)` after `MIPI_SEQ_POWER_ON` | "re-send the init" | No effect; the VBT sequence already runs `INIT_OTP`/`DISPLAY_ON` identically to the working reload. |
| Re-adding the DSI panel power-cycle at the top of `pre_enable` (`vlv_dsi.c`) | "force a power cycle" | Built + DMI-gated + matched on device → did **not** fix, made resume worse (early DCS over an unready link, CRTC left disabled). Patch deleted. |

---

## Feature Dependencies

```
A. Forced DSI teardown on resume
    ├──requires──> i915 module patch path (DKMS build harness — exists from v1.0..v7.0)
    ├──requires──> accurate DSI readout/hook points (intel_dsi_get_hw_state / sanitize_encoder)
    └──enhances──> B. Honest resume readout (B makes A's commit deterministic)

B. Honest resume readout
    └──requires──> confirmation of DSI transcoder/encoder active state after S3

H. Dual-link teardown correction
    ├──requires──> D. VBT decode of dsi.config->dual_link (confirm ports == A|C)
    └──conflicts──> (none) but overlaps A — implement as one patch series, not two

I. Fastset readout fix / mainline verify
    └──requires──> kernel-version check of the test image + mainline build

G. Windows RE differential
    ├──requires──> Ghidra + REA tooling (declared in milestone)
    └──enhances──> A/H (may reveal the exact teardown/reset sequence to mirror)

D. Seamless recovery fallback ──enhances──> every avenue (always-available safety net)
C. Backlight fix               ──independent of, but needed alongside, A/B/H
F. Upstream filing + ledger    ──requires──> E (ledger) first
```

### Dependency Notes

- **A requires the DKMS/module harness**: already proven end to end in v1.0–v7.0 (`scripts/install_dkms.sh`,
  `patches/`, CI module build). No new infrastructure.
- **H requires a VBT decode**: `docs/` has the extraction tooling (`uefi_firmware`, capstone) and the
  `G0CN12WW` VBT (`$VBT GEMINILAKE`). Decode `dsi.config->dual_link` before writing any dual-link code.
- **G enhances A/H**: the Windows RE is the highest-information, highest-cost input; sequence it so the
  cheap A/B/I experiments run in parallel first.
- **J conflicts with nothing** but must not be used to mask a real fix — treat it as a complement, not a
  substitute.

---

## MVP Definition

### Launch with (the minimum that can prove the concept on the D330)

- [ ] **E. Ledger** — one consolidated tried/disproven table (cheap, unblocks F). 
- [ ] **I. Mainline/fastset verification** — cheap test; may change the resume code path by itself. 
- [ ] **A (+B). Forced DSI teardown / honest readout on `82H0` resume** — the primary root-cause candidate.
- [ ] **C. Backlight resume fix** — required for any "lit panel" outcome; independent and low-cost.
- [ ] **D. Seamless reload fallback** — guarantees a shippable result even if A/B/H fail.

### Add after validation (v8.x)

- [ ] **H. Dual-link teardown correction** — only if the VBT decode confirms dual-link and A/B are insufficient.
- [ ] **G. Windows RE differential** — do once A/B have narrowed the problem; use it to explain and harden the fix.
- [ ] **J. Compositor-side never-disable** — only if KWin still forces the broken transition after A/B.

### Future consideration (v9+)

- [ ] **K. DSI power-cycle wait hardening** — only if a timing dependency surfaces.
- [ ] Upstreaming the quirk/patch as a proper i915 series (needs F first).

### Expected behaviour a correct resume must produce (success criteria for A/B/H)

After an S3 cycle on `82H0` with KWin running, **without** any i915 reload:

1. Panel lit, upright, at the saved rotation (270°), within ~1 s of resume.
2. `actual_brightness == brightness` and `bl_power == 0` with no manual write.
3. Deterministic across ≥10 consecutive S3 cycles and both `deep` and `s2idle`.
4. The resume trace shows the DSI enter `post_disable`/device-ready-clear then a full `pre_enable`
   (i.e. a real disable→enable, not a fastset), or (avenue B) the readout reports the encoder disabled
   so the commit performs a real modeset.
5. No `drm_mode_config_cleanup`/`assert_dmc_loaded`/`ULPS still active` kernel WARN.
6. No `card0` re-registration visible to the compositor (i.e. no reload happened).

---

## Feature Prioritisation Matrix

| Feature (avenue) | Likelihood it fixes the black panel | User value | Implementation cost | Priority |
|---------|------------|---------------------|----------|----------|
| A. Forced DSI teardown on resume (+B) | HIGH | HIGH | MEDIUM | **P1** |
| C. Backlight resume fix | CERTAIN (but separate) | HIGH | LOW | **P1** |
| D. Seamless reload fallback | CERTAIN (shippable bar) | HIGH | MEDIUM | **P1** |
| E. Consolidated ledger | — | MEDIUM (unblocks F) | LOW | **P1** |
| I. Fastset readout fix / mainline verify | MEDIUM | MEDIUM | LOW | **P2** |
| H. Dual-link teardown correction | MEDIUM-HIGH (if dual-link) | HIGH | HIGH | **P2** |
| G. Windows RE differential | MEDIUM (info value HIGH) | MEDIUM | HIGH | **P2** |
| F. Upstream filing | LOW (direct) | HIGH (durability) | LOW | **P2** |
| J. Compositor never-disable | MEDIUM | MEDIUM | LOW-MEDIUM | **P3** |
| K. Power-cycle wait hardening | LOW | LOW | LOW | **P3** |

**Priority key:** P1 = must have for the milestone to land; P2 = should have; P3 = nice to have.

---

## Competitor / Prior-Art Feature Analysis

| Aspect | Upstream i915 | N100 DSI fix (`dascenci/n100-dsi-blackscreen-fix`) | Our approach (D330 / GLK) |
|---------|--------------|--------------|-----------------|
| Symptom | GLK S3 known-broken (CI xfail) | Alder Lake DSI black on first boot, works after suspend (inverse) | GLK DSI black after S3, works after reload |
| Root-cause class | (unfixed) | VBT block 42 bad timings; DMC loads after DSI encoder; CDCLK not recalculated; panel power-cycle not respected | State-provenance: DSI encoder reused from DC9-restored state; no disable half before re-enable |
| Fix style | — | Defer DSI encoder init until DMC ready; **force full modeset for DSI encoders**; add power-cycle delay | Force a real disable→enable (teardown) on `82H0` resume; honest readout; dual-link correction |
| Transferable lesson | — | "Force full modeset for DSI encoders" and "wait for DMC before DSI init" are the right *shape* of fix even though the SoC differs (v8.0's avenue B/A) | Adopt the shape, prove on GLK trace evidence; do not port blindly (DMC is already correct here) |

---

## Sources

- i915 source, `torvalds/linux` (master), HIGH confidence:
  - `display/intel_display_driver.c` — `__intel_display_driver_resume()` / `intel_display_driver_pm_resume()` / probe entry points.
  - `display/intel_display_power.c` — `intel_power_domains_suspend/resume`, `bxt_display_core_init(resume)`, `bxt_enable_dc9`/`bxt_disable_dc9`, `intel_display_power_resume_early`.
  - `display/intel_modeset_setup.c` — `intel_modeset_setup_hw_state()`, `intel_sanitize_encoder()` ("resume register restoring").
  - `display/vlv_dsi.c` — `intel_dsi_pre_enable()`, `glk_dsi_enable_io()`, `glk_dsi_device_ready()`, `intel_dsi_get_hw_state()` (BXT/GLK PLL guard), `intel_dsi_init()` dual-link `ports` selection.
  - `display/intel_dsi_vbt.c` — `intel_dsi_vbt_gpio_init()`, `mipi_exec_gpio()`, `intel_dsi_vbt_exec_sequence()`.
  - `display/intel_dsi.c` — `intel_dsi_wait_panel_power_cycle()`, `intel_dsi_shutdown()`.
  - `display/intel_dmc.c` — `intel_dmc_load_program()`, `assert_dmc_loaded()`, DC9/DC6 notes.
- Kernel commit history (HIGH confidence):
  - `8a1deb329ffb` "drm/i915/glk: Add cold boot sequence for GLK DSI" (2017-06-13) — S3/S4 rationale.
  - `74e4ce6a7875` "drm/i915/glk: Split GLK DSI device ready functionality" (2017-06-13).
  - `3acbec03b3c5` "drm/i915/glk: Fix DSI \"*ERROR* ULPS is still active\" messages" (2017-04-28).
  - `beb29980026f` "drm/i915: Corrupt DSI picture fix for GeminiLake" (2019-04-30) — CDCLK 158400 limit.
  - `615c8ec48621` "drm/i915/dsi: Don't set/read the DSI C clock divider on GLK" (2025-07-18) — bogus fastset mismatch.
  - `f13c2a0032f0` "drm/i915: Wait for VLV/CHV/BXT/GLK DSI panel power cycle delay on reboot" (2020-10-01).
  - `abeae421b03d` "Revert drm/i915/bxt: Disable device ready before shutdown command" (2017-09-05) — "dual link is not supported and will need some rework in the upstream code".
- i915 CI: `drivers/gpu/drm/ci/xfails/i915-glk-skips.txt` — `# Suspend to RAM seems to be broken on this machine` (MEDIUM-HIGH confidence).
- dri-devel, `[BUG] Lenovo D330-10IGL: Blank screen issues with DSI display on Gemini Lake` (Sep 2025), Jani Nikula reply → file at the i915 bug tracker (HIGH confidence, `lists.freedesktop.org`).
- `github.com/dascenci/n100-dsi-blackscreen-fix` (Alder Lake DSI) — prior-art fix shape: force full modeset for DSI encoders; wait for DMC before DSI init (MEDIUM confidence, different SoC).
- On-device trace evidence (HIGH confidence, local): `docs/research/DISPLAY_RESUME_CCS_MODIFIER.md`, `docs/research/DSI_RESUME_TRACE_ANALYSIS.md`.
- `docs/windows_analysis/RESUME_SEQUENCE.md` — **superseded** on PPS/TCON/timing; use for WDDM/GOP background only (LOW confidence).
- Upstream bug trackers: freedesktop bug 109267 `[GLK DSI] Display not working with i915 driver` and 108826 `[GLK DSI] Black screen after grub` (search-result snippets only — direct fetch blocked by Anubis; LOW-MEDIUM confidence).

---

## Gaps to Address (needed before roadmap finalisation)

- **VBT decode**: confirm `dsi.config->dual_link` (ports A|C) and the MIPI-sequence version (v2 vs v3) from `$VBT GEMINILAKE` — decides whether avenue H is in scope.
- **Kernel version delta**: does the test kernel (`7.0.0-38`) and the shipping `7.0.14-d330-fix` carry `615c8ec48621` and the other recent GLK DSI fixes? Decides avenue I.
- **Readout instrumentation**: add `pr_err` markers to `intel_dsi_get_hw_state()` and `intel_sanitize_encoder()` for `82H0` on resume to prove whether the encoder is read as active (validates A/B directly).
- **Windows RE not yet performed**: the actual `igdkmd64.sys` D3→D0 callback is unread; avenue G is unranked-by-evidence until then.
- **DMC program provenance on resume**: whether `bxt_display_core_init(resume=true)`'s single `intel_dmc_load_program()` is fully equivalent to probe-time `intel_dmc_init()` for GLK — not proven either way.

---

*Feature/avenue research for: Lenovo IdeaPad D330-10IGL (82H0) i915 GLK MIPI-DSI resume black screen*
*Researched: 2026-10-12*
