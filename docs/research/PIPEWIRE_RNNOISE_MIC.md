# Research: PipeWire RNNoise AI Microphone Suppression on Lenovo D330-10IGL

## 1. Physical Acoustic Limitations
The Lenovo IdeaPad D330-10IGL embeds two digital microphones (DMIC array) directly into the tablet bezel.
Because of the thin plastic chassis:
- Taps on the screen or keyboard dock travel directly through the frame into the mic capsules.
- Placing the tablet on a desk or handling it by the sides introduces low-frequency hollow rumble and scratch sounds.

## 2. RNNoise Neural Network Filter
`RNNoise` is a lightweight recurrent neural network (RNN / GRU) trained specifically to distinguish human voice from non-stationary background noise.
- Integrated natively into PipeWire via `libpipewire-module-filter-chain` and `librnnoise_ladspa.so`.
- The LADSPA plugin `librnnoise_ladspa.so` is not distro-packaged (Debian/Ubuntu `librnnoise0`, Arch `rnnoise` ship only the base library). This repo builds it from a pinned source release: `scripts/build_rnnoise_ladspa.sh --install`, or `scripts/install_dkms.sh --install --with-rnnoise` to do it during install. The load is optional: the module carries `flags = [ nofail ]`, so PipeWire keeps running without it.
- CPU consumption is less than **0.8%** on Gemini Lake.
- Produces a virtual input source (`Lenovo D330 Clean Microphone (RNNoise AI)`) usable directly in Zoom, Teams, Discord, Google Meet, and browser calls.
