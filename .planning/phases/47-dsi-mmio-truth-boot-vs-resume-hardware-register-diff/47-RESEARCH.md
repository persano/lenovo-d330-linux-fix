# Phase 47: DSI MMIO Truth (Boot vs Resume Hardware Register Diff) - Research

**Researched:** 2026-10-13
**Domain:** i915 GLK (Gemini Lake) DSI/DPHY MMIO instrumentation via a CI-built debugfs snapshot node; boot-vs-resume register readback, diff, and mechanism-naming
**Confidence:** HIGH (in-repo facts read this session; upstream register maps fetched from torvalds/linux@master this session; remaining unknowns are on-device empirical questions, logged in Open Questions, not silently assumed)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Dump Instrumentation**
- Debugfs snapshot node in a CI-built i915 (e.g. `i915_dsi_regs`) — deterministic, both arms dumped with the same tool, matches success criterion 1 (CI-built kernel or dump tooling); devcoredump rejected (only fires on hang), out-of-tree dump module rejected.
- Register scope: the 5 known ftrace MMIO ranges (0x6b000-0x6c000 DSI ports, 0x160000-0x164000 BXT/GLK DSI PHY, 0x46000-0x47000 CDCLK/DSI PLL/DE PLL, 0xc7200-0xc7400 legacy PPS, 0x138000-0x139000 GT DISP PWRON/MIPIO_RST_CTRL) + full DSI transcoder/port block readback.
- Dump trigger: manual sysfs/debugfs echo per state — ordered, verifiable, identical code path on both arms; auto-on-resume hook rejected (noisy, races the 18 s window).
- Output: one text dump per state + sha256 registered in the RE kit manifest via `scripts/prepare_safety_kit.sh`; single multi-state file rejected.

**Capture Pairing & Session Protocol**
- Working reference state: fresh boot (GOP-initialized panel, working image) — that is exactly the working state whose mechanism we must name; reload arm not the reference (rebind proven NOT to restore the panel per NO_CLEAN_FIX_PROOF).
- Session shape: one on-device session — boot dump → user suspends/resumes → dump immediately while panel still black, inside the capture window.
- Window discipline: binding v8.0 protocol — `systemd-inhibit --what=idle` held through the whole test, ≥18 s window, `rtcwake`-timed suspend; relaxed timing rejected (prior captures invalidated by idle blanking).
- Repeatability: one boot/resume pair first; a second pair only if the diff is ambiguous (respects the user-trigger budget; one test per session rule).

**Mechanism Claim & Evidence Standard**
- Claim form: ONE named mechanism as a testable claim of the form "GOP sets register X=Y at boot; resume leaves X=Z" — ranked top-3 hypotheses rejected as a weaker handoff to Phase 48.
- Volatile-register exclusions: per-range exclusion table with reasons (interrupt-clear, timing-volatile, self-clearing bits) — required by success criterion 2.
- Evidence bar: every diff row cites register offset + capture file + line/section; `scripts/test_pitfalls_ledger.sh` gate stays green.
- Phase 48 handoff: `DSI_MMIO_DIFF.md` ends with an explicit "what to restore/replicate" register list feeding the fix plan.

### the agent's Discretion
Node naming (the decision says "e.g. `i915_dsi_regs`"), dump file format details, diff script implementation, named-register overlay table size, and the internal structure of `DSI_MMIO_DIFF.md` are implementation choices — as long as the locked evidence standard (per-row offset + file + line citation) holds.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MMIO-01 | Hardware-level display register diff between working fresh boot and broken resume exists — DSI/DPHY transcoder registers current tooling cannot show (no `i915_dsi_info` on this kernel); delivered as a small CI-built debug/dump patch with the diff recorded in `docs/research/DSI_MMIO_DIFF.md` | Confirmed upstream has NO DSI register debugfs to inherit (must be written); verified the node can follow `intel_display_debugfs.c` patterns; verified the 5-range scope maps onto real GLK register blocks; verified prior evidence bounds what the diff will find (21 known differing readable registers; PHY block readback is the genuinely new ground) |
| MMIO-02 | The diff names the mechanism: which hardware state the GOP sets at boot that the kernel's resume path does not (or sets wrong), as a testable claim | Verified the claim must survive ledger rows 3/18 (forced live overwrites of readable mismatches did nothing) — so the claim must land on state that forcing cannot replicate (RO status bits, PHY calibration block, GOP-only values); research provides the claim-form decision tree per diff outcome |
</phase_requirements>

## Summary

Phase 47 builds the instrument v8.0 said it needed: a small, additive debugfs node in the CI-built i915 that reads back the five known display MMIO ranges (verbatim scope from RESUME_CAPTURE_PROTOCOL) plus the full DSI port/transcoder block, once on a working fresh boot (GOP-handover state, panel showing image) and once on a broken S3 resume (panel black, inside the ≥18 s inhibit-held window). The two checksummed dumps are diffed with a per-range exclusion table for volatile/side-effect registers, and the result is `docs/research/DSI_MMIO_DIFF.md` ending in ONE named mechanism claim.

Two facts dominate the planning. First, **there is no upstream template to copy**: mainline i915 has no DSI register debugfs node at all (`intel_dsi_debugfs.c` and `vlv_dsi_debugfs.c` 404 on torvalds master; `grep.app` index of master shows zero hits for `i915_dsi_info`, while the index is confirmed current because `i915_display_info` resolves in `intel_display_debugfs.c`). The node is ~100-150 lines of new, purely additive kernel code following verified registration and read-safety patterns from `intel_display_debugfs.c`. Second, **prior evidence already bounds this diff**: an exhaustive cold-vs-resume readback on this exact device (7.0.14-d330-fix) found only **21 differing registers**, forcing those values onto the black state did nothing (ledger rows 3/18), and resume-vs-reload readbacks were byte-identical — while the DSI PHY range `0x162000/0x163000` read `0xffffffff` on both arms via intel-gpu-tools. The genuinely new ground this phase covers is (a) the PHY/calibration block read through the in-kernel `intel_de_read` path (which the driver itself uses to poll PHY `GRC_DONE`, so it is not a priori dead), (b) the GLK read-only status bits in `MIPI_CTRL` (`0x6b104`/`0x6b904`: PHY status, ULPS state, lane stop state, MIPIO port power), and (c) the complete raw sweep with one deterministic, checksummed tool on both arms.

The mechanism claim therefore cannot be "any readable register differs → restore it"; rows 3/18 killed that. It must name hardware state that **forcing cannot replicate** — the strongest candidates visible to this dump are the GLK RO status bits (live link state) and, if readable, the GOP's DPHY calibration values. The research provides a claim-form decision tree so the executor names the claim from the diff, not from hope. One critical machine-hang rule from upstream governs the node: on BXT/GLK, DSI register access with the DSI PLL in a bad/off state can **hang the machine** — the node must gate its DSI-block reads on `bxt_dsi_pll_is_enabled()` exactly like `intel_dsi_get_hw_state()` does.

