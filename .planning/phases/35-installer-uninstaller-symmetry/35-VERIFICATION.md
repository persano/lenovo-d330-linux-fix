---
phase: 35-installer-uninstaller-symmetry
verified: 2026-10-08T15:52:00Z
status: human_needed
score: 8/10 must-haves verified
behavior_unverified: 2
overrides_applied: 0
re_verification:
  previous_status: null
  previous_score: null
  gaps_closed: []
  gaps_remaining: []
  regressions: []
gaps:
  - truth: "SC1: install -> uninstall leaves nothing under /etc, /usr/local/bin, /usr/share/alsa (real find sweep on the target)"
    status: partial
    reason: "Machine half is green (--verify --removed empty root rc=0, populated root rc=1+DRIFT). The real find sweep needs a systemd target and cannot run here; deferred to UAT. Residual machine risk: two manifest entries marked required are only deployed when their parent dir already exists, so --verify --root / can false-DRIFT on a host lacking /usr/share/alsa/ucm2 or /usr/share/initramfs-tools/hooks."
    artifacts:
      - path: "scripts/install_dkms.sh"
        issue: "manifest kinds `/usr/share/alsa/ucm2/sof-essx8336` (dir) and `/usr/share/initramfs-tools/hooks/lenovo-d330-plymouth` (exec) are required, but install only deploys them when the Debian/Ubuntu parent dir exists (lines 688, 423). On the primary Mint target both exist; on a dracut-only host --verify reports 2 false DRIFTs (reproduced: 2 DRIFT of 77)."
    missing:
      - "Mark those two entries `dir-optional`/`exec-optional` (or add a parent-dir check to do_verify), OR document the Debian-only precondition."
  - truth: "Honest non-root uninstall message (WR-04)"
    status: partial
    reason: "The misleading success line is correctly gated; no false success. But do_uninstall's removal list is bare `rm -f` under `set -euo pipefail`, so on a real installed tree (root-owned files) the first unprivileged rm fails and the shell aborts before the honest `[WARN] not root` line can print. The warn path is only reachable on a clean tree (reproduced: clean WSL run prints the WARN; a non-writable dir reproduces the set -e abort, rc=1)."
    artifacts:
      - path: "scripts/install_dkms.sh"
        issue: "lines 767-844: bare `rm -f` removals; a permission-denied removal aborts do_uninstall under set -e before the summary at lines 909-915."
    missing:
      - "Guard each removal (`|| true`) or record the first failure and keep going, so the honest non-root WARN is always reached."
behavior_unverified_items:
  - truth: "SC1: real `find /etc /usr/local/bin /usr/share/alsa` returns empty after install -> uninstall on the target"
    test: "On the D330 (or a systemd VM) run `sudo ./scripts/install_dkms.sh --install`, then `sudo ./scripts/install_dkms.sh --uninstall`, then `find /etc /usr/local/bin /usr/share/alsa \\( -name '*d330*' -o -name 'lenovo-d330*' \\)`."
    expected: "Empty output. In particular /etc/d330-hardware-state.json must be gone and /usr/share/alsa/ucm2/sof-essx8336 must be empty/removed."
    why_human: "Needs a real root filesystem and a root-run install/uninstall cycle; the off-hardware --verify fixture only proves the manifest logic, not the actual rm/find on a live tree."
  - truth: "SC2: `systemctl is-enabled` on all 9 units returns `enabled` after a real install"
    test: "After `sudo ./scripts/install_dkms.sh --install` (and, for the packaged paths, `dpkg -i` / `rpm -i`), run `for u in d330-tablet-daemon lenovo-d330-power lenovo-d330-camera-loopback d330-hardware-state lenovo-d330-backlight-pwm d330-sensor-filter d330-auto-hibernate d330-thermal d330-swapfile; do systemctl is-enabled \"$u.service\"; done`."
    expected: "Every line `enabled`."
    why_human: "`systemctl is-enabled` state requires a running systemd (PID 1); off-hardware --verify only proves the three enable sites list the same 9 unit names."
