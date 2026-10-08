# Phase 35: Installer & Uninstaller Symmetry - Research

**Researched:** 2026-10-08
**Domain:** Bash installer/uninstaller inverse symmetry (systemd, GRUB regen, package `%post`)
**Confidence:** HIGH (all claims read from source this session; no external registry claims)
**Audit Ref:** M1, M2, M11, N6

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **GRUB regeneration both ways (M1):** Run `update-grub` (fallback `grub-mkconfig -o /boot/grub/grub.cfg`) after touching `/etc/default/grub.d/` in BOTH `do_install()` and `do_uninstall()`; honest `[WARN]` when no mkconfig tool is found, never a silent no-op. Reuse the phase-33/34 ladder detection already in the script where possible.
- **`--uninstall` in a rescue shell (M11):** Skip `dkms`/`make`/`gcc` build-tool checks for `--uninstall`; skip the `EUID` (root) check for `--uninstall` too (rescue-shell use). `--install` keeps both checks.
- **Enable all shipped units (M2):** Enable every deployed unit in `scripts/install_dkms.sh`, `packaging/debian/postinst` and the RPM `%post`. Compute the list from what actually ships.
- **Roadmap SC2 says "all 9 units"; phase 34 DELETED `lenovo-d330-resume.service`, so the shipped census is 8.** Record this premise drift explicitly and target the real shipped count (8), not a stale 9. The plan must enumerate the units and assert the count.
- **Foreign drop-in safety (M11):** Replace `rm -rf /etc/systemd/system/earlyoom.service.d` with `rm -f /etc/systemd/system/earlyoom.service.d/d330-override.conf` + `rmdir /etc/systemd/system/earlyoom.service.d 2>/dev/null || true` — never delete a directory that may hold foreign drop-ins.
- **Uninstall completeness (N6):** Add to uninstall: `rm -f /etc/d330-hardware-state.json`, `systemctl unmask systemd-networkd-wait-online.service NetworkManager-wait-online.service`, and the `dracut -f` branch that install has but uninstall lacks.
- **Missing-package WARNs (N6):** `[ -d /etc/thermald ]`, `[ -d /etc/tlp.d ]`, `[ -d /usr/share/color/icc ]` silent skips become `[WARN]` lines naming the missing package/dir so a partial install is visible.
- **`--verify` mode (machine-checked symmetry):** New `--verify` mode diffs deployed paths against a manifest the installer itself defines, exiting non-zero on drift.

### the agent's Discretion
- Manifest representation (bash array vs generated file), `--verify` output format, exact WARN wording, whether grub regen helper is extracted to a function.

### Deferred Ideas (OUT OF SCOPE)
- Rewriting the installer as declarative manifests (only the `--verify` diff is in scope)
- Tray applet / tablet daemon session wiring (Phase 36)
- Package-level uninstall sections beyond the RPM `%post` enable (RPM `%preun` gap already noted for a later phase)
- Full doc-parity sweep of CHANGES_AUDIT (Phase 42)

> **PREMISE CORRECTION (see Finding 2):** CONTEXT's locked line "the shipped census is 8" is **wrong**. The actual shipped unit set is **9** (verified by glob of `patches/**/etc/systemd/system/*.service`). Phase 34 deleted the resume unit, dropping shipped from 10→9 and enabled from 9→8. The locked target "enable all shipped" therefore means **9 enabled after Phase 35**, which happens to match roadmap SC2's "all 9". The plan must enumerate the 9 units and assert the count rather than trusting either the "8" premise or the stale "7/9" figure.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| M1 | Deployed config must actually take effect (update-grub both ways) | Findings 1, 3 — Action Inventory rows I12, I26; GRUB ladder reuse surface |
| M2 | Enable all shipped units (install + deb postinst + rpm %post) | Finding 2, 9 — unit census table, per-site enable sets |
| M11 | `--uninstall` must work in a rescue shell; no foreign drop-in deletion | Findings 4, 5, 6 — gate analysis, `rm -rf` replacement |
| N6 | Uninstall completeness; missing-package WARNs | Findings 6, 7, 9 — gaps and silent skips |
</phase_requirements>

## Executive Summary

`scripts/install_dkms.sh` is a single 764-line script with `do_install()` (`:147-585`) and `do_uninstall()` (`:587-732`). The uninstall path is a largely faithful hand-maintained inverse of the install path: of ~34 discrete install actions, the overwhelming majority have an exact `rm -f`/`systemctl disable` counterpart. The symmetry is real but **not exact**, and the four audit items are all genuine defects verified by reading the source:

- **M1 (GRUB regen):** `do_install()` deploys `/etc/default/grub.d/50/51/52` (`:269-276`) and `do_uninstall()` removes them (`:628-630`), but **neither direction regenerates `grub.cfg` for these snippets**. GRUB regen exists only inside the phase-33/34 resume-snippet ladder (`:486-517` install, `:713-726` uninstall), which is gated on `d330-swapfile` readiness and on snippet presence respectively. So `50/51/52` are written/removed but never take effect until an unrelated `update-grub` happens.
- **M2 (enable set):** Install deploys **9** units but enables only **8** — `lenovo-d330-camera-loopback.service` ships and is copied (`:354-355`) but is never enabled. Uninstall *does* disable it (`:667`). deb `postinst` enables 7, RPM `%post` enables 4. The stated pre-conditions ("7/9, 6, 3") are stale by +1 each because the `d330-auto-hibernate` enable lines were added in Phase 33 after those numbers were recorded.
- **M11 (rescue shell + foreign drop-in):** `check_prerequisites()` runs before dispatch at `:759` and hard-fails on missing `dkms`/`make`/`gcc` (`:54-72`) plus an `EUID` gate (`:49-52`), so `--uninstall` cannot run in a minimal rescue shell. `do_uninstall` line `:643` does `rm -rf /etc/systemd/system/earlyoom.service.d`, which deletes foreign drop-ins.
- **N6 (completeness):** `/etc/d330-hardware-state.json` (written by `d330-ctl save`, invoked as `ExecStop` of the hardware-state unit) is never removed; uninstall has no `dracut` branch (`:727-729` only); no `unmask` of the wait-online services exists anywhere; and three install-time `[ -d ]` guards (`:295` thermald, `:553` tlp.d, `:557` color/icc) silently skip.

**Primary recommendation:** Add a `run_grub_regen()` helper around the existing ladder, call it after any `grub.d` write/remove; compute the shipped-unit list from `patches/**/etc/systemd/system/*.service` and enable all of it in all three sites; make `check_prerequisites` conditional on `ACTION`; replace the two broad `rm -rf` on system dirs where the directory may hold foreign content; and implement `--verify` as a manifest function with a `--root DIR` prefix for off-hardware fixture testing.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Unit deploy + enable | System (package/installer) | — | `install_dkms.sh`, deb postinst, rpm `%post` own systemd state |
| GRUB regeneration | System bootloader | — | Must run on the machine whose `/boot/grub/grub.cfg` is being changed |
| Swapfile + fstab resume | System storage/boot | — | Installer renders config; kernel reads at boot |
| Manifest inventory / `--verify` | Installer (static) | CI test | Manifest is a static list; verification can run against a fixture root |
| Package enable parity | Packaging metadata | Installer | deb/rpm must mirror the installer's enable set |

## Action Inventory

Every filesystem/service action in `do_install()` paired with its `do_uninstall()` counterpart. **This is the core deliverable.**

