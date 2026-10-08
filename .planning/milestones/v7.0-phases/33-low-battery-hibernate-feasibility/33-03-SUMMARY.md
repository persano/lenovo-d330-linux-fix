---
phase: 33-low-battery-hibernate-feasibility
plan: 03
subsystem: power
tags: [hibernate, documentation, readme, guard-suite, docs-anchors, uat-deferred, on-device]

# Dependency graph
requires: [33-01, 33-02]
provides:
  - "README.md rewritten as the subsystem's single source of truth: 5% refuse-and-degrade path, swapfile lifecycle (create-once, why recreation invalidates resume_offset), filefrag activation chain, Secure Boot/lockdown + unencrypted-image disclosures, R1 probe commands, three enablement sites, uninstall behavior, local + on-device verification"
  - "test_hibernate_guards.sh grown 19 → 20 cases: readme-docs-anchors greps the README for all eight mandatory anchor tokens (header/usage counts updated)"
  - "Full local gate green across all three plans' touched files (bash -n x2, py_compile, guards failed=0, harness --dry-run, ExecStart grep)"
  - "Task 2 on-device SC1/SC2/SC3 acceptance sequence extracted verbatim under 'Deferred to UAT (Task 2, blocking-human)' — hardware-only, never executed here"
affects: [34, 35, UAT, verification]

# Actuals (#2632) — same estimateTokens scale (chars/4 over realized diff)
actuals:
  tokens: 3300
  tasks: 1
  commits: 2

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "docs-anchor suite case: acceptance-criteria anchor tokens grepped from README into the shared CASE_FAIL counter, so docs cannot drift from shipped filenames unasserted"
    - "README-as-contract: every claim names shipped artifacts (unit files, installed daemon name, installer flow) and the suite pins the critical tokens"

key-files:
  created: []
  modified:
    - patches/power_hibernate/README.md
    - scripts/test_hibernate_guards.sh

key-decisions:
  - "README documents Secure Boot/lockdown degradation as an owner decision, never as an instruction to weaken security (R3 posture; VALIDATION security domain)"
  - "R1 probe commands and the 'round trip is the ONLY proof' rule are embedded verbatim in the README's Known Limits so the unverified initramfs swap-file resume cannot be forgotten later"
  - "requirements-completed left empty: SC1/SC2/SC3 on-device proof is Task 2, deferred to UAT — marking them complete now would claim unproven success (threat T-33-04, audit C3 pattern)"

requirements-completed: []

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "Subsystem README (single source of truth) + readme-docs-anchors suite case pinning its eight mandatory tokens; suite now 20 cases"
    verification:
      - kind: unit
        ref: "scripts/test_hibernate_guards.sh#readme-docs-anchors (passed=20 failed=0)"
        status: pass
      - kind: automated_ui
        ref: "task 1 verify block (DOCS OK, rc=0) + plan verification gate (all 5 gates rc=0)"
        status: pass
    human_judgment: false
  - id: D2
    description: "On-device acceptance for SC1 (hibernate → power-cycle → resume round trip), SC2 (real /proc/swaps dry-run report), SC3 (is-enabled after fresh install) plus R1 initramfs evidence collection"
    verification: []
    human_judgment: true
    rationale: "Requires the physical D330 tablet: power cycle, real hibernate, bootloader/lockdown/initramfs probes. No automation can prove a resume that survives power-off (RESEARCH R1); plan Task 2 is gate=blocking-human, autonomous: false, deferred-to-UAT."

# Metrics
duration: 20min
completed: 2026-10-08
status: complete
deferred_commit: false
---

# Phase 33 Plan 03: Low-Battery Hibernate Feasibility (Wave 3) Summary

**README rewritten as the shipped subsystem's single source of truth with an eight-token docs-anchor suite case (suite 19 → 20, all gates green); the on-device SC1/SC2/SC3 round trip + R1 evidence steps deferred verbatim to UAT, never executed here**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-10-08T10:30:49Z
- **Completed:** 2026-10-08T10:50Z
- **Tasks:** 1 / 2 (Task 2 is a `checkpoint:human-verify gate="blocking-human"` deferred to UAT by design)
- **Files modified:** 2

