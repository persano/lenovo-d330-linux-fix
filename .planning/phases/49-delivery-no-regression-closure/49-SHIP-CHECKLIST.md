---
plan: 49-03
phase: 49-delivery-no-regression-closure
doc: ship checklist (work order for /gsd-ship)
created: 2026-10-16
status: armed — nothing here has been executed yet (no merge, no push, no code/data commit)
inventory_source: git status --porcelain=v1 --untracked-files=all (run fresh 2026-10-16, 52 lines, all classified)
---

# 49-SHIP-CHECKLIST — /gsd-ship work order (v9.0 delivery)

This file is a PLAN, not an execution record. No merge, no push, and no
commit of code or data has been performed by 49-03 (deferred-commit
machine). /gsd-ship owns every action below.

## (a) DONE-02 close table — the five guard bars (2026-10-16, 49-03 Task 1 sweep)

| # | Command | Expected (pinned) | Actual (verbatim) | Exit code |
|---|---------|-------------------|-------------------|-----------|
| 1 | `bash scripts/test_pitfalls_ledger.sh` | `passed=4 failed=0` | `Ledger gate: files=51 hits=0` … `Ledger gate suite summary: passed=4 failed=0` | 0 |
| 2 | `bash scripts/test_dsi_mmio_evidence.sh` | `passed=7 failed=0` | `DSI MMIO evidence suite summary: passed=7 failed=0` (mmio-kit-verify, manifest-covers 3 artifacts, citations >=10, exclusion-table 7 reasons, single-claim, handoff, allow-markers — all [OK]) | 0 |
| 3 | `bash scripts/test_dsi_mmio_evidence.sh --fixtures` | `passed=8 failed=0` | `DSI MMIO evidence suite summary: passed=8 failed=0` (5 fixture cases + 3 backstop cases all [OK]) | 0 |
| 4 | `bash scripts/prepare_safety_kit.sh --kit-dir docs/dumps/re_kit --verify` | every artifact OK incl. close1-3 dumps + diffs | 65 artifact lines all `OK`, incl. `close1_boot/close1_resume/close1_lit`, `close2_*` (boot/resume/lateblack), `close3_*` (boot/resume/lateblack) and every `dsi_regs_diff_close*` diff; final line `[OK] safety kit verified: all artifacts match docs/dumps/re_kit/MANIFEST.sha256` | 0 |
| 5 | `bash scripts/dsi_mmio_diff.sh --selftest` | `selftest summary: passed=35 failed=0` | `selftest summary: passed=35 failed=0` (cases A,B,B2,C,D,E,F,G,H,I all [OK]) | 0 |

Ledger invariant: `docs/research/RESUME_FIX_LEDGER.md` header still reads
`## Lever rows: 32` — rows 30-32 stand as final truth; zero row appends
made by this plan (the 49-01 cycles are confirmation captures, not levers).

**Corrected full-suite command** (verbatim for future re-runs; the
48-VALIDATION.md variant lacks `--kit-dir` and fails today — its bare
`--verify` targets `docs/dumps/safety_kit`, which does not exist):

```
bash scripts/test_pitfalls_ledger.sh && \
bash scripts/test_dsi_mmio_evidence.sh && \
bash scripts/test_dsi_mmio_evidence.sh --fixtures && \
bash scripts/prepare_safety_kit.sh --kit-dir docs/dumps/re_kit --verify && \
bash scripts/dsi_mmio_diff.sh --selftest
```

## (b) Ship list (D-05 / D-06 / D-07)

**Branch merge — AS-IS.** `instrument/d330-dsi-dump` merges to `main` as-is
at /gsd-ship. Measured range (fresh `git log --oneline instrument/d330-dsi-dump ^main`):
**11 commits, fdafc43 → 550cb55** (the 49-03-PLAN line said 8 — stale
number superseded by the measured log; range endpoints unchanged):

