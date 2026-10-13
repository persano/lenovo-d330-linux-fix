# Phase 43: Guardrails, Ledger & Safe Recovery Baseline - Pattern Map

**Mapped:** 2026-10-12
**Files analyzed:** 15 (5 new, 10 modified)
**Analogs found:** 13 / 15 with exact or role matches (2 new-file formats cite RESEARCH.md proposals)

**Note on paths:** the planning tree lives at `.gsd/phases/...` on disk (`.planning/phases/...` is the same directory via junction). Measured git ground truth: the index has NO symlink entry for `.planning` and tracks files under the `.planning/phases/...` spellings (`git ls-files .gsd/phases` = 0 entries), so the ledger gate's scan list comes from `git ls-files` filtered to `*-PLAN.md`/`*-SUMMARY.md` under `.planning/phases/`; a `.gsd/phases` working-tree glob is a fallback only when `git ls-files` is unavailable.

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `docs/research/RESUME_FIX_LEDGER.md` (new) | doc / evidence ledger | batch (static text consumed by gate) | `docs/research/COMMUNITY_FINDINGS.md` + RESEARCH.md Pattern 2 table format | role-match |
| `docs/research/RESUME_CAPTURE_PROTOCOL.md` (new) | doc / runbook | batch | `docs/dumps/README.md` | role-match |
| `scripts/test_pitfalls_ledger.sh` (new) | test (guard suite) | batch text-scan + fixture probe | `scripts/test_display_fix_guards.sh` (skeleton) + `scripts/test_harness_trust.sh` (probe) | exact (skeleton) |
| `scripts/test_safety_kit.sh` (new) | test (guard suite) | fixture file-I/O | `scripts/test_installer_symmetry.sh` (fixtures) + `scripts/build_rnnoise_ladspa.sh:144` | exact |
| `scripts/prepare_safety_kit.sh` (new) | utility (kit prep/checksum) | file-I/O | `scripts/extract_telemetry.sh` + `scripts/build_rnnoise_ladspa.sh` | role-match |
| `patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh` (modify) | hook (systemd system-sleep) | event-driven | self (hardening in place); siblings `lenovo-d330-wifi-resume.sh` / `lenovo-d330-touchscreen-resume.sh` | exact |
| `scripts/install_dkms.sh` (modify) | installer / manifest | CRUD | self: `deploy_manifest()` :89-168, uninstall :867, verify :1159-1166 | exact |
| `packaging/debian/rules` (modify) | packager | batch copy | self :36-48 (mkdir+cp per tree) | exact |
| `packaging/arch/PKGBUILD` (modify) | packager | batch install | self :42-59 (`install -d` + `install -m`) | exact |
| `packaging/rpm/lenovo-d330-fix.spec` (modify) | packager | batch install + `%files` | self :37-69 (`%install`) + :87-96 (`%files`) | exact |
| `.github/workflows/build-packages.yml` (modify) | CI packager | batch copy | self build-deb :40-69 | exact |
| `scripts/test_storage_cellular.sh` (modify) | harness runner | batch chain | self :64 (`bash -n` list), :75-150 (suite chain) | exact |
| `scripts/test_display_fix_guards.sh` (modify) | test (guard suite) | static grep | self (hook cases added) | exact |
| `scripts/test_installer_symmetry.sh` (modify) | test (fixture suite) | fixture file-I/O | self :92-116 (`dump_manifest`/`populate_root`) | exact |
| `CHANGES_AUDIT.md` (modify) | doc | batch | self :471 (test-count sentence) | exact |

---

## Pattern Assignments

### `docs/research/RESUME_FIX_LEDGER.md` (new, doc / evidence ledger)

**Analog:** `docs/research/COMMUNITY_FINDINGS.md` (doc shape) + RESEARCH.md Pattern 2 (table format — the locked decision says keywords live in the ledger).

**Doc header pattern** — every `docs/research/*.md` opens with an H1 naming the scope, then sectioned bodies. `COMMUNITY_FINDINGS.md:1-9`:

```markdown
# Community Research & Prior Art Ingestion: Lenovo IdeaPad D330-10IGL

## 1. Executive Summary
...
---
```

**Machine-readable table pattern** (from RESEARCH.md:218-228 — this is the format the gate parses; no exact in-repo analog exists):

