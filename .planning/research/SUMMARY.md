# Project Research Summary

**Project:** Lenovo IdeaPad D330-10IGL (Type 82H0) — milestone v8.0: fix the i915 Gemini Lake MIPI-DSI resume black screen
**Domain:** Linux kernel DRM/i915 display-driver bug, native-binary reverse engineering, out-of-tree distro packaging, on-device hardware verification
**Researched:** 2026-10-12
**Confidence:** MEDIUM overall (HIGH on the repo integration surface and the do-not-retry ledger; MEDIUM on the root-cause avenue ranking; LOW on upstream already having a fix)

## Executive Summary

This is not a missing-write bug and it is not a misconfiguration. On-device `i915_reg_rw`/`pr_err` tracing plus a read of current mainline source establish that suspend/resume runs the **full** cold DSI power-on sequence, drives the same VBT GPIOs (144/145/160), programs the same PLL/CDCLK, and leaves every host register **byte-identical** to a working state, yet the panel stays black. The single most diagnostic fact: with no compositor running, the resume trace buffer is empty (`entries-written=0`) — i915 issues **no** DSI/pipe writes at all, because its readout believes the DSI encoder is still enabled (registers survived via DC9) and reuses stale state instead of re-initialising the link. The only reliable recovery, proven on hardware, is a PCI **unbind/bind reload** of `0000:00:02.0`, which works because the driver *probe* path hands the atomic core a different starting state than `__intel_display_driver_resume()`. This is a **state-provenance / readout failure**, not a `pre_enable()` failure.

The recommended approach is deliberately two-track and milestone-safe. **Ship a hardened, packaged, machine-verified automatic unbind/bind recovery first** (option c). This is the only path with a demonstrated working end state, and PROJECT.md explicitly accepts an invisible reload/compositor restart as a valid bar. The current recovery hook exists but has three concrete gaps: it is not shipped by ANY packager (so `.deb`/`.rpm`/PKGBUILD users get no recovery at all), its runtime-disable file is not in the deploy manifest, and the manual `d330-display-reload.sh` is not deployed. Close those, and the milestone has a shippable result even if the root cause is never found. **Then pursue the actual driver fix in parallel** (option a) via the RE push and a safe `bindeb-pkg` test-kernel lane, implementing the primary root-cause candidate: force a real DSI teardown (`intel_dsi_disable()`+`intel_dsi_post_disable()`, or make the resume readout report the encoder inactive so the atomic commit performs a full modeset instead of a fastset) on `82H0` resume. Reject the out-of-tree-module path — it cannot fix this, because i915's display symbols are not exported. A separate, independent second bug (backlight resume leaves `bl_power=4`, `actual_brightness=0` while `brightness=640`) must be fixed alongside: even a repaired link is dark without it.

The key risks are hardware-bricking and false evidence, and both have concrete mitigations the repo is already good at. Never hot-remove the GPU or issue a bare PCI reset (both disproven, both can hang the box); the only safe device recovery is unbind/bind. Never flash a BIOS (the newer `G0CN14WW` dump carries a BROXTON VBT with no MIPI sequence block and can brick the tablet). Never overwrite the distro i915 module without a golden off-device backup and a live USB. Treat black-resume-vs-working-reload as the only valid control (cold boot never runs the DSI path). Treat decompiler/LLM RE output as untrusted until every claim cites file+address+raw bytes and is resolved against `i915_reg.h`. A binding Do-Not-Retry Ledger (22 on-device-disproven levers + community/upstream dead ends) must gate every phase plan.

## Key Findings

### Recommended Stack

This is a **delta** stack; the shell/Python/DKMS/packaging/CI tooling from v1–v7 is already validated and must not be re-added. What is new: the RE toolchain (REA 6.4.0 MCP server driving Ghidra 12.1.4 on the Windows host, JDK 21 already present, Node 26 already present), a reversible i915 build/install lane (`bindeb-pkg` test kernel, never hand-overwriting the distro module), kernel-version bisect tooling (mainline CLI sweep first, `git bisect` over a narrowed window), and cheaper on-device instrumentation (`CONFIG_DRM_USE_DYNAMIC_DEBUG=y` + dyndbg to fix the documented "drm.debug lands nothing" dead end, plus bpftrace/perf-probe kprobes to trace i915 functions live with no rebuild).

