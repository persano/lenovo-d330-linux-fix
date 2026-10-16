---
phase: 47-dsi-mmio-truth-boot-vs-resume-hardware-register-diff
verified: 2026-10-14T21:45:00Z
status: passed
score: 39/39 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification: none (initial — no previous VERIFICATION.md existed)
prohibition_review: >-
  30 judgment-tier prohibitions across the 4 plans (planner-flagged-unverified,
  EDGE_ABSENT origin): 30/30 LLM-judged SATISFIED with concrete enforcement
  evidence (patch code, machine gates, session records) — NON-AUTHORITATIVE
  verdicts, human review recommended at the end-of-phase checkpoint. Not a
  silent pass; see Prohibition Review section.
deferred_to_ship:  # informational — owned by /gsd-ship by design (user-approved deferred-commit + branch-CI), not phase gaps
  - "Merge/cherry-pick branch instrument/d330-dsi-dump (fdafc43, fb86c6a, 30f077c, b753d39) into main: patches/d330_dsi_dump.patch + .github/workflows/build-kernel.yml"
  - "Stage with exec bit: scripts/dsi_mmio_diff.sh, scripts/test_dsi_mmio_evidence.sh, scripts/capture_dsi_dumps.sh (all 100755)"
  - "Commit untracked evidence/docs: docs/research/DSI_MMIO_DIFF.md, docs/dumps/re_kit/{boot,broken}_dsi_regs.txt, {boot,resume}_dsi_regs_session1.txt, dsi_regs_diff.txt, dsi_regs_diff_names.txt, MANIFEST.sha256, .planning/47-0{1,2,3,4}-SUMMARY.md, 47-REVIEW*.md, 47-VERIFICATION.md"
  - "After tracking, the plain ledger gate covers DSI_MMIO_DIFF.md (47-04 used a --gate-probe scratch copy pre-ship: files=1 hits=0)"
---

# Phase 47: DSI MMIO Truth (Boot vs Resume Hardware Register Diff) Verification Report

**Phase Goal:** Get below the kernel's software model — capture the DSI/DPHY/transcoder hardware register state that v8.0 could not see, on both a working fresh boot and a broken resume, and name the differing mechanism.
**Verified:** 2026-10-14T21:45:00Z
**Status:** passed
**Re-verification:** No — initial verification

**Deferred-commit caveat applied:** per the phase verification context, code/data files are intentionally uncommitted on main (branch-CI + deferred-commit, user-approved). "File X contains Y" must-haves were verified against FILE CONTENT at the artifact-of-record (branch `instrument/d330-dsi-dump` for the patch + workflow; main working tree for scripts/docs/dumps). No must-have required a main-branch commit hash.

## Goal Achievement

The phase goal is met with a closed evidence chain: an additive CI-built debugfs snapshot node captured 7296-word register dumps on all four arms (boot/resume of the bug session + a working-resume contrast session), the bug pair's diff is machine-generated, cited, and byte-reproducible, and `docs/research/DSI_MMIO_DIFF.md` names ONE testable mechanism (operational-state sequencing, not value restore) with a concrete Phase-48 handoff. Every load-bearing register value in the doc was re-verified this session against the actual capture-file lines, and the repo copies were hash-matched against the device originals over SSH.

### Observable Truths

Roadmap success criteria (the contract):

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC1 | A register dump covering the DSI/DPHY/transcoder block exists for BOTH states, captured on-device with the CI-built kernel, checksummed and registered in the RE kit manifest | ✓ VERIFIED | `boot_dsi_regs.txt` + `broken_dsi_regs.txt` (7296 records each, 0 skip markers) + session-1 contrast pair; kit `--verify` exit 0 (38-line manifest); dump kernel from CI run 38494943266 (live-checked: `conclusion=success`); device originals hash-identical to repo copies (SSH sha256, this session) |
| SC2 | `DSI_MMIO_DIFF.md` records the diff, excludes volatile/irrelevant registers with reasons, and names the mechanism as a testable claim | ✓ VERIFIED | 7 sections; exclusion table mirrored from `build_exclusions()` with 7 distinct reason families; exactly 1 mechanism-claim heading; claim in "GOP sets X=Y at boot; resume leaves X=Z" form with falsification condition; §6 handoff list |
| SC3 | Every claim is machine-evidenced; the ledger gate stays green | ✓ VERIFIED | 32 `file:line` citation anchors in the doc — every load-bearing value byte-checked against the actual dump lines this session; ledger gate 4/4 green (`files=40 hits=0`); kit verify + evidence suite 7/7 + RE suite 6/6 green this session |

