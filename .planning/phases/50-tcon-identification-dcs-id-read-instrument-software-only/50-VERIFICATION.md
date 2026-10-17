---
phase: 50-tcon-identification-dcs-id-read-instrument-software-only
verified: 2026-10-17T04:10:12Z
status: passed
score: 8/8 must-haves verified
covered_files:
  - .github/workflows/build-kernel.yml
  - .planning/phases/50-tcon-identification-dcs-id-read-instrument-software-only/50-01-PLAN.md
  - .planning/phases/50-tcon-identification-dcs-id-read-instrument-software-only/50-01-SUMMARY.md
  - .planning/phases/50-tcon-identification-dcs-id-read-instrument-software-only/50-02-PLAN.md
  - .planning/phases/50-tcon-identification-dcs-id-read-instrument-software-only/50-02-SUMMARY.md
  - .planning/phases/50-tcon-identification-dcs-id-read-instrument-software-only/50-03-PLAN.md
  - .planning/phases/50-tcon-identification-dcs-id-read-instrument-software-only/50-03-SUMMARY.md
  - .planning/phases/50-tcon-identification-dcs-id-read-instrument-software-only/50-04-PLAN.md
  - .planning/phases/50-tcon-identification-dcs-id-read-instrument-software-only/50-04-SUMMARY.md
  - .planning/phases/50-tcon-identification-dcs-id-read-instrument-software-only/50-05-PLAN.md
  - .planning/phases/50-tcon-identification-dcs-id-read-instrument-software-only/50-05-SUMMARY.md
  - docs/dumps/re_kit/MANIFEST.sha256
  - docs/dumps/re_kit/dsi_regs_diff_tcon_boot_vs_resume.txt
  - docs/dumps/re_kit/tcon_boot_dsi_regs.txt
  - docs/dumps/re_kit/tcon_boot_dsi_regs_run2.txt
  - docs/dumps/re_kit/tcon_i2c_sweep.txt
  - docs/dumps/re_kit/tcon_i2c_sweep_run2.txt
  - docs/dumps/re_kit/tcon_i2c_trace_boot.txt
  - docs/dumps/re_kit/tcon_i2c_trace_boot_run2.txt
  - docs/dumps/re_kit/tcon_i2c_trace_resume.txt
  - docs/dumps/re_kit/tcon_resume_dsi_regs.txt
  - docs/research/DSI_MMIO_DIFF.md
  - docs/research/TCON_IDENTIFICATION.md
  - patches/d330_dsi_dump.patch
  - scripts/capture_dsi_dumps.sh
  - scripts/dsi_mmio_diff.sh
  - scripts/tcon_i2c_sweep.sh
covered_digest: "v3:sha256:89008087449d0d7b36548566500e60cd46aadf5bfb433855b2ff9ab0838e8513"
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: passed
  previous_score: 8/8
  gaps_closed: []
  gaps_remaining: []
  regressions: []
---

# Phase 50: TCON Identification — DCS ID-Read Instrument (Software-Only) Verification Report