**Core technologies:**
- **REA 6.4.0 + Ghidra 12.1.4** — agent-driven native-binary RE; REA is a purpose-built MCP bridge with an OpenCode client and an experimental Windows Ghidra P0 path (read-only PE x86/x64) that fits this Windows host. Config-only, no code.
- **`bindeb-pkg` test kernel (Lane B)** — the recommended, revertible way to ship a patched i915: the stock kernel stays bootable, the patched kernel is a first-class package with its own GRUB entry. Never patch a core module through a second DKMS.
- **`CONFIG_DRM_USE_DYNAMIC_DEBUG=y` + dyndbg, and bpftrace/perf-probe kprobes** — replace the slow `pr_err` rebuild loop; the 0-`vlv_dsi`-sites dead end is a build-config artifact, not a hard limit.
- **`mainline` CLI + `git bisect`** — settle cheaply whether GLK DSI resume is a fixed regression before any costly bisect. Caveat: `git bisect run` cannot survive the per-step reboot; use a manual checklist or a boot-time self-resuming harness driven over SSH.
- **External objective pass/fail signal** (compositor screenshot luminance via `grim`+ImageMagick, or a USB webcam) — no host register distinguishes a lit panel from a black one; observation must be external.
- **WSL2 Ubuntu** — required host for REA's firmware (binwalk/unblob) and process-capture lanes (Linux-only; Windows returns `unsupported_host`).

### Expected Features

The FEATURES.md deliverable is a ranked **candidate-fix-avenue** list (not a consumer feature list). The load-bearing insight: the reload reconstructs (1) a completed DSI teardown before re-init, (2) a display-core init from `POWER_DOMAIN_INIT` on a torn-down core, (3) a fresh encoder with fresh VBT config committed through `intel_initial_commit()` rather than `drm_atomic_helper_commit_duplicated_state()`, and (4) DMC load at a different time (both load it; the naive "resume skips DMC" theory is wrong and trips `assert_dmc_loaded`).

**Must have (table stakes — the milestone fails without these):**
- **A (+B). Forced DSI teardown / honest resume readout on `82H0`** — the primary root-cause candidate; reproduces the one thing the reload does that resume does not. DMI-gated.
- **C. Backlight resume fix** — independent, certain, low-cost; without it even a fixed link is dark.
- **D. Seamless automatic recovery fallback** — the shippable bar if A/B fail; the gap is making it clean and packaging it.
- **E. One consolidated tried/disproven ledger** — unblocks upstream filing; prevents re-treading.
- **F. Upstream filing + mainline test** — the bug is a known upstream gap (i915 CI `i915-glk-skips.txt`: "Suspend to RAM seems to be broken on this machine").

**Should have (differentiators):**
- **H. Dual-link DSI teardown correction** — only if the VBT decode confirms `dsi.config->dual_link` (ports A|C); upstream explicitly does not support BXT/GLK dual-link.
- **G. Windows `igdkmd64.sys` D3→D0 RE differential** — highest-information, highest-cost input; the existing `RESUME_SEQUENCE.md` PPS/timing premise is superseded.
- **I. Fastset/readout-mismatch fix (DSI C clock divider) + mainline verify** — cheap; commit `615c8ec48621` may change the resume fastset decision.

**Defer (v8.x / v9+):**
- **J. Compositor-side never-disable** — KWin-only; a diagnostic, not a product fix (no-compositor resume is also black).
- **K. DSI power-cycle wait hardening** — only if a timing dependency surfaces.
- **L. Proper upstream i915 quirk series** — needs F first.

**Anti-features (do NOT rebuild — all disproven):** PPS/TCON timing clamp, D-PHY retune, register forcing, keep-panel-powered, suspend-depth change, PMIC/I2C bus 6, `glk_cold_boot=0` forcing, DMC probe-init, bare PCI reset, DCS re-send, the `pre_enable` power-cycle patch.

### Architecture Approach