**Primary recommendation:** build `patches/d330_dsi_dump.patch` — an additive debugfs node (echo-triggered snapshot + cat-readable buffer, ~7.3k `offset=value` lines per dump, gated on DSI-PLL-enabled, wrapped in display RPM) applied by the existing CI workflow alongside the CCS patch; capture one boot/resume pair per the binding protocol; diff with a small repo script that emits ledger-safe rows citing offset + capture file + line; write `DSI_MMIO_DIFF.md` with per-range exclusion table, ONE testable mechanism claim, and a Phase 48 "what to restore/replicate" list.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Register readback instrumentation | Kernel display tier (i915 debugfs node, CI-built patch) | — | Only in-kernel `intel_de_read` with display RPM held reads registers deterministically; userspace IGT already showed limits (0xffffffff PHY reads) |
| Capture session orchestration (inhibit, rtcwake, trigger, file capture) | On-device userspace (root shell) | — | v9.0 binding process rules: user triggers suspend/resume; capture runs in an inhibit-held window per RESUME_CAPTURE_PROTOCOL |
| Diff computation + exclusion table | Repo tooling (bash/awk script) | — | Machine-checkable rows; reproducible; produces the citation format the DIFF doc requires |
| RE kit registration | `scripts/prepare_safety_kit.sh --kit-dir docs/dumps/re_kit --register` | `scripts/test_re_diff_evidence.sh` (verify) | Existing checksummed manifest pipeline, mechanics read this session |
| Mechanism claim + interpretation | `docs/research/DSI_MMIO_DIFF.md` | `scripts/test_pitfalls_ledger.sh` (gate) | Text discipline against 29 banned-lever alias regexes; every row cites offset + file + line |
| Fix design (what to restore/replicate) | Phase 48 (out of scope here) | — | DIFF doc only hands off the register list + claim |

## What This Phase Must Add Over Prior Evidence

This section is load-bearing for planning: the diff is NOT landing on a blank map.

Prior machine evidence, read this session [VERIFIED: docs/research/DISPLAY_RESUME_CCS_MODIFIER.md:69-99, verbatim table]:

| reg | name | cold (works) | resume (black) |
| :-- | :--- | :----------- | :------------- |
| `0x6b004` | DSI INTR_STAT | `00000000` | `40200000` (bit30 + bit22 LP_RX_TIMEOUT) |
| `0x6b010` | DSI HS_TX_TIMEOUT | `003fffff` | `0000b8ea` |
| `0x6b044` | DSI HIGH_LOW_SWITCH_COUNT | `0000001d` | `0000001e` |
| `0x6b080` / `0x6b098` | DSI DPHY_PARAM | `09051003` | `0a051003` |
| `0x6b088` | DSI CLK_LANE_SWITCH_TIME_CNT | `0022000f` | `0014000c` |
| `0x6b094` | DSI INTR_EN | `00000001` | `00000000` |
| `0x46000` | **CDCLK_CTL** | `00300278` | `00b0013b` |
| `0x160018` | DSI PHY | `00000115` | `00000001` |
| (plus pipe scanout/position, DSPASURF, DC-state and RC6 counters — benign/expected rows) | | | |

Quoted verbatim from the same section: "Live-overwriting the candidates on the *black-resume* state — `0x46000` (CDCLK_CTL) and `0x160018` (DSI-PHY), on top of the whole DSI block already forced by the module experiments — did **not** bring the image back. So it is not a static register value." And: "the MIPI PHY `0x162000`/`0x163000` reads `0xffffffff` in both: powered down, not decoded" (resume-vs-reload readback, `intel_reg read` / intel-gpu-tools). Also: "Reading the DSI link block (`0x6b000`/`0x6b8xx`), `DEVICE_READY`, `INTR_STAT`, the panel regs (`0x160018`, `0x160020`, `0x160054`, `0x138090`), the PPS (`0xc7204`), `CDCLK_CTL` (`0x46000`) and the DSI PLL (`0x46080`) on the black resume state and again after a working reload gives an **empty diff**."

Consequences for Phase 47 planning:

1. **The readable-register boot-vs-resume diff largely already exists** (that cold-vs-resume table IS a GOP-state-vs-resume-state diff for readable registers — at cold boot i915 fast-boots and never inits DSI, so cold-boot values are GOP values [VERIFIED: docs/research/DISPLAY_RESUME_CCS_MODIFIER.md:105-110]). The new dump MUST (a) reconfirm those rows on the CI dump kernel with one consistent tool and citations, and (b) be positioned in `DSI_MMIO_DIFF.md` as a superset — it will fail the evidence bar if it silently re-discovers 2026-era rows as "new".
2. **The new ground is the PHY block readback via the in-kernel path.** IGT returned 0xffffffff on 0x162000/0x163000; the kernel's own DSI PHY code polls `GRC_DONE` in `BXT_PORT_REF_DW3` (`0x16218c`), so the in-kernel read path demonstrably works when the driver uses it. Whether the dump node sees real values there is THE empirical question of the session, and the mechanism claim likely lives there (GOP's calibration values vs whatever the kernel resume leaves) or in the RO status bits.
3. **GLK RO status bits are the best "live link state" candidates**: `MIPI_CTRL` (`0x6b104`, port A / `0x6b904`, port C) read-only bits — `GLK_PHY_STATUS_PORT_READY` (bit 31), `GLK_ULPS_NOT_ACTIVE` (bit 30), `GLK_MIPIIO_RESET_RELEASED` (bit 28), `GLK_CLOCK_LANE_STOP_STATE` (bit 27), `GLK_DATA_LANE_STOP_STATE` (bit 26), `GLK_MIPIIO_PORT_POWERED` (bit 1) [CITED: torvalds/linux@master `drivers/gpu/drm/i915/display/vlv_dsi_regs.h`, MIPI_CTRL bit defines, fetched this session]. The prior 21-row table does NOT list `0x6b104` — these bits may be the first readable live-state difference ever captured on this device.
4. **The claim cannot be "restore the differing readable registers"** — ledger row 3 and row 18 already disprove that (values were forced to match cold boot byte-for-byte, screen stayed black) [VERIFIED: docs/research/RESUME_FIX_LEDGER.md:65-66,80]. The DIFF doc must engage with that history explicitly and point the claim at state forcing cannot replicate.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Linux kernel 7.0.0 tree (`~/d330-kernel/linux-7.0.0` on device; Ubuntu archive source in CI) | 7.0.0-38 (resolute) | Source of truth for register macros and the i915 display code the patch touches | The CI patch must apply to THIS tree; all register macro names must be grepped here, not assumed [VERIFIED: docs/research/DISPLAY_RESUME_CCS_MODIFIER.md:300-302] |
| i915 display debugfs framework (`drm_debugfs_create_files` / custom fops) | in-tree | How the dump node is exposed | Verified pattern on master; the 7.0.0 tree equivalent must be grepped on device |
| `scripts/prepare_safety_kit.sh` | repo | `--kit-dir docs/dumps/re_kit --register FILE` / `--verify` | Read this session [VERIFIED: scripts/prepare_safety_kit.sh:65-83, 93-133] |
| `scripts/test_pitfalls_ledger.sh` | repo | banned-lever gate the DIFF doc must stay green under | Read this session [VERIFIED: scripts/test_pitfalls_ledger.sh:170-186, 216-234] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `systemd-inhibit` + `rtcwake` (util-linux) | on-device | Binding window discipline (inhibit held, timed suspend) | Every capture session [VERIFIED: docs/research/RESUME_CAPTURE_PROTOCOL.md:26-37] |
| intel-gpu-tools (`intel_reg read --count=<decimal>`) | on-device | Fallback cross-check only | NOT the primary instrument (prior IGT limitations: PHY reads 0xffffffff; `intel_reg dump` mis-decodes GLK pipe regs as 0 [VERIFIED: docs/research/DISPLAY_RESUME_CCS_MODIFIER.md:312-313]) |
| GitHub Actions `workflow_dispatch` build | repo CI | Build the dump kernel `.deb` (~40 min), grep-proves patches landed | [VERIFIED: .github/workflows/build-kernel.yml:105-113, 132-143] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| In-kernel debugfs node (LOCKED) | `intel_reg read` from intel-gpu-tools | Rejected by prior evidence: IGT read path returned 0xffffffff for the PHY range and mis-decodes GLK regs; also not "same tool both arms + manifest + CI-built" per locked decision |
| Echo-triggered snapshot buffer (recommended) | Plain seq_file that walks registers on every `cat` | Snapshot freezes values at trigger time (inside the 18 s window); cat-on-read would re-read registers whenever the file is copied, possibly after the window |
| One text dump per state (LOCKED) | Single multi-state file | Rejected in CONTEXT (arm identity must be unambiguous) |

