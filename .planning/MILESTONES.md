# Milestones

## v9.0 v9.0 (Shipped: 2026-10-16)

**Phases completed:** 0 phases, 0 plans, 0 tasks

**Key accomplishments:**

- (none recorded)

---

## v9.0 v9.0 (Shipped: 2026-10-16)

**Phases completed:** 3 phases, 10 plans, 4 tasks

**Key accomplishments:**

- Dump-pair diff tooling (`dsi_mmio_diff.sh`) that joins boot/resume captures into file:line-cited markdown rows with per-range exclusion and all-ones/PLL-off state classification, plus the 7-case static evidence guard (`test_dsi_mmio_evidence.sh`) proven green via fixtures and red-until-evidence in plain mode.

---

## v9.0 Actually Fix the D330 Resume Black Screen (In Progress)

**Phases:** 47-49 (DSI MMIO truth; clean DMI-gated fix; delivery + closure). Carries the unmet v8.0 promise: make the D330 resume show an image. Self-sufficient: no upstream dependency.

## v8.0 v8.0 (Closed: 2026-10-13 - RE + honest closure; BUG NOT FIXED, continues in v9.0)

**Phases completed:** 4 phases, 8 plans, 0 tasks

**Key accomplishments:**

- GOP driver identified + two-VBT handoff decoded (SPI VBT vs runtime OpRegion VBT, block-53 sequences)
- Resume-vs-reload differential + decisive displayinfo experiment: kernel display state byte-identical working-vs-broken; failure below the kernel model
- 29-row binding disproven-lever ledger with machine gate; rebind "recovery" myth-busted (only a full reboot restores the panel)
- 3 deployed, eyes-on-tested fix candidates all falsified; ROOT-4 honest closure (NO_CLEAN_FIX_PROOF.md)
- The resume black screen is NOT fixed. The fix hunt continues as milestone v9.0.

---

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
