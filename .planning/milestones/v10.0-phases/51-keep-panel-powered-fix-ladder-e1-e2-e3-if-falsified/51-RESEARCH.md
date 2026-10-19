# Phase 51: Keep-Panel-Powered Fix Ladder (E1 → E2, E3 if falsified) - Research

**Researched:** 2026-10-17
**Domain:** i915 GLK DSI panel power lifecycle across S3 (kernel patch + device-session experiment ladder)
**Confidence:** MEDIUM-HIGH (design doc + kernel source + repo instrument chain all opened this session; two gaps flagged in Assumptions Log)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions (verbatim, 51-CONTEXT.md:18-38)

- **E3 Redefinition (post-Phase-50):** E3's verdict comes from the X=Y operational-set dump taken after E1's cut + eyes-on + ftrace/GPIO-144 rail evidence — NOT from a DCS ID read (proven dead: `ret=4 avail=0 data=00 00 00` ×3 in `docs/research/TCON_IDENTIFICATION.md`). The pre-INIT_OTP DCS read still runs ONCE per E3 session as a zero-expectation informative bonus (it costs nothing and records the dead-path state at wake). If E1 falsifies and E3's dump/ftrace verdict is ambiguous → escalate to Phase 53 buy-gate immediately; E4 wake-order variants are skipped (E4 needs a live TCON, which no software probe can show). E3 is built LAZILY — only when E1 falsifies, never in the E1/E2 CI kernels (one candidate per CI iteration, success criterion 4).
- **Device Sessions & Cadence:** One user-authorized device session per rung: deploy (sha-verified rollback first) → suspend → wake → ftrace/dump evidence → eyes-on verdict. On E1 success: 5 user-triggered resume cycles to prove X=Y holds + battery quantification in the same session. Fail-fast: first falsifying machine evidence ends the rung — evidence archived, ledger row appended, no same-day retries. Sessions run as soon as the CI build is green (no artificial scheduling delay).
- **Measurement & Artifacts:** `capture_dsi_dumps.sh` extended with resume arms for ~0-1s and ~4s post-wake captures inside the ≥18s window discipline. Battery cost (success-path only): one 15-min S3 with keep-hot ON vs OFF, battery % + upower energy-rate deltas. Dead-experiment exclusions are LOCKED: no host-MMIO holds, no defer-PPS-to-resume, no `disable_power_well=0`, no s2idle escape (all falsified, `v10.0-keep-panel-powered.md` §3). Every rung appends a `RESUME_FIX_LEDGER.md` row (success or failure); full ladder falsification writes the `NO_CLEAN_FIX_PROOF.md` v10.0 section.
- **the agent's Discretion:** All implementation choices at the agent's discretion: exact patch shape, ftrace event set details, dump-comparison tooling extensions, ledger row wording, CI workflow tweaks. DMI gate implementation (`d330_82h0_panel()` helper) details per research `v10.0-keep-panel-powered.md` §1.

### Deferred Ideas (OUT OF SCOPE, verbatim, 51-CONTEXT.md:74-77)

- TCON datasheet hunt (wake/reset requirements) — gated on Phase 53 wire-level identification; no public FRU→glass cross-reference exists
- E4 wake-order variants — only reachable if E3 shows a live TCON, which the redefined E3 cannot show (effectively dead pending Phase 53)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| KEEP-01 | `d330_82h0_panel()` DMI helper + suspend-commit flag on `struct intel_display`, gate fires only on `82H0` during the suspend commit — never on KWin's post-resume modeset or user modesets | §Architecture Patterns (Pattern 1 suspend-only discriminator, two-flag design), §Code Examples 1/2 (helper verbatim from `d330_dsi_panel_power_cycle.patch:44-55`, flag placement verified against v7.0 `intel_display_driver.c`) |
| KEEP-02 | E1 skips DISPLAY_OFF / ASSERT_RESET / POWER_OFF + SHUTDOWN DCS; keeps BACKLIGHT_OFF + all host-side teardown; ftrace proves skips | §Pattern 2 (E1 cut list against verified v7.0 `vlv_dsi.c` code), §Common Pitfalls P2 (marker gap — must be closed by E1 patch's own markers), §Validation (evidence gates) |
| KEEP-03 | E2 skips POWER_ON + INIT_OTP behind keep-hot flag; keeps DEASSERT_RESET, GLK link bring-up, DISPLAY_ON, backlight; success = X=Y set in ~4s dump + eyes-on | §Pattern 3 (E2 cut list), §Pattern 4 (two-dump measurement), X=Y literal quoted in §Pattern 4 |
| KEEP-04 | E3 (only if E1 falsifies): DCS ID read pre-INIT_OTP + dump/ftrace/GPIO-144 verdict, escalation decision → Phase 53, ledger rows | §Pattern 5 (lazy E3 shape), CONTEXT locked redefinition, Phase 50 dead-path evidence (`TCON_IDENTIFICATION.md:11-18`) |
| KEEP-05 | Honest verdict either way: image after S3 held across cycles + battery quantified, OR full falsification with machine evidence + `NO_CLEAN_FIX_PROOF.md` v10.0 section | §Common Pitfalls P1/P12 (ledger-row-11 reconciliation), §Code Examples 4 (ledger row append mechanics), §Validation (gates) |
</phase_requirements>

## Summary

Phase 51 executes the keep-panel-powered ladder: E1 skips the three panel-facing VBT calls (`MIPI_SEQ_DISPLAY_OFF`, `MIPI_SEQ_ASSERT_RESET`, `MIPI_SEQ_POWER_OFF`) plus the video-mode SHUTDOWN DCS at suspend while keeping BACKLIGHT_OFF and all host-side teardown; E2 skips `MIPI_SEQ_POWER_ON` + `MIPI_SEQ_INIT_OTP` at resume behind a keep-hot flag; E3 (lazy, only on E1 falsification) is the redefined dump/ftrace/GPIO-144 rail-survival discriminator with one zero-expectation pre-INIT_OTP DCS read. The design doc `.planning/research/v10.0-keep-panel-powered.md` is the phase's single source of experiment logic; its §1/§3/§4 content was re-verified against torvalds/linux v7.0 raw source this session (suspend/resume hooks and all three DSI hooks' code content match the doc).

Three findings change how the phase must be planned:

1. **Ledger row 11 already bans E1's lever** — `| 11 | Keep the panel powered (early-return from intel_dsi_post_disable) | early-return from\|keep the panel powered\|intel_dsi_post_disable | still black, so the panel does not survive suspend even when i915 leaves it alone |` [VERIFIED: docs/research/RESUME_FIX_LEDGER.md:73]. The ledger is binding for every plan. E1 is still executable, but every PLAN/SUMMARY line that trips alias regexes must carry narrow `<!-- planner-discipline-allow: <substring> -->` markers, and the plan must frame E1 as the machine-evidenced, E2-paired ladder (row 11 was an eyes-on-only early-return with no dump/ftrace evidence of what actually happened to the rails, and no paired warm-resume skip).
2. **The D330SEQ/D330GPIO markers do not exist in the CI kernel** — repo-wide search this session found `D330SEQ`/`D330GPIO` only in prose docs, never in `patches/*.patch` or the CI workflow, and `.github/workflows/build-kernel.yml:111-148` applies only four patches, none carrying markers [VERIFIED: workflow + grep this session]. KEEP-02's "ftrace proves the skips" therefore requires the E1 patch to carry its own skip markers (precedent: `pr_info`/`drm_info` markers — `D330DSIREG` in the dump patch, `[D330 82H0] resume:` in the power-cycle patch). One cheap on-device grep (`dmesg | grep -c D330SEQ`) can confirm before the CI build is spent.
3. **Two falsified patches are still applied by every CI build** — `build-kernel.yml:138` applies `d330_dsi_panel_power_cycle.patch` (ledger row 31: runs `MIPI_SEQ_POWER_OFF` at the top of `intel_dsi_pre_enable()` in the resume window) and `:147` applies `d330_dsi_mipio_reset.patch` (row 32) [VERIFIED: .github/workflows/build-kernel.yml:138,147]. The row-31 patch cuts GPIO 144 again at resume and would clear E1's keep-hot state; it also *defines* `d330_82h0_panel()`, so an E1 patch re-defining the helper alongside it would fail to compile. Recommended: drop both falsified applies in the E1 CI iteration and let the E1 patch be self-contained (helper + flags + markers in one file).

**Primary recommendation:** plan E1 as a self-contained `vlv_dsi.c` patch that (a) reuses the exact helper shape already proven in CI, (b) adds its own suspend/resume skip markers, (c) rides a CI apply list that drops the two falsified pre-enable patches — then run the one-session fail-fast measurement exactly as CONTEXT locks it.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Panel-side teardown skip at suspend (E1) | Kernel (i915 DSI driver, `vlv_dsi.c`) | CI (patch delivery) | Only tier that reaches `intel_dsi_post_disable()`; PMIC rail hold is a side effect of not driving GPIO 144 low |
| Warm-resume enable skip (E2) | Kernel (`intel_dsi_pre_enable`) | — | Same function the KWin commit invokes; gated by driver flag, not caller identity |
| Suspend-only discriminator flag | Kernel (`intel_display_driver_suspend/resume`) | — | No encoder-hook-time flag exists; set before `drm_atomic_helper_suspend()`, cleared in resume so KWin/user modesets never trip it |
| Rail-survival evidence (E3) | Device measurement (dump node + ftrace/dmesg + eyes-on) | Kernel (lazy one-shot DCS read) | Verdict is machine evidence archived from the device session; DCS read is a zero-expectation bonus |
| Evidence capture and comparison | Userspace scripts (`capture_dsi_dumps.sh`, `dsi_mmio_diff.sh`) | debugfs node (kernel) | Existing instrument chain; extends with new arms only |
| Patch build + apply proof | CI (GitHub Actions `build-kernel.yml`) | — | Device cannot compile; one candidate per iteration |
| Deploy + rollback safety | Host script (`deploy_d330_kernel.sh`) | Device dpkg | sha-verified discipline already proven 5+ times |
| Verdict authority | Human (user eyes-on) | — | Machine evidence corroborates, never replaces the user's verdict |

## Standard Stack

### Core

| Component | Version / Pin | Purpose | Why Standard |
|-----------|---------------|---------|--------------|
| Ubuntu kernel source (`apt-get source linux`) | pinned from device `uname -r` (currently `7.0.0-38-generic` era; workflow default `'7.0.0-38-generic'` / release `questing`) [VERIFIED: .github/workflows/build-kernel.yml:11-16] | CI build base for the patched `.deb` | Same pipeline that produced every 47/49/50 kernel; config seeded from the target kernel's own `/boot/config-*` (build-kernel.yml:61-94) |
| i915 DSI driver (`drivers/gpu/drm/i915/display/vlv_dsi.c`, `intel_display_driver.c`, `intel_dsi_vbt.c`) | torvalds/linux tag `v7.0` content verified via raw fetch this session | E1/E2 patch targets | The only code that runs the VBT sequences driving GPIO 144/160 [VERIFIED: torvalds/linux v7.0 raw `vlv_dsi.c` — `intel_dsi_post_disable` ends `MIPI_SEQ_ASSERT_RESET` → `msleep(panel_off_delay)` → `MIPI_SEQ_POWER_OFF` → `panel_power_off_time = ktime_get_boottime()`; `intel_dsi_pre_enable` runs `MIPI_SEQ_POWER_ON` → `msleep(panel_on_delay)` → `MIPI_SEQ_DEASSERT_RESET` → GLK link bring-up → `MIPI_SEQ_INIT_OTP` → `DISPLAY_ON` → backlight] |
| GitHub Actions workflow `.github/workflows/build-kernel.yml` | repo-tracked (manual `workflow_dispatch`, ~40 min, `timeout-minutes: 240`) [VERIFIED: build-kernel.yml:1-24] | Build + apply-proof of the E1 kernel | Grep-proofs per patch block are the standing CI contract (lines 105-148) |
| `gh` CLI | 2.92.0 on this host [VERIFIED: probed this session] | `gh workflow run build-kernel.yml` + `gh run view <id>` | One candidate per CI iteration discipline |

