# Phase 43: Guardrails, Ledger & Safe Recovery Baseline - Research

**Researched:** 2026-10-12
**Domain:** Bash guard-harness engineering (ledger gate, kit checksums), systemd system-sleep recovery hook hardening, deploy-manifest symmetry, deb/rpm/Arch packaging
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Ledger + Machine Gate**
- Consolidate the 22 disproven levers from `docs/research/DISPLAY_RESUME_CCS_MODIFIER.md`, `DSI_RESUME_TRACE_ANALYSIS.md` and `COMMUNITY_FINDINGS.md` into one `RESUME_FIX_LEDGER.md` with per-lever evidence links.
- `test_pitfalls_ledger.sh` scans `.planning/phases/*/*.md` (plans, summaries) plus `docs/research/*.md` for banned-lever mentions in fix-proposal context.
- The ledger carries a canonical lever name + alias regex table per lever; the test parses the table and matches text — keywords live in the ledger, not the test.
- Wire the new test into the existing 36-script harness (`test_storage_cellular.sh` + `bash -n` loop) per house pattern.

**Safety Kit + Capture Protocol**
- Repo-side automation now (prep/checksum scripts + protocol doc + runbook); golden `i915.ko.zst`, live USB and VBT/GOP dump are on-device runbook steps executed at deployment (repo has no hardware access).
- Protocol doc at `docs/research/RESUME_CAPTURE_PROTOCOL.md`: black-resume vs working-reload, no cold-boot control, `systemd-inhibit`, full ≥18 s window, journald + captures.
- Live USB reuses the `scripts/build_live_iso.sh` harness; runbook step = build + dd + verify against manifest checksums.
- Kit integrity: SHA-256 per artifact + one `MANIFEST.sha256`, verified by a new test script; scripts idempotent (safe re-run).

**Recovery Hardening**
- Harden the existing `patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh` hook (already DMI-gated, timeout-bounded, state-file disable) — no new service unit.
- One bounded attempt (existing `timeout 30`), explicit failure logging, no retry loop (a retry can wedge the GPU mid-resume).
- Keep the display-manager restart; the live Wayland session cannot survive the GPU teardown, so logging back in is the accepted bar.
- DMI gate stays exact `product_name == "82H0"` (10IGL test device only); 10IGM (81H3/81MD) is out of scope.

**Packaging, Manifest, Disable & Coexistence**
- Keep `/etc/default/lenovo-d330-display-resume` (`D330_DISPLAY_RESUME=0`) as the state file and add it to `deploy_manifest()` so `--verify` and uninstall treat it as a state-class entry.
- The recovery ships through `install_dkms.sh` + all three packagers (`packaging/debian/rules`, `packaging/arch/PKGBUILD`, `packaging/rpm/lenovo-d330-fix.spec`) + the CI `.deb`; packagers mirror the installer's manifest set.
- Non-fighting contract: the hook stands down when the real fix (Phase 45) writes a marker (e.g. `D330_REAL_FIX=1`) into the same state file; the contract is documented now, Phase 45 sets it.
- Extend `test_installer_symmetry.sh` fixtures + packager-parity tests to assert hook + state file install/uninstall/verify symmetry.

### the agent's Discretion
- Ledger table format and gate matching mechanics (keywords live in the ledger per the locked decision; format details are open).
- New guard-suite case breakdown (which suite owns which case).
- Safety-kit script names, kit directory layout, runbook structure.
- Hook hardening specifics (log message wording, exact stand-down check shape).

### Deferred Ideas (OUT OF SCOPE)
- None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GUARD-01 | 22 on-device disproven levers + community/upstream dead ends consolidated into one binding ledger | All lever source material verified in the three research docs (verbatim quotes below); candidate 22-row scaffold provided; ledger table format proposed |
| GUARD-02 | Machine-checkable test fails if a phase plan or the repo re-proposes a banned lever as a fix | House guard-suite pattern (test_display_fix_guards.sh), ledger-parses-table + fixture-probe case design, `planner-discipline-allow` marker convention, allowlist scope design |
| GUARD-03 | Safe on-device test protocol + off-device golden `i915.ko`/live-USB staged before kernel experiments | Capture-protocol inputs all verified (≥18 s window, `systemd-inhibit`, no-cold-boot rationale); kit = prep/checksum script + `MANIFEST.sha256` + tamper-detection guard; `sha256sum -c` house precedent |
| RECOV-01 | After resume on 82H0 display auto-restored (DMI-gated, time-bounded unbind/bind + DM restart) | Hook already implements the mechanism (verified line-by-line); hardening = explicit failure logging + REAL_FIX stand-down; hook-case guard design |
| RECOV-02 | Ships through installer + all three packagers + CI .deb, manifest-symmetric | Installer side COMPLETE (manifest :118, install :442-444, uninstall :867); gap verified in all 3 packagers + CI .deb (no system-sleep hooks shipped); exact edit sites listed |
| RECOV-03 | Idempotent, disable-able via manifest-tracked state file, does not fight the real fix | `state` manifest kind semantics verified (SKIP-when-absent :1159-1166); state file currently absent from manifest (gap); `D330_REAL_FIX=1` stand-down check + fixture test design |
</phase_requirements>

## Summary

Phase 43 is a **pure repo-side bash/packaging phase**: every deliverable is authored in `scripts/`, `docs/research/`, `packaging/`, and `.github/workflows/`, and all machine validation runs through the existing 36-script local harness. The recovery hook that satisfies RECOV-01 already exists and works — `patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh` has the `82H0` DMI gate, `timeout 30` bound, unbind/bind loop, display-manager restart, and the `D330_DISPLAY_RESUME=0` disable file. The installer already ships and uninstalls it (manifest `exec` entry, install copy, uninstall rm). The verified gaps are exactly: (1) no ledger, (2) no machine gate, (3) no safety-kit automation/protocol doc, (4) **no packager ships any system-sleep hook** (all three + the CI `.deb` ship a subset that excludes `patches/*/etc/systemd/system-sleep/`), and (5) the state file `/etc/default/lenovo-d330-display-resume` is not in `deploy_manifest()`, so `--verify`/uninstall do not manage it.

