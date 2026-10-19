---
phase: 50-tcon-identification-dcs-id-read-instrument-software-only
plan: 50-01
subsystem: kernel-instrument
tags: [i915, dsi, dcs, debugfs, ci, kernel-patch]

requires: []
provides:
  - "patches/d330_dsi_dump.patch extended in place: kstrtouint 0/1/2 write-side parse + d330_dsi_dump_id_reads() with five LP-mode VC-0 port-A DCS/generic reads appended as '# DCS ID READ' section strictly after the named overlay"
  - ".github/workflows/build-kernel.yml grep-proofs for 'DCS ID READ' and 'mipi_dsi_dcs_read' inside the dump-patch apply block"
  - "echo-2 kernel .deb built by CI run 38974632465, downloaded, sha256-secured — deployable artifact for 50-04"
affects: [50-04, 50-05, 51]

actuals:
  tokens: 2900
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "value-trigger debugfs node (echo 0/1/2) with bounded kstrtouint_from_user parse, >2 rejected -EINVAL"
    - "per-read ret + MIPI_INTR_STAT(A) bit-29 (GEN_READ_DATA_AVAIL) post-check + raw-bytes annotation — return value alone never proves an answered read (RX path always returns >= 4)"
    - "PLL-off skip annotation instead of FIFO access (BSpec machine-hang rule); read-only contract, zero register writes"

key-files:
  created: []
  modified:
    - patches/d330_dsi_dump.patch
    - .github/workflows/build-kernel.yml

key-decisions:
  - "CI build (green run incl. apply/grep-proof step) is the load-bearing compile proof; the device-side staged-tree check was not recorded by Task 1 execution — plan explicitly allows this fallback when the staged tree is absent"
  - "Artifact lineage check passed: run dispatched with the same 7.0.14-d330-fix inputs as the prior successful run, not workflow defaults (release-pin lesson from 47-01)"
  - "Remote dispatch head 3f87b2a verified byte-identical to local 8df3c56 for both task files (git diff empty), so the CI build proves the exact committed patch"

requirements-completed: [TCON-01]

# Metrics
duration: 2h20min
completed: 2026-10-16
status: complete
---

# Phase 50 Plan 01: echo-2 DCS ID-read instrument (kernel node + CI build) Summary

**`i915_dsi_regs` node extended with an `echo 2` value trigger that appends five annotated LP-mode DCS/generic ID reads after the MMIO walk, proven compiled by green CI run 38974632465, kernel .deb downloaded and sha256-secured for 50-04 deployment.**

## Performance

- **Duration:** ~2h20min (Task 1 by prior executor session; Task 2 dispatch-to-artifact 22:15Z–00:34Z + local securing)
- **Completed:** 2026-10-16
- **Tasks:** 2
- **Files modified:** 2 (patches/d330_dsi_dump.patch, .github/workflows/build-kernel.yml)

## Accomplishments

- **Task 1 (tracer, committed `8df3c56`):** write handler moved from `kstrtobool_from_user` to
  `kstrtouint_from_user` — 0 no-op, 1 the byte-identical historical MMIO walk, 2 walk + DCS ID
  reads, >2 rejected `-EINVAL`; mutex-trylock EBUSY discipline, len/words reset and walk call
  untouched. New `d330_dsi_dump_id_reads()` helper finds the DSI encoder on the display, targets
  `intel_dsi->dsi_hosts[PORT_A]->device`, forces `MIPI_DSI_MODE_LPM` + `channel = 0` before every
  run (the VBT executor mutates both in place), and always attempts five reads: `mipi_dsi_dcs_read`
  0x04 x3 bytes, then 0xDA/0xDB/0xDC x1 byte each (literals, not kernel enums), then
  `mipi_dsi_generic_read` register 0x00 x3 bytes. Every read emits one `d330_dsi_dump_add()` row
  annotated with ret + MIPI_INTR_STAT(A) bit-29 post-check + `%*ph` raw bytes; all runs attempted
  even on earlier failures. Section header + rows emitted strictly after
  `d330_dsi_dump_overlay()`, every data line DCS-prefixed so the diff tooling's `^0x...=` record
  regex and the 47/49 record counts never see them. PLL gate reuses the walk's `dsi_ok`: PLL off →
  `# DCS ID READ` header + `DCS SKIP pll-off`, zero FIFO access. `D330DSIREG: snapshot captured`
  pr_info string byte-identical (47/49 capture scripts poll it). Zero register writes anywhere in
  the new code.
