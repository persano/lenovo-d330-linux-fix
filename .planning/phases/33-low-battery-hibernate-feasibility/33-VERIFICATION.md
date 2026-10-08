---
phase: 33-low-battery-hibernate-feasibility
verified: 2026-10-08T12:33:14Z
status: human_needed
score: 11/17 must-haves verified
behavior_unverified: 2
overrides_applied: 0
---

# Phase 33: Low-Battery Hibernate Feasibility Verification Report

**Phase Goal:** Make the 5% emergency hibernate actually able to complete, or degrade safely instead of silently failing.
**Verified:** 2026-10-08T12:33:14Z
**Status:** human_needed
**Re-verification:** No — initial verification (no prior VERIFICATION.md existed)

## Verdict Per Roadmap Success Criterion

| SC | Criterion (ROADMAP.md:130-132) | Verdict | Evidence |
|----|-------------------------------|---------|----------|
| SC1 | `systemctl hibernate` on the target returns 0 with a resume device present | ⚠️ HUMAN (hardware-only) | Static prerequisites all present and machine-checked: swapfile unit `patches/power_hibernate/etc/systemd/system/d330-swapfile.service:13` (clamp 4096/8192, free-space guard, `$${NEED}`, idempotent `[ -e /var/swapfile ]`), resume activation fail-closed ladder `scripts/install_dkms.sh:404-444` (mkconfig → exact `grep -qF "resume=UUID=${ROOT_UUID}"` + `resume_offset=${RESUME_OFFSET}` at :421-422 → `exit 1` + manual cmdline at :436-443). The round trip itself cannot run here — 33-03-PLAN Task 2 (`checkpoint:human-verify gate="blocking-human"`, plan line 110) exists, untouched since planning (git log: last touch `3cd21ac`, pre-execution), all 7 steps extracted verbatim in 33-03-SUMMARY "## Deferred to UAT (Task 2, blocking-human)" lines 188-206. |
| SC2 | `d330-auto-hibernate --dry-run` reports the swap situation | ✓ VERIFIED (machine-checked locally; on-device run remains as UAT item 2) | Ran live: zram-only fixture → `[SWAP] path=/dev/zram0 type=zram size=3145724 used=0 priority=-2` / `hibernate readiness: NOT-READY (resume not configured)` / `[INFO] No battery power supply detected...` / `RC=0` — report prints before the battery gate (`tools/d330-auto-hibernate.py:162-169`). Suite case `no-battery-report-first` asserts report-before-gate ordering; `passed=21 failed=0`. |
| SC3 | service is `enabled` after `--install` | ✓ VERIFIED statically (on-device confirmation remains as UAT item 1) | `systemctl enable d330-auto-hibernate.service` present at `scripts/install_dkms.sh:296`, `packaging/debian/postinst:19`, `packaging/rpm/lenovo-d330-fix.spec:49` (plus `d330-swapfile.service` at :297/:20/:50). Suite cases `enable-site-install-dkms` / `enable-site-debian-postinst` / `enable-site-rpm-spec` all `[OK]`. Postinst/enable line executed only on a real install → UAT. |

**Score:** 11/17 must-haves verified (2 behavior-unverified, 4 hardware-pending)

## Goal Achievement

### Observable Truths

