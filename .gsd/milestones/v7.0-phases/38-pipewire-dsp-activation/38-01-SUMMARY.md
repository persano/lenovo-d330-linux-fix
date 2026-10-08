---
phase: 38
plan: 01
subsystem: pipewire-dsp-activation
tags: [pipewire, filter-chain, rnnoise, ladspa, dsp, honesty, installer-symmetry]
dependency_graph:
  requires: []
  provides:
    - "valid D330 speaker EQ filter-chain graph loaded from pipewire.conf.d"
    - "valid D330 RNNoise LADSPA mic graph loaded from pipewire.conf.d"
    - "non-vacuous scripts/test_audio_dsp.sh --dry-run structure validator"
    - "scripts/test_mic_rnnoise.sh D330_LADSPA_DIRS seam with fail-closed plugin probe (SC2)"
  affects:
    - "scripts/install_dkms.sh manifest/install/uninstall path (filter-chain.conf.d -> pipewire.conf.d)"
    - "scripts/test_storage_cellular.sh aggregate dry-run runner"
    - "CHANGES_AUDIT.md sections 4.3 and 7.5 (routing honesty + node names)"
    - "patches/audio_dsp/README.md (honest routing + dependency docs)"
tech-stack:
  added: []
  patterns:
    - "libpipewire-module-filter-chain with inlined filter.graph.nodes + explicit links"
    - "builtin bq_highpass / bq_peaking / clamp control vocabulary (no biquad Type, no limiter)"
    - "D330_LADSPA_DIRS colon+glob env seam for fail-closed LADSPA plugin probing"
key-files:
  created:
    - patches/audio_dsp/etc/pipewire/pipewire.conf.d/50-lenovo-d330-speaker-dsp.conf
    - patches/audio_dsp/etc/pipewire/pipewire.conf.d/51-lenovo-d330-rnnoise-mic.conf
  modified:
    - scripts/install_dkms.sh
    - scripts/test_audio_dsp.sh
    - scripts/test_mic_rnnoise.sh
    - scripts/test_storage_cellular.sh
    - CHANGES_AUDIT.md
    - patches/audio_dsp/README.md
  deleted:
    - patches/audio_dsp/etc/pipewire/filter-chain.conf.d/50-lenovo-d330-speaker-dsp.conf
    - patches/audio_dsp/etc/pipewire/filter-chain.conf.d/51-lenovo-d330-rnnoise-mic.conf
decisions:
  - "Ship both fragments under pipewire.conf.d (the running daemon's read path); the legacy filter-chain.conf.d location is only read by `pipewire -c filter-chain.conf`."
  - "Inline each filter.graph (no shared top-level filter_chain.nodes) so one file cannot clobber the other."
  - "Replace the nonexistent `limiter` builtin with the builtin `clamp` and drop the invalid `biquad`/\"Type\" vocabulary."
  - "Downgrade the routing claim to honest virtual-sink/source selection instead of shipping untested WirePlumber rerouting."
  - "Enforce SC2 by making the RNNoise probe exit non-zero when librnnoise_ladspa.so is absent, proven via a fake LADSPA dir."
metrics:
  duration: "~15 min"
  completed: 2026-10-08
  tasks: 5
  files_changed: 10
status: complete
actuals:
  tokens: 7974
  tasks: 5
  commits: 5
---

# Phase 38 Plan 01: PipeWire DSP Activation Summary

The D330 speaker EQ and RNNoise mic graphs now ship valid and loadable from `/etc/pipewire/pipewire.conf.d/`, the two echo-only harnesses became non-vacuous validators with SC2 fail-closed, and the routing claim was downgraded to an honest virtual-sink/source selection model.

## What Was Built

