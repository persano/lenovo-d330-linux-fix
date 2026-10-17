# Phase 50: TCON Identification — DCS ID-Read Instrument (Software-Only) - Pattern Map

**Mapped:** 2026-10-16
**Files analyzed:** 8 (5 modified, 3 new)
**Analogs found:** 8 / 8

All analog paths verified git-TRACKED (`git ls-files` non-empty for every entry below).

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `patches/d330_dsi_dump.patch` (extend echo-2 write side + DCS read section) | kernel/debugfs instrumentation (patch) | request-response (debugfs write trigger → frozen read buffer) | same file (existing node code) | exact (self-extension) |
| `scripts/capture_dsi_dumps.sh` (echo-2 mode, timeout-wrapped trigger, blind invocation) | controller (device capture script) | file-I/O + device trigger | same file | exact (self-extension) |
| `scripts/dsi_mmio_diff.sh` (`# DCS ID READ` parser + comparison block + selftest fixtures) | utility (transform/parser) | batch transform (two-file join → markdown) | same file | exact (self-extension) |
| `scripts/tcon_i2c_sweep.sh` | controller (device sweep collector) | file-I/O (stdout → archive file, sha256) | `scripts/capture_dsi_dumps.sh` | role-match |
| `.github/workflows/build-kernel.yml` (grep-proofs for new symbols) | config (CI pipeline) | pipeline (apply → grep → build) | same file (existing apply+grep step) | exact (self-extension) |
| `docs/research/TCON_IDENTIFICATION.md` | docs (verdict report) | n/a (evidence synthesis) | `docs/research/GOP_DSI_RE_FINDINGS.md` | role-match |
| `docs/research/DSI_MMIO_DIFF.md` §6 (0x6b004 row label only) | docs (correction) | n/a (label edit) | same file §5.2 (already-correct decode) + `scripts/test_dsi_mmio_evidence.sh` gate | exact |
| `scripts/test_dsi_mmio_evidence.sh` / `scripts/test_pitfalls_ledger.sh` (must stay green — no edit expected) | test (gate) | static check | same files | exact |

Note: this phase touches **no new kernel source file** — the DCS read code lands inside the existing patch's `intel_dsi_dump_debugfs.c`. There is **no codebase analog for the `mipi_dsi_dcs_read()` call shape itself** (repo has zero DCS-read code); use RESEARCH.md Pattern 1/2 Code Examples for that piece.

## Pattern Assignments

### `patches/d330_dsi_dump.patch` (kernel/debugfs instrumentation, request-response)

**Analog:** same file (phase-47/49 node; extend in place, additive-only)

**Output contract comment to extend** (patch lines 21-33) — the new `# DCS ID READ` section joins this contract:
```c
 * Output contract (parsed by phase-47 diff tooling):
 *   # RANGE <lo>-<hi> (<N> words)   before each walked range
 *   0x<off>=<8-hex-value>           one data line per walked word
 *   # SKIPPED: DSI PLL off - DSI block reads skipped
 *   NAME 0x<off>=<8-hex> <decode>   # NAMED OVERLAY section rows (the
 *                                   leading NAME keeps overlay rows out
 *                                   of the ^0x...=... record regex)
```
New row rule: `DCS` prefix plays the role of `NAME` — keeps ID rows out of the record regex.

**Write-side parse to replace** (patch lines 242-258) — `kstrtobool_from_user` rejects "2" (Pitfall 2):
```c
static ssize_t
d330_dsi_dump_write(struct file *filp, const char __user *ubuf,
		    size_t cnt, loff_t *ppos)
{
	struct intel_display *display = filp->private_data;
	bool trigger;
	int ret;

	ret = kstrtobool_from_user(ubuf, cnt, &trigger);
	if (ret)
		return ret;

	if (!trigger)
		return cnt;

	if (!mutex_trylock(&d330_dsi_dump_lock))
		return -EBUSY; /* concurrent trigger: never corrupt the buffer */
```
Change to `kstrtouint_from_user()` accepting 0/1/2, `>2` → `-EINVAL`; keep `echo 1` semantics, `-EBUSY` mutex discipline, `d330_dsi_dump.len/words` reset (lines 265-266) and the walk call exactly as-is; add the DCS section call after `d330_dsi_dump_walk(display)` inside the same lock.

