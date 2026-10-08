---
phase: installer-uninstaller-symmetry
plan: "35-01"
subsystem: infra
tags: [bash, installer, uninstaller, deploy-manifest, systemd, grub, dkms, guard-suite, symmetry]

requires:
  - phase: 33-low-battery-hibernate-feasibility
    provides: grub mkconfig ladder + uninstall snapshot precedent, swapfile/resume activation
  - phase: 34-deliver-the-actual-pps-display-resume-fix
    provides: resume service deletion (unit census 10 -> 9), --kernel-src clamp step
provides:
  - deploy_manifest() single source of truth (path<TAB>kind) for install/uninstall/verify
  - --verify [--root DIR] + --dump-manifest read-only modes (drift non-zero + DRIFT lines)
  - run_grub_regen() helper called after grub.d mutation in BOTH install and uninstall
  - rescue-shell bypass: --uninstall/--verify skip dkms/make/gcc + EUID gates
  - 9-unit enable parity across install_dkms.sh, deb postinst, rpm %post
  - narrow earlyoom drop-in removal + named missing-package WARNs
  - uninstall gap closure (state json, wait-online unmask, dracut branch)
  - scripts/test_installer_symmetry.sh (11 cases) wired into the storage harness
affects: [36-tray-tablet-daemon-wiring, 42-changes-audit-doc-parity, packaging]

actuals:
  tokens: 9300
  tasks: 7
  commits: 7

tech-stack:
  added: []
  patterns:
    - "Manifest-driven installer verification: one deploy_manifest() consumed by --verify and cross-checked by a guard suite"
    - "Read-only diagnostics (--verify/--dump-manifest) bypass the prerequisite gate; only --install gates on build tools + root"
    - "Narrow file-scoped removal (rm -f owned.conf + rmdir empty) instead of rm -rf on shared systemd drop-in dirs"
    - "pipefail-safe guard assertions (capture awk output, match with bash case) instead of awk|grep -q"

key-files:
  created:
    - scripts/test_installer_symmetry.sh
  modified:
    - scripts/install_dkms.sh
    - packaging/debian/postinst
    - packaging/rpm/lenovo-d330-fix.spec
    - scripts/test_storage_cellular.sh

key-decisions:
  - "Manifest is authoritative for --verify; install/uninstall literal copy/rm lines retained verbatim because the phase-33 hibernate guard suite greps them (gate compatibility), with a guard suite case cross-checking manifest <-> installer drift"
  - "Two separate `systemctl unmask` lines (networkd, NM) instead of one multi-arg line: the Task 6 verify contract greps each `unmask <unit>` substring contiguously"
  - "--uninstall bypasses the EUID/build-tool gate in addition to --verify/--dump-manifest (rescue-shell requirement M11)"
  - "verify skips unit-enabled/fstab-line kinds for --root != / (no systemd / not the real fstab in a fixture tree)"

patterns-established:
  - "deploy_manifest() path<TAB>kind inventory as the single artifact source"
  - "Fixture round trip: --dump-manifest output populates a temp root, --verify --root asserts it"

requirements-completed: [SC1, SC2]

