# Phase 35: Installer & Uninstaller Symmetry — Validation Strategy

**Created:** 2026-10-08 (slim pipeline: research + inline plan, no plan-checker; review + verification kept)
**ASVS level:** 1, **block on:** high

## Security Validation

| Threat | Mitigation / validation |
|---|---|
| Uninstall leaves stale config (T-35-01, high) | Manifest-driven uninstall + `--verify [--root]` drift detection; suite fixture round trip asserts identity clean/empty |
| Broad `rm -rf` on systemd drop-in dirs wipes foreign files (T-35-02, high) | Narrow `rm -f d330-owned.conf` + `rmdir \|\| true`; `no-broad-rm-rf` / `dropin-narrow-removal` suite cases |
| `--uninstall` skips the root check (T-35-03, med) | Deliberate rescue-shell use; removal scoped to manifest paths only |
| False "install succeeded" while units disabled (T-35-05, high) | 9-unit enable parity across install_dkms.sh / deb postinst / rpm %post; real `is-enabled` UAT |
| grub regen failure breaks boot (T-35-04, med) | Warn-not-fail; exact-value verify retained |

## Functional Validation

1. Static: `bash -n` all touched files; manifest single-source grep; grub regen present in both `do_install`/`do_uninstall`; prereq/EUID install-gated; 9-unit parity count per file; no broad `rm -rf *.service.d`; named package WARNs; uninstall gap greps.
2. Fixture behaviour: `--verify --root <mktemp>` on an empty/tampered root → non-zero + `DRIFT`; populated root → exit 0. No real `systemctl`/`dkms`/`grub` invoked.
3. New suite `scripts/test_installer_symmetry.sh` (cases listed in plan Task 7) wired into `scripts/test_storage_cellular.sh --dry-run`.
4. Existing gates stay green: `test_hibernate_guards.sh` 21/0, `test_display_fix_guards.sh` 10/0, `test_storage_cellular.sh --dry-run` rc=0.

## On-Target / Human Acceptance (deferred → VERIFICATION overrides)

- SC1: real install → uninstall → `find /etc /usr/local/bin /usr/share/alsa (...)` empty.
- SC2: `systemctl is-enabled` on all 9 units → `enabled` after a real install (three install paths).
- GRUB regen observed in grub.cfg both ways; rescue-shell `--uninstall` runs without build tools.