| # | `do_install()` action (file:line) | `do_uninstall()` counterpart (file:line) | Status |
|---|-----------------------------------|------------------------------------------|--------|
| I1 | `rm -rf`/`mkdir`/`cp -r` DKMS src → `/usr/src/lenovo-d330-fix-1.0.0` (`:153-155`) | `rm -rf "${DEST_SRC}"` (`:597`) | REVERSED |
| I2 | `dkms add/build/install` (`:167-169`) | `dkms remove --all` (`:594-596`) | REVERSED |
| I3 | `modprobe -v` load module (`:578`) | `modprobe -r` unload (`:591`) | REVERSED |
| I4 | `cp` 8 `modprobe.d` confs: i915, audio, power, camera, audio-antipop, display-pwm, cellular, wireless (`:183-197`) | `rm -f` 8 matching confs (`:600-607`) | REVERSED |
| I5 | `mkdir -p /etc/udev/hwdb.d /etc/udev/rules.d` (`:203`) | — (dirs left) | ASYMMETRIC (benign, pre-existing dirs) |
| I6 | `cp` 3 `hwdb.d` files (`:204-208`) | `rm -f` 3 (`:608-610`) | REVERSED |
| I7 | `cp` 10 `rules.d` files (`:209-228`) | `rm -f` 10 (`:611-620`) | REVERSED |
| I8 | `cp` + `chmod +x` ModemManager fcc-unlock `8086:7360` (`:231-234`) | `rm -f` (`:621`) | REVERSED |
| I9 | `systemd-hwdb update` + `udevadm trigger` (`:236-238`) | same (`:705-707`) | REVERSED |
| I10 | `cp` 2 X11 xorg.conf.d files (`:246-250`, guard `[ -d /etc/X11/xorg.conf.d ]`) | `rm -f` 2 (`:622-623`) | REVERSED |
| I11 | `mkdir -p /usr/lib/systemd/system-sleep` + `cp`+`chmod` 2 sleep hooks (`:252-258`) | `rm -f` 2 (`:624-625`) | REVERSED (mkdir left, benign) |
| I12 | `mkdir -p /etc/sysctl.d /etc/systemd` + `cp` 2 confs + `sysctl --system` (`:261-266`) | `rm -f` 2 (`:626-627`) | ASYMMETRIC — `sysctl --system` not re-run on uninstall |
| I13 | `cp` grub.d `50/51/52` (`:269-276`, guard `[ -d /etc/default/grub.d ]`) | `rm -f` `50/51/52` (`:628-630`) | **ASYMMETRIC — no `update-grub` in EITHER direction (M1)** |
| I14 | `cp`+`chmod` initramfs-tools hook `lenovo-d330-plymouth` (`:277-281`) | `rm -f` (`:640`) | REVERSED |
| I15 | `mkdir -p /etc/environment.d` + `cp` vaapi conf (`:284-286`) | `rm -f` (`:641`) | REVERSED |
| I16 | `cp` `/etc/default/earlyoom` (`:287-288`) | `rm -f` (`:642`) | REVERSED |
| I17 | `mkdir -p` + `cp -r` `/etc/systemd/system/earlyoom.service.d/*` (`:289-292`) | `rm -rf /etc/systemd/system/earlyoom.service.d` (`:643`) | **ASYMMETRIC — over-deletes foreign drop-ins (M11)** |
| I18 | `cp` thermald `thermal-conf.xml` (`:295-297`, guard `[ -d /etc/thermald ]`) | `rm -f` (`:644`) | REVERSED (install silently skips if dir absent) |
| I19 | `mkdir -p /usr/local/bin` + `cp`+`chmod` 13 tools (`:303-342`) | `rm -f` 13 (`:646-658`) | REVERSED |
| I20 | `cp` autostart `d330-tray.desktop` (`:345-347`, guard `[ -d /etc/xdg/autostart ]`) | `rm -f` (`:645`) | REVERSED |
| I21 | `cp` 9 systemd units (`:350-367`) | `rm -f` 9 units (`:693-701`) | REVERSED |
| I22 | `systemctl daemon-reload` (`:369`) | `systemctl daemon-reload` (`:702`) | REVERSED |
| I23 | `systemctl enable` **8** units (`:373-380`) | `systemctl disable --now` **9** units (`:665-673`) | **ASYMMETRIC — camera-loopback enabled by uninstall path only (M2)** |
| I24 | `systemctl start d330-swapfile.service` (`:396`) | `disable --now` (`:673`) + `swapoff` (`:674`) | REVERSED |
| I25 | append `/var/swapfile none swap sw 0 0` to `/etc/fstab` (`:406-418`) | exact-match remove (`:678-692`) | REVERSED (swapfile itself kept by design) |
| I26 | render `/etc/default/grub.d/53-lenovo-d330-resume.cfg` (`:463-478`) | `rm -f` (`:639`) | REVERSED |
| I27 | resume mkconfig ladder `update-grub`→`grub2-mkconfig`→`grub-mkconfig` (`:486-517`) | conditional mkconfig when 53 was present (`:713-726`) | REVERSED (resume path only — see I13) |
| I28 | resume `update-initramfs -u` (`:508-510`) | `update-initramfs -u` (`:727-729`) | REVERSED |
| I29 | `cp -r` ALSA UCM2 → `/usr/share/alsa/ucm2/sof-essx8336` (`:535-540`, guard `[ -d $UCM_DIR ]`) | `rm -rf /usr/share/alsa/ucm2/sof-essx8336` (`:659`) | ASYMMETRIC (broad `rm -rf`; dir is installer-created) |
| I30 | `cp` 2 pipewire filters (`:541-548`, guard `[ -d /etc/pipewire ]`) | `rm -f` 2 (`:660-661`) | REVERSED |
| I31 | `cp` TLP conf (`:553-556`, guard `[ -d /etc/tlp.d ]`) | `rm -f` (`:662`) | REVERSED (install silently skips) |
| I32 | `cp` ICC profile (`:557-560`, guard `[ -d /usr/share/color/icc ]`) | `rm -f` (`:663`) | REVERSED (install silently skips) |
| I33 | initramfs refresh: `update-initramfs -u -k all` **elif** `dracut -f` (`:566-572`) | `update-initramfs -u` only (`:727-729`) | **ASYMMETRIC — no `dracut` branch (N6)** |
| I34 | (runtime) `/etc/d330-hardware-state.json` written by `d330-ctl save` (`tools/d330-ctl:116-118`, unit `ExecStop`) | — none | **NOT REVERSED (N6)** |
| I35 | (nothing) no mask/unmask anywhere | (to add) `unmask systemd-networkd-wait-online NetworkManager-wait-online` | **NOT REVERSED (net-new, N6)** |
| I36 | `check_prerequisites` + `EUID` gate before dispatch (`:47-74` called `:759`) | blocks `--uninstall` in rescue shell | **NOT REVERSED (M11)** |

