# Phase 35: Installer & Uninstaller Symmetry - Context

**Gathered:** 2026-10-08
**Status:** Ready for planning (gray areas auto-accepted per operator standing instruction: autonomous run, recommended options, no questions)

<domain>
## Phase Boundary

Audit M1/M2/M11/N6: `--install` and `--uninstall` must be exact inverses, deployed config must actually take effect (update-grub both ways), and `--uninstall` must work in a rescue shell. Scope: `scripts/install_dkms.sh` (grub regen both paths, prereq/EUID skip for uninstall, enable all shipped units, foreign drop-in fix, uninstall additions, missing-package WARNs, new `--verify` mode), `packaging/debian/postinst`, `packaging/rpm/lenovo-d330-fix.spec`. No changes to phases 36+ scope (tray/tablet daemon wiring).

</domain>

<decisions>
## Implementation Decisions

### GRUB regeneration both ways (M1)
- Run `update-grub` (fallback `grub-mkconfig -o /boot/grub/grub.cfg`) after touching `/etc/default/grub.d/` in BOTH `do_install()` and `do_uninstall()`; honest `[WARN]` when no mkconfig tool is found, never a silent no-op. Reuse the phase-33/34 ladder detection already in the script where possible

### `--uninstall` in a rescue shell (M11)
- Skip `dkms`/`make`/`gcc` build-tool checks for `--uninstall`; skip the `EUID` (root) check for `--uninstall` too (rescue-shell use). `--install` keeps both checks

### Enable all shipped units (M2)
- Enable every deployed unit in `scripts/install_dkms.sh`, `packaging/debian/postinst` and the RPM `%post`. Compute the list from what actually ships.
- **Correction (35-RESEARCH, evidence-backed):** the real shipped set is **9 units** after phase 34's `lenovo-d330-resume.service` deletion — `lenovo-d330-camera-loopback.service` still ships and is the missing enable. Current enabled counts: install_dkms.sh 8, deb postinst 7, rpm `%post` 4. Roadmap SC2 "all 9 units" is therefore correct once camera-loopback is enabled; do NOT harden to 8 (an earlier draft of this context said 8 — that was stale). The plan must enumerate the 9 and assert the count.

### Foreign drop-in safety (M11)
- Replace `rm -rf /etc/systemd/system/earlyoom.service.d` with `rm -f /etc/systemd/system/earlyoom.service.d/d330-override.conf` + `rmdir /etc/systemd/system/earlyoom.service.d 2>/dev/null || true` — never delete a directory that may hold foreign drop-ins

### Uninstall completeness (N6)
- Add to uninstall: `rm -f /etc/d330-hardware-state.json` (written by `d330-hardware-state.service` ExecStop, never removed), `systemctl unmask systemd-networkd-wait-online.service NetworkManager-wait-online.service`, and the `dracut -f` branch that install has but uninstall lacks

### Missing-package WARNs (N6)
- `[ -d /etc/thermald ]`, `[ -d /etc/tlp.d ]`, `[ -d /usr/share/color/icc ]` silent skips become `[WARN]` lines naming the missing package/dir so a partial install is visible

### `--verify` mode (machine-checked symmetry)
- New `--verify` mode diffs deployed paths against a manifest the installer itself defines, exiting non-zero on drift; this makes symmetry machine-checkable rather than eyeballed (roadmap component)

### the agent's Discretion
- Manifest representation (bash array vs generated file), `--verify` output format, exact WARN wording, whether grub regen helper is extracted to a function

</decisions>

<code_context>
## Existing Code Insights

- `scripts/install_dkms.sh` — single script with `do_install()`/`do_uninstall()`, `check_prerequisites()` (hard-fails on missing build tools; invoked before dispatch ~:470), `EUID` check, service copy block ~:260-284, enable block ~:286-297 (7 units), grub.d deploys ~:186-194, phase-33/34 additions (`--kernel-src` step; grub ladder ~:404-444; uninstall snapshot/mkconfig ~:553-556), foreign drop-in `rm -rf /etc/systemd/system/earlyoom.service.d` ~:399, silent `[ -d ... ]` skips ~:213/:318/:322
- `packaging/debian/postinst` — six enables; `packaging/rpm/lenovo-d330-fix.spec` — three enables in `%post`, ships units via glob
- Shipment set after phase 34: `lenovo-d330-resume.service` deleted → 8 units expected enabled
- Existing gates: `scripts/test_hibernate_guards.sh` 21/0, `scripts/test_display_fix_guards.sh` 10/0, `scripts/test_storage_cellular.sh --dry-run` rc=0 (delegates all)
- Patterns: phase-32/33/34 guard posture; suite skeleton `scripts/test_microsd_guards.sh`

</code_context>

<specifics>
## Specific Ideas

No operator-specific extras beyond the ROADMAP component list.

</specifics>

<canonical_refs>
## Canonical Refs

- `.planning/ROADMAP.md` — `### Phase 35:` (goal, 2 success criteria, Audit Ref M1/M2/M11/N6, component list with file:line)
- `scripts/install_dkms.sh`
- `packaging/debian/postinst`
- `packaging/rpm/lenovo-d330-fix.spec`
- `.planning/phases/34-deliver-the-actual-pps-display-resume-fix/34-VERIFICATION.md` — unit census 9→8 note
- `.planning/phases/33-low-battery-hibernate-feasibility/33-02-PLAN.md` — grub ladder + uninstall snapshot precedent

</canonical_refs>

<deferred>
## Deferred Ideas

- Rewriting the installer as declarative manifests (only the `--verify` diff is in scope)
- Tray applet / tablet daemon session wiring (Phase 36)
- Package-level uninstall sections beyond the RPM %post enable (RPM %preun gap already noted for a later phase)
- Full doc-parity sweep of CHANGES_AUDIT (Phase 42)

</deferred>