```
550cb55 ci(48-01): apply the iter-3 MIPIO reset patch after the iter-2 apply
41325d1 feat(48-01): DMI-gated iter-3 fix patch - pulse the DSI-block MIPIO reset at the top of resume-enable on 82H0
18c12f7 fix(48-01): re-create the DSI dump node on every probe - unbind/bind killed it
65c0b01 ci(48-01): apply the iter-2 panel power cycle patch, retarget the DMI gate anchor
f1914da feat(48-01): DMI-gated iter-2 fix patch - full panel power-off settle at the top of resume-enable on 82H0
122a75c ci(48-01): apply the iter-1 DMI fix patch and grep-anchor its DMI gate in build-kernel.yml
1418a8b feat(48-01): DMI-gated iter-1 fix patch - clear retained DSI DEVICE_READY before GLK enable probe on 82H0
b753d39 fix(47): WR-02 gate DSI PHY walk and PHY overlay reads behind the DSI PLL gate
30f077c fix(47): drop ampersand at i915_debugfs.c call site - i915->display is already struct intel_display *
fb86c6a fix(47): register dump node from i915-only i915_debugfs.c
fdafc43 feat(47): i915_dsi_regs debugfs dump node + CI apply
```

CI-green anchors (per 49-03-PLAN / 49-RESEARCH §2): 2× CCS, 2× dump-node,
DMI gate, it3 pulse marker. All dumps/kernels DMI-gated 82H0 — harmless on
other machines (v8.0 failed-candidate precedent).

**it1 patch: git-history-only.** Ledger row 30 — the iter-1 fix patch is
NEVER applied by CI at ship; it exists only as documented history on the
branch (commit 1418a8b + its ci apply commit).

**Deferred-commit inventory** — built mechanically from
`git status --porcelain=v1 --untracked-files=all` (52 lines; every line
classified exactly once, none unaccounted):

SHIP-COMMIT (46 lines) — stage and commit all of these at /gsd-ship:

- `M  .planning/config.json` — `use_worktrees: false` deliberate machine
  setting (research §2: commit it at ship).
- `M  docs/research/UPSTREAM_HANDOFF.md` — v9.0 addendum
  (mechanism-unreachable summary; OPTIONAL documentation, blocks nothing).
- `?? .planning/phases/48-clean-dmi-gated-fix-mmio-guided/48-02-PROGRESS-task1.md`
  — phase-48 progress record (planning doc; the only planning-phase file
  still untracked).
- `?? docs/dumps/re_kit/*.txt` — 26 files (the session1 + it1/it2/it3 +
  close1/close2/close3 dump arms and their non-close diffs):
  `boot_dsi_regs.txt`, `boot_dsi_regs_session1.txt`, `broken_dsi_regs.txt`,
  `close1_boot_dsi_regs.txt`, `close1_lit_dsi_regs.txt`,
  `close1_resume_dsi_regs.txt`, `close2_boot_dsi_regs.txt`,
  `close2_lateblack_dsi_regs.txt`, `close2_resume_dsi_regs.txt`,
  `close3_boot_dsi_regs.txt`, `close3_lateblack_dsi_regs.txt`,
  `close3_resume_dsi_regs.txt`, `dsi_regs_diff.txt`, `dsi_regs_diff_it1.txt`,
  `dsi_regs_diff_it2.txt`, `dsi_regs_diff_it3.txt`,
  `dsi_regs_diff_lit_vs_wake.txt`, `dsi_regs_diff_names.txt`,
  `it1_boot_dsi_regs.txt`, `it1_resume_dsi_regs.txt`,
  `it2_boot_dsi_regs.txt`, `it2_resume_dsi_regs.txt`,
  `it3_boot_dsi_regs.txt`, `it3_resume_dsi_regs.txt`,
  `reload_lit_dsi_regs.txt`, `resume_dsi_regs_session1.txt`
  (the close1-3 diff files + `MANIFEST.sha256` are ALREADY tracked and
  unmodified — verified via `git ls-files`; 21 re_kit files tracked total).
