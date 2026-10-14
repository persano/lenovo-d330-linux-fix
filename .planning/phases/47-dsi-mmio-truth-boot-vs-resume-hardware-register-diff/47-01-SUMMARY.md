---
plan: 47-01
phase: 47-dsi-mmio-truth-boot-vs-resume-hardware-register-diff
status: complete
deferred_commit: false
completed: 2026-10-14
---

# 47-01-SUMMARY: DSI dump debugfs node + CI-built dump kernel

## What Was Built

Additive i915 instrumentation for the D330 (82H0): a `i915_dsi_regs` debugfs snapshot
node (write=trigger, read=frozen 256 KB dump, zero register writes) gated on
`bxt_dsi_pll_is_enabled()` to honor the machine-hang rule, covering the 5 locked MMIO
ranges plus the 21-row named overlay; wired into CI (`build-kernel.yml`) with 2 new
grep anchors, built and secured as a `.deb` artifact.

## Tasks

| # | Task | Status | Proof |
|---|------|--------|-------|
| 1 | Tracer — dump-node patch + CI wiring + device compile check | DONE | patch 3 hunks; device compile on `santiago-D330` (`~/d330-kernel/linux-7.0.0`): `git apply --check` OK, `make M=drivers/gpu/drm/i915 modules` exit 0, `intel_dsi_dump_debugfs.o` built (508,928 B), tree reverted clean |
| 2 | Dispatch CI build + secure dump-kernel artifact | DONE | run `38494943266` (branch `instrument/d330-dsi-dump`, sha `30f077c`): SUCCESS; grep-proof verified in log (`i915_dsi_regs` node + `bxt_dsi_pll_is_enabled` gate + both CCS anchors); artifact downloaded + sha256'd |

## Deliverables (branch-held — NOT on main)

Per user-approved branch-only commit (checkpoint decision, 2026-10-14): the two Task-1
files are committed on branch `instrument/d330-dsi-dump`, NOT deferred on main.

| File | Branch commits |
|------|----------------|
| `patches/d330_dsi_dump.patch` | `fdafc43` (feat) → `fb86c6a` (modpost fix: register from i915-only i915_debugfs.c; xe.ko also compiles intel_display_debugfs.c) → `30f077c` (pointer fix: drop `&` — `i915->display` is already `struct intel_display *` in i915_debugfs.c) |
| `.github/workflows/build-kernel.yml` | `fdafc43` (apply step + 2 grep anchors, strictly additive) |

**/gsd-ship must merge/cherry-pick `instrument/d330-dsi-dump` into main** (3 commits:
`fdafc43`, `fb86c6a`, `30f077c`) to land the deliverable on main.

## CI Artifact (47-03 consumes)

- Run: `38494943266` (workflow_dispatch, inputs `kernel_version=7.0.0-38-generic`,
  `ubuntu_release=resolute`)
- URL: https://github.com/persano/lenovo-d330-linux-fix/actions/runs/38494943266
- Artifact: `kernel-deb/` downloaded to
  `C:\Users\Familia\AppData\Local\Temp\opencode\47-artifact\kernel-deb\`
- `linux-image-7.0.14-d330-fix_7.0.14-1_amd64.deb`
  sha256 `ba47df8dd595c87649ce2a91a9e087e9cd90c20e166eee44f302dd1876fe87be`
- `linux-headers-7.0.14-d330-fix_7.0.14-1_amd64.deb`
  sha256 `fa34ef6208e7de93e54b4629f604e82ce049a4999c79c3fae80b664eb828f0b0`
- `kernel.config` sha256
  `6cb18717c6914d4947489eedf8cb69ac23db3faa8ef9b9f563ff02c346dcd32d`

## Key Decisions / Deviations

1. **Checkpoint decision (user-approved):** CI dispatch requires a pushed branch, which
   conflicts with deferred-commit mode. User authorized a branch-only commit
   (`instrument/d330-dsi-dump`); main untouched.
2. **Registration moved to i915-only `i915_debugfs.c`** (deviation, machine-evidenced):
   CI run 38476720516 failed at modpost — `xe.ko` also compiles
   `intel_display_debugfs.c` and hit the undefined `d330_dsi_dump_register`.
   Fix commit `fb86c6a`.
3. **Call-site pointer fix** (deviation, machine-evidenced): run `38486559196` failed at
   `i915_debugfs.c:748` — `&i915->display` passed `struct intel_display **` where the
   prototype wants `struct intel_display *`. Fix commit `30f077c`; run `38494943266`
   green.
4. **Snapshot-at-trigger design preserved:** node writes a frozen buffer at echo time,
   so the ≤18 s window cannot be invalidated by a slow file copy.

## Self-Check

- Ledger gate `scripts/test_pitfalls_ledger.sh`: green (`files=36 hits=0` at plan time;
  re-verified green post-implementation).
- CI grep-proof: all 4 anchors present in built tree (run log `Apply the display fixes
  and prove they landed` step).
- Artifact sha256 recorded above; `.deb` ready for 47-03 deploy.
- `## Self-Check: PASSED`