### Supporting (existing repo tooling — extend, do not rebuild)

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `scripts/deploy_d330_kernel.sh` | sha-verified-before-dpkg deploy, distinct incoming name, rollback never removed [VERIFIED: scripts/deploy_d330_kernel.sh:8-18] | Every rung's deploy; override `D330_ROLLBACK_DEB`/`D330_ROLLBACK_SHA` for the Phase 51 rollback asset |
| `scripts/capture_dsi_dumps.sh` | arm-based MMIO capture (`boot\|resume\|boot2\|resume2`), record-floor gates, session-record echo [VERIFIED: scripts/capture_dsi_dumps.sh:26,137-144] | Both per-session dumps; needs new ~0-1s / ~4s resume-arm naming per CONTEXT |
| `scripts/dsi_mmio_diff.sh` | X=Y/X=Z comparison, per-range exclusion table, `--selftest` fixtures [VERIFIED: 50-PATTERNS.md:145-180] | Post-session diff; extend parser only if a new dump section is added |
| `scripts/prepare_safety_kit.sh --register/--verify` | sha256 evidence round-trip in `docs/dumps/re_kit/MANIFEST.sha256` | Register every new dump/trace/diff artifact |
| `scripts/test_pitfalls_ledger.sh` | banned-lever gate over PLAN/SUMMARY + `docs/research/*.md` [VERIFIED: scripts/test_pitfalls_ledger.sh:1-41] | Run after every doc/plan edit |
| bash gates: `dsi_mmio_diff.sh --selftest` (52/0), `test_dsi_mmio_evidence.sh` (7/0), `test_pitfalls_ledger.sh` (4/0) [VERIFIED: 50-04-SUMMARY.md:62] | static verification, ~30 s | per-task sampling |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| CI-built `.deb` kernel | on-device DKMS/module swap | Rejected: PITFALLS shortcut table — one bad module = unbootable panel, requires live USB; CI + rollback is the proven path |
| Ad-hoc device tree rebuilds for markers | markers inside the E1 patch | Rejected: markers were historically built ad hoc ("rebuilt into the 7.0.0-38 tree", `DSI_RESUME_TRACE_ANALYSIS.md:141`) and never committed; that is exactly why they are missing today |
| `dsi_mmio_diff.sh` full diff as E1/E2 verdict | dedicated X=Y operational-set check (6 registers) | Full diff is necessary but slow to read at 0-1s; the 6-register literal is the binary criterion — cheap to grep |

**Installation:** none this phase (no new packages; see Package Legitimacy Audit).

## Package Legitimacy Audit

No external packages are installed by this phase. The patch stack, scripts, and CI workflow are all repo-internal; kernel build dependencies are preinstalled by the workflow's own `apt-get` step (build-kernel.yml:38-45) and are CI-side only.

| Package | Registry | Verdict | Disposition |
|---------|----------|---------|-------------|
| — (none) | — | — | — |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture (one rung = one CI iteration + one device session)

```
host (Windows, pwsh + Git Bash)
  │  edit patch → git commit → gh workflow run build-kernel.yml
  ▼
GitHub Actions: apt-get source → git apply stack (apply + grep-proofs) → bindeb-pkg → artifact
  │  gh run download / sha256
  ▼
deploy_d330_kernel.sh: local sha → remote rollback sha (D330_ROLLBACK_DEB override) → scp
  → remote sha → dpkg -S stdin → reboot → wait ssh        [password: stdin only]
  ▼
device santiago-D330 (user-triggered session)
  │  arm ftrace/dmesg capture → user suspends (S3 ≥45 s / 15-min for battery arm)
  │  wake → dump #1 (~0-1 s, pre-KWin-commit) → dump #2 (~4 s, post-commit) → both < 18 s window
  │  ftrace/dmesg: skips present?   eyes-on: image?
  ▼
verdict split:
  X=Y + image            → 5 user cycles + battery arm → ledger success row → (E2 if needed)
  X=Z / black            → fail-fast: archive evidence → ledger row 33+ → E3 built lazily
  ambiguous after E3     → escalate Phase 53 buy-gate (CONTEXT locked)
```