Plan 47-01 (dump instrument):

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | echo-trigger walks locked scope into a frozen kernel buffer; cat emits it — identical code path both arms (D-01) | ✓ VERIFIED | Directly observed: 4 real captures produced via the node on-device (D330DSIREG journal confirmations, 47-03 record); snapshot-by-construction verified in patch source (single walk at write, buffer emit at read); broken-arm values cross-corroborate the prior IGT in-window capture (0x6b010 003fffff→0000b8ea etc. byte-identical) |
| 2 | Walked scope exactly the locked one: 5 ranges + named overlay (D-02) | ✓ VERIFIED | 7296/arm = 1024+4096+1024+128+1024 on all four dumps; `d330_dsi_dump_range()` calls in patch match the locked scope verbatim; `# NAMED OVERLAY` section present |
| 3 | DSI reads gated on `bxt_dsi_pll_is_enabled()`; PLL off → skip marker INSTEAD of the `# RANGE` header | ✓ VERIFIED | Patch code inspected: gate `!((geminilake\|\|broxton) && !bxt_dsi_pll_is_enabled(display))` emits both markers instead of the DSI/PHY headers; marker strings byte-exact; downstream contract fixture-proven (selftest B/B2/H/I). Note: the guard never fired on any arm (0 `# SKIPPED`, all arms PLL-on) — by design for a safety gate |
| 4 | All reads through intel_de_read family under display RPM + drm_modeset_lock_all; never raw readl | ✓ VERIFIED | `intel_de_read` present in patch; `readl(`/`writel(` count = 0; `intel_display_rpm_put` + `drm_modeset_unlock_all` in the trigger path |
| 5 | Patch strictly additive: one new source file, one Makefile line, one registration call | ✓ VERIFIED | 310-line raw unified diff, 3 target files: `intel_dsi_dump_debugfs.c` (new, 276 lines), `i915_debugfs.c` (2 hunks: prototype + one `d330_dsi_dump_register(i915->display)` call), `Makefile` (1 line in the DEBUG_FS object list); nothing in the DSI enable/disable path |
| 6 | CI applies the dump patch next to the CCS patch, grep-proves landing, produces deployable .deb | ✓ VERIFIED | Branch workflow carries `d330_dsi_dump.patch` (2 refs) + `i915_dsi_regs` + `bxt_dsi_pll_is_enabled` anchors + CCS patch intact; `gh run view 38494943266` live-checked this session: `conclusion=success`, headBranch `instrument/d330-dsi-dump` |
| 7 | Write trigger boolean-only; node perms 0600 | ✓ VERIFIED | `kstrtobool` present in write handler; `0600` in the `debugfs_create_file` call; no offset/length parameters |
| 8 | Zero register writes, no mode changes (idempotent) | ✓ VERIFIED | `intel_de_write\|writel(` count = 0 in patch; capture helper write-tool count = 0 (only the node echo) |
| 9 | 0xffffffff reads preserved verbatim, never dropped/normalized | ✓ VERIFIED | 2960/4096 all-ones words preserved in the PHY range across all four arms; diff-integrity note in `dsi_regs_diff.txt` documents positions byte-identical across arms |
| 10 | [backstop] Ascending offset order per range → deterministic join | ✓ VERIFIED | Executed this session: full-pipeline rebuild from the registered dumps + names file reproduces the registered artifact's script half byte-identical (`first-difference-line=none`, 32/32 lines); selftest E green |

