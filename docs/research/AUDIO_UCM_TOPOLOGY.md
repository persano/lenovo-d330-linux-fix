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
   - The Intel **SST** driver (`snd_soc_skl`, `dsp_driver=2`) fails to correctly clock the Gemini Lake DMIC interface, yielding 0-byte recordings or silent noise.
   - This is *not* a reason to force SOF. On this machine the HDA controller enumerates as PCI `class 0x040300`, which `snd_intel_dsp_driver_probe()` (`sound/hda/core/intel-dsp-config.c`) maps to `SND_INTEL_DSP_DRIVER_LEGACY`. SOF then rejects the device outright at `sound/soc/sof/intel/hda.c`: *"the DSP is not enabled on this platform, aborting probe"*. See section 3.

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

**Do not force `snd_intel_dspcfg dsp_driver=3`.** That was shipped once and it
zeroed audio completely:

- The controller is PCI `8086:3198` and enumerates as `class 0x040300`
  ("no DSP present"). `snd_intel_dsp_driver_probe()` honours a forced
  `dsp_driver` at the top of the function, *before* it ever inspects that
  class, so `dsp_driver=3` routed the device to SOF.
- SOF's `hda_dsp_probe_early()` checks the same class itself and aborts with
  `-ENODEV`, while `snd_hda_intel` stood down because SOF was selected.
- Net effect: `0000:00:0e.0` bound to no driver at all and
  `aplay -l` reported `no soundcards found`. The PCI class is firmware-set and
  identical on every boot, so this was reproducible, not a resume artifact.

With the option removed, auto-detection returns
`SND_INTEL_DSP_DRIVER_LEGACY` for `0x040300` and the codec comes up normally:

```
snd_hda_intel 0000:00:0e.0: bound 0000:00:02.0 (ops intel_audio_component_bind_ops [i915])
snd_hda_codec_alc269 hdaudioC0D0: ALC256: picked fixup headset-mic (model specified)
snd_hda_codec_alc269 hdaudioC0D0: autoconfig for ALC256: line_outs=1 (0x14/0x0/0x0/0x0/0x0) type:speaker
```

So on this board the codec is a **Realtek ALC256 on the HDA link**, not an
ES8316/ES8336 on I2S, and the legacy `snd_hda_intel` driver is the correct one.

Remaining options in the file:

- `options snd_hda_intel model=headset-mic,auto enable=1,1` — applies the
  ALC256 headset-mic fixup and is the option that actually matters here.
- `options snd_soc_sof_intel_hda_common dmic_num=2` and
  `options snd_soc_es8316 quirk=0x0013` — inert: they target modules that no
  longer load on this hardware. Kept only so a future board revision with the
  ES8316 picks them up; harmless while SOF stays unbound.

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