coverage:
  - id: D1
    description: "Single deploy manifest drives a read-only --verify [--root] that exits non-zero with DRIFT lines on drift"
    requirement: SC1
    verification:
      - kind: integration
        ref: "scripts/test_installer_symmetry.sh#manifest-single-source"
        status: pass
      - kind: integration
        ref: "scripts/test_installer_symmetry.sh#verify-drift-detected"
        status: pass
      - kind: integration
        ref: "scripts/test_installer_symmetry.sh#verify-clean-passes"
        status: pass
    human_judgment: false
  - id: D2
    description: "GRUB regenerated (or named WARN) after grub.d changes in both install and uninstall"
    requirement: SC1
    verification:
      - kind: unit
        ref: "scripts/test_installer_symmetry.sh#grub-regen-both-paths"
        status: pass
    human_judgment: false
  - id: D3
    description: "--uninstall works in a rescue shell (skips dkms/make/gcc + EUID); --install unchanged"
    requirement: SC1
    verification:
      - kind: unit
        ref: "scripts/test_installer_symmetry.sh#uninstall-rescue-bypass"
        status: pass
    human_judgment: false
  - id: D4
    description: "All 9 shipped units enabled in install_dkms.sh, deb postinst and rpm %post"
    requirement: SC2
    verification:
      - kind: unit
        ref: "scripts/test_installer_symmetry.sh#enable-parity-9"
        status: pass
    human_judgment: false
  - id: D5
    description: "Foreign systemd drop-ins safe (narrow rm) + named missing-package WARNs (thermald/tlp/icc)"
    requirement: SC1
    verification:
      - kind: unit
        ref: "scripts/test_installer_symmetry.sh#dropin-narrow-removal"
        status: pass
      - kind: unit
        ref: "scripts/test_installer_symmetry.sh#warn-named-packages"
        status: pass
      - kind: unit
        ref: "scripts/test_installer_symmetry.sh#no-broad-rm-rf"
        status: pass
    human_judgment: false
  - id: D6
    description: "Uninstall closes gaps: removes /etc/d330-hardware-state.json, unmasks wait-online, runs dracut branch"
    requirement: SC1
    verification:
      - kind: unit
        ref: "scripts/test_installer_symmetry.sh#uninstall-gaps"
        status: pass
    human_judgment: false
  - id: D7
    description: "New symmetry guard suite green and delegated into scripts/test_storage_cellular.sh"
    verification:
      - kind: unit
        ref: "scripts/test_installer_symmetry.sh (11 cases, passed=11 failed=0)"
        status: pass
      - kind: integration
        ref: "scripts/test_storage_cellular.sh --dry-run (delegates the suite, rc=0)"
        status: pass
    human_judgment: false
  - id: D8
    description: "On-device SC1 (install->uninstall leaves nothing under /etc,/usr/local/bin,/usr/share/alsa) and SC2 (all 9 units is-enabled=on) on real hardware"
    requirement: SC2
    verification: []
    human_judgment: true
    rationale: "Real systemctl is-enabled state, actual grub.cfg regeneration and a rescue-shell invocation require the target D330/systemd host; only fixture/static checks run off-hardware (Task 8 blocking-human UAT)."

duration: ~15min
completed: 2026-10-08
status: complete
---

# Phase 35 Plan 35-01: Installer & Uninstaller Symmetry Summary

**Manifest-driven installer symmetry: `deploy_manifest()` + `--verify [--root]`, GRUB regen both ways, rescue-shell uninstall, 9-unit enable parity, narrow drop-in removal, gap closure, and an 11-case guard suite.**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-10-08T14:57:07Z
- **Completed:** 2026-10-08T15:11:00Z
- **Tasks:** 7 auto tasks complete (Task 8 = blocking-human checkpoint, deferred to UAT)
- **Files modified:** 5 (1 created, 4 modified)

## Accomplishments

- `scripts/install_dkms.sh` now defines `deploy_manifest()` (`path<TAB>kind`), the single source of truth consumed by `--verify [--root DIR]` and `--dump-manifest`; `--verify` exits non-zero with per-entry `DRIFT` lines and needs neither build tools nor root.
- GRUB is regenerated after `/etc/default/grub.d` mutation in BOTH `do_install` and `do_uninstall` via `run_grub_regen()` (named `[WARN]` when no mkconfig tool, never a failure), preserving the phase-33/34 resume verification behaviour.
- `--uninstall` (and `--verify`/`--dump-manifest`) bypass the dkms/make/gcc and EUID gates, so uninstall works from a rescue shell; `--install` keeps both.
- All 9 shipped units are enabled (with the `2>/dev/null || true` idiom) in `install_dkms.sh`, `packaging/debian/postinst` and the RPM `%post` — `lenovo-d330-camera-loopback.service` was the previously-missing one.
- Foreign earlyoom drop-ins are safe: `rm -f .../d330-override.conf` + `rmdir ... || true` replaces the broad `rm -rf`; silent skips for thermald/tlp/icc now log named `[WARN]` lines.
- Uninstall completeness: removes `/etc/d330-hardware-state.json`, unmasks `systemd-networkd-wait-online.service` and `NetworkManager-wait-online.service`, and adds install's `dracut -f` branch.
- New `scripts/test_installer_symmetry.sh` (11 cases) with a `--dump-manifest` fixture round trip, delegated into `scripts/test_storage_cellular.sh`.

## Task Commits

Each task was committed atomically via `gsd-tools query commit`:

