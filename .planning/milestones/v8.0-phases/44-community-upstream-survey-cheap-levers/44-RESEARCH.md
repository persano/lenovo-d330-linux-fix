---
phase: 44
slug: community-upstream-survey-cheap-levers
created: 2026-10-12
status: researched
---

# Phase 44 Research — Community & Upstream Survey + Cheap Levers

## Survey method

- Web survey fetched from the Windows host (WSL has no network).
- Device evidence via SSH (`192.168.2.195`, plink batch mode, host key pinned
  `SHA256:BzlraZlvJmCaAoAKc97VRhOkmX0AGMu2Xju82XJManM`).
- Primary tracker (gitlab.freedesktop.org) is behind an Anubis bot-wall for
  scripted access; absence-of-fix conclusions rest on the mail-archive mirror
  of intel-gfx/lkml, GitHub commit history, and search snippets. The tracker
  itself opens fine in a human browser — that is the SURVEY-03 filing path.

## SURVEY-01 — upstream/community state

**Answer: NO tracked-and-fixed GLK DSI resume-black regression exists
upstream (qualified — see caveats).**

| Source | Finding | URL |
|--------|---------|-----|
| drm/intel GitLab (bot-blocked for scripts; one search snippet) | Issue 6619 "Black screen waking from suspend" — a tablet where "the display is fully black, I can continue to SSH into the device": exactly our symptom class; status/fix not verifiable by script | https://gitlab.freedesktop.org/drm/i915/kernel/-/issues/6619 |
| intel-gfx via mail-archive mirror (2026-08-04, Jinman Ma, DSI command-mode patch v2) | Verbatim: "TTY switching and suspend/resume can also leave the internal panel blank... not addressed by this patch. They will be reported and investigated separately." → DSI resume-blank is a live, unowned upstream problem class as of Aug 2026 | https://www.mail-archive.com/intel-gfx@lists.freedesktop.org/msg382939.html |
| intel-gfx fixes pull (2022-12-30) | "Fix DSI resume issues on ICL+" — ICL+ only, not GLK | lore/mail-archive |
| GLK DSI cold boot series (2017, Madhav Chauhan) | Historical groundwork (~v4.13), predates our failure mode | lore |
| lkml 2026-09-07 regression report | eDP (not DSI) s2idle resume black-frame regression — adjacent, different pipeline | https://lkml.org/lkml/2026/9/7/1196 |
| ChromeOS | Tracker requires sign-in; no public GLK-DSI-suspend issue found; UNREACHABLE, not evidence of absence | — |
| Community (lucasgabmoreno/linuxmint_lenovod330) | README still lists "does not recover after a suspension" as unfixable; ships sleep-target masking + xrandr refresh scripts; 3 open issues, all 2022 | https://github.com/lucasgabmoreno/linuxmint_lenovod330 |
| Mint forums (2026-03, D330 suspend black) | Unresolved; community points to older LTS kernels; no kernel-side fix | https://forums.linuxmint.com/viewtopic.php?t=465261 |
| NEW: upstream D330 interest (Thomas Zimmermann, sysfb) | "sysfb: Fix display output on Lenovo D330 (and others)" v1 2026-08-27 → v4 2026-09-10, targeted at drm-misc-next for v7.4 — boot-time orientation only, NOT S3 resume; signals maintainer attention to D330 | mail-archive intel-gfx |

Caveat: GitLab issues UI + API bot-blocked; Q_A's "NO" is only as strong as
the mirrors searched.

## SURVEY-02 — known GLK DSI fix + mainline sweep

**Commit `615c8ec48621f5c157fef3633d6e4be81d7a370f`** — "drm/i915/dsi: Don't
set/read the DSI C clock divider on GLK" (Ville Syrjälä, 2025-07-18/19,
mainline via drm-intel-next). Touches `drivers/gpu/drm/i915/display/
vlv_dsi_pll.c` (+11 −2): adds `has_dsic_clock()` (BXT only), stops programming
the DSI-C divider on GLK, masks `BXT_DSIC_16X_MASK` during readout to kill
bogus fastset mismatches. **First carrying version: v6.18** (absent in v6.17,
ancestor of v6.18; no `Fixes:` tag, no stable backport). Nature: fastset
mismatch cleanup — NOT a resume fix.