```markdown
<!-- LEDGER-LEVERS-START -->
| # | Lever (canonical) | Alias regex (ERE, case-insensitive) | Disproof one-liner | Evidence |
|---|-------------------|--------------------------------------|--------------------|----------|
| 1 | PPS/TCON power-cycle clamp | `intel_pps\.c\|PP_CONTROL` | wrong subsystem (eDP); legacy PPS 0xc7204 runs identical cold vs resume | DISPLAY_RESUME_CCS_MODIFIER.md §Disproven theories |
<!-- LEDGER-LEVERS-END -->
```

Rules to enforce (RESEARCH.md:228): sentinels present exactly once; every row has 5 cells; alias regex compiles against a positive AND negative probe line; no empty cells. Alias regexes must be lever-specific, never bare short tokens (`i915\.enable_psr=0` not `PSR`) — Pitfall 6, RESEARCH.md:358-362.

**Evidence-link content sources (verbatim row material):**
- `docs/research/DISPLAY_RESUME_CCS_MODIFIER.md:231-269` — "## Disproven theories (do not retry)", 15 bullets.
- `docs/research/DISPLAY_RESUME_CCS_MODIFIER.md:191-203` — `vlv_dsi.c` on-device experiments (forced MIPI registers, msleep, sequence re-sends).
- `docs/research/DSI_RESUME_TRACE_ANALYSIS.md:93-110` — "## Ruled out by these traces"; :111-131 "## Disproven patch: DSI panel power cycle on resume"; :208-211 `intel_power_domains_init_hw(display, false)` lever.
- `docs/research/COMMUNITY_FINDINGS.md:48-60` (§2.3 sleep-target masking), :24-46 (§2.2 xrandr brute force), §2.4 kernel params (`i915.enable_psr=0`, `i915.enable_fbc=0`, `i915.enable_dpcd_backlight=0`).

Row count: author enumerates during the task; if the count lands ≠ 22, state the final count in the ledger header and reconcile at plan-check — do not pad rows (RESEARCH.md Open Question 1, A2).

---

### `docs/research/RESUME_CAPTURE_PROTOCOL.md` (new, doc / runbook)

**Analog:** `docs/dumps/README.md` — the house runbook format: overview → prerequisites → usage steps → artifact layout. `docs/dumps/README.md:1-24` shows the section ladder (Overview / Prerequisites with an `apt install` block / Usage Options A-B / Bundle Structure tree); :50-71 shows the artifact-tree convention.

**Verified protocol inputs to document** (all from RESEARCH.md:438-448, each with its source doc citation):
- Full ≥18 s capture window (`DSI_RESUME_TRACE_ANALYSIS.md:172-174` — a 6 s window made INIT_OTP look truncated).
- `systemd-inhibit --what=idle` during tests (`DSI_RESUME_TRACE_ANALYSIS.md:106-109`).
- No cold-boot control arm; working control = unbind/bind reload (`DISPLAY_RESUME_CCS_MODIFIER.md:109-110`).
- `rtcwake -m mem -s N` to suspend without lid (`CCS doc :307`).
- Only unconditional `pr_err` `D330*` markers trace; drm.debug/dyndbg is a dead end (`DSI doc :134-142`).
- ftrace filter ranges: five display register ranges at `DSI doc :19-23`.
- Golden-module rollback pipeline: build → `strip --strip-debug` → `zstd -19` → copy to `/lib/modules/7.0.0-38-generic/kernel/drivers/gpu/drm/i915/i915.ko.zst` → `depmod -a` → `update-initramfs -u` → reboot; rollback = restore golden `.ko.zst` + same steps (`CCS doc :303-307`).
- VBT/GOP dumps: `scripts/extract_telemetry.sh` stages `vbt/i915_vbt.bin` (`docs/dumps/README.md:69-71`); GOP from `bios.bin` via `uefi_firmware` (`CCS doc :213-228`).
- Live USB: reuse `scripts/build_live_iso.sh` (build + dd + verify against manifest checksums) — locked decision.

---

### `scripts/test_pitfalls_ledger.sh` (new, guard suite)

**Analog (skeleton):** `scripts/test_display_fix_guards.sh` — copy the whole frame.

**Header + path anchoring** (test_display_fix_guards.sh:18-33):

```bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

MODULE="patches/dkms/lenovo-d330-fix/lenovo_d330_fix.c"   # path constants up top
```

**Assertion helpers** (test_display_fix_guards.sh:67-86) — accumulate into `CASE_FAIL`, never exit from a case:

```bash
CASE_FAIL=0

expect_file_out() {
    if ! grep -qF -- "$1" "$2"; then
        echo "    [detail] $2 missing: $1"
        CASE_FAIL=1
    fi
}
expect_no_file_out() { ... }        # inverse, :74-79
expect_regex_file_out() { ... }     # grep -Eq, :81-86
```

