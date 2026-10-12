# Phase 44: Community & Upstream Survey + Cheap Levers - Pattern Map

## Metadata
- Files classified: 3 new, 0 modified
- Generated: 2026-10-12
- Codebase: lenovo-d330-linux-screen-fix @ milestone v8.0

## File Classification

| File | Status | Task | Trust tier |
|------|--------|------|-----------|
| `docs/research/UPSTREAM_SURVEY.md` (new, doc / survey) | new | 44-01-T2 | evidence doc |
| `docs/upstream/I915_BUG_REPORT_GLK_DSI_RESUME.md` (new, doc / upstream report) | new | 44-01-T3 | external-bound |
| `docs/research/KERNEL_SWEEP_EVIDENCE.md` (new, doc / on-device evidence) | new | 44-01-T1 | evidence doc |

## Pattern Assignments

### `docs/research/UPSTREAM_SURVEY.md` (new, doc / survey)

**Analog:** `docs/research/COMMUNITY_FINDINGS.md` — the house source-survey
doc shape: title, method note, per-source findings table, disproof/dead-end
sections with URLs, conclusion block. Survey rows cite URL + status; sources
that are bot-blocked are recorded UNREACHABLE, never guessed (Pitfall 2:
fabricated survey claims are worse than an honest gap).

**Notes:** the ledger gate scans docs/research/*.md; the survey will quote the
device cmdline (`i915.enable_psr=0 i915.enable_fbc=0`) and community
workarounds (`systemctl mask`) — these are DESCRIBED dead ends/mitigations,
not fix proposals; carry `planner-discipline-allow` markers with the exact
strings quoted (Phase 43 mechanism), one per exact string.

### `docs/upstream/I915_BUG_REPORT_GLK_DSI_RESUME.md` (new, doc / upstream report)

**No analog found** — first upstream-bound artifact in the repo. Shape follows
the drm/intel issue template (environment, description, steps to reproduce,
kernel trace, regression status), self-contained (no repo-internal tooling
referenced), with a repo-side header note that the filing is pending user
submission (no credentials on the dev machine — CONTEXT.md grey area 1).
Not in the ledger gate's scan scope (docs/upstream/ is outside the scanned
roots); do not move it into docs/research to dodge a needed marker.

### `docs/research/KERNEL_SWEEP_EVIDENCE.md` (new, doc / on-device evidence)

**Analog:** `docs/research/DSI_RESUME_TRACE_ANALYSIS.md` — the on-device
evidence doc: per-session command + output excerpts with device identity
(uname, DMI), timestamps, and the observation channel recorded (SSH capture +
user panel verdict). Every sweep command is logged verbatim so the test is
reproducible. Follows the Phase 43 capture protocol (rtcwake suspend, ≥18 s
window, inhibit hold, no cold-boot arm).

## Shared Patterns

### 1. Evidence docs carry device identity + verbatim commands
Every on-device excerpt is preceded by `uname -r`/date and the exact command
run (DSI doc precedent, cap.sh/reg_*.txt pointers).

### 2. UNREACHABLE is a finding
Bot-blocked or sign-in-walled sources are recorded as unreachable with what
was attempted (survey agent precedent this phase); absence claims name the
mirrors actually searched.

### 3. planner-discipline-allow for quoted levers
Docs quoting banned-lever strings (cmdline quotes, community workarounds)
carry per-exact-string markers — the Phase 43 gate mechanism (ledger gate
scans docs/research).

### 4. Self-contained upstream reports
The bug report references nothing repo-internal; reproducer uses mainline
tools only (rtcwake, journalctl, dmesg).