**Installation:**
```bash
# No new packages. Kernel toolchain already staged per RESUME_CAPTURE_PROTOCOL:
sudo apt install -y util-linux coreutils zstd binutils intel-gpu-tools acpica-tools
```

**Version verification:** No external packages are installed by this phase (kernel source from the Ubuntu archive via the existing CI workflow). Nothing to run the npm/pip gates on.

## Package Legitimacy Audit

> No external packages are installed in this phase: the only "dependency" is the Ubuntu-archive kernel source already resolved by `.github/workflows/build-kernel.yml` (`apt-get source linux=${SRC_VER}`), verified in-repo. No npm/pypi/crates artifacts. **Audit: N/A (none required).**

## Architecture Patterns

### System Architecture Diagram

```
                        ONE ON-DEVICE SESSION (user-triggered, inhibit held ≥18 s)
                                      │
        ┌─────────────────────────────┤
        │ (arm 1) fresh boot          │ (arm 2) S3 resume, panel black
        │ panel shows image (GOP      │ rtcwake-timed; user resumes;
        │ handover intact)            │ echo trigger while still black
        ▼                             ▼
  ┌─────────────────────────────────────────────┐
  │ CI-BUILT i915: debugfs snapshot node        │
  │  echo 1 > i915_dsi_regs                     │
  │   ├─ RPM grab + modeset lock                │
  │   ├─ gate: DSI PLL enabled? (else skip DSI) │
  │   └─ walk 5 ranges + DSI port block         │
  │       → frozen snapshot buffer (kernel)     │
  │  cat i915_dsi_regs > <arm>_dsi_regs.txt     │
  └─────────────────────────────────────────────┘
        │                             │
        ▼                             ▼
  docs/dumps/re_kit/boot_dsi_regs.txt   broken_dsi_regs.txt
        └───────┬────────────────────┘
                ▼
     scripts/dsi_mmio_diff.sh (+ exclusion table)
                │ rows: offset | boot | resume | name | verdict | citation
                ▼
     docs/research/DSI_MMIO_DIFF.md
       ├─ per-range exclusion table (volatile/side-effect, with reasons)
       ├─ ONE mechanism claim "GOP sets X=Y at boot; resume leaves X=Z"
       └─ "what to restore/replicate" list → Phase 48
                │
                ▼
     scripts/prepare_safety_kit.sh --register  (sha256 per dump into re_kit MANIFEST)
     scripts/test_pitfalls_ledger.sh gate stays green
```

### Recommended Project Structure
```
patches/
└── d330_dsi_dump.patch           # additive i915 debugfs node (CI applies it)
scripts/
├── dsi_mmio_diff.sh              # dump-pair diff → cited rows + exclusion enforcement
└── test_dsi_mmio_evidence.sh     # static evidence guard (pattern: test_re_diff_evidence.sh)
docs/dumps/re_kit/
├── boot_dsi_regs.txt             # arm 1 dump (registered in MANIFEST)
├── broken_dsi_regs.txt           # arm 2 dump (registered in MANIFEST)
└── dsi_regs_diff.txt             # raw diff artifact (registered)
docs/research/
└── DSI_MMIO_DIFF.md              # the deliverable: diff + exclusions + ONE claim + handoff
```

### Pattern 1: Debugfs snapshot node (the dump instrument)

**What:** A root-only debugfs file at `/sys/kernel/debug/dri/0/i915_dsi_regs`. Write side (`echo 1 > …`) performs the register walk into a kernel-side frozen snapshot buffer and logs one `D330DSIREG` confirmation line to dmesg; read side (`cat`) emits the buffer. Same code path both arms.

**When to use:** Always for this phase — this is the locked instrument shape.

**Verified upstream patterns it must follow** (all fetched this session from torvalds/linux@master):

Registration (node added to the display debugfs list or created next to it):
```c
// Source: drivers/gpu/drm/i915/display/intel_display_debugfs.c (master ~823-858)
static const struct drm_info_list intel_display_debugfs_list[] = {
	{"intel_display_caps", intel_display_caps, 0},
	{"i915_display_info", i915_display_info, 0},
	...
};
void intel_display_debugfs_register(struct intel_display *display)
{
	struct dentry *debugfs_root = display->drm->debugfs_root;
	debugfs_create_file("i915_fifo_underrun_reset", 0644, debugfs_root,
			    display, &i915_fifo_underrun_reset_ops);
	drm_debugfs_create_files(intel_display_debugfs_list,
				 ARRAY_SIZE(intel_display_debugfs_list),
				 debugfs_root, display->drm->primary);
```
Custom fops with a write side exist upstream (`i915_fifo_underrun_reset_ops` / `crtc_updates_fops`) — the snapshot node uses the same shape (`simple_open`, `read = seq_read`, `write = trigger`, `.llseek = default_llseek`).

Read-safety contract (register reads from debugfs):
```c
// Source: intel_display_debugfs.c (master) — i915_display_info
wakeref = intel_display_rpm_get(display);
drm_modeset_lock_all(display->drm);
... reads via intel_de_read(display, reg) ...
drm_modeset_unlock_all(display->drm);
intel_display_rpm_put(display, wakeref);
```
(and the alternative wrap: `wakeref = intel_display_power_get(display, POWER_DOMAIN_INIT)` — used by `i915_sr_status`.)