**Runner** (test_display_fix_guards.sh:243-278):

```bash
CASE_NAMES=(
    case_ledger_parses
    case_gate_fails_on_banned_fix
    case_allowlist_marker_honored
    ...
)
for fn in "${CASE_NAMES[@]}"; do
    CASE_FAIL=0
    "$fn" || true
    name="${fn#case_}"
    name="${name//_/-}"
    if [ "$CASE_FAIL" -eq 0 ]; then
        echo "  [OK] $name"; passed=$((passed + 1))
    else
        echo "  [FAIL] $name"; failed=$((failed + 1)); continue
    fi
done
echo ""
echo "=========================================================="
echo " Guard suite summary: passed=$passed failed=$failed"
echo "=========================================================="
if [ "$failed" -gt 0 ]; then exit 1; fi
exit 0
```

**Core gate pattern** — parse the ledger table with `awk`, pass regexes as `grep -E` arguments, never `eval` (RESEARCH.md anti-pattern, :308). House `awk` structured-extraction precedents: `scripts/test_installer_symmetry.sh:92-101` (kind filter) and :101 (`strip_manifest` awk skip-block). Gate mechanics:
1. Locate `<!-- LEDGER-LEVERS-START -->` / `<!-- LEDGER-LEVERS-END -->` sentinels; fail if 0 or >1 of each.
2. Extract rows with `awk -F'|'`; validate 5 cells; reject empty cells.
3. Scan `git ls-files` filtered to `*-PLAN.md` + `*-SUMMARY.md` under `.planning/phases/` (the tracked spelling) plus `docs/research/*.md` **minus allowlist** (the ledger itself, the 3 source docs, the new protocol doc); `.gsd/phases` working-tree glob only as fallback; assert the plan/summary subset count > 0 separately from the total, and exit 1 in normal mode when the subset is empty.
4. Strip each scanned file's `<!-- planner-discipline-allow: <string> -->` lines / match-then-exempt per string.
5. For each lever, `grep -Ein -- "$re" "$f"`; on hit print `file:line` + lever name, set failure. Non-zero exit = banned lever re-proposed.

**Fixture-probe case (non-vacuity)** — copy the SC1 shape from `scripts/test_harness_trust.sh:58-123`: baseline-green check BEFORE mutation, mutation, assert failure, restore, assert clean. `test_harness_trust.sh:82-91`:

```bash
# SC1 is non-vacuous only if the subject is GREEN before mutation. Without
# this baseline a script that already exits non-zero ... would ``pass'' SC1 by
# failing for the wrong reason.
local baseline_rc=0
( cd "$REPO_ROOT" && eval "$cmd" ) >/dev/null 2>&1 || baseline_rc=$?
if [ "$baseline_rc" -ne 0 ]; then
    bad "SC1 $label: baseline '$cmd' already exits $baseline_rc on the intact subject"
    return 0
fi
```

For the gate, prefer the **env-seam probe** (no repo mutation at all) — the house precedent for an env-var seam driving a failure-path probe is `scripts/test_storage_cellular.sh:110-120`:

```bash
if sc2_out="$(D330_LADSPA_DIRS="/nonexistent-empty-ladspa" bash scripts/test_mic_rnnoise.sh --probe 2>&1)"; then
    echo "[FAIL] RNNoise probe passed with librnnoise_ladspa.so absent (SC2)" >&2
    exit 1
fi
```

So the gate should accept a scan-root override (e.g. `D330_LEDGER_SCAN_DIR`) used only by a `--gate-probe` mode, and the fixture case plants a banned-lever plan in a `mktemp -d` dir (RESEARCH.md:234-242):

```bash
case_gate_fails_on_banned_fix() {
    local tmp; tmp="$(mktemp -d "$FIX/ledger_XXXXXX")"
    printf 'Plan: fix black resume by setting i915.enable_psr=0\n' > "$tmp/44-01-PLAN.md"
    local rc=0
    D330_LEDGER_SCAN_DIR="$tmp" bash scripts/test_pitfalls_ledger.sh --gate-probe || rc=$?
    [ "$rc" -ne 0 ] || { echo "    [detail] gate passed a banned-lever fix proposal"; CASE_FAIL=1; }
}
```

**Allowlist marker source** (exact house convention, from `.gsd/milestones/v7.0-phases/32-.../32-01-PLAN.md:69-72`):