### Task 1 — Valid speaker DSP graph in `pipewire.conf.d`
- New `patches/audio_dsp/etc/pipewire/pipewire.conf.d/50-lenovo-d330-speaker-dsp.conf`: one `libpipewire-module-filter-chain` module with an inlined `filter.graph.nodes` chain — `bq_highpass` (Freq 130 / Q 0.707), two `bq_peaking` (2800 Hz Q1.2 +3.5 dB, 8000 Hz Q1.0 +2.0 dB) and a builtin `clamp` (Min/Max ±0.8414 ≈ -1.5 dBFS) replacing the nonexistent `limiter`.
- Explicit `links` chain each node `Out` -> next `In`; no top-level `filter_chain.nodes` shared variable.
- `capture.props` `media.class = Audio/Sink`, `node.name = effect_input.d330_speaker_dsp`; `playback.props` `node.name = effect_output.d330_speaker_dsp`, `node.passive = true`, `audio.channels = 2`, `audio.position = [ FL FR ]`.

### Task 2 — Valid RNNoise graph + dependency doc
- New `patches/audio_dsp/etc/pipewire/pipewire.conf.d/51-lenovo-d330-rnnoise-mic.conf`: inlined single `ladspa` node (`plugin = librnnoise_ladspa`, `label = noise_suppressor_mono`) with only the widely supported `"VAD Threshold (%)"` control.
- `capture.props.node.name = capture.d330_rnnoise` (`node.passive = true`); `playback.props.node.name = rnnoise_source_d330`, `media.class = Audio/Source`, `audio.rate = 48000`.
- Header comment documents the `librnnoise-ladspa` package dependency and that the VAD grace controls are version-dependent and intentionally omitted.
- Both legacy `filter-chain.conf.d/50,51` files deleted.

### Task 3 — Installer/manifest/packager path move
- `scripts/install_dkms.sh`: manifest entries, install `mkdir -p`/`cp` sources and destinations, and uninstall `rm -f` all moved to `/etc/pipewire/pipewire.conf.d/`; uninstall keeps a guarded `rm -f` of the legacy `filter-chain.conf.d` paths for migration.
- `packaging/debian/rules`, `packaging/rpm/lenovo-d330-fix.spec`, `packaging/arch/PKGBUILD` required no change — they install patch trees via wildcards (verified: no `filter-chain.conf.d` reference present).
- Installer symmetry guard suite green (17/0); `bash -n` clean.

### Task 4 — Honest DSP + RNNoise harnesses (SC2)
- `scripts/test_audio_dsp.sh --dry-run` now validates the speaker conf structure (present under `pipewire.conf.d`, has `bq_highpass`/`bq_peaking`/`clamp`/`links`/`effect_input.d330_speaker_dsp`, no `label = biquad`/`label = limiter`/`"Type"`, legacy copy gone), prints `passed=/failed=` and exits non-zero on any failure.
- `scripts/test_mic_rnnoise.sh` gained the `D330_LADSPA_DIRS` seam (colon-separated, glob allowed; default `/usr/lib/ladspa:/usr/lib/*/ladspa`), a fail-closed `[FAIL]` + non-zero probe when `librnnoise_ladspa.so` is absent, and a static `--dry-run` graph validator.

### Task 5 — Honesty docs + aggregate runner wiring
- `CHANGES_AUDIT.md` §4.3: replaced the "only targets the internal speakers ... leaving 3.5mm uncolored" claim with the honest virtual-sink selection model and the daemon read path; §7.5 node name corrected to `rnnoise_source_d330`; deploy table rows repointed to `pipewire.conf.d`.
- `patches/audio_dsp/README.md`: honest description, how to select the DSP sink/source (`wpctl set-default`), the `librnnoise-ladspa` dependency, and the version-dependent VAD note.
- `scripts/test_storage_cellular.sh`: aggregate dry-run now runs `test_audio_dsp.sh --dry-run` and asserts the RNNoise probe fails closed with the plugin absent.

## Commits

