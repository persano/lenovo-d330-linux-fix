---
plan: 47-03
phase: 47-dsi-mmio-truth-boot-vs-resume-hardware-register-diff
status: complete
deferred_commit: true
completed: 2026-10-14
subsystem: dsi-mmio-capture
tags: [mmio-01, dsi, s3-resume, evidence, kit]
requires:
  - 47-01 CI dump kernel (run 38494943266, image deb sha256 ba47df8d…fe87be)
provides:
  - One registered boot/resume dump pair (session 2, bug reproduced) in docs/dumps/re_kit/
  - Session-1 working-resume contrast pair registered alongside
  - scripts/capture_dsi_dumps.sh helper (repo + staged on device)
affects:
  - 47-04 (diff inputs are the two registered session-2 arms)
tech-stack:
  added: []
  patterns: [kit-manifest-registration, snapshot-at-trigger-capture]
key-files:
  created:
    - scripts/capture_dsi_dumps.sh
    - docs/dumps/re_kit/boot_dsi_regs.txt
    - docs/dumps/re_kit/broken_dsi_regs.txt
    - docs/dumps/re_kit/boot_dsi_regs_session1.txt
    - docs/dumps/re_kit/resume_dsi_regs_session1.txt
  modified:
    - docs/dumps/re_kit/MANIFEST.sha256
decisions:
  - All four dumps registered in the kit manifest (script supported repeatable --register with no scheme change) — session-1 pair is honest evidence, registered like the primary pair
  - Session-1 kept as working-resume contrast pair only; user's missed at-wake verdict recorded as-is, never attributed as fault
  - Device end-state per plan — dump kernel STAYS installed; known-good deb remains the rollback artifact; no restore step
metrics:
  duration: ~2h (session 1 11:12-11:14, session 2 16:16-16:18, continuation 16:23-16:29)
  completed: 2026-10-14
actuals:
  tokens: 135000
  tasks: 3
  commits: 0
---

# Phase 47 Plan 03: On-Device Capture Session Summary

One checksummed boot/resume DSI MMIO pair (bug reproduced, panel black at wake and after) plus a working-resume contrast pair, all four registered in the RE kit manifest, verify green.

## What Was Built

- `scripts/capture_dsi_dumps.sh` — per-arm capture helper (node resolve across dri minors, trigger echo, D330DSIREG dmesg wait, frozen-buffer cat, sha256, per-section count check, 5000-record floor gate). Zero register writes; staged on device at `/usr/local/bin/capture_dsi_dumps.sh` (root-owned, 10585 B).
- Four DSI MMIO dumps in `docs/dumps/re_kit/` — session 2's boot/resume pair (the bug pair) and session 1's boot/resume pair (working-resume contrast), each 7296 records.
- `docs/dumps/re_kit/MANIFEST.sha256` — 4 new lines, one per dump, registered via `prepare_safety_kit.sh --register` (idempotent).

## Tasks

| # | Task | Status | Proof |
|---|------|--------|-------|
| 1 | Capture helper + dump-kernel deploy with verified rollback | DONE | Deploy from CI run 38494943266 (image deb sha256 `ba47df8d…fe87be`); rollback deb verified live on device (`20dc04db…9e91`, matches NO_CLEAN_FIX_PROOF.md record) BEFORE install; post-reboot `uname -r` = `7.0.14-d330-fix` (re-verified live 16:26); node live (D330DSIREG lines in journal) |
| 2 | The ONE on-device session — boot dump → suspend/resume → resume dump | DONE | Two sessions executed 2026-10-14 (see Capture Record); user verdicts recorded verbatim; hashes match device originals |
| 3 | Register both dumps in the RE kit manifest | DONE | 4 lines registered; `--verify` exit 0 (all 36 manifest lines OK); `grep -c 'boot_dsi_regs.txt\|broken_dsi_regs.txt'` = 2; pitfalls ledger 4/4 green; RE evidence suite 6/6 green (cases 1-2 went green as planned) |

## Capture Record

All timestamps device-local (-03). Both sessions ran on the same dump kernel (`7.0.14-d330-fix`). Evidence pulled from device journal (`journalctl -k`, boots -1 and 0); device originals at `/home/santiago/d330_dsi_capture{,2}/` verified sha256-identical to the fetched repo copies.

### Session 1 — working-resume contrast pair (device boot -1, 11:07:49–15:23:18)

| Arm | D330DSIREG trigger | PM evidence | sha256 | Repo file | Panel verdict (user) |
|-----|--------------------|-------------|--------|-----------|----------------------|
| boot | 11:12:23 | (pre-suspend; no PM event before this arm) | `d375e9e4ec11c7f4f6745353459a8551ff4ca5af80824fb67031220298a9f714` | `boot_dsi_regs_session1.txt` | desktop image visible at capture |
| resume | 11:14:41 (0 s after wake) | suspend entry (deep) 11:14:20 → suspend exit 11:14:41 | `d9e7759c53c2102613795a392afcc0f8eb0c3cbc521c2548d8e90297e6bd0d09` | `resume_dsi_regs_session1.txt` | panel image came up later (working resume); at-wake verdict MISSED by the user — recorded as such, never attributed as fault |

