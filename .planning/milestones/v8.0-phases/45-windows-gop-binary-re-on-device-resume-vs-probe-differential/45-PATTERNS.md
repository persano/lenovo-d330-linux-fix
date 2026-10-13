# Phase 45: Windows/GOP Binary RE + On-Device Resume-vs-Probe Differential - Pattern Map

## Metadata
- Files classified: 6 new, 1 modified
- Generated: 2026-10-12
- Codebase: lenovo-d330-linux-screen-fix @ milestone v8.0

## File Classification

| File | Status | Task | Trust tier |
|------|--------|------|-----------|
| `docs/dumps/re_kit/` (new, gitignored artifacts + manifest) | new | 45-01-T1 | local-only |
| `docs/research/GOP_DSI_RE_FINDINGS.md` (new, doc / RE findings) | new | 45-01-T2, T3 | evidence doc |
| `docs/research/RESUME_VS_RELOAD_DIFFERENTIAL.md` (new, doc / differential evidence) | new | 45-01-T4 | evidence doc |
| `scripts/test_re_diff_evidence.sh` (new, guard suite) | new | 45-01-T4 | test |
| fix kernel patch + branch (new, CI-built) | new | 45-02-T1 | kernel code |
| `docs/research/NO_CLEAN_FIX_PROOF.md` (new, conditional, ROOT-04) | new | 45-02-T2 | evidence doc |
| `CHANGES_AUDIT.md` (modified, count sentence) | modified | 45-01-T4 | audit |

## Pattern Assignments

### `docs/research/GOP_DSI_RE_FINDINGS.md` (new, doc / RE findings)
**Analog:** `docs/research/DSI_RESUME_TRACE_ANALYSIS.md` — evidence doc with
device identity, per-claim citation format `file+offset+bytes`, and the
observation channel recorded. RE claims cite the binary (sha256), the
function/address, and the decompiled snippet — no uncited assertions
(Pitfall: fabricated RE evidence). Background refs to
`docs/windows_analysis/RESUME_SEQUENCE.md` marked as superseded-context.

### `docs/research/RESUME_VS_RELOAD_DIFFERENTIAL.md` (new, doc / differential evidence)
**Analog:** `docs/research/KERNEL_SWEEP_EVIDENCE.md` + the Phase 43 capture
protocol — per-arm command+output excerpts, timestamps, boot ids, and the
instrumentation channel named (ftrace functions, MMIO ranges, backlight
sysfs). Kernel logs alone are NOT evidence (clean logs established).

### `scripts/test_re_diff_evidence.sh` (new, guard suite)
**Analog:** `scripts/test_safety_kit.sh` — fixture guard suite (pristine
first, no system mutation), asserting the evidence docs' machine-checkable
shape: RE citations present, differential arm structure, VBT decode section,
D330 identity blocks. Wired into the harness bash-n list + chain after the
safety kit suite.

### `docs/dumps/re_kit/` (new, kit)
**Analog:** `docs/dumps/safety_kit/` — artifacts gitignored, manifest
committable, registered/verified via the existing
`scripts/prepare_safety_kit.sh --register/--verify` (Phase 43 pipeline).

### Fix kernel patch + branch (new, kernel code)
**Analog:** the existing CI flow that produced `7.0.14-d330-fix`
(`.github/workflows/build-kernel.yml`) and the Option 2 PPS clamp precedent
(already in `intel_pps.c` on device). DMI gate lands in
`drivers/gpu/drm/i915/display/intel_quirks.c`-style table or the targeted
resume path, gated on the `82H0` DMI string; deploy via the Phase 43
rollback pipeline (strip → zstd → deploy → depmod → initramfs → reboot).

## Shared Patterns

### 1. Evidence docs carry device identity + verbatim commands
Same as Phase 44 shared pattern 1 (DSI doc precedent).
### 2. Kit pipeline for binary artifacts
Binaries never committed; manifest via prepare_safety_kit.sh; sha256 on
every artifact (Phase 43 precedent).
### 3. planner-discipline-allow for quoted levers
Research docs quoting banned-lever strings carry per-string markers.
### 4. Fix verification is register/sysfs-based
Panel verdicts from user eyes are ruled out (Phase 44); acceptance uses
backlight sysfs + ftrace evidence (ROOT-02/03).
