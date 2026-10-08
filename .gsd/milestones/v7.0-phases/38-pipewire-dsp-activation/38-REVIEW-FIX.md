---
phase: 38
fixed_at: 2026-10-08T17:51:30Z
review_path: (inline findings supplied with the fixer task; no 38-REVIEW.md on disk)
iteration: 1
findings_in_scope: 8
fixed: 8
skipped: 0
status: all_fixed
---

# Phase 38: Code Review Fix Report

**Fixed at:** 2026-10-08T17:51:30Z
**Source review:** findings provided inline with the fixer task (no `38-REVIEW.md` exists in the phase directory)
**Iteration:** 1

**Summary:**
- Findings in scope: 8
- Fixed: 8
- Skipped: 0

## Fixed Issues

### CR-01: RNNoise module can take PipeWire startup down when the optional plugin is absent

**Files modified:** `patches/audio_dsp/etc/pipewire/pipewire.conf.d/51-lenovo-d330-rnnoise-mic.conf`, `scripts/install_dkms.sh`
**Commit:** `c8d86a3`
**Applied fix:** Added `flags = [ nofail ]` to the `libpipewire-module-filter-chain` module entry (matching upstream `source-rnnoise.conf`) so a host without `librnnoise-ladspa` cannot fail the daemon's startup. Documented the optional dependency in the header comment. In `scripts/install_dkms.sh` `check_prerequisites()`, added a named `log_warn` (plus an `[OK]` when present) that searches the same paths `scripts/test_mic_rnnoise.sh` uses (`/usr/lib/ladspa:/usr/lib/*/ladspa`) so a missing plugin is surfaced rather than silent.

### WR-02: Speaker DSP dry-run passed on a broken graph

**File modified:** `scripts/test_audio_dsp.sh`
**Commit:** `fe37e98`
**Applied fix:** Added non-vacuous structural assertions: `context.modules = [` present, `filter.graph = {` present, braces/brackets balanced (`conf_balanced`), `effect_output.d330_speaker_dsp` present, the `clamp` node declares both `Min` and `Max` (`clamp_controls_ok`), and every `links` `output`/`input` endpoint names a declared node (`links_nodes_declared`). Summary is now passed=17 failed=0 with non-zero exit on any violation.

### WR-03: Aggregate runner never ran the RNNoise dry-run

**File modified:** `scripts/test_storage_cellular.sh`
**Commit:** `ffc6985`
**Applied fix:** Added `bash scripts/test_mic_rnnoise.sh --dry-run` to the aggregate `--dry-run` check list (its non-zero exit propagates under `set -e`).

### WR-04: Negative check only rejected one of the two legacy VAD controls

**File modified:** `scripts/test_mic_rnnoise.sh`
**Commit:** `0d56080`
**Applied fix:** Widened the negative assertion to `grep -qE 'Retroactive VAD Grace|VAD Grace Period'`, so reintroducing either legacy control alone now fails the dry-run.

### WR-05: No packager shipped `patches/*/etc/pipewire/**`

**Files modified:** `packaging/debian/rules`, `packaging/rpm/lenovo-d330-fix.spec`, `packaging/arch/PKGBUILD`
**Commit:** `4e14adc`
**Applied fix:** Debian: `mkdir -p` + `cp patches/audio_dsp/etc/pipewire/pipewire.conf.d/*.conf` into `debian/lenovo-d330-fix/etc/pipewire/pipewire.conf.d/` (dh_install picks it up from the debian/<pkg> tree). RPM: added the dir + `cp` in `%install` and `/etc/pipewire/pipewire.conf.d/*` to `%files`. Arch: `install -d` + `install -m 644` in `package()`. Styles mirror the existing config-tree handling in each recipe.

### WR-06: Syntax-gate loop omitted the two audio scripts

**File modified:** `scripts/test_storage_cellular.sh`
**Commit:** `ffc6985`
**Applied fix:** Added `scripts/test_audio_dsp.sh` and `scripts/test_mic_rnnoise.sh` to the `bash -n` loop (both report `[OK]`).

### WR-07: SC2 assertion counted any non-zero exit as pass

**File modified:** `scripts/test_storage_cellular.sh`
**Commit:** `ffc6985`
**Applied fix:** Captured the probe's combined output and now require BOTH a non-zero exit AND the `librnnoise_ladspa.so not found` diagnostic; a missing/crashing script (non-zero without that line) is failed. The RNNoise `--dry-run` structure check also runs in the same aggregate path.

### WR-08: Copy-pasted `ck`/`ckn` validator in the RNNoise script

**Files modified:** `scripts/lib_conf_check.sh` (new), `scripts/test_audio_dsp.sh`, `scripts/test_mic_rnnoise.sh`
**Commits:** `fe37e98`, `0d56080`
**Applied fix:** Extracted the `ck`/`ckn` PASS/FAIL helpers into a tiny sourced helper `scripts/lib_conf_check.sh`; both validators now `source "${SCRIPT_DIR}/lib_conf_check.sh"` and keep their `local pass=0 fail=0` counters (bash dynamic scoping lets the helpers mutate them). Behavior unchanged; both dry-runs still pass.

## Skipped Issues

None — all findings were fixed.

---

_Fixed: 2026-10-08T17:51:30Z_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 1_