## Accomplished

- **Task 1 — Subsystem README rewrite + docs-anchor suite case:** `patches/power_hibernate/README.md` grew from a 8-line stub to a 171-line subsystem reference covering every mandatory fact: the unchanged 5% discharging threshold and the refuse-and-degrade path (`[ERROR] hibernate skipped: <reason>` → suspend fallback, four refusal reasons, `[DRY-RUN]` honest report); the resume swap lifecycle (root eMMC only, MemTotal clamp 4096–8192 MiB, `df` free-space `[WARN]` skip, `dd`/`chmod 600`/`mkswap`, fstab entry, and why the file must never be recreated — it would move the header and invalidate the boot-time `resume_offset`); the activation chain (`filefrag -v` offset → template render of `53-lenovo-d330-resume.cfg` → mkconfig ladder → grep-verify of `grub.cfg` → `update-initramfs -u`, with the no-GRUB manual-step path printing the exact cmdline and exiting non-zero); known limits (Secure Boot + kernel lockdown degradation presented as owner decision only, the **unencrypted** post-hibernate memory image disclosure, R1's UNVERIFIED initramfs swap-file resume with the three probe commands verbatim); all three enablement sites; uninstall behavior (units + snippet + fstab line removed, file left); and local + on-device verification commands. The installed daemon is named as the service ExecStart target (`/usr/local/bin/d330-auto-hibernate`, no `.py`) and the README never promises hibernate works when activation was skipped.
- **Suite case appended:** `case_readme_docs_anchors` greps the README for all eight acceptance anchors (`d330-swapfile.service`, `53-lenovo-d330-resume.cfg`, `resume_offset`, `filefrag`, `initramfs`, `Secure Boot`, `unencrypted`, `d330-auto-hibernate.service`) through the existing `expect_file_out` helper and shared counters; header list and usage text updated 19 → 20 cases. No production code changed.
- **Task 2 — NOT executed** (see Deferred section below): the on-device acceptance sequence is hardware-only; per plan (`autonomous: false`, `gate="blocking-human"`) and orchestrator instruction it was extracted into this SUMMARY verbatim for later UAT conversion.

## Task Commits

Committed atomically via `gsd-tools query commit` (per-task):

1. **Task 1: Subsystem README rewrite + docs-anchor suite case** — `586c0d1` (docs) — verify printed `DOCS OK`, rc=0
2. **Task 2: On-device acceptance** — no commit (hardware-only; produces evidence, not code)

**Plan metadata:** `docs(33): wave 3 summary` (this file + STATE/ROADMAP updates)

## Verify Raw Outputs

**Task 1 verify** (`bash w33_03_t1_verify.sh`, the plan's `<automated>` block verbatim): `DOCS OK` / rc=0

**Plan-level verification gate (raw tail of final run, all five gates):**

```
### GATE 1: bash -n x2
rc(bash -n hibernate)=0
rc(bash -n storage)=0
### GATE 2: py_compile
rc(py_compile)=0
### GATE 3: hibernate guards suite
==========================================================
 Lenovo D330 Hibernate Guard Suite (env-seam fixtures)    
==========================================================
  [OK] zram-only-refuse
  [OK] swapfile-ready-proceed
  [OK] safe-battery-report
  [OK] resume-not-configured
  [OK] hibernation-unavailable
  [OK] empty-swaps-refuse
  [OK] malformed-swaps-tolerated
  [OK] no-battery-report-first
  [OK] execstart-matches-install-path
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
  [OK] readme-docs-anchors

==========================================================
 Guard suite summary: passed=20 failed=0
==========================================================
rc(suite)=0
### GATE 4: harness dry-run (tail)
rc(harness)=0
  [OK] swapfile-unit-static
  [OK] resume-snippet-template
  [OK] installer-activation-step
  [OK] uninstall-symmetry
  [OK] readme-docs-anchors

==========================================================
 Guard suite summary: passed=20 failed=0
==========================================================
[INFO] ModemManager FCC Unlock: patches/cellular_storage/etc/ModemManager/fcc-unlock.d/8086:7360
[INFO] Cellular Rules: patches/cellular_storage/etc/udev/rules.d/78-lenovo-d330-cellular.rules
[OK] dry-run verification complete
### GATE 5: ExecStart grep consistency
rc(execstart)=0
```

Plan `<verification>` block: all five gates rc=0; suite `failed=0` with `[OK] readme-docs-anchors`; suite total **20** cases.

## Deviations from Plan

### Auto-fixed Issues

None — no Rule 1/2/3 fixes were needed; Task 1's acceptance criteria passed on the first verify run.

### Deliberate non-actions

1. **[requirements] SC1/SC2/SC3 not marked complete.** The plan frontmatter carries `requirements: [SC1, SC2, SC3]`, but all three are proven only on the tablet (Task 2). `requirements mark-complete` was intentionally skipped — marking them now would claim unproven success (threat T-33-04, the exact audit-C3 pattern this phase exists to fix). They close when the UAT items below record on-device results.
2. **[Task 2] Checkpoint not executed, not auto-approved.** `gate="blocking-human"` + hardware-only; the seven-step sequence is preserved verbatim in the Deferred section below.

---

**Total deviations:** 0 auto-fixed; 2 deliberate non-actions (both documented above).
**Impact on plan:** none — the plan's `<verification>` gate and `<success_criteria>` local clause are fully green.

## Issues Encountered

- **Shell environment quirks (tooling, not plan):** (a) `node` is not on the WSL/bash PATH — the shim runs as `node.exe` via Windows interop (`/mnt/c/Program Files/nodejs/node.exe`); (b) the Bash tool's outer PowerShell layer expands `$var`/`$?` inside command strings before bash sees them — all script logic was therefore executed from temp `.sh` files per orchestrator guidance, with no inline multiline bash; (c) `.planning` is a symlink → `.gsd` (pre-existing since Oct 7), so `git status` shows the whole `.planning/` tree as unstaged deletions with `.gsd/` untracked — pre-existing state, untouched, and commits stage only explicit `--files` paths (added through the symlink as `.planning/phases/...`, same as waves 1–2).
- The harness's line-omission notice ("2 FAIL") was a false alarm: it matched the two `failed=0` summary lines case-insensitively; the raw gate file contains zero FAIL lines.

## Known Stubs

None. No hardcoded empty values, placeholder text, or unwired components introduced.

## Threat Flags

None new — Task 1 only documents existing surface; the plan's threat register (T-33-01..05) already covers every claim written (unencrypted-image disclosure = T-33-01 mitigation, README-as-operator-trust = trust boundary "documentation → operator trust"). No new network endpoints, auth paths, or schema changes.

## Deferred to UAT (Task 2, blocking-human)

> Verbatim from `33-03-PLAN.md` Task 2 — **not executed, not approved.** Extracted here so the main agent can turn these into UAT items (Phase 32 VERIFICATION-override precedent). Resume signal: recorded results (paste of the seven steps, especially the round-trip outcome), or "approved" if all steps pass. Failures pasted with evidence are an acceptable resume — they feed the R1 fallback record.

**Task 2: On-device acceptance — SC1/SC2/SC3 round trip + R1 evidence (deferred-to-UAT)**

**what-built:** Complete Phase 33 stack on the target D330: daemon refuse-and-degrade + swap report (33-01), disk-backed resume swap with verified `resume=UUID=... resume_offset=...` activation and all three installers enabling both units (33-02), documented subsystem (Task 1). Local machine checks are all green; what remains is provable only on the tablet.

**precondition:** Phase 33 assets are installed on the D330 via a fresh `scripts/install_dkms.sh --install` run (or the deb/rpm package) with the root filesystem mounted read-write and the device charged above 20% for the hibernate test.

**how-to-verify:** Run on the D330 target, in order, recording each result into the phase record (SUMMARY/UAT; VERIFICATION.md overrides, if any, are applied later by the verification workflow):

1. **SC3 — enablement:** `systemctl is-enabled d330-auto-hibernate.service` → expect `enabled`; `systemctl is-enabled d330-swapfile.service` → expect `enabled`.
2. **SC2 — honest report:** `d330-auto-hibernate --dry-run` → expect the swap table (zram row plus `/var/swapfile` row) and `hibernate readiness: READY`. If it prints `NOT-READY`, record the exact reason — that is an honest result, not a test failure.
3. **Resume plumbing:** `grep resume_offset= /boot/grub/grub.cfg` finds the parameter; `cat /proc/cmdline` contains `resume=` and `resume_offset=`; after boot `/sys/power/resume` is not `0:0`; `swapon --show` lists `/var/swapfile`.
4. **R1 evidence (research's top risk):** `grep mmc /lib/modules/$(uname -r)/modules.builtin` (is the eMMC driver builtin?), `lsinitramfs /boot/initrd.img-* | grep resume`, `grep -r RESUME_OFFSET /usr/share/initramfs-tools /etc/initramfs-tools 2>/dev/null`, plus `stat -f -c %S /` vs `getconf PAGESIZE`, `bootctl status`/`efibootmgr -v` (bootloader identity), `cat /sys/kernel/security/lockdown`, `grep -w disk /sys/power/state`.
5. **SC1 — the round trip:** open unsaved work, run `systemctl hibernate` → expect rc=0, device powers off; press power → expect the session restored exactly (kernel resumes from the swapfile). This is the ONLY proof of SC1 — the systemctl return code alone only proves the image was written (RESEARCH R1).
6. **Refusal on device (audit C3 regression):** with `/var/swapfile` swapoff'ed (temporarily), `d330-auto-hibernate --dry-run` must show `NOT-READY` + the `[ERROR]` refusal reason; `swapon /var/swapfile` afterwards to restore.
7. **Negative environment:** if lockdown is active or `disk` is absent from `/sys/power/state`, record that hibernate is unavailable on that install and confirm the daemon degrades loudly instead of claiming success (R3 behavior check).

Expected outcomes: steps 1-3 and 6 green; step 5 green closes SC1; step 4 is evidence — if the initramfs hook lacks swap-file resume support, record the probe outputs verbatim so the locked evidence-gated-fallback record can be written instead of claiming success.

**resume-signal:** Reply with the recorded results (paste of the seven steps, especially the round-trip outcome), or "approved" if all steps pass. Failures pasted with evidence are an acceptable resume — they feed the R1 fallback record.

## User Setup Required

None — no external service configuration required. (The D330 tablet itself is the pending verification surface, captured above.)

## Next Phase Readiness

- Phase 33's local posture is fully green: daemon + swapfile/activation/packaging + documentation, suite 20/0.
- UAT conversion: the seven steps above become `/gsd-verify-work 33` items (SC1/SC2/SC3 + R1 evidence); Phase 32's `32-VERIFICATION.md` / `32-UAT.md` are the recording precedent.
- Blockers: none local. Phase sign-off remains gated on Task 2's recorded on-device results (plan `<verification>` clause).

---
*Phase: 33-low-battery-hibernate-feasibility*
*Completed: 2026-10-08*

## Self-Check: PASSED

All three key files found on disk (`patches/power_hibernate/README.md`, `scripts/test_hibernate_guards.sh`, `33-03-SUMMARY.md`); Task 1 commit `586c0d1` and docs commit `c7799d9` present in `git log --oneline --all`; mirror-sync commit `401cfbe` restores the legacy `.gsd/` tracked mirrors.