**PLL gate to reuse for the DCS section** (patch lines 181-194) — machine-hang rule, Pitfall 4:
```c
	dsi_ok = !((display->platform.geminilake || display->platform.broxton) &&
		   !bxt_dsi_pll_is_enabled(display));
	if (!dsi_ok) {
		d330_dsi_dump_add("# SKIPPED: DSI PLL off - DSI block reads skipped\n");
		d330_dsi_dump_add("# SKIPPED: DSI PLL off - PHY reads skipped\n");
	} else {
		d330_dsi_dump_range(display, 0x6b000, 0x6c000);
```
The walk currently computes `dsi_ok` locally; the DCS section needs the same value — either return it or gate at the call site.

**Annotated-section append helper** (patch lines 71-87) — use for every `# DCS ID READ` / `DCS` line:
```c
__printf(1, 2)
static void d330_dsi_dump_add(const char *fmt, ...)
{
	va_list args;
	int n;

	if (!d330_dsi_dump.buf || d330_dsi_dump.len >= d330_dsi_dump.size)
		return;
	...
}
```
Emits after `d330_dsi_dump_overlay()` (patch line 199) — section must be strictly after NAMED OVERLAY (Pitfall 6).

**Session-confirmation line** (patch lines 269-270) — capture script polls `D330DSIREG`:
```c
	pr_info("D330DSIREG: snapshot captured (%u words, %zu bytes buffered)\n",
		d330_dsi_dump.words, d330_dsi_dump.len);
```

**No analog (use RESEARCH.md):** `mipi_dsi_dcs_read()`/`mipi_dsi_generic_read()` call shape, `dsi_hosts[PORT_A]->device` traversal, `MIPI_DSI_MODE_LPM`/`channel = 0` reset, and the INTR_STAT bit-29 (`GEN_READ_DATA_AVAIL`) answered/timeout annotation — 50-RESEARCH.md Code Examples (lines 208-237, 339-398) verbatim. Return value is ALWAYS ≥4 (Pitfall 1): never annotate success from `ret`.

### `scripts/capture_dsi_dumps.sh` (controller, file-I/O + device trigger)

**Analog:** same file (47/49 discipline; extend with echo-2 mode)

**Arm/arg parsing pattern** (lines 96-101) — add `boot2`/`resume2` (or a mode flag) in this `case`:
```bash
[ $# -ge 1 ] && [ $# -le 2 ] || { usage; exit 2; }
ARM="$1"
case "$ARM" in
    boot|resume) ;;
    *) log_err "arm must be 'boot' or 'resume' (got '$ARM')"; usage; exit 2 ;;
esac
```

**Trigger block to wrap in `timeout`** (lines 152-164):
```bash
TRIG_TIME="$(date '+%F %T %z')"
T0="$(date +%s)"

BEFORE=$(dmesg 2>/dev/null | grep -c 'D330DSIREG' || true)
ERRFILE="$(mktemp)"
if ! echo 1 > "$NODE" 2>"$ERRFILE"; then
    log_err "trigger failed: $(cat "$ERRFILE")"
    log_err "(EBUSY would mean another trigger is in flight; retry in a moment)"
    rm -f "$ERRFILE"
    exit 1
fi
```
Echo-2 mode: `timeout 15 sh -c "echo 2 > '$NODE'"` (RESEARCH Pattern 3, lines 262-267); a hanging read can never wedge the session.

**Record regex + section-count validation** (lines 60, 195-217) — unchanged for echo-2 (`DCS` rows must not match `RECORD_RE`; floor/gate logic stays keyed on record counts):
```bash
RECORD_RE='^0x[0-9a-f]+=[0-9a-f][0-9a-f]...[0-9a-f]$'
...
RECORDS=$(grep -cE "$RECORD_RE" "$OUT" || true)
```

**Blind invocation / one-command resume arm:** reuse the existing pattern — pre-staged script, single command, output to file, session record echo at lines 267-270:
```bash
echo "[INFO] ---- capture record (paste into the session log) ----"
echo "arm=$ARM trigger_time=$TRIG_TIME out=$OUT"
echo "sha256=$HASH"
```

