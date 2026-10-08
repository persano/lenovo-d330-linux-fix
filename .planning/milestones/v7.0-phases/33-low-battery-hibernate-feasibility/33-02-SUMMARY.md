---
phase: 33-low-battery-hibernate-feasibility
plan: 02
subsystem: power
tags: [hibernate, swapfile, resume-activation, grub, systemd, packaging, guard-suite]

# Dependency graph
requires: [33-01]
provides:
  - "Idempotent d330-swapfile.service: exists-guarded dd/chmod 600/mkswap/swapon creation, 4096-8192 MiB clamp, free-space [WARN] guard, never recreates (R4)"
  - "53-lenovo-d330-resume.cfg template: placeholder-only resume=UUID/__D330_RESUME_UUID__ + resume_offset/__D330_RESUME_OFFSET__ line, no machine state in repo"
  - "install_dkms.sh: unit copy + both enable lines in enable block (before log_ok), post-enable resume-activation section (start-unit → fstab verify-before-append → R7 unit check → filefrag offset → blkid UUID → guarded snippet render → mkconfig ladder + grub.cfg grep-verify + update-initramfs → locked manual-step exit 1), uninstall symmetry (snippet rm, unit disable/rm, swapoff + fstab-line removal, /var/swapfile left on disk)"
  - "postinst + rpm %post both enable both units (SC3 x3 installer sites); no %preun invented (R8 gap → Phase 35)"
  - "test_hibernate_guards.sh extended 12 → 19 cases (enable-site ×3, unit/snippet static, activation-step, uninstall-symmetry), failed=0"
affects: [33-03, 35]

# Actuals (#2632) — same estimateTokens scale (chars/4 over realized diff)
actuals:
  tokens: 6000
  tasks: 3
  commits: 3

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "filefrag -v first-extent physical column parsed as field 4 with '..' stripped (empirically verified on e2fsprogs 1.47 output; RESEARCH Q1.4 tooling correction applied, show=OFFSET absent)"
    - "install-time template render: sed substitution of the two __D330_*__ tokens into /etc/default/grub.d only, content-compare before write (idempotent, core /etc/default/grub never touched)"
    - "fail-closed activation ladder: every failure link prints the exact resume=UUID=... resume_offset=... cmdline and exits non-zero, after enablement already landed (checker W1 ordering)"

key-files:
  created:
    - patches/power_hibernate/etc/systemd/system/d330-swapfile.service
    - patches/power_hibernate/etc/default/grub.d/53-lenovo-d330-resume.cfg
  modified:
    - scripts/install_dkms.sh
    - packaging/debian/postinst
    - packaging/rpm/lenovo-d330-fix.spec
    - scripts/test_hibernate_guards.sh

key-decisions:
  - "filefrag offset parse = awk 4th field + strip '..' (filefrag -v physical_offset column is rendered as 'start.. end:'; verified against real e2fsprogs output, not guessed from docs)"
  - "swapfile unit runs creation through one && chain with || { rm -f; WARN; exit 1; } — a partial dd/mkswap never leaves a half-written file that would block the next boot's creation attempt"
  - "swapfile start failure downgrades the whole activation section to a loud [WARN] + skip (install continues, daemon degrades honestly per 33-01); mkconfig/verify failure still hard-exits non-zero per the locked 'never silently inactive' rule"
  - "RPM spec stays enable-only: no %preun invented (R8 verified), uninstall-symmetry gap recorded for Phase 35 below"

requirements-completed: [SC1, SC3]

# Coverage metadata (#1602)
coverage:
  - id: C1
    description: "Disk-backed resume swap asset: d330-swapfile.service creates /var/swapfile only when absent (MemTotal clamp 4096-8192 MiB, df avail size+2048MiB guard with [WARN] + non-zero, dd conv=fsync, chmod 600, mkswap, swapon) and never rewrites an existing file"
    requirement: SC1
    verification:
      - kind: unit
        ref: "scripts/test_hibernate_guards.sh#swapfile-unit-static (dd count==1, existence guard, clamp, guard strings)"
        status: pass
      - kind: automated_ui
        ref: "task 1 verify block (ASSETS OK, rc=0)"
        status: pass
    human_judgment: false
  - id: C2
    description: "Resume cmdline activation: installer renders placeholder template → mkconfig ladder (update-grub → grub2-mkconfig → grub-mkconfig) → grep resume_offset= in generated grub.cfg → update-initramfs; any break prints the exact cmdline and exits non-zero"
    requirement: SC1
    verification:
      - kind: unit
        ref: "scripts/test_hibernate_guards.sh#installer-activation-step + #resume-snippet-template"
        status: pass
      - kind: automated_ui
        ref: "task 2 verify block (INSTALLER OK, rc=0); on-device round trip is 33-03"
        status: pass
    human_judgment: false
  - id: C3
    description: "Both units enabled by all three installers (install_dkms enable block before log_ok, postinst before update-initramfs, rpm %post), machine-checked by three enable-site cases"
    requirement: SC3
    verification:
      - kind: unit
        ref: "scripts/test_hibernate_guards.sh#enable-site-install-dkms / #enable-site-debian-postinst / #enable-site-rpm-spec"
        status: pass
      - kind: automated_ui
        ref: "task 3 verify block (PACKAGING + SUITE OK, rc=0)"
        status: pass
    human_judgment: false
  - id: C4
    description: "Uninstall symmetry for everything Phase 33 adds: snippet rm, unit disable --now + rm, swapoff + fstab-line removal (grep -v context, not append string), /var/swapfile intentionally left on disk with a comment; pre-existing daemon coverage untouched"
    requirement: SC3
    verification:
      - kind: unit
        ref: "scripts/test_hibernate_guards.sh#uninstall-symmetry (six coverage points)"
        status: pass
      - kind: automated_ui
        ref: "task 2 verify block"
        status: pass
    human_judgment: false