The bug is a state-provenance failure inside i915's non-exported display code, which drives the whole integration architecture. Option (a) — a clean i915 resume-path patch — is the right *goal* but is unimplemented and unproven; it can only be attempted after the RE push answers "what does probe do that resume does not?" Option (b) — an out-of-tree/DMI module — **cannot fix this** (display symbols not exported; register forcing already disproven); keep the existing `lenovo_d330_fix.ko` honest as a banner-only module. Option (c) — auto unbind/bind reload + display-manager restart — already exists and meets the accepted bar. Option (d) — KWin workaround — is an experiment, not a product fix. The integration work is dominated by three repo invariants already modeled well: the **deploy manifest** (`deploy_manifest()` in `scripts/install_dkms.sh`) as single source of truth, the **installer symmetry guard** (`test_installer_symmetry.sh`), and the **harness-trust meta-guard** (`test_harness_trust.sh` requiring `--apply` on any mutation test).

**Major components:**
1. **`deploy_manifest()` + installer/uninstaller symmetry** — single source of truth; every new artifact must appear in manifest, install body, uninstall body, all three packagers, and the CI `.deb`, or the guard suite fails.
2. **Display resume recovery hook** (`patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh`) — DMI-gated to `82H0`, `timeout 30`-bounded, reloads i915 then restarts `display-manager`; the proven recovery, currently unpackaged.
3. **Option-2 kernel patch lane** (`run_kernel_src_step()` + `patches/d330_display_resume_fix.patch` + `build-kernel.yml`) — dry-run-gated, fail-soft; the only path to an upstreamable fix.
4. **Upstream i915 DMI quirk mechanism** (`intel_quirks.c` `intel_dmi_quirks[]` + `intel_has_quirk()`) — the mandatory shape for any board-specific fix; never an inline `dmi_match()`.
5. **Static + on-device test harness** (36 scripts) — extend with new guard cases; any on-device mutation test must be `--apply`-gated or live in a non-`test_*` script.

### Critical Pitfalls

1. **Re-treading a disproven lever (no ledger discipline)** — the single highest-probability failure. The disproven list lives in prose docs, not as a gate. Fix: make the ledger the single source of truth, add it as a blocking review gate on every phase plan, and encode it as a `scripts/test_pitfalls_ledger.sh` that greps plans for banned levers.
2. **Forcing probe-style init on resume trips the `assert_dmc_loaded` WARNING** — `intel_power_domains_init_hw(display, false)` on `82H0` is the probe-time path; at resume DMC is not guaranteed loaded, so it hits `intel_dmc.c:701`, no panel. The display core is already torn down/re-init'd every S3; "resume doesn't reset the PHY" is false. Do not force it; treat the WARNING as a red flag.
3. **Bare PCI reset / hot-remove bricks the box** — `echo 1 > .../reset` makes the panel worse; `remove`+rescan left the box hung. Only unbind/bind recovers. Never hot-remove; keep a live USB + golden module staged.
4. **Flashing `G0CN14WW` (BROXTON VBT) wipes the MIPI sequence block** — the working VBT is `$VBT GEMINILAKE` (GPIO 144/145/160). Hard rule: never flash any BIOS; work only from the current flash dump (`bios.bin` sha256 `7494…7C4B`).
5. **Trusting the decompiler and the LLM as ground truth** — `igdkmd64.sys` is large, stripped, no PDB; the model will confidently explain wrong output. Every RE claim must cite file+address+raw bytes, resolve constants against `i915_reg.h`/PRM, prefer the disassembler for MMIO, and cross-check with a second engine. The GOP legacy eDP PPS (`0xC7200`) is a red herring — it is not the DSI panel path and reads identical cold vs resume.

Two evidence-integrity traps compound all of the above: comparing **cold boot vs resume** (cold boot never runs the DSI path; the control must be **black resume vs working reload**), and reading CRTC state **minutes after resume** without `systemd-inhibit --what=idle` (flaky readout). Captures must span the full ~18 s DSI window.

## Implications for Roadmap

Four phases. The ordering is load-bearing: (c) is provably correct today and independent of the RE outcome, so it lands first to guarantee a shippable milestone; (a) depends on the RE unknown and must not be risked on an unfound root cause.