**Asymmetry tally:** 10 non-clean-inverse rows. Of these, **6 are genuinely NOT REVERSED** (missing counterpart or missing counterpart-side step): I13 (grub regen for 50/51/52 — M1), I23 (camera-loopback never enabled — M2), I33 (dracut branch — N6), I34 (hardware-state.json — N6), I35 (unmask — N6), I36 (rescue-shell gate — M11). The remaining 4 (I5, I12, I17, I29) have both sides present but are not exact inverses (benign dir gaps, missing `sysctl --system`, over-broad `rm -rf`).

## Findings

### Finding 1 — Action inventory / dispatch (deliverable #1)
See the Action Inventory table above. Dispatch is a plain `case` after option parsing (`:738-753`) and a single `check_prerequisites` call (`:759`) followed by `case "$ACTION"` (`:761-764`). There is no `--verify` case, no `--uninstall`-specific prerequisite relaxation. `set -euo pipefail` at `:9` means any unguarded failing command aborts; the script mitigates with `|| true` throughout both paths, which is why asymmetries are silent rather than crashing.

### Finding 2 — Unit census (deliverable #2)
**Shipped units (verified by glob `patches/**/etc/systemd/system/*.service` = 9 files):**

| # | Unit | Patch dir | install enable | deb postinst | rpm %post | uninstall disable |
|---|------|-----------|:--:|:--:|:--:|:--:|
| 1 | `d330-tablet-daemon.service` | dock | ✅ `:373` | ✅ `:13` | ✅ `:46` | ✅ `:665` |
| 2 | `lenovo-d330-power.service` | power | ✅ `:374` | ✅ `:14` | ✅ `:47` | ✅ `:666` |
| 3 | `lenovo-d330-camera-loopback.service` | camera | ❌ | ❌ | ❌ | ✅ `:667` |
| 4 | `d330-hardware-state.service` | hardware_controls | ✅ `:375` | ✅ `:15` | ❌ | ✅ `:668` |
| 5 | `lenovo-d330-backlight-pwm.service` | display_ergonomics | ✅ `:376` | ✅ `:16` | ❌ | ✅ `:669` |
| 6 | `d330-sensor-filter.service` | sensors | ✅ `:377` | ✅ `:17` | ❌ | ✅ `:670` |
| 7 | `d330-auto-hibernate.service` | power_hibernate | ✅ `:379` | ✅ `:18` | ✅ `:48` | ✅ `:671` |
| 8 | `d330-thermal.service` | thermal | ✅ `:378` | ❌ | ❌ | ✅ `:672` |
| 9 | `d330-swapfile.service` | power_hibernate | ✅ `:380` | ✅ `:19` | ✅ `:49` | ✅ `:673` |

**Counts:** shipped **9**; install enables **8** (`:373-380`); deb postinst enables **7** (`:13-19`); rpm `%post` enables **4** (`:46-49`); uninstall disables **9** (`:665-673`).

**SC2 verdict:** roadmap SC2 "all 9 units returns enabled" is **unattainable today** because `camera-loopback` is never enabled (8/9). It becomes correct after Phase 35 enables all shipped units. CONTEXT's claim that "the shipped census is 8" is **false** — 9 units ship. The stale "7/9, 6, 3" figures were recorded before Phase 33 added the `d330-auto-hibernate` enable lines to all three sites (deb +1 → 7, rpm +1 → 4, install +1 → 8); see `33-02-PLAN.md:225` which added exactly those lines.

