---
phase: 44
slug: community-upstream-survey-cheap-levers
created: 2026-10-12
status: discussed
---

# Phase 44 — Context: Community & Upstream Survey + Cheap Levers

## Goal (from ROADMAP)

Settle the cheap, high-leverage questions before any costly bisect or RE:
does upstream already fix GLK DSI resume (SURVEY-01), does the test kernel
carry the known GLK DSI fix `615c8ec48621` and does a mainline sweep yield a
good/bad kernel pair (SURVEY-02), and is a correctly-formed i915 bug report
(trace + reproducer) filed or prepared for the upstream tracker (SURVEY-03).

## Device access (new this session)

- The test unit is reachable: `192.168.2.195:22`, user `santiago` (LAN only).
  Credentials live in `.env` (gitignored, NEVER committed or echoed into repo
  files). SSH runs as a normal user; root via sudo with the same password.
- Device facts at phase start: running kernel `7.0.14-d330-fix` (custom build,
  2026-10-10), also installed `7.0.0-30-generic` and `7.0.0-38-generic`; DMI
  `82H0`; cmdline carries `i915.enable_psr=0 i915.enable_fbc=0` (existing
  shipped mitigation, not a resume fix); **the
  `/usr/lib/systemd/system-sleep/lenovo-d330-display-resume.sh` hook is NOT
  installed on the device right now** (only touchscreen + wifi hooks, no
  state file) — automatic recovery is currently inactive on the unit.
- WSL on the dev machine has NO network (mirrored-mode failure falls back to
  None); all device access goes through Windows `plink.exe`, and all web
  survey access goes through the Windows host.

## Grey areas resolved (autonomous decisions, documented judgment)

1. **How is SURVEY-03 (bug report) filed without tracker credentials?**
   Decision: capture REAL evidence from the device (journalctl kernel excerpt,
   dmesg, reproducer), author the complete upstream-ready report as a
   committed deliverable under `docs/upstream/`, and attempt automated filing
   via API only if a user-provided token exists. No GitLab token is present on
   this machine (checked env + git config), so final submission is a
   hand-off: the report ships ready-to-file and the user performs the
   submission (or supplies a token). SURVEY-03 is then honestly marked
   prepared-not-filed unless the user files during the phase.
2. **How wide is the mainline sweep (SURVEY-02)?**
   Decision: first check the running kernel and the installed kernels against
   the known fix commit `615c8ec48621` and the GLK DSI resume history; run
   resume tests on the kernels already on the device (3). Install additional
   mainline kernels ONLY if the survey evidence points to a good/bad boundary
   that one more kernel version can settle; each install is reversible via
   the boot menu and documented. No bulk bisect on hardware in this phase —
   that is Phase 45's differential, gated behind this survey by design.
3. **What is the safe on-device test protocol for the sweep?**
   Decision: suspend via `rtcwake -m mem -s N` (never lid), SSH reconnects
   after resume; the display-resume hook stays UNINSTALLED during the sweep so
   the measured behavior is the kernel's own resume (no hook variable);
   recovery between test kernels is the documented manual unbind/bind reload
   if the panel stays black. No cmdline changes, no hook installs, no BIOS
   writes during phase 44. Every on-device action is logged in the survey
   deliverable.
4. **Which sources does the SURVEY-01 web survey use?**
   Decision: gitlab.freedesktop.org/drm/intel issue tracker (GLK DSI resume
   searches), lore.kernel.org (i915/intel-gfx threads), ChromeOS bug tracker,
   and distro forums (Ubuntu/Mint) — fetched from the Windows host. Paywalled
   or bot-blocked sources are documented as unreachable rather than guessed.
   Every claim in the survey deliverable carries its URL.

## Anchors from the roadmap / requirements

- Phase ordering is load-bearing: the cheap survey runs before the costly
  Windows/GOP RE and root-cause differential (Phase 45).
- Success criteria: (1) documented survey states whether GLK DSI resume is a
  fixed regression anywhere; (2) test kernel checked against `615c8ec48621`
  and a mainline sweep yields a good/bad pair if one exists; (3) a
  correctly-formed i915 bug report (trace plus reproducer) filed or updated.
- The D330 is the 82H0 variant only (81H3/81MD out of scope); cold boot works
  because GOP leaves the display initialized — no cold-boot control arm ever.

## Note

The Phase 43 hook/kit work gives this phase the banned-lever ledger and the
safety rules; the survey deliverables must respect the ledger (no re-proposing
banned levers as fixes) and the capture protocol (≥18 s windows, inhibit hold,
two arms only) when gathering on-device evidence.