| # | Truth (plan must_haves) | Status | Evidence |
|---|------------------------|--------|----------|
| 33-01.1 | `--dry-run` prints full swap situation + readiness verdict before battery gate | ✓ VERIFIED | Fixture run above; `print_swap_report` called before `get_battery_info` (`tools/d330-auto-hibernate.py:162-166`); suite cases `zram-only-refuse`, `no-battery-report-first` |
| 33-01.2 | No non-zram swap → refuse hibernate, `[ERROR]` + suspend fallback, hibernate never invoked | ✓ VERIFIED (behavioral) | Verifier ran the real (non-dry-run) path with a recording `D330_SYSTEMCTL` stub + zram-only fixture: output `[ERROR] hibernate skipped: only zram swap present`, `DAEMON_RC=0`, invoked verbs = `suspend` only (hibernate absent). Code: `tools/d330-auto-hibernate.py:175-180` |
| 33-01.3 | Ready path invokes `systemctl hibernate` list-form with rc checked | ✓ VERIFIED (behavioral) | Suite case `rc-propagates` (ran `[OK]`): stub exits 7 → daemon rc non-zero + `[ERROR] systemctl hibernate failed (rc=7)`, verb `hibernate` recorded (`scripts/test_hibernate_guards.sh:447-470`); code `tools/d330-auto-hibernate.py:150-159` |
| 33-01.4 | Threshold policy untouched: 5%, discharging-only, legacy outputs | ✓ VERIFIED | `CRITICAL_THRESHOLD_PERCENT = 5` (daemon :12), discharging gate :173, `[OK] Battery level safe.` :186, `[INFO] No battery power supply detected` :168; suite `safe-battery-report` |
| 33-01.5 | ExecStart == install path, Type=oneshot kept w/ rationale, udev functional line byte-identical | ✓ VERIFIED | `d330-auto-hibernate.service:11-12` (`Type=oneshot`, `ExecStart=/usr/local/bin/d330-auto-hibernate`) == `install_dkms.sh:244` cp target; `git diff 7c62661^..7c62661` on the udev rules shows only added comment lines — the `SUBSYSTEM==...` functional line unchanged; rpm spec `:35-36` + debian rules `:11-12` mv+chmod the suffix-free name |
| 33-01.6 | Suite green (`failed=0`), harness `--dry-run` rc=0 | ✓ VERIFIED | See raw tails below |
| 33-02.1 | Idempotent swapfile unit: create-once, clamp 4096-8192, dd/chmod 600/mkswap, free-space guard, `$${NEED}` | ✓ VERIFIED | `d330-swapfile.service:13` read in full: `[ -e /var/swapfile ]` guard, `-lt 4096`/`-gt 8192` clamps, `NEED=$(( (SIZE_MB + 2048) * 1024 * 1024 ))` + `df --output=avail` compare with `[WARN]` + `exit 1`, `$${NEED}`/`$${AVAIL}` doubled (WR-01), `dd ... && chmod 600 && mkswap && swapon \|\| { rm -f; WARN; exit 1; }`; suite `swapfile-unit-static` |
| 33-02.2 | Resume activation fail-closed: render → mkconfig → exact-value grep-verify → manual cmdline + exit 1 | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Present + wired: render idempotency `install_dkms.sh:384-390`, mkconfig ladder :404-420, WR-02 exact greps :421-422, manual-step `exit 1` :436-443. No test executes the ladder (needs root+GRUB) — only static greps (`installer-activation-step`). See behavior_unverified_items #1 |
| 33-02.3 | Enable lines in all 3 installers (SC3) | ✓ VERIFIED | See SC3 row |
| 33-02.4 | Uninstall symmetry: daemon rm, both units disable/rm, snippet rm, swapoff, fstab line removal | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Lines present: daemon rm `install_dkms.sh:570`, disable :589/:591, swapoff :592, snippet rm :556 (+ IN-05 mkconfig re-run :553-555), fstab anchored `grep -qxF` guard + `grep -v -xF` + rc handling :596-608, unit rm :618/:620. Suite `uninstall-symmetry` greps all six points; IN-01 removal behavior was harness-proven in the fix worktree. The full uninstall flow never executes in any gate — REVIEW-FIX itself flags IN-05 "requires human verification". See behavior_unverified_items #2 |
| 33-02.5 | fstab verify-before-append + immediate activation | ✓ VERIFIED | `install_dkms.sh:313` (`systemctl start d330-swapfile.service`), :324-334 (exact-line grep, duplicate refusal, WR-03 trailing-newline guard :331-332); suite `installer-activation-step` |
| 33-02.6 | Extended suite green + harness rc=0 | ✓ VERIFIED | Raw tails below |
| 33-03.1 | README documents subsystem, suite-anchored | ✓ VERIFIED | `patches/power_hibernate/README.md` 167 lines, all 8 anchor tokens present (33 matching lines); suite case `readme-docs-anchors` `[OK]` |
| 33-03.2 | On-device: `is-enabled` → enabled (SC3) | ⚠️ HARDWARE-PENDING | UAT item 1 |
| 33-03.3 | On-device: `--dry-run` from real `/proc/swaps` (SC2) | ⚠️ HARDWARE-PENDING | UAT item 2 |
| 33-03.4 | On-device: hibernate round trip survives power cycle (SC1) | ⚠️ HARDWARE-PENDING | UAT item 5 — the only proof of SC1 |
| 33-03.5 | R1 initramfs evidence collected on tablet | ⚠️ HARDWARE-PENDING | UAT item 4 |

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- |--------|---------|
| `tools/d330-auto-hibernate.py` | env seams, parser, verdict, refuse-and-degrade, rc-checked hibernate | ✓ VERIFIED | 194 lines; seams :16-22, `readiness()` :126-137 feeds both verdict and refusal (one source of truth); no `shell=True`/`os.system` anywhere in this file |
| `patches/.../d330-auto-hibernate.service` | ExecStart fixed, oneshot kept + rationale | ✓ VERIFIED | read in full, lines 6-12 |
| `patches/.../d330-swapfile.service` | new idempotent oneshot unit | ✓ VERIFIED | read in full |
| `patches/.../53-lenovo-d330-resume.cfg` | placeholder-only template | ✓ VERIFIED | grep shows only `__D330_RESUME_UUID__`/`__D330_RESUME_OFFSET__` tokens; no machine state |
| `patches/.../99-lenovo-d330-battery-critical.rules` | comment only, functional line byte-identical | ✓ VERIFIED | `git diff` = comment-only |
| `patches/power_hibernate/README.md` | subsystem docs + anchors | ✓ VERIFIED | 167 lines; docs-anchor case green |
| `scripts/install_dkms.sh` | activation, enable ×2, uninstall symmetry | ✓ VERIFIED | lines cited above; `bash -n` green |
| `packaging/debian/postinst`, `packaging/rpm/...spec`, `packaging/debian/rules` | enable lines + suffix-free mv/chmod | ✓ VERIFIED | greps above |
| `scripts/test_hibernate_guards.sh` | fixture + static suite | ✓ VERIFIED | 525 lines, 21 cases, ran green |
| `scripts/test_storage_cellular.sh` | delegates new suite, rc=0 | ✓ VERIFIED | ran green, RC=0 |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------- | ------- |
| dry-run verdict | refusal decision | same `readiness()` call on same parse | ✓ WIRED | `tools/d330-auto-hibernate.py:163` (one call feeds `print_swap_report` and the :175 branch) |
| suite fixtures | daemon end-to-end | `D330_*` env seams | ✓ WIRED | `scripts/test_hibernate_guards.sh:98-103` runs the real script, no root/battery/systemd |
| service ExecStart | install target | literal equality | ✓ WIRED | asserted by `execstart-matches-install-path` case (:230-253) against service, installer, rpm spec, deb rules |
| enable sites ×3 | suite static guards | one case per installer | ✓ WIRED | cases at suite :295-330 region, all ran `[OK]` |
| installer offset | grub.d render → mkconfig → grep | closed fail-closed loop | ✓ WIRED (static) | `install_dkms.sh:379-443`, any break → `exit 1` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| -------- | ------------- | ------ | ------------------ | ------ |
| swap report + verdict | `entries` | `D330_PROC_SWAPS` (default real `/proc/swaps`) | yes — fixture run produced real rows | ✓ FLOWING |
| battery gate | `cap`/`status` | sysfs power_supply (seamed) | yes — fixture 3% Discharging drove the critical branch in verifier's real-mode run | ✓ FLOWING |
| resume activation | `ROOT_UUID`/`RESUME_OFFSET` | `blkid` / `filefrag -v` at install time | yes — computed at install, not hardcoded | ✓ FLOWING (static trace) |
| swapfile unit size | `SIZE_MB` | `/proc/meminfo` MemTotal | yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| SC2 dry-run zram fixture | `D330_PROC_SWAPS=<fixture> python3 tools/d330-auto-hibernate.py --dry-run` | swap row + `NOT-READY (resume not configured)` + INFO, RC=0 | ✓ PASS |
| Real-mode refusal never invokes hibernate | non-dry-run, zram-only, battery 3% Discharging, recording `D330_SYSTEMCTL` stub | `[ERROR] hibernate skipped: only zram swap present`, `DAEMON_RC=0`, verbs invoked: `suspend` only | ✓ PASS |
| Guard suite | `bash scripts/test_hibernate_guards.sh` | `passed=21 failed=0` | ✓ PASS |
| Harness gate | `bash scripts/test_storage_cellular.sh --dry-run` | `RC=0`, both delegated suites green | ✓ PASS |
| Honest-success check (item 7) | read of daemon + runs above | daemon prints no success message on the hibernate path; `[CRITICAL]` is followed either by real `run_power_action("hibernate")` (rc checked, `[ERROR]` on failure) or by `[ERROR] hibernate skipped` — never success without invocation. `--dry-run` reports per-swap rows + verdict per requirement | ✓ PASS |
| py_compile | `python3 -m py_compile tools/d330-auto-hibernate.py` (via suite `daemon-syntax-gates`) | `[OK]` | ✓ PASS |