### Phase 43: Guardrails, Ledger & Safe Recovery Baseline
**Rationale:** Everything else depends on not bricking the tablet and on not re-treading dead levers. The repo is already strong at manifest/symmetry/harness-trust; this phase converts the prose disproven list into a machine-checkable gate and stages the safety kit.
**Delivers:** The consolidated `docs/research/RESUME_FIX_LEDGER.md` (binding, all 22 D-rows + community/upstream dead ends); a ledger-gate test that greps phase plans for banned levers; safe test protocol (black-resume vs working-reload control, ≥18 s captures, `systemd-inhibit`); golden `i915.ko.zst` staged off-device + live USB + tablet source tree under git/checksummed; current VBT/GOP dump backed up; **and the hardened, packaged recovery (c)**: add the runtime-disable file to the manifest, ship the `system-sleep` hooks through all three packagers + CI `.deb`, decide on deploying `d330-display-reload`, extend `test_display_fix_guards.sh`/`test_installer_symmetry.sh`.
**Addresses:** Features D (seamless recovery), E (ledger).
**Avoids:** Pitfall 1 (re-tread), Pitfall 3 (reset/hot-remove), Pitfall 4 (BIOS flash), Pitfall 5 (lost recovery), Anti-Pattern 4 (unpackaged hook), Anti-Pattern 5 (un-gated mutation test).