human_verification:
  - test: "SC1 real find sweep (see behavior_unverified_items #1)"
    expected: "find returns empty after install -> uninstall"
    why_human: "live root filesystem + root install/uninstall cycle"
  - test: "SC2 real is-enabled sweep (see behavior_unverified_items #2)"
    expected: "all 9 units report enabled"
    why_human: "needs running systemd"
  - test: "GRUB regen observed in /boot/grub/grub.cfg"
    expected: "After install the 50/51/52 (and 53 when hibernate activated) snippets are reflected; after uninstall they are gone, or the honest 'no mkconfig tool found' WARN was logged."
    why_human: "Bootloader regeneration only happens against a real /boot with a mkconfig tool."
  - test: "Rescue-shell --uninstall"
    expected: "`./scripts/install_dkms.sh --uninstall` runs without dkms/make/gcc present and without the root check aborting."
    why_human: "Requires a minimal rescue environment; the off-hardware proof is the install-only gate (verified statically and by --dry-run)."
  - test: "Residual CR-01 on a non-Debian host"
    expected: "Decide whether `--verify` may false-DRIFT for /usr/share/alsa/ucm2/sof-essx8336 and /usr/share/initramfs-tools/hooks/lenovo-d330-plymouth when those parent dirs are absent."
    why_human: "Target-distro packaging choice; reproduced as 2 DRIFTs on a fixture missing only those two parents."
deferred:
  - truth: "RPM %preun uninstall section (disable/remove units on package removal)"
    addressed_in: "Phase 42"
    evidence: "35-CONTEXT <deferred>: 'Package-level uninstall sections beyond the RPM %post enable (RPM %preun gap already noted for a later phase)'."
  - truth: "Tray applet / tablet daemon session wiring"
    addressed_in: "Phase 36"
    evidence: "ROADMAP Phase 36: Desktop Session Wiring - Tray Applet & Tablet Daemon."
---

# Phase 35: Installer & Uninstaller Symmetry Verification Report

**Phase Goal:** `--install` and `--uninstall` must be exact inverses, and deployed configuration must actually take effect.
**Verified:** 2026-10-08T15:52:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Verdict Summary

| SC | Machine half | Hardware half | Verdict |
|----|--------------|---------------|---------|
| SC1 install→uninstall leaves no `*d330*`/`lenovo-d330*` under /etc, /usr/local/bin, /usr/share/alsa | ✓ VERIFIED (`--verify --removed` empty rc=0 / populated rc=1+DRIFT; `--verify --root` drift/clean) | ⚠️ needs target (find sweep) | PASS (off-hardware) + UAT |
| SC2 `systemctl is-enabled` all 9 units `enabled` after install | ✓ VERIFIED (9 distinct enables × 3 sites, camera-loopback present, manifest unit set identical) | ⚠️ needs target (is-enabled) | PASS (off-hardware) + UAT |

**No must-have truth FAILED, no artifact MISSING/STUB, no key link NOT_WIRED, no debt markers.** The two remaining truths are present + wired but their runtime behavior cannot be exercised off-hardware → `human_needed`.

> Working-tree note: `scripts/test_display_fix_guards.sh` and `scripts/test_resume_loop.sh` are dirty (CRLF artifact from `core.autocrlf=true`); this is a pre-existing local checkout artifact, not a phase regression. All gates were run against the committed LF blobs in a clean clone (`git -c core.autocrlf=false clone`) at HEAD `dc4deca`.

## Goal Achievement

### Observable Truths