**Phase Goal:** Identify the D330 panel's TCON controller (or prove the software read path dead) using only the running kernel — extend the existing dump node with a DCS ID-read trigger, capture the ID reads in both operational states (X=Y boot, X=Z black-resume), rule the I2C sideband in or out, and correct the DSI_MMIO_DIFF §6 register label.
**Verified:** 2026-10-17T04:10:12Z
**Status:** passed
**Re-verification:** Yes — report regenerated after doc delta commit 97f0b4d (T-50-14 "pre-kernel GOP blind spot" sentence added to TCON_IDENTIFICATION.md's I2C conclusion); prior report's fingerprint went stale. Prior verdict passed 8/8, no `gaps:` section; all must-haves re-checked at full scope, none weakened.

## Goal Achievement

### Observable Truths

Merged from ROADMAP success criteria 1-4 (roadmap contract) and the five plans' frontmatter `must_haves`.

| #   | Truth   | Status     | Evidence       |
| --- | ------- | ---------- | -------------- |
| 1   | Echo-2 DCS ID-read instrument exists in the patch: kstrtouint 0/1/2 write-side parse (>2 → -EINVAL), five reads (0x04 ×3B, 0xDA/0xDB/0xDC ×1B, generic reg-0x00 ×3B) with per-read ret + MIPI_INTR_STAT(A) bit-29 avail + `%*ph` data annotation, `MIPI_DSI_MODE_LPM` + `channel = 0` forced before every run, PLL-gated with `DCS SKIP pll-off`, section strictly after the overlay, zero register writes in new code | ✓ VERIFIED | patches/d330_dsi_dump.patch:423 (`kstrtouint_from_user`), :427 (`trigger > 2`), `d330_dsi_dump_id_reads` section (no `intel_de_write`/`_WRITE(` additions — live grep returned only the parse anchors) |
| 2   | CI built the echo-2 kernel with grep-proofs resolving; deployed with sha-verified rollback retained; capture/diff userspace tooling handles the new section while echo-1 stays byte-compatible (SC1) | ✓ VERIFIED | build-kernel.yml:120/128/129 grep-proofs for `DCS ID READ` + `mipi_dsi_dcs_read` (live grep); prior green CI run 38974632465 (recorded, not re-queried this pass); capture/diff scripts re-gated green this pass — selftest **52/0** |
| 3   | Both operational states captured with the instrument, kit-registered and diffed (SC2 first half) | ✓ VERIFIED | `# DCS ID READ` header at line 7323 of tcon_boot_dsi_regs.txt / _run2 / tcon_resume_dsi_regs.txt; exactly 5 `^DCS ` rows per file (grep -c = 5/5/5); diff has `## DCS ID READ comparison` (line 25) with 5 read ids all `timeout` and "comparison block emitted (5 read ids)" (line 44); `prepare_safety_kit.sh --verify` **exit 0** — "[OK] safety kit verified: all artifacts match docs/dumps/re_kit/MANIFEST.sha256" |
| 4   | The software read path is proven dead with the failure mode documented — the verdict document states one explicit verdict with machine evidence (SC2 second half) | ✓ VERIFIED | TCON_IDENTIFICATION.md:9 explicit verdict, :13-16 per-run matrix (X=Y ×2, X=Z ×1), :18 failure mode (`ret=4` not success; `avail` bit-29 is the discriminator, reads 0 everywhere), :22 falsification record; file re-read in full this pass |
| 5   | I2C sideband ruled out with archived sweep + tracepoint data and a written conclusion (SC3) | ✓ VERIFIED | TCON_IDENTIFICATION.md:38-45: 11 buses enumerated (:40), no PMIC by name on bus 6 (:41), zero i2c-core transfers during the echo-2 run + wake traffic only Goodix/i2c-3 (:42), GPIO line-23 reset candidate (:43), **:45 "Pre-kernel GOP blind spot" bullet present** (the previously-missing T-50-14 mandatory sentence — closes Info note 3 of the prior report); sideband verdict stays time-window-scoped, no over-claim |
| 6   | DSI_MMIO_DIFF §6's 0x6b004 row carries the bit-accurate decode and both anomalies stay flagged open; ledger gate green (SC4) | ✓ VERIFIED | DSI_MMIO_DIFF.md:370 `0x40280000 = SPL_PKT_SENT (bit 30) \| HS_TX_TIMEOUT (bit 21) \| LOW_CONTENTION (bit 19); LP_RX_TIMEOUT (bit 22) NOT set — "HS video stream never accepted by panel"`; :365 (0x6b010 OPEN anomaly, MIPI_HS_TX_TIMEOUT(A), write/read-back = own gated change) and :367 (0x6b080 OPEN) re-read live; ledger gate **4/0** and evidence gate **7/0** re-run this pass |
| 7   | tcon_i2c_sweep.sh ships syntax-clean with dynamic bus enumeration and honest degradation (50-02 tooling arm of TCON-03) | ✓ VERIFIED | scripts/tcon_i2c_sweep.sh in covered set, `bash -n` clean (prior pass), archived sweep artifacts verified against manifest this pass (truth 3 / kit exit 0) |
| 8   | Phase 51 hand-off is documented: the read-path-dead consequence and ladder impact are recorded | ✓ VERIFIED | TCON_IDENTIFICATION.md:22 (E3-shaped discriminator needs Phase 53 hardware), :59-61 (E1/E2 unaffected; E3 redefined; Phase 53 buy-gate becomes the identification path) |

**Score:** 8/8 truths verified (0 present-but-behavior-unverified)

### Advisory (New Scope, Unevidenced)

New-scope findings from Step 7 with no deterministic evidence — reported, not blocking.

| # | Finding | Category | Why Advisory |
|---|---------|----------|--------------|
| — | None | — | re-verification ran; no new-scope Step 7 finding raised this pass |

### Required Artifacts

| Artifact | Expected    | Status | Details |
| -------- | ----------- | ------ | ------- |
| `patches/d330_dsi_dump.patch` | extended in place: echo-2 write side + DCS ID read section | ✓ VERIFIED | exists, substantive (parse anchors :423/:427 live); no write-side additions in new code |
| `.github/workflows/build-kernel.yml` | grep-proofs for DCS ID READ / mipi_dsi_dcs_read | ✓ VERIFIED | lines 120/128/129 live grep |
| CI `linux-image-*-d330-fix_*.deb` | built, sha256 recorded | ✓ VERIFIED | run 38974632465 success + sha recorded in 50-01-SUMMARY (prior pass, carried; no CI re-trigger needed for a docs-only delta) |
| `scripts/capture_dsi_dumps.sh` | echo-2 arms + timeout-wrapped trigger + validation | ✓ VERIFIED | in covered set; regression-green via kit verify (captures it produced match manifest) |
| `scripts/dsi_mmio_diff.sh` | DCS parser + comparison block + selftest fixtures | ✓ VERIFIED | selftest **52/0** re-run this pass (fixtures A-M incl. echo-1 compat + determinism) |
| `scripts/tcon_i2c_sweep.sh` | new one-run I2C sideband archive | ✓ VERIFIED | in covered set; produced the archived sweep artifacts verified against manifest |
| `docs/research/DSI_MMIO_DIFF.md` §6 | corrected 0x6b004 row + open anomalies | ✓ VERIFIED | :370, :365, :367 live grep |
| `docs/dumps/re_kit/` tcon artifacts (9) | X=Y ×2 + X=Z captures, sweeps, traces, diff | ✓ VERIFIED | `--verify` exit 0, all match MANIFEST.sha256 |
| `docs/research/TCON_IDENTIFICATION.md` | verdict document incl. T-50-14 mandatory sentence | ✓ VERIFIED | full re-read: verdict + failure mode + I2C conclusion with **:45 GOP blind-spot sentence** + Phase 51 consequences; 0 TBD/FIXME/XXX/PLACEHOLDER matches (grep -c = 0) |

### Key Link Verification

Automated `verify.key-links` returned no parseable entries for these plans' prose-format key_links (50-03's only structured entry resolves as "Source file not found: §6 corrected row" — pathless prose, not a broken link); links verified manually per wiring patterns:

| From | To  | Via | Status | Details |
| ---- | --- | --- | ------ | ------- |
| d330_dsi_dump_write value parse | echo-2 walk + reads | kstrtouint_from_user 0/1/2, >2 → -EINVAL | ✓ WIRED | patch :423/:427 live |
| DCS section | diff tooling record regex | DCS-prefixed rows after overlay, never matching `^0x...=` | ✓ WIRED | 5 rows per capture; selftest fixtures J-M prove historical record counts unaffected |
| capture trigger | kernel read path | `timeout -k 5 15 sh -c "echo 2 > node"` | ✓ WIRED | capture_dsi_dumps.sh:205 (prior pass, carried); both arms produced DCS sections |
| sweep/trace output | kit | prepare_safety_kit --register → MANIFEST.sha256 | ✓ WIRED | `--verify` exit 0 this pass |
| verdict | evidence | TCON_IDENTIFICATION.md ↔ boot/resume dumps + diff + sweep | ✓ WIRED | artifact table shas (first 8) match kit-registered captures; GOP blind-spot claim scoped to tracepoint windows |
| mipi_dsi_dcs_read/generic_read | port-A device | `intel_dsi->dsi_hosts[PORT_A]->device` with LPM + VC 0 | ✓ WIRED | patch read section; VBT executor refusal documented as why this node is the only software read path |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| tcon_boot/resume DCS rows | per-read ret/avail/bytes | live `mipi_dsi_dcs_read` + `intel_de_read(MIPI_INTR_STAT)` on device | Yes — `ret=4 avail=0 data=00 00 00` stable across 3 runs | ✓ FLOWING |
| tcon_i2c_sweep.txt | bus inventory / ACK grids | on-device i2cdetect/sysfs/gpioinfo/dmesg | Yes — 11 real buses | ✓ FLOWING |
| dsi_regs_diff DCS block | joined DCS states | real parse of the two kit dumps | Yes — comparison block emitted from capture data | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Diff-tool selftest (echo-1 compat + DCS fixtures) | `bash scripts/dsi_mmio_diff.sh --selftest` | passed=52 failed=0 | ✓ PASS |
| DSI MMIO evidence gate | `bash scripts/test_dsi_mmio_evidence.sh` | passed=7 failed=0 | ✓ PASS |
| Pitfalls-ledger gate | `bash scripts/test_pitfalls_ledger.sh` | passed=4 failed=0 | ✓ PASS |
| Safety-kit integrity | `bash scripts/prepare_safety_kit.sh --verify --kit-dir docs/dumps/re_kit` | exit 0, "[OK] safety kit verified" | ✓ PASS |
| DCS sections in both arm captures | `grep -c '^DCS '` on boot/boot2/resume dumps | 5 / 5 / 5 rows + `# DCS ID READ` header at :7323 in each | ✓ PASS |
| ID-read comparison block in shipped diff | grep `DCS ID READ comparison\|comparison block emitted` | header :25, 5 timeout rows :29-33, "emitted (5 read ids)" :44 | ✓ PASS |
| T-50-14 mandatory GOP blind-spot sentence | grep `Pre-kernel GOP blind spot` docs/research/TCON_IDENTIFICATION.md | match at line 45 | ✓ PASS |
| §6 decode + open anomalies | grep `0x6b004`/`OPEN` docs/research/DSI_MMIO_DIFF.md | :370 decode, :365/:367 OPEN anomalies present | ✓ PASS |
| CI pipeline (load-bearing compile proof) | `gh run view 38974632465` (prior pass) | `conclusion: success` — carried forward; no re-run needed for docs-only delta | ✓ PASS (carried) |

