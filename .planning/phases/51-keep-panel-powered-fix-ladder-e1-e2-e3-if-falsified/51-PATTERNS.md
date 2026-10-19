# Phase 51: Keep-Panel-Powered Fix Ladder (E1 → E2, E3 if falsified) - Pattern Map

**Mapped:** 2026-10-17
**Files analyzed:** 8 (5 modified/new in Wave 0, 2 conditional, 1 runbook block)
**Analogs found:** 7 / 8 (lazy E3 patch has a role-match; multi-file patch *format* has no precedent — see No Analog Found)

All analog paths verified git-TRACKED (`git ls-files` non-empty for every entry below).

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `patches/d330_dsi_keep_hot.patch` (NEW — E1 self-contained: DMI helper + flag A/B + skip sites + skip markers) | kernel patch (delivery) | call-site gating (kernel suspend path; no new data flow) | `patches/d330_dsi_panel_power_cycle.patch` | exact (same target file `vlv_dsi.c`, same helper, same marker voice; multi-file extension noted below) |
| `.github/workflows/build-kernel.yml` (drop two falsified applies per P3; add grep-proofs for keep-hot symbols + markers) | config (CI pipeline) | pipeline (apply → grep → build) | same file, apply step lines 105-148 | exact (self-extension) |
| `scripts/capture_dsi_dumps.sh` (new resume arms ~0-1 s / ~4 s post-wake) | controller (device capture script) | file-I/O + device trigger | same file | exact (self-extension) |
| X=Y operational-set check — `scripts/dsi_mmio_diff.sh` extension (6-register literal + selftest fixture) OR runbook grep one-liner (agent's discretion) | utility (transform/parser) | batch transform (single-file check → verdict line) | same file, selftest block lines 518-547 | exact (self-extension) |
| Marker-capture runbook block (enable → suspend → collect → disable, ≥18 s window; lands in `docs/research/RESUME_CAPTURE_PROTOCOL.md` or the phase plan doc — agent's discretion) | docs (runbook) | event-driven (ftrace/dmesg collection) | `docs/research/RESUME_CAPTURE_PROTOCOL.md` §Tracing rules + §Capture window | role-match |
| `docs/research/RESUME_FIX_LEDGER.md` (append rung row(s) + increment count line) | docs (ledger) | n/a (evidence registry) | same file, rows 30-32 + count line 58 | exact |
| `docs/research/NO_CLEAN_FIX_PROOF.md` (v10.0 falsification section — ONLY on full-ladder falsification) | docs (falsification closure) | n/a | same file, allow-marker header lines 3-10 | exact |
| lazy E3 instrumentation patch (ONE DCS read pre-INIT_OTP — built ONLY if E1 falsifies; never in E1/E2 CI kernels) | kernel patch (instrumentation) | request-response (kernel → panel DSI read) | `patches/d330_dsi_dump.patch` (echo-2 DCS section, Phase 50) | role-match (conditional file) |

## Pattern Assignments

### `patches/d330_dsi_keep_hot.patch` (kernel patch, call-site gating)

**Analog:** `patches/d330_dsi_panel_power_cycle.patch` (CI-proven, compiles green today — but dropped from the apply stack in the SAME iteration, see P3)

**Patch header/provenance shape** (power-cycle lines 1-33) — copy the voice verbatim, update the narrative to the E1 experiment:
```diff
From: Antigravity Autonomous Agent <engineering@lenovo-d330-fix.local>
Subject: [PATCH] drm/i915/dsi: <one-line change summary>
<prose paragraphs: what/why/sequencing-only disclaimer>
Signed-off-by: Antigravity Autonomous Agent <engineering@lenovo-d330-fix.local>
---
 drivers/gpu/drm/i915/display/vlv_dsi.c | N +++++
 1 file changed, N insertions(+)
--- a/drivers/gpu/drm/i915/display/vlv_dsi.c
+++ b/drivers/gpu/drm/i915/display/vlv_dsi.c
@@ ... @@
```

**DMI helper — copy shape verbatim** (power-cycle lines 44-55); safe to re-emit ONLY because P3 removes the power-cycle patch from the CI apply list in the same iteration (otherwise duplicate `static` function = build failure):
```c
static bool d330_82h0_panel(void)
{
	static bool dmi_checked;
	static bool is_d330_82h0;

	if (!dmi_checked) {
		is_d330_82h0 = dmi_match(DMI_PRODUCT_NAME, "82H0");
		dmi_checked = true;
	}

	return is_d330_82h0;
}
```

**Comment + marker style — repo precedent** (power-cycle lines 66-94: prose comment block naming the DMI model, the window rationale, and the sequencing-only disclaimer; then the gated block with a `drm_info` marker):
```c
	/*
	 * Lenovo IdeaPad D330-10IGL (82H0): ... rationale prose ...
	 * Sequencing only: ... no operational register values are written.
	 */
	if (d330_82h0_panel() &&
	    display->power.domains.init_wakeref) {
		drm_info(display->drm,
			 "[D330 82H0] resume: panel power-off settle before DSI init\n");
		intel_dsi_vbt_exec_sequence(intel_dsi, MIPI_SEQ_ASSERT_RESET);
		...
	}
```
E1's own skip markers replace the executed sequences with e.g. `drm_info(display->drm, "[D330 82H0] suspend: skip DISPLAY_OFF/ASSERT_RESET/POWER_OFF (keep-hot)\n");` (51-RESEARCH Code Example 3). Marker precedent chain: `D330DSIREG` `pr_info` (`d330_dsi_dump.patch:445`), `[D330 82H0] resume:` `drm_info` (power-cycle :88-89). **The patch must carry its own markers** — P2: `D330SEQ`/`D330GPIO` do not exist in any CI kernel today.

**Gate = `d330_82h0_panel() && display->suspend_commit_in_progress`** at every E1 skip site (Pattern 1, KEEP-01). Flag A set in `intel_display_driver_suspend()` immediately BEFORE `state = drm_atomic_helper_suspend(display->drm);`, cleared in `intel_display_driver_resume()` (51-RESEARCH Code Example 2, source-verified v7.0). Flag B `panel_keep_hot` set at E1's skipped `MIPI_SEQ_POWER_OFF`, cleared whenever `MIPI_SEQ_POWER_OFF` actually executes (51-RESEARCH Pattern 1 two-flag design; P4: flag A alone breaks E2).

**Cut list (E1)** — skip only, under the gate: `MIPI_SEQ_DISPLAY_OFF`, `MIPI_SEQ_ASSERT_RESET`, `MIPI_SEQ_POWER_OFF` in `intel_dsi_post_disable()`, and only the `is_vid_mode` SHUTDOWN `dpi_send_cmd` block in `intel_dsi_disable()`; keep BACKLIGHT_OFF + `intel_backlight_disable()`, fifo drain, `intel_dsi_port_disable`, `intel_dsi_unprepare()`, `intel_dsi_clear_device_ready()`, `bxt_dsi_pll_disable()`, `msleep(panel_off_delay)`, `panel_power_off_time` line (51-RESEARCH Pattern 2, verified keep-structure). **Never a blanket early-return from `intel_dsi_post_disable`** — banned ledger row 11 wording, skips host teardown (Anti-Patterns).

**Multi-file note:** this patch touches `vlv_dsi.c` + `intel_display_driver.c` (+ flag field on `struct intel_display`, likely `intel_display.h`). No repo patch is multi-file today (all four are single `diff --git`); standard unified-diff multi-file `format-patch` shape applies — content, not format, is what the analogs provide (51-RESEARCH Code Examples 1-3 supply the verified v7.0 code).

**E2 cut (second iteration, separate CI candidate):** skip `MIPI_SEQ_POWER_ON` + `MIPI_SEQ_INIT_OTP` in `intel_dsi_pre_enable()` behind flag B; keep DEASSERT_RESET, GLK link bring-up, DISPLAY_ON, backlight (51-RESEARCH Pattern 3). **Never in the E1 kernel** — one candidate per CI iteration.

### `.github/workflows/build-kernel.yml` (config, pipeline)

**Analog:** same file, step "Apply the display fixes and prove they landed" (lines 105-148)

**Apply + grep-proof block to imitate** (lines 111-129 stay UNTOUCHED; add the keep-hot block in the same voice, comment paragraph per patch):
```yaml
          git apply -p1 "$GITHUB_WORKSPACE/patches/d330_dsi_dump.patch"
          grep -R 'i915_dsi_regs' drivers/gpu/drm/i915/display/
          grep -R 'bxt_dsi_pll_is_enabled' drivers/gpu/drm/i915/display/intel_dsi_dump_debugfs.c
          grep -R 'DCS ID READ' drivers/gpu/drm/i915/display/
          grep -R 'mipi_dsi_dcs_read' drivers/gpu/drm/i915/display/intel_dsi_dump_debugfs.c
```

**P3 removal (same change):** delete the power-cycle apply + grep (lines 130-138) and the mipio apply + grep (lines 140-148) — both are ledger-falsified levers (rows 31/32) whose resume-window `MIPI_SEQ_POWER_OFF` fights keep-hot and whose DMI helper collides with the E1 patch's own definition. Replace with a one-paragraph comment citing rows 31/32, then:

```yaml
          git apply -p1 "$GITHUB_WORKSPACE/patches/d330_dsi_keep_hot.patch"
          grep -R 'd330_82h0_panel' drivers/gpu/drm/i915/display/vlv_dsi.c
          grep -R 'suspend_commit_in_progress' drivers/gpu/drm/i915/display/
          grep -R 'keep-hot' drivers/gpu/drm/i915/display/vlv_dsi.c
```
1-2 grep anchors per new symbol/marker string (51-RESEARCH Code Example 6). Warning signs (P3): `git apply` context failure, duplicate `d330_82h0_panel`, or resume ftrace showing `POWER_OFF` despite skips.

### `scripts/capture_dsi_dumps.sh` (controller, file-I/O + device trigger)

**Analog:** same file — add the ~0-1 s and ~4 s resume arms (CONTEXT locked) as new `case` arms.

**Arm/arg parsing to extend** (lines 135-144) — new names at agent's discretion (e.g. `resumefast`/`resumelate`, both echo-1):
```bash
[ $# -ge 1 ] && [ $# -le 2 ] || { usage; exit 2; }
ARM="$1"
case "$ARM" in
    boot|resume|boot2|resume2) ;;
    *) log_err "arm must be 'boot', 'resume', 'boot2' or 'resume2' (got '$ARM')"; usage; exit 2 ;;
esac
case "$ARM" in
    boot2|resume2) ECHO=2 ;;
    *)             ECHO=1 ;;
esac
```

**Header contract comment + usage text updated in the same change** (contract lines 38-89, usage lines 115-133) — pin the new arm semantics (trigger lands inside the ≥18 s wake window: dump #1 ~0-1 s pre-KWin-commit, dump #2 ~4 s post-commit; both echo-1 MMIO walks). Trigger is synchronous (returns after the walk, lines 191-218), so back-to-back blind invocation inside one window is safe; `EBUSY` = other trigger in flight.

**Session record echo — unchanged contract** (lines 344-347):
```bash
echo "[INFO] ---- capture record (paste into the session log) ----"
echo "arm=$ARM trigger_time=$TRIG_TIME out=$OUT"
echo "sha256=$HASH"
echo "bytes=$SIZE lines=$LINES records=$RECORDS skipped_sections=$SKIPCOUNT"
```
Floor/gate logic (sections f-g) applies unchanged to the new arms. Node-minor glob logic (lines 151-177) — do not touch (P8).

### `scripts/dsi_mmio_diff.sh` (utility, batch transform) — X=Y operational-set check

**Analog:** same file — either extend with a small operational-set verdict section, or pin a grep one-liner in the runbook (research's "Alternatives Considered" table prefers the extension with a fixture; agent's discretion).

**Selftest helpers to copy** (lines 521-542) — new fixture goes beside fixtures A-G (lines 548-686+):
```bash
selftest() {
    local passed=0 failed=0
    ...
    ok()   { echo "  [OK] $1";   passed=$((passed + 1)); }
    bad()  { echo "  [FAIL] $1" >&2; failed=$((failed + 1)); }
    # expect_eq <name> <got> <want>
    expect_eq() {
        if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got: $2, want: $3)"; fi
    }
    # expect_has <name> <file> <pattern>
    expect_has() {
        if grep -qE -- "$3" "$2"; then ok "$1"; else bad "$1 (pattern missing: $3)"; fi
    }
```
Fixture pattern: small hand-built dump files in `mktemp -d`, `run_diff`, `expect_count` on the emitted verdict line (50-PATTERNS fixture excerpt; determinism fixture E must still hold).

**Comparison-section emission model** (lines 478-498, the phase-50 `## DCS ID READ comparison` END block) — copy this shape for a `## X=Y operational set` section: emit iff the input carries the DSI range, print per-register expected-vs-actual with a single verdict line.

**The 6-register literal — binary criterion, verbatim** (51-CONTEXT fact 10 / 51-RESEARCH Pattern 4, sourced from `.planning/research/v10.0-keep-panel-powered.md:26`):
```
0x6b010=003fffff, 0x6b044=0000001d, 0x6b080/0x6b098=09051003, 0x6b088=0022000f, 0x6b094=1, 0x160018=00000115
```
Broken (X=Z) counterparts for fixture contrast: `0x6b010=0000b8ea, 0x6b044=0000001e, 0x6b080/0x6b098=0a051003, 0x6b088=0014000c, 0x160018=00000001` (`docs/research/DSI_MMIO_DIFF.md:117` + ledger rows 30-31).

Runbook one-liner alternative (if no extension): per-register `grep -E '^0x6b010=003fffff$' <dump>` × 6, all-hit = X=Y.

### Marker-capture runbook block (docs, event-driven collection)

**Analog:** `docs/research/RESUME_CAPTURE_PROTOCOL.md` — write the block in its voice, citing the same sources. No script exists for marker collection (50-PATTERNS "No Analog Found" — keep it a runbook block, not a script).

**Suspend mechanism** (protocol lines 68-74):
```markdown
Suspend with `rtcwake -m mem -s N` (choose N to cover the capture window).
For trace spans that must cover the whole suspend-plus-resume cycle in one
ftrace session, the prior on-device method was `rtcwake -m no -s 45` followed
by `systemctl suspend`.
```

**≥18 s window rule** (protocol lines 85-91) — a 6-second capture already produced one wrong conclusion; never ship shorter.

**Tracing rules — the load-bearing fact** (protocol lines 110-115): only compiled-in `D330`-prefixed `pr_info`/`drm_info` markers produce output; `drm.debug`/`dyndbg` is a verified dead end. E1's skip markers therefore land in `dmesg`/`journalctl -k`, and the block should say so explicitly (A2: historical "ftrace" evidence was captured from dmesg, `DSI_RESUME_TRACE_ANALYSIS.md:141`). Block shape: enable/collection is `dmesg`-based → user suspends → wake → collect dmesg excerpt covering the cycle → `dmesg | grep 'D330 82H0'` proves the skips → `prepare_safety_kit.sh --register`. Optional pre-check before spending a CI build: `dmesg | grep -c D330SEQ` on the installed kernel (expected 0, A1).

Battery arm (success path only): `upower -i $(upower -e | grep BAT)` before/after one 15-min S3 with keep-hot ON vs OFF; fallback `/sys/class/power_supply/BAT*` (A3). No analog — first use of upower in repo.

### `docs/research/RESUME_FIX_LEDGER.md` (docs, evidence registry)

**Analog:** same file — rows 30-32 are the shape to copy; count line at 58.

**Count line** (line 58, MUST be incremented to match actual rows):
```markdown
## Lever rows: 32
```

**5-cell row shape** (rows 30-32, abbreviated to structure):
```markdown
| 33 | <one-line rung description naming the lever> | `<alias regex>` | <disproof or success note with eyes-on verdict verbatim + machine evidence> | <artifact file list: plan/summary + kit files + dump shas> |
```
Gate rules (P9): `| n | name | `regex` | disproof | evidence |` exactly 5 cells; alias regex must hit at least one SOURCE_DOC; `test_pitfalls_ledger.sh` fails the count line or a parse error (`ledger_parses`). Row 11 (line 73) is the binding ban on E1's lever — E1 rows/plan lines matching its alias regex need narrow `<!-- planner-discipline-allow: <substring of the HIT LINE> -->` markers (P1; Example below in Shared Patterns). Never edit row 11's disproof cell without user sign-off.

### `docs/research/NO_CLEAN_FIX_PROOF.md` (docs, conditional falsification closure)

**Analog:** same file — only written on full-ladder falsification (CONTEXT). The file is a SOURCE_DOC for the ledger gate and already carries allow markers.

**Allow-marker header to extend** (lines 3-10) — append one marker per new quoted alias in the same edit (P10):
```markdown
<!-- planner-discipline-allow: bl_power -->
<!-- planner-discipline-allow: mem_sleep -->
<!-- planner-discipline-allow: modprobe -r -->
...
```
Section prose style: numbered sections, every claim with machine evidence + eyes-on verdict verbatim (§1 table shape, lines 21-29).

### Lazy E3 instrumentation patch (conditional — kernel patch, request-response)

**Analog:** `patches/d330_dsi_dump.patch` via 50-PATTERNS (the echo-2 DCS read section is the exact code to reuse: bounded waits, `avail` bit-29 annotation, "ret alone is never success")

Shape: one pre-INIT_OTP DCS read (0x04/0xDA-0xDB-0xDC) over the re-trained link via `intel_dsi_host_transfer()` (v7.0 `vlv_dsi.c` verified) + marker line; verdict comes from the X=Y dump + ftrace/GPIO-144 rail evidence, NOT the read (dead path: `ret=4 avail=0 data=00 00 00` ×3, `TCON_IDENTIFICATION.md:11-18`). Built ONLY after E1 falsification, in its own CI iteration; ambiguous → Phase 53 buy-gate (CONTEXT locked).

## Shared Patterns

### Logging helpers (device scripts)
**Source:** `scripts/capture_dsi_dumps.sh:110-113`
**Apply to:** any new device-side script block; runbook commands use the same `[INFO]/[OK]/[WARN]/[ERROR]` prefixes when echoed
```bash
log_info() { echo "[INFO] $*"; }
log_ok()   { echo "[OK] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_err()  { echo "[ERROR] $*" >&2; }
```

### Allow-marker for gated aliases (binding for every PLAN/SUMMARY/edit this phase)
**Source:** `scripts/test_pitfalls_ledger.sh:217-228` (substring gate) + `docs/research/NO_CLEAN_FIX_PROOF.md:3-10`
**Apply to:** every `*-PLAN.md`/`-SUMMARY.md` line tripping row 11's alias regex (`early-return from|keep the panel powered|intel_dsi_post_disable`)
```markdown
- E1 skips the teardown inside intel_dsi_post_disable() during the suspend commit only.
<!-- planner-discipline-allow: intel_dsi_post_disable() during the suspend commit -->
```
Marker text must appear verbatim inside the hit LINE; one marker exempts every line in that file containing it; the marker line itself must not be a hit.

### Static gates (must stay green; run after every doc/plan edit)
**Source:** 50-04-SUMMARY.md:62 (verified counts)
```bash
bash scripts/dsi_mmio_diff.sh --selftest && bash scripts/test_dsi_mmio_evidence.sh && bash scripts/test_pitfalls_ledger.sh
```
Expected: selftest 52/0 → grows by the new fixture · evidence 7/0 · ledger 4/0.

### Kit registration (every new artifact)
**Source:** `scripts/prepare_safety_kit.sh` (`--register`/`--verify`; 50-PATTERNS excerpt)
```bash
bash scripts/prepare_safety_kit.sh --register <file>   # file must live in the kit dir
bash scripts/prepare_safety_kit.sh --verify --kit-dir docs/dumps/re_kit
```
Apply to: both resume dumps, dmesg/marker excerpts, diff outputs, session records.

### Deploy + rollback (unchanged script; env override only)
**Source:** `scripts/deploy_d330_kernel.sh:8-18, 20-27, 70-71` (51-RESEARCH P6/P7)
**Apply to:** every rung's deploy session
```powershell
$env:D330_ROLLBACK_DEB='/home/santiago/<retained-rollback>.deb'; $env:D330_ROLLBACK_SHA='<sha>'
```
Default is the stale d47 deb — ALWAYS override. Password on ssh stdin only (`sudo -S -p ''`); WSL is broken (`0x8007054f`) — pwsh-native ssh (`ssh -i $HOME/.ssh/d330_ed25519 ... santiago@192.168.2.195`). Never copy the plaintext password from `scripts/verify_d330_deploy.sh:8` into any new file.

### Marker style (kernel side — the ftrace/dmesg proof contract)
**Source:** `patches/d330_dsi_panel_power_cycle.patch:88-89` + `patches/d330_dsi_dump.patch:445`
**Apply to:** every skip site in the keep-hot patch; the matching CI grep-proof
```c
drm_info(display->drm, "[D330 82H0] suspend: skip DISPLAY_OFF/ASSERT_RESET/POWER_OFF (keep-hot)\n");
pr_info("D330DSIREG: snapshot captured (%u words, %zu bytes buffered)\n", ...);
```

## No Analog Found

| File / Piece | Role | Data Flow | Reason | Fallback |
|------|------|-----------|--------|----------|
| Multi-file kernel patch (`vlv_dsi.c` + `intel_display_driver.c` + header flag field in one `.patch`) | kernel patch format | call-site gating | All four repo patches are single-file; no multi-file apply precedent in CI | standard unified-diff multi-file format-patch; content from 51-RESEARCH Code Examples 1-3 (v7.0 source-verified) + power-cycle voice |
| ftrace/dmesg marker collection *script* | device collector | event-driven | No marker-collecting script exists (47/49 used ad-hoc dmesg) — CONTEXT asks for a runbook block, not a script | RESUME_CAPTURE_PROTOCOL.md voice + E1 patch's own `drm_info` markers; `dmesg \| grep 'D330 82H0'` |
| Battery quantification (`upower` energy-rate deltas) | measurement step | batch (before/after) | First use of upower in the repo | `/sys/class/power_supply/BAT*` fallback (A3); 51-CONTEXT Measurement section |
| X=Y operational-set *check* as a first-class diff-tool verdict | utility | batch transform | Existing tool does full diff + exclusion table only; the 6-register literal lives in docs | dsi_mmio_diff.sh extension with fixture (recommended) or runbook grep one-liner × 6 |

## Metadata

**Analog search scope:** `patches/`, `scripts/`, `.github/workflows/`, `docs/research/`, `.planning/research/`
**Files scanned:** 8 primary reads (power-cycle patch full, workflow full, capture script full, diff tool targeted ranges, ledger rows, protocol sections, NO_CLEAN header) + tracked-source greps
**Pattern extraction date:** 2026-10-17
**Tracked-source gate:** all named analog paths confirmed via `git ls-files` (non-empty); no mirror/gitignored paths emitted.