```markdown
<!-- planner-discipline-allow: mkfs.ext4 -F -->
<!-- planner-discipline-allow: sleep 1 -->
```

No machine consumer exists yet (RESEARCH.md A5) — this gate is its first; semantics: per-file, per-exact-string exemption, never blanket.

**Anti-patterns** (RESEARCH.md:306-311): no keywords hard-coded in the test; no `eval` on ledger regexes; do not scan the ledger against itself; gate must print file:line on hit.

---

### `scripts/test_safety_kit.sh` (new, guard suite)

**Analog (fixtures):** `scripts/test_installer_symmetry.sh` — copy the fixture frame. `test_installer_symmetry.sh:61-63`:

```bash
FIX="$(mktemp -d)"
trap 'rm -rf "$FIX"' EXIT
CASE_OUT="$FIX/case.out"
```

And its helpers `expect_rc_eq` / `expect_out` (:70-82) for asserting on captured command output. Then build a fixture kit inside `$FIX`: write dummy artifacts, run `scripts/prepare_safety_kit.sh --register` against them, assert `MANIFEST.sha256` format, run `sha256sum -c`, tamper one artifact, assert non-zero, restore. Tamper-detection assertion shape (mirrors `case_verify_drift_detected`, test_installer_symmetry.sh:220-244: assert the good case is green first, then corrupt and expect failure — never the reverse order):

```bash
# pristine -> verify passes
rc=0; sha256sum -c "$FIX/kit/MANIFEST.sha256" ... || rc=$?
expect_rc_eq "$rc" 0
# tampered -> verify fails
printf 'x' >> "$FIX/kit/artifact.bin"
rc=0; sha256sum -c ... || rc=$?
if [ "$rc" -eq 0 ]; then echo "    [detail] tampered kit verified clean"; CASE_FAIL=1; fi
```

**Integrity primitive:** `scripts/build_rnnoise_ladspa.sh:143-148`:

```bash
log_info "Verifying SHA-256..."
if ! echo "${RNNOISE_SHA256}  ${WORK_DIR}/${RNNOISE_TARBALL}" | sha256sum -c -; then
    log_err "SHA-256 mismatch for ${RNNOISE_TARBALL}; aborting."
    exit 1
fi
```

Note the two-space separation in manifest lines (`<sha256>  <path>`) — that is what `sha256sum -c` parses.

**Test-count side effect (Pitfall 2):** adding this suite (and `test_pitfalls_ledger.sh`) makes `test_doc_parity.sh:183-187` fail until `CHANGES_AUDIT.md:471` is updated from "36 test guards" to 38 in the same phase. `CHANGES_AUDIT.md:471` current text:

```
Every subsystem includes an automated bash verification test script supporting `--probe`, `--simulate`, and `--dry-run` modes. The suite currently ships 36 test guards (`scripts/test_*.sh`); the representative ones are:
```

---

### `scripts/prepare_safety_kit.sh` (new, utility)

**Analog:** `scripts/extract_telemetry.sh` (repo-side artifact staging under `docs/dumps/`) + `scripts/build_rnnoise_ladspa.sh` (verify step + idempotent logging).

**Header + dirs + log helpers** (extract_telemetry.sh:15-22, 32-36):

```bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DUMPS_DIR="${REPO_ROOT}/docs/dumps"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }
```

(`build_live_iso.sh:15-18` shows the plain no-color variant `log_info/log_ok/log_warn/log_err` — either is house style.)

**Argument parsing with --dry-run** (build_live_iso.sh:32-56 + :62-87): parse `--kit-dir`, `--register <file>`, `--verify`, `--dry-run`, `--help` in a `while [[ $# -gt 0 ]]` case loop; a `--dry-run` block validates prerequisites and exits 0 without side effects. Reuse points to validate in dry-run: `sha256sum` presence, kit dir writability, and that `scripts/build_live_iso.sh --dry-run` itself passes (its tool check is at build_live_iso.sh:68-75).

**Register mode** (per RESEARCH.md:486-488): `--register <file>` appends `<sha256>  <relative-path>` to `<kit-dir>/MANIFEST.sha256` (idempotent: replace an existing line for the same path rather than appending a duplicate). `--verify` runs `sha256sum -c MANIFEST.sha256` inside the kit dir. Kit dir default `docs/dumps/safety_kit/`; `.gitignore` artifacts but keep `MANIFEST.sha256` committable (runbook directs on-device execution; repo has no hardware access). Not named `test_*` — it is a mutating utility, so the SC2 `--apply` meta-guard does not apply to it (it never touches the system, only repo-side files).

---