### Probe Execution

Not applicable — no `scripts/*/tests/probe-*.sh` probes declared for this phase; the four static gates are the phase's declared runnable checks and were all re-run in this verification.

### Decision Coverage

`check.decision-coverage-verify` → `{"skipped": true, "reason": "no trackable decisions", "total": 0}` — 50-CONTEXT.md has no trackable `<decisions>` entries; nothing to report.

### Test Quality Audit

Phase-linked checks are the four shell gate suites. Disabled-test scan: no `skip`/`xit`/`pending` patterns in `scripts/dsi_mmio_diff.sh --selftest`, `scripts/test_dsi_mmio_evidence.sh`, `scripts/test_pitfalls_ledger.sh`, or `scripts/prepare_safety_kit.sh`. Assertions are value-level (exact counts, exact verdict strings, sha256 equality) — no circular fixtures (expected values are pinned literals in the gate scripts, not generated by the system under test).

**Disabled tests on requirements:** 0 → none. **Circular patterns detected:** 0 → none. **Insufficient assertions:** 0 → none.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| TCON-01 | 50-01, 50-02 (50-04 deploy) | echo-2 DCS ID-read instrument, LP/VC0, CI-shipped, capture/diff handle the section | ✓ SATISFIED | truths 1-2, 7; patch + workflow anchors live; gates green |
| TCON-02 | 50-04, 50-05 | identity or read-path-proven-dead with failure mode, both-state captures kit-registered + diffed | ✓ SATISFIED | truths 3-4; dead-path branch fired 3×, documented with machine evidence |
| TCON-03 | 50-02, 50-04, 50-05 | I2C sideband ruled in or out: sweep + tracepoints archived + written conclusion | ✓ SATISFIED | truths 5, 7; written conclusion now carries the T-50-14 GOP blind-spot sentence (:45) |
| TCON-04 | 50-03 | §6 0x6b004 bit-accurate decode, anomalies flagged, ledger green | ✓ SATISFIED | truth 6 |

No ORPHANED requirements — REQUIREMENTS.md maps exactly TCON-01..04 to phase 50.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| — | — | no TBD/FIXME/XXX/PLACEHOLDER matches in the delta file (docs/research/TCON_IDENTIFICATION.md, grep -c = 0) or any phase-modified implementation file | — | none |

Info notes (not blocking, surfaced for developer decision):
1. **TCON_IDENTIFICATION.md still omits the literal AUO PnP 0xaf06/6104 and FRU 5D11A20220 citations** (SC2 cross-check clause; 50-05 Task 3). Re-checked this pass: `grep -c` = 0 for both strings. Under the fired dead-path branch the cross-check is vacuous (no ID bytes to cross-check) and the doc states the FRU/glass cross-reference "does not exist publicly today" — no over-claim; one-line edit would close it.
2. **TCON_IDENTIFICATION.md does not carry the block-55 negative-result note** (50-CONTEXT specific idea; 50-05 Task 3). Not part of any truth or success criterion.
3. **50-SECURITY.md's T-50-14 row still reads "the declared mandatory sentence is ABSENT"** — now stale: the sentence exists at TCON_IDENTIFICATION.md:45 (commit 97f0b4d). Threat substance closed; the status row itself needs a one-line refresh at next SECURITY pass. Non-blocking (T-50-14 was already below the `block_on: high` gate).

### Human Verification Required

None outstanding. The phase's two `checkpoint:human-verify` device tasks (50-04 Session A, 50-05 Session B) were executed with the user present; eyes-on verdicts are recorded verbatim in the SUMMARYs (X=Y "image visible" both runs; X=Z "screen lit but black"). No behavior-dependent truth is unexercised (behavior_unverified = 0): every truth in this phase is a document/artifact truth re-checked live this pass.

### Gaps Summary

No gaps. All four roadmap success criteria and every plan-frontmatter must-have remain observably true: the echo-2 instrument exists (CI-verified), both-state captures are kit-registered with the read path proven dead and its failure mode documented, the I2C sideband is ruled out with archived evidence and a written conclusion **including the T-50-14 pre-kernel GOP blind-spot sentence (this round's delta — verified present at TCON_IDENTIFICATION.md:45)**, and DSI_MMIO_DIFF §6 carries the bit-accurate decode with both gates green. Three minor documentation omissions (Info notes 1-3) remain surfaced for developer decision; none fails a truth.

---

_Verified: 2026-10-17T04:10:12Z_
_Verifier: the agent (gsd-verifier)_