| # | Hash | Message | Files |
|---|------|---------|-------|
| 1 | `152676a` | fix(38): ship valid D330 speaker DSP graph under pipewire.conf.d | new 50-...conf |
| 2 | `e80e223` | fix(38): ship valid D330 RNNoise graph, drop legacy filter-chain.conf.d fragments | new 51-...conf, deleted 50/51 legacy confs |
| 3 | `0b1c2bd` | fix(38): install DSP fragments to pipewire.conf.d, drop inert filter-chain.conf.d path | scripts/install_dkms.sh |
| 4 | `3d4d700` | test(38): make DSP dry-run structural and enforce RNNoise SC2 with D330_LADSPA_DIRS | test_audio_dsp.sh, test_mic_rnnoise.sh |
| 5 | `36f2f9f` | docs(38): honest DSP routing and wire audio/RNNoise guards into aggregate runner | CHANGES_AUDIT.md, README.md, test_storage_cellular.sh |

The two legacy configs were pre-staged with `git add -A` and landed in commit 2 via a directory pathspec (`patches/audio_dsp/etc/pipewire/filter-chain.conf.d`), because gsd-tools `--files` skips deleted paths and a filename pathspec would exclude the deletions.

## Verification (raw results)

- Task 1: `SPEAKER-GRAPH-OK` (rc 0).
- Task 2: `RNNOISE-GRAPH-OK` (rc 0).
- Task 3: `INSTALLER-OK`; symmetry `passed=17 failed=0`; `bash -n scripts/install_dkms.sh` rc 0.
- Task 4: `DSP-DRYRUN-OK` (11/0); plugin present rc 0 (`PLUGIN-PRESENT-RC0`); plugin absent `missing_plugin_rc=1` with `[FAIL]`.
- Task 5: `DOCS-AND-RUNNER-OK`; `RUNNER-BASHN-OK`.
- Final gate run: installer symmetry 17/0, hibernate 21/0, display-fix 10/0, microsd 26/0, noop 5/0, audio DSP structure 11/0, RNNoise probe present rc 0 / absent rc 1 — all as expected.
- Aggregate `bash scripts/test_storage_cellular.sh --dry-run` rc 0 with the new checks included.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Corrected §7.5 node name drift**
- **Found during:** Task 5
- **Issue:** `CHANGES_AUDIT.md` §7.5 still described a virtual mic node `lenovo_d330_clean_mic`, which no config ships; the actual graph exposes `rnnoise_source_d330`.
- **Fix:** Reworded the §7.5 bullets and repointed the conf path to `pipewire.conf.d`, consistent with the plan's honesty goal.
- **Files modified:** CHANGES_AUDIT.md

**2. [Process] Legacy deletions folded into the Task 2 commit**
- **Found during:** Task 1/2 commits
- **Issue:** gsd-tools `--files` skips non-existent paths, so a deleted file cannot enter the commit pathspec and a filename pathspec silently excludes it.
- **Fix:** Staged the removals with `git add -A` and committed them under a directory pathspec in commit 2; Task 1's commit therefore contains only the new speaker graph.
- **Files:** patches/audio_dsp/etc/pipewire/filter-chain.conf.d (both files).

## Threat Flags

None — config-only graph fragments plus test harnesses; no new network, auth, or trust-boundary surface.

## Known Stubs

None.

## Deferred / Out of Scope

- SC1 (`pw-dump` shows `d330_speaker_dsp` and `rnnoise_source_d330` after a daemon restart) is hardware/daemon-only: this host has no PipeWire daemon. SC2 is machine-checked above; SC1 remains a documented hardware override.
- Automatic WirePlumber routing of the hardware sink through the DSP, and VAD grace tuning, remain deferred (documented in README/CHANGES_AUDIT).

## Self-Check: PASSED

- Created files exist: patches/audio_dsp/etc/pipewire/pipewire.conf.d/50-lenovo-d330-speaker-dsp.conf, 51-lenovo-d330-rnnoise-mic.conf
- Deleted files absent: patches/audio_dsp/etc/pipewire/filter-chain.conf.d/50-lenovo-d330-speaker-dsp.conf, 51-lenovo-d330-rnnoise-mic.conf
- Commits exist: 152676a, e80e223, 0b1c2bd, 3d4d700, 36f2f9f
