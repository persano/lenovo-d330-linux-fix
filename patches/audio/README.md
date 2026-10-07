# Audio & Microphone UCM Profiles

This directory packages ALSA Use Case Manager (UCM2) profiles and kernel audio options for the Lenovo IdeaPad D330-10IGL (`82H0`) and D330-10IGM (`81H3`, `81MD`).

## Contents

- `ucm2/sof-essx8336/sof-essx8336.conf`: Master ALSA UCM2 card profile.
- `ucm2/sof-essx8336/HiFi.conf`: HiFi usecase definitions (Speaker, Headphones, Mic, Headset).
- `etc/modprobe.d/lenovo-d330-audio.conf`: Kernel audio driver options forcing SOF DSP driver (`dsp_driver=3`), DMIC count, and ES8316 quirks.

Audio testing is handled by `scripts/test_audio_profiles.sh`.