Plan 47-02 (diff tooling + evidence guard):

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Join emits one row per differing offset: offset, boot, resume, interpretation, verdict, citation with file+line (D-07) | ✓ VERIFIED | `dsi_regs_diff.txt` has 14 six-column rows, every citation `boot_dsi_regs.txt:<n>; broken_dsi_regs.txt:<n>`; selftest A green |
| 2 | Non-differing collapse to per-range identical counts; exclusion rows list offset + reason (D-06) | ✓ VERIFIED | Summary block: 1017/4094/1024/128/1019 per-range counts (7282+14=7296); excluded rows still print with reasons |
| 3 | 0xffffffff range → ONE unreadable-state row, never thousands of fake diffs | ✓ VERIFIED | Selftest C green (fixture with >90% all-ones → one state row, zero per-register rows); real pair produced 0 state rows (no range crossed 90%) |
| 4 | Missing/skipped DSI section → explicit state row, never silent drop | ✓ VERIFIED | Selftest B/B2 green (marker-present + zero-record section → `skipped-pll-off`, never `readable`) |
| 5 | Exclusion entries carry TRUE-semantics reasons, separate entries (no lumping) | ✓ VERIFIED | `build_exclusions()` inspected: 17 separate entries — W1C status group, 0x6b094 own config-state entry citing rows 3/18, RX-FIFO group, 0x6b074 own read-only-status entry, 0x6b138, PPS, surface, counters |
| 6 | Deterministic output (same inputs → byte-identical) | ✓ VERIFIED | Selftest E + this session's rebuild cmp-identical |
| 7 | Evidence suite proves the bar statically: manifest, kit verify, citations, exclusion table, single claim, handoff, markers | ✓ VERIFIED | Real mode 7/7 green this session (runs against the repo as found) |
| 8 | [backstop] The suite can actually fail | ✓ VERIFIED | Executed this session: `--fixtures` 8/8 including 3 backstop assertions — a contract-violating fixture (duplicate claim heading + 1 citation anchor) makes the suite exit non-zero and both named cases catch it |

Plan 47-03 (on-device capture):

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Both capture arms exist as separate dumps from the SAME node and helper (D-03, D-04) | ✓ VERIFIED | Both files + session-1 pair in `docs/dumps/re_kit/`; one helper, one node; 47-03 capture record with per-arm triggers |
| 2 | Boot dump taken before any suspend, no intervening modeset (A5) | ✓ VERIFIED | Session record: boot arms pre-suspend, "no PM event before this arm" per device journal; user verdict: desktop image visible |
| 3 | Resume panel-black verdict is the USER's eyes-on report in the session record | ✓ VERIFIED | 47-03 record, verbatim: "CONFIRMED by user: panel BLACK right after wake (16:18:38) and STILL BLACK afterward — the bug reproduced"; sysfs never used for visibility |
| 4 | Both dumps sha256-registered via --register, --verify passes (D-03) | ✓ VERIFIED | Kit verify exit 0 (38 lines OK); manifest has exactly 1 line each for boot/broken/diff artifacts |
| 5 | Per-range counts recorded; short/truncated dump caught BEFORE registration | ✓ VERIFIED | 7296/arm on all four arms; helper floor gate (5000 records); counts recorded in 47-03 summary |
| 6 | Rollback .deb verified with recorded sha256 BEFORE install | ✓ VERIFIED | 47-03 record: `20dc04db…9e91` verified live on device pre-install (matches NO_CLEAN_FIX_PROOF.md) |
| 7 | User-triggered suspend/resume; no SSH step required their eyes; never blamed | ✓ VERIFIED | Per the plan's own runbook, rtcwake-timed suspend IS the user-triggered suspend; user delegated command execution (authorized); user's eyes remained the verdict channel; session-1 missed verdict recorded as-is |
| 8 | [backstop] Second pair ONLY if ambiguous | ✓ VERIFIED | Parse summary 7296/arm, 0 warnings, 0 state rows → not ambiguous → no second bug pair; session-1 pair captured as the honest fallback for the missed at-wake verdict, disclosed as such |