# Metrics
duration: 45min
completed: 2026-10-08
status: complete
deferred_commit: false
---

# Phase 33 Plan 02: Low-Battery Hibernate Feasibility (Wave 2) Summary

**Hibernate can now physically complete: idempotent disk-backed swapfile unit, install-time-rendered resume cmdline with mkconfig verify + locked manual-step fallback, both units enabled in all three installers, guard suite grown 12 → 19 cases, all gates green**

## Performance

- **Duration:** ~45 min
- **Completed:** 2026-10-08
- **Tasks:** 3 / 3
- **Files modified:** 4 modified, 2 created

## Accomplished

- **Task 1:** New `d330-swapfile.service` (Type=oneshot, inline `/bin/sh -c` following the `lenovo-d330-resume.service` form): existence guard `[ -e /var/swapfile ]` means an existing file is never touched (only re-activated via `/proc/swaps` check), creation path derives SIZE_MB from `MemTotal` clamped to 4096–8192, requires `df --output=avail` size + 2048 MiB margin else loud `[WARN]` + non-zero with nothing written, then `dd if=/dev/zero ... conv=fsync && chmod 600 && mkswap && swapon` with a `|| { rm -f; WARN; exit 1; }` cleanup so a partial file never blocks retry. Header comment explains why `resume_offset` forbids recreation (R4). New `53-lenovo-d330-resume.cfg` template: single append line with only `__D330_RESUME_UUID__` / `__D330_RESUME_OFFSET__` placeholders, zero machine state.
- **Task 2:** `install_dkms.sh` gains the unit copy beside the service copy, both `systemctl enable` lines inside the enable block before `log_ok`, and a clearly-marked post-enable resume-activation section in the plan's exact A/B/C order (checker W1: enablement precedes any step that may exit non-zero): (1) `systemctl start d330-swapfile.service` with rc captured, failure → `[WARN]` + skip all activation, install continues; (2) fstab append with Phase-32 verify-before-append and duplicate refusal, reported before writing; (3) `stat -f -c %S /` vs `getconf PAGESIZE` (R7) — mismatch forces the manual branch; (4) offset exclusively from `filefrag -v` first extent; (5) `blkid -s UUID -o value` on `findmnt -n -o SOURCE /` with rc captured; (6) guarded template render into `/etc/default/grub.d` only, content-compare idempotency, repo template never modified; (7) mkconfig ladder → grep `resume_offset=` in generated `grub.cfg` → `update-initramfs -u` → success line, any break prints the exact copy-pasteable `resume=UUID=... resume_offset=...` cmdline and `exit 1` (locked honesty); (8) uninstall symmetry: snippet rm in the grub.d list, unit disable + rm in their lists, `swapoff` + fstab-line removal via `grep -v` context, `/var/swapfile` deliberately left with a comment citing the RESEARCH §4 risk rationale.
- **Task 3:** `postinst` and rpm `%post` each gain both enable lines in the established idiom (SC3 now holds across all three installers); no `%preun` invented (R8). `test_hibernate_guards.sh` appends 7 static cases (19 total, header/usage counts updated): `enable-site-install-dkms` (also asserts enable-before-log_ok line order), `enable-site-debian-postinst` (enable-before-update-initramfs), `enable-site-rpm-spec` (inside `%post`, plus anti-regression that `%preun` stays absent), `swapfile-unit-static`, `resume-snippet-template`, `installer-activation-step` (positive greps only, `show=OFFSET` forbidden, manual-step `exit 1` present), `uninstall-symmetry` (six coverage points).

## Task Commits

Committed atomically via `gsd-tools query commit` (per-task):

1. **Task 1: New assets — idempotent swapfile unit + resume snippet template** — `23c0b1a` (feat) — verify printed `ASSETS OK`, rc=0
2. **Task 2: Installer — activation, cmdline render + mkconfig verify, enablement, uninstall symmetry** — `c381ce8` (feat) — verify printed `INSTALLER OK`, rc=0
3. **Task 3: Packaging enablement ×2 + static guard suite extension** — `dc546dc` (test) — verify printed `PACKAGING + SUITE OK`, rc=0

