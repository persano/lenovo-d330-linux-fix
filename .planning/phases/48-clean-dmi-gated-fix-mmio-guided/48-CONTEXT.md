# Phase 48: Clean DMI-Gated Fix (MMIO-Guided) - Context

**Gathered:** 2026-10-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Land the actual fix: a DMI-gated (`82H0`) kernel change that makes the panel show an image after resume, guided by the Phase 47 mechanism — replicating the GOP's boot-time panel init in the resume path or restoring the differing hardware state. Built by CI, deployed with the known-good rollback `.deb` retained first; ≤5 fix iterations; on failure the honest-closure document is updated with a v9.0 section — never a fake fix; every attempt ledger-recorded.

</domain>

<decisions>
## Implementation Decisions

### Fix Mechanism
- The fix makes the resume path RUN the missing DSI link re-establish sequence (what a full modeset does — the chvt/reload workaround proves that path lights the panel), DMI-gated to 82H0. Per DSI_MMIO_DIFF §5/§6: reach the operational state by sequencing — NEVER patch register values on the black state (ledger rows 3/18: value overwrites achieved "registers match cold boot" and the screen stayed black).
- Hook: in the DSI encoder enable path (`vlv_dsi`/`intel_dsi_vbt` post-resume enable) via a small DMI quirk flag that forces the DSI sequence re-run on the first enable after resume. Not a forced full modeset (heavier, touches core paths).
- The `i915_dsi_regs` dump node STAYS in the fix kernel during iterations (machine evidence every cycle; root-only, zero register writes).
- Iteration budget (FIX-02: ≤5), pre-allocated: iter 1 primary sequence fix → iter 2 parameter/order adjustment → iter 3 alternative hook → iters 4-5 spare; honest closure at budget end.

### Test & Deploy Loop
- CI `.deb` only; known-good rollback `.deb` sha-verified retained BEFORE every deploy (FIX-02 binding).
- Success bar: user-triggered suspend/resume; panel shows desktop image after resume (eyes-on; sysfs never counts — ledger row) + machine evidence (at-wake dump shows operational rows = boot set, timeout bits unset / ftrace sequence ran).
- One session per iteration: deploy → reboot → user suspend/resume → verdict + broken/working dump if failed → next iteration. User triggers suspend/resume themselves; delegation of scripted execution was user-authorized in Phase 47 sessions and renews per-session only on explicit ask.
- Failure evidence: every failed attempt gets a RESUME_FIX_LEDGER row + broken-state `dsi_regs` dump archived in the RE kit.

### Honesty Boundaries
- If the fix fails all 5 iterations: honest closure — `NO_CLEAN_FIX_PROOF.md` v9.0 section with the 5 attempts, the at-wake re-dump instrument spec, and the concrete next step (per DSI_MMIO_DIFF §5 falsification: if sequencing reaches X=Y, holds at wake, panel still black → mechanism is below host MMIO, panel TCON side). NEVER a fake fix.
- Guard harness full chain green at every iteration close (ledger gate, evidence suites, kit verify).
- FIX-03: no step waits on upstream; the upstream post is optional documentation filed by the user whenever convenient.
- Rollback verified before EVERY deploy (like 47-03); known-good deb never deleted.

</decisions>

<code_context>
## Existing Code Insights

### The Phase-48 handoff (DSI_MMIO_DIFF.md §6, binding)
- Register targets (state to reach by sequencing, from cited rows): 0x160018=00000115 (claim anchor, bits 8/4/2), 0x6b010=003fffff, 0x6b044=0000001d, 0x6b080/0x6b098=09051003 (bit24 clear), 0x6b088=0022000f, 0x6b004 timeout bits clear, 0x6b104 RO verify-only (identical in both states — NOT a lever).
- Invisible state: DPHY calibration area 0x162000-0x164000 unreadable (all-ones); the resume path already writes the same PHY words as the trace records (0x162024=8080e480, 0x162028=8080e480, 0x162070=33cb0443) — the missing piece is the sequencing that makes the operational state HOLD, not the words.
- Testability protocol: fix → at-wake re-dump (dump node in baseline) → judge: panel lights only if operational rows equal boot set AND timeout bits unset. Falsification → pivot to §6 next instrument (panel TCON side).

### Established Patterns
- CI kernel pipeline: `build-kernel.yml` dispatch inputs `kernel_version=7.0.0-38-generic`, `ubuntu_release=resolute`; branch-based (instrument/* or fix/*); grep-proof anchors step. Branch `instrument/d330-dsi-dump` currently carries dump node at b753d39 (PLL-gated PHY reads) — the fix patch builds on top of that branch (it is the current artifact-of-record; main merge happens at ship).
- DMI gate pattern: `dmi_match(DMI_PRODUCT_NAME, "82H0")` — used by the shipped CCS fix (skl_universal_plane.c), CI grep-proofs it.
- Deploy discipline: sha256-verify .deb before `dpkg -i`; rollback deb (`20dc04db…9e91`) present on device at `~/linux-image-7.0.14-d330-fix_7.0.14-1_amd64.deb` and never deleted; device SSH `santiago-D330`, scripted sudo per device convention.
- Capture tooling (phase-47, committed): `scripts/capture_dsi_dumps.sh` (device-staged at /usr/local/bin/), `scripts/dsi_mmio_diff.sh`, `scripts/test_dsi_mmio_evidence.sh` — every iteration's at-wake dump reuses this.
- Ledger gate `scripts/test_pitfalls_ledger.sh` must stay green; any new ledger rows appended for failed attempts keep the gate green (rows are added as DISPROVEN records, not fix proposals).

### Banned Levers (must not re-propose)
- 29+ ledger rows including: plain register value restore (rows 3/18), RO-status matching (0x6b104), sysfs-as-visibility, SSH-triggered eyes-on tests, PSR/FBC toggles as resume fix, DMI quirk hacks that just force backlight, etc. The fix must be the sequencing mechanism, evidenced.

</code_context>

<specifics>
## Specific Ideas

- The chvt/reload workaround is the existence proof: a full modeset after resume lights the panel. The fix aims to give the DSI encoder the equivalent of that re-run on the first post-resume enable — machine-evidenced by the at-wake dump reaching the boot operational set.
- The 0x6b010 row interpretation: "LP RX timeout must be left at the boot value, not a fired real time" — in the broken state the link times out; the sequence fix should prevent the timeout path entirely.
- Prediction test for iteration 1: after the fix + resume, at-wake dump should show 0x160018=00000115 and timeout bits clear; panel shows image. If dump is boot-set but panel stays black → falsification branch (TCON side).

</specifics>

<deferred>
## Deferred Ideas

- Upstream posting of the eventual fix (FIX-03) — filed by user whenever convenient, not part of any iteration.

</deferred>