**Failure policy comment block** (lines 44-54) — extend the header contract comment in the same style when the echo-2 mode lands (Pitfall 2 "update contract comment in the same change").

### `scripts/dsi_mmio_diff.sh` (utility, batch transform)

**Analog:** same file (diff engine; add `# DCS ID READ` parsing + fixtures)

**Section parser to extend** (lines 123-166) — the awk `parse_arm` handles `# RANGE` / `# SKIPPED` / `# NAMED OVERLAY` / `#`-generic. Add a branch for `# DCS ID READ` before the generic `if ($0 ~ /^#/) { next }` (line 143), emitting e.g. `D <arm> <line> <cmd> <avail> <ret>` reps, and treat `DCS`-prefixed rows as section state (never `W` warnings, never `R` records):
```bash
            if ($0 ~ /^# NAMED OVERLAY/) { inov = 1; insec = 0; next }
            if ($0 ~ /^#/) { next }
            if ($0 ~ /^[ \t]*$/) { next }
            if (inov) { next }
            if (insec) {
                if ($0 ~ valre) { ... print "R\t" ... }
                else { ... print "W\t" ... }
```

**Comparison-block emission pattern** — follow the state-row path: collect per-arm per-read state, join on read id, print a second markdown table after the register table (emission block lines 363-418, `## summary` END block lines 409-417). Vocabulary per RESEARCH: `answered` (bit29 set) / `timeout` (bit clear) / `missing-section` / `DCS SKIP`.

**Selftest fixture pattern to copy** (lines 428-449, 455-478) — new fixtures for the DCS section go here (present-both / present-one-arm / `DCS SKIP`, per Wave-0 gap):
```bash
selftest() {
    local passed=0 failed=0
    ...
    ok()   { echo "  [OK] $1";   passed=$((passed + 1)); }
    bad()  { echo "  [FAIL] $1" >&2; failed=$((failed + 1)); }
    expect_eq() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got: $2, want: $3)"; fi; }
    expect_has() { if grep -qE -- "$3" "$2"; then ok "$1"; else bad "$1 (pattern missing: $3)"; fi; }
    expect_count() { ... }
    ...
    local bootf="$d/boot_dsi_regs.txt" resumef="$d/broken_dsi_regs.txt"
    { echo "# RANGE 0x6b000-0x6c000 (1024 words)"; echo "0x6b000=0000000a"; } > "$bootf"
    run_diff "$bootf" "$resumef" "$d/a.md"
    expect_count "A: exactly one differing row (0x6b004)" "$d/a.md" '^\| 0x6b004 ' 1
```
Determinism assertion (fixture E, lines 559-578) must still hold — same inputs → byte-identical output.

**Header contract comment** (lines 7-25) — add the `# DCS ID READ` / `DCS` line grammar there in the same pinned-verbatim style.

### `scripts/tcon_i2c_sweep.sh` (NEW — controller, file-I/O)

**Analog:** `scripts/capture_dsi_dumps.sh` (device-side root script, OUTDIR default, log helpers, sha256, session record)

**Script skeleton:** start from 50-RESEARCH.md "Supporting Script Skeleton" (lines 413-432) — dynamic bus range from `i2cdetect -l`, `|| true` on every probe, single archive file. Then graft the capture-script conventions:

Logging helpers (capture lines 76-79):
```bash
log_info() { echo "[INFO] $*"; }
log_ok()   { echo "[OK] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_err()  { echo "[ERROR] $*" >&2; }
```
Root check + OUTDIR default (capture lines 103-106, 136-145):
```bash
[ "$(id -u)" -eq 0 ] || { log_err "must run as root ..."; exit 1; }
...
    if [ -n "${SUDO_USER:-}" ]; then
        OUTDIR="$(getent passwd "$SUDO_USER" | cut -d: -f6)/d330_dsi_capture"
    else
        OUTDIR="$PWD/d330_dsi_capture"
    fi
```
Checksum + record echo (capture lines 199, 267-270): `sha256sum "$OUT"` + `[INFO] ---- capture record ----` block.

Header comment style: usage, contract, failure policy — mirror capture lines 1-55. Include tool provenance (`i2cdetect --version` / `gpioinfo --version`) per RESEARCH version-verification note; degrade honestly to sysfs-only if tools absent (Assumption A4).