| #   | Truth   | Status     | Evidence       |
| --- | ------- | ---------- | -------------- |
| 1 | A single `deploy_manifest()` is the source of truth; `--verify [--root DIR]` diffs against it and exits non-zero on drift | ✓ VERIFIED | `deploy_manifest()` at `scripts/install_dkms.sh:81-161`; `do_verify` consumes it (`:936-1058`). Empty fixture root → `verify: 56 DRIFT of 77` rc=1; populated-from-manifest fixture → `[OK] verify: all 77 manifest entries present` rc=0. Suite `manifest-single-source`, `manifest-deploy-consistency`, `verify-drift-detected`, `verify-clean-passes` green. (Install/uninstall do not *iterate* the manifest — the manifest↔install↔uninstall contract is enforced by the `manifest-deploy-consistency` case incl. a mutation test; see note.) |
| 2 | `update-grub`/`grub-mkconfig` runs after touching `/etc/default/grub.d` in BOTH do_install and do_uninstall (honest WARN when absent) | ✓ VERIFIED | `run_grub_regen()` `:270-289`; call in `do_install` `:421` ("grub.d snippets deployed") and `do_uninstall` `:899` ("grub.d snippets removed"), guarded by `GRUB_D_WAS_PRESENT` `:798-802`. Honest WARN at `:285`. Suite `grub-regen-both-paths` green. |
| 3 | `--uninstall` (and `--verify`/`--dump-manifest`) skip dkms/make/gcc + EUID checks; `--install` keeps both | ✓ VERIFIED | Gate `:1101-1108` calls `check_prerequisites` only for `install`; else logs "Skipping prerequisite/root checks... (rescue-shell / read-only mode)". Demonstrated non-root: `--uninstall --dry-run` rc=0, `--verify` rc=1 (ran, drift) with the skip line; `--install --dry-run` rc=1 "Missing required build tools: dkms". Suite `uninstall-rescue-bypass` green. |
| 4 | All 9 shipped units enabled at install_dkms.sh, deb postinst and rpm %post (camera-loopback = the missing one) | ✓ VERIFIED | 9 distinct `systemctl enable *.service` in each of the three files; `lenovo-d330-camera-loopback.service` present in all three; the manifest `unit-enabled` set equals the enable set. Suite `enable-parity-9` green. |
| 5 | earlyoom drop-in removal is narrow (`rm -f d330-override.conf` + `rmdir`); missing-package skips log a named `[WARN]` | ✓ VERIFIED | `:812-813` narrow removal; no `rm -rf /etc/systemd/system/*.service.d`. Named WARNs at `:446` (thermald), `:711` (tlp), `:719` (colord/ICC). No doubled `[WARN] [WARN]` (`grep 'log_warn "\[WARN\]'` = 0). Suite `dropin-narrow-removal`, `warn-named-packages`, `no-broad-rm-rf`, `no-broad-ucm-rm-rf` green. |
| 6 | Uninstall removes `/etc/d330-hardware-state.json`, unmasks the two wait-online units, runs the dracut branch | ✓ VERIFIED | `:844` state json, `:886-887` two unmask lines, `:901-907` update-initramfs/dracut branch. Suite `uninstall-gaps` green. |
| 7 | SC1 machine half: `--verify --removed` empty rc=0, populated rc=1+DRIFT; `--verify --root` drift/clean | ✓ VERIFIED | `--verify --removed --root <empty mktemp>` rc=0 ("all 77 manifest entries absent"); populate one manifest path → rc=1 + `[DRIFT] ... still present after uninstall`. `--verify --root <populated>` rc=0. Suite `verify-removed-direction`, `verify-conditional-absent` green. |
| 8 | New `scripts/test_installer_symmetry.sh` green and delegated; existing suites stay green | ✓ VERIFIED | 16/0 (see tail); hibernate 21/0; display 10/0; `test_storage_cellular.sh --dry-run` rc=0 (26/0 + 10/0 + 21/0 + 16/0). Wired at `scripts/test_storage_cellular.sh:59,86`. |
| 9 | SC1 hardware half: real `find /etc /usr/local/bin /usr/share/alsa` empty after install→uninstall on the target | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Manifest/uninstall code present + wired; no off-hardware test exercises a live root install/uninstall. UAT item. Residual CR-01 risk in `gaps` (2 required-but-conditional entries). |
| 10 | SC2 hardware half: `systemctl is-enabled` returns `enabled` for all 9 units after a real install | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Static 9-unit parity verified; requires running systemd (PID 1) for real `is-enabled`. UAT item. |