### Finding 3 — GRUB regen (deliverable #3)
- **Install:** `grub.d` snippets `50/51/52` are copied at `:269-276` inside `if [ -d "/etc/default/grub.d" ]`. **No mkconfig follows.** The only install-side regen is the resume ladder at `:486-517`: tool detection `update-grub`→`grub2-mkconfig`→`grub-mkconfig` (`:488-494`), run at `:499-503`, verified by grepping the rendered tokens out of `grub.cfg` (`:504-506`), with `update-initramfs -u` on success (`:508-510`).
- **Uninstall:** `rm -f` of `50/51/52` at `:628-630` and `53` at `:639`. A `RESUME_SNIPPET_WAS_PRESENT` flag is captured before removing `53` (`:635-638`) and the same detection ladder is re-run conditionally at `:713-726`. Generic snippets `50/51/52` are **not** tracked, so their removal never triggers regen.
- **Reuse surface:** the ladder exists twice already (`:488-494` and `:714-722`); CONTEXT permits extracting it to a helper (discretion). The honest `[WARN]` on no-tool already exists at `:724`, but only in the uninstall-resume branch; the install ladder warns at `:516` only when prerequisites are missing.
- **Exact insertion points:** install — inside/after the `[ -d /etc/default/grub.d ]` block at `:276` (or immediately after, before `:277`); uninstall — after the `50/51/52` removals at `:630` (add a was-present flag mirroring `:635-638`, or regen unconditionally when the dir existed).

### Finding 4 — `check_prerequisites` / `EUID` (deliverable #4)
- `EUID` guard: `check_prerequisites` `:49-52` — `if [ "$EUID" -ne 0 ] && [ "$DRY_RUN" = false ]; then ... exit 1`.
- Build-tool guard: `:54-72` — missing `dkms`/`make`/`gcc` collects into `missing[]` and `exit 1` (`:68-72`); kernel-headers only `[WARN]` (`:63-66`).
- Call site: `:759`, **before** the `case "$ACTION"` dispatch at `:761-764`. So `--uninstall` runs the full gate.
- **Why this blocks rescue:** a rescue/minimal shell is typically root but lacks `dkms`/`make`/`gcc`, so `exit 1` at `:71` aborts before any removal. The `EUID` gate is the ironic inverse (rescue is usually root) but CONTEXT locks skipping it for uninstall anyway. Recommended shape: pass `ACTION` into `check_prerequisites` (or guard the two blocks with `[ "$ACTION" = "install" ]`), keeping full checks for `--install`/`--dry-run`.

### Finding 5 — Foreign drop-in / broad `rm -rf` (deliverable #5)
`rg "rm -rf /etc/systemd|rm -rf /etc/|rm -rf /usr" scripts/` returns exactly two system-dir deletions:
- `scripts/install_dkms.sh:643` — `rm -rf /etc/systemd/system/earlyoom.service.d` (**M11 target**; the directory may hold foreign drop-ins). The installer-authored drop-in is exactly `patches/oom_protection/etc/systemd/system/earlyoom.service.d/d330-override.conf` (verified directory listing), so the CONTEXT replacement filename is exact.
- `scripts/install_dkms.sh:659` — `rm -rf /usr/share/alsa/ucm2/sof-essx8336` (installer-created subdir via `mkdir -p` at `:537`; lower risk but still a broad delete that would remove any foreign file placed in that package-owned dir).
Plus two self-owned staging deletes: `:153` and `:597` (`rm -rf "${DEST_SRC}"`). `rm -rf /etc/systemd/system/earlyoom.service.d` is the only sanctioned replacement target per CONTEXT.

### Finding 6 — Uninstall gaps (deliverable #6)
- **`/etc/d330-hardware-state.json`:** producer/consumer is `tools/d330-ctl` — `STATE_FILE = "/etc/d330-hardware-state.json"` (`:16`), written by `cmd_save` via `json.dump` (`:116-118`), read by `cmd_restore` (`:127-134`). The producing unit is `patches/hardware_controls/etc/systemd/system/d330-hardware-state.service` (`ExecStart=/usr/local/bin/d330-ctl restore` `:9`, `ExecStop=/usr/local/bin/d330-ctl save` `:10`). `do_uninstall` removes the unit (`:696`) and disables it (`:668`) but **never removes the JSON**. Add `rm -f /etc/d330-hardware-state.json`.
- **Mask/unmask:** `rg "mask" scripts/install_dkms.sh packaging/` returns **zero hits** — there is no mask or unmask anywhere. The CONTEXT addition of `systemctl unmask systemd-networkd-wait-online.service NetworkManager-wait-online.service` is net-new defensive cleanup, not a reversal of an install action.
- **dracut vs update-initramfs:** install `:566-572` tries `update-initramfs -u -k all` first, **elif** `dracut -f`. Uninstall `:727-729` only calls `update-initramfs -u` — no `dracut` branch. On a dracut-only distro, uninstall never refreshes initramfs after removing the hook at `:640` and the resume snippet at `:639`.