### `patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh` (modify, hook)

**Analog:** the file itself — hardening is additive-only (Pitfall 7, RESEARCH.md:364-368: keep the `case "${1:-}/${2:-}"` dispatch, `DRV`/`DISABLE_FILE` values, DMI gate string, and `timeout 30` exactly).

**Verified invariants (do not change):** hook lines 31-32, 45-49, 54-57, 61-65, 73-75:

```bash
DRV=/sys/bus/pci/drivers/i915
DISABLE_FILE=/etc/default/lenovo-d330-display-resume
case "${1:-}/${2:-}" in
    post/*)
        [ "$(cat /sys/class/dmi/id/product_name 2>/dev/null)" = "82H0" ] || exit 0
        [ -d "$DRV" ] || exit 0
        if [ -r "$DISABLE_FILE" ]; then
            . "$DISABLE_FILE"
        fi
        if [ "${D330_DISPLAY_RESUME:-1}" = "0" ]; then
            logger -t d330-display "resume reload disabled (D330_DISPLAY_RESUME=0 in $DISABLE_FILE)"
            exit 0
        fi
        timeout 30 "$0" _run || logger -t d330-display "i915 reload/restart timed out or failed (rc=$?)"
        ...
        systemctl restart display-manager.service 2>/dev/null || \
            systemctl restart sddm.service 2>/dev/null || \
            logger -t d330-display "display manager restart failed"
```

**Addition 1 — REAL_FIX stand-down** (RESEARCH.md Pattern 6, :296-299): insert after the existing disable check (:54-57), BEFORE the timeout line:

```bash
if [ "${D330_REAL_FIX:-0}" = "1" ]; then
    logger -t d330-display "real fix active (D330_REAL_FIX=1); reload hook stands down"
    exit 0
fi
```

**Addition 2 — distinct timeout/failure logging:** distinguish timeout (rc=124) from other failure in the log line so `journalctl -t d330-display` triage is unambiguous (RESEARCH.md:302-303). One bounded attempt, no retry loop (locked decision — a retry can wedge the GPU mid-resume).

**Logging convention:** every decision path logs via `logger -t d330-display` (hook :38, :55, :58, :62, :72, :75) — keep this for the new lines.

**Sibling-role consistency:** `patches/wireless/etc/systemd/system-sleep/lenovo-d330-wifi-resume.sh` and `patches/touchscreen/.../lenovo-d330-touchscreen-resume.sh` share the same location + system-sleep contract; the display hook stays a plain executable (no unit file — the retired `patches/dkms/etc/systemd/system/lenovo-d330-resume.service` must stay deleted; zero-refs case at `test_display_fix_guards.sh:109-119`).

---

### `scripts/install_dkms.sh` (modify, installer/manifest)

**Analog:** the file itself. Three edit sites, each copying an adjacent verbatim precedent.

**Edit 1 — manifest line:** add the state file next to the existing `state` entry. `install_dkms.sh:157` is the precedent:

```bash
/etc/d330-hardware-state.json	state
```

New line (TAB-separated, same two-column format):

```bash
/etc/default/lenovo-d330-display-resume	state
```

Do NOT add a do_install copy action — `state` kind semantics (documented at :77-78: "runtime state file (written by a unit ExecStop, removed on uninstall); verify reports SKIP when absent") mean it is not created at install. Note: `case_manifest_deploy_consistency` in the symmetry suite already skips `state` on the install-action check (:183), so no fixture-helper change is needed for this kind.

**Edit 2 — uninstall rm:** mirror the existing state-file removal pattern (:867 shows the hook rm; the state-json rm is the analogous line in `do_uninstall`):

```bash
rm -f /etc/default/lenovo-d330-display-resume
```

**Edit 3 — no verify changes:** `state` handling is already implemented at :1159-1166:

```bash
state|file-optional|exec-optional|dir-optional|grub-snippet-optional)
    # CR-01: conditional/runtime artifacts must not fail a legit
    # install. Present => OK, absent => SKIP.
    if [ -e "$full" ]; then
        echo "  [OK] $path ($kind): present"
    else
        echo "  [SKIP] $path ($kind): conditional/runtime artifact absent"
```

**House rule (Pitfall 5):** reuse the `state` kind exactly; any NEW kind would need `dump_manifest()` regex + `populate_root()` + `do_verify()` extended together.

---

### `packaging/debian/rules` (modify) / `packaging/arch/PKGBUILD` (modify) / `packaging/rpm/lenovo-d330-fix.spec` (modify) / `.github/workflows/build-packages.yml` (modify)