### Probe Execution

No phase-declared `probe-*.sh` for Phase 33 — not applicable (guard suites are the declared gate and were executed above).

### Requirements Coverage

No `REQUIREMENTS.md` IDs for this phase (`phase_req_ids: null`); the roadmap SCs are the work contract.

| Requirement | Source | Description | Status | Evidence |
| ----------- | ------ | ----------- | ------ | -------- |
| SC1 | ROADMAP.md:130 | hibernate returns 0 with resume device on target | ? NEEDS HUMAN | static prerequisites verified; round trip is UAT item 5 |
| SC2 | ROADMAP.md:131 | `--dry-run` reports swap situation | ✓ SATISFIED | live fixture run + suite |
| SC3 | ROADMAP.md:132 | service enabled after `--install` | ? NEEDS HUMAN (static half ✓) | 3 enable sites machine-checked; runtime confirmation UAT item 1 |
| ORPHANED | — | none | — | no other requirements map to Phase 33 |

### Decision Coverage

`gsd-tools query check.decision-coverage-verify` → `skipped: true, reason: "no trackable decisions"` (33-CONTEXT decisions were translated into plan must_haves at planning time; gate non-blocking).

### Test Quality Audit

| Test File | Linked Req | Active | Skipped | Circular | Assertion Level | Verdict |
|-----------|-----------|--------|---------|----------|-----------------|---------|
| `scripts/test_hibernate_guards.sh` | SC1-SC3 | 21 | 0 | no (fixtures authored independently, daemon under test) | Value + behavioral (exact marker strings, `expect_no_out`, ordering assertion, real-mode rc case) | ✓ |