### Finding 7 — Silent skips (deliverable #7)
Install-time `[ -d ]` guards that silently skip and the package each implies:

| Line | Guard | Package / dir implied | Priority |
|------|-------|----------------------|----------|
| `:295` | `[ -d "/etc/thermald" ]` | `thermald` | **CONTEXT-named (N6)** |
| `:553` | `[ -d "/etc/tlp.d" ]` | `tlp` | **CONTEXT-named (N6)** |
| `:557` | `[ -d "/usr/share/color/icc" ]` | `colord` / ICC profile dir | **CONTEXT-named (N6)** |
| `:231` | `[ -d "/etc/ModemManager/fcc-unlock.d" ]` | `modemmanager` | secondary |
| `:246` | `[ -d "/etc/X11/xorg.conf.d" ]` | X server | secondary |
| `:269` | `[ -d "/etc/default/grub.d" ]` | `grub-common` | secondary |
| `:277` | `[ -d "/usr/share/initramfs-tools/hooks" ]` | `initramfs-tools` (Debian) | secondary |
| `:345` | `[ -d "/etc/xdg/autostart" ]` | freedesktop/xdg dir | secondary |
| `:536` | `[ -d "$UCM_DIR" ]` (`/usr/share/alsa/ucm2`) | `alsa-ucm-conf` | secondary |
| `:541` | `[ -d "/etc/pipewire" ]` | `pipewire` | secondary |

CONTEXT scope is the three bold rows; a plan may add WARNs there only (the others are adjacent and optional).

### Finding 8 — `--verify` design (deliverable #8)
A manifest-diff mode can compare the deploy inventory from Finding 1. Recommended representation: a single function `deploy_manifest()` emitting `path<TAB>kind` lines (kinds: `file`, `exec`, `dir`, `unit`, `unit-enabled`, `grub-snippet`, `fstab-line`), consumed by both `do_install`/`do_uninstall` (single source of truth) and by `--verify`. `--verify [--root DIR]` reads the manifest, prefixes each path with `${D330_ROOT:-}${DIR}`, and checks: file exists; mode has `+x` for `exec`; `systemctl is-enabled` returns `enabled` for `unit-enabled` (skippable when `systemctl` absent or `--root` is set); fstab line present via `grep -qxF`. Exit non-zero and print each drift with its kind. **What is machine-checkable off-hardware:** the manifest ↔ script consistency (static: every manifest path appears as a deploy target and vice versa), the enable-set equality across the three sites, and a fixture-tree existence check if `--root` is honored. Full temp-root deploy requires prefixing every absolute destination with a `ROOT_PREFIX` — a larger refactor; the honest minimum for Phase 35 is the **static manifest self-check + a PATH-shim fixture test** (see Finding 10).

### Finding 9 — Package manifest parity (deliverable #9)
Per-unit enable parity across `install_dkms.sh` / `packaging/debian/postinst` / `packaging/rpm/lenovo-d330-fix.spec` `%post`:

| Unit | install | deb | rpm |
|------|:--:|:--:|:--:|
| `d330-tablet-daemon` | ✅ | ✅ | ✅ |
| `lenovo-d330-power` | ✅ | ✅ | ✅ |
| `lenovo-d330-camera-loopback` | ❌ | ❌ | ❌ |
| `d330-hardware-state` | ✅ | ✅ | ❌ |
| `lenovo-d330-backlight-pwm` | ✅ | ✅ | ❌ |
| `d330-sensor-filter` | ✅ | ✅ | ❌ |
| `d330-auto-hibernate` | ✅ | ✅ | ✅ |
| `d330-thermal` | ✅ | ❌ | ❌ |
| `d330-swapfile` | ✅ | ✅ | ✅ |

Both packages ship all units by glob (`spec:40` `cp patches/*/etc/systemd/system/*.service`; `debian/rules` packages the same glob), so deploy parity holds; only **enable** parity differs. `packaging/arch/PKGBUILD` packages units (`install -m 644 ... *.service`) but **enables nothing** (no `.install`, no `systemctl`) — outside CONTEXT scope but noted. Neither deb nor rpm has an uninstall section (`%preun`/`prerm` absent), consistent with the deferred `%preun` gap.

