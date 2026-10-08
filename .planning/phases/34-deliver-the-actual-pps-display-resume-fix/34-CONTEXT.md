# Phase 34: Deliver the Actual PPS / Display Resume Fix - Context

**Gathered:** 2026-10-08
**Status:** Ready for planning (gray areas auto-accepted per operator standing instruction: autonomous run, recommended options, no questions)

<domain>
## Phase Boundary

Audit C4/N3/M17: the advertised 600 ms panel power-cycle clamp and DMI orientation quirk must actually be produced by the recommended install path, or the docs must stop claiming them. Scope: `scripts/install_dkms.sh` (new optional `--kernel-src` patch step), `patches/dkms/lenovo-d330-fix/` (C module PM handler, Makefile, dkms.conf), `patches/dkms/etc/systemd/system/lenovo-d330-resume.service`, `README.md`, `patches/boot_orientation/etc/default/grub.d/50-lenovo-d330-boot.cfg`, `CHANGES_AUDIT.md` claims. No changes to phases 35+ scope (installer symmetry, tray/daemon wiring).

</domain>

<decisions>
## Implementation Decisions

### PPS Clamp Delivery (C4 core)
- Add optional `--kernel-src /usr/src/linux` step to `scripts/install_dkms.sh` that applies `patches/d330_display_resume_fix.patch` with `patch -p1 --dry-run` FIRST; on context mismatch against the running kernel: loud `[WARN]`, do not fail the install (roadmap-locked)
- The patch remains optional: default install stays DKMS-module + `enable_psr=0 enable_fbc=0` (Option 1); docs must say the clamp needs Option 2

### DKMS Module PM Handler
- Research decides between the two roadmap options: (a) move the delay from `PM_POST_SUSPEND` (post-re-energise, `elapsed < 600` never true) to `PM_SUSPEND_PREPARE`/pre-modeset where it can affect TCON sequencing, or (b) reduce the module to an honest DMI-matched banner + `dmesg` breadcrumb
- Recommended default (auto-accepted): option (a) if research shows `PM_SUSPEND_PREPARE` timing can precede panel power-on on this i915/DSI stack; otherwise option (b) — honesty over a dead code path. The choice and its evidence live in 34-RESEARCH.md

### lenovo-d330-resume.service
- Recommended (auto-accepted): **delete the unit plus its enable/disable/copy pair** — current `ExecStart` only `echo`s connector status; a real DRM connector-detect + forced modeset recovery cannot be built or validated without hardware, and shipping an echo as "resume recovery" is exactly the audit's false-advertising finding
- If research finds an existing repo tool already does connector recovery, revisit in PLAN; otherwise deletion is the honest fix

### README / CHANGES_AUDIT Truth
- `README.md:54-67` rewritten so each Option states exactly what it does: Option 1 = `i915 enable_psr=0 enable_fbc=0` + DKMS module (DMI banner, no PPS clamp); Option 2 = adds the 600 ms clamp patch via `--kernel-src`; "will now work reliably" claims become accurate, non-guaranteeing statements
- `video=efifb:nobgrt` removed from `50-lenovo-d330-boot.cfg` (not a documented efifb option)
- `CHANGES_AUDIT.md` §2.2: ADD the claimed `video=eDP-1:panel_orientation=right_side_up` / `video=DSI-1:...` params to the grub.d snippet (low risk: absent connectors are ignored by the kernel) so the shipped set matches the audit doc; if research shows the params are harmful/no-op on this stack, correct the doc instead and record why

### Build System
- `patches/dkms/lenovo-d330-fix/Makefile` + `dkms.conf`: add `BUILT_MODULE_LOCATION[0]="."` and a `MAKE_MATCH[0]` guard (roadmap-locked, mechanical)

### the agent's Discretion
- Exact `[WARN]`/`[OK]` wording, README prose layout, whether the module banner prints one line or two
- Test-suite naming for the new static cases (`scripts/test_resume_loop.sh` exists per SC2 — extend or wrap as research dictates)

</decisions>

<code_context>
## Existing Code Insights

- `patches/dkms/lenovo-d330-fix/lenovo_d330_fix.c:97-118` — `PM_POST_SUSPEND` handler: sleeps after panel re-energised, gated on `elapsed < 600 ms` (never true in practice); DMI match table present
- `patches/dkms/etc/systemd/system/lenovo-d330-resume.service:9` — `ExecStart` echoes connector status only
- `scripts/install_dkms.sh` — phased install script, `[ -f ] && cp` guarded deploys, `systemctl enable` block ~:286-297, grub.d deploys ~:186-194, phase-33 added resume-activation ladder :404-444 (do not disturb)
- `patches/boot_orientation/etc/default/grub.d/50-lenovo-d330-boot.cfg:7` — contains `video=efifb:nobgrt`
- `README.md:54-67` — Option 1 "Suspend and resume will now work reliably" claim
- `scripts/test_resume_loop.sh` — existing resume-loop harness (SC2: 5 cycles); `scripts/test_hibernate_guards.sh` (21 cases) and `scripts/test_storage_cellular.sh --dry-run` are the current green gates (do not break)
- Patterns: phase-32/33 guard posture (fail closed, honest messages, `[DRY-RUN]` where execution impossible), suite skeleton from `scripts/test_microsd_guards.sh`

</code_context>

<specifics>
## Specific Ideas

No operator-specific extras beyond the ROADMAP component list.

</specifics>

<canonical_refs>
## Canonical Refs

- `.planning/ROADMAP.md` — `### Phase 34:` (goal, 3 success criteria, Audit Ref C4/N3/M17, component list)
- `scripts/install_dkms.sh`
- `patches/d330_display_resume_fix.patch`
- `patches/dkms/lenovo-d330-fix/lenovo_d330_fix.c`
- `patches/dkms/lenovo-d330-fix/Makefile`
- `patches/dkms/lenovo-d330-fix/dkms.conf`
- `patches/dkms/etc/systemd/system/lenovo-d330-resume.service`
- `patches/boot_orientation/etc/default/grub.d/50-lenovo-d330-boot.cfg`
- `README.md`
- `CHANGES_AUDIT.md`
- `scripts/test_resume_loop.sh`
- `.planning/phases/33-low-battery-hibernate-feasibility/33-CONTEXT.md` — honesty posture carried forward

</canonical_refs>

<deferred>
## Deferred Ideas

- Real DRM connector-detect + forced modeset recovery in the resume service (needs hardware validation; deletion chosen instead)
- Upstreaming the clamp as a proper quirk, i915 driver changes
- Tray applet / tablet daemon session wiring (Phase 36), installer symmetry (Phase 35)
- Changing Option 1's kernel params (`enable_psr=0 enable_fbc=0` stays as documented)

</deferred>