**Score:** 8/10 truths verified (2 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected    | Status | Details |
| -------- | ----------- | ------ | ------- |
| `scripts/install_dkms.sh` | manifest + `--verify [--root] [--removed]` + `--dump-manifest`, grub regen both ways, rescue bypass, 9-unit enable, narrow removal, named WARNs, uninstall gaps | ✓ VERIFIED | `bash -n` clean; all greps/behavior confirmed (see truths). 59628 bytes, 1115 lines. |
| `scripts/test_installer_symmetry.sh` | 16-case guard suite, static + fixture, no real systemctl/dkms/grub | ✓ VERIFIED | 16/0; no system mutation. |
| `packaging/debian/postinst` | 9 enables incl. camera-loopback | ✓ VERIFIED | 9 distinct enables `:13-21`; `sh`-clean. |
| `packaging/rpm/lenovo-d330-fix.spec` | 9 enables incl. camera-loopback | ✓ VERIFIED | 9 distinct enables `:47-55`; units shipped by glob `:40`. |
| `packaging/debian/rules` | ship all 9 unit files | ✓ VERIFIED | `cp patches/*/etc/systemd/system/*.service` `:22` (all 9 source units exist in repo). |

### Key Link Verification

| From | To  | Via | Status | Details |
| ---- | --- | --- | ------ | ------- |
| `deploy_manifest()` | `do_verify` | `done < <(deploy_manifest)` `:1049` | ✓ WIRED | Every manifest entry is read and checked. |
| `do_install` | GRUB regen | `run_grub_regen "grub.d snippets deployed"` `:421` | ✓ WIRED | after grub.d copies `:413-419`. |
| `do_uninstall` | GRUB regen | `run_grub_regen "grub.d snippets removed"` `:899` | ✓ WIRED | guarded by removed-snippet detection `:798-802`. |
| CLI `--removed`/`--root` | `do_verify` | `do_verify "$VERIFY_ROOT" "$VERIFY_REMOVED"` `:1113` | ✓ WIRED | flags parsed `:1071-1080`. |
| enable sites | 9 shipped units | `systemctl enable <unit>` ×3 files | ✓ WIRED | sets identical; all 9 unit source files exist. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| `do_verify` | `path`/`kind` | `deploy_manifest()` heredoc (77 lines) | Yes — 77 entries iterated, drift counted | ✓ FLOWING |
| `--verify --root` fixture | `full="${root%/}${path}"` | parsed CLI root | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| Removed-direction clean | `bash scripts/install_dkms.sh --verify --removed --root <empty>` | rc=0, "all 77 manifest entries absent" | ✓ PASS |
| Removed-direction drift | `--verify --removed --root <one manifest path>` | rc=1, `[DRIFT] ... still present after uninstall` | ✓ PASS |
| Presence drift | `--verify --root <empty>` | rc=1, "56 DRIFT of 77" | ✓ PASS |
| Presence clean | `--verify --root <populated from manifest>` | rc=0, "all 77 manifest entries present" | ✓ PASS |
| Conditional absent (CR-01) | fixture of required entries only | rc=0, optional entries SKIP | ✓ PASS |
| Rescue bypass | `--uninstall --dry-run` (non-root) | rc=0, skip line | ✓ PASS |
| Install gate retained | `--install --dry-run` (non-root) | rc=1, "Missing required build tools: dkms" | ✓ PASS |
| Non-root uninstall honesty | `--uninstall` on clean WSL | rc=0, `[WARN] not root - removals were skipped` | ✓ PASS (see gap #2) |
| `set -e` on failing `rm -f` | non-writable dir | rc=1, aborts before next line | ✓ PASS (documents gap #2) |

### Probe Execution

No `scripts/*/tests/probe-*.sh` exist for this phase and neither PLAN nor SUMMARY declares probes; the phase's machine checks are the fixture `--verify` round trip and the guard suite. **Step 7c: SKIPPED (no probes declared).**

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| SC1 | 35-01 | install→uninstall leaves no `*d330*`/`lenovo-d330*` under /etc,/usr/local/bin,/usr/share/alsa | ✓ SATISFIED (machine half) / ⚠️ hardware UAT | `--verify --removed` round trip; UCM2 source has exactly the 2 files the narrow removal deletes. |
| SC2 | 35-01 | `systemctl is-enabled` on all 9 units `enabled` after install | ✓ SATISFIED (machine half) / ⚠️ hardware UAT | 9-unit parity × 3 sites; all 9 unit files ship. |

No orphaned requirements (both roadmap SCs are claimed by 35-01).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `scripts/install_dkms.sh` | 767-844 | bare `rm -f` under `set -e` in `do_uninstall` | ⚠️ Warning | Non-root uninstall aborts on first permission-denied removal, before the honest WARN; no false success (see gap #2). |
| `scripts/install_dkms.sh` | 144, 116 | required manifest kinds only deployed when parent dir exists | ⚠️ Warning | Can false-DRIFT `--verify` on a non-Debian host (see gap #1). |
| — | — | `TBD`/`FIXME`/`XXX` in phase-modified files | ℹ️ Info | None found. |

### Grub / Trust-boundary notes

- `run_grub_regen` is warn-not-fail (`:285`, callers suffix `|| true`) — a missing tool cannot break boot (threat T-35-04 mitigated).
- Narrow drop-in removal + `rmdir || true` protects foreign systemd files (T-35-02 mitigated).
- `--uninstall` EUID skip is deliberate (T-35-03 accepted); removal is scoped to manifest paths.

### Human Verification Required

See frontmatter `human_verification` (5 items). Priority order:

1. **SC2 real enablement** — install then `systemctl is-enabled` the 9 units → all `enabled`.
2. **SC1 real symmetry** — install → uninstall → `find /etc /usr/local/bin /usr/share/alsa \( -name '*d330*' -o -name 'lenovo-d330*' \)` → empty (`/etc/d330-hardware-state.json` gone).
3. **GRUB regen both ways** — confirm `grub.cfg` reflects snippets after install and not after uninstall (or the honest WARN).
4. **Rescue-shell `--uninstall`** — runs without build tools / root gate.
5. **Residual CR-01 decision** — accept or fix the 2 required-but-conditional manifest entries.

### Gaps Summary

No BLOCKER. Two PARTIAL warnings:

1. **Residual CR-01 (required-but-conditional).** `--verify --root /` on a host lacking `/usr/share/alsa/ucm2` or `/usr/share/initramfs-tools/hooks` still false-DRIFTs on `/usr/share/alsa/ucm2/sof-essx8336` (dir) and `/usr/share/initramfs-tools/hooks/lenovo-d330-plymouth` (exec). The target (Linux Mint/Ubuntu) has both dirs, so this is a target-distro edge, not a blocker. Reproduced: 2 DRIFT of 77.
2. **Non-root uninstall honesty.** The false success line is fixed (no false success), but the new honest WARN is unreachable on a real installed tree because bare `rm -f` fails under `set -e` and aborts first. Consider `|| true` on removals so the summary always prints.

Both are `partial` (warnings), not failed must-haves; overall status stays `human_needed` pending the SC1/SC2 hardware halves.

---

_Verified: 2026-10-08T15:52:00Z_
_Verifier: the agent (gsd-verifier)_