**The machine-hang gate (non-negotiable):**
```c
// Source: vlv_dsi.c (master), intel_dsi_get_hw_state, ~line 950-958:
/*
 * On Broxton the PLL needs to be enabled with a valid divider
 * configuration, otherwise accessing DSI registers will hang the
 * machine. See BSpec North Display Engine registers/MIPI[BXT].
 */
if ((display->platform.geminilake || display->platform.broxton) &&
    !bxt_dsi_pll_is_enabled(display))
	goto out_put_power;
```
The node must apply the identical gate before touching the `0x6b000` DSI block (print a `DSI PLL off — DSI reads skipped` marker instead of reading).

### Pattern 2: Raw range walk + named-register overlay

**What:** The dump walks each of the 5 locked ranges word-by-word (32-bit) and prints `0xOFFSET=VALUE`; a second section prints a curated named table (name, offset, value, key bit decode) for interpretation — most importantly the `MIPI_CTRL` RO status bits and `DEVICE_READY`.

**Locked scope, verbatim** [VERIFIED: docs/research/RESUME_CAPTURE_PROTOCOL.md:119-125]:
```text
(reg >= 0x6b000  && reg < 0x6c000)    /* DSI ports A..C, INTR, DEVICE_READY, MIPI_CTRL */
(reg >= 0x160000 && reg < 0x164000)   /* BXT/GLK DSI PHY */
(reg >= 0x46000  && reg < 0x47000)    /* CDCLK, DSI PLL, DE PLL */
(reg >= 0xc7200  && reg < 0xc7400)    /* legacy PPS */
(reg >= 0x138000 && reg < 0x139000)   /* BXT_P_CR_GT_DISP_PWRON / MIPIO_RST_CTRL */
```
Word counts: 0x6b000-0x6c000 → 1024; 0x160000-0x164000 → 4096; 0x46000-0x47000 → 1024; 0xc7200-0xc7400 → 128; 0x138000-0x139000 → 1024. Total ≈ 7,296 registers ≈ 29 KB MMIO reads ≈ well under one second of dump time (orders of magnitude inside the 18 s window). Text output ≈ 7k lines / ~170 KB per dump — a file, never printk (see Pitfall 4).

**Named-register map for the overlay table** (verified from torvalds master this session; the executor MUST re-grep each macro in the actual `linux-7.0.0` tree before coding — paths may differ from master):

- DSI controller block [CITED: vlv_dsi_regs.h] — `BXT_MIPI_BASE = 0x60000`; port A at `0x6b000+`, port C at `0x6b800+` (so the locked 0x6b000-0x6c000 range IS the DSI transcoder/port block): `MIPI_DEVICE_READY 0x6b000/0x6b800`, `MIPI_INTR_STAT 0x6b004/0x6b804` (write-1-to-clear), `MIPI_INTR_EN 0x6b008/0x6b808`, `MIPI_HS_TX_TIMEOUT 0x6b010`, `MIPI_HIGH_LOW_SWITCH_COUNT 0x6b044`, `MIPI_DPI_CONTROL 0x6b048`, `MIPI_DPI_DATA 0x6b04c` (write-only), `MIPI_INIT_COUNT 0x6b050`, timing counts `0x6b028-0x6b040` (HSYNC/HBP/HFP/HACTIVE/VSYNC/VBP/VFP padding), `MIPI_VIDEO_MODE_FORMAT 0x6b058`, `MIPI_EOT_DISABLE 0x6b05c`, `MIPI_LP_BYTECLK 0x6b060`, `MIPI_LP_GEN_DATA 0x6b064 / MIPI_HS_GEN_DATA 0x6b068` (RX FIFOs, pop on read), `MIPI_LP_GEN_CTRL 0x6b06c / MIPI_HS_GEN_CTRL 0x6b070` (TX FIFO triggers), `MIPI_GEN_FIFO_STAT 0x6b074`, `MIPI_DPHY_PARAM 0x6b080`, `MIPI_CLK_LANE_SWITCH_TIME_CNT 0x6b088`, `MIPI_STOP_STATE_STALL 0x6b08c`, `MIPI_INTR_STAT_REG_1 0x6b090 / MIPI_INTR_EN_REG_1 0x6b094`, `MIPI_CLK_LANE_TIMING 0x6b098`, `MIPI_TLPX_TIME_COUNT 0x6b0a4`, `BXT_MIPI_PORT_CTRL 0x6b0c0/0x6b8c0` (`DPI_ENABLE` bit 31, `AFE_LATCHOUT` bit 17, `LP_OUTPUT_HOLD` bit 16), `BXT_MIPI_TRANS_HACTIVE/VACTIVE/VTOTAL 0x6b0f8/0x6b0fc/0x6b100`, `MIPI_CTRL 0x6b104/0x6b904` (GLK RO status bits listed above; `BXT_PIPE_SELECT` bits 9:7, `GLK_MIPIIO_ENABLE` bit 0), `MIPI_READ_DATA_RETURN0-7 0x6b118+` (RX FIFO, pop on read), `MIPI_READ_DATA_VALID 0x6b138`.
- DSI PHY block [CITED: bxt_dpio_phy_regs.h] — PHY bases `0x6C000 / 0x162000 / 0x163000`; on the D330 the relevant PHYs are `0x162000` (DSI port A) and `0x163000` (DSI port C), inside the locked 0x160000-0x164000 range. Named anchors: `BXT_PORT_CL1CM_DW0 0x162000` (`PHY_POWER_GOOD` bit 16), `DW9 0x162024` (IREF0RC), `DW10 0x162028` (IREF1RC), `DW28 0x162070` (OCL1 power-down/SUS_CLK_CONFIG), `DW30 0x162078`, `BXT_PORT_REF_DW3 0x16218c` (`GRC_DONE` bit 22 — the bit the driver polls), `REF_DW6 0x162198` (GRC calibration codes), `REF_DW8 0x1621a0`, PCS/TX per-lane registers `0x1624xx-0x162dxx` (TX swing/de-emphasis per lane). The ftrace reload trace wrote exactly `0x162024=8080e480 0x162028=8080e480 0x162070=33cb0443` and `0x163198=ffffff 0x1631a0=30008003` [VERIFIED: docs/research/DSI_RESUME_TRACE_ANALYSIS.md:44-46].
- Clock/PLL block — `CDCLK_CTL 0x46000`, `BXT_DE_PLL_ENABLE 0x46070`, `BXT_DSI_PLL_ENABLE 0x46080`, DSI PLL ratio/control [CITED: vlv_dsi_pll_regs.h:81: `#define BXT_DSI_PLL_CTL 0x161000`] — note `0x161000` sits inside the locked 0x160000-0x164000 range; chicken/clkgate regs `GEN9_CLKGATE_DIS_0 0x46530`, `GEN9_CLKGATE_DIS_4 0x4653c`, `GEN8_CHICKEN_DCPR_1 0x46430`, `HSW_NDE_RSTWRN_OPT 0x46408` [VERIFIED: docs/research/DSI_RESUME_TRACE_ANALYSIS.md:102-105].
- Legacy PPS block [CITED: intel_pps_regs.h] — `PCH_PPS_BASE = 0xC7200`; instance 0: `PP_STATUS 0xc7200` (timing-volatile), `PP_CONTROL 0xc7204` (unlock key 0xabcd in bits 31:16; `EDP_FORCE_VDD` bit 3, `EDP_BLC_ENABLE` bit 2), `PP_ON_DELAYS 0xc7208`, `PP_OFF_DELAYS 0xc720c`, `PP_DIVISOR 0xc7210`; instance 1 at `0xc73xx` (stride 0x100).
- GT power block [CITED: torvalds master `intel_display_regs.h:22-23`]: `#define BXT_P_CR_GT_DISP_PWRON _MMIO(0x138090)` / `#define  MIPIO_RST_CTRL (1 << 2)`.

