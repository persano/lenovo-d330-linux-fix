---
phase: 38-pipewire-dsp-activation
uat: 2026-10-08
status: passed
score: 3/3 tests (2 machine-checked, 1 overridden pending hardware)
overrides_applied: 1
note: |
  38-VERIFICATION.md: 3/3 must-haves verified (SC1 hardware/daemon overridden).
  Machine proofs: dsp dry-run 17/0, rnnoise dry-run 7/0, SC2 fails closed (absent
  plugin -> rc 1 with [FAIL]; fake plugin -> rc 0). Suites: symmetry 17/0, hibernate
  21/0, display 10/0, microsd 26/0, noop 5/0, storage --dry-run rc 0.
  Live pw-dump deferred: re-surface /gsd-verify-work 38.
audit_acknowledged:
  milestone: v7.0
  at: 2026-10-08
  gap_snapshot: "passed::scenarios=0"
---

## Tests

### 1. SC1: live daemon loads both nodes (on-device)

expected: |
  After install + `systemctl --user restart pipewire pipewire-pulse wireplumber`,
  `pw-dump | grep -E 'd330_speaker_dsp|rnnoise_source_d330'` shows both nodes; `wpctl status`
  lists the DSP sink/source; the RNNoise module loads without crashing when the plugin is absent.
result: [pass] note: |
  Deferred under VERIFICATION override[0] (no PipeWire daemon here). Machine half green:
  fragments under /etc/pipewire/pipewire.conf.d/, valid graphs, flags=[nofail], packagers ship the dir.

### 2. SC2: missing RNNoise plugin fails closed

expected: |
  With `librnnoise_ladspa.so` absent the RNNoise test exits non-zero.
result: [pass] note: |
  `D330_LADSPA_DIRS=/nonexistent-empty-ladspa scripts/test_mic_rnnoise.sh --probe` -> rc 1 with
  `[FAIL] librnnoise_ladspa.so not found`; fake plugin dir -> rc 0. Aggregate runner asserts both
  the non-zero exit and the [FAIL] line.

### 3. Valid graphs deployed where the server reads them

expected: |
  Speaker + RNNoise filter-chain fragments are valid and under pipewire.conf.d/ (not filter-chain.conf.d/).
result: [pass] note: |
  `test_audio_dsp.sh --dry-run` 17/0 and `test_mic_rnnoise.sh --dry-run` 7/0: valid builtin labels,
  controls, explicit links naming declared nodes, inlined nodes, no biquad/limiter/"Type"; legacy
  filter-chain.conf.d/ copies removed; installer manifest/install/uninstall moved to pipewire.conf.d/.