**Analog:** each file's own per-tree copy block. The new block mirrors an existing shipped tree one-for-one, including the `chmod 755` (or `install -m 755`) because `cp` preserves 0644 (rules:28-30 states this explicitly).

**debian/rules** — precedent tree block (:46-48, systemd units) and the chmod rationale (:28-30):

```makefile
	# Install systemd
	mkdir -p debian/lenovo-d330-fix/etc/systemd/system
	cp patches/*/etc/systemd/system/*.service debian/lenovo-d330-fix/etc/systemd/system/
	...
	# cp preserves 0644 and dh_fixperms only normalizes usr/bin, not
	# /usr/local/bin, so make every installed tool executable.
	chmod 755 debian/lenovo-d330-fix/usr/local/bin/*
```

New block:

```makefile
	# System-sleep resume hooks (plain executables; systemd discovers by dir).
	mkdir -p debian/lenovo-d330-fix/usr/lib/systemd/system-sleep
	cp patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh \
	   debian/lenovo-d330-fix/usr/lib/systemd/system-sleep/
	chmod 755 debian/lenovo-d330-fix/usr/lib/systemd/system-sleep/lenovo-d330-display-resume.sh
```

**PKGBUILD** — precedent (:57-59):

```bash
    # Install systemd
    install -d "${pkgdir}/etc/systemd/system"
    install -m 644 "${srcdir}"/../patches/*/etc/systemd/system/*.service "${pkgdir}/etc/systemd/system/"
```

New block:

```bash
    install -d "${pkgdir}/usr/lib/systemd/system-sleep"
    install -m 755 "${srcdir}"/../patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh \
        "${pkgdir}/usr/lib/systemd/system-sleep/"
```

**RPM spec** — `%install` precedent (:41, :62) AND the mandatory `%files` addition (:87-96 lists every shipped tree; an unpackaged buildroot file fails rpmbuild, RESEARCH.md Pitfall 4 / A1):

```spec
mkdir -p %{buildroot}/etc/systemd/system
...
cp %{_builddir}/patches/*/etc/systemd/system/*.service %{buildroot}/etc/systemd/system/

%files
/usr/local/bin/*
/etc/systemd/system/*
...
```

New: one `mkdir -p` + `cp` + `chmod 755` in `%install` for `/usr/lib/systemd/system-sleep/lenovo-d330-display-resume.sh`, plus the path as its own line in `%files`.

**CI build-deb** — precedent mkdir/cp/chmod block (:40-44, :63-69):

```yaml
          mkdir -p build/deb/DEBIAN build/deb/usr/local/bin \
                   build/deb/etc/modprobe.d build/deb/etc/udev/rules.d \
                   ...
          cp patches/*/etc/systemd/system/*.service build/deb/etc/systemd/system/
```

New: add `build/deb/usr/lib/systemd/system-sleep` to the mkdir list + a `cp patches/display/etc/systemd/system-sleep/lenovo-d330-display-resume.sh build/deb/usr/lib/systemd/system-sleep/` + `chmod 755`.

**No postinst/%post/.install change needed:** system-sleep hooks are plain executables, nothing to enable or daemon-reload (RESEARCH.md:274).

**Do NOT ship the state file in any packager:** Pitfall 3 (RESEARCH.md:340-344) — a shipped `D330_DISPLAY_RESUME=0` silently disables RECOV-01. Packagers mirror the installer's *shipped* set (hook = yes, runtime state file = no).

---

### `scripts/test_storage_cellular.sh` (modify, harness runner)

**Analog:** itself. Two wiring points, exact shapes:

**`bash -n` list** (:64) — append both new suites to the existing space-separated loop list:

```bash
    for f in tools/d330-microsd-setup.sh scripts/test_microsd_guards.sh scripts/test_hibernate_guards.sh scripts/test_display_fix_guards.sh scripts/test_installer_symmetry.sh scripts/test_noop_guards.sh scripts/test_audio_dsp.sh scripts/test_mic_rnnoise.sh scripts/test_udev_hwdb_match.sh scripts/test_power_stack.sh scripts/test_wireless_coex.sh scripts/test_harness_trust.sh scripts/test_doc_parity.sh scripts/test_storage_cellular.sh; do
```

**Suite chain** (:75-150) — each entry follows this comment+call contract (its non-zero exit propagates under `set -e`):

```bash
    # Doc<->code parity guard (Phase 42, SC1): asserts CHANGES_AUDIT.md and the
    # shipping docs still match the code (...). Same contract
    # as the suites above - its non-zero exit propagates under set -e.
    bash scripts/test_doc_parity.sh
```