- **Task 2 (CI dispatch + artifact):** run
  [38974632465](https://github.com/persano/lenovo-d330-linux-fix/actions/runs/38974632465)
  (workflow_dispatch on `instrument/d330-dsi-dcs-read`, head `3f87b2a`) concluded **success**;
  every job step green including "Apply the display fixes and prove they landed" — the step log
  shows both new anchors resolving in the CI tree (`grep -R 'DCS ID READ'` hitting the
  `d330_dsi_dump_add("# DCS ID READ\n")` emission and the contract comment; `grep -R
  'mipi_dsi_dcs_read'` hitting the 0x04/0xDA/0xDB/0xDC call sites in
  `intel_dsi_dump_debugfs.c`) alongside the pre-existing `i915_dsi_regs` / `bxt_dsi_pll_is_enabled`
  / CCS anchors.
- **Artifact secured:** `kernel-deb` artifact (id 12083313012, not expired) downloaded to
  `C:\Users\Familia\AppData\Local\Temp\opencode\50-01-artifact\` and sha256'd:
  - `linux-image-7.0.14-d330-fix_7.0.14-1_amd64.deb` —
    `22AE3D58F9796197F452EBDF30814468FD2CCB0D5B826600736BA6FD0AACFA1A`
  - `linux-headers-7.0.14-d330-fix_7.0.14-1_amd64.deb` —
    `8DA33ECE33BEDC920D96A90333D7CB2ACCFBB2FB1C51E4EF6AB0AD10E3E3FDB5`
  - `kernel.config` — `6CB18717C6914D4947489EEDF8CB69AC23DB3FAA8EF9B9F563FF02C346DCD32D`
- **Rollback .deb untouched** per plan step 5 — 50-04 Task 1 verifies it before any install.

## CI Artifact (50-04 consumes)

- Run: https://github.com/persano/lenovo-d330-linux-fix/actions/runs/38974632465 (conclusion success, 2026-10-16T22:15Z–2026-10-17T00:33Z)
- Lineage: `7.0.14-d330-fix_7.0.14-1` — same inputs as the prior successful run, not workflow defaults
- Staging dir: `C:\Users\Familia\AppData\Local\Temp\opencode\50-01-artifact\`
- `linux-image-7.0.14-d330-fix_7.0.14-1_amd64.deb` sha256
  `22AE3D58F9796197F452EBDF30814468FD2CCB0D5B826600736BA6FD0AACFA1A`
- `linux-headers-7.0.14-d330-fix_7.0.14-1_amd64.deb` sha256
  `8DA33ECE33BEDC920D96A90333D7CB2ACCFBB2FB1C51E4EF6AB0AD10E3E3FDB5`
- `kernel.config` sha256
  `6CB18717C6914D4947489EEDF8CB69AC23DB3FAA8EF9B9F563FF02C346DCD32D`

## Task Commits

Each task committed atomically (repo's v10.0 per-task directive, same as 50-02/50-03):

1. **Task 1: echo-2 DCS ID-read instrument (patch + grep-proofs)** - `8df3c56` (feat)
2. **50-01-SUMMARY.md** - this commit (docs)

Task 2 produced no code delta — it ran the pipeline and secured the artifact by
reference/sha256 (deploy is 50-04 by design).

## Compile-Check Result

Device-side staged-tree check was not recorded by Task 1 execution. Per plan Task 1 step 7's
explicit fallback, the green CI run is the load-bearing compile proof: the full kernel + i915
module built to .deb with the extended patch applied and both grep-anchors resolving in the same
apply step. Remote head `3f87b2a` verified byte-identical to local `8df3c56` for
`patches/d330_dsi_dump.patch` and `.github/workflows/build-kernel.yml` (empty `git diff`), so
the built artifact proves exactly the committed patch.

## Symbol-Spelling Deviations from Research

None recorded — Task 1 executed against the 7.0 tree spellings per the plan's instruction that
"the 7.0 tree spelling wins" over the mainline-verified research examples; the CI grep-proofs
(`mipi_dsi_dcs_read`, `intel_dsi_dump_debugfs.c` compile) confirm the spellings used.

## Deviations from Plan

None in this continuation session. Task 2's remaining steps (verify run, verify apply-step log,
download artifact, record sha256, leave rollback .deb untouched) executed exactly as written.

## Gate results (final)

- `bash scripts/dsi_mmio_diff.sh --selftest` → passed=52 failed=0
- `bash scripts/test_dsi_mmio_evidence.sh` → passed=7 failed=0
- `bash scripts/test_pitfalls_ledger.sh` → passed=4 failed=0 (files=40 hits=0)

## Requirements

- **TCON-01** — instrument arm COMPLETE: echo-2 node exists in the patch, compiles (CI proof),
  grep-proofs prove the symbols landed, green run produced + secured the kernel .deb with
  recorded sha256. (Userspace tooling arm was 50-02; on-device capture is 50-04/50-05.)

## Known Stubs

None. No hardcoded empty values, placeholder text, or unwired data introduced.

## Next Phase Readiness

- 50-04 Task 1: verify the retained rollback .deb, then install the sha-verified
  `linux-image-7.0.14-d330-fix_7.0.14-1_amd64.deb` (`22AE3D58...FA1A`) from the staging dir
- 50-04/50-05: `echo 2` node + 50-02 capture arms are one command away; DCS section validated
  by the capture script before registration
- No blockers.

## Self-Check: PASSED

- FOUND: patches/d330_dsi_dump.patch (echo-2 write side + d330_dsi_dump_id_reads, commit 8df3c56)
- FOUND: .github/workflows/build-kernel.yml (two new grep anchors, commit 8df3c56)
- FOUND: commit 8df3c56 (in HEAD ancestry, git log --oneline -14)
- FOUND: CI run 38974632465 conclusion success; apply step green; both new anchors resolving in step log
- FOUND: linux-image-7.0.14-d330-fix_7.0.14-1_amd64.deb downloaded + sha256 22AE3D58...FA1A recorded