Plan 47-04 (diff + mechanism + handoff):

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `dsi_regs_diff.txt` script-generated from the two registered dumps, manifest-registered (D-03) | ✓ VERIFIED | Rebuild from registered inputs byte-identical (script half); registered (suite case green); parse summary matches 47-03's recorded counts |
| 2 | Doc records diff as cited rows (D-07), non-differing collapsed | ✓ VERIFIED | §4.1 table = the artifact's 14 rows verbatim; per-range counts stated; 32 citation anchors |
| 3 | Per-range exclusion table, every excluded register with TRUE-semantics reason (D-06) | ✓ VERIFIED | §3 mirrors `build_exclusions()` verbatim; suite found 7 distinct reason strings |
| 4 | Reconciliation vs prior 21-row table: reconfirm-prior / explained, positioned as superset | ✓ VERIFIED | Annex: 10 reconfirm-prior, 2 tree-named counters (new-vs-table), 0x13816c bug-associated, 0x160084 variance; 0x46000 not-reproduced (third value 0080013b on all four arms); 8 prior rows out-of-scope; "nothing from 2026-era re-discovered as new" |
| 5 | Exactly ONE mechanism claim, testable, rows 3/18 engaged, state-not-value (D-05) | ✓ VERIFIED | §5: single heading; claim form "GOP sets X=Y (0x160018=00000115, 0x6b010=003fffff, …); broken resume leaves X=Z" with both value sets cited; dedicated rows-3/18 subsection (write-back + 5-register batch disproofs); claim is sequencing-reached operational state, never value restore; falsification condition present |
| 6 | Honest unreachable branch taken where applicable (D-05) | ✓ VERIFIED | DPHY calibration area 0x162000-0x164000 all-ones on ALL FOUR arms recorded honestly (§4.3 + §5 limitation); carried to Phase 48 as replay-the-writes, not guessed diff rows |
| 7 | Doc ends with "what to restore/replicate" list feeding Phase 48 (D-08) | ✓ VERIFIED | §6: concrete target table (8 offsets + boot/broken values + roles), invisible-state replay list (ftrace PHY words), instrument notes (node stays in CI baseline) |
| 8 | Narrow per-string allow markers cover every ledger alias; ledger gate green | ✓ VERIFIED | Exactly one marker (`0x160018`) in both doc and summary; ledger 4/4 (`files=40 hits=0`); untracked-doc gate-probe hits=0 recorded pre-ship |
| 9 | Every claim machine-evidenced; no sysfs panel-visibility claims | ✓ VERIFIED | All 14 claim rows byte-checked against dump lines this session (10 spot-checked exactly: 0x6b004/6b010/6b044/6b080/6b088/6b094/6b098/160018/160084/13816c — all match); verdicts cite the 47-03 eyes-on record |
| 10 | [backstop] Evidence suite green in real mode | ✓ VERIFIED | 7/7 this session, exit 0 |

**Score:** 39/39 truths verified (0 present, behavior-unverified)

### Deferred Items (Step 9b)