### Pattern 3: Diff methodology with exclusion table

**What:** `scripts/dsi_mmio_diff.sh` parses both dumps into `offset=value` records, joins on offset, classifies every differing offset against a per-range exclusion table, and emits markdown rows already shaped for `DSI_MMIO_DIFF.md` (offset | boot value | resume value | interpretation | verdict | citation = file + line of each raw dump). Non-differing registers collapse to a count per range; exclusion rows list offset + reason (interrupt-status volatile, RX-FIFO pop-on-read, timing-volatile PPS sequence state, self-clearing/compositor-volatile scanout regs).

### Pattern 4: Mechanism-claim decision tree (how to form the ONE claim)

The executor fills this in from the actual diff — this is the shape, not the conclusion:

| Diff outcome | Named mechanism claim (form) | Testability for Phase 48 |
|---|---|---|
| PHY block (`0x162000/0x163000`) reads real values on both arms and DIFFERS | "GOP sets DSI PHY calibration/programming (e.g. IREF/GRC/TX swing) X=Y at boot; the resume path's PHY init leaves X=Z" | Restore/replicate the GOP PHY values in the resume path; verify by readback + eyes-on |
| PHY block reads 0xffffffff on BOTH arms (IGT behavior repeats) | PHY state invisible to readback; claim falls to the strongest READABLE difference: "at boot MIPI_CTRL RO status = Y (PHY ready / lanes in stop state); after resume = Z" — i.e. the link never re-reaches the boot-time state | Drive the exact RO-bit state at resume; verify via the dump's RO bits + eyes-on |
| Everything readable identical on boot vs resume (extends the prior empty resume-vs-reload diff) | The honest claim names the closest differing host state and states the unreachable part explicitly: no readable MMIO difference exists beyond the known rows; mechanism is below host MMIO (panel TCON side); "what to restore/replicate" = the RO-status target state + GOP's PPS use | Phase 48 receives the honest instrumented dead-end + the next instrument (matches SC1's "proven unreachable with documented reason + concrete next instrument" path) |

Rules regardless of outcome: exactly ONE claim (locked), every row cites offset + capture file + line, and the claim must NOT reduce to a ledger row 3/18 re-proposal (forcing readable values was disproven; the claim must be about state that the enable path *reaches or fails to reach*, which is what RO bits and PHY-block state capture).

### Anti-Patterns to Avoid
- **printk-based dump:** ~7k lines ≈ hundreds of KB into a ~512 KB default dmesg ring risks losing evidence lines mid-window; and console output races the capture. Dump into the kernel buffer, emit via `cat`.
- **cat-on-read register walk:** re-reads hardware whenever the file is copied — the copy may happen after the 18 s window (prior captures were invalidated by exactly this class of timing drift).
- **Reusing `intel_reg read` (IGT) as the instrument:** prior session evidence shows its PHY reads return 0xffffffff and `intel_reg dump` mis-decodes GLK pipe regs [VERIFIED: docs/research/DISPLAY_RESUME_CCS_MODIFIER.md:126-128, 312-313].
- **Reads without the DSI-PLL gate:** documented machine-hang risk [CITED: vlv_dsi.c BSpec warning].
- **Non-additive patch:** any touch of the DSI enable/disable path changes what the broken arm measures and may accidentally "fix" the bug (the dump kernel must still exhibit the failure — verify by eyes-on before the resume dump; a lit panel invalidates the pair).
- **Writing the DIFF doc without ledger-alias discipline:** the doc is scanned by the gate; several register names the dump WILL discuss are alias strings of banned rows (see Ledger Gate Discipline).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| debugfs file plumbing | custom dentry/seq machinery | `drm_debugfs_create_files` / `debugfs_create_file` with existing fops shapes | Upstream-verified; handles locking/release |
| MMIO reads + RPM | raw `readl()` on PCI BAR in the node | `intel_de_read()` under `intel_display_rpm_get` / `intel_display_power_get(POWER_DOMAIN_INIT)` | The driver's own path; handles uncore + display RPM |
| Checksum/manifest | ad-hoc hash files | `scripts/prepare_safety_kit.sh --kit-dir docs/dumps/re_kit --register/--verify` | Existing tamper-detect pipeline [VERIFIED: scripts/prepare_safety_kit.sh] |
| Evidence gate for the doc | bespoke linter | `scripts/test_pitfalls_ledger.sh` + a new `test_dsi_mmio_evidence.sh` following `scripts/test_re_diff_evidence.sh` (read this session: static grep-anchor cases + manifest verify, no hardware) | Same harness conventions; keeps machine-evidence bar checkable |
| Session windowing | new sleep/inhibit logic | Binding protocol verbatim: `systemd-inhibit --what=idle`, ≥18 s, `rtcwake` | Prior captures were invalidated by exactly these shortcuts [VERIFIED: docs/research/RESUME_CAPTURE_PROTOCOL.md:76-91] |

**Key insight:** everything novel here is the ~150-line additive kernel node plus the interpretation; all infrastructure (build, deploy, manifest, gates, protocol) exists and is machine-checked.

## Ledger Gate Discipline for DSI_MMIO_DIFF.md (planner-critical)

`scripts/test_pitfalls_ledger.sh` scans EVERY `docs/research/*.md` except a 5-file allowlist [VERIFIED: scripts/test_pitfalls_ledger.sh:55-61, 170-186]; `DSI_MMIO_DIFF.md` is NOT allowlisted, so any banned-row alias string appearing in it fails the build unless the file carries a narrow per-string marker line `<!-- planner-discipline-allow: <exact string> -->` (mechanism verified at [VERIFIED: scripts/test_pitfalls_ledger.sh:216-234]; working example: `RESUME_VS_RELOAD_DIFFERENTIAL.md` lines 1-5 with markers including `bl_power`).

