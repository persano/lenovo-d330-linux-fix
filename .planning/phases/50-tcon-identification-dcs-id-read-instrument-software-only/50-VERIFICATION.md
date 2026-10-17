---
phase: 50-tcon-identification-dcs-id-read-instrument-software-only
verified: 2026-10-17T03:35:22Z
status: passed
score: 8/8 must-haves verified
covered_files:
  - .github/workflows/build-kernel.yml
  - .planning/phases/50-tcon-identification-dcs-id-read-instrument-software-only/50-01-PLAN.md
  - .planning/phases/50-tcon-identification-dcs-id-read-instrument-software-only/50-01-SUMMARY.md
  - .planning/phases/50-tcon-identification-dcs-id-read-instrument-software-only/50-02-PLAN.md
  - .planning/phases/50-tcon-identification-dcs-id-read-instrument-software-only/50-02-SUMMARY.md
  - .planning/phases/50-tcon-identification-dcs-id-read-instrument-software-only/50-03-SUMMARY.md
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
covered_digest: "v3:sha256:f856c69c96ca36c666f9b3e46569cb6e575496cc28d389e1513d0e5360c8ee08"
behavior_unverified: 0
overrides_applied: 0
---

# Phase 50: TCON Identification — DCS ID-Read Instrument (Software-Only) Verification Report

**Phase Goal:** Identify the D330 panel's TCON controller (or prove the software read path dead) using only the running kernel — extend the existing dump node with a DCS ID-read trigger, capture the ID reads in both operational states (X=Y boot, X=Z black-resume), rule the I2C sideband in or out, and correct the DSI_MMIO_DIFF §6 register label.
**Verified:** 2026-10-17T03:35:22Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

Merged from ROADMAP success criteria 1-4 (roadmap contract) and the five plans' frontmatter `must_haves`.

