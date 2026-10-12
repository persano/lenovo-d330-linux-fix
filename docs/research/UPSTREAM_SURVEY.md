# Upstream & Community Survey — GLK DSI Resume Black Screen (Phase 44)

## 1. Method

- Fetched from the Windows host (WSL on this machine has no network).
- Primary tracker `gitlab.freedesktop.org` is behind an Anubis bot-wall for
  scripted access: issues UI and API return the challenge page to scripts.
  Absence-of-fix conclusions therefore rest on the mail-archive mirror of
  intel-gfx/lkml, GitHub commit history, and search snippets. The tracker
  opens fine in a human browser — that is the issue-6619 filing path (Task 3).
- Device evidence via SSH (plink batch mode, host key pinned). Sweep evidence:
  `docs/research/KERNEL_SWEEP_EVIDENCE.md` (same session).

## 2. Per-source findings

| Source | Finding | URL | Status |
|--------|---------|-----|--------|
| drm/intel GitLab | Issue 6619 "Black screen waking from suspend" — a tablet where "the display is fully black, I can continue to SSH into the device": exactly our symptom class. Status/fix not verifiable by script (bot-wall) | https://gitlab.freedesktop.org/drm/i915/kernel/-/issues/6619 | REACHABLE IN BROWSER ONLY |
| intel-gfx via mail-archive (2026-08-04, Jinman Ma, DSI command-mode patch v2) | Verbatim: "TTY switching and suspend/resume can also leave the internal panel blank... not addressed by this patch. They will be reported and investigated separately." → DSI resume-blank is a live, unowned upstream problem class as of Aug 2026 | https://www.mail-archive.com/intel-gfx@lists.freedesktop.org/msg382939.html | REACHABLE |
| intel-gfx fixes pull (2022-12-30) | "Fix DSI resume issues on ICL+" — ICL+ only, not GLK | mail-archive mirror | REACHABLE |
| GLK DSI cold-boot series (2017, Madhav Chauhan) | Historical groundwork (~v4.13), predates the failure mode | mail-archive mirror | REACHABLE |
| lkml regression report (2026-09-07) | eDP (not DSI) s2idle resume black-frame regression — adjacent, different pipeline | https://lkml.org/lkml/2026/9/7/1196 | REACHABLE |
| ChromeOS issue tracker | Requires sign-in; no public GLK-DSI-suspend issue found | — | UNREACHABLE (not evidence of absence) |
| Community repo `lucasgabmoreno/linuxmint_lenovod330` | README still lists "does not recover after a suspension" as unfixable; ships sleep-target masking + xrandr refresh scripts; 3 open issues, all 2022 | https://github.com/lucasgabmoreno/linuxmint_lenovod330 | REACHABLE |
| Mint forums (2026-03, D330 suspend black) | Unresolved; community points to older LTS kernels; no kernel-side fix | https://forums.linuxmint.com/viewtopic.php?t=465261 | REACHABLE |
| Thomas Zimmermann sysfb series (2026-08-27 → v4 2026-09-10) | "sysfb: Fix display output on Lenovo D330 (and others)" — targeted at drm-misc-next for v7.4; boot-time orientation/output only, NOT S3 resume; signals maintainer attention to the D330 | mail-archive intel-gfx | REACHABLE |

## 3. The known GLK DSI commit: `615c8ec48621f5c157fef3633d6e4be81d7a370f`

- Title: "drm/i915/dsi: Don't set/read the DSI C clock divider on GLK"
  (Ville Syrjälä, 2025-07-18/19, via drm-intel-next).
- Content: `drivers/gpu/drm/i915/display/vlv_dsi_pll.c` (+11 −2): adds
  `has_dsic_clock()` (BXT only), stops programming the DSI-C divider on GLK,
  masks `BXT_DSIC_16X_MASK` during readout to kill bogus fastset mismatches.
- First carrying version: **v6.18** (absent in v6.17; no `Fixes:` tag; no
  stable backport). Nature: fastset mismatch cleanup — **not a resume fix**.

### Device verification

- Running kernel `7.0.14-d330-fix` = Ubuntu 7.0.0-38.38 base + v7.0.14
  (built 2026-10-10 by CI runner); other bootable kernel `7.0.0-38-generic`
  (same Ubuntu base). v7.0.x > v6.18 ⇒ every installed kernel postdates the fix.
- The device source tree `~/d330-kernel/linux-7.0.0` contains the fix's code:
  `has_dsic_clock` at `drivers/gpu/drm/i915/display/vlv_dsi_pll.c:266,293,367,526`.
- Device cmdline carries the mitigation params `i915.enable_psr=0`
  `i915.enable_fbc=0` (shipped mitigations for Hypothesis 3, still failing).

### Consequence

The known GLK DSI fix is present in every bootable kernel and the failure
persists → the good/bad pair cannot exist on the `615c8ec48621` axis; the
failure is independent of that commit (as its content predicts).

## 4. Two-kernel sweep result (Task 1)

- Both bootable kernels were S3-cycled on-device (rtcwake, ~30 s, detached
  capture). Kernel logs on BOTH arms are clean with the identical signature:
  normal ACPI S3 wake, `lenovo_d330_fix` resume banner, no DSI/i915 errors —
  matching the ledger's established signature (the failure is invisible in
  kernel logs).
- Panel verdicts were UNRELIABLE (user not continuously watching; immediate
  answers contradicted later and retracted): a kernel-axis good/bad pair is
  NOT established. See `docs/research/KERNEL_SWEEP_EVIDENCE.md` for the full
  record, including the arm A pre-suspend `dpms=Off` confound.

## 5. Conclusion (SURVEY-01 / SURVEY-02)

- **SURVEY-01: NO tracked-and-fixed GLK DSI resume-black regression exists
  upstream** (qualified: tracker bot-blocked; absence established via the
  mail-archive mirror + GitHub history + search snippets). DSI resume-blank
  is confirmed as a live, unowned problem class (Jinman Ma, Aug 2026). The
  two bootable kernels were S3-cycled on-device; kernel logs are clean on
  both, and the panel verdicts were unreliable, so the sweep could not
  isolate a kernel-axis differentiator either way.
- **SURVEY-02: no additional mainline sweep is warranted** — no candidate
  version carries a GLK DSI resume fix on this axis (the one known GLK DSI
  commit is present in both kernels and the failure persists), so a wider
  kernel-version sweep has no hypothesis to confirm. Recorded as the sweep's
  honest scope limit.
- Community prior art ships only destructive workarounds
  (`systemctl mask sleep.target suspend.target hibernate.target
  hybrid-sleep.target`, `xrandr` refresh scripts) — none fixed, all
  documented as such in the ledger.
- Remaining cheap lever: the upstream report (SURVEY-03, Task 3) targeting
  issue 6619, prepared as a paste-and-submit document.

<!-- planner-discipline-allow: i915.enable_psr=0 -->
<!-- planner-discipline-allow: i915.enable_fbc=0 -->
<!-- planner-discipline-allow: systemctl mask -->
<!-- planner-discipline-allow: xrandr -->
<!-- planner-discipline-allow: sleep.target -->