### Finding 10 — Environment reality (deliverable #10)
- **This machine:** Windows dev box; `bash` resolves to `c:\windows\system32\bash.exe` (WSL). No `systemctl`/`dkms`/`update-grub` on the Windows side.
- **Machine-testable off-hardware:** (a) static greps — unit census (`glob`), enable-line presence per site, replacement of `rm -rf .../earlyoom.service.d`, presence of a `dracut` branch in uninstall, `--verify` manifest ↔ deploy-target consistency, `check_prerequisites` gated on `ACTION`; (b) a **PATH-shim fixture test** modeled on `scripts/test_microsd_guards.sh` — shadow `systemctl`, `dkms`, `update-grub`, `grub-mkconfig`, `update-initramfs`, `dracut`, `modprobe`, `systemd-hwdb`, `udevadm` and run `do_install`/`do_uninstall` against a temp root. This requires a `ROOT_PREFIX="${D330_ROOT:-}"` prefix on destinations (refactor) or a fixture that pre-creates the absolute paths; without it, only static checks run.
- **Hardware-only:** actual `systemctl is-enabled` state, real `grub.cfg` regeneration and boot-menu effect, rescue-shell invocation, `dkms` build on the target kernel.
- **Existing gates to preserve:** `scripts/test_hibernate_guards.sh` 21/0, `scripts/test_display_fix_guards.sh` 10/0, `scripts/test_storage_cellular.sh --dry-run` rc=0. `scripts/test_distro_packaging.sh` only checks file existence/syntax — no enable parity today.

## Risks / Unknowns

| # | Risk | Severity | Mitigation |
|---|------|----------|------------|
| R1 | CONTEXT/roadmap premise drift: "shipped 8" / "7,6,3 enabled" are all wrong (real: 9 shipped / 8,7,4 enabled). A plan hardening to 8 will fail SC2. | HIGH | Enumerate the 9 units from glob; assert count in a guard case; target 9 enabled. |
| R2 | Adding grub regen to install may surface a non-zero `update-grub` on machines with no ESP/EFI layout; install currently uses `|| true`. | MEDIUM | Keep `|| true` + honest `[WARN]`, matching the locked "never silent no-op" rule. |
| R3 | `--verify` with `--root` requires prefixing every hardcoded absolute path; large diff surface, regression risk in install path. | MEDIUM | Ship static manifest self-check first; add `--root` as opt-in; PATH-shim fixture for behavior. |
| R4 | Skipping `EUID` for `--uninstall` lets an unprivileged user attempt writes that then fail per-command (all `|| true`), producing a misleading "Uninstallation complete." | MEDIUM | Gate each removal behind an explicit writability/root check, or print a single honest failure summary. |
| R5 | `systemctl unmask` of wait-online on a system that never masked it is a no-op (fine) but could unmask a deliberately masked service. | LOW | CONTEXT locks it; scope to the two named units only. |
| R6 | RPM `%post` enable parity edit has no `%preun`; enabling more units widens the existing uninstall gap. | LOW | Out of scope per CONTEXT; record, don't invent `%preun`. |

**Unknowns:** none blocking. The one open design choice is the `--verify` representation (Bash array vs generated file) — CONTEXT leaves it to discretion; Finding 8 recommends a manifest function.

## Recommended Implementation Approach