Device verification (SSH):

- Running kernel `7.0.14-d330-fix` = Ubuntu 7.0.0-38.38 base + v7.0.14
  (journalctl /proc/version: "Ubuntu 7.0.0-38.38-generic 7.0.14", built
  2026-10-10 by CI runner).
- The device source tree `~/d330-kernel/linux-7.0.0` (Ubuntu 7.0.0-38 base)
  contains the fix's code: `has_dsic_clock` at
  `drivers/gpu/drm/i915/display/vlv_dsi_pll.c:266,293,367,526`.
- v7.0.x > v6.18 ⇒ every installed kernel postdates the fix.

**Bootable kernels on the device:** `/boot` has `vmlinuz-7.0.0-38-generic`
and `vmlinuz-7.0.14-d330-fix` only (`/lib/modules` also lists
`7.0.0-30-generic` but there is no `/boot/vmlinuz-7.0.0-30-generic` — not
bootable; excluded from the sweep).

**Consequences for SURVEY-02:**
1. The known GLK DSI fix is present in every bootable kernel and the failure
   persists → the good/bad pair cannot exist on the `615c8ec48621` axis; the
   failure is independent of that commit (as its content predicts).
2. The sweep's remaining question: does ANY installed kernel resume with a lit
   panel? Both bootable kernels are expected bad (prior sessions failed on
   7.0.0-38-era kernels); the sweep executes the two-kernel resume test with
   the Phase 43 protocol (rtcwake, ≥18 s, inhibit hold) and records
   D330-marker/dmesg evidence + user-confirmed panel state.
3. No additional kernel installs are warranted: the survey shows no candidate
   version carries a GLK DSI resume fix (nothing between v6.18 and v7.0.x on
   this axis), so a wider mainline sweep has no hypothesis to confirm —
   recorded as the sweep's honest scope limit rather than silently skipped.

## SURVEY-03 — bug report target and mechanism

- Target: **update existing drm/intel issue 6619** ("Black screen waking from
  suspend", tablet + black screen + working SSH — same symptom class) with the
  GLK-specific evidence (trace, reproducer, kernel versions tested), OR file a
  new GLK-specific issue if 6619 turns out closed/irrelevant when opened in a
  browser.
- Scripted filing is blocked (Anubis bot-wall; no credentials on this
  machine). Deliverable: upstream-ready report at `docs/upstream/
  I915_BUG_REPORT_GLK_DSI_RESUME.md` with real on-device trace evidence from
  the sweep, written so the user can paste-and-submit (or supply a token for
  API filing). SURVEY-03 is honestly "prepared" unless the user submits during
  the phase.

## Open questions for planning

1. Sweep observation channel: kernel-side evidence (dmesg D330 markers, DRM
   state) is capturable over SSH; the lit/black verdict on the physical panel
   needs the user's eyes (one structured question per kernel test) — the
   autonomous run pauses once for this.
2. Does the sweep need the 7.0.0-38-generic boot at all if 7.0.14 already
   shows the failure with full evidence? Decision deferred to planning: test
   both, but only 7.0.14 needs the full 18 s trace capture if 38 confirms the
   same binary outcome.
3. Reproducer shape for the report: plain `rtcwake -m mem -s 30` + expected
   symptom + hardware identity — no repo-internal tooling required, so the
   report stands alone upstream.

## Pitfalls (phase-specific)

- SSH dies during device suspend: every suspend command must be wrapped in
  `rtcwake` (auto-resume) and every post-resume read must tolerate a delayed
  reconnect (retry loop on the SSH side).
- The device's display-resume hook is NOT installed; between tests the panel
  may stay black — that is the measured condition, not a fault; do not install
  hooks mid-sweep (CONTEXT.md decision 3).
- Do not change cmdline/boot config on the device during the sweep.
- Never write device credentials into any repo file or tool output.