**Kit registration (after the run):** `scripts/prepare_safety_kit.sh --register <file>` — idempotent line replace, kit-relative paths only (prepare lines 93-110); artifacts must live inside `docs/dumps/re_kit/` (or pass `--kit-dir`). Tracepoint enable/disable stays in the capture session, not this script (locked decision); enable commands: `.planning/research/v10.0-tcon-hunt.md:194-198` (`echo 1 > /sys/kernel/tracing/events/i2c/i2c_{write,read,reply,result}/enable`).

### `.github/workflows/build-kernel.yml` (config, pipeline)

**Analog:** same file — the "Apply the display fixes and prove they landed" step (lines 105-139). Extend the `d330_dsi_dump.patch` block with 1-2 greps for the new symbols, per-comment pattern:
```yaml
          git apply -p1 "$GITHUB_WORKSPACE/patches/d330_dsi_dump.patch"
          grep -R 'i915_dsi_regs' drivers/gpu/drm/i915/display/
          grep -R 'bxt_dsi_pll_is_enabled' drivers/gpu/drm/i915/display/intel_dsi_dump_debugfs.c
```
Add e.g. `grep -R 'DCS ID READ' drivers/gpu/drm/i915/display/` immediately after, with a phase-50 comment paragraph in the same voice as lines 114-117. Do not disturb the other patches' apply blocks (falsified-candidate history, lines 109-110 comment).

### `docs/research/TCON_IDENTIFICATION.md` (NEW — docs, verdict report)

**Analog:** `docs/research/GOP_DSI_RE_FINDINGS.md` (verdict-style findings doc: provenance table, numbered sections, file:line citations, honest limitations)

Structure to copy (GOP lines 13-38):
```markdown
# GOP / DSI RE Findings (Windows path, WRE-01 / WRE-02 / WRE-03)

Status: **phase 45 working notes**. Every claim cites file + address + bytes (or line).
Kit: `docs/dumps/re_kit/` (checksummed, `MANIFEST.sha256` @ commit 731d383).
...
## 1. Provenance

| Artifact | Source | SHA-256 (first 16) |
|---|---|---|
```
Required content (CONTEXT): identity-or-proven-dead verdict + I2C conclusion (buses, PMIC bus 6, sideband in/out, pre-kernel GOP blind spot) + datasheet-gated candidate notes (AUO G101EAN01.x, ILI9881C, ST7701/ST7703, HX8394(F), NT36672(a)) vs AUO PnP 0xaf06/6104 + FRU 5D11A20220 + block-55 negative result. Every verdict carries machine evidence (capture shas, diff output) alongside reasoning. If the doc uses planner-discipline-sensitive terms, add the `<!-- planner-discipline-allow: ... -->` header comments like GOP lines 1-11 (e.g. `PMIC I2C bus 6` already allow-listed there).

### `docs/research/DSI_MMIO_DIFF.md` §6 (docs correction — label only)

**Analog:** same file §5.2 (already carries the corrected decode) + the row to change (line 368):
```markdown
| 0x6b004 | bits 30/21 clear (0x00080000 baseline) | 40280000 | status: no LP_RX_TIMEOUT marking |
```
Replace reading with (RESEARCH Correction Targets, line 404): `SPL_PKT_SENT | HS_TX_TIMEOUT | LOW_CONTENTION; LP_RX_TIMEOUT (bit 22) NOT set — "HS video stream never accepted by panel"`. Bit definitions verbatim from RESEARCH lines 357-364. **Fix only this row** (CONTEXT locks scope; §4.2 line 153 stays AS-IS). `0x6b010` (line 363) and `0x6b080` (line 365): add/keep open-anomaly flag with documented reason (write/read-back = register write, violates read-only contract), no value edits.

**Gate re-verification after the edit:** `bash scripts/test_dsi_mmio_evidence.sh` pins `>=10 file:line citation anchors`, `REASON_ANCHORS` distinctness (lines 46-47, 102-119), exactly ONE mechanism-claim section, and the D-08 handoff heading (lines 119-127) — a label-only row edit preserves all; run it plus `bash scripts/test_pitfalls_ledger.sh`.

## Shared Patterns