| #   | Truth   | Status     | Evidence       |
| --- | ------- | ---------- | -------------- |
| 1   | Echo-2 DCS ID-read instrument exists in the patch: kstrtouint 0/1/2 write-side parse (>2 → -EINVAL), five reads (0x04 ×3B, 0xDA/0xDB/0xDC ×1B, generic reg-0x00 ×3B) with per-read ret + MIPI_INTR_STAT(A) bit-29 avail + `%*ph` data annotation, `MIPI_DSI_MODE_LPM` + `channel = 0` forced before every run, PLL-gated with `DCS SKIP pll-off`, section strictly after the overlay, zero register writes in new code | ✓ VERIFIED | patches/d330_dsi_dump.patch:228-320 (`d330_dsi_dump_id_reads`), :423-428 (`kstrtouint_from_user`, `trigger > 2 → -EINVAL`), :290-291 (LPM + channel), :247/272/279 (DCS SKIP), :357/366 (overlay then id_reads); live grep found no `intel_de_write`/`_WRITE(` additions |
| 2   | CI built the echo-2 kernel with grep-proofs resolving; deployed with sha-verified rollback retained; capture/diff userspace tooling handles the new section while echo-1 stays byte-compatible (SC1) | ✓ VERIFIED | `gh run view 38974632465` → status completed / conclusion **success** (checked live); build-kernel.yml:128-129 anchors; capture_dsi_dumps.sh:138-142 (boot2/resume2), :205 (`timeout -k 5 15 sh -c "echo 2 > '$NODE'"`), :315-334 (DCS section validation); dsi_mmio_diff.sh parser :163-170 + comparison block :228-251 + fixtures J-M :751-832; selftest **52/0** (fixtures A-I incl. determinism unchanged); rollback `c2c2cd89…1073` sha-verified before install and retained (50-04-SUMMARY Deploy Record; distinct incoming name, nothing removed) |
| 3   | Both operational states captured with the instrument, kit-registered and diffed (SC2 first half) | ✓ VERIFIED | docs/dumps/re_kit/tcon_boot_dsi_regs.txt + `_run2` + tcon_resume_dsi_regs.txt each contain `# DCS ID READ` + exactly five rows `DCS … ret=4 avail=0 data=00 00 00` (read live); dsi_regs_diff_tcon_boot_vs_resume.txt contains `## DCS ID READ comparison` with 5 read ids (timeout × timeout); `prepare_safety_kit.sh --verify` **exit 0**, all 9 tcon artifacts OK against MANIFEST.sha256 |
| 4   | The software read path is proven dead with the failure mode documented — the verdict document states one explicit verdict with machine evidence (SC2 second half) | ✓ VERIFIED | docs/research/TCON_IDENTIFICATION.md:9 verdict, :13-18 per-run matrix (3 identical runs: X=Y ×2, X=Z ×1), :18 failure-mode analysis (`ret=4` is not evidence of success because the host RX path returns ≥4 even on timeout; `avail` bit-29 is the discriminator and reads 0 everywhere), :22-23 falsification record (E3 discriminator dead as designed); shas cited, user eyes-on verdicts verbatim (50-04/50-05 SUMMARYs) |
| 5   | I2C sideband ruled out with archived sweep + tracepoint data and a written conclusion (SC3) | ✓ VERIFIED | tcon_i2c_sweep.txt/_run2 + tcon_i2c_trace_boot/_run2 + tcon_i2c_trace_resume kit-registered; TCON_IDENTIFICATION.md:38-44 conclusion: 11 buses enumerated, no PMIC by name on bus 6 (bus 6 = gmbus dpb), zero i2c-core transfers during the echo-2 instrument run, wake trace only Goodix touchscreen + one i2c-3 write, GPIO line-23 reset candidate; sideband verdict scoped to the observed windows — no over-claim detected |
| 6   | DSI_MMIO_DIFF §6's 0x6b004 row carries the bit-accurate decode and both anomalies stay flagged open; ledger gate green (SC4) | ✓ VERIFIED | DSI_MMIO_DIFF.md:370 `0x40280000 = SPL_PKT_SENT (bit 30) \| HS_TX_TIMEOUT (bit 21) \| LOW_CONTENTION (bit 19); LP_RX_TIMEOUT (bit 22) NOT set — "HS video stream never accepted by panel"`; :365 (0x6b010 OPEN anomaly, name corrected to tree-verified MIPI_HS_TX_TIMEOUT(A), write/read-back = register WRITE → own gated change), :367 (0x6b080 OPEN); ledger gate **4/0** live; evidence gate **7/0** live |
| 7   | tcon_i2c_sweep.sh ships syntax-clean with dynamic bus enumeration and honest degradation (50-02 tooling arm of TCON-03) | ✓ VERIFIED | scripts/tcon_i2c_sweep.sh exists (137 lines), `bash -n` exit 0, `i2cdetect -V` provenance (line 92, WR-01 fix commit 7e06f28); its on-device run produced the archived sweep artifacts (truth 5) |
| 8   | Phase 51 hand-off is documented: the read-path-dead consequence and ladder impact are recorded | ✓ VERIFIED | TCON_IDENTIFICATION.md:22 (E3 cannot work; any E3-shaped discriminator needs Phase 53 hardware), :58-60 (E1/E2 unaffected; E3 must be redefined; Phase 53 buy-gate becomes the identification path) |

**Score:** 8/8 truths verified (0 present-but-behavior-unverified)

### Advisory (New Scope, Unevidenced)

Not applicable — initial verification, no re-verification round.

### Required Artifacts