Strings the DIFF doc will realistically need to mention and their ledger alias rows [VERIFIED: docs/research/RESUME_FIX_LEDGER.md:61-92]:
- `0x138090` (row 7 alias; the dump reads it by scope) → needs marker
- `BXT_DSI_PLL_CTL` (row 8 alias; readable in range 2) → needs marker
- `bl_power` (row 27) if backlight sysfs state is described → needs marker
- `0x160018` (rows 4/6 alias; a known differing register) → needs marker
- `MIPI_DPHY_PARAM`, `MIPI_CLK_LANE_SWITCH_TIME_CNT`, `MIPI_HIGH_LOW_SWITCH_COUNT`, `MIPI_HS_TX_TIMEOUT` (row 18 aliases — these are ALSO names of registers in the dump that will differ per the prior 21-row table) → needs markers if the DIFF cites them by name
- `CDCLK_CTL` (row 4 alias) → needs marker
- `PMIC` (row 12 alias) if panel rails are discussed → needs marker
- `glk_cold_boot` (row 14 alias) if the correlate is discussed → needs marker
- `PP_CONTROL` (row 1 alias) if PPS control is named → needs marker
- `DSI regulator` / `0x160054` / `BXT_P_DSI_REGULATOR_CFG` (row 6) → needs markers if mentioned
- `intel_dsi_post_disable` (row 11 alias) if suspend path is described → needs marker

Design rule for the executor: prefer register ADDRESSES (unaliased: `0x6b080`, `0x6b104`, `0x162024`…) over legacy register NAME macros in the DIFF prose, and add one narrow marker per unavoidable exact string at the top of the file, mirroring `GOP_DSI_RE_FINDINGS.md` lines 1-11. Never widen exemptions wholesale.

## Common Pitfalls

### Pitfall 1: Reading DSI registers with the DSI PLL off can hang the machine
**What goes wrong:** Hardware hang mid-dump → lost session, evidence uncollectable.
**Why it happens:** BSpec rule implemented in `intel_dsi_get_hw_state()` upstream.
**How to avoid:** Gate the DSI-block walk on `bxt_dsi_pll_is_enabled()`; skip-and-mark otherwise.
**Warning signs:** Any dump run without the gate is a process failure, not just a risk.

### Pitfall 2: PHY block reads 0xffffffff (possibly on both arms)
**What goes wrong:** The diff's "new ground" (DSI PHY) reads as all-ones; a naive parser treats it as a 7,168-register difference.
**Why it happens:** Power-gated/not-decoded reads return 0xffffffff (prior IGT evidence); in-kernel behavior unknown until the boot dump.
**How to avoid:** The diff script must classify all-ones as a per-range *state* (report "PHY block unreadable: 0xffffffff (powered/not decoded)" once), not as per-register diffs. The boot dump doubles as the readback-capability probe.
**Warning signs:** Hundreds of `0xffffffff` rows in the first diff run.

### Pitfall 3: The dump kernel accidentally changing what it measures
**What goes wrong:** The patch touches (or perturbs) the DSI path and the resume arm captures a *working* state; the pair is meaningless.
**Why it happens:** Enthusiasm — "while we're in there".
**How to avoid:** Patch is strictly additive (new file/registration + list entry only); CI grep proves no enable-path lines changed; the user confirms the panel is still black before the resume echo fires. If accidentally lit: discard the pair, do not interpret.
**Warning signs:** Resume dump shows boot-like RO bits.

### Pitfall 4: dmesg/printk as the dump channel
**What goes wrong:** Ring-buffer overflow loses dump lines; console output races the capture.
**How to avoid:** Snapshot buffer + `cat`; only ONE `D330DSIREG` confirmation line in dmesg.
**Warning signs:** `dmesg | grep D330DSIREG` shows truncated/absent block.

### Pitfall 5: Volatile registers masquerading as mechanism
**What goes wrong:** `0x6b004 INTR_STAT` (W1C, prior diff showed it differing), PPS `PP_STATUS` sequence bits, RX-FIFO regs, compositor scanout regs — all differ for reasons unrelated to the failure; a wrong "mechanism" claim gets shipped.
**Why it happens:** Raw sweep reads everything.
**How to avoid:** Per-range exclusion table with reasons (locked decision); interpretation weighted toward RO status bits and static config.
**Warning signs:** Differing rows that are all interrupt/status/counters.

### Pitfall 6: Window/timing shortcuts
**What goes wrong:** Idle blanking or a stale capture invalidates the resume arm (prior sessions burned by exactly this).
**How to avoid:** Binding protocol verbatim: inhibit held through the test, ≥18 s window, `rtcwake`-timed suspend, dump fired while panel still black [VERIFIED: docs/research/RESUME_CAPTURE_PROTOCOL.md:76-91; docs/research/DSI_RESUME_TRACE_ANALYSIS.md:106-109].
**Warning signs:** CRTC reads taken minutes after resume; inhibit released mid-test.

### Pitfall 7: CI patch context drift
**What goes wrong:** `git apply -p1` fails or lands on renamed files (master vs 7.0.0 tree differences).
**How to avoid:** Author the patch against the device tree (`~/d330-kernel/linux-7.0.0`), verify macro paths by grep in that tree, then let CI apply + grep-prove [VERIFIED: .github/workflows/build-kernel.yml:105-113]. CI build ~40 min, one dispatch per change.
**Warning signs:** CI red at "Apply the display fixes and prove they landed".