Add `bash scripts/test_pitfalls_ledger.sh` and `bash scripts/test_safety_kit.sh` at the tail of the chain (after doc-parity).

---

### `scripts/test_display_fix_guards.sh` (modify — extend with hook cases)

**Analog:** itself. New hook cases copy the existing static-grep case shapes (`case_kernel_src_dryrun_first` :121-142 shows `bash -n` + literal greps; `expect_file_out` / `expect_no_file_out` are the assertion primitives). Expected new cases (RECOV-01/RECOV-03 map):
- hook DMI gate exact string `"82H0"` present;
- `timeout 30 "$0" _run` present;
- no retry loop (no repeated `_run` invocation / no loop around the reload);
- `D330_REAL_FIX=1` stand-down present;
- `logger -t d330-display` failure lines present (timeout vs other failure distinguished);
- DM restart ladder intact (`display-manager.service` → `sddm.service` fallback);
- `DRV=`, `DISABLE_FILE=` values unchanged.
Assemble the banned unit name from parts if a zero-refs style check is needed (:26-30 shows the part-assembly trick so the suite never ships the contiguous literal).

---

### `scripts/test_installer_symmetry.sh` (modify — extend fixtures)

**Analog:** itself. `dump_manifest()` kind regex (:92-95) already includes `state`; the header comment "Cases (17)" (:13-18) and the runner `CASE_NAMES` (:477-495) gain the new cases. Key existing pieces new assertions build on:
- `dump_manifest` (`:92-95`) — kind filter, `state` already listed.
- `populate_root` (`:105-116`) — creates `state` entries via the `*` default arm; the new state-file line will flow through automatically. Assert the fixture verify count grows after the manifest edit (Pitfall 5 warning sign: `:356`).
- `case_manifest_deploy_consistency` (`:175-218`) — `state` is skipped on the install-action check (:183) but still requires an uninstall removal action (:205-216), which is exactly the RECOV-02 assertion for the new state file.
- `case_verify_conditional_absent` (`:257-275`) — proves SKIP semantics for absent conditionals; extend assertions so the new state-file entry is verified present-OK / absent-SKIP / DRIFT-in-`--removed`.

---

### `CHANGES_AUDIT.md` (modify)

**Analog:** itself, `:471` — the parity-coupled sentence (quoted under `scripts/test_safety_kit.sh` above). Change `36 test guards` → `38 test guards` and list the two new suites in the representative-ones enumeration if the sentence names them. Run `bash scripts/test_doc_parity.sh` after.

---

## Shared Patterns

### 1. House guard-suite skeleton
**Source:** `scripts/test_display_fix_guards.sh:18-33, 67-86, 243-278`
**Apply to:** `test_pitfalls_ledger.sh`, `test_safety_kit.sh` (and every future `test_*.sh`).
`set -euo pipefail`; SCRIPT_DIR/REPO_ROOT anchor + `cd "$REPO_ROOT"`; path constants at top; per-case functions accumulating `CASE_FAIL`; `CASE_NAMES` array runner with `passed=N failed=M` summary; exit 1 on any failure. Never exit from inside a case.

### 2. SC1 fixture-probe non-vacuity
**Source:** `scripts/test_harness_trust.sh:58-123` (baseline-green → mutate → assert fail → restore → assert clean); env-seam variant `scripts/test_storage_cellular.sh:110-120` (`D330_LADSPA_DIRS=/nonexistent-empty-ladspa ... --probe` must exit non-zero).
**Apply to:** the ledger gate's "gate fails on banned lever" case (use the `D330_LEDGER_SCAN_DIR` seam + `--gate-probe` so no repo files are touched) and the kit tamper-detection case (pristine passes first, then tamper).

### 3. mktemp fixture + trap hygiene
**Source:** `scripts/test_installer_symmetry.sh:61-63` (`FIX="$(mktemp -d)"; trap 'rm -rf "$FIX"' EXIT`), `scripts/test_harness_trust.sh:43-56` (snapshot + restore-all trap).
**Apply to:** both new suites. Never leave the tree dirty.

### 4. sha256sum integrity
**Source:** `scripts/build_rnnoise_ladspa.sh:143-148` (`echo "<hash>  <file>" | sha256sum -c -`).
**Apply to:** `prepare_safety_kit.sh` (generate/verify) and `test_safety_kit.sh` (assert). Two-space separator format for `sha256sum -c` compatibility.