### Phase 44: Community & Upstream Survey + Cheap Levers
**Rationale:** Cheap before expensive. Confirm nothing upstream already fixes this, test a 6.17+ / mainline kernel, and check whether the test kernel carries `615c8ec48621` and the recent GLK DSI fixes — this may change the resume path by itself for near-zero cost.
**Delivers:** Upstream/bug-tracker research (i915 GitLab, lore.kernel.org, ChromeOS, distro forums); a correctly-filed i915 bug (Jani Nikula's redirect) with trace + reproducer; the mainline-kernel sweep result (good/bad pair); avenue I verdict (is `615c8ec48621` in the test kernel?).
**Addresses:** Features F (upstream filing), I (fastset/mainline verify).
**Avoids:** Wasting a long `git bisect` before the cheap boundary test.

### Phase 45: Windows / GOP Binary RE + On-Device Resume-vs-Probe Differential
**Rationale:** This is the unknown that gates the root-cause fix. Two independent inputs: static RE of `igdkmd64.sys`/`IntelGopDriver` (what the vendor D3→D0 does) and the dynamic resume-vs-probe trace (what i915 probe does that resume does not, around `intel_modeset_setup_hw_state()`). Run the cheap A/B/I experiments in parallel with the RE.
**Delivers:** REA+Ghidra bootstrap on the Windows host (config-only; verify the EFI-subsystem GOP image is accepted, else fall back to WSL/`uefi_firmware`+capstone); VBT decode confirming `dsi.config->dual_link`; the primary-candidate patch implementing forced DSI teardown / honest readout (avenues A+B); the backlight resume fix (C); a CI `-d330-fix` kernel built as a **non-default** GRUB entry; and, if the RE reveals it, avenue H.
**Uses:** REA + Ghidra + GLM 5.3 Flash; the `bindeb-pkg` test-kernel lane; dynamic-debug + kprobes instrumentation; WSL2 firmware extraction.
**Addresses:** Features A, B, C, G, H, I.
**Avoids:** Pitfall 2 (probe-init `assert_dmc_loaded`), Pitfall 6 (decompiler/LLM false positive), Pitfall 7 (GOP PPS mis-attribution), Pitfall 8 (wrong control/phantom evidence), Pitfall 9 (extraction false positives), RE pitfalls R1–R10.

### Phase 46: Verification, Delivery & Upstream (conditional)
**Rationale:** Prove the fix works where it must (cold boot, touch, audio, v1–v7 tools) and ship it through the honest channel; upstream only if a real fix landed.
**Delivers:** On-device `--apply`-gated rtcwake + reload-recovery acceptance test (hook ran on `82H0`, device rebound, fresh card node, backlight on); no-regression proof on cold boot/touch/audio/existing tools; upstream submission (i915 DMI quirk via `intel_quirks.c`, plain-text `git send-email` to intel-gfx, correct trailers, real developer identity for DCO) **only if** Phase 45 landed a real fix.
**Addresses:** Features A/B/H verification, F/D delivery.
**Avoids:** Sham shipping — if no lever is found, close the milestone honestly on the packaged recovery rather than shipping a non-fix (Pitfall: dirty reload described as a driver fix).

### Phase Ordering Rationale

- **(c) before (a)** because (c) is provably correct today and independent of the RE outcome; putting (a) first risks the whole milestone on an unfound root cause.
- **Ledger/safety first** because the tablet has no serial console and a bad module can leave it with no usable display; the safety kit and the banned-lever gate must exist before any device experiment.
- **Cheap levers before the costly bisect** because a good/bad kernel pair or a one-line config check may settle the question for near-zero cost.
- **RE and dynamic trace in parallel** because they are independent inputs to the same question; the static RE is the highest-cost, so the cheap A/B/I experiments run alongside.
- **Phase-grouping follows the architecture's build order** (ARCHITECTURE.md "Recommended Build Order"), and the deliverable grouping mirrors the manifest/symmetry/harness-trust invariants.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 44 (community/upstream survey):** the upstream question "is GLK DSI resume a fixed mainline regression?" could not be confirmed — web search hit bot challenges and lore.kernel.org/GitLab hit the Anubis anti-bot wall. This phase needs a dedicated bug-tracker research task before committing to a long bisect.
- **Phase 45 (Windows/GOP RE):** niche domain, sparse docs, and the highest false-positive risk; needs a bounded-RE plan (specific MMIO addresses + resume-path call graph, time-boxed) and a citation-discipline review gate.
- **Phase 45 (test-kernel lane):** the `git bisect`-across-reboot constraint and whether `CONFIG_KPROBES`/`KPROBE_EVENTS` are present in the Ubuntu generic tree both need confirming.

Phases with standard patterns (skip research-phase):
- **Phase 43 (guardrails/packaging):** the manifest/symmetry/harness-trust invariants are all read directly from the repo and well understood.
- **Phase 46 (verification):** established repo patterns (static guards + `--apply`-gated on-device test + doc parity).

### Milestone Constraints (carry through every phase)

- **Target kernel = current test kernel, Ubuntu `7.0.0-38-generic`** (clean CI build tag `7.0.14-d330-fix`). Fixes ship on this kernel.
- **Real D330 hardware is available** — all root-cause claims must be verified on-device, not just by source reading.
- **Upstream-worthy but a local fix is acceptable** — a clean, upstreamable fix is the goal; a DMI-gated local patch is a valid outcome.
- **Observable bar:** resume always yields a working display; a seamless automatic recovery (invisible i915 reload/compositor restart) is an acceptable bar. The expected correct-resume behaviour (FEATURES.md §"Expected behaviour") is the stretch target: panel lit upright at 270° within ~1 s, `actual_brightness == brightness` and `bl_power == 0` with no manual write, deterministic across ≥10 S3 cycles and both `deep`/`s2idle`, and no reload/card-node re-registration visible to the compositor.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM-HIGH | REA/Ghidra toolchain HIGH (verified vs upstream docs + local host); bisect/rollback workflow MEDIUM (standard tooling, one automation subtlety); "is GLK DSI resume a fixed regression" LOW (upstream streams bot-blocked). |
| Features | MEDIUM-HIGH | Resume-vs-reload mechanism HIGH (read from current mainline source); avenue ranking MEDIUM (grounded in on-device trace evidence, not yet proven on hardware). |
| Architecture | MEDIUM | Repo integration points HIGH (read directly from the tree); option choice constrained by prior on-device research; upstream process MEDIUM (kernel docs read, i915 GitLab bot-walled). |
| Pitfalls | HIGH | Do-not-retry ledger and safety traps are on-device reproduced, some cross-checked upstream; RE pitfalls MEDIUM (category-level); upstream survey MEDIUM. |

**Overall confidence:** MEDIUM. The repo surface and the ledger are solid; the root-cause avenue is a well-reasoned hypothesis with strong circumstantial evidence but no proven lever yet. Plan the milestone so a shippable result (packaged recovery) does not depend on the hypothesis being correct.

### Gaps to Address

- **Is GLK DSI resume a fixed mainline regression?** — unconfirmed (bot walls). Resolve in Phase 44's bug-tracker research before committing to a long bisect.
- **VBT decode: `dsi.config->dual_link` (ports A|C) and MIPI-sequence version (v2 vs v3)** — decides whether avenue H is in scope. Decode before writing any dual-link code.
- **Kernel version delta** — does the test kernel (`7.0.0-38`) and shipping `7.0.14-d330-fix` carry `615c8ec48621` and the recent GLK DSI fixes? Decides avenue I.
- **Readout instrumentation** — add `pr_err` markers to `intel_dsi_get_hw_state()` and `intel_sanitize_encoder()` for `82H0` on resume to prove whether the encoder is read as active (validates A/B directly).
- **Windows RE not yet performed** — the actual `igdkmd64.sys` D3→D0 callback is unread; avenue G is unranked-by-evidence until then.
- **DMC program provenance on resume** — whether `bxt_display_core_init(resume=true)`'s single `intel_dmc_load_program()` is fully equivalent to probe-time `intel_dmc_init()` for GLK is not proven either way.
- **REA Windows P0 vs EFI-subsystem `IntelGopDriver`** — P0 admits native PE x86/x64 app/DLL; EFI images are untested. Verify with `rea providers`/a one-off open, keep the Linux-WSL Ghidra / capstone fallback.
- **`CONFIG_KPROBES`/`KPROBE_EVENTS` in the Ubuntu generic build tree** — assumed enabled; confirm with `zgrep KPROBE /boot/config-$(uname -r)` before relying on bpftrace/perf-probe.

## Sources

### Primary (HIGH confidence)
- i915 source, `torvalds/linux` (master): `display/intel_display_driver.c`, `intel_display_power.c`, `intel_modeset_setup.c`, `vlv_dsi.c`, `intel_dsi_vbt.c`, `intel_dsi.c`, `intel_dmc.c`, `intel_quirks.c`, `drm_panel_orientation_quirks.c`.
- On-device trace evidence (local): `docs/research/DISPLAY_RESUME_CCS_MODIFIER.md`, `docs/research/DSI_RESUME_TRACE_ANALYSIS.md`, `docs/research/COMMUNITY_FINDINGS.md`.
- Repo (read directly): `scripts/install_dkms.sh`, `patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh`, `patches/d330_display_resume_fix.patch`, `patches/dkms/lenovo-d330-fix/*`, `scripts/test_*.sh`, `.github/workflows/build-kernel.yml`, all three packagers.
- REA docs (`morluto/rea`) — installation, Windows Ghidra P0, firmware-analysis, CLI; npm `rea-agents` latest = 6.4.0; GitHub Releases Ghidra 12.1.4 (`ghidra_12.1.4_PUBLIC_20260921.zip`).
- Kernel commits: `8a1deb329ffb` (GLK cold boot, S3/S4 rationale), `abeae421b03d` (dual-link unsupported), `615c8ec48621` (DSI C clock divider / bogus fastset), `f13c2a0032f0` (panel power-cycle wait).
- dri-devel: `[BUG] Lenovo D330-10IGL: Blank screen issues with DSI display on Gemini Lake` (2025-09-04) + Jani Nikula reply → file at the i915 tracker.
- Intel: `How to File i915 and xe Bugs` (`drm.pages.freedesktop.org/intel-docs`).

### Secondary (MEDIUM confidence)
- i915 CI `drivers/gpu/drm/ci/xfails/i915-glk-skips.txt` — "# Suspend to RAM seems to be broken on this machine".
- intel-gfx `[PATCH v3] drm/i915/dmc: fix assert_dmc_loaded WARN during async firmware load` (May 2026); Ubuntu SRU ADL-N warm-boot WARNING (~20%).
- `github.com/dascenci/n100-dsi-blackscreen-fix` (Alder Lake prior art) — "force full modeset for DSI encoders", "wait for DMC before DSI init"; `Creatomat/i915-suspend-fix`, `ansulev/meteor-lake-suspend-fix` (neighbour platforms).
- Kernel tooling practice (`bindeb-pkg`, `git bisect`, mainline/`drm-tip`); the "bisect cannot survive a reboot" constraint inferred from the test's reboot requirement.

### Tertiary (LOW confidence)
- `docs/windows_analysis/RESUME_SEQUENCE.md` — superseded on PPS/TCON/timing; use for WDDM/GOP background only.
- Upstream bug trackers freedesktop 109267 / 108826, 101205 (BYT) — snippets only, direct fetch blocked; different platforms.
- CVE-2026-31540 (i915 NULL deref on suspend with missing firmware) — keep DMC/GuC firmware present and matching.

---
*Research completed: 2026-10-12*
*Ready for roadmap: yes*
