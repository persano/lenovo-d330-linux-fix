---
phase: 43
plan: 43-04
wave: 2
status: complete
commits:
  - 7457425
  - 3784b30
  - db7d4e2
requirements: [GUARD-03]
---

# Plan 43-04 — Safety Kit Pipeline + Capture Protocol

## What shipped

- `scripts/prepare_safety_kit.sh` — kit prep/verify utility (deliberately not `test_*`-prefixed: mutating repo-side utility, never touches the system). Modes: `--register FILE` (repeatable; idempotent — replaces the existing manifest line for the same kit-relative path, never duplicates; refuses paths outside/escaping the kit dir), `--verify` (`sha256sum -c MANIFEST.sha256` from inside the kit dir, non-zero on any mismatch), `--dry-run` (hard-checks sha256sum presence, kit-dir writability, `scripts/build_live_iso.sh` existence; reports the ISO toolchain dry-run result informationally without failing kit-side checks), `--kit-dir DIR` (default `docs/dumps/safety_kit`), `--help`. Manifest lines are exactly `<64-hex><two spaces><kit-relative path>`.
- `scripts/test_safety_kit.sh` — fixture guard suite, 6 cases, all green:
  - `prep-script-syntax`, `register-creates-manifest` (strict format regex: 64 hex + exactly two spaces + kit-relative path, no `/` escape, no `..`; idempotent re-register keeps line count unchanged and hash consistent), `verify-passes-pristine` (pristine-first, SC1 rule), `verify-fails-on-tamper` (one appended byte flips verify to non-zero; restore makes it green again), `manifest-format-rejects-junk`, `protocol-doc-complete` (asserts the inhibit hold, ≥18 s window, rtcwake, no-cold-boot rationale, rollback pipeline steps, kit registration/verification commands, D330 marker-tracing rule, citations to both research docs, the ISO/kit script references, and the D330_REAL_FIX coexistence pointer).
- `docs/research/RESUME_CAPTURE_PROTOCOL.md` — two-arm capture protocol (black resume vs working unbind/bind reload; NO cold-boot control with the GOP fast-boot citation), `rtcwake -m mem`, `systemd-inhibit --what=idle` held for the entire test, ≥18-second window on BOTH arms with the 6-second-counterexample citation, capture set per arm (journalctl, dmesg, ftrace over the five display register ranges, prior-art capture pointers), D330-prefixed `pr_err`-only tracing rule with the drm.debug/dyndbg dead-end citation, verbatim golden-module rollback pipeline (build → strip --strip-debug → zstd -19 → deploy → depmod -a → update-initramfs -u → reboot; rollback = restore golden module + repeat), off-device kit-staging runbook (golden module, live ISO, VBT dump, GOP extract with `bios.bin` sha256, checksummed source tree; each `--register`ed, one `--verify` as mandatory pre-restore), and the D330_REAL_FIX coexistence cross-reference to the hook header.
- `scripts/test_storage_cellular.sh` — `test_safety_kit.sh` wired into the bash -n list and the chain (after the ledger suite). Harness now chains 38 suites.
- `.gitignore` — `docs/dumps/safety_kit/*` ignored with `!docs/dumps/safety_kit/MANIFEST.sha256` negated back in (artifacts never committed, manifest committable). Empirically verified: probe file ignored, manifest not ignored.
- `CHANGES_AUDIT.md` — count sentence 37 → 38; doc-parity green at 19 cases (representative-ones enumeration unchanged; the suite does not require it).

## Verification

- `bash scripts/test_safety_kit.sh` → `Safety kit suite summary: passed=6 failed=0`.
- `bash scripts/test_doc_parity.sh` → 19/0 at "38 test guards".
- `bash scripts/test_harness_trust.sh` → 9/0.
- `bash scripts/test_storage_cellular.sh --dry-run` → `CHAIN_EXIT=0` with all 38 suites green, including both new suites (`Ledger gate suite summary: passed=4 failed=0`, `Safety kit suite summary: passed=6 failed=0`).

## Deviations

- Executed inline by the orchestrator (subagent dispatch broken, disclosed at wave-1 start). Plan followed exactly; no worktree (ISOLATION=none milestone-wide).
- Plan Task 1's junk-manifest case assumed GNU `sha256sum -c` rejects a one-space separator line; empirically it accepts it for simple names. Implemented the intent (malformed manifest must fail verification, fail-closed) with a truncated hash, which `sha256sum -c` always rejects ("no properly formatted checksum lines"); the strict two-space format remains enforced at register time by the format regex.
- The ledger gate caught `43-01-SUMMARY.md` quoting its own fixture string `i915.enable_psr=0` once the SUMMARY became a tracked scanned file; resolved with the designed per-string `planner-discipline-allow` marker on that summary (committed with Task 3).
- The committed `.gitignore` also carries the user's own local additions made during this session (`.env` credential exclusion, local tool-state entries); no secret content is committed.

## Requirements touched

- GUARD-03: checksum-driven kit pipeline with tamper-detection suite chained into the harness, documented safe on-device capture protocol, and the off-device staging runbook — staged and machine-checked repo-side before any kernel experiment.

<!-- planner-discipline-allow: i915.enable_psr=0 -->
<!-- planner-discipline-allow: drm.debug/dyndbg dead-end citation -->