### 5. deploy_manifest single source of truth + `state` kind
**Source:** `scripts/install_dkms.sh:89-168` (manifest), :157 (state precedent), :867 (uninstall rm precedent), :1159-1166 (state verify semantics); consumers `scripts/test_installer_symmetry.sh:92-116`.
**Apply to:** the state-file addition (manifest line + uninstall `rm -f` only — no install copy, no verify-kind changes). A second artifact list is forbidden (RESEARCH.md "Don't Hand-Roll": :317-318).

### 6. `logger -t d330-display` decision logging
**Source:** hook lines 38, 55, 58, 62, 72, 75.
**Apply to:** every new hook decision path (REAL_FIX stand-down, distinguished timeout/failure) so `journalctl -t d330-display` is the single triage surface.

### 7. Static-grep assertion helpers
**Source:** `scripts/test_display_fix_guards.sh:67-86` (`expect_file_out` / `expect_no_file_out` / `expect_regex_file_out`), `scripts/test_installer_symmetry.sh:70-87` (`expect_rc_eq` / `expect_out` / `contains` — note the SIGPIPE-safe `case`-based `contains`).
**Apply to:** all extended/new case functions. Prefer `case` substring tests over `printf | grep -q` pipes (pipefail SIGPIPE race, :84-87).

### 8. Harness wiring contract
**Source:** `scripts/test_storage_cellular.sh:64` (bash -n list) and :75-150 (chained suites, comment + bare `bash scripts/test_*.sh`).
**Apply to:** both new suites. Non-zero exit propagates; `passed=N failed=M` summary flows into harness output.

### 9. Packager parity triplicate
**Source:** the per-tree blocks in `debian/rules:36-48`, `PKGBUILD:42-59`, RPM spec `:37-69` + `%files :87-96`, CI `build-packages.yml:40-69`; parity assertions `case_user_unit_packaged` (`test_installer_symmetry.sh:360-373`) and `case_enable_parity_8` (:339-354) show the "same artifact grepped in all three packagers" assertion shape.
**Apply to:** the hook shipping — identical path `/usr/lib/systemd/system-sleep/lenovo-d330-display-resume.sh` in all three packagers + CI build-deb; `%files` line mandatory in the RPM; no state file shipped anywhere; no postinst/%post changes. Extend packager-parity cases with a `usr/lib/systemd/system-sleep` grep loop over `$DEBIAN_RULES $RPM_SPEC $ARCH_PKGBUILD` (+ CI file).

### 10. `<!-- planner-discipline-allow: <exact string> -->` allowlist
**Source:** `.gsd/milestones/v7.0-phases/32-data-loss-boot-safety-guards/32-01-PLAN.md:69-72` (marker convention).
**Apply to:** the ledger gate as a per-file, per-exact-string exemption (its first machine consumer — RESEARCH.md A5). Never blanket exemptions.

---

## No Analog Found

| File | Role | Data Flow | Reason | Fallback |
|------|------|-----------|--------|----------|
| `docs/research/RESUME_FIX_LEDGER.md` — the pipe-table lever format | doc / machine-consumed table | batch | No in-repo machine-parsed markdown table exists | RESEARCH.md Pattern 2 (:218-228) is the proposed format; sentinel + 5-cell row rules are specified there |
| `planner-discipline-allow` machine consumer | gate feature | batch | Convention exists only as plan-file text; no automated consumer anywhere (RESEARCH.md A5) | Define semantics in the new gate: per-file, per-string exemption; document in the suite header |

---

## Metadata

**Analog search scope:** `scripts/` (46 shell scripts), `patches/*/etc/systemd/system-sleep/`, `packaging/{debian,arch,rpm}/`, `.github/workflows/`, `docs/research/`, `docs/dumps/`, `.gsd/milestones/v7.0-phases/`
**Files read in full or targeted:** 16 (`test_display_fix_guards.sh`, `test_installer_symmetry.sh`, `test_harness_trust.sh`, `test_storage_cellular.sh`, the display hook, `install_dkms.sh` targeted sections, `build_rnnoise_ladspa.sh`, `build_live_iso.sh`, `extract_telemetry.sh`, `build-packages.yml`, `debian/rules`, `PKGBUILD`, RPM spec, `COMMUNITY_FINDINGS.md`, `docs/dumps/README.md`, marker-plan files)
**Pattern extraction date:** 2026-10-12
**Source docs:** `43-CONTEXT.md` (locked decisions), `43-RESEARCH.md` (verified line numbers — all spot-checked against the working tree this session)
