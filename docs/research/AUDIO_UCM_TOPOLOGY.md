# Lenovo IdeaPad D330: Audio Routing & ALSA UCM2 Topology

## 1. Hardware Architecture & Problem Analysis

The Lenovo IdeaPad D330-10IGL (`82H0`) and D330-10IGM (`81H3`, `81MD`) integrate an Intel Gemini Lake audio DSP subsystem (PCI `8086:3198`) coupled with digital microphones (DMIC) and an I2S / HDA audio codec.

### Audio Stack Breakdown
- **DSP Engine**: Intel Smart Sound Technology (SST) / Sound Open Firmware (SOF).
- **Codecs**:
  * Everest Semi `ES8316` / `ES8336` (`ESSX8336:00` ACPI ID).
  * Realtek `ALC269` / `ALC255` variants on certain motherboard revisions.
- **Microphone**: Dual digital PCH microphones (DMIC0 and DMIC1).
- **Headphone Jack**: 3.5mm 4-pole TRRS combo jack with mechanical sense switch.

### Common Linux Failure Modes
1. **Missing UCM2 Profile**:
   - Modern sound servers (PipeWire, PulseAudio) rely on ALSA Use Case Manager (UCM2) to identify endpoints.
   - Without a machine-specific UCM2 profile matching the card identifier (`sof-essx8336` or `HDA Intel PCH`), the system defaults to "Dummy Output" or presents raw ALSA hardware channels without volume curve calibration.
2. **Headphone Auto-Mute**:
   - In raw ALSA mode, plugging in headphones plays audio simultaneously through both internal speakers and headphones. Jack sensing pins fail to trigger hardware mute (`JackHWMute`).
3. **Internal DMIC Silence**:
   - Legacy Intel SST driver (`snd_soc_skl`) fails to correctly clock the Gemini Lake DMIC interface, yielding 0-byte recordings or silent noise. SOF (`snd_intel_dspcfg dsp_driver=3`) is mandatory.

---

## 2. UCM2 Profile Architecture

The provided profile (`patches/audio/ucm2/sof-essx8336/`):
- Defines the `HiFi` use case syntax version 4.
- Configures endpoints:
  * `Speaker`: Internal stereo transducers with default 85% gain.
  * `Headphones`: 3.5mm stereo output with priority 200, linked to `JackControl "Headphone Jack"` and `JackHWMute "Speaker"`.
  * `Mic`: Internal dual DMIC array with capture gain calibration.
  * `Headset`: 3.5mm TRRS input with `JackControl "Headset Mic Jack"`.

---

## 3. Kernel Configuration (`lenovo-d330-audio.conf`)

- Enforces `options snd_intel_dspcfg dsp_driver=3` to guarantee SOF DSP stack initialization.
- Informs SOF of the dual DMIC hardware configuration (`options snd_soc_sof_intel_hda_common dmic_num=2`).
- Configures Everest Semi codec quirks (`options snd_soc_es8316 quirk=0x0013`).

---

## 4. Verification

Test audio functionality via `scripts/test_audio_profiles.sh`:
```bash
# Probe audio hardware and sound server status
bash scripts/test_audio_profiles.sh --probe

# Test internal speakers playback
bash scripts/test_audio_profiles.sh --test-speakers

# Test internal microphone capture
bash scripts/test_audio_profiles.sh --test-mic

# Monitor headphone jack insertion/removal
bash scripts/test_audio_profiles.sh --monitor-jack
```