1. **Task 1: Deploy manifest + `--verify [--root DIR]`** - `b04d067` (feat)
2. **Task 2: GRUB regeneration in both install and uninstall (M1)** - `9740b85` (fix)
3. **Task 3: `--uninstall`/`--verify` rescue-shell bypass (M11)** - `2b9e4ab` (fix)
4. **Task 4: Enable all 9 shipped units at all three sites (M2)** - `bdb52cb` (fix)
5. **Task 5: Foreign drop-in safety + named missing-package WARNs (M11/N6)** - `72d83a9` (fix)
6. **Task 6: Uninstall completeness (N6)** - `0b6f631` (fix)
7. **Task 7: Installer symmetry guard suite + fixture round trip** - `8d98395` (test)

**Plan metadata:** `docs(35): summary` (this SUMMARY)

## Files Created/Modified

- `scripts/install_dkms.sh` - `deploy_manifest()`, `do_verify()`, `run_grub_regen()`, mode dispatch/gate, 9-unit enable block, narrow drop-in removal, named WARNs, uninstall gap closure.
- `scripts/test_installer_symmetry.sh` - new 11-case guard suite (static + manifest-driven fixture).
- `scripts/test_storage_cellular.sh` - added the suite to the `bash -n` loop and delegated it.
- `packaging/debian/postinst` - 7 -> 9 enables (+camera-loopback, +thermal).
- `packaging/rpm/lenovo-d330-fix.spec` - 4 -> 9 enables (+camera-loopback, +hardware-state, +backlight-pwm, +sensor-filter, +thermal).

## Raw Gate Tails (final, verbatim)

```
===== installer symmetry suite =====
 Guard suite summary: passed=11 failed=0
symmetry rc=0

===== hibernate guards =====
 Guard suite summary: passed=21 failed=0
hibernate rc=0

===== display fix guards =====
 Guard suite summary: passed=10 failed=0
display rc=0

===== storage/cellular dry-run =====
 Guard suite summary: passed=26 failed=0
[OK] dry-run verification complete
storage rc=0

===== verify fixture drift proof =====
verify --root empty rc=1
  [SKIP] fstab line (fstab-line): non-root target
[ERROR] verify: 67 DRIFT of 77 manifest entries (root=/tmp/tmp.MciS2wCQcu).
DRIFT lines: 68

===== broad rm -rf check =====
no broad rm -rf on service.d
```

## Decisions Made

- **Manifest authoritative for `--verify`, literal copy/rm lines retained.** The phase-33 hibernate guard suite (`case_execstart_matches_install_path`, `case_uninstall_symmetry`, `case_installer_activation_step`) greps exact literal `cp`/`rm -f` lines in `install_dkms.sh`. Replacing those with a manifest iterator would break the 21/0 gate. So the refactor keeps the literal copy/removal lines verbatim and makes `deploy_manifest()` the single artifact source consumed by `--verify`, with a guard-suite case (`manifest-single-source`) cross-checking every manifest basename against the installer to prevent drift.
- **Two `systemctl unmask` lines** (networkd, NM) rather than one multi-arg call, so each `unmask <unit>` substring appears contiguously for the verify contract.
- **`--verify` kind semantics:** `dir`/`file`/`exec`/`unit`/`grub-snippet`/`state` check existence (exec also `+x`); `unit-enabled` and `fstab-line` are checked only against `/` and skipped for a fixture root.

## Deviations from Plan

### Verify-contract adaptations

**1. [Contract adaptation] `--verify` had to bypass the prerequisite gate in Task 1, not Task 3**

- **Found during:** Task 1
- **Issue:** Task 1's verify runs `bash "$S" --verify --root "$R"` and expects a `DRIFT` line. At Task 1 the script still called `check_prerequisites` before dispatch, which exits 1 with "requires root"/"missing build tools" on the dev host — so no `DRIFT` line could ever print.
- **Fix:** Task 1 gates the prerequisite call so `--verify`/`--dump-manifest` skip it; Task 3 extends the same gate to `--uninstall` (the M11 rescue-shell case). Both verifies pass.
- **Files modified:** scripts/install_dkms.sh
- **Committed in:** b04d067 (Task 1), 2b9e4ab (Task 3)

**2. [Contract adaptation] `systemctl unmask` split into two lines**