1. **`run_grub_regen()` helper** wrapping the existing detection ladder (`:488-494`). Call after grub.d writes at `:276` and after grub.d removals at `:630` (track `50/51/52` presence like `:635-638`). Reuse for the resume path (`:497-517`, `:713-726`). Honest `[WARN]` when no tool found.
2. **Unit census function** — `shipped_units()` returning the 9 basenames (or glob `patches/**/etc/systemd/system/*.service`). `do_install` enables every entry; deb postinst and rpm `%post` gain the missing enables (`d330-thermal`, `d330-sensor-filter`, `d330-hardware-state`, `lenovo-d330-backlight-pwm`, `lenovo-d330-camera-loopback` as applicable per-site). Assert count = 9.
3. **`check_prerequisites` gated on `ACTION`** — skip `EUID` (`:49-52`) and build-tool checks (`:54-72`) when `ACTION=uninstall`; keep for install/dry-run.
4. **Foreign drop-in fix at `:643`** — `rm -f .../d330-override.conf` + `rmdir ... 2>/dev/null || true`. (Confirm the shipped drop-in filename in `patches/oom_protection/etc/systemd/system/earlyoom.service.d/` and delete that exact file only.)
5. **Uninstall additions:** `rm -f /etc/d330-hardware-state.json`; `systemctl unmask systemd-networkd-wait-online.service NetworkManager-wait-online.service`; add `elif command -v dracut; then dracut -f || true` at `:729`.
6. **Missing-package WARNs** at `:295`, `:553`, `:557` (optionally the secondary guards in Finding 7).
7. **`--verify`:** `deploy_manifest()` function + `--verify [--root DIR]` exit non-zero on drift; static self-check plus PATH-shim fixture; document hardware-only checks.
8. **Guard suite** `scripts/test_installer_symmetry.sh` modeled on `test_microsd_guards.sh`: static cases (unit census = 9; every shipped unit enabled in all mandated sites; `rm -rf .../earlyoom.service.d` absent; `dracut` branch present in uninstall; `ACTION`-gated prereqs; `--verify` manifest ↔ deploy targets) + fixture cases via PATH shims.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Bash guard suites (shell, `set -euo pipefail`) |
| Config file | none — each suite is standalone (`scripts/test_*.sh`) |
| Quick run command | `bash scripts/test_installer_symmetry.sh` (new) |
| Full suite command | `for f in scripts/test_*.sh; do bash "$f"; done` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| M1 | grub regen invoked after grub.d touch in both paths | static | `grep -c 'run_grub_regen' scripts/install_dkms.sh` | ❌ Wave 0 |
| M2 | 9 shipped units all enabled at all mandated sites | static | unit-census guard case | ❌ Wave 0 |
| M11 | no `rm -rf /etc/systemd/system/earlyoom.service.d`; prereqs gated | static | grep guard case | ❌ Wave 0 |
| N6 | hardware-state.json removed; dracut branch present; unmask present | static | grep guard case | ❌ Wave 0 |
| M1/M2/M11/N6 | deploy/uninstall inverse behavior | fixture | PATH-shim fixture (temp root) | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `bash scripts/test_installer_symmetry.sh`
- **Per wave merge:** full `scripts/test_*.sh` sweep
- **Phase gate:** full suite green; hardware-only UAT for real `update-grub`/enabled state.

### Wave 0 Gaps
- [ ] `scripts/test_installer_symmetry.sh` — new guard suite covering the requirements above
- [ ] PATH-shim fixture harness (shadow systemctl/dkms/grub tools) — no existing installer shim suite
- [ ] Optional `ROOT_PREFIX`/`D330_ROOT` refactor to enable temp-root behavior tests

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A2 | `c:\windows\system32\bash.exe` is a usable WSL bash for running static/shim suites | Finding 10 | If not, CI on Linux is the only test host; static checks still valid |
| A3 | `rmdir` on a non-empty foreign drop-in dir is the desired no-op (CONTEXT locks it) | Finding 5 | Acceptable by decision |

*(A1 was resolved during research: `patches/oom_protection/etc/systemd/system/earlyoom.service.d/d330-override.conf` exists — the replacement filename is exact.)*

**Note:** All other claims in this research are `[VERIFIED:]` against files read this session (line ranges cited inline) or `[CITED:]` to ROADMAP/CONTEXT/phase artifacts.

## Sources

### Primary (HIGH confidence — read this session)
- `scripts/install_dkms.sh` (all 764 lines) — line ranges throughout Findings 1-6
- `packaging/debian/postinst` (27 lines) — enable set `:13-19`
- `packaging/rpm/lenovo-d330-fix.spec` (60 lines) — `%post` `:46-49`, `%install` glob `:40`
- `tools/d330-ctl` `:16,116-118,127-134` — state-file producer/consumer
- glob `patches/**/etc/systemd/system/*.service` — 9 shipped units
- `patches/hardware_controls/etc/systemd/system/d330-hardware-state.service` — ExecStop writer
- `.planning/ROADMAP.md:181-200` — Phase 35 goal/SC/components

### Secondary (MEDIUM confidence)
- `.planning/phases/35-installer-uninstaller-symmetry/35-CONTEXT.md` — locked decisions (premise corrected)
- `.planning/phases/34-*/34-VERIFICATION.md:69`; `34-01-SUMMARY.md:255,259`; `34-RESEARCH.md:141` — unit deletion / census history
- `scripts/test_microsd_guards.sh`, `scripts/test_display_fix_guards.sh`, `scripts/test_distro_packaging.sh` — suite patterns

## Metadata

**Confidence breakdown:**
- Action inventory: HIGH — every row read from source with line numbers
- Unit census: HIGH — glob + three enable sites read
- GRUB/prereq/drop-in/silent-skip findings: HIGH — direct source reads
- `--verify` design: MEDIUM — design recommendation, not yet implemented
- Environment: MEDIUM — Windows host, WSL bash assumed usable

**Research date:** 2026-10-08
**Valid until:** 2026-11-07 (stable repo; 30 days)
