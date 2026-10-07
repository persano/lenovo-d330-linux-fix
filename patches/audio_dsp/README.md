# Audio DSP Refinements for Lenovo IdeaPad D330-10IGL

Contains PipeWire acoustic compensation filter-chain presets and ALSA DAC anti-pop latency configurations.

## File Hierarchy
- `etc/pipewire/filter-chain.conf.d/50-lenovo-d330-speaker-dsp.conf`: High-pass biquad, dialogue peak EQ, and anti-clipping limiter.
- `etc/modprobe.d/lenovo-d330-audio-antipop.conf`: ALSA power ramp delay parameters.
- `etc/udev/rules.d/91-lenovo-d330-headset-jack.rules`: Headset input jack event routing.
