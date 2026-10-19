---
gsd_state_version: "1.0"
milestone: v11.0
milestone_name: Ship the Fix — Every Supported Distro + One-Script Installer
current_phase: 54
current_phase_name: One-Script Installer (d330-full-setup.sh)
status: planning
stopped_at: v10.0 closed — upstream GLK reset-order fixup validated 10/10 eyes-on (ledger row 34); v11.0 opened
last_updated: "2026-10-19T20:00:00.000Z"
last_activity: 2026-10-19
last_activity_desc: v10.0 closed (51-06 closure, 52/53 retired unexecuted, NO_CLEAN_FIX_PROOF §9 overturn); v11.0 roadmap opened
progress:
  total_phases: 3
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# STATE: Project Execution State

- **Active Milestone**: Milestone 11 (v11.0) — Ship the Fix: Every Supported Distro + One-Script Installer
- **Active Phase**: 54 — One-Script Installer (`scripts/d330-full-setup.sh`)
- **Status**: v10.0 CLOSED (2026-10-19). The milestone's "no clean fix" premise was overturned: the upstream GLK reset-order fixup (issue #13225, note 3698515), adapted in `patches/d330_dsi_glk_reset_order_fixup.patch` (sha F97F4E87), validated 10/10 lit S3 resumes + all boots on the reference D330 (ledger row 34; `docs/research/NO_CLEAN_FIX_PROOF.md` §9). Kernel `7.0.14-d330-fix` (CI run 39281203672) carries the fixup + CCS quirk; device audit confirmed every parity config installed.
- **Blockers**: None.
- **Next Immediate Action**: Plan Phase 54 (one-script installer) → Phase 55 (multi-distro release) → Phase 56 (device audit + tag v11.0)

## Project Reference

See `.planning/PROJECT.md` (updated 2026-10-12 for v8.0).

**Core value:** full hardware parity + screen-resume fix for the Lenovo D330-10IGL.
**Current focus:** Phase 54 — one-script installer automating the Kubuntu guide for every supported distro.

## Current Position

Phase: 54 — One-Script Installer
Plan: not yet planned
Status: v11.0 opened; roadmap written
Last activity: 2026-10-19 — v10.0 closure + v11.0 opening

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table. Recent decisions affecting current work:

- [v10.0 close, 2026-10-19]: the real fix is VBT parse-time reset-sequence reordering (GLK fixup from #13225), NOT any host-MMIO lever — rows 30-33 stand, the generalization to "no clean fix" was wrong (NO_CLEAN_FIX_PROOF §9).
- [v10.0 close, 2026-10-19]: Phase 52 (self-healing hotkey) and Phase 53 (logic analyzer) retired unexecuted — superseded by the fix; purchase declined verbatim in 53-BUY-GATE.md.
- [v11.0 open, 2026-10-19]: release covers Ubuntu-family (`.deb` kernel from CI + installer) and Fedora/Arch (patch-into-distro-kernel path); installer never `rm`s, backs up boot files, supports `--dry-run`, prints manual fallback per step.
- Upstream: issue #17401 filed (evidence + attachments), #13225 carries the fix + second-unit confirmation comment (user paste — Akismet blocks API comments from this account). GitLab labels impossible for community reporter role.

### Pending Todos

- User pastes the two upstream comments (bodies already provided in chat, 2026-10-19) on #13225 and #17401 when convenient.

### Blockers/Concerns

See the Blockers list above.

## Deferred Items

Items acknowledged/deferred at milestone close, most recent first:

| Category | Item | Status | Deferred At | Milestone |
|----------|------|--------|-------------|-----------|
| uat_gaps | 32/32-UAT.md | testing (scenarios=0) | 2026-10-08 | v7.0 |
| uat_gaps | 33/33-UAT.md | passed (scenarios=0) | 2026-10-08 | v7.0 |
| uat_gaps | 34/34-UAT.md | passed (scenarios=0) | 2026-10-08 | v7.0 |
| uat_gaps | 35/35-UAT.md | passed (scenarios=0) | 2026-10-08 | v7.0 |
| uat_gaps | 36/36-UAT.md | passed (scenarios=0) | 2026-10-08 | v7.0 |
| uat_gaps | 37/37-UAT.md | passed (scenarios=0) | 2026-10-08 | v7.0 |
| uat_gaps | 38/38-UAT.md | passed (scenarios=0) | 2026-10-08 | v7.0 |
| uat_gaps | 39/39-UAT.md | passed (scenarios=0) | 2026-10-08 | v7.0 |
| uat_gaps | 40/40-UAT.md | passed (scenarios=0) | 2026-10-08 | v7.0 |
| uat_gaps | 41/41-UAT.md | passed (scenarios=0) | 2026-10-08 | v7.0 |
| uat_gaps | 42/42-UAT.md | passed (scenarios=0) | 2026-10-08 | v7.0 |
| deferred_items | 39/deferred-items.md: Wireless Intel options | resolved in place | 2026-10-08 | v7.0 |

Known verification overrides at v7.0 close: 12 newly acknowledged (11 `uat_gaps` + 1 `deferred_items` resolved in place), 0 carried forward from a prior close.

## Session Continuity

Last session: 2026-10-19
Stopped at: v10.0 closed; v11.0 opened with phases 54-56
Resume file: None

## Archived Milestones

- [x] **Milestone 1: Display & Power Parity (v1.0)** - Phases 0-5 Completed & Shipped
- [x] **Milestone 2: Peripheral Parity & Tablet Usability (v2.0)** - Phases 6-9 Completed & Shipped
- [x] **Milestone 3: Vision, Ergonomics & Multimedia (v3.0)** - Phases 10-14 Completed & Shipped
- [x] **Milestone 4: Connectivity, Firmware & System Boot (v4.0)** - Phases 15-20 Completed & Shipped
- [x] **Milestone 5: CI/CD & Remastered Live ISO Distribution (v5.0)** - Phases 21-23 Completed & Shipped
- [x] **Milestone 6: System Resilience, Performance & Usability Polish (v6.0)** - Phases 24-31 Completed & Shipped
- [x] **Milestone 7: Pre-Deployment Audit Remediation (v7.0)** - Phases 32-42 Completed & Shipped (archived to `.gsd/milestones/v7.0-ROADMAP.md`)
- [x] **Milestone 10: Crack the Panel (v10.0)** - Phases 50-53 Closed 2026-10-19 (fix = upstream GLK reset-order fixup, ledger row 34; 52/53 retired unexecuted)

## Operator Next Steps

- Continue v11.0 execution: Phase 54 (installer) → 55 (release) → 56 (audit + tag)