### Pitfall 8: Deploying without a retained rollback
**What goes wrong:** Panel-degrading kernel stuck on the device.
**How to avoid:** Known-good `.deb` retained before deploy (v8.0 pattern: sha256 recorded, host copy at `C:\Users\Familia\AppData\Local\Temp\opencode\rollback\`) [VERIFIED: docs/research/NO_CLEAN_FIX_PROOF.md:78-81].
**Warning signs:** Deploy step without a recorded pre-image checksum.

## Code Examples

### Dump node skeleton (shape only; adapt to the 7.0.0 tree's struct names)
```c
// Source: patterns verified from torvalds/linux@master intel_display_debugfs.c / vlv_dsi.c
static int dsi_dump_run(struct intel_display *display, struct seq_file *m)
{
	struct ref_tracker *wakeref;

	wakeref = intel_display_rpm_get(display);
	drm_modeset_lock_all(display->drm);

	/* BSpec: DSI access with bad PLL state can hang the machine */
	if (!bxt_dsi_pll_is_enabled(display))
		seq_puts(m, "DSI PLL off - DSI block reads skipped\n");
	else
		dsi_dump_range(m, display, 0x6b000, 0x6c000); /* ports A+C block */
	dsi_dump_range(m, display, 0x46000, 0x47000);         /* CDCLK/PLL */
	dsi_dump_range(m, display, 0xc7200, 0xc7400);         /* legacy PPS */
	dsi_dump_range(m, display, 0x160000, 0x164000);       /* DSI PHY */
	dsi_dump_range(m, display, 0x138000, 0x139000);       /* GT DISP PWRON */

	drm_modeset_unlock_all(display->drm);
	intel_display_rpm_put(display, wakeref);
	return 0;
}
/* write side: echo 1 > i915_dsi_regs -> walk into frozen buffer + one D330DSIREG log line */
/* read side:  cat i915_dsi_regs            -> emit frozen buffer via seq_read */
```

### Session sequence (arm 2, resume)
```bash
# inside systemd-inhibit --what=idle wrapper, root
rtcwake -m mem -s 45 &          # timed suspend (binding protocol)
systemctl suspend               # user-triggered per v9.0 rules
# ... device resumes, panel BLACK, inside the ≥18 s window ...
echo 1 > /sys/kernel/debug/dri/0/i915_dsi_regs          # walk + freeze (fast)
dmesg | tail -1                                          # D330DSIREG confirmation
cat /sys/kernel/debug/dri/0/i915_dsi_regs > broken_dsi_regs.txt
sha256sum broken_dsi_regs.txt
# off-device: scripts/prepare_safety_kit.sh --kit-dir docs/dumps/re_kit --register broken_dsi_regs.txt
```

### Diff script core (join on offset)
```bash
awk -F= 'NF==2 {print $1"="$2}' boot_dsi_regs.txt   | sort > /tmp/a
awk -F= 'NF==2 {print $1"="$2}' broken_dsi_regs.txt | sort > /tmp/b
join -t= -j1 /tmp/a /tmp/b | awk -F= '$2!=$3 {print}'   # differing offsets, both arms
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Ad-hoc on-device module instrumentation (pr_err markers, IGT `intel_reg read`) | CI-built additive debugfs node, one deterministic tool, checksummed dumps | This phase | Same code path both arms; machine-checkable evidence bar |
| ftrace write-only register visibility (`i915_reg_rw` ranges) | Full readback incl. never-written-by-driver registers (GOP state, RO status bits) | This phase | First boot-state (GOP) visibility on readable registers |
| intel-gpu-tools userspace reads | In-kernel `intel_de_read` under display RPM | Ongoing upstream | May unlock the PHY block IGT couldn't read |

**Deprecated/outdated:**
- `intel_reg dump` on GLK: mis-decodes pipe regs as 0 — do not use for interpretation [VERIFIED: docs/research/DISPLAY_RESUME_CCS_MODIFIER.md:312-313].
- `drm.debug`/dyndbg tracing on this kernel: dead end (0 `vlv_dsi` dynamic-debug sites) [VERIFIED: docs/research/RESUME_FIX_LEDGER.md:78].

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The 7.0.0 Ubuntu tree's i915 display file layout (debugfs registration site, `intel_dsi` struct shape, header names) is close enough to torvalds master that the cited patterns translate directly | Standard Stack / Patterns | Patch authoring targets the wrong symbols; mitigated by grep-first workflow in the device tree (Pitfall 7) |
| A2 | In-kernel `intel_de_read` can read the 0x162000/0x163000 PHY block (unlike IGT) because the driver itself polls `GRC_DONE` there | What This Phase Must Add / Decision tree | PHY block unreadable → decision-tree row 2/3 path; mechanism claim leans on RO status bits (still deliverable) |
| A3 | Power-gated region reads return 0xffffffff (vs hang) on this platform for non-DSI ranges | Pitfall 2 | A hang risk class appears where assumed safe → mitigation: the gate pattern + one-session-first discipline; a hang is recoverable by reboot, pair re-run |
| A4 | `echo`-triggered snapshot semantics satisfy the locked "manual sysfs/debugfs echo per state" wording | Pattern 1 | Planner/user can prefer plain cat-on-read; the snapshot design is the recommended, strictly-safer reading |
| A5 | i915 fastboot keeps the boot dump GOP-faithful (no DSI init runs at boot; no user-triggered modeset between boot and dump) | What This Phase Must Add | Boot dump is kernel-contaminated → DIFF must then classify which values i915 could have written (ftrace reload write-set provides the boundary) |

## Open Questions (RESOLVED)

1. **Will the in-kernel read path read the DSI PHY block?**
   - What we know: IGT read 0xffffffff there; the driver polls PHY `GRC_DONE`, so the kernel path works when the driver uses it.
   - What's unclear: whether plain `intel_de_read` under RPM in a debugfs context returns real values, 0xffffffff, or hangs.
   - Recommendation: boot dump runs first and doubles as the capability probe; the exclusion table and decision tree already branch on the outcome.
   - RESOLVED: handled as a Pattern-4 decision-tree branch in 47-04 — the boot dump doubles as the capability probe and the tree branches on the outcome.
2. **Does the diff produce a register-level mechanism, or only RO-bit correlates?**
   - What we know: 21 readable registers differed cold-vs-resume and forcing them did nothing; resume-vs-reload readable diff was empty.
   - What's unclear: whether the new ground (PHY block, RO bits) yields the ONE claim or the honest unreachable-mechanism closure.
   - Recommendation: use the Pattern 4 decision tree; both outcomes satisfy MMIO-02 if stated as a testable claim with the "what to restore/replicate" list.
   - RESOLVED: the ONE claim is formed by the Pattern-4 mechanism-claim decision tree in 47-04 (register-level mechanism or honest unreachable-mechanism closure; both satisfy MMIO-02).
3. **Name of register `0x160018`** (known differing DSI-PHY-area register).
   - What we know: prior diff lists it unnamed ("DSI PHY `0x160018`").
   - Recommendation: grep `0x160018` in the 7.0.0 tree during implementation; if unnamed there, cite it by address only.
   - RESOLVED: 47-01 Task 1 tree-greps `0x160018` in the 7.0.0 tree during implementation; if unnamed there, the overlay cites it by address only.
4. **Is `MIPI_CTRL` (`0x6b104`) state captured by the prior 21-row diff?**
   - What we know: the prior table does not list `0x6b104`; it may have been identical or unlisted.
   - Recommendation: no action — the new dump covers it either way; DIFF notes whether it reconfirms or adds it.
   - RESOLVED: no action — the new dump covers `0x6b104` either way; 47-04 records whether it reconfirms or adds it.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| GitHub Actions CI (workflow_dispatch, ~40 min build) | Dump kernel `.deb` | ✓ (existing workflow) | repo | — |
| Device (82H0) + user session time (one session, v9.0 budget) | Both capture arms | ✓ (binding process) | — | Second pair only if diff ambiguous (locked) |
| Kernel toolchain on device (`make M=drivers/gpu/drm/i915 modules`) | Patch authoring/testing against device tree | ✓ (staged per protocol) | linux-7.0.0 tree | CI full build |
| `systemd-inhibit`, `rtcwake`, `sha256sum`, `zstd` | Session + kit | ✓ (protocol prerequisites installed) | util-linux/coreutils | — |
| intel-gpu-tools | Fallback cross-check | ✓ | on-device | not primary |
| Known-good rollback `.deb` | Safe deploy | ✓ (retained at temp\rollback + on device, sha256 recorded) | 7.0.14-d330-fix | — |

**Missing dependencies with no fallback:** none identified.
**Missing dependencies with fallback:** none identified.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Repo bash harness (`scripts/test_*.sh`, static/evidence guards, no hardware) |
| Config file | none (convention-based) |
| Quick run command | `bash scripts/test_pitfalls_ledger.sh` |
| Full suite command | `for t in scripts/test_*.sh; do bash "$t"; done` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MMIO-01 | Dumps exist, registered in re_kit manifest, manifest verifies; DIFF doc exists with cited rows | static (bash) | `bash scripts/prepare_safety_kit.sh --verify --kit-dir docs/dumps/re_kit` + new `bash scripts/test_dsi_mmio_evidence.sh` | ❌ Wave 0 (new test file) |
| MMIO-02 | DIFF doc contains exactly ONE mechanism-claim section + "what to restore/replicate" list; ledger gate green | static (bash) | `bash scripts/test_pitfalls_ledger.sh` + anchors in `test_dsi_mmio_evidence.sh` | ❌ Wave 0 (new test file) |

### Sampling Rate
- **Per task commit:** `bash scripts/test_pitfalls_ledger.sh`
- **Per wave merge:** full harness loop above
- **Phase gate:** full suite green + manifest `--verify` before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `scripts/test_dsi_mmio_evidence.sh` — manifest coverage of the two dumps + DIFF-doc citation anchors + single-claim check (follow `scripts/test_re_diff_evidence.sh` shape, read this session)
- [ ] `scripts/dsi_mmio_diff.sh` — diff generator with exclusion table (produces the cited rows the test anchors)

*(Framework install: none needed.)*

## Security Domain

### Applicable ASVS Categories (security_asvs_level: 1, enforcement on)

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V5 Input Validation | yes | Debugfs write handler accepts only a boolean trigger (`kstrtobool` pattern, as upstream `i915_fifo_underrun_reset_write` does); NO user-controllable register offsets — the walked table is a compile-time constant |
| V6 Cryptography | yes (integrity only) | sha256 via coreutils `sha256sum` through the existing kit script — never hand-rolled |
| V4 Access Control | yes | Node perms 0400/0200 root-only inside debugfs (debugfs root is 0700 by default); arbitrary-register-read = info-leak surface if world-readable — must not be |
| V2/V3/V7-V14 | no | No auth/session/API/package surface in this phase |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Debugfs info leak (raw MMIO readback exposed to non-root) | Information Disclosure | 0400 perms, root-only debugfs mount context |
| Instrument patch widening into behavior change (silent fix/break of the measured bug) | Tampering (of the measurement) | Strictly additive patch + CI grep proof + eyes-on confirmation before resume dump |
| Evidence tampering (dump file substitution) | Tampering | Kit manifest sha256 registration + `--verify` gate before use |

## Sources

### Primary (HIGH confidence — read in-repo this session)
- `.planning/phases/47-.../47-CONTEXT.md` — locked decisions
- `.planning/REQUIREMENTS.md` — MMIO-01/02; `.planning/STATE.md` — milestone state
- `docs/research/NO_CLEAN_FIX_PROOF.md` (§3 decisive experiment, §4 future work = this phase's charter)
- `docs/research/RESUME_CAPTURE_PROTOCOL.md` (5 ranges verbatim; window/inhibit/rtcwake; golden-module pipeline; kit staging)
- `docs/research/DSI_RESUME_TRACE_ANALYSIS.md` (ftrace methodology; reload trace register values; glk_cold_boot correlate; pr_err marker pattern)
- `docs/research/GOP_DSI_RE_FINDINGS.md` (two-VBT; block-53 table; GOP decomp limits)
- `docs/research/DISPLAY_RESUME_CCS_MODIFIER.md` (prior exhaustive 21-register cold-vs-resume diff; empty resume-vs-reload diff; IGT PHY 0xffffffff; GOP RE PPS findings; disproven theories)
- `docs/research/RESUME_VS_RELOAD_DIFFERENTIAL.md`, `docs/research/RESUME_FIX_LEDGER.md` (29 rows + alias regexes)
- `scripts/test_pitfalls_ledger.sh`, `scripts/prepare_safety_kit.sh`, `scripts/test_re_diff_evidence.sh`, `.github/workflows/build-kernel.yml`
- `docs/dumps/re_kit/boot_displayinfo.txt`, `displayinfo_diff.txt` (what `i915_display_info` covers: software state only)

### Secondary (MEDIUM — canonical upstream files fetched this session via webfetch; seam classifies webfetch LOW, upgraded to [CITED] because the fetched artifacts are the authoritative torvalds/linux@master sources themselves)
- `drivers/gpu/drm/i915/display/vlv_dsi_regs.h` (DSI controller register map, BXT_MIPI_BASE, GLK RO bits)
- `drivers/gpu/drm/i915/display/bxt_dpio_phy_regs.h` (PHY bases 0x162000/0x163000, CL1CM/REF/PCS/TX regs)
- `drivers/gpu/drm/i915/display/intel_pps_regs.h` (PCH_PPS_BASE 0xC7200, PPS fields, stride)
- `drivers/gpu/drm/i915/display/intel_display_debugfs.c` (registration list, RPM/modeset-lock read pattern, write-side fops patterns)
- `drivers/gpu/drm/i915/display/vlv_dsi.c` (DSI-PLL hang warning; glk_cold_boot logic; `intel_dsi_prepare` register writes; `display->dsi.mmio_base = BXT_MIPI_BASE` ~line 1918)
- `drivers/gpu/drm/i915/display/intel_display_regs.h:22-23` (BXT_P_CR_GT_DISP_PWRON 0x138090, MIPIO_RST_CTRL bit 2)
- `drivers/gpu/drm/i915/display/vlv_dsi_pll_regs.h:81` (BXT_DSI_PLL_CTL 0x161000)
- grep.app index of torvalds/linux master (0 hits for `i915_dsi_info` — no upstream DSI debugfs exists; index freshness confirmed via `i915_display_info` hit)

### Tertiary (LOW — validate in Wave 0/implementation)
- None carried; all upstream-adjacent claims are CITED above, all platform-specific unknowns are logged as Open Questions.

## Metadata

**Confidence breakdown:**
- Instrument design (debugfs node): HIGH — registration/read-safety patterns verified from canonical source; no upstream DSI node exists to mis-assume
- Register scope/map: HIGH for in-repo ranges (verbatim) / CITED for upstream names / the device-tree grep step is mandatory before coding
- Prior-evidence bounding of the diff: HIGH — 21-row table and empty-diff results read verbatim this session
- Pitfalls: HIGH for the PLL-hang gate and window discipline; MEDIUM for PHY readback behavior (empirical, Open Question 1)
- Mechanism-claim shape: MEDIUM by nature — it is formed from on-device data; the decision tree bounds every outcome

**Research date:** 2026-10-13
**Valid until:** 2026-11-12 (stable: repo + mainline register maps are slow-moving; re-verify only if the CI source version changes)