No failed truths — nothing to defer. Ship-stage ownership notes (informational, by design): see `deferred_to_ship` in frontmatter. The patch + workflow live on branch `instrument/d330-dsi-dump` (4 commits incl. the post-review WR-02 fix `b753d39`); scripts/doc/dumps are untracked on main; `/gsd-ship` owns all commits.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `patches/d330_dsi_dump.patch` | Additive snapshot-node patch | ✓ VERIFIED | Branch-held (artifact-of-record per phase context); content verified from `git show instrument/d330-dsi-dump` — 3 target files, zero write helpers, gate + markers + kstrtobool + 0600 |
| `.github/workflows/build-kernel.yml` | Apply + grep-proof extended, CCS intact | ✓ VERIFIED | Branch-held; dump refs ×2 + anchors, CCS patch ref intact |
| CI artifact `linux-image-7.0.14-d330-fix_*.deb` | Deployable dump kernel | ✓ VERIFIED | Run 38494943266 `success` (live-checked); deployed on device (`uname -r` = 7.0.14-d330-fix per 47-03, re-verified live 16:26); image deb sha256 recorded |
| `scripts/dsi_mmio_diff.sh` | Diff tooling with selftest | ✓ VERIFIED | On disk (untracked, deferred-commit); selftest 35/35; rebuild reproduces registered artifact |
| `scripts/test_dsi_mmio_evidence.sh` | 7-case evidence guard + fixtures | ✓ VERIFIED | Real 7/7; fixtures 8/8 incl. violating-fixture backstop; no skip patterns |
| `scripts/capture_dsi_dumps.sh` | Capture helper, zero register writes | ✓ VERIFIED | On disk; staged on device (/usr/local/bin, 100755 per 47-03); write-tool count 0 |
| `docs/dumps/re_kit/boot_dsi_regs.txt` + `broken_dsi_regs.txt` | The bug pair | ✓ VERIFIED | 7296 records each; registered; device originals hash-identical (SSH, this session) |
| `docs/dumps/re_kit/{boot,resume}_dsi_regs_session1.txt` | Working-resume contrast pair | ✓ VERIFIED | Registered; at-wake-verdict-missed limitation honestly recorded; used only as contrast |
| `docs/dumps/re_kit/dsi_regs_diff.txt` | Canonical cited diff | ✓ VERIFIED | 71 lines; registered; script half byte-reproducible; annex classifies all 14 offsets |
| `docs/dumps/re_kit/dsi_regs_diff_names.txt` | Tree-verified names | ✓ VERIFIED | 2 entries; both names + exact lines live-verified on the device tree this session (`GEN6_GT_GFX_RC6` intel_gt_regs.h:1544, `GEN9_GT_PM_CONFIG` intel_guc_reg.h:77) |
| `docs/dumps/re_kit/MANIFEST.sha256` | Registration of all artifacts | ✓ VERIFIED | 38 lines; `--verify` exit 0 |
| `docs/research/DSI_MMIO_DIFF.md` | The phase deliverable | ✓ VERIFIED | 7 sections; 32 citation anchors; exactly 1 claim; handoff; 1 narrow marker; clean anti-pattern scan |
| `.planning/.../47-REVIEW.md` + `47-REVIEW-FIX.md` | Review loop record | ✓ VERIFIED | Iteration 2: critical 0 / warning 0, 6 info (IN-01…IN-06); fixes executed not just read |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| patch | CI tree | apply step + grep anchors in build-kernel.yml | WIRED | Run 38494943266 success; both dump anchors resolve; CCS anchors intact |
| registration call | node on device | `d330_dsi_dump_register()` in i915_debugfs.c | WIRED | Node live (D330DSIREG journal lines; node resolved across dri minors); captures produced |
| Makefile | module link | `display/intel_dsi_dump_debugfs.o` in DEBUG_FS list | WIRED | CI compile green (modpost fix commits fb86c6a/30f077c documented); object built on device compile check (508,928 B) |
| dumps | diff artifact | `dsi_mmio_diff.sh boot broken --names` | WIRED | Rebuild byte-identical (this session) |
| diff artifact | doc rows | §4.1/§4.2 quote artifact rows | WIRED | Values byte-checked against capture lines |
| kit manifest | evidence suite | cases 1-2 (manifest-covers + verify) | WIRED | Real mode 7/7 green |
| doc handoff | Phase 48 fix plan | §6 targets + instrument notes | WIRED | Concrete offsets + values + mechanism shape; node stays in CI baseline for at-wake re-dump |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| boot/broken dumps | register records | device MMIO walk (in-kernel) via node echo + cat | Yes — device originals hash-identical to repo copies | ✓ FLOWING |
| dsi_regs_diff.txt | diff rows | script join of the two registered dumps | Yes — byte-reproducible from inputs | ✓ FLOWING |
| DSI_MMIO_DIFF.md rows | cited values | capture-file lines (e.g. boot:1033, broken:1033) | Yes — every load-bearing value byte-verified | ✓ FLOWING |
| names file | register names | device-tree grep (live re-verified) | Yes | ✓ FLOWING |