**Disabled tests on requirements:** 0 → no blocker. **Circular patterns:** 0. **Insufficient assertions:** 0.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `patches/power_hibernate/README.md` | — | SUMMARY says "171-line", file is 167 lines | ℹ️ Info | cosmetic count drift in SUMMARY prose; all 8 anchors present, suite case green |
| `scripts/build_live_iso.sh` | — | copies `tools/d330-*` without suffix-free rename (same class as CR-01, outside phase file list) | ⚠️ Warning | recorded in 33-REVIEW-FIX.md:144-146 for Phase 35; not part of this phase's contract |

No `TBD`/`FIXME`/`XXX`/`TODO` debt markers in any phase-touched file. No stubs, no `return null`/empty handlers, no hardcoded empty data. `shell=True` occurrences exist only in pre-existing `tools/d330-tablet-daemon.py` and `tools/d330-tray.py` — untouched by this phase; the phase's daemon uses list-form subprocess exclusively.

### Review Fixes Landed (spot-check)

All 9 commits `9f6b2b3`..`6620482` present in `git log`. Spot-checks:
- **WR-02 (exact-value greps):** `scripts/install_dkms.sh:421-422` — `grep -qF "resume=UUID=${ROOT_UUID}"` AND `grep -qF "resume_offset=${RESUME_OFFSET}"` both required before `ACTIVATION_OK=true` ✓
- **IN-04 (rc seam):** `tools/d330-auto-hibernate.py:22` `D330_SYSTEMCTL` seam, :154 used as binary; suite case `rc-propagates` (:451) runs non-dry-run against 7-exit stub — ran `[OK]` ✓

