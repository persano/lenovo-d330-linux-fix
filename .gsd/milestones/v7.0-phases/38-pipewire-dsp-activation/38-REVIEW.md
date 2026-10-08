---
phase: 38-pipewire-dsp-activation
reviewed: 2026-10-08
reviewer: gsd-code-reviewer (diff 4e6c297..HEAD)
status: all findings fixed (see 38-REVIEW-FIX.md)
---

# Phase 38 Code Review

| # | Sev | Location | Finding | Status |
|---|-----|----------|---------|--------|
| 1 | CRITICAL | `patches/.../51-lenovo-d330-rnnoise-mic.conf:18` | Optional RNNoise module lacked `flags = [ nofail ]`, so a host without `librnnoise-ladspa` could fail PipeWire startup entirely. | FIXED c8d86a3 (+ installer `log_warn` on missing plugin) |
| 2 | MEDIUM | `scripts/test_audio_dsp.sh:99-108` | Dry-run was substring-grep only; a structurally broken graph still passed. | FIXED fe37e98 (brace balance, link-endpoint/node-name checks, clamp Min/Max) |
| 3 | MEDIUM | `scripts/test_storage_cellular.sh:96` | Aggregate runner never ran the RNNoise dry-run. | FIXED ffc6985 |
| 4 | LOW | `scripts/test_mic_rnnoise.sh:109` | Negative check missed the other legacy control `VAD Grace Period`. | FIXED 0d56080 |
| 5 | LOW | `packaging/{debian/rules:5,rpm spec:34,arch PKGBUILD:13}` | No packager shipped `etc/pipewire/**`, so DSP fragments were absent from packages. | FIXED 4e14adc |
| 6 | LOW | `scripts/test_storage_cellular.sh:59` | `bash -n` loop omitted the two audio scripts. | FIXED ffc6985 |
| 7 | LOW | `scripts/test_storage_cellular.sh:101` | SC2 assertion treated any non-zero exit as pass. | FIXED ffc6985 (requires non-zero + `[FAIL]` line) |
| 8 | LOW | `scripts/test_mic_rnnoise.sh:86` | Duplicated `ck`/`ckn` validator. | FIXED fe37e98 (`scripts/lib_conf_check.sh` shared helper) |

Clean categories: graph syntax valid (builtin labels/controls, real `In`/`Out` links, inlined nodes); `context.modules` under `pipewire.conf.d/` correct per pipewire.conf(5); SC2 empirically verified (absent -> rc 1, present -> rc 0); installer path consistency + symmetry 17/0; no shell injection/quoting hazards.