No static returns, hardcoded literals, or mocks feeding any claim.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Evidence suite real mode | `bash scripts/test_dsi_mmio_evidence.sh` | 7/7, exit 0 | ✓ PASS |
| Suite can fail (backstop) | `bash scripts/test_dsi_mmio_evidence.sh --fixtures` | 8/8 incl. violating-fixture non-zero | ✓ PASS |
| Diff tooling classification branches | `bash scripts/dsi_mmio_diff.sh --selftest` | 35/35, exit 0 | ✓ PASS |
| Ledger gate | `bash scripts/test_pitfalls_ledger.sh` | 4/4, `files=40 hits=0` | ✓ PASS |
| RE evidence suite (guard chain) | `bash scripts/test_re_diff_evidence.sh` | 6/6, exit 0 | ✓ PASS |
| Kit integrity | `bash scripts/prepare_safety_kit.sh --verify --kit-dir docs/dumps/re_kit` | 38 artifacts OK, exit 0 | ✓ PASS |
| Diff artifact provenance | rebuild from registered dumps + names, compare | byte-identical (script half, 32/32 lines) | ✓ PASS |
| CI run claim | `gh run view 38494943266 --json conclusion,headBranch` | `success`, `instrument/d330-dsi-dump` | ✓ PASS |
| Capture authenticity | SSH sha256 of device originals | matches repo copies + manifest exactly | ✓ PASS |
| Tree-name claims | SSH grep of device kernel tree | both names at exactly the cited lines | ✓ PASS |

### Probe Execution

| Probe | Command | Result | Status |
|-------|---------|--------|--------|
| Phase evidence guard (real) | `bash scripts/test_dsi_mmio_evidence.sh` | exit 0, 7/7 | PASS |
| Phase evidence guard (fixtures + backstop) | `bash scripts/test_dsi_mmio_evidence.sh --fixtures` | exit 0, 8/8 | PASS |
| Diff selftest | `bash scripts/dsi_mmio_diff.sh --selftest` | exit 0, 35/35 | PASS |
| Ledger gate | `bash scripts/test_pitfalls_ledger.sh` | exit 0, 4/4 | PASS |
| RE guard | `bash scripts/test_re_diff_evidence.sh` | exit 0, 6/6 | PASS |
| Kit verify | `bash scripts/prepare_safety_kit.sh --verify --kit-dir docs/dumps/re_kit` | exit 0 | PASS |

SUMMARY.md probe claims were not trusted — every gate was re-executed in this verifier's own process this session.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| MMIO-01 | 47-01, 47-02, 47-03, 47-04 | Hardware-level register diff between working fresh boot and broken resume, for registers kernel tooling cannot show; CI-built debug/dump patch; diff + interpretation in `DSI_MMIO_DIFF.md` | ✓ SATISFIED | Dump node in CI-built i915 (no `i915_dsi_info` needed); 7296-word boot/resume pair + contrast pair, checksummed, registered; cited diff artifact; doc complete |
| MMIO-02 | 47-04 | The diff names the mechanism: which hardware state the GOP sets that the resume path does not, as a testable claim | ✓ SATISFIED | §5: GOP sets the DSI operational state X=Y (7 cited registers); broken resume fails to re-reach it (leaves X=Z, timeout-marked); working resume re-reaches it byte-for-byte; falsifiable by Phase-48 sequencing replication + at-wake re-dump |

Orphaned requirements: none — REQUIREMENTS.md maps Phase 47 → {MMIO-01, MMIO-02} only; both claimed by plans.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | No TBD/FIXME/XXX/PLACEHOLDER/stub/empty-impl patterns in any phase file | — | Clean |

Info-level note (already tracked as REVIEW IN-06, out of fix scope by review decision): DSI_MMIO_DIFF.md §1/§7 describe the diff run as `scripts/dsi_mmio_diff.sh … (run in docs/dumps/re_kit/)` — from that cwd the literal `scripts/` prefix does not resolve (this verifier reproduced the same miss on first attempt; correct form is a repo-root run or `../../../scripts/` prefix). The rebuild itself is proven byte-identical, so provenance stands; only the reproducibility instructions degrade.

### Test Quality Audit

| Test File | Linked Req | Active | Skipped | Circular | Assertion Level | Verdict |
|-----------|-----------|--------|---------|----------|-----------------|---------|
| scripts/test_dsi_mmio_evidence.sh | MMIO-01 | 7 real + 8 fixtures | 0 | No (violating-fixture backstop proves non-circularity) | Value/behavioral (exact counts, headings, markers; negative backstop) | VALID |
| scripts/dsi_mmio_diff.sh --selftest | MMIO-01 | 35 | 0 | No (hand-authored fixtures, expected offsets/verdicts asserted exactly) | Value-level (exact offset lists + verdicts + citations + determinism cmp) | VALID |
| scripts/test_pitfalls_ledger.sh | MMIO-01/02 (gate) | 4 | 0 | No | Behavioral (fails on banned lever; marker honored) | VALID |