### Logging helpers
**Source:** `scripts/capture_dsi_dumps.sh:76-79`
**Apply to:** `scripts/tcon_i2c_sweep.sh`, echo-2 additions in `capture_dsi_dumps.sh`
```bash
log_info() { echo "[INFO] $*"; }
log_ok()   { echo "[OK] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_err()  { echo "[ERROR] $*" >&2; }
```

### Output contract: `#`-headers keep non-record rows out of the record regex
**Source:** `patches/d330_dsi_dump.patch:21-33` (kernel side) + `scripts/dsi_mmio_diff.sh:7-25` (parser side)
**Apply to:** the `# DCS ID READ` section (kernel emit) and its parser branch (diff)
```c
 *   NAME 0x<off>=<8-hex> <decode>   # NAMED OVERLAY section rows (the
 *                                   leading NAME keeps overlay rows out
 *                                   of the ^0x...=... record regex)
```
Rules: section strictly AFTER `# NAMED OVERLAY`; rows `DCS`-prefixed; never match `^0x...=`; `echo 1` output byte-compatible with historical captures.

### Kit registration
**Source:** `scripts/prepare_safety_kit.sh:70-73, 93-110`
**Apply to:** every new artifact (both DCS dumps, I2C sweep output, trace logs, diff outputs)
```bash
--register FILE   # idempotent sha256 line in MANIFEST.sha256; file must be inside the kit dir
# verify round-trip:
bash scripts/prepare_safety_kit.sh --verify --kit-dir docs/dumps/re_kit
```

### Static gates (must stay green; run per task)
**Source:** `scripts/test_dsi_mmio_evidence.sh`, `scripts/test_pitfalls_ledger.sh`, `scripts/dsi_mmio_diff.sh --selftest`
```bash
bash scripts/dsi_mmio_diff.sh --selftest && bash scripts/test_dsi_mmio_evidence.sh && bash scripts/test_pitfalls_ledger.sh
```

### CI apply-proof
**Source:** `.github/workflows/build-kernel.yml:105-139`
**Apply to:** the extended `d330_dsi_dump.patch` block (1-2 greps per patch, comment paragraph per patch)
```bash
git apply -p1 "$GITHUB_WORKSPACE/patches/d330_dsi_dump.patch"
grep -R 'i915_dsi_regs' drivers/gpu/drm/i915/display/
grep -R 'bxt_dsi_pll_is_enabled' drivers/gpu/drm/i915/display/intel_dsi_dump_debugfs.c
```

### Session record / machine evidence alongside verdicts
**Source:** `scripts/capture_dsi_dumps.sh:152-164, 267-270`
**Apply to:** capture echo-2 mode, tcon_i2c_sweep.sh
```bash
echo "[INFO] ---- capture record (paste into the session log) ----"
echo "arm=$ARM trigger_time=$TRIG_TIME out=$OUT"
echo "sha256=$HASH"
```

## No Analog Found

| File / Piece | Role | Data Flow | Reason | Fallback |
|------|------|-----------|--------|----------|
| `mipi_dsi_dcs_read()` / `mipi_dsi_generic_read()` call shape, `dsi_hosts[PORT_A]->device` traversal, bit-29 annotation | kernel read primitive | DSI read | Repo contains zero DCS-read code (node is MMIO-read-only today) | 50-RESEARCH.md Code Examples lines 208-237, 339-398 (mainline-source verified) |
| i2c tracepoint capture block (`i2c:i2c_*` enable/collect) | trace session step | event-driven (ftrace) | No tracepoint-collecting script exists (47/49 used markers only) | `.planning/research/v10.0-tcon-hunt.md:194-198` commands; scope conclusion to kernel-era traffic (Pitfall 5) |
| `kstrtouint_from_user` echo-2 parse | kernel write side | request-response | Existing side uses `kstrtobool_from_user` only | 50-RESEARCH.md Pitfall 2 (lines 304-307) |

## Metadata

**Analog search scope:** `patches/`, `scripts/`, `.github/workflows/`, `docs/research/`, `.planning/research/`
**Files scanned:** ~8 primary reads + repo-wide greps (i2c, tracepoints, kit registration)
**Pattern extraction date:** 2026-10-16
**Tracked-source gate:** all 10 named analog paths confirmed via `git ls-files` (non-empty); no mirror/gitignored paths emitted.