## Verify Raw Outputs

**Task 1** (`bash w33_02_t1.sh`): `ASSETS OK` / RC=0

**Task 2** (`bash w33_02_t2.sh`): `INSTALLER OK` / T2 RC=0

**Task 3** (`bash w33_02_t3.sh`): `PACKAGING + SUITE OK` / RC=0

**Full phase gate (final run, raw tail):**

```
=== FULL PHASE GATE ===
bash -n chain rc=0
py_compile rc=0
guards rc=0

==========================================================
 Guard suite summary: passed=19 failed=0
==========================================================
harness rc=0
[INFO] ModemManager FCC Unlock: patches/cellular_storage/etc/ModemManager/fcc-unlock.d/8086:7360
[INFO] Cellular Rules: patches/cellular_storage/etc/udev/rules.d/78-lenovo-d330-cellular.rules
[OK] dry-run verification complete
ExecStart/install-path grep: OK
execstart rc=0
auto_hibernate rc=0
[DRY-RUN] Logic verified successfully.
=== GATES DONE ===
```

**Hibernate suite tail (final run):**

```
  [OK] type-oneshot-kept
  [OK] udev-glob-comment
  [OK] daemon-syntax-gates
  [OK] enable-site-install-dkms
  [OK] enable-site-debian-postinst
  [OK] enable-site-rpm-spec
  [OK] swapfile-unit-static
  [OK] resume-snippet-template
  [OK] installer-activation-step
  [OK] uninstall-symmetry

==========================================================
 Guard suite summary: passed=19 failed=0
==========================================================
```

## Deviations from Plan

1. **[Rule 1/clarification] filefrag offset field chosen empirically, not from the plan's illustrative awk.** RESEARCH §2 shows `awk '/^ 0:/{print $NF; exit}'`; real e2fsprogs output (verified live on this box: `0: 0.. 1023: 133828608.. 133829631: 1024:`) makes `$NF` the flags/length column. The implementation takes field 4 and strips the `..` suffix, yielding the physical start — same value systemd computes (`hibernate-util.c:247-250`). Test contract unchanged (static greps only); on-device confirmation of the offset value belongs to 33-03.
2. **[clarification] `|| true` guards on filefrag/sed command substitutions inside the activation block** — the script runs under `set -euo pipefail`; without them a missing binary would kill the script before the locked manual-step message could print (correctness requirement of the fail-closed posture, Rule 2).
3. **[clarification] swapfile unit's existing-file branch exits with `swapon`'s rc** if re-activation fails, rather than unconditionally 0 — honest failure for the installer's step-1 rc capture. Creation side still uses the `|| { rm -f; WARN; exit 1; }` form.

No test contract was modified to make anything pass; all acceptance greps and verify blocks pass unmodified.

## Known Stubs

None. No hardcoded empty values, placeholder UI strings, or unwired components introduced.

## Threat Flags

None new — the plan's threat model (T-33-01..05) already covers every file touched: `chmod 600` + suite assertion (T-33-01), grub.d-only writes + grep-verify + manual-step exit (T-33-02), fail-closed sub-steps (T-33-04), clamp + free-space guard (T-33-05). No new network endpoints, auth paths, or schema changes.

## Open Items for Later Phases

- **RPM `%preun` gap (Phase 35):** the spec has no uninstall section at all today (R8 verified — the plan forbade inventing one). `packaging/rpm/lenovo-d330-fix.spec` therefore leaves both enable'd units and any rendered state behind on `rpm -e`. Phase 35 (installer/uninstaller symmetry) should add `%preun` covering: `systemctl disable --now` for all enabled units (including the two added here), unit file removal is handled by `%files` but the `/etc/fstab` swap line and the grub.d snippet are **not** shipped by the RPM (installer-only paths) — document that asymmetry there.
- **Estimate advisory:** plan estimate 118 000 tokens (confidence: low) vs actual ≈ 6 000 tokens (chars/4 over the 24 149-char diff). The **W-1 over-budget advisory is accepted and noted** as instructed: the low-confidence estimate was ~20× the realized diff; feed this into the calibration file rather than adjusting the plan.
- **On-device proof (33-03):** filefrag offset value, real `systemctl hibernate` rc, power-cycle resume round trip (R1 initramfs hook still UNVERIFIED), `systemctl is-enabled` ×2.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Plan 33-03 (on-device round trip) now has every static prerequisite: swapfile unit enabled + rendered cmdline verified in `grub.cfg` at install time.
- Phase 35 gets the RPM `%preun` gap above.
- No blockers.

---
*Phase: 33-low-battery-hibernate-feasibility*
*Completed: 2026-10-08*

## Self-Check: PASSED

All 7 key files found on disk; all 3 task commits (`23c0b1a`, `c381ce8`, `dc546dc`) present in `git log --oneline --all`.