**Disabled tests on requirements:** 0 · **Circular patterns:** 0 · **Insufficient assertions:** 0

### Decision Coverage

`check.decision-coverage-verify`: skipped — "No trackable decisions in CONTEXT.md" (the `<decisions>` block is prose, not ID-tagged). Non-blocking. All CONTEXT decision themes were nonetheless honored and machine-checked: debugfs node (not devcoredump/out-of-tree module) — built; locked 5-range scope + full block — verbatim in patch + captures; manual echo trigger both arms — done; separate per-state dumps, kit-registered — done; inhibit + 18 s window + rtcwake — recorded; one pair (second only if ambiguous) — honored; ONE named mechanism (not top-3) — suite-enforced; exclusion table with reasons — present; Phase-48 handoff — present; ledger gate green throughout.

### Prohibition Review (LLM judge — NON-AUTHORITATIVE, human review recommended)

All 4 plans self-declare their prohibition blocks as "flagged-unverified" (recalled from research/pitfalls; no SPEC `## Prohibitions` exists — EDGE_ABSENT). Per the escalation-gate rule these are recorded here with LLM-judged verdicts + enforcement evidence; they are not silently absorbed into `passed`:

- **47-01 (6/6 satisfied):** dmesg-as-channel — single pr_info + frozen buffer ✓; ungated DSI reads — gate in code ✓; cat-re-walks — snapshot-by-construction ✓; touching DSI enable/disable path — 3 additive target files only ✓; world-readable node — 0600 ✓; intel-gpu-tools — not used ✓.
- **47-02 (4/4 satisfied):** all-ones as ordinary diffs — state-row classification + selftest C ✓; silent exclusions — excluded rows print with reasons ✓; hard-coded conclusions — rows computed from captures (rebuild-proven) ✓; banned-lever re-proposal — ledger gate hits=0 ✓.
- **47-03 (7/7 satisfied):** agent-triggered suspend — plan-prescribed rtcwake with user authorization; eyes remained verdict channel (judgment call, flagged for the human checkpoint) ⚠→✓; no inhibit — held per record ✓; window <18 s — trigger 0-1 s after wake ✓; cold-boot-as-reference — fresh-boot arms used ✓; unverified rollback — verified pre-install ✓; interpreting a lit-resume pair — session-1 kept contrast-only, no at-wake claim ✓; on-device module substitution — CI kernel deployed ✓.
- **47-04 (7/7 satisfied):** value-restore claim — explicitly sequencing-state ✓; >1 claim — suite single-claim ✓; uncited rows — all cited ✓; silent drops — everything printed with reasons ✓; unmarked aliases — 1 narrow marker, gate green ✓; sysfs visibility claims — eyes-on citations ✓; softened handoff — concrete instrument + targets ✓.

### Human Verification Required

None outstanding from automated checks. This evidence/tooling phase's one user-facing element — the on-device capture session — already executed as the plan's blocking `checkpoint:human-verify` task, with the user's eyes-on verdicts recorded verbatim in 47-03 (boot: image visible; broken resume: black at wake and after — bug reproduced; session-1 at-wake verdict missed, recorded honestly). At the end-of-phase checkpoint, the recommended human items are:

1. **Prohibition spot-check** — review the LLM-judged prohibition verdicts above (especially the 47-03 suspend-trigger delegation judgment call).
2. **Ship-stage confirmation** — the deferred_to_ship list (branch merge + 100755 staging + evidence commits) is acknowledged as /gsd-ship scope.

### Gaps Summary

None. All 39 must-haves verified; every machine gate re-executed green in this verifier's own process; the captures' authenticity chain closed against the device originals; the mechanism claim's cited values byte-verified against the actual dump lines; the diff artifact proven byte-reproducible from its registered inputs; the CI run live-confirmed; the review loop closed at 0 critical / 0 warning.

Phase goal achieved: the hardware truth below the kernel's software model is captured on both arms, and the differing mechanism is named as ONE testable, falsifiable claim with a concrete Phase-48 handoff.

---

_Verified: 2026-10-14T21:45:00Z_
_Verifier: the agent (gsd-verifier)_
