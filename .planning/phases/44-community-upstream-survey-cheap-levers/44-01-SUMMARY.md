---
phase: 44
plan: 44-01
wave: 1
status: complete
commits:
  - 246635d
  - 155f17f
  - 8c6a563
requirements: [SURVEY-01, SURVEY-02, SURVEY-03]
---

# Plan 44-01 — On-Device Kernel Sweep + Upstream Survey + Bug Report

## What shipped

- `docs/research/KERNEL_SWEEP_EVIDENCE.md` — full two-arm S3 sweep record on the device (7.0.14-d330-fix at 14:48, 7.0.0-38-generic at 15:34 local): cmdlines verbatim, boot ids, pre/post DSI sysfs state, clean resume log excerpts (module banners 2283 ms / 3021 ms), panel-verdict reliability section (verdicts UNRELIABLE — see deviations), method deviation (no systemd-inhibit hold; detached rtcwake only), and the environment facts needed to reproduce (Kubuntu GRUB `env_block=512+1` dual-store mechanics at raw LBA 512-513 of the btrfs root partition, `grub-reboot` submenu-id truncation, eMMC index flip mmcblk0↔mmcblk1, by-uuid addressing rule).
- `docs/research/UPSTREAM_SURVEY.md` — house survey shape: method note (Windows-host fetching; tracker bot-walled), 9-source findings table with URLs (issue 6619, Jinman Ma Aug-2026 DSI command-mode acknowledgment, ICL+-only fixes pull, 2017 GLK cold-boot groundwork, lkml 2026-09-07 eDP regression, ChromeOS UNREACHABLE, lucasgabmoreno repo, Mint forum 2026-03, Zimmermann sysfb v7.4 series), the 615c8ec48621 analysis (v6.18, no stable backport, fastset cleanup not a resume fix, `has_dsic_clock` present at `vlv_dsi_pll.c:266` in the device tree), sweep results, and the SURVEY-01/02 conclusion block (no tracked-and-fixed GLK DSI resume-black regression upstream, qualified; no additional mainline sweep warranted).
- `docs/upstream/I915_BUG_REPORT_GLK_DSI_RESUME.md` — paste-and-submit upstream report: hardware identity, kernel versions, one-command reproducer (`rtcwake -m mem -s 30`), the full i915 unbind/bind recovery as the only working control, clean journalctl resume excerpt, sysfs states, ruled-out list (615c8ec48621, PSR/FBC already off, module-reload/reset/rescan failures), maintainer ask, and the issue-6619 update-or-new filing instruction. Mainline tools only; no repo-internal references.
- Device left in restored state: `7.0.14-d330-fix` running, `GRUB_DEFAULT="1>0"` restored, `update-grub` re-run, both GRUB env stores cleared to header-only, stray files removed.

## Verification

- `bash scripts/test_pitfalls_ledger.sh` → `passed=4 failed=0` (both new research docs carry the per-string planner-discipline-allow markers for `i915.enable_psr=0` and `i915.enable_fbc=0`; survey doc additionally for `systemctl mask`, `xrandr`, `sleep.target`).
- Doc checks: survey doc non-empty, contains `615c8ec48621`, records unreachable sources; bug report present under `docs/upstream/`.
- `bash scripts/test_storage_cellular.sh --dry-run` (via chain runner) → `CHAIN_EXIT=0`, all 38 suites green.

## Deviations

- **Panel verdicts unreliable (the headline deviation).** The plan assumed one structured user pause per arm with a decisive lit/black verdict. Reality: the user answered immediately per arm (arm A "stayed BLACK", arm B "came back LIT"), then retracted the distinction ("both black but lit"), stated they were not looking at the device continuously, and could not recall either arm's outcome when asked precisely. A re-test with a three-state vocabulary was offered and declined. Recorded honestly: the kernel-axis good/bad pair is NOT established; the upstream report claims only the measurable evidence (clean kernel logs both arms) and the user's multi-session experience on the d330-fix kernel.
- **Arm A confound:** pre-suspend `dpms=Off` (panel already timed off), so arm A tested resume-from-dark-panel while arm B tested resume-from-lit-panel; the inter-arm sysfs delta is not attributable to the kernel version.
- **Method deviation:** no `systemd-inhibit` hold as the plan specified; the sweep ran detached with rtcwake only (no human input during arms). Recorded in the evidence doc.
- **One-time grub config change (user-approved before starting):** `GRUB_DEFAULT="1>0"` → `saved` for two kernel switches, then fully reverted with `update-grub` and both env stores cleared. Kubuntu's custom GRUB env mechanics required writing `next_entry=1>2` (numeric path) directly into the embedded block (raw LBA 512-513 of the btrfs partition) and `/boot/grub/grubenv`; `grub-reboot` with submenu entry ids truncated its value on this device. Two redirect bugs (`A>B` unquoted inside `sh -c`) produced stray files/short values, all cleaned up and documented for reproducibility.
- The plan's Task 2 conclusion wording ("the sweep shows the installed kernels fail resume") was replaced with the honest framing: kernel logs clean on both arms, panel verdicts unreliable, differentiator not isolated.
- Executed inline by the orchestrator (subagent dispatch broken, disclosed at wave start; ISOLATION=none milestone-wide, sequential execution).

## Requirements touched

- SURVEY-01: upstream/community state established with cited sources and honest unreachability marks.
- SURVEY-02: both bootable kernels S3-cycled on-device with captured evidence; known GLK DSI commit verified present in both; no wider sweep warranted.
- SURVEY-03: upstream-ready bug report prepared at `docs/upstream/I915_BUG_REPORT_GLK_DSI_RESUME.md`; filing remains a user handoff (tracker bot-walled, no credentials on this machine).

<!-- planner-discipline-allow: i915.enable_psr=0 -->
<!-- planner-discipline-allow: i915.enable_fbc=0 -->
