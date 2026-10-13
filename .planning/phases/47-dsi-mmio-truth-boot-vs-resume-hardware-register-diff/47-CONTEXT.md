# Phase 47: DSI MMIO Truth (Boot vs Resume Hardware Register Diff) - Context

**Gathered:** 2026-10-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Capture the DSI/DPHY/transcoder hardware register state below the kernel's software model on the D330-10IGL (82H0) — one dump of the working fresh boot (GOP-initialized panel) and one dump of the broken resume (panel dark, ≤18 s window) — diff them, and name the mechanism: which hardware state the GOP sets at boot that the kernel's resume path does not (or sets wrong), as a testable claim in `docs/research/DSI_MMIO_DIFF.md`. Delivered via a small CI-built debug/dump instrumentation patch or dump tooling, checksummed and registered in the RE kit manifest. Every claim machine-evidenced; ledger gate stays green.

</domain>

<decisions>
## Implementation Decisions

### Dump Instrumentation
- Debugfs snapshot node in a CI-built i915 (e.g. `i915_dsi_regs`) — deterministic, both arms dumped with the same tool, matches success criterion 1 (CI-built kernel or dump tooling); devcoredump rejected (only fires on hang), out-of-tree dump module rejected.
- Register scope: the 5 known ftrace MMIO ranges (0x6b000-0x6c000 DSI ports, 0x160000-0x164000 BXT/GLK DSI PHY, 0x46000-0x47000 CDCLK/DSI PLL/DE PLL, 0xc7200-0xc7400 legacy PPS, 0x138000-0x139000 GT DISP PWRON/MIPIO_RST_CTRL) + full DSI transcoder/port block readback.
- Dump trigger: manual sysfs/debugfs echo per state — ordered, verifiable, identical code path on both arms; auto-on-resume hook rejected (noisy, races the 18 s window).
- Output: one text dump per state + sha256 registered in the RE kit manifest via `scripts/prepare_safety_kit.sh`; single multi-state file rejected.

### Capture Pairing & Session Protocol
- Working reference state: fresh boot (GOP-initialized panel, working image) — that is exactly the working state whose mechanism we must name; reload arm not the reference (rebind proven NOT to restore the panel per NO_CLEAN_FIX_PROOF).
- Session shape: one on-device session — boot dump → user suspends/resumes → dump immediately while panel still black, inside the capture window.
- Window discipline: binding v8.0 protocol — `systemd-inhibit --what=idle` held through the whole test, ≥18 s window, `rtcwake`-timed suspend; relaxed timing rejected (prior captures invalidated by idle blanking).
- Repeatability: one boot/resume pair first; a second pair only if the diff is ambiguous (respects the user-trigger budget; one test per session rule).

### Mechanism Claim & Evidence Standard
- Claim form: ONE named mechanism as a testable claim of the form "GOP sets register X=Y at boot; resume leaves X=Z" — ranked top-3 hypotheses rejected as a weaker handoff to Phase 48.
- Volatile-register exclusions: per-range exclusion table with reasons (interrupt-clear, timing-volatile, self-clearing bits) — required by success criterion 2.
- Evidence bar: every diff row cites register offset + capture file + line/section; `scripts/test_pitfalls_ledger.sh` gate stays green.
- Phase 48 handoff: `DSI_MMIO_DIFF.md` ends with an explicit "what to restore/replicate" register list feeding the fix plan.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `docs/research/RESUME_CAPTURE_PROTOCOL.md` — binding capture protocol (two arms, inhibit hold, 18 s window, rtcwake, five ftrace MMIO ranges).
- `docs/research/NO_CLEAN_FIX_PROOF.md` — v8.0 closure: kernel display state byte-identical working-vs-broken; the unknown lives below the kernel's model; future-work list is this phase's direct input.
- `docs/research/GOP_DSI_RE_FINDINGS.md` — GOP boot-time panel init, two-VBT handoff, SPI dump `gop_driver_dc90d1e2.efi` RE.
- `scripts/prepare_safety_kit.sh` + `docs/dumps/safety_kit/MANIFEST.sha256` — kit registration/checksum pipeline (`--register`, `--verify`).
- `scripts/test_pitfalls_ledger.sh` — banned-lever machine gate (must stay green).
- `docs/dumps/re_kit/` — existing boot/broken `i915_display_info` captures (boot_displayinfo.txt, broken_displayinfo.txt, displayinfo_diff.txt).

### Established Patterns
- CI builds i915 with patches from `patches/` (currently only `d330_display_resume_fix.patch` applied; failed-candidate patches stay in repo as documentation).
- Every hardware claim must be machine-evidenced (traces, register dumps); sysfs state never trusted for "panel visible" (ledger row: "sysfs dpms/bl_power state == visible image" DISPROVEN).
- User triggers every suspend/resume themselves; no SSH-triggered test ever requires the user's eyes (v9.0 binding process rule).

### Integration Points
- New debugfs dump node lands in the i915 DSI code path (vlv_dsi / BXT DSI PHY); patch added to CI workflow alongside the CCS fix patch.
- Dumps registered in RE kit manifest; diff document in `docs/research/DSI_MMIO_DIFF.md` per REQUIREMENTS MMIO-01/MMIO-02.

</code_context>

<specifics>
## Specific Ideas

- The dump must capture state while the panel is still black — post-resume reads taken minutes after resume are flaky (compositor blanking confound documented in DSI_RESUME_TRACE_ANALYSIS).
- The fresh-boot dump must be taken with the panel showing an image (GOP handover intact) — cold-boot control remains banned as a resume-path control, but boot-vs-resume diff IS the phase goal (the working reference is boot, not reload).

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