- `?? scripts/*` — 19 helpers (capture/session/debug/deploy/verify):
  `capture_d330_boot_arm.sh`, `capture_dsi_dumps.sh`,
  `close_session_d330.sh`, `debug_d330_dumpnode.sh`, `debug_d330_node.sh`,
  `debug_d330_rebind.sh`, `deploy_48_it2_via_gitbash.sh`,
  `deploy_48_it2_via_wsl.sh`, `deploy_48_via_wsl.sh`, `dsi_mmio_diff.sh`,
  `fetch_close_dumps.ps1`, `fetch_it1_dumps.sh`, `read_session2_script.sh`,
  `reload_d330_display.sh`, `run_session3.sh`, `session3_d330.sh`,
  `test_deploy_dryrun.sh`, `test_dsi_mmio_evidence.sh`,
  `verify_d330_deploy.sh`
  (already-tracked helpers: `prepare_safety_kit.sh`, `deploy_d330_kernel.sh`,
  `test_pitfalls_ledger.sh` et al. — 49 tracked scripts total, unmodified).

Already committed, nothing to do: `docs/research/DSI_MMIO_DIFF.md` (its §5.2
correction edits are already in history — no porcelain line), all
`*-PLAN.md`/`*-SUMMARY.md` under `.planning/phases/49-*/*`,
`.planning/milestones/v9.0-close-out.md`, `docs/research/RESUME_FIX_LEDGER.md`.

NEVER-COMMIT (4 lines) — runtime state; exclude from any staging:

- `.gsd/.gsd-allow-shrink` — runtime sentinel
- `.gsd/dispatch-isolation-sentinel.json` — runtime sentinel
- `.gsd/milestone.lock` — runtime lock
- `.planning/milestone.lock` — runtime lock

Guard rules carried into /gsd-ship: no `*.deb` anywhere in this tree (the
rollback assets live only on the device — never remove them, D-12); no
local patch staging files exist in the porcelain output.

## (c) Push state

`main` is **47 commits ahead of `origin/main`** (measured:
`git rev-list --count main ^origin/main` = 47; the 49-RESEARCH §2 figure of
35 was stale at plan time). Push happens at /gsd-ship only — never before.
The `instrument/d330-dsi-dump` branch merge (section b) rides the same push.

## (d) Post-ship device expectations

The merges and the push do NOT touch the device. End-state stays per
D-12 / v9.0-close-out §4 (verified live by 49-03 Task 1, 2026-10-16):

- `uname -r` → `7.0.14-d330-fix` (exit 0)
- Dump node resolves: `/sys/kernel/debug/dri/0000:00:02.0/i915_dsi_regs`
  (root-glob also lists the driver aliases `dri/1` and `dri/128`; exit 0).
  NOTE for re-runs: the debugfs glob must run INSIDE a root shell
  (`sudo sh -c 'ls /sys/kernel/debug/dri/*/i915_dsi_regs'`); a non-root
  ssh glob cannot traverse debugfs and fails with exit 2.
- Rollback chain sha-verified on device (exit 0, verbatim):
  - `/home/santiago/deploy_incoming_fea98e575ad2.deb` =
    `fea98e575ad2d2aa5aad0728b1c3c6855e7c14be9fe4d36c0d9a62704d1dc876` ✓
  - `/home/santiago/d47_dump_kernel.deb` =
    `ba47df8dd595c87649ce2a91a9e087e9cd90c20e166eee44f302dd1876fe87be` ✓
- Recovery order unchanged: current it3 kernel → d47 dump kernel →
  Phase-43 live USB / golden module. Recovery = manual reboot only
  (ledger row 29; no automation ever — D-09/D-10).

## (e) Escalation note

If 49-01 had halted on a new falsifier (a cycle contradicting the §5.2
contrast), this checklist is VOID and the fix ladder owns the next step.
It did not: all 3 cycles completed, verdicts "Black but lit" ×3, the
late-black-vs-boot contrast reproduced in 2 independent cycles. This
checklist stands.