### Pattern 1: Suspend-only discriminator (KEEP-01)
**What:** one bool on `struct intel_display` set in `intel_display_driver_suspend()` immediately before the atomic suspend, cleared in `intel_display_driver_resume()`; gate = `d330_82h0_panel() && display->suspend_commit_in_progress`.
**When to use:** every E1 skip site in `intel_dsi_post_disable()` / `intel_dsi_disable()`.
**Why this shape:** `intel_dsi_post_disable()` runs for *every* modeset/DPMS-off, and KWin's post-resume modeset runs ~3 s after wake (marker-trace proof, `DSI_RESUME_TRACE_ANALYSIS.md:150-157`) — a caller-identity gate would misfire; a suspend-window flag cannot. Verified placement: `intel_display_driver_suspend()` sets state then calls `state = drm_atomic_helper_suspend(display->drm);` [VERIFIED: torvalds/linux v7.0 `intel_display_driver.c` raw fetch — function body: `state = drm_atomic_helper_suspend(display->drm); ... display->restore.modeset_state = state;`], flag must be set BEFORE that call; `intel_display_driver_resume()` clears it [CITED: v10.0-keep-panel-powered.md:66].
**Two-flag design (agent's discretion, recommended):** flag A `suspend_commit_in_progress` (suspend-side gate, cleared in resume) is *not* available to E2 — it is already cleared by the time KWin's commit runs `intel_dsi_pre_enable()`. E2 needs flag B `panel_keep_hot`: set when E1 skips `MIPI_SEQ_POWER_OFF`, cleared whenever `MIPI_SEQ_POWER_OFF` actually executes (per design doc: "Keep-hot flag (set at E1's skipped suspend, cleared whenever POWER_OFF runs)" [CITED: v10.0-keep-panel-powered.md:102]). Two bools, one each on `struct intel_display` / `struct intel_dsi`.

### Pattern 2: E1 cut list (patch site map, v7.0 content verified)
**What:** in `intel_dsi_post_disable()` skip `intel_dsi_vbt_exec_sequence(intel_dsi, MIPI_SEQ_DISPLAY_OFF)`, `MIPI_SEQ_ASSERT_RESET`, `MIPI_SEQ_POWER_OFF`; in `intel_dsi_disable()` skip only the `is_vid_mode` SHUTDOWN `dpi_send_cmd` block; keep `MIPI_SEQ_BACKLIGHT_OFF` + `intel_backlight_disable()`; keep fifo drain, `intel_dsi_port_disable`, `intel_dsi_unprepare()`, `intel_dsi_clear_device_ready()` (GLK ULPS + MIPI-IO power-gate), `bxt_dsi_pll_disable()`.
**When to use:** only under the Pattern-1 gate.
**Verified keep-structure** [VERIFIED: torvalds/linux v7.0 `vlv_dsi.c` raw fetch, exact order]: `drm_dbg_kms` → vblank/scaler off → fifo-empty wait + `intel_dsi_port_disable` + `usleep_range(2000, 5000)` → `intel_dsi_unprepare` → (`TEAR_OFF` if cmd) → `MIPI_SEQ_DISPLAY_OFF` → `intel_dsi_clear_device_ready` → (broxton-only regulator block, skipped on GLK) → `bxt_dsi_pll_disable` → `MIPI_SEQ_ASSERT_RESET` → `msleep(intel_dsi->panel_off_delay)` → `MIPI_SEQ_POWER_OFF` → `panel_power_off_time = ktime_get_boottime()`.
**`panel_power_off_time` line:** leave as-is (design doc rationale: stale/updated timestamp cannot stall `intel_dsi_wait_panel_power_cycle()` because resume follows suspend by ≫5000 ms in every session) [CITED: v10.0-keep-panel-powered.md:94].

### Pattern 3: E2 warm-resume enable
**What:** in `intel_dsi_pre_enable()`, behind flag B, skip `intel_dsi_vbt_exec_sequence(intel_dsi, MIPI_SEQ_POWER_ON)` and `MIPI_SEQ_INIT_OTP` (GPIO 160 1/0/1 TCON reset toggle — the one call that would throw away kept state); keep `MIPI_SEQ_DEASSERT_RESET`, GLK `glk_dsi_enable_io` + `intel_dsi_device_ready` + prepare, `MIPI_SEQ_DISPLAY_ON` (DCS 0x11 + 0x29), port enable, backlight enable + `MIPI_SEQ_BACKLIGHT_ON`.
**Verified flow** [VERIFIED: torvalds/linux v7.0 `vlv_dsi.c` raw fetch]: `intel_dsi_wait_panel_power_cycle` → PLL disable/enable → `MIPI_SEQ_POWER_ON` → `msleep(panel_on_delay)` → `MIPI_SEQ_DEASSERT_RESET` → (`glk_dsi_enable_io` returns `cold_boot`, GLK prepare) → `intel_dsi_device_ready` → `MIPI_SEQ_INIT_OTP` → video-mode: `msleep(20)`, `TURN_ON`, `msleep(100)`, `MIPI_SEQ_DISPLAY_ON`, `intel_dsi_port_enable` → `intel_backlight_enable` + `MIPI_SEQ_BACKLIGHT_ON`.
**Never built in CI together with E1's first iteration** — one candidate per iteration (CONTEXT: success criterion 4).

### Pattern 4: Two-dump measurement inside the ≥18 s window
**What:** dump #1 at ~0-1 s post-exit (pre-KWin-commit; expects DC9 reset defaults), dump #2 at ~4 s post-exit (post-commit — the discriminator). Binary criterion = X=Y operational set, quoted verbatim from the design doc fact 10: ``0x6b010=003fffff, 0x6b044=0000001d, 0x6b080/0x6b098=09051003, 0x6b088=0022000f, 0x6b094=1, 0x160018=00000115`` [VERIFIED: .planning/research/v10.0-keep-panel-powered.md:26, read this session; identical literal in 51-CONTEXT.md:51]. Broken (X=Z) counterparts for contrast: `0x6b010=0000b8ea, 0x6b044=0000001e, 0x6b080/0x6b098=0a051003, 0x6b088=0014000c, 0x160018=00000001` [VERIFIED: docs/research/DSI_MMIO_DIFF.md:117 row + ledger rows 30-31 literals read this session].
**When to use:** every rung, both dumps, both arms' session record echoed and kit-registered.

### Pattern 5: Lazy E3 (only on E1 falsification)
**What:** instrumentation-only patch: one DCS read (0x04/0xDA-0xDB-0xDC, already proven dead: `ret=4 avail=0 data=00 00 00` ×15, `TCON_IDENTIFICATION.md:11-18`) sent pre-INIT_OTP over the re-trained link via `intel_dsi_host_transfer()` (verified present at v7.0 `vlv_dsi.c`, `return 4 + packet.payload_length;` — `ret` alone is never success) + the X=Y-set dump + ftrace/GPIO-144 rail evidence as the real verdict; ambiguous → Phase 53 buy-gate.
**When to use:** never in E1/E2 CI kernels.

### Anti-Patterns to Avoid
- **Blanket early-return from `intel_dsi_post_disable`** — the exact wording of banned ledger row 11, and it skips host-side teardown the resume path expects (fifo drain, `clear_device_ready`, PLL off). Gate each *panel-facing call* instead [VERIFIED: ledger row 11 quote above; keep-structure verified in v7.0 source].
- **Gating on the caller ("is this suspend?")** — i915's own resume never reaches `pre_enable`; KWin's commit does ~3 s later; there is no caller discriminator. Flag only.
- **Skipping BACKLIGHT_OFF** — battery/LED cost and a separately disproven lever; CONTEXT keeps it.
- **Building E2 or E3 into the E1 kernel** — violates one-candidate-per-iteration (CONTEXT success criterion 4).
- **Re-defining `d330_82h0_panel()` while `d330_dsi_panel_power_cycle.patch` is still applied** — duplicate static function = build failure (see Common Pitfalls P3).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| sha-verified deploy + rollback | bespoke scp/dpkg sequence | `deploy_d330_kernel.sh` (+ `D330_ROLLBACK_DEB/SHA` env) | Clobber-incident discipline baked in ("There is no `rm` anywhere in this file", :18); T-50-09 closed |
| MMIO capture + floor checks | raw `devmem`/`intel_reg dump` reads | `capture_dsi_dumps.sh` (snapshot node, contract-validated) | snapshot-by-construction; `intel_reg` mis-decodes GLK pipe regs (PITFALLS) |
| X=Y/X=Z comparison | ad-hoc grep per session | `dsi_mmio_diff.sh` (+ small operational-set check extension) | per-range exclusion table + determinism selftest already exist |
| Evidence registration | manual sha notes | `prepare_safety_kit.sh --register` + `--verify` | round-trip proven in 47/49/50 |
| Banned-lever compliance | reviewing docs by eye | `test_pitfalls_ledger.sh` | regex gate catches reworded re-proposals too (`grep -Ein` per alias) |
| DCS read plumbing | new LP-read driver code | existing `i915_dsi_regs` echo-2 node (Phase 50) | bounded waits + `avail` annotation already hardened |
| Battery drain measurement | custom coupler/logging | `upower` energy-rate + battery % (device-side, TUI-free) [ASSUMED present — see A3] | standard on the KDE/Ubuntu image; fallback `/sys/class/power_supply/BAT*` |

**Key insight:** this phase's risk is experiment contamination (wrong kernel state), not code complexity — every measurement primitive already exists and is proven; the only genuinely new code is ~30 lines of gated skips + markers + one flag.

## Common Pitfalls

### P1: Ledger row 11 bans E1's own lever (binding gate)
**What goes wrong:** any `*-PLAN.md`/`*-SUMMARY.md` line matching `early-return from|keep the panel powered|intel_dsi_post_disable` (case-insensitive) fails `test_pitfalls_ledger.sh` → build red.
**Why it happens:** E1 *is* row 11's lever, re-attempted with new machine evidence; the gate cannot tell the difference.
**How to avoid:** (1) run the gate early, collect hit lines; (2) for each hit add one `<!-- planner-discipline-allow: <substring of the HIT LINE> -->` HTML-comment line in that file — marker text must appear verbatim inside the hit line (gate logic: `[[ "$text" == *"$a"* ]]`, `test_pitfalls_ledger.sh:217-228` [VERIFIED]); (3) frame E1 in the plan as the measured ladder (row 11 evidence was eyes-on-only with no dump/ftrace, no suspend-discriminator, no E2 pairing — `DISPLAY_RESUME_CCS_MODIFIER.md:200,245-247` [VERIFIED]); (4) *never* the marker line itself contains the alias as prose without it being a real hit-line substring.
**Warning signs:** gate output `BANNED LEVER: ... at <file>:<line>`.

### P2: D330SEQ/D330GPIO markers do not exist in the CI kernel
**What goes wrong:** KEEP-02/KEEP-03 verification asks for ftrace proof, session finds an empty trace → rung stuck with no machine evidence.
**Why it happens:** historical markers were built ad hoc into an uncommitted tree ("rebuilt into the 7.0.0-38 tree", `DSI_RESUME_TRACE_ANALYSIS.md:133-141` [VERIFIED]); no `patches/*.patch` ever contained them (repo-wide grep this session; `git log --all -S D330SEQ` shows only doc commits).
**How to avoid:** put skip markers inside the E1/E2 patch itself at the cut sites — precedent shapes: `pr_info("D330DSIREG: snapshot captured ...")` (`d330_dsi_dump.patch:445` [VERIFIED]) and `drm_info(display->drm, "[D330 82H0] resume: panel power-off settle before DSI init\n")` (`d330_dsi_panel_power_cycle.patch:88-89` [VERIFIED]); add CI grep-proofs for the marker strings. Optionally confirm on-device first: `dmesg | grep -c D330SEQ` on the installed echo-2 kernel (expected 0 — see A1).
**Warning signs:** tracefs `trace` file has no `D330*` lines after a full suspend.

### P3: Falsified pre-enable patches are still in the CI apply stack
**What goes wrong:** E1 kernel silently still runs the row-31 power cycle (`MIPI_SEQ_POWER_OFF` at top of `pre_enable` in the resume window) → keep-hot state cleared at wake, E1/E2 contaminated; or the new patch re-defines `d330_82h0_panel()` → duplicate-symbol build failure.
**Why it happens:** `build-kernel.yml:130-148` still applies `d330_dsi_panel_power_cycle.patch` (:138) and `d330_dsi_mipio_reset.patch` (:147) with comments describing them as the phase-48 iterations, and the mipio patch explicitly "Requires the iteration-2 patch applied first (reuses its DMI helper)" (:144-146) [VERIFIED: workflow lines read this session].
**How to avoid:** in the E1 CI iteration, remove both applies (they are falsified levers — rows 31/32 — and their resume-window behavior contradicts keep-hot), let the E1 patch define its own `d330_82h0_panel()`; keep `d330_display_resume_fix.patch` + `d330_dsi_dump.patch` applies untouched. Update the workflow comment block in the same change.
**Warning signs:** `git apply` context failure, duplicate `d330_82h0_panel`, or resume ftrace showing `POWER_OFF` despite E1 skips.

### P4: One-flag design breaks E2
**What goes wrong:** plan reuses `suspend_commit_in_progress` as E2's gate; it is cleared in `intel_display_driver_resume()` before KWin's `pre_enable` → E2 never skips → full re-init → X=Z.
**How to avoid:** two flags (Pattern 1) or one keep-hot flag with different clear points; verify by reading the resume function before writing the plan [VERIFIED placement: v7.0 `intel_display_driver.c` resume body clears `display->restore.modeset_state = NULL` near the top].

### P5: Window/timing discipline
**What goes wrong:** dump #2 lands after 18 s (KWin commit at ~3 s, but slow manual steps push past the window) or the two dumps collide with `EBUSY`.
**How to avoid:** pre-stage scripts at `/usr/local/bin/` (deploy record precedent `50-04-SUMMARY.md:28` [VERIFIED]), run the two captures back-to-back blind-invocation style inside one ≥18 s window; trigger is synchronous (returns after the walk) — `capture_dsi_dumps.sh:191-196` [VERIFIED]. Never use a short trace window: it already caused one wrong conclusion (PITFALLS "Test with a short trace window" [VERIFIED: .planning/research/PITFALLS.md table row]).

### P6: Rollback asset handling
**What goes wrong:** incoming deb overwrites the rollback asset (documented 2026-10-15 incident), or the plan assumes the wrong rollback constant (script default is `/home/santiago/d47_dump_kernel.deb` sha `ba47df8d…`, `deploy_d330_kernel.sh:70-71` [VERIFIED], not the current kernel).
**How to avoid:** pass `D330_ROLLBACK_DEB`/`D330_ROLLBACK_SHA` explicitly — Phase 50's deploy used `/home/santiago/deploy_incoming_c2c2cd89ce91.deb` sha `c2c2cd89…1073` [VERIFIED: 50-04-SUMMARY.md:26]; the currently installed echo-2 deb sha is `22AE3D58F9796197F452EBDF30814468FD2CCB0D5B826600736BA6FD0AACFA1A` [VERIFIED: 50-04-SUMMARY.md:13]; decide in the plan which is the E1 rollback (prefer the exact installed deb if retained on device — confirm at session start).

### P7: WSL is broken on this host; pwsh-native ssh only
**What goes wrong:** `verify_d330_deploy.sh`-style scripts `cd /mnt/d/...` fail — verified this session: `wsl: Error 0x8007054f` (networking config failure) [VERIFIED: probed this session].
**How to avoid:** run sessions via PowerShell ssh (`ssh -i $HOME/.ssh/d330_ed25519 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_d330 ... santiago@192.168.2.195` — `verify_d330_deploy.sh:7` [VERIFIED]), `sudo -S -p ''` with the password on stdin only.

### P8: Dump node / card-minor drift
**What goes wrong:** node missing after an unbind/bind (buffer-alloc early-return skips re-creation — fixed riding iteration 3, ledger row 31 evidence [VERIFIED: RESUME_FIX_LEDGER.md:93]) or i915 enumerates `card1` at next boot.
**How to avoid:** capture script already globs `dri/*/i915_dsi_regs` and prefers minor 0 (`capture_dsi_dumps.sh:151-177` [VERIFIED]); do not unbind/bind during a rung session — only reboot re-probes cleanly.

### P9: Ledger row append mechanics
**What goes wrong:** new rung row appended but `## Lever rows: 32` count line (RESUME_FIX_LEDGER.md:58 [VERIFIED]) not incremented, or row has ≠5 cells, or new alias regex matches none of the five `SOURCE_DOCS` → `ledger_parses` fails → gate red.
**How to avoid:** update count + row + keep the 5-cell `| n | name | `regex` | disproof | evidence |` shape exactly like rows 30-32; alias regex must hit at least one source doc (`test_pitfalls_ledger.sh:299-302` [VERIFIED]).
**Warning signs:** `Ledger gate: parse failure - ...`.

### P10: `NO_CLEAN_FIX_PROOF.md` is gate-scanned
**What goes wrong:** the v10.0 falsification section quotes banned aliases → gate red (the file is a SOURCE doc, not in the 5-file allowlist — `test_pitfalls_ledger.sh:47-61` [VERIFIED]; it already carries allow markers at lines 3-10, 99-102, 135).
**How to avoid:** append markers for each new quoted alias in the same edit.

### P11: KWin/post-resume modeset tripping keep-hot on a LATER modeset
**What goes wrong:** after a successful suspend skip, a later user DPMS-off/modeset runs `post_disable` with the suspend flag (if the flag is cleared too late) or E2 skip fires on a cold boot (if keep-hot flag lacks a clear point).
**How to avoid:** flag A cleared in `intel_display_driver_resume()` (before any later modeset); flag B cleared on the first executed `MIPI_SEQ_POWER_OFF` (cold boot runs POWER_OFF at first suspend → flag false at first resume; also panel power-off at unbind/reload clears it).

### P12: E1 success ≠ image (expectation management)
**What goes wrong:** team reads "rails held" as "fix landed"; resume may still land X=Z if the TCON lost state despite rails (or PMIC cut them anyway — the decisive risk, `v10.0-keep-panel-powered.md` §4 [CITED]).
**How to avoid:** CONTEXT's ladder handles it: E1 falsified → lazy E3 with dump/ftrace/GPIO-144 evidence; ambiguous → Phase 53. E1 alone success criteria require BOTH ftrace-skip proof AND X=Y dump AND eyes-on (roadmap success criteria 1-2).

## Code Examples

### 1. DMI helper — copy shape verbatim from the proven CI patch
```c
// Source: patches/d330_dsi_panel_power_cycle.patch:44-55 (applied by CI today, compiles green)
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
Only re-emit this in the E1 patch if P3's apply-stack cleanup removed the power-cycle patch; otherwise the definition collides.

### 2. Suspend flag placement (source-verified)
```c
// Source: torvalds/linux v7.0 intel_display_driver.c (raw fetch, this session) + v10.0-keep-panel-powered.md:66
int intel_display_driver_suspend(struct intel_display *display)
{
	...
	display->suspend_commit_in_progress = true;   /* SET BEFORE the atomic suspend */
	state = drm_atomic_helper_suspend(display->drm);   /* runs intel_dsi_disable -> post_disable */
	...
}
// intel_display_driver_resume(): display->suspend_commit_in_progress = false;
// gate at each skip site:  d330_82h0_panel() && display->suspend_commit_in_progress
```

### 3. E1 skip site shape (keep vs skip, against verified v7.0 body)
```c
// Source: torvalds/linux v7.0 vlv_dsi.c intel_dsi_post_disable / intel_dsi_disable (raw fetch)
/* SKIP behind the suspend flag: */
intel_dsi_vbt_exec_sequence(intel_dsi, MIPI_SEQ_DISPLAY_OFF);      /* E1 cut 1 */
/* ... host-side teardown BELOW stays unconditional ... */
intel_dsi_vbt_exec_sequence(intel_dsi, MIPI_SEQ_ASSERT_RESET);     /* E1 cut 2 (GPIO 160) */
msleep(intel_dsi->panel_off_delay);                                /* keep (harmless, t3/t4 timing) */
intel_dsi_vbt_exec_sequence(intel_dsi, MIPI_SEQ_POWER_OFF);        /* E1 cut 3 (GPIO 144) — set keep-hot flag B here */
/* intel_dsi_disable(): keep MIPI_SEQ_BACKLIGHT_OFF + intel_backlight_disable;
   SKIP only the is_vid_mode SHUTDOWN dpi_send_cmd block */

/* Marker style for the machine proof (repo precedent): */
drm_info(display->drm, "[D330 82H0] suspend: skip DISPLAY_OFF/ASSERT_RESET/POWER_OFF (keep-hot)\n");
```

### 4. Ledger row append (5-cell shape, rows 30-32 pattern)
```markdown
## Lever rows: 33            <- MUST be incremented (header count == actual rows)
| 33 | <one-line rung description> | `<alias regex hitting a SOURCE_DOC>` | <one-line disproof or success note> | <artifact file list> |
```

### 5. Allow-marker for gated aliases (substring of the HIT line)
```markdown
- E1 skips the teardown inside intel_dsi_post_disable() during the suspend commit only.
<!-- planner-discipline-allow: intel_dsi_post_disable() during the suspend commit -->
```
Marker text must be a substring of the offending line (gate: `test_pitfalls_ledger.sh:217-228`); one marker exempts every line in that file containing it.

### 6. CI apply + grep-proof block (extend in the same voice, lines 114-128 pattern)
```yaml
git apply -p1 "$GITHUB_WORKSPACE/patches/d330_dsi_keep_hot.patch"
grep -R 'd330_keep_hot_suspend' drivers/gpu/drm/i915/display/vlv_dsi.c
grep -R 'skip DISPLAY_OFF' drivers/gpu/drm/i915/display/vlv_dsi.c
```
Plus removal lines for the two falsified applies with a one-paragraph comment (P3).

## State of the Art

| Approach | Status | When Changed | Impact on Phase 51 |
|----------|--------|--------------|--------------------|
| DCS ID read as E3 discriminator | **DEAD** (Phase 50: `ret=4 avail=0 data=00 00 00` ×3 runs both arms) | 2026-10-17 | E3 redefined per CONTEXT: dump/ftrace/GPIO-144 verdict; DCS read = zero-expectation bonus only |
| Falsified fix candidates 30-32 (pre-enable ULPS clear / full power cycle / MIPIO pulse) | ledger-closed, **but still applied by CI** | rows written 2026-10-15 | P3: remove from apply stack for E1 |
| Rebind/unbind reload | proven bar is **reboot only** (45-02 correction, ledger rows 29/PROVEN bar) | 2026-10-13 | recovery during sessions = reboot, never rebind |
| Host MMIO holds across S3 | disproven by construction (DC9 unconditional on GLK) | v10.0 research fact 3 | locked dead-experiment exclusion |
| Marker tracing via `drm.debug`/dyndbg | dead (zero `[drm:...]` lines land) | pre-v9.0 | only compiled-in markers (`pr_info`/`drm_info`) work — P2 |
| E4 wake-order variants | effectively dead pending Phase 53 | CONTEXT 2026-10-17 | never plan E4 |

**Deprecated/outdated:**
- Roadmap Phase 51 text still describes E3 as "DCS ID read pre-INIT_OTP → TCON-alive vs rails-cut verdict" (`ROADMAP.md:306-308` [VERIFIED]) — superseded by 51-CONTEXT redefinition; plans must follow CONTEXT, not the roadmap sentence.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The installed echo-2 kernel (sha `22ae3d58…`) contains no `D330SEQ`/`D330GPIO` markers (inferred from CI apply list + no marker patch in git history; NOT checked on-device this session) | P2, KEEP-02 | Low — one `dmesg \| grep -c D330SEQ` at session start settles it; if present, ftrace path works as written |
| A2 | E1's markers can be dmesg `drm_info`/`pr_info` lines and still satisfy the roadmap's "ftrace (D330SEQ/D330GPIO)" wording (repo precedent: historical "ftrace" evidence was captured from dmesg, `DSI_RESUME_TRACE_ANALYSIS.md:141` "captured from dmesg") | KEEP-02 | Medium — if the planner insists on literal tracefs output, use `trace_printk()`-style markers instead (same patch sites) |
| A3 | `upower` is present on the device for the battery arm (`upower -i $(upower -e \| grep BAT)`); fallback `/sys/class/power_supply/BAT*` | Measurement | Low — device runs KDE/Ubuntu desktop stack; fallback exists |
| A4 | The two falsified pre-enable patches actually fire during a normal KWin post-resume commit (row-31 session evidence says the failure mode changed → it fired once; exact `init_wakeref` window vs KWin timing not re-derived) | P3 | Low either way: removing them is correct (falsified) and removes the ambiguity |
| A5 | Rollback asset choice for E1 (echo-2 deb vs `deploy_incoming_c2c2cd89ce91.deb`) — which deb is retained on the device is decided at session start | P6 | Low — both shas recorded; script hard-fails on mismatch |
| A6 | Exact patch filename/hunk context for E1 (`d330_dsi_keep_hot.patch` used illustratively above) | Code Examples | None — agent's discretion per CONTEXT |
| A7 | `msleep(intel_dsi->panel_off_delay)` kept during E1 skip is harmless (t3/t4 sequencing with rails never cut); alternative is skipping it too | Pattern 2 | Low — design doc says keep-and-leave-timestamp; either compiles, session evidence decides |

**If this table is empty:** n/a — seven items above need confirmation only where flagged.

## Open Questions

1. **Ledger-row-11 framing sign-off** — E1 re-attempts a banned lever with new evidence.
   - What we know: the ledger's own intro says binding for every plan; the allow-marker mechanism exists precisely for legitimate citations/re-attempts; 45/48/49 used markers for exactly this situation.
   - What's unclear: whether the planner must additionally annotate the row's disproof (evidence was eyes-on only) in the plan text.
   - Recommendation: proceed with narrow allow markers + explicit "new evidence: dump/ftrace per rung, E2 pairing, suspend discriminator" paragraph; never edit the row's disproof cell without user sign-off.
2. **Do the falsified pre-enable patches get removed from CI (P3)?**
   - Recommendation: yes, in the E1 iteration, with a workflow comment citing rows 31/32; alternative is keeping them and NOT redefining the helper — rejected because they fight keep-hot at resume (A4).
3. **Rollback asset for the E1 deploy** (A5) — decide from the live device inventory at session start; both candidate shas are recorded above.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| node (`gsd-tools.cjs` commit verb) | doc commits | ✓ | v26.5.1 (probed) | — |
| git | commits, `git apply --check` | ✓ | 2.55.0.windows.3 | — |
| `gh` CLI | trigger/watch `build-kernel.yml`, fetch artifacts | ✓ | 2.92.0 | — |
| bash (Git Bash) | gate scripts (`test_*`, `--selftest`) | ✓ | GNU bash 5.2.21 (probed) | — |
| pwsh | native ssh session driver | ✓ | 7.6.6 | — |
| OpenSSH client | device ssh (key `~/.ssh/d330_ed25519`) | ✓ | Windows 9.5p2 | — |
| WSL | legacy scripts (`verify_d330_deploy.sh` `/mnt/d` path) | ✗ | error `0x8007054f` (probed this session) | pwsh-native ssh (locked practice) |
| Device `santiago-D330` (192.168.2.195) | deploy + capture sessions | not probed this session (user-authorized sessions only) | kernel `linux-image-7.0.14-d330-fix` sha `22ae3d58…` installed | rollback deb on device |
| GitHub Actions runner | kernel `.deb` builds (~40 min) | ✓ (runs 38974632465-class proven) | `ubuntu-latest`, `timeout-minutes: 240` | — |
| `upower` on device | battery quantification (success path only) | ✗ not probed | — | `/sys/class/power_supply/BAT*` (A3) |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** WSL → pwsh (already the practice); `upower` → sysfs (A3).

## Validation Architecture

> `.planning/config.json`: `workflow.nyquist_validation: true` (present), `security_enforcement: true`, `security_asvs_level: 1`.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | bash gate scripts (repo convention; no unit-test framework for kernel patches) [VERIFIED: 50-VALIDATION.md:22] |
| Config file | none — scripts are self-contained with `--selftest`/`--fixtures` modes |
| Quick run command | `bash scripts/dsi_mmio_diff.sh --selftest && bash scripts/test_dsi_mmio_evidence.sh && bash scripts/test_pitfalls_ledger.sh` |
| Full suite command | same three gates (they are the gates) + `bash scripts/prepare_safety_kit.sh --verify --kit-dir docs/dumps/re_kit` at phase gate |
| Expected green counts | selftest 52/0 · evidence 7/0 · ledger 4/0 (50-04-SUMMARY.md:62 [VERIFIED]) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| KEEP-01 | suspend-only DMI-gated flag infra lands in CI tree | CI grep-proof | `gh run view <run> --json status,conclusion` + workflow greps (Pattern 6) | ❌ Wave 0 (new patch + greps) |
| KEEP-02 | E1 skips proven by markers; keep-teardown intact | static gate + device session (manual-only) | gates above; on-device: dump pair + marker/dmesg capture + `prepare_safety_kit.sh --verify` | ❌ Wave 0 (resume arms in capture script) |
| KEEP-03 | E2 X=Y set in ~4 s dump + eyes-on | static gate + device session (manual-only) | `dsi_mmio_diff.sh` on the 4 s dump + eyes-on verdict | ❌ Wave 0 (X=Y operational-set check — see gaps) |
| KEEP-04 | lazy E3 discriminator + escalation record | manual-only (conditional) | kit `--verify` exit 0 + ledger row | ⏸ built only if E1 falsifies |
| KEEP-05 | honest verdict: ledger rows + `NO_CLEAN_FIX_PROOF.md` v10.0 section | static gate | `bash scripts/test_pitfalls_ledger.sh` (count line + rows parse) | ✅ files exist |

### Sampling Rate
- **Per task commit:** the three-gate quick command (~30 s)
- **Per wave merge:** same gates + `git apply --check` of the new patch against the expected apply-stack order (after P3 cleanup, from a clean `apt-get source` tree if available locally; otherwise rely on the CI apply step itself)
- **Phase gate:** all gates green + CI run green + one completed device session per rung with kit `--verify` exit 0 before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `patches/d330_dsi_keep_hot.patch` (or final name) — new file, self-contained E1 helper + flag A/B + skip markers
- [ ] `.github/workflows/build-kernel.yml` — drop the two falsified applies (P3), add grep-proofs for the new symbols/markers
- [ ] `scripts/capture_dsi_dumps.sh` — new resume arms for the ~0-1 s / ~4 s pair (CONTEXT locked; naming + contract comment update in the same change)
- [ ] X=Y operational-set check (6-register literal) — either a small `dsi_mmio_diff.sh` extension with a selftest fixture, or a documented grep one-liner pinned in the runbook
- [ ] ftrace/dmesg marker capture runbook block (enable → suspend → collect → disable, 18 s window) — no marker-collecting script exists (50-PATTERNS "No Analog Found" [VERIFIED])

## Security Domain

> `security_enforcement: true`, `security_asvs_level: 1`, `security_block_on: high` [VERIFIED: .planning/config.json].

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | no network auth surface; device access = ssh key `d330_ed25519` only |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes | existing hardened paths: `kstrtouint_from_user` bounded parse + `mutex_trylock -EBUSY` in the dump node (T-50-01 closed); E1/E2 patches add **no** userspace parse surface — keep it that way |
| V6 Cryptography | no | sha256 integrity (deploy + kit) is verification, not a crypto protocol — reuse existing scripts, never hand-roll |

### Known Threat Patterns for this stack (kernel patch + scripted device sessions)

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Rollback asset clobber by incoming upload | Tampering | `deploy_d330_kernel.sh` distinct incoming name + remote sha verify before `dpkg -i`; `D330_ROLLBACK_DEB/SHA` explicit (P6); never `rm` |
| Sudo password leaking into repo/logs | Information Disclosure | password on ssh stdin only (`deploy_d330_kernel.sh:20-27` [VERIFIED]); **pre-existing literals live in `scripts/verify_d330_deploy.sh:8` (and phase-48 deploy scripts) — out of this phase's delta (50-SECURITY T-50-10 precedent), but Phase 51 must not copy them into any new file** |
| Patch silently widening the measured system | Tampering | one candidate per CI iteration; CI grep-proofs pin the applied hunk; comment block documents every apply-list change (P3) |
| Evidence substitution / over-claim | Repudiation | eyes-on verdicts recorded verbatim beside machine evidence; kit sha256 round-trip; fail-fast archives first falsifying capture |
| Ledger gate bypass by reworded lever | Tampering | gate is in the harness (`test_pitfalls_ledger.sh` in the suite); allow markers are per-string, per-file, and the suite's own fixture cases prove non-vacuity |
| New kernel code hanging suspend/resume | DoS | skips are call-site gating only — no new waits, no new register writes; E2's skip removes `INIT_OTP`, adds nothing |
| No registry installs | Supply-chain | confirmed: zero npm/pip/cargo/apt installs in this phase's delta (Package Legitimacy Audit) |

## Sources

### Primary (HIGH confidence)
- `.planning/research/v10.0-keep-panel-powered.md` (read in full this session) — experiment ladder §1/§3, risks §4, facts 1-10
- torvalds/linux tag `v7.0` raw fetch (this session): `drivers/gpu/drm/i915/display/vlv_dsi.c` (full file — `intel_dsi_pre_enable`, `intel_dsi_disable`, `intel_dsi_post_disable`, `intel_dsi_host_transfer` content verified), `intel_display_driver.c` (suspend/resume bodies verified)
- `patches/d330_dsi_panel_power_cycle.patch` (read in full) — helper shape, CI-applied state
- `.github/workflows/build-kernel.yml` (read in full) — apply list, grep-proof contract, build config
- `docs/research/RESUME_FIX_LEDGER.md` (read lines 56-95) — row 11 verbatim, row shapes, count line
- `scripts/test_pitfalls_ledger.sh` (read in full) — scan scope, marker semantics, parse rules
- `scripts/capture_dsi_dumps.sh` (read in full) — arms, window, failure policy
- `scripts/deploy_d330_kernel.sh` (read lines 1-120) — rollback discipline, credential handling
- `.planning/ROADMAP.md` Phase 51 block (lines 280-346) + `51-CONTEXT.md` (read in full) — must-do list, locked decisions

### Secondary (MEDIUM confidence)
- `docs/research/TCON_IDENTIFICATION.md` (read in full) — Phase 50 dead-read verdict, E3 consequences
- `docs/research/DISPLAY_RESUME_CCS_MODIFIER.md:185-264` — row-11 experiment record, disproven-theory list
- `docs/research/DSI_RESUME_TRACE_ANALYSIS.md:130-189` — marker provenance, KWin-commit timing, sequence orders
- `50-PATTERNS.md`, `50-VALIDATION.md`, `50-SECURITY.md`, `50-04-SUMMARY.md` (read this session) — plan-shape, gates, deploy/session precedents

### Tertiary (LOW confidence — validation flagged)
- `upower` availability on device (A3) — not probed
- Absence of markers in the *installed* kernel (A1) — inferred from repo evidence, needs one on-device grep

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — CI pipeline, patch stack, and kernel source all opened this session
- Architecture: HIGH — design doc re-verified against v7.0 source; two-flag nuance derived from verified resume body
- Pitfalls: HIGH for P1/P3/P6/P7 (all read from source this session), MEDIUM for P2/A1 (on-device state not checked), MEDIUM for P4 window semantics (derived, not executed)

**Research date:** 2026-10-17
**Valid until:** 7 days (fast-moving: device session state, CI apply stack, and installed kernel can each change within a week)