The riskiest deliverable is the ledger gate (GUARD-02): the scan targets (`.planning/phases/*/*.md`, `docs/research/*.md`) legitimately *contain* banned-lever mentions in the ledger itself, the three source docs, and phase CONTEXT/RESEARCH docs — so the gate needs a precise scope + allowlist mechanism or it fails vacuously or false-positives. The repo already has the house convention for this: `<!-- planner-discipline-allow: <exact string> -->` markers in plan files (v7.0 phases 32/33), which the gate should formalize as a machine-consumed per-file allowlist. The second risky area is packager symmetry: the RPM spec must list the hook in `%files` or rpmbuild fails on unpackaged buildroot files, and no packager may ship a state file containing `D330_DISPLAY_RESUME=0` (that would silently disable RECOV-01 in packaged installs).

**Primary recommendation:** Author the ledger as a strict pipe-table with sentinel-delimited lever rows (canonical name, alias regex, disproof one-liner, evidence link); implement `test_pitfalls_ledger.sh` parsing the table with `awk` (no `eval`), scanning only `*-PLAN.md`/`*-SUMMARY.md` under `.planning/phases/` plus `docs/research/*.md` minus an explicit allowlist (ledger + 3 source docs + honor `planner-discipline-allow` markers); add the state file to `deploy_manifest()` as a `state` entry + uninstall `rm -f`; mirror the hook into all three packagers + CI `.deb` (with `%files` coverage and no default `=0` state file); harden the hook with distinct timeout/failure log lines and the `D330_REAL_FIX=1` stand-down; and ship kit prep/verify scripts + the capture protocol doc.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Banned-lever ledger + machine gate | Repo (scripts + docs/research) | — | Pure static text gate over repo markdown; no runtime component |
| Safety-kit prep/checksum + protocol doc | Repo (scripts + docs/research) | On-device runbook steps | Repo has no hardware access; kit artifacts produced at deployment per runbook |
| Resume recovery hook (RECOV-01) | On-device runtime (systemd system-sleep) | Repo (patches/display) | Hook runs as root in systemd-suspend context on the tablet; repo owns the source + install path |
| Deploy manifest symmetry (state file) | Repo (scripts/install_dkms.sh) | — | `deploy_manifest()` is the single source of truth consumed by install/uninstall/verify |
| Packager + CI .deb shipping | Repo (packaging/*, .github/workflows) | CI runners | Static cp/install additions; CI builds on ubuntu-latest / archlinux container |
| On-device capture protocol execution | On-device (tablet) | Repo doc | Protocol documented in repo; execution (rtcwake, ftrace, intel_reg, dmesg) needs real hardware |

## Standard Stack

### Core
| Tool | Version (on this dev machine) | Purpose | Why Standard |
|------|------------------------------|---------|--------------|
| GNU bash | 5.2.21 (WSL2 interop) | All guard suites, prep/checksum scripts | The whole 36-script harness is bash; house pattern is `set -euo pipefail` + case functions |
| GNU coreutils | 9.4 | `sha256sum -c` (kit integrity), `mktemp` (fixtures), `timeout` (hook bound) | `sha256sum -c -` already used by `scripts/build_rnnoise_ladspa.sh:144`; `timeout 30` already in the hook |
| GNU awk | 5.2.1 | Ledger table parsing, manifest line filtering | Every suite already uses `awk` for structured extraction (e.g. test_installer_symmetry dump_manifest :92-95) |
| systemd system-sleep hooks | systemd (target: Kubuntu 26.04) | Recovery hook execution contract | Established house pattern (touchscreen + wifi resume hooks shipped since v1-v2) |
| dpkg / rpmbuild / makepkg | CI (ubuntu-latest, archlinux:latest) | Package shipping | Existing CI workflow build-deb/build-rpm/build-arch builds all three today |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `git ls-files` | test-count parity check | test_doc_parity.sh:183 counts `scripts/test_*.sh` vs CHANGES_AUDIT.md |
| `scripts/extract_telemetry.sh` | VBT/ACPI/DRM dump staging for the kit | Existing tooling; produces `docs/dumps/telemetry_<ts>/vbt/i915_vbt.bin` |
| `scripts/build_live_iso.sh` | Live-USB kit artifact | Reuse per locked decision; its `--dry-run` validates xorriso/unsquashfs/mksquashfs + source paths |
| `sha256sum -c MANIFEST.sha256` | Kit verification | One manifest over all kit artifacts |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| system-sleep hook | systemd Inhibitor Locks (upstream recommendation) | Locks are the "proper" API but cannot run an action at resume; the hook is the proven on-device mechanism — locked decision keeps the hook |
| Ledger keywords in the test script | Keywords in the ledger table | Locked decision: keywords live in the ledger, not the test |
| New display-manager unit | Harden existing hook | Locked decision: no new service unit |

**Installation:** No new packages. Nothing to install — the phase is bash + existing tooling. **No package registry, no npm/pip/cargo involved.**

## Package Legitimacy Audit

> Not applicable — this phase installs **zero external packages**. All work uses repo-resident scripts, POSIX/GNU coreutils already on the dev machine, and existing CI tooling. No registry lookups required.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```
                        ┌─────────────────────────────────────────────┐
                        │                REPO (D330 fix)               │
                        │                                              │
  .planning/phases/*/*.md ──┐   ┌── docs/research/RESUME_FIX_LEDGER.md  │
  (plans, summaries)        │   │    (lever table: name|alias-regex|    │
        │                   │   │     disproof|evidence-link)           │
        ▼                   ▼   ▼                                       │
  ┌──────────────────────────────────────────┐                        │
  │ scripts/test_pitfalls_ledger.sh          │                        │
  │  1. parse lever table (awk, no eval)     │── non-zero exit ──▶ plan│
  │  2. scan *.md for alias-regex hits       │      = banned lever    │   author
  │  3. honor planner-discipline-allow       │      re-proposed       │   blocked
  └──────────────────────────────────────────┘                        │
                                                                      │
  ┌──────────────────────────────────────────┐                        │
  │ scripts/prepare_safety_kit.sh (--register│   golden i915.ko.zst   │
  │  / --verify) + MANIFEST.sha256           │── checksummed kit ────▶│ off-device
  └──────────────────────────────────────────┘   live ISO, VBT/GOP,   │ staging
                       ▲  tamper ⇒ non-zero          source tarball   │
  scripts/test_safety_kit.sh (fixture kit)                             │
                                                                      │
  ┌──────────────────────────────────────────┐                        │
  │ patches/display/.../display-resume.sh    │──── cp ───▶ /usr/lib/  │ on-device
  │  (82H0 gate, timeout 30, unbind/bind,    │            system-sleep│ runtime
  │   DM restart, disable+REAL_FIX checks)   │                        │
  └──────────────────────────────────────────┘                        │
        │ shipped by                                                   │
        ▼                                                              │
  install_dkms.sh (manifest exec + state entry)                        │
  debian/rules · CI build-deb · PKGBUILD · RPM spec(%files)            │
        │                                                              │
        ▼                                                              │
  test_installer_symmetry.sh (fixtures assert install/uninstall/       │
  verify symmetry for hook + state file, packager parity)              │
                        └─────────────────────────────────────────────┘
```

### Recommended Project Structure

```
docs/research/
├── RESUME_FIX_LEDGER.md          # NEW — the 22-row lever ledger + community/upstream dead ends
├── RESUME_CAPTURE_PROTOCOL.md    # NEW — black-resume vs working-reload capture protocol
├── DISPLAY_RESUME_CCS_MODIFIER.md   # existing ledger source (allowed in scan)
├── DSI_RESUME_TRACE_ANALYSIS.md     # existing ledger source (allowed in scan)
└── COMMUNITY_FINDINGS.md            # existing ledger source (allowed in scan)

scripts/
├── test_pitfalls_ledger.sh       # NEW — GUARD-01/02 gate suite
├── test_safety_kit.sh            # NEW — kit integrity guard (fixture-based)
├── prepare_safety_kit.sh         # NEW — kit prep/checksum (NOT test_* — no --apply gate needed)
└── (existing suites extended)

patches/display/etc/systemd/system-sleep/
└── lenovo-d330-display-resume.sh # hardened in place

packaging/{debian/rules, arch/PKGBUILD, rpm/lenovo-d330-fix.spec}
.github/workflows/build-packages.yml   # CI .deb mirror
```

### Pattern 1: House guard-suite skeleton (all new suites follow this)

**What:** `set -euo pipefail`, per-case functions accumulating `CASE_FAIL`, `CASE_NAMES` array runner, `passed=N failed=M` summary, exit 1 on any failure.
**When to use:** every new `scripts/test_*.sh`.
**Example (condensed from the verified house pattern):**

```bash
#!/usr/bin/env bash
# Source: scripts/test_display_fix_guards.sh:18-278 (verbatim house pattern)
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

passed=0
failed=0
CASE_FAIL=0

case_ledger_parses() {
    # accumulate failures into CASE_FAIL, never exit directly
    :
}

CASE_NAMES=(case_ledger_parses)
for fn in "${CASE_NAMES[@]}"; do
    CASE_FAIL=0
    "$fn" || true
    name="${fn#case_}"; name="${name//_/-}"
    if [ "$CASE_FAIL" -eq 0 ]; then echo "  [OK] $name"; passed=$((passed + 1))
    else echo "  [FAIL] $name"; failed=$((failed + 1)); fi
done
echo "Guard suite summary: passed=$passed failed=$failed"
[ "$failed" -gt 0 ] && exit 1
exit 0
```

### Pattern 2: Ledger lever table (proposed format — discretion area)

**What:** A strict pipe table between HTML sentinels so the test can locate exactly the machine-readable rows, immune to prose edits elsewhere in the doc.

```markdown
<!-- LEDGER-LEVERS-START -->
| # | Lever (canonical) | Alias regex (ERE, case-insensitive) | Disproof one-liner | Evidence |
|---|-------------------|--------------------------------------|--------------------|----------|
| 1 | PPS/TCON power-cycle clamp | `intel_pps\.c\|PP_CONTROL` | wrong subsystem (eDP); legacy PPS 0xc7204 runs identical cold vs resume | DISPLAY_RESUME_CCS_MODIFIER.md §Disproven theories |
| 2 | D-PHY exit_zero_cnt / HS retune | `exit_zero_cnt\|HS_TX_TIMEOUT.*retun` | retune left registers matching cold boot, screen still black | CCS doc §Disproven theories |
...
<!-- LEDGER-LEVERS-END -->
```

Rules the gate should enforce: sentinels present exactly once; every row has 5 cells; alias regex compiles against a probe (positive AND negative test line embedded in the ledger or suite); no empty cells.

### Pattern 3: Fixture-probe case (GUARD-02 non-vacuity, house SC1 style)

**What:** the gate must PROVE it fails: plant a banned lever in a temp file shaped like a plan, expect non-zero; then assert the pristine tree still passes. Mirrors `test_harness_trust.sh` SC1 ("SC1 is non-vacuous only if the subject is GREEN before mutation", :82).

```bash
case_gate_fails_on_banned_fix() {
    local tmp; tmp="$(mktemp -d "$FIX/ledger_XXXXXX")"
    printf 'Plan: fix black resume by setting i915.enable_psr=0\n' > "$tmp/44-01-PLAN.md"
    local rc=0
    # scan a path override seam so the probe never reads the real tree
    D330_LEDGER_SCAN_DIR="$tmp" bash scripts/test_pitfalls_ledger.sh --gate-probe || rc=$?
    [ "$rc" -ne 0 ] || { echo "    [detail] gate passed a banned-lever fix proposal"; CASE_FAIL=1; }
}
```

### Pattern 4: Packager hook shipping (the three mirrors)

```bash
# Source: existing patterns — debian/rules:37-48 (cp+mkdir), PKGBUILD:42-44
# (install -d + install -m), RPM spec:37-41 + %files:87-96.
# debian/rules:
	mkdir -p debian/lenovo-d330-fix/usr/lib/systemd/system-sleep
	cp patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh \
	   debian/lenovo-d330-fix/usr/lib/systemd/system-sleep/
	chmod 755 debian/lenovo-d330-fix/usr/lib/systemd/system-sleep/lenovo-d330-display-resume.sh

# PKGBUILD:
    install -d "${pkgdir}/usr/lib/systemd/system-sleep"
    install -m 755 "${srcdir}"/../patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh \
        "${pkgdir}/usr/lib/systemd/system-sleep/"

# RPM spec (%install):
mkdir -p %{buildroot}/usr/lib/systemd/system-sleep
cp %{_builddir}/patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh %{buildroot}/usr/lib/systemd/system-sleep/
chmod 755 %{buildroot}/usr/lib/systemd/system-sleep/lenovo-d330-display-resume.sh
# AND add to %files (mandatory — see Pitfall 4):
/usr/lib/systemd/system-sleep/lenovo-d330-display-resume.sh

# CI build-packages.yml (build-deb step, mirrors debian/rules):
mkdir -p build/deb/usr/lib/systemd/system-sleep
cp patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh build/deb/usr/lib/systemd/system-sleep/
chmod 755 build/deb/usr/lib/systemd/system-sleep/lenovo-d330-display-resume.sh
```

No postinst/%post/makepkg .install change is needed: system-sleep hooks are plain executables; systemd discovers them by directory, nothing to enable or daemon-reload.

### Pattern 5: State-file manifest + uninstall symmetry

```bash
# deploy_manifest() — add ONE line next to the existing state entry
# (scripts/install_dkms.sh:157 verbatim precedent):
/etc/d330-hardware-state.json	state
# new:
/etc/default/lenovo-d330-display-resume	state

# do_uninstall — mirror the existing state-file rm (install_dkms.sh:923 verbatim pattern):
rm -f /etc/default/lenovo-d330-display-resume
```

`state` semantics already implemented in `do_verify` (present → OK, absent → SKIP; `--removed` mode → presence is DRIFT), and `populate_root()` in test_installer_symmetry already creates `state` entries in fixtures — **no verify-kind code changes needed**, only the manifest line + uninstall rm + assertions.

### Pattern 6: Hook hardening (additive; no behavior change)

```bash
# patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh
# After the existing disable check (:50-57), BEFORE the reload:
if [ "${D330_REAL_FIX:-0}" = "1" ]; then
    logger -t d330-display "real fix active (D330_REAL_FIX=1); reload hook stands down"
    exit 0
fi
# Existing timeout line stays (one bounded attempt, no retry):
#   timeout 30 "$0" _run || logger -t d330-display "i915 reload/restart timed out or failed (rc=$?)"
# Hardening: distinguish timeout (rc=124) from other failure in the log line so
# journalctl -t d330-display triage is unambiguous.
```

### Anti-Patterns to Avoid
- **Keywords in the test script:** locked decision says the ledger table is the keyword source; a test with hard-coded lever names drifts from the ledger and re-creates the WR-03 vacuity class.
- **`eval` on ledger content:** regexes parsed from markdown must be passed as arguments (`grep -E "$re"`), never `eval`'d.
- **Retry loops in the hook:** locked decision — one bounded attempt; a retry can wedge the GPU mid-resume.
- **Shipping `D330_DISPLAY_RESUME=0` as default content in packages:** silently disables RECOV-01 in packaged installs.
- **Scanning the ledger against itself:** the ledger + three source docs legitimately name every lever; without an allowlist the gate trips on its own input.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Artifact integrity | Custom hash/checksum logic | `sha256sum` + one `MANIFEST.sha256`, verified with `sha256sum -c` | House precedent `build_rnnoise_ladspa.sh:144`; hand-rolled hashing is a security no-no |
| Install/uninstall/verify inventory | A second artifact list for the state file | `deploy_manifest()` + `state` kind | Manifest is the declared single source of truth (:61); a second list drifts (M1/M2 audit findings) |
| "Does my test fail when it should?" | Manual review | Fixture probes (SC1 mutation style, `test_harness_trust.sh:82-99`) | Vacuity is the house's #1 recurring audit finding (WR-03) |
| Recovery mechanism | Any new mechanism (service unit, udev, compositor script) | The existing hook | Only full i915 unbind/bind is proven on-device ("no lighter recovery works", CCS doc :121) |
| Text scan engine | Custom matcher | `grep -E` + awk table parse | Standard tools; regexes from the ledger need no engine |
| Plan-file allowlist | A new scheme | `<!-- planner-discipline-allow: <exact string> -->` marker convention | Existing house convention (v7.0 32-01/32-02/33-01 PLAN files) |

**Key insight:** nearly every Phase 43 deliverable extends machinery that already exists and is already machine-checked. The phase's real work is *wiring + content*, not mechanism invention.

## Common Pitfalls

### Pitfall 1: Ledger gate trips on its own input (vacuity / false positive)
**What goes wrong:** the locked scan scope includes `docs/research/*.md`, but `RESUME_FIX_LEDGER.md` and the three source docs legitimately mention every lever; phase CONTEXT/RESEARCH docs discuss levers legitimately too. The gate either always fails or gets neutered.
**Why it happens:** "scan for banned mentions" conflates *disproof documentation* with *fix re-proposal*.
**How to avoid:** scan only `*-PLAN.md` and `*-SUMMARY.md` under `.planning/phases/` (the locked decision itself says "plans, summaries") plus `docs/research/*.md` excluding an explicit allowlist (`RESUME_FIX_LEDGER.md` + the three source docs + the new protocol doc); honor `<!-- planner-discipline-allow: ... -->` markers in scanned files for single-string exemptions.
**Warning signs:** gate red on a pristine tree; gate green after someone deletes ledger rows to silence it.

### Pitfall 2: Cross-suite test-count parity break
**What goes wrong:** adding `test_pitfalls_ledger.sh` + `test_safety_kit.sh` (36 → 38) makes `test_doc_parity.sh` fail.
**Why it happens:** `test_doc_parity.sh:183-187` greps `CHANGES_AUDIT.md` for the real `git ls-files 'scripts/test_*.sh'` count; `CHANGES_AUDIT.md:471` currently states "36 test guards".
**How to avoid:** update the CHANGES_AUDIT.md count (and any README suite lists the doc-parity case checks) in the same phase; run `bash scripts/test_doc_parity.sh` after adding suites.
**Warning signs:** `test-script-count-parity` case failure.

### Pitfall 3: State file shipped with disable content
**What goes wrong:** a packager copies a fixture state file containing `D330_DISPLAY_RESUME=0`; packaged installs lose automatic recovery (RECOV-01 silently violated).
**Why it happens:** copy-pasting installer artifacts into packages without checking content.
**How to avoid:** ship the hook only in packagers; the state file is a runtime/user artifact (`state` class = not created at install, SKIP-when-absent in verify). If a packager ever ships it, content must be default-enabled and declared as config (`deb` conffile, `rpm` `%config(noreplace)`, `pacman` `backup=()`).
**Warning signs:** packager-parity test asserting state-file content; user report of black resume on a packaged install.

### Pitfall 4: RPM %files omission
**What goes wrong:** hook cp added to `%install` but not `%files` → rpmbuild fails with "Installed (but unpackaged) file(s) found" [ASSUMED].
**Why it happens:** the spec's `%files` (:87-96) lists each shipped tree explicitly; a new path needs its own line.
**How to avoid:** add `/usr/lib/systemd/system-sleep/lenovo-d330-display-resume.sh` to `%files`; CI build-rpm green is the proof.
**Warning signs:** build-rpm job failure.

### Pitfall 5: Fixture harness stops mirroring the manifest
**What goes wrong:** `test_installer_symmetry.sh` helpers hard-code kind lists; a new manifest entry in an unhandled kind silently escapes every fixture case.
**Why it happens:** `dump_manifest()` awk filter (:92-95) and `populate_root()` (:104-116) enumerate kinds; the `state` kind is already handled in both, but any NEW kind would not be.
**How to avoid:** reuse the `state` kind exactly; if a new kind is ever introduced, extend `dump_manifest()` regex + `populate_root()` + `do_verify()` together (house rule from the M1/M2 symmetry audit).
**Warning signs:** fixture `--verify` count in the case output doesn't grow after a manifest edit.

### Pitfall 6: Ledger regex false positives on shared tokens
**What goes wrong:** broad alias regexes (e.g. bare `PSR`, `PPS`) flag unrelated plans (battery, thermal) and block planning.
**Why it happens:** short tokens are legitimately used by other subsystems.
**How to avoid:** alias regexes must be lever-specific (`i915\.enable_psr=0`, `intel_pps\.c`, `MIPI_SEQ_POWER_ON`) and multi-word where needed; the gate prints the matched file+line so a false positive is triage-able, and `planner-discipline-allow` grants per-file exemptions.
**Warning signs:** battery/thermal plans failing the ledger suite.

### Pitfall 7: Hardening breaks the proven hook
**What goes wrong:** refactor of the hook (restructured case arms, changed `$0` self-exec, altered disable-file path) breaks the on-device recovery that currently works.
**Why it happens:** the hook is the deliverable being hardened; regression here is the worst outcome.
**How to avoid:** additive-only changes; keep the `case "${1:-}/${2:-}"` dispatch, `DRV`/`DISABLE_FILE` values, DMI gate string, and `timeout 30` exactly; add new guard cases asserting those invariants (`bash -n` + static greps + a shim run of the `_run` path via `D330_SYSTEMCTL`-style seams if execution is wanted).
**Warning signs:** any diff touching the `case` dispatch lines or removing `logger` calls.

### Pitfall 8: WSL/dev-machine environment drift
**What goes wrong:** bash here resolves through the WSL shim (`c:\windows\system32\bash.exe`); one probe saw a transient WSL startup error (0x8007054f) before recovering. Suite runs occasionally fail for environment reasons, not code reasons.
**Why it happens:** dev machine is Windows; the harness runs under WSL2 (bash 5.2.21, coreutils 9.4, gawk 5.2.1 — all confirmed).
**How to avoid:** re-run once on a transient environment failure before diagnosing; keep suites static/fixture-based (they already are) so no systemd/logger/hardware is needed.
**Warning signs:** WSL banner noise in suite output.

## Code Examples

### The proven recovery hook — verified invariants (do not change semantics)

```bash
# Source: patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh:31-32,48,54,61-62,73-75 (verbatim)
DRV=/sys/bus/pci/drivers/i915
DISABLE_FILE=/etc/default/lenovo-d330-display-resume
        [ "$(cat /sys/class/dmi/id/product_name 2>/dev/null)" = "82H0" ] || exit 0
        if [ "${D330_DISPLAY_RESUME:-1}" = "0" ]; then
            timeout 30 "$0" _run || logger -t d330-display "i915 reload/restart timed out or failed (rc=$?)"
        systemctl restart display-manager.service 2>/dev/null || \
            systemctl restart sddm.service 2>/dev/null || \
            logger -t d330-display "display manager restart failed"
```

### deploy_manifest — current state-class precedent + the missing entry

```bash
# Source: scripts/install_dkms.sh:118 and :157 (verbatim; note :91-167 contain NO
# /etc/default/lenovo-d330-display-resume line today)
/usr/lib/systemd/system-sleep/lenovo-d330-display-resume.sh	exec
/etc/d330-hardware-state.json	state
```

### do_verify state handling (already implemented — reuse as-is)

```bash
# Source: scripts/install_dkms.sh:1159-1166 (verbatim)
            state|file-optional|exec-optional|dir-optional|grub-snippet-optional)
                # CR-01: conditional/runtime artifacts must not fail a legit
                # install. Present => OK, absent => SKIP.
                if [ -e "$full" ]; then
                    echo "  [OK] $path ($kind): present"
                else
                    echo "  [SKIP] $path ($kind): conditional/runtime artifact absent"
                fi
```

### Harness wiring point (new suites join here, after doc-parity)

```bash
# Source: scripts/test_storage_cellular.sh:146-150 (verbatim tail of the dry-run chain)
    # Doc<->code parity guard (Phase 42, SC1): asserts CHANGES_AUDIT.md and the
    # shipping docs still match the code (swappiness, scheduler, FBC, watchdog,
    # tray, wireless, test-count, touch-mode, modes, 0-byte files). Same contract
    # as the suites above - its non-zero exit propagates under set -e.
    bash scripts/test_doc_parity.sh
```

The `bash -n` list at :64 must also gain the new suite files.

### Ledger source material — the on-device disproven levers (verbatim heads)

From `docs/research/DISPLAY_RESUME_CCS_MODIFIER.md:231-269`, section "## Disproven theories (do not retry)" — 15 bullets, including verbatim: "PPS / TCON power-cycle timing clamp (`intel_pps.c`) — wrong subsystem (eDP)"; "D-PHY `exit_zero_cnt` quirk, `HS_TX_TIMEOUT` retuning"; "`CDCLK_CTL` (`0x46000`) and DSI-PHY (`0x160018`) value mismatch — written live on the black state, no effect"; "DCS re-send after video enable"; "Suspend depth: both `deep` (S3) and `s2idle` resume black"; "`modprobe -r i915` after resume: still blocked"; "`glk_cold_boot` ordering ... (correlate, not cause)"; "Forcing a probe-style full display-core init at resume ... trips repeated WARNING ... no panel"; "Bare PCI `echo 1 > .../reset` does **not** recover ... Only the i915 **unbind/bind** reload restores the panel -- do not hot-remove the GPU".

Plus the same doc's `### vlv_dsi.c experiments tried on-device (none fixed it)` (:191-203): forced `MIPI_HS_TX_TIMEOUT=0x3fffff`, `MIPI_DPHY_PARAM=0x09051003`, `MIPI_CLK_LANE_SWITCH_TIME_CNT=0x0022000f`, `MIPI_HIGH_LOW_SWITCH_COUNT=0x1d`, `MIPI_INTR_EN=0x1`; `msleep(300)` after `MIPI_SEQ_POWER_ON`; early-return from `intel_dsi_post_disable()`; panel power-cycle + `MIPI_SEQ_INIT_OTP`/`MIPI_SEQ_DISPLAY_ON` re-send; `BXT_P_DSI_REGULATOR_CFG` bit15 (skipped on GLK).

From `docs/research/DSI_RESUME_TRACE_ANALYSIS.md`: "## Ruled out by these traces" (:93-110 — CDCLK, `0x138090` marker, DSI PLL math, post-resume CRTC reads) and "## Disproven patch: DSI panel power cycle on resume" (:111-131), plus the `intel_power_domains_init_hw(display, false)` lever (:208-211).

From `docs/research/COMMUNITY_FINDINGS.md`: §2.3 sleep-target masking (systemctl mask sleep/suspend/hibernate targets — battery/thermal cost, not a fix), §2.2 brute-force `xrandr` reset (X11-only, "Cannot wake a kernel that failed S0ix"), §2.4 kernel params (`i915.enable_psr=0`, `i915.enable_fbc=0`, `i915.enable_dpcd_backlight=0` as community-suggested levers).

### Capture-protocol verified inputs (all from on-device research docs)

- **Full ≥18 s window:** "A shorter 6 s capture made it look like the sequence stopped mid-`INIT_OTP`; a full 18 s window shows it completes through `DISPLAY_ON` and `BACKLIGHT_ON`" [VERIFIED: docs/research/DSI_RESUME_TRACE_ANALYSIS.md:172-174].
- **`systemd-inhibit`:** "Any test must hold `systemd-inhibit --what=idle` or read within seconds of the resume" (KDE idle blanking turns the CRTC off) [VERIFIED: DSI_RESUME_TRACE_ANALYSIS.md:106-109].
- **No cold-boot control:** "Cold boot works because the UEFI GOP leaves the display fully initialised and `i915` fast-boots without re-programming the pipe; resume forces a real modeset" [VERIFIED: DISPLAY_RESUME_CCS_MODIFIER.md:109-110]. The working control arm is a **reload** (unbind/bind), not a cold boot.
- **Suspend without lid:** `rtcwake -m mem -s N` [VERIFIED: CCS doc :307].
- **Marker tracing:** only unconditional `pr_err` markers (`D330*`) produce output — drm.debug/dyndbg is a verified dead end [VERIFIED: DSI doc :134-142].
- **ftrace filter ranges:** the five display register ranges verbatim at DSI doc :19-23.
- **Existing on-device capture scripts:** `/home/santiago/cap.sh`, `cap2.sh`, `noc2.sh`; traces `reg_resume_inst.txt`, `reg_reload2.txt`, `reg_resume_noc.txt` [VERIFIED: DSI doc :32-35].
- **Golden-module rollback pipeline:** module build → `strip --strip-debug` → `zstd -19` → copy to `/lib/modules/7.0.0-38-generic/kernel/drivers/gpu/drm/i915/i915.ko.zst` → `depmod -a` → `update-initramfs -u` → reboot [VERIFIED: CCS doc :303-307]; rollback = restore golden `.ko.zst` + same depmod/initramfs steps.
- **VBT dump:** `scripts/extract_telemetry.sh` already stages `vbt/i915_vbt.bin` + `vbt_decoded.txt` under `docs/dumps/telemetry_<ts>/` [VERIFIED: docs/dumps/README.md:69-71]. GOP was extracted separately from `bios.bin` via `uefi_firmware` + capstone [VERIFIED: CCS doc :213-228].

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| X11 xrandr brute-force recovery (community) | Wayland-era hook: unbind/bind + DM restart | on-device finding | Community script cannot work under KWin/Wayland; hook is the current bar |
| `drm.debug`/dyndbg tracing | unconditional `pr_err` markers in the module | v8.0 research | dyndbg verified dead for i915 display path on this kernel |
| "i915 has no panel GPIO on GLK" note | corrected: VBT MIPI sequences drive GPIO 144/145/160 directly | v8.0 (DSI doc :176-186) | ledger must carry the corrected claim, not the stale one |
| system-sleep hooks | upstream still recommends Inhibitor Locks for reaction-style logic | current systemd docs | hooks remain the right tool for *actions at resume*; locks can't run actions |

**Deprecated/outdated:** `patches/dkms/etc/systemd/system/lenovo-d330-resume.service` was retired in Phase 34 and must stay deleted (zero-refs case, test_display_fix_guards.sh:109-119) — do not resurrect a service unit for the recovery.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | rpmbuild fails the build when buildroot contains unpackaged files, so `%files` must list the hook | Pitfall 4 / Pattern 4 | CI build-rpm fails (visible, cheap to fix); low risk |
| A2 | The "22 levers" enumerate to the scaffold sketched in "Ledger source material" (15 disproof bullets + 5 vlv_dsi experiments + trace-doc levers, some merged) | GUARD-01 support | Ledger row count ≠ 22 → plan-check mismatch; author enumerates during ledger task and reconciles |
| A3 | "Packagers mirror the installer's manifest set" means packagers ship the *hook* but not the runtime `state` file (state class = not created at install) | Pitfall 3 / Open Question 2 | If the user wants the state file shipped default-enabled, one extra cp + config-class handling per packager |
| A4 | The `D330_REAL_FIX=1` stand-down check should be *implemented* in Phase 43 (contract "documented now, Phase 45 sets it" read as: check ships now, marker written by Phase 45) | Pattern 6 / Open Question 3 | If document-only: the non-fighting contract (RECOV-03) is untestable this phase |
| A5 | `<!-- planner-discipline-allow: ... -->` has no existing automated consumer (grep over tools/ + scripts/ found none); the ledger gate would be its first machine consumer | Pattern 3 / Don't Hand-Roll | If a consumer exists elsewhere with different semantics, align with it |

## Open Questions (RESOLVED)

All five questions are dispositioned in the phase plans; dispositions below cite the resolving plan/task.

1. **Exact composition of the 22 ledger rows**
   - Resolved: 43-01 Task 2 — one row per *distinct lever* (forced-register batch = one row), final count in the ledger header, reconciled honestly against the roadmap bar of 22 (no padding) with any discrepancy flagged in the plan summary.
   - What we know: all source bullets verified verbatim; a 20+-row scaffold exists (see Code Examples).
   - What's unclear: whether the roadmap's "22" counts each forced register as its own row or as one experiment row.
   - Recommendation: author the ledger with one row per *distinct lever* (a forced-registers batch = one row), state the final count in the ledger header, and if it lands ≠ 22, reconcile with the roadmap number at plan-check rather than padding rows.

2. **Do packagers ship the state file?**
   - What we know: locked decision says packagers mirror the installer's manifest set; the installer's `state` class is not created at install.
   - What's unclear: whether "mirror" includes shipping a default-enabled `/etc/default/lenovo-d330-display-resume`.
   - Recommendation: ship the hook only in packagers; treat the state file as runtime-managed (skip in package parity assertions). Default-enabled shipping is the fallback if the user wants it.
   - Resolved: 43-03 Task 2 — packagers ship the hook only; the runtime state file is referenced by no packager file (machine-checked parity assertion), mirroring the installer's shipped set per A3.

3. **Implement `D330_REAL_FIX=1` stand-down now or document-only?**
   - Recommendation: implement now (3-line additive check, fixture-testable, RECOV-03's "does not fight the real fix" becomes machine-checked this phase); Phase 45 only ever writes the marker.
   - Resolved: 43-02 Task 1 — stand-down implemented now as an additive hook block with a guard case pinning its ordering; Phase 45 only writes the marker.

4. **Kit artifact location + git policy**
   - What we know: repo has no hardware access; kit artifacts are binaries (module, ISO, dumps) that must not be committed.
   - Recommendation: `scripts/prepare_safety_kit.sh --kit-dir <dir>` (default `docs/dumps/safety_kit/`, `.gitignore`d for artifacts but not for `MANIFEST.sha256`); runbook directs on-device execution with `--register <file>` per artifact.
   - Resolved: 43-04 Tasks 1–3 — kit dir default `docs/dumps/safety_kit/`; `.gitignore` covers artifacts with `MANIFEST.sha256` negated back in (Task 3); register/verify semantics fixture-asserted in `test_safety_kit.sh`.

5. **Final scan scope for the ledger gate**
   - Recommendation: `*-PLAN.md` + `*-SUMMARY.md` under `.planning/phases/` (matches "plans, summaries" in the locked decision) + `docs/research/*.md` minus the four allowlisted docs + honor `planner-discipline-allow` markers. Confirm at plan-check.
   - Resolved: 43-01 Task 1 (checker-corrected) — scan root is the git-tracked tree (`git ls-files` filtered to `.gsd/phases` plan/summary paths plus `docs/research/*.md`), NOT the `.planning` symlink path (with `core.symlinks=false` git checks `.planning` out as a text stub, so globbing it finds zero files and the gate would pass vacuously); allowlist + `planner-discipline-allow` markers honored; scanned-file count asserted > 0 and a zero-file normal-mode scan exits 1.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| bash | all suites, gate, kit scripts | ✓ (WSL2 interop) | 5.2.21 | git-bash |
| GNU coreutils (sha256sum, mktemp, timeout) | kit integrity, fixtures, hook | ✓ | 9.4 | — |
| GNU awk | ledger table parse, manifest filters | ✓ | 5.2.1 | — |
| git | test-count parity, repo scans | ✓ | repo is a git repo | — |
| systemd / systemctl / logger | on-device hook behavior only | ✗ on dev machine | — | static + fixture tests (house rule); no runtime hook tests here |
| xorriso/unsquashfs/mksquashfs | live-USB kit build | n/a (on-device runbook step) | — | build_live_iso.sh --dry-run validates presence at run time |
| intel-gpu-tools (intel_reg, intel_vbt_decode) | capture protocol, VBT dump | n/a (on-device) | — | documented in docs/dumps/README.md prerequisites |

**Missing dependencies with no fallback:** none for repo-side work. All on-device needs are runbook steps by locked decision (repo has no hardware access).
**Missing dependencies with fallback:** systemctl/logger on the dev machine — hook tests are static greps + `bash -n` + fixture/seam runs, matching every existing suite.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | House bash guard harness — 36 `scripts/test_*.sh` suites, case-function pattern, wired into `scripts/test_storage_cellular.sh --dry-run` |
| Config file | none — pattern lives in each suite (see Pattern 1) |
| Quick run command | `bash scripts/test_pitfalls_ledger.sh` / `bash scripts/test_safety_kit.sh` / `bash scripts/test_display_fix_guards.sh` / `bash scripts/test_installer_symmetry.sh` (per touched suite) |
| Full suite command | `bash scripts/test_storage_cellular.sh --dry-run` (chains every guard suite + the `bash -n` loop) plus `bash scripts/test_harness_trust.sh` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GUARD-01 | Ledger parses; row count ≥ 22; every row has alias regex + disproof + evidence link; sentinels unique | unit (static) | `bash scripts/test_pitfalls_ledger.sh` | ❌ Wave 0 (new suite) |
| GUARD-02 | Gate exits non-zero on planted banned-lever fix proposal; pristine tree passes; allowlist marker + source-doc exclusions honored; gate prints file:line on hit | unit (fixture) | `bash scripts/test_pitfalls_ledger.sh` | ❌ Wave 0 |
| GUARD-03 | Kit scripts exist + `bash -n` clean; fixture kit: pristine → `sha256sum -c` passes, tampered artifact → non-zero; MANIFEST format valid | unit (fixture) | `bash scripts/test_safety_kit.sh` | ❌ Wave 0 |
| RECOV-01 | Hook: exact `82H0` DMI gate, `timeout 30` present, no retry loop, explicit failure logging, DM restart ladder intact, `D330_REAL_FIX=1` stand-down | unit (static + `bash -n`) | `bash scripts/test_display_fix_guards.sh` (extended with hook cases) | ✅ suite exists, cases new |
| RECOV-02 | Hook shipped by debian/rules, PKGBUILD, RPM spec (+`%files`), CI build-deb; state file in `deploy_manifest()` + uninstall `rm -f`; verify fixture round-trips with new entry | unit (static + manifest fixture) | `bash scripts/test_installer_symmetry.sh` (extended) | ✅ suite exists, cases new |
| RECOV-03 | Install idempotent (re-run safe); state file SKIP-when-absent / OK-present / DRIFT-in-removed; disable via `D330_DISPLAY_RESUME=0`; stand-down with `D330_REAL_FIX=1` | unit (fixture + static) | `bash scripts/test_installer_symmetry.sh` + `bash scripts/test_display_fix_guards.sh` | ✅ machinery exists, cases new |
| (parity) | CHANGES_AUDIT.md test count updated 36→38 | unit (static) | `bash scripts/test_doc_parity.sh` | ✅ exists |

### Sampling Rate
- **Per task commit:** `bash -n` on touched scripts + the touched suite(s) (house Nyquist pattern from v7.0 summaries).
- **Per wave merge:** `bash scripts/test_storage_cellular.sh --dry-run` (full chained harness).
- **Phase gate:** full harness green + `bash scripts/test_harness_trust.sh` green before `/gsd-verify-work`; CI build-packages (tag/manual) proves the packaging additions compile into all three artifacts.

### Wave 0 Gaps
- [ ] `scripts/test_pitfalls_ledger.sh` — covers GUARD-01, GUARD-02 (new suite; the ledger doc itself is its Phase-1 task input)
- [ ] `scripts/test_safety_kit.sh` — covers GUARD-03 (fixture-based; no real artifacts needed)
- [ ] `bash -n` list + suite chain in `scripts/test_storage_cellular.sh` gains both new suites
- [ ] CHANGES_AUDIT.md count update (Pitfall 2) — not a test file, but test_doc_parity.sh fails without it

*(Framework install: none needed — no new test framework; bash harness already installed and green.)*

## Security Domain

### Applicable ASVS Categories (level 1, per config `security_asvs_level: 1`)

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | n/a — no auth surface in this phase |
| V3 Session Management | no | n/a |
| V4 Access Control | yes (thin) | hook executes as root in system-sleep context; keep additions least-privilege, no new privilege steps |
| V5 Input Validation | yes | ledger table parsed strictly (awk cell-count validation); regexes passed as `grep -E` args, never `eval`; hook sources only the root-owned `/etc/default/lenovo-d330-display-resume` (existing `. "$DISABLE_FILE"` — keep root-owned 0644, do not weaken) |
| V6 Cryptography | yes (integrity only) | SHA-256 via `sha256sum`; never hand-rolled hashing |
| V7/V9/V14 | no | n/a |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Ledger/gate bypass by re-proposing a lever in new wording | Tampering | Gate is in the harness (harness-trust meta-guard covers suite integrity); gate prints file:line hits; `planner-discipline-allow` exemptions are per-string, not blanket |
| Kit artifact tampering (golden module swapped for a bad build) | Tampering | `MANIFEST.sha256` verified with `sha256sum -c` before any restore; tamper-detection case in test_safety_kit.sh |
| State-file tampering to disable recovery silently | Tampering/DoS | File lives in `/etc/default/` (root-owned); hook logs every disable/stand-down decision to journal (`logger -t d330-display`), so silent disable is detectable |
| Command injection via sourced state file | Elevation | `. "$DISABLE_FILE"` executes shell — keep it root-owned; hook parses only simple `VAR=value` lines; no untrusted input reaches the hook (DMI string compared as a literal) |
| Hook wedging the resume path | DoS | `timeout 30` bound (existing), no retry loop (locked decision), failure logged |

## Sources

### Primary (HIGH confidence)
- `patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh` (full read) — hook mechanism, gates, timeout, disable file
- `scripts/install_dkms.sh` (:61-168 manifest, :435-444 install, :865-867/:923 uninstall, :1012-1186 verify) — manifest kinds + state semantics
- `scripts/test_display_fix_guards.sh` (full read) — house guard-suite skeleton
- `scripts/test_installer_symmetry.sh` (full read) — manifest fixture machinery (17 cases)
- `scripts/test_storage_cellular.sh` (full read) — harness wiring point
- `scripts/test_doc_parity.sh:182-187` + `CHANGES_AUDIT.md:471` — test-count parity coupling
- `scripts/d330-display-reload.sh` (full read) — manual reload tool
- `docs/research/DISPLAY_RESUME_CCS_MODIFIER.md` (full read) — disproven levers + capture inputs + module pipeline
- `docs/research/DSI_RESUME_TRACE_ANALYSIS.md` (full read) — trace method, ruled-out levers, ≥18 s window, systemd-inhibit
- `docs/research/COMMUNITY_FINDINGS.md` (full read) — community dead ends, kernel-param levers
- `packaging/debian/rules`, `packaging/arch/PKGBUILD`, `packaging/rpm/lenovo-d330-fix.spec`, `.github/workflows/build-packages.yml`, `packaging/debian/postinst` (full reads) — verified packager subset (no system-sleep hooks) and exact edit sites
- `scripts/build_live_iso.sh`, `scripts/build_rnnoise_ladspa.sh:144`, `docs/dumps/README.md`, `scripts/extract_telemetry.sh` — kit reuse points
- `.gsd/milestones/v7.0-MILESTONE-AUDIT.md:40` — packager-subset gap already audited

### Secondary (MEDIUM confidence)
- [CITED: man7.org/systemd-suspend.service(8)] — system-sleep hook contract: two args (`pre`/`post` + action), `SYSTEMD_SLEEP_ACTION` env, executables run in parallel and block the action until all finish, `user.slice` frozen during execution, hooks are "intended for local use only and should be considered hacks" (fetched 2026-10-12; systemd 262~devel rendering)

### Tertiary (LOW confidence)
- [ASSUMED] rpmbuild unpackaged-files build failure semantics (Pitfall 4)
- [ASSUMED] timeout(1) rc=124 convention (used only to enrich the hook's log wording, not asserted anywhere)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — everything is existing repo machinery, verified by full file reads this session
- Architecture: HIGH — all edit sites located with line numbers; installer-side RECOV-02 work confirmed already complete
- Pitfalls: HIGH — each pitfall is anchored to verified code (self-trip scope, doc-parity coupling, %files, fixture kind lists)
- Ledger content: HIGH on source bullets (verbatim), MEDIUM on the exact "22" composition (scaffold provided; author reconciles)

**Research date:** 2026-10-12
**Valid until:** 2026-11-11 (stable: repo-local facts; systemd docs stable)