### Human Verification Required (UAT — on the D330 tablet)

Precondition for items 1-7: fresh `scripts/install_dkms.sh --install` (or deb/rpm package) on the tablet, root r/w, battery >20%.

1. **SC3 — enablement.** Run: `systemctl is-enabled d330-auto-hibernate.service` and `systemctl is-enabled d330-swapfile.service`. Expected: both print `enabled`.
2. **SC2 — honest report (on-device).** Run: `d330-auto-hibernate --dry-run`. Expected: swap table (zram row + `/var/swapfile` row) and `hibernate readiness: READY`; if `NOT-READY`, record the exact reason (honest result, not failure).
3. **Resume plumbing.** Run: `grep resume_offset= /boot/grub/grub.cfg`; `cat /proc/cmdline`; `cat /sys/power/resume`; `swapon --show`. Expected: parameter present, cmdline has `resume=`+`resume_offset=`, resume not `0:0`, `/var/swapfile` active.
4. **R1 evidence (top research risk).** Run the probe set: `grep mmc /lib/modules/$(uname -r)/modules.builtin`, `lsinitramfs /boot/initrd.img-* | grep resume`, `grep -r RESUME_OFFSET /usr/share/initramfs-tools /etc/initramfs-tools`, `stat -f -c %S /` vs `getconf PAGESIZE`, `bootctl status`/`efibootmgr -v`, `cat /sys/kernel/security/lockdown`, `grep -w disk /sys/power/state`. Expected: record verbatim — if swap-file resume unsupported, the evidence-gated-fallback record gets written instead of a success claim.
5. **SC1 — the round trip (the only proof).** Open unsaved work, run `systemctl hibernate`. Expected: rc=0, device powers off, power-on restores the session exactly. rc alone only proves the image was written.
6. **Refusal on device (audit C3 regression).** `swapoff /var/swapfile`, then `d330-auto-hibernate --dry-run`. Expected: `NOT-READY` + `[ERROR]` refusal reason; restore with `swapon /var/swapfile`.
7. **Negative environment.** If lockdown active or `disk` absent from `/sys/power/state`, record hibernate unavailable and confirm the daemon degrades loudly instead of claiming success.
8. **WR-02 on a real install** (review-flagged "requires human verification"): a stale grub.cfg (old UUID/offset) must fail the verify step into the manual-step branch with `exit 1`.
9. **IN-05 on a real uninstall** (review-flagged "requires human verification"): removing the resume snippet must re-run the mkconfig ladder (`update-grub`/`grub2-mkconfig`/`grub-mkconfig`) with honest log lines, or `[WARN]` when no tool exists.
10. **Installer activation ladder end-to-end** (behavior-unverified #1): on install, confirm render → mkconfig → exact-value grep actually succeeds (success line) — or on a non-GRUB host, confirm the exact `resume=UUID=... resume_offset=...` manual cmdline prints and the installer exits non-zero.

### behavior_unverified_items

1. **33-02.2 (activation fail-closed ladder).** Test: UAT items 8 + 10. Expected: verify failure → exact manual cmdline printed + `exit 1`; success path greps exact rendered UUID/offset. Why human: needs root + GRUB; no gate executes the installer.
2. **33-02.4 (uninstall execution incl. IN-05 mkconfig re-run).** Test: UAT item 9. Expected: snippet removed → mkconfig ladder re-runs or loud `[WARN]`; fstab line removed; units disabled/removed; swapoff run. Why human: full uninstall flow never runs in any gate (static greps only).

### Gaps Summary

No gaps: every locally-verifiable must-have passed with code/command evidence (11 VERIFIED, 2 behavior-present awaiting the human install/uninstall exercises above, 4 hardware-pending). The phase goal's headline claim (SC1) is by design provable only on the tablet — plan Task 2 was correctly left blocking-human and never auto-approved, and the seven acceptance steps are extracted verbatim for UAT. No broken promise found: every SUMMARY claim checked against the codebase held (the only drift is a cosmetic 171 vs 167 line count in 33-03-SUMMARY prose).

---

_Verified: 2026-10-08T12:33:14Z_
_Verifier: the agent (gsd-verifier)_
