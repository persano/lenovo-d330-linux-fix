# Audio DSP Refinements for Lenovo IdeaPad D330-10IGL

Contains PipeWire filter-chain presets (speaker EQ and RNNoise mic denoise) and ALSA DAC anti-pop latency configuration.

## File Hierarchy
- `etc/pipewire/pipewire.conf.d/50-lenovo-d330-speaker-dsp.conf`: Speaker EQ graph (builtin `bq_highpass`, two `bq_peaking` bands and a `clamp`), exposed as a virtual sink.
- `etc/pipewire/pipewire.conf.d/51-lenovo-d330-rnnoise-mic.conf`: RNNoise LADSPA mic denoise graph, exposed as a virtual source.
- `etc/modprobe.d/lenovo-d330-audio-antipop.conf`: ALSA power ramp delay parameters.
- `etc/udev/rules.d/91-lenovo-d330-headset-jack.rules`: Headset input jack event routing.

Both filter-chain fragments are installed to `/etc/pipewire/pipewire.conf.d/`, the directory the
running PipeWire daemon reads. The legacy `/etc/pipewire/filter-chain.conf.d/` location is only
consumed by `pipewire -c filter-chain.conf` and left these graphs inactive (Phase 38, audit M7).

## How the filter-chain is applied (honest)

The graphs do **not** silently reroute audio. They create virtual nodes that must be selected or
routed explicitly:

- **Speaker DSP**: creates a virtual sink named `effect_input.d330_speaker_dsp` (description
  "Lenovo D330 Speaker DSP") whose output goes to `effect_output.d330_speaker_dsp`. To hear the EQ
  you must select or route to this sink, for example:
  - `pw-cli list-objects Node | grep d330_speaker_dsp` to find the node id, then
  - `wpctl set-default <id>` (or route the ES8336 hardware sink through it in a WirePlumber rule).
  The 3.5mm headphone path is not touched.
- **RNNoise mic**: creates a virtual source named `rnnoise_source_d330` fed from
  `capture.d330_rnnoise`. Select it as the default input (`wpctl set-default <id>`) to denoise the
  internal DMIC array.

## Dependencies
- The mic graph needs the LADSPA plugin `librnnoise_ladspa.so`. No distro packages it (the base
  RNNoise library ships, not the LADSPA plugin). Build it with
  `scripts/build_rnnoise_ladspa.sh --install` (installs into `/usr/lib/ladspa`). The dependency is
  OPTIONAL: the filter-chain module is loaded with `flags = [ nofail ]`, so a host without the
  plugin keeps running and the denoiser stays inactive.
- Only the widely supported `VAD Threshold (%)` control is set. The VAD grace-period controls are
  version-dependent (present only in newer librnnoise builds) and are intentionally omitted so the
  graph also loads against older packages.

## Verification
- `scripts/test_audio_dsp.sh --dry-run` validates the speaker graph structure.
- `scripts/test_mic_rnnoise.sh --probe` fails closed (non-zero) when `librnnoise_ladspa.so` is
  absent; `scripts/test_mic_rnnoise.sh --dry-run` validates the RNNoise graph structure.
