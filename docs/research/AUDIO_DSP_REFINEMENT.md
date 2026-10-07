# Research: Audio DSP Curves & Anti-Pop Jack Delay on Lenovo D330-10IGL

## 1. Acoustic Limitations of Tablet Chassis
The Lenovo IdeaPad D330-10IGL houses two miniature 1.0W speakers firing downwards/outwards from the tablet tablet chassis.
Without digital signal processing (which Windows OEM drivers apply via Dolby Audio / Conexant / Realtek software APOs):
1. **Chassis Resonance & Distortion**: Low frequencies below 130 Hz cause physical membrane over-excursion and harsh plastic buzzing.
2. **Speech Intelligibility**: Mid-range frequencies around 2.5 kHz - 3.5 kHz are muffled due to small port apertures.
3. **Clipping**: High volume media peaks trigger digital and analog clipping.

## 2. PipeWire Filter-Chain DSP Architecture
We implement an equivalent DSP pipeline via native PipeWire filter-chain (`50-lenovo-d330-speaker-dsp.conf`):
1. **High-Pass Biquad (130 Hz, Q=0.707)**: Safely filters sub-bass out of the physical speakers.
2. **Parametric Peaking EQ (2800 Hz, Q=1.2, +3.5 dB)**: Restores dialogue presence and movie vocal clarity.
3. **High-Shelf / Peaking EQ (8000 Hz, Q=1.0, +2.0 dB)**: Adds air and crispness to treble.
4. **Fast Peak Limiter (-1.5 dBFS ceiling, 50ms release)**: Prevents clipping at 100% volume.

## 3. Headphone Jack Pop Elimination
When Linux enters audio power-saving mode, the DAC is powered down. Upon playing a new notification or audio stream, sudden power restoration introduces a DC offset surge into high-sensitivity earphones, audible as an uncomfortable "pop" or "click".
We address this via `lenovo-d330-audio-antipop.conf`:
- `snd_soc_core pmdown_time=1000`: Delays power collapse by 1 second, keeping the DAC powered between sequential sounds.
- `power_save_node_latency=1000`: Allows internal charge pump capacitor soft ramp-down before shutoff.
