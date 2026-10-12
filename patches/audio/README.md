# Audio & Microphone UCM Profiles

This directory packages ALSA Use Case Manager (UCM2) profiles and kernel audio options for the Lenovo IdeaPad D330-10IGL (`82H0`) and D330-10IGM (`81H3`, `81MD`).

## Contents

- `ucm2/sof-essx8336/sof-essx8336.conf`: Master ALSA UCM2 card profile.
- `ucm2/sof-essx8336/HiFi.conf`: HiFi usecase definitions (Speaker, Headphones, Mic, Headset).
- `etc/modprobe.d/lenovo-d330-audio.conf`: Kernel audio driver options. Applies the ALC256 headset-mic fixup (`snd_hda_intel model=headset-mic,auto`), plus DMIC count and ES8316 quirks that are inert on this board.

  Do **not** add `options snd_intel_dspcfg dsp_driver=3`. The controller enumerates as PCI `class 0x040300`, SOF rejects that class and refuses to probe, and the result is no sound card at all. Auto-detection already selects the legacy `snd_hda_intel` driver that the ALC256 needs. See `docs/research/AUDIO_UCM_TOPOLOGY.md`.

Audio testing is handled by `scripts/test_audio_profiles.sh`.