| Artifact | Expected    | Status | Details |
| -------- | ----------- | ------ | ------- |
| `patches/d330_dsi_dump.patch` | extended in place: echo-2 write side + DCS ID read section | ✓ VERIFIED | additive-only; `D330DSIREG: snapshot captured` pr_info string unchanged (:445); echo-1 semantics preserved (walk call :443, mutex/reset untouched per patch context) |
| `.github/workflows/build-kernel.yml` | grep-proofs for DCS ID READ / mipi_dsi_dcs_read | ✓ VERIFIED | lines 120-129; anchors resolving in green CI run 38974632465 |
| CI `linux-image-*-d330-fix_*.deb` | built, downloaded, sha256 recorded | ✓ VERIFIED | run 38974632465 success; `linux-image-7.0.14-d330-fix_7.0.14-1_amd64.deb` sha256 `22AE3D58…FA1A` recorded (50-01-SUMMARY); remote head verified byte-identical to local committed patch |
| `scripts/capture_dsi_dumps.sh` | echo-2 arms + timeout-wrapped trigger + validation | ✓ VERIFIED | boot2/resume2 arms; `timeout -k 5 15`; five-row-or-SKIP validation; missing section exits non-zero |
| `scripts/dsi_mmio_diff.sh` | DCS parser + comparison block + selftest fixtures | ✓ VERIFIED | DH/D/DK rep kinds; four-state vocabulary (answered/timeout/missing-section/DCS SKIP); fixtures J-M; selftest 52/0 |
| `scripts/tcon_i2c_sweep.sh` | new one-run I2C sideband archive | ✓ VERIFIED | exists, syntax-clean, provenance + honest degradation; run on device in 50-04 |
| `docs/research/DSI_MMIO_DIFF.md` §6 | corrected 0x6b004 row + open anomalies | ✓ VERIFIED | :370, :365, :367; §4.2 and RESUME_FIX_LEDGER.md untouched (50-03-SUMMARY diff-verified; no contradicting changes found) |
| `docs/dumps/re_kit/` tcon artifacts (9) | X=Y ×2 + X=Z captures, sweeps, traces, diff | ✓ VERIFIED | all present, all kit-registered, `--verify` exit 0 |
| `docs/research/TCON_IDENTIFICATION.md` | verdict document | ✓ VERIFIED | dead-path verdict + failure mode + I2C conclusion + Phase 51 consequences; see Info notes below for two minor omissions |

### Key Link Verification

| From | To  | Via | Status | Details |
| ---- | --- | --- | ------ | ------- |
| d330_dsi_dump_write value parse | echo-2 walk + reads | kstrtouint_from_user 0/1/2, >2 → -EINVAL | ✓ WIRED | patch :423-443 — echo 1 preserved, echo 2 routes `trigger == 2` into the walk's id_reads flag |
| DCS section | diff tooling record regex | DCS-prefixed rows after overlay, never matching `^0x...=` | ✓ WIRED | section rows validated by capture script (:322-334) and parsed as distinct DH/D/DK kinds (diff :163-170); selftest fixtures A-I + determinism prove historical record counts unaffected |
| capture trigger | kernel read path | `timeout -k 5 15 sh -c "echo 2 > node"` | ✓ WIRED | capture :205; failure path exits non-zero with captured stderr |
| sweep output | kit | prepare_safety_kit --register → MANIFEST.sha256 | ✓ WIRED | all 9 tcon artifacts OK under `--verify` exit 0 |
| verdict | evidence | TCON_IDENTIFICATION.md ↔ boot/resume dumps + diff + sweep, cross-cited by sha | ✓ WIRED | shas in doc match kit manifest (first-8 prefixes match captured artifacts) |
| mipi_dsi_dcs_read/generic_read | port-A device | `intel_dsi->dsi_hosts[PORT_A]->device` with LPM + VC 0 reset | ✓ WIRED | patch :277-291; VBT executor refusal documented as the reason this node is the only software read path |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| tcon_boot/resume_dsi_regs.txt DCS rows | per-read ret/avail/bytes | live `mipi_dsi_dcs_read` + `intel_de_read(MIPI_INTR_STAT)` on the device | Yes — real device reads (`ret=4 avail=0 data=00 00 00`, stable across 3 runs) | ✓ FLOWING |
| tcon_i2c_sweep.txt | bus inventory / i2cdetect grids | on-device `i2cdetect -l`, sysfs, `i2cdetect -y`, gpioinfo, dmesg | Yes — 11 real buses, real ACK grids | ✓ FLOWING |
| dsi_regs_diff_tcon_boot_vs_resume.txt | joined DCS states | real parse of the two kit dumps | Yes — comparison block emitted from actual capture data | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Diff-tool selftest (echo-1 compat + DCS fixtures) | `bash scripts/dsi_mmio_diff.sh --selftest` | passed=52 failed=0 | ✓ PASS |
| DSI MMIO evidence gate | `bash scripts/test_dsi_mmio_evidence.sh` | passed=7 failed=0 | ✓ PASS |
| Pitfalls-ledger gate | `bash scripts/test_pitfalls_ledger.sh` | passed=4 failed=0 | ✓ PASS |
| Safety-kit integrity | `bash scripts/prepare_safety_kit.sh --verify --kit-dir docs/dumps/re_kit` | exit 0, all artifacts match MANIFEST | ✓ PASS |
| Sweep script syntax | `bash -n scripts/tcon_i2c_sweep.sh` | exit 0 | ✓ PASS |
| CI pipeline (load-bearing compile proof) | `gh run view 38974632465 --json status,conclusion` | `{"conclusion":"success","status":"completed"}` | ✓ PASS |
| DCS sections in both arm captures | grep `^# DCS ID READ` / `^DCS ` on boot + resume dumps | header + 5 annotated rows in each (live read) | ✓ PASS |
| ID-read comparison block in shipped diff | grep on dsi_regs_diff_tcon_boot_vs_resume.txt | `## DCS ID READ comparison` + per-read rows + "comparison block emitted (5 read ids)" | ✓ PASS |

