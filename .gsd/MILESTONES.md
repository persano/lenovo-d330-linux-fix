# Milestones

## v7.0 Pre-Deployment Audit Remediation (Shipped: 2026-10-08)

**Phases completed:** 11 phases, 15 plans, 53 tasks

**Key accomplishments:**

- Explicit `--device` selection with three ordered pre-write guards (mountpoints, bidirectional root-device, typed-yes) in front of the first `parted` write, machine-proven abort-before-write by a 12-case PATH-shim suite with a parted canary — audit C1 format path closed.
- `--mount-data` now writes only proven, boot-safe fstab lines: locked `nofail,x-systemd.device-timeout=10s` options, `findmnt --verify` before the append, EXIT-trap rollback on failed mount with non-zero exit and no false success, honest duplicate/legacy refusal — machine-checked by nine new shim cases plus a real `findmnt`/`systemd-analyze` parse proof.
- `--mount-home` is now an honest non-zero "not implemented" stub with the help row marked unsupported, the closing `Storage expansion task complete.` has exactly one source occurrence reachable only from genuine format/mount-data completion, and the legacy `test_storage_cellular.sh --dry-run` harness runs real `bash -n` gates plus the whole 26-case guard suite instead of echoing three paths.
- Daemon now honest about hibernate readiness: env-seamed swap/resume report in --dry-run, refuse-and-degrade with rc-checked systemctl calls, ExecStart aligned to install path, 12-case guard suite green
- Hibernate can now physically complete: idempotent disk-backed swapfile unit, install-time-rendered resume cmdline with mkconfig verify + locked manual-step fallback, both units enabled in all three installers, guard suite grown 12 → 19 cases, all gates green
- README rewritten as the shipped subsystem's single source of truth with an eight-token docs-anchor suite case (suite 19 → 20, all gates green); the on-device SC1/SC2/SC3 round trip + R1 evidence steps deferred verbatim to UAT, never executed here
- Honest DMI banner module + deleted echo-only resume service + dry-run-gated `--kernel-src` clamp step + efifb:nobgrt kept with panel_orientation tokens, all truth-checked by a new 10-case guard suite.
- Manifest-driven installer symmetry: `deploy_manifest()` + `--verify [--root]`, GRUB regen both ways, rescue-shell uninstall, 9-unit enable parity, narrow drop-in removal, gap closure, and an 11-case guard suite.
- Wireless conf corrected to Realtek-only, hwdb/udev match strings fixed to real DMI/HID forms, no-op udev properties removed, and a mutation-proven SC3 test suite added.

---
