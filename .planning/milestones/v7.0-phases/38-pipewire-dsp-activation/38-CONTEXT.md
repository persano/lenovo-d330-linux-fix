# Phase 38: PipeWire DSP Activation - Context

**Gathered:** 2026-10-08 | **Status:** Ready (auto-accepted; slim pipeline)

<domain>
Audit M7: the speaker EQ and RNNoise mic must actually load in the running PipeWire daemon with valid graph definitions. Scope: `patches/audio_dsp/etc/pipewire/filter-chain.conf.d/50-...speaker-dsp.conf`, `51-...rnnoise-mic.conf`, `scripts/install_dkms.sh`, `scripts/test_audio_dsp.sh`, `scripts/test_mic_rnnoise.sh`, `CHANGES_AUDIT.md` §4.3, `patches/audio_dsp/README.md`.
</domain>

<decisions>
### Deploy path (M7)
- Move both conf fragments from `etc/pipewire/filter-chain.conf.d/` to `etc/pipewire/pipewire.conf.d/` (only `filter-chain.conf` consumes `filter-chain.conf.d`; the running server consumes `pipewire.conf.d`). Update manifest (`:148-149`), install (`:707-711`), uninstall (`:854-855`), packagers, README.

### Valid speaker graph (M7)
- Rewrite `50-...speaker-dsp.conf` as ONE valid filter-chain module: `label = bq_highpass` (Freq/Q), `bq_peaking` (Freq/Q/Gain) nodes with explicit `links` chaining them, replace the nonexistent `limiter` with the builtin `clamp` (Min/Max), and inline the graph inside `filter.graph` (no shared top-level `filter_chain.nodes`). Drop the invalid `label = biquad` and `"Type"` controls.

### RNNoise graph (M7)
- Rewrite `51-...rnnoise-mic.conf` valid (ladspa node inside `filter.graph`), keep only widely-supported controls (`VAD Threshold (%)`); document the `librnnoise-ladspa` package dependency and that VAD grace controls are version-dependent. 

### Routing honesty (M7)
- Do NOT ship extra untested wireplumber routing; instead DOWNGRADE the `CHANGES_AUDIT.md` §4.3 claim that EQ "colors only the speakers". State the DSP exposes a virtual sink (`effect_input.d330_speaker_dsp`) that the user/desktop must select or route to; document selection in `patches/audio_dsp/README.md`.

### Tests
- `scripts/test_audio_dsp.sh --dry-run`: validate the conf STRUCTURE statically (files under pipewire.conf.d, no `label = biquad`, no `"Type"`, links present, expected node names) and fail non-zero on violation.
- `scripts/test_mic_rnnoise.sh`: add a `D330_LADSPA_DIRS` env seam; probe exits NON-ZERO when `librnnoise_ladspa.so` is absent (SC2). `--dry-run` validates the conf statically.

### the agent's Discretion
- Exact clamp Min/Max values, biquad Q/Gain, README wording.
</decisions>

<code_context>
- `50-...speaker-dsp.conf`: `label = biquad` (invalid) x3, `"Type" = "Highpass"/"Peaking"` (invalid controls), `label = limiter` (nonexistent), 4 nodes with no `links`, `filter_chain.nodes` shared var reused by both files.
- `51-...rnnoise-mic.conf`: ladspa node referencing `librnnoise_ladspa`, controls `VAD Grace Period (ms)`/`Retroactive VAD Grace (ms)` (absent in older builds).
- Install `:306-313`/`:697-712` -> `/etc/pipewire/filter-chain.conf.d/`; uninstall `:854-855`; manifest `:148-149` `file-optional`.
- `scripts/test_audio_dsp.sh:61-70` dry-run echo-only exit 0. `scripts/test_mic_rnnoise.sh:46-66` dry-run echo-only exit 0; missing plugin -> `[INFO]` + exit 0 (must fail).
- No `pw-cli`/`pw-dump` on this host -> SC1 (nodes loaded) is hardware/override; SC2 is machine-checkable via the env seam.
</code_context>

<canonical_refs>
- `.planning/ROADMAP.md` `### Phase 38:` (goal, SC1 pw-dump nodes, SC2 missing plugin non-zero; components; Audit M7)
- `.planning/phases/37-noop-tools-pwm-sensor-filter/37-01-PLAN.md` (test-harness honesty pattern)
</canonical_refs>

<deferred>
- Automatic wireplumber routing of the hardware sink through the DSP; VAD grace tuning.
</deferred>