Session 1 is registered as a contrast pair: it shows what a WORKING resume looks like at the register level. It is not the bug pair and makes no at-wake claim.

### Session 2 — the bug pair (device boot 0, started 15:23:53)

| Arm | D330DSIREG trigger | PM evidence | sha256 | Repo file | Panel verdict (user) |
|-----|--------------------|-------------|--------|-----------|----------------------|
| boot | 16:16:46 | (pre-suspend; no PM event before this arm) | `99af22aec45410596c132ff170e39287cf568829c24d8980dbcef2877e9f2399` | `boot_dsi_regs.txt` | desktop image visible at capture |
| resume | 16:18:39 (0 s after wake — inside the ≤18 s window) | suspend entry (deep) 16:17:50 → suspend exit 16:18:39 | `a858df424d41b6eb01328bac223194839a1f715ceeca216c6d003a22bda0f918` | `broken_dsi_regs.txt` | CONFIRMED by user: panel BLACK right after wake (16:18:38) and STILL BLACK afterward — the bug reproduced |

Session discipline: the user was authorized to delegate command execution via SSH; suspend/resume triggers ran scripted with idle-inhibit held. The user's eyes remained the panel-verdict channel; sysfs was never trusted for panel visibility. No failed capture was attributed to the user. Second pair not scheduled (47-04 may request one only if the diff is ambiguous, per D-04 backstop).

### Per-section integrity (all four dumps identical shape)

- 7296 record lines each = expected 1024 (DSI ports 0x6b000) + 4096 (DSI PHY 0x160000) + 1024 (PLL/CDCLK 0x46000) + 128 (legacy PPS 0xc7200) + 1024 (GT DISP PWRON 0x138000)
- 0 `# SKIPPED` markers — DSI sections READABLE on all four arms (no PLL-off gate trip)
- Named overlay present; helper floor check passed on every arm (caught-before-registration gate held)

First-data-row corroboration of the bug (0x6b000 DSI block): boot arm `0x6b000=00000001, 0x6b004=00080000, 0x6b010=003fffff` vs broken-resume arm `0x6b000=00000001, 0x6b004=40280000, 0x6b010=0000b8ea` — real differences exist for 47-04's diff.

## 47-01 Artifact Provenance

- CI run 38494943266 (`instrument/d330-dsi-dump`, sha 30f077c): `linux-image-7.0.14-d330-fix_7.0.14-1_amd64.deb` sha256 `ba47df8dd595c87649ce2a91a9e087e9cd90c20e166eee44f302dd1876fe87be` — deployed, device now runs it
- Known-good rollback retained at device `~/linux-image-7.0.14-d330-fix_7.0.14-1_amd64.deb`, sha256 `20dc04db5dab7066333e2382896af43cf50622276b9d8f62c75d3d92a2839e91` (re-verified live post-session)
- Device end-state (per plan): dump kernel STAYS installed; no restore-to-known-good step

## Deviations from Plan

1. **[Rule 2 - auto-added, evidenced] Node path drift across dri minors.** Post-deploy boot enumerated i915 as card1/dri/1, so the helper resolves the node across `/sys/kernel/debug/dri/*/i915_dsi_regs` (prefers minor 0, warns on non-canonical). Plan pinned the literal dri/0 path.
2. **[Deferred-commit override] Task 3 action 4 said "commit the manifest change"** — this project runs deferred-commit mode; the manifest + dump registrations are recorded in the Deferred Commits ledger below instead. `/gsd-ship` commits them.
3. **[Session-1 registration]** Resume instructions' fallback (sha256s only in summary) not needed — `--register` is repeatable with no scheme change, so all four files went into the manifest directly.

## Deferred Commits

All code/data changes uncommitted — will be committed by /gsd-ship.

- `feat(47-03): DSI MMIO capture helper + dump-kernel deploy with verified rollback` — files: `scripts/capture_dsi_dumps.sh` (stage 100755 at ship; device copy at /usr/local/bin/capture_dsi_dumps.sh)
- `feat(47-03): register boot/resume DSI dump pairs in re_kit manifest` — files: `docs/dumps/re_kit/MANIFEST.sha256`, `docs/dumps/re_kit/boot_dsi_regs.txt`, `docs/dumps/re_kit/broken_dsi_regs.txt`, `docs/dumps/re_kit/boot_dsi_regs_session1.txt`, `docs/dumps/re_kit/resume_dsi_regs_session1.txt` (txts whitelisted by `.gitignore` `!docs/dumps/re_kit/*.txt` — kit convention commits text evidence, binaries stay out; 45-02 displayinfo precedent)

## Self-Check

- [x] All 4 dumps exist in docs/dumps/re_kit/, hashes match session records and device originals
- [x] MANIFEST.sha256 verify exit 0 (36 lines, all OK)
- [x] Manifest grep count for boot/broken arms = 2
- [x] Pitfalls ledger green (4/4), RE evidence suite green (6/6)
- [x] Device live checks: `uname -r` = 7.0.14-d330-fix; rollback deb sha256 20dc04db…9e91; helper staged 100755
- [x] scripts/capture_dsi_dumps.sh exists in repo (untracked, deferred)

## Self-Check: PASSED
