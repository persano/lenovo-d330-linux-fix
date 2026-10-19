# Phase 51: Keep-Panel-Powered Fix Ladder (E1 → E2, E3 if falsified) - Context

**Gathered:** 2026-10-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Attempt the actual fix: hold the panel rails / reset line / TCON state alive through S3 so the resume path never needs the GOP's unreachable re-init — E1 skip the panel-side teardown at suspend, E2 warm-resume enable, E3 (redefined, see below) rail-survival discriminator if E1 falsifies. Success = image after resume (eyes-on, X=Y held); any falsification is machine-evidenced and names exactly which cut killed the attempt.

Post-Phase-50 reality baked into this phase: the DCS read path is DEAD in both arms (3 identical runs), so the roadmap's original "E3 DCS ID read discriminator" cannot produce a TCON-alive verdict. E3 is redefined per Grey Area 1 below.

</domain>

<decisions>
## Implementation Decisions

### E3 Redefinition (post-Phase-50)
- E3's verdict comes from the X=Y operational-set dump taken after E1's cut + eyes-on + ftrace/GPIO-144 rail evidence — NOT from a DCS ID read (proven dead: `ret=4 avail=0 data=00 00 00` ×3 in `docs/research/TCON_IDENTIFICATION.md`)
- The pre-INIT_OTP DCS read still runs ONCE per E3 session as a zero-expectation informative bonus (it costs nothing and records the dead-path state at wake)
- If E1 falsifies and E3's dump/ftrace verdict is ambiguous → escalate to Phase 53 buy-gate immediately; E4 wake-order variants are skipped (E4 needs a live TCON, which no software probe can show)
- E3 is built LAZILY — only when E1 falsifies, never in the E1/E2 CI kernels (one candidate per CI iteration, success criterion 4)

### Device Sessions & Cadence
- One user-authorized device session per rung: deploy (sha-verified rollback first) → suspend → wake → ftrace/dump evidence → eyes-on verdict
- On E1 success: 5 user-triggered resume cycles to prove X=Y holds + battery quantification in the same session
- Fail-fast: first falsifying machine evidence ends the rung — evidence archived, ledger row appended, no same-day retries
- Sessions run as soon as the CI build is green (no artificial scheduling delay)

### Measurement & Artifacts
- `capture_dsi_dumps.sh` extended with resume arms for ~0-1s and ~4s post-wake captures inside the ≥18s window discipline
- Battery cost (success-path only): one 15-min S3 with keep-hot ON vs OFF, battery % + upower energy-rate deltas
- Dead-experiment exclusions are LOCKED: no host-MMIO holds, no defer-PPS-to-resume, no `disable_power_well=0`, no s2idle escape (all falsified, `v10.0-keep-panel-powered.md` §3)
- Every rung appends a `RESUME_FIX_LEDGER.md` row (success or failure); full ladder falsification writes the `NO_CLEAN_FIX_PROOF.md` v10.0 section

### the agent's Discretion
- All implementation choices at the agent's discretion: exact patch shape, ftrace event set details, dump-comparison tooling extensions, ledger row wording, CI workflow tweaks
- DMI gate implementation (`d330_82h0_panel()` helper) details per research `v10.0-keep-panel-powered.md` §1

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `patches/d330_dsi_dump.patch` — echo-2 DCS instrument (Phase 50); its ftrace markers D330SEQ/D330GPIO discipline carries over
- `scripts/capture_dsi_dumps.sh` — arm-based capture (boot/resume/boot2/resume2) with sha + session-record contract; extends naturally for E1/E2 resume arms
- `scripts/dsi_mmio_diff.sh` — X=Y/X=Z comparison with per-range exclusion table; selftest fixtures pattern for new arms
- `scripts/deploy_d330_kernel.sh` — sha-verified-before-dpkg deploy with distinct incoming-name discipline (T-50-09 evidence)
- `scripts/prepare_safety_kit.sh` + `docs/dumps/re_kit/MANIFEST.sha256` — evidence registration/verify round-trip
- X=Y operational set literal (fact 10): `0x6b010=003fffff, 0x6b044=0000001d, 0x6b080/0x6b098=09051003, 0x6b088=0022000f, 0x6b094=1, 0x160018=00000115`

### Established Patterns
- One candidate per CI iteration; `gh workflow run build-kernel.yml` + grep-proofs
- Ledger-gate discipline: gated alias strings in phase docs need narrow `planner-discipline-allow` markers (substring of the hit LINE)
- pwsh-native ssh + `sudo -S` password via stdin (WSL transport broken); device `santiago-D330` / `santiago@192.168.2.195`

### Integration Points
- `intel_dsi_post_disable()` / `intel_dsi_disable()` (E1 skips) and `intel_dsi_pre_enable()` (E2 skips) in the kernel patch tree
- `intel_display_driver_suspend()` — suspend-commit flag set before `drm_atomic_helper_suspend()`
- Roadmap-locked: keep-hot gates on the SUSPEND side only (KWin post-resume modeset must never trip it)

</code_context>

<specifics>
## Specific Ideas

No additional specifics beyond the accepted tables — session speed matters to the user (inline orchestrator execution for device sessions was preferred in Phase 50 over subagent dispatch).

</specifics>

<deferred>
## Deferred Ideas

- TCON datasheet hunt (wake/reset requirements) — gated on Phase 53 wire-level identification; no public FRU→glass cross-reference exists
- E4 wake-order variants — only reachable if E3 shows a live TCON, which the redefined E3 cannot show (effectively dead pending Phase 53)

</deferred>