- **Found during:** Task 6
- **Issue:** Task 6's verify greps `unmask NetworkManager-wait-online.service` as a contiguous substring; a single multi-arg line `unmask systemd-networkd-wait-online.service NetworkManager-wait-online.service` does not contain it.
- **Fix:** Emit two separate `systemctl unmask <unit>` lines (semantically identical).
- **Files modified:** scripts/install_dkms.sh
- **Committed in:** 0b6f631 (Task 6)

### Auto-fixed issues

**3. [Rule 3 - Blocking] `pipefail` + `grep -q` SIGPIPE in the new suite**

- **Found during:** Task 7 (suite authoring)
- **Issue:** `awk '/do_install()/,/^}/' "$S" | grep -q ...` under `set -o pipefail` returned non-zero: `awk`'s >64 KB output received SIGPIPE when `grep -q` exited early, failing `grub-regen-both-paths`.
- **Fix:** Capture the awk range into a variable and match with bash `case "$body" in *needle*)` (no pipeline); same for the other piped checks.
- **Files modified:** scripts/test_installer_symmetry.sh
- **Verification:** Suite green 11/0.
- **Committed in:** 8d98395 (Task 7)

---

**Total deviations:** 2 verify-contract adaptations, 1 auto-fixed blocking issue.
**Impact on plan:** No scope creep. The literal copy/rm lines were deliberately retained for phase-33 gate compatibility (documented above); manifest/verify symmetry is machine-checked by the new suite.

## Issues Encountered

- None beyond the deviations above. The stale `check_prerequisites`/census comments were corrected in-place (Task 4) to reflect the 9-unit shipped census.

## Known Stubs

None.

## Threat Flags

None — no new network/auth/trust surface; the changes are scoped to the installer's manifest, verify mode, GRUB regen, permissions/skip gates, enable parity and drop-in removal, all covered by the plan's threat register (T-35-01..T-35-05).

## Deferred to UAT (Task 8, blocking-human)

Task 8 is a `checkpoint:human-verify` with `gate="blocking-human"`. It was **NOT executed and NOT auto-approved**. Extracted contract:

**What-built:** Single-source deploy manifest driving install/uninstall/`--verify`, GRUB regen on both paths, rescue-shell `--uninstall`, all 9 shipped units enabled at the three sites, foreign drop-in safety, named missing-package WARNs, uninstall gap closure, and a fixture-verified symmetry suite. Local machine checks are green; SC1/SC2 need the target.

**Precondition:** A D330 (or a throwaway Linux VM with systemd) with a snapshot/backup of `/etc` and a GRUB install; run the installer root-privileged.

**How-to-verify:**
1. **SC2 enablement:** `sudo ./scripts/install_dkms.sh --install` then `for u in d330-auto-hibernate d330-swapfile lenovo-d330-camera-loopback ... (all 9); do systemctl is-enabled "$u"; done` → every line `enabled`.
2. **SC1 symmetry:** `sudo ./scripts/install_dkms.sh --uninstall` then `find /etc /usr/local/bin /usr/share/alsa \( -name '*d330*' -o -name 'lenovo-d330*' \)` → empty (note: `/etc/d330-hardware-state.json` must be gone).
3. **`--verify` both directions:** `sudo ./scripts/install_dkms.sh --verify` after install → all OK exit 0; after uninstall → drift/empty per manifest (record output).
4. **GRUB:** confirm `/boot/grub/grub.cfg` reflects the grub.d snippets after install and no longer after uninstall (or the honest WARN was logged).
5. **Rescue shell:** as non-root or in a shell without dkms installed, `./scripts/install_dkms.sh --uninstall` must run (not hard-fail on prerequisites).
Record verbatim outputs.

**Resume-signal:** Reply with the recorded results or "approved". Evidenced failures are acceptable resume data for the VERIFICATION override record.

## Next Phase Readiness

- Tasks 1-7 complete; all gates green. SC1/SC2 machine-checked off-hardware; real-device proof is the Task 8 UAT.
- Phase 36 (tray/tablet daemon wiring) and Phase 42 (CHANGES_AUDIT doc-parity) can proceed; the RPM `%preun` gap remains intentionally deferred.

---
*Phase: 35-installer-uninstaller-symmetry*
*Completed: 2026-10-08*