### Probe Execution

Not applicable — no `scripts/*/tests/probe-*.sh` probes declared for this phase; the four static gates above are the phase's declared runnable checks and were all run in this verification.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ---------- | ----------- | ------ | -------- |
| TCON-01 | 50-01, 50-02 (50-04 deploy) | echo-2 DCS ID-read instrument, LP/VC0, CI-shipped, capture/diff scripts handle the section | ✓ SATISFIED | truths 1-2, 7; patch + workflow + scripts verified live; CI success; deployed + captured |
| TCON-02 | 50-04, 50-05 | identity or read-path-proven-dead with failure mode, both-state captures kit-registered + diffed | ✓ SATISFIED | truths 3-4; dead-path branch fired (3 identical runs) and is documented with machine evidence |
| TCON-03 | 50-02, 50-04, 50-05 | I2C sideband ruled in or out: sweep + tracepoints archived + written conclusion | ✓ SATISFIED | truths 5, 7; written conclusion in TCON_IDENTIFICATION.md §I2C |
| TCON-04 | 50-03 | §6 0x6b004 bit-accurate decode, anomalies flagged, ledger green | ✓ SATISFIED | truth 6 |

No ORPHANED requirements — REQUIREMENTS.md maps exactly TCON-01..04 to phase 50 (line 142).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| — | — | no TBD/FIXME/XXX/PLACEHOLDER/`return null`-stub matches in any phase-modified implementation file | — | none |

Info notes (not blocking, surfaced for developer decision):
1. **TCON_IDENTIFICATION.md omits the literal AUO PnP 0xaf06/6104 and FRU 5D11A20220 citations** (SC2's cross-check clause; 50-05 Task 3 acceptance). Under the fired dead-path branch the cross-check is vacuous — there are no ID bytes to cross-check — and the doc does state the FRU/glass cross-reference "does not exist publicly today" plus the full candidate fingerprint list. No over-claim; a one-line edit adding the literal part numbers would fully close the clause.
2. **TCON_IDENTIFICATION.md does not carry the block-55 negative-result note** (50-CONTEXT specific idea; 50-05 Task 3 action text). Not part of any truth or success criterion; a one-line addition would satisfy the plan action text.
3. **The explicit "pre-kernel GOP I2C blind spot" sentence is absent** from the I2C conclusion (50-05 Task 3 acceptance; T-50-14). However, every conclusion claim is time-window-scoped ("during the echo-2 instrument run", "during wake-to-capture"), so no over-claim from kernel-only traces was detected; the GOP-era invisibility is implied rather than stated.

### Human Verification Required

None outstanding. The phase's two `checkpoint:human-verify` device tasks (50-04 Session A, 50-05 Session B) were executed with the user present; eyes-on verdicts are recorded verbatim in the SUMMARYs (X=Y "image visible" both runs; X=Z "screen lit but black"). Re-running the device sessions is not required for phase closure — the dead-path verdict is stable across 3 runs and kit-verified.

### Gaps Summary

No gaps. All four roadmap success criteria and every plan-frontmatter must-have are observably true in the codebase: the echo-2 instrument exists and compiles (CI-verified), both-state captures are kit-registered with the read path proven dead and its failure mode documented, the I2C sideband is ruled out with archived evidence and a written conclusion, and DSI_MMIO_DIFF §6 carries the bit-accurate decode with the ledger gate green. Three minor documentation omissions (Info notes 1-3) are surfaced for developer decision; none fails a truth, and none blocks Phase 51 — E1/E2 are independent of DCS reads and the E3 redefinition is already recorded in the verdict doc.

---

_Verified: 2026-10-17T03:35:22Z_
_Verifier: the agent (gsd-verifier)_
