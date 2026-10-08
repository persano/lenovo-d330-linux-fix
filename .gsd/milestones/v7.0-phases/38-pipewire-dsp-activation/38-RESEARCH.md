# Phase 38: PipeWire DSP Activation - Research

**Researched:** 2026-10-08 | **Mode:** inline (slim pipeline)

## Findings
- **R1 wrong directory**: the running PipeWire server never reads `/etc/pipewire/filter-chain.conf.d/`; that dir is only for `pipewire -c filter-chain.conf`. To load inside the daemon the fragments must live under `/etc/pipewire/pipewire.conf.d/`. Both files are currently dead config.
- **R2 invalid graph**: `label = biquad` is not a builtin label (valid: `bq_lowpass`, `bq_highpass`, `bq_peaking`, `bq_bandpass`, `bq_notch`, `bq_lowshelf`, `bq_highshelf`); controls are `Freq`/`Q`/`Gain` only (no `Type`). `label = limiter` does not exist (use builtin `clamp`). Nodes declare no `links`, so a multi-node graph cannot resolve.
- **R3 shared variable clash**: both files assign `filter_chain.nodes`, so whichever loads last clobbers the other; inline each graph instead.
- **R4 SC2 test lies**: `test_mic_rnnoise.sh` prints `[INFO]` and exits 0 when the plugin is missing; `--dry-run` echoes and exits 0. Must fail non-zero on missing plugin (SC2) and validate config statically.
- **R5 no pw tools here**: SC1 (`pw-dump` shows both nodes) needs a running PipeWire -> hardware override; SC2 is proven with a fake LADSPA dir via a `D330_LADSPA_DIRS` seam.

## Approach
Move to `pipewire.conf.d/`, rewrite both graphs valid + inline, swap limiter->clamp, document the RNNoise package dep, downgrade the §4.3 routing claim, and replace the two echo-only harnesses with static/structure validators (SC2 enforced via an env seam).
