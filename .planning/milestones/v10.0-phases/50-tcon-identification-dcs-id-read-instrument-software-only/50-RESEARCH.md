# Phase 50: TCON Identification — DCS ID-Read Instrument (Software-Only) - Research

**Researched:** 2026-10-16
**Domain:** Linux i915/MIPI-DSI kernel instrumentation (Geminilake), debugfs extension, hardware-in-the-loop capture protocol
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Instrument Behavior (echo 2 DCS reads)
- DCS read results go in an appended annotated section **after** the NAMED OVERLAY:
  `# DCS ID READ` header, one `DCS`-prefixed annotated line per read (keeps rows out of
  the `^0x...=` record regex the diff tooling parses).
- Per-read failure semantics: record the errno/failure per read and **continue** all five
  reads — refusals are themselves informative.
- `echo 1` stays MMIO-walk-only (47/49 tooling and historical captures stay valid);
  `echo 2` = MMIO walk + DCS ID reads.
- Read timeout behavior: reuse the RX path's existing bounded `GEN_READ_DATA_AVAIL` wait
  (`intel_dsi_host_transfer`), annotate each outcome incl. errno, no extra wrapper.

#### Capture Protocol & Device Sessions
- **2 sessions**: (A) boot arm X=Y — echo-2 capture + I2C sweep + tracepoints, no suspend
  involved; (B) black-resume arm X=Z — separate user-authorized suspend/resume session,
  capture on resume. The suspend IS the session's one test.
- Black-resume capture mechanics: extend `scripts/capture_dsi_dumps.sh` with the echo-2
  mode, a `timeout`-wrapped trigger (a hanging read can never wedge the session), and a
  one-command blind invocation writing to a file.
- Diff: extend `scripts/dsi_mmio_diff.sh` to parse the `# DCS ID READ` section and emit an
  ID-read comparison block (boot-vs-resume per read: answered/errno).
- Kit registration: every new artifact goes into `MANIFEST.sha256` (both DCS dumps, I2C
  sweep outputs, tracepoint logs, diff outputs).

#### I2C Sweep Scope
- Delivery: dedicated `scripts/tcon_i2c_sweep.sh` — bus inventory, per-bus `i2cdetect -y`,
  `gpioinfo` rail claims, `dmesg` PMIC/controller lines — archives everything kit-ready in
  one run.
- Tracepoints: `i2c:i2c_write/read/reply/result` enabled during the echo-2 instrument run
  in both arms (passive observation, no extra user burden); the written conclusion must
  cover the boot-arm run at minimum.
- Bus range: dynamic — sweep every enumerated bus from `i2cdetect -l` +
  `/sys/bus/i2c/devices` (research's `seq 0 9` is a floor, not a bound).
- Conclusion location: single `docs/research/TCON_IDENTIFICATION.md` carries identity-or-
  proven-dead verdict + I2C conclusion (buses, PMIC on bus 6, sideband in/out) +
  datasheet-gated candidate notes (AUO G101EAN01.x, ILI9881C, ST7701/ST7703, HX8394(F),
  NT36672(a)) cross-checked against AUO PnP 0xaf06/6104 and FRU 5D11A20220.

#### DSI_MMIO_DIFF §6 Correction & Open Anomalies
- §6 correction scope: fix **only** the 0x6b004 row label to the bit-accurate decode
  (`SPL_PKT_SENT | HS_TX_TIMEOUT | LOW_CONTENTION`; LP_RX_TIMEOUT bit 22 NOT set),
  cross-consistent with §5.2 and `NO_CLEAN_FIX_PROOF.md` §7.1.
- `0x6b010=0xb8ea` anomaly: stays flagged **open** with a documented reason — a
  write/read-back probe is a register WRITE, which violates this instrument's read-only
  contract; it needs its own gated change.
- `0x6b080` DPHY anomaly (matches neither VBT nor kernel values): same treatment —
  flagged, documented, no action this phase.
- Ledger rows this phase: **none** — nothing here falsifies a fix lever; ID-read results
  are evidence in `TCON_IDENTIFICATION.md`. The ledger gate (`test_pitfalls_ledger.sh`)
  just stays green.

### the agent's Discretion
(none declared in CONTEXT.md — all instrument decisions are locked above)

### Deferred Ideas (OUT OF SCOPE)
- The 0x6b010 write/read-back probe (register-write instrument mode) — deliberate
  non-goal: violates the read-only instrument contract; own gated change if ever needed.
- Pre-kernel GOP bus-traffic capture — needs Phase 53 hardware (logic analyzer).
- Any fix-candidate work — Phase 51's territory; this phase only instruments and identifies.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TCON-01 | `echo 2 > .../i915_dsi_regs` performs DCS reads (0x04/0xDA/0xDB/0xDC + generic 0x83) in LP mode, VC 0, appended as annotated dump section; CI-built, sha-verified rollback retained, capture/diff scripts handle new section | Standard Stack + Architecture Patterns (§ Pattern 1/2), Code Examples (kernel write-side extension, exact `mipi_dsi_dcs_read()` call shape), Common Pitfalls 1-3 |
| TCON-02 | Boot (X=Y) and black-resume (X=Z) ID-read captures, kit-registered and diffed, cross-checked vs AUO PnP 0xaf06/6104 + FRU 5D11A20220 and 5 candidate fingerprints; identity OR proven-dead read path | Capture Protocol patterns, Code Examples (capture script echo-2 mode), Validation Architecture, Assumptions Log A1-A3 (candidate fingerprint confidence) |
| TCON-03 | I2C sideband ruled in/out: bus inventory + per-bus sweep, PMIC on bus 6, `i2c:i2c_*` tracepoints archived, written conclusion | Standard Stack (i2c-tools/libgpiod), Code Examples (tcon_i2c_sweep.sh skeleton), Common Pitfall 5 |
| TCON-04 | DSI_MMIO_DIFF §6 0x6b004 row corrected to bit-accurate decode (SPL_PKT_SENT \| HS_TX_TIMEOUT \| LOW_CONTENTION; bit 22 NOT set), consistent with §5.2 and NO_CLEAN_FIX_PROOF §7.1; 0x6b010 anomaly stays flagged | Verified bit definitions from `vlv_dsi_regs.h` (see Code Examples), Correction targets table |
</phase_requirements>

## Summary

Phase 50 extends the existing `i915_dsi_regs` debugfs node (patches/d330_dsi_dump.patch) with an `echo 2` trigger that performs the normal MMIO walk and then issues five DCS/generic reads against the live DSI device (0x04 Get Display ID, 0xDA/0xDB/0xDC per-byte fallbacks, one generic register-page read), LP mode, VC 0, port A, appending a `# DCS ID READ` annotated section. All feasibility claims were re-verified this session against mainline kernel source (torvalds/linux master, fetched raw): `mipi_dsi_dcs_read()` → `mipi_dsi_device_transfer()` → `intel_dsi_host_transfer()` implements the full RX path (clears `GEN_READ_DATA_AVAIL`, bounded 50 ms `intel_de_wait_for_set_ms`, `read_data()` from the LP GEN DATA FIFO), and the VBT sequence executor hard-refuses reads (`ret = -EOPNOTSUPP` in `mipi_exec_send_packet()` for all generic-read and DCS-read packet types) — confirming the node extension is the only software path.

The single most important new technical finding for planning: **`intel_dsi_host_transfer()` never returns an error for a timed-out read.** It logs `drm_err("Timeout waiting for read data.")`, then calls `read_data()` unconditionally and returns `4 + packet.payload_length` (always 4 for a 1-byte DCS read). A "per-read errno" as written in 50-CONTEXT.md cannot come from the return code — the instrument must discriminate answered-vs-refused by checking the `GEN_READ_DATA_AVAIL` interrupt bit (bit 29 of `MIPI_INTR_STAT(A)` = 0x6b004) after each call and annotating both the return value and the bit state. Worst case per read is two bounded 50 ms waits (~100 ms), so all five reads cost ≤ ~500 ms — a hanging read cannot wedge a session, and the `timeout`-wrapped blind invocation for the black-resume arm is belt-and-braces rather than load-bearing.

Two more verifiable implementation facts the planner needs: (1) the read primitive needs a `struct mipi_dsi_device *`, and i915's VLV/GLK driver creates exactly one per port inside `intel_dsi_host_init()` ("our little hack" — `host->device = device`, never registered with the driver model) reachable as `intel_dsi->dsi_hosts[PORT_A]->device`; its `mode_flags` and `channel` are mutated in place by the VBT executor, so the instrument must set `MIPI_DSI_MODE_LPM` + `channel = 0` on that same object before calling `mipi_dsi_dcs_read()` and must tolerate the executor having last-set them to something else. (2) The `echo 1` write side today uses `kstrtobool_from_user`, which accepts "1"/"y"/"on" but NOT "2" — the parsing must change to a value parse (e.g. `kstrtouint_from_user` with `>2` rejected) while preserving `echo 1` semantics.

**Primary recommendation:** build the `echo 2` mode as a read-side extension in `intel_dsi_dump_debugfs.c` that reuses `mipi_dsi_dcs_read()`/`mipi_dsi_generic_read()` on `dsi_hosts[PORT_A]->device`, annotates per-read outcome from the INTR_STAT bit-29 post-check (not the return code), and lands as one new CI kernel iteration with the standard sha-verified rollback discipline.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| DCS ID-read trigger (`echo 2`) | Kernel (i915 debugfs, `intel_dsi_dump_debugfs.c`) | — | Only the kernel can drive the DSI host transfer path; VBT executor refuses reads |
| MMIO walk + frozen snapshot | Kernel (existing node) | — | Unchanged; `echo 2` reuses it |
| Capture orchestration (boot/resume arms) | Userspace (`scripts/capture_dsi_dumps.sh`) | — | 47/49 discipline; triggers node, validates, checksums |
| ID-read comparison (boot vs resume) | Userspace (`scripts/dsi_mmio_diff.sh`) | — | Parses `# DCS ID READ` section into answered/errno blocks |
| I2C bus sweep + tracepoint capture | Userspace (`scripts/tcon_i2c_sweep.sh`) | Kernel tracepoints (`i2c:i2c_*`) | Passive observation; kernel emits, userspace archives |
| TCON identity verdict | Docs (`docs/research/TCON_IDENTIFICATION.md`) | — | Human-reasoned cross-check of ID bytes vs candidate fingerprints |
| §6 register-label correction | Docs (`docs/research/DSI_MMIO_DIFF.md`) | — | Pure documentation fix; ledger gate re-verified |
| CI kernel build + rollback-deploy | CI (`.github/workflows/build-kernel.yml`) + `scripts/deploy_d330_kernel.sh` | — | Existing pipeline; one new iteration |

## Standard Stack

### Core

| Library/Tool | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Linux i915 DSI host (`vlv_dsi.c` `intel_dsi_host_transfer`) | in-kernel (Ubuntu 7.0.0-38-generic tree, GLK) | RX path for DCS/generic reads | The only software path to the panel; verified RX-implemented |
| `mipi_dsi_dcs_read()` / `mipi_dsi_generic_read()` (`drm_mipi_dsi.c`) | in-kernel | Read primitives building DCS_READ (0x06) / GENERIC_READ_REQUEST (0x04/0x14/0x24) packets | Standard MIPI helper API; sets LPM flag from `dsi->mode_flags` |
| `patches/d330_dsi_dump.patch` (existing) | phase-47, post-49 re-probe-safe | Base node being extended | Frozen output contract; additive-only extension |
| `.github/workflows/build-kernel.yml` (existing) | manual-dispatch CI | Builds `linux-image-*-d330-fix` .deb | Only build path (D330 too slow to compile locally) |
| `scripts/deploy_d330_kernel.sh` (existing) | sha-verified-rollback discipline | Deploy with unbreakable rollback | Proven across 47-49; rollback deb `d47_dump_kernel.deb` retained |

### Supporting

| Library/Tool | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `i2c-tools` (`i2cdetect -l`, `i2cdetect -y`) | distro package on device | I2C bus inventory + address sweep | TCON-03 sweep; install on device if absent (`apt install i2c-tools`) |
| `libgpiod` (`gpioinfo`) | distro package on device | PMIC GPIO rail claims | TCON-03; identifies GPIO 144/145/160 owners |
| ftrace `i2c:i2c_write/read/reply/result` | in-kernel tracepoints (verified in `include/trace/events/i2c.h`) | Passive I2C transfer capture during instrument run | TCON-03; enable via tracefs during both arms |
| `timeout` (coreutils) | distro | Wraps blind echo-2 trigger on resume arm | Black-resume session (locked decision) |
| `sha256sum` + `docs/dumps/re_kit/MANIFEST.sha256` + `scripts/prepare_safety_kit.sh --register` | existing kit tooling | Artifact registration/verification | Every new capture, trace log, sweep output, diff output |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Extending `i915_dsi_regs` (`echo 2`) | New separate debugfs node (`i915_dsi_info`) | Rejected by locked decision + research §3.3: no upstream precedent, duplicate registration/PLL-gating/buffer code; extend the proven node |
| `mipi_dsi_dcs_read()` direct call | VBT sequence executor read element | Impossible: `mipi_exec_send_packet()` returns `-EOPNOTSUPP` for all READ types (verified mainline); would need executor redesign |
| Return-value-only annotation | INTR_STAT bit-29 post-check | Return value is ALWAYS ≥0 on this host (verified); bit check is the only reliable answered/refused discriminator |
| `kstrtobool_from_user` (keep) | `kstrtouint_from_user` value parse | kstrtobool rejects "2"; must change; uint-parse with `>2` → `-EINVAL` preserves echo 1 |

**Installation (device-side, TCON-03 only):**
```bash
sudo apt-get install -y i2c-tools libgpiod-tools   # if absent; probe first, archive versions
```

**Version verification:** No new kernel-side packages (all in-tree symbols). Device-side tools are distro packages; the sweep script should archive `i2cdetect --version`/`gpioinfo --version` output into the kit for provenance. Kernel tree version is pinned by the CI input (`kernel_version`, e.g. `7.0.0-38-generic`) — the deployed baseline is `7.0.14-d330-fix` per capture script; the exact next-iteration kernel version is a deploy-time decision, not a research decision.

## Package Legitimacy Audit

No external registry packages are installed by this phase. Device-side `i2c-tools` and `libgpiod-tools` are canonical Debian/Ubuntu archive packages (decades-old maintenance), not npm/PyPI additions — the Package Legitimacy Gate does not apply. No packages removed; none flagged.

## Architecture Patterns

### System Architecture Diagram

```
[Session A: boot, X=Y]                          [Session B: suspend/resume, X=Z]
        |                                                  |
 user runs:                                          user triggers suspend/resume
 sudo capture_dsi_dumps.sh boot2 [outdir]           (one test per session, own verdict)
        |                                                  |
        v                                                  v
 timeout 15 sh -c 'echo 2 > /sys/kernel/debug/dri/*/i915_dsi_regs'   (blind, file-output)
        |                                                  |
        +--------------------> kernel <---------------------+
                                |
        d330_dsi_dump_write(): kstrtouint(2) -> walk (unchanged) -> DCS reads:
        mipi_dsi_dcs_read(dsi_hosts[PORT_A]->device, 0x04/0xDA/0xDB/0xDC)
        mipi_dsi_generic_read(device, {0x00}, ...)  [LP via mode_flags, VC 0]
        per read: annotate ret + INTR_STAT bit29 post-check, continue on failure
                                |
                                v
        frozen buffer: # RANGE ... / records / # NAMED OVERLAY / # DCS ID READ
                                |
        cat node > file    +    dmesg D330DSIREG line    +    i2c trace log
                                |
                                v
        prepare_safety_kit.sh --register -> MANIFEST.sha256
                                |
        dsi_mmio_diff.sh boot2_dump resume2_dump -> ID-read comparison block
                                |
                                v
        docs/research/TCON_IDENTIFICATION.md: identity OR proven-dead verdict
        (cross-check: AUO PnP 0xaf06/6104, FRU 5D11A20220, 5 candidate fingerprints)
        + I2C conclusion (buses, PMIC bus 6, sideband in/out)
        + DSI_MMIO_DIFF.md §6 0x6b004 row corrected
```

### Recommended Project Structure (files touched)

```
patches/
└── d330_dsi_dump.patch        # extended: echo-2 write side + DCS read section
scripts/
├── capture_dsi_dumps.sh       # extended: echo-2 mode, timeout-wrapped trigger, blind invocation
├── dsi_mmio_diff.sh           # extended: # DCS ID READ parser + comparison block + selftest fixtures
└── tcon_i2c_sweep.sh          # NEW: bus inventory + i2cdetect + gpioinfo + dmesg, kit-ready archive
docs/research/
├── TCON_IDENTIFICATION.md     # NEW deliverable: verdict + I2C conclusion + candidate notes
└── DSI_MMIO_DIFF.md           # §6 0x6b004 row corrected only
.github/workflows/
└── build-kernel.yml           # apply-verification greps for the new symbols (same pattern)
```

### Pattern 1: LP-mode DCS read via the port's virtual mipi_dsi_device

**What:** the read primitive operates on the `mipi_dsi_device` that `intel_dsi_host_init()` allocates per port ("our little hack"). LP mode and VC are properties of that object, not of the call.

**When to use:** every read in the echo-2 instrument.

**Example (kernel, additive to `intel_dsi_dump_debugfs.c`):**
```c
// Source: mainline vlv_dsi.c / intel_dsi.c / drm_mipi_dsi.c (fetched raw this session)
#include <drm/drm_mipi_dsi.h>
#include "intel_dsi.h"   /* struct intel_dsi_host, enc_to_intel_dsi() */

static void d330_dsi_dump_id_reads(struct intel_display *display)
{
	/* find the DSI encoder -> intel_dsi -> port A host -> virtual device */
	struct intel_dsi *intel_dsi /* from the DSI encoder on this display */;
	struct mipi_dsi_device *dsi_dev = intel_dsi->dsi_hosts[PORT_A]->device;
	u8 buf[3];
	ssize_t ret;

	d330_dsi_dump_add("# DCS ID READ\n");
	if (!dsi_dev) {
		d330_dsi_dump_add("DCS SKIP no-dsi-device-for-port-A\n");
		return;
	}
	/* LP + VC 0 (the VBT executor mutates these in place - set every run) */
	dsi_dev->mode_flags |= MIPI_DSI_MODE_LPM;
	dsi_dev->channel = 0;

	ret = mipi_dsi_dcs_read(dsi_dev, 0x04 /* MIPI_DCS_GET_DISPLAY_ID */, buf, 3);
	/* answered/refused from INTR_STAT bit 29 (GEN_READ_DATA_AVAIL) post-check:
	   intel_dsi_host_transfer() ALWAYS returns >= 4 even on RX timeout       */
	d330_dsi_dump_add("DCS 0x04 id read ret=%zd avail=%d data=%*ph\n",
			  ret, d330_dsi_intradata_avail(display, PORT_A), 3, buf);
	/* ... repeat for 0xDA / 0xDB / 0xDC (1 byte each), generic read reg 0x00 ... */
}
```

**Call-shape facts (all verified this session, mainline master):**
- `mipi_dsi_dcs_read(struct mipi_dsi_device *dsi, u8 cmd, void *data, size_t len)` builds `MIPI_DSI_DCS_READ` (0x06) short packet, `channel = dsi->channel`; `mipi_dsi_device_transfer()` adds `MIPI_DSI_MSG_USE_LPM` iff `dsi->mode_flags & MIPI_DSI_MODE_LPM` (BIT(11)).
- Generic read: `mipi_dsi_generic_read(dsi, &reg, 1, data, len)` → type `MIPI_DSI_GENERIC_READ_REQUEST_1_PARAM` (0x14). NOTE: the roadmap's "0x83" is the **Data ID byte on the wire** (0x83 = VC0?? no — 0x83 = `MIPI_DSI_GENERIC_READ_REQUEST_1_PARAM` with the high bit set is NOT a kernel enum; the kernel enum value is 0x14, and `mipi_dsi_create_packet()` computes header byte `(channel<<6)|type` = 0x14 for VC0. The "0x83" phrasing traces to vendor datasheets that label the generic read with 1 param as data-type 0x83 — the kernel constant is 0x14; use `mipi_dsi_generic_read()` and let the kernel format the header). [CITED: include/video/mipi_display.h enum, fetched this session]
- DCS cmd constants kernel-side: `MIPI_DCS_GET_DISPLAY_ID = 0x04` (verified in `include/video/mipi_display.h`). `0xDA/0xDB/0xDC` (ID1/ID2/ID3) are **not** kernel enum members — pass them as literals. [VERIFIED: include/video/mipi_display.h:82-133 fetched this session — no ID1/2/3 entries exist]

### Pattern 2: per-read outcome annotation (the errno lie)

**What:** annotate each read with BOTH the return value and the GEN_READ_DATA_AVAIL bit (bit 29, `(1 << 29)`, named `GEN_READ_DATA_AVAIL` in `vlv_dsi_regs.h`) state of `MIPI_INTR_STAT(A)` (0x6b004) after the call.

**Why:** `intel_dsi_host_transfer()` on RX timeout does `drm_err("Timeout waiting for read data.\n")` then unconditionally `read_data()`s the FIFO and returns `4 + packet.payload_length`. There is no negative errno path for a non-answering panel. CONTEXT's "record the errno" therefore means: record ret (always ≥ 4 on this host) + the avail bit + whatever bytes the FIFO returned (stale/garbage on timeout). A `dmesg | grep -c "Timeout waiting for read data"` delta per arm is a cheap secondary check the capture script can archive.

**When to use:** every read; also the diff tool's answered/errno vocabulary (answered = avail bit set; timeout = bit clear + dmesg timeout line).

### Pattern 3: capture discipline (47/49 mirror, boot + black-resume)

**What:** two user-owned sessions; every artifact kit-registered; diffed.

**Session A (boot, X=Y):** no suspend. Run I2C sweep + enable i2c tracepoints, then `capture_dsi_dumps.sh boot2` (new mode) — echo-2 trigger wrapped in `timeout 15` — then disable tracepoints, archive trace log. All outputs `prepare_safety_kit.sh --register`.

**Session B (black-resume, X=Z):** user triggers suspend/resume themselves; on resume the user runs the one-command blind invocation (script writes output to a file, no eyes needed during the run; user reports the panel verdict in their own time). ≥18 s window discipline applies. One test per session.

**Example (userspace, capture script echo-2 extension):**
```bash
# timeout-wrapped trigger: a wedged read can never strand the session (locked decision)
if ! timeout 15 sh -c "echo 2 > '$NODE'" 2>"$ERRFILE"; then
    log_err "echo-2 trigger failed or timed out: $(cat "$ERRFILE")"
    exit 1
fi
```

### Pattern 4: additive-only patch + CI proof greps

**What:** extend `patches/d330_dsi_dump.patch` in place (same file, same DMI-honest commentary style), then extend the CI `git apply` + grep-proof step with 1-2 greps for the new symbols (e.g. `grep -R 'DCS ID READ' drivers/gpu/drm/i915/display/`), following the existing per-patch comment pattern in `build-kernel.yml`.

**When to use:** always, in this repo — the CI step exists precisely to prove patches landed.

### Anti-Patterns to Avoid

- **Trusting `mipi_dsi_dcs_read()`'s return value as success:** always ≥ 4 on GLK even with a dead panel. Use the bit-29 post-check.
- **Adding a new debugfs node:** duplicates registration/PLL-gating/snapshot logic; rejected by locked decision.
- **Letting DCS lines match the record regex:** all `# DCS ID READ` rows must be `DCS`-prefixed (locked decision) or the 47/49 record counts and diff parser break.
- **Changing `echo 1` semantics:** historical captures and `test_dsi_mmio_evidence.sh` fixtures pin the format; `echo 2` must be strictly additive output.
- **Issuing reads without the PLL gate:** the BSpec machine-hang rule applies to the same DSI block; gate the DCS section behind the existing `dsi_ok` check (if PLL off, emit `# SKIPPED`-style annotation, never touch the FIFOs).
- **Writing any register from the new code:** the read-only instrument contract (and TCON-04's open-anomaly treatment) forbids write probes this phase.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| DSI packet construction (ECC, short/long format, header bytes) | Hand-built DSI packets written to GEN CTRL FIFO | `mipi_dsi_dcs_read()` / `mipi_dsi_generic_read()` | `mipi_dsi_create_packet()` handles format; host transfer handles FIFO flow-control + BTA sequencing |
| Read timeout handling | Custom wait loop around INTR_STAT | The RX path's existing bounded 50 ms `intel_de_wait_for_set_ms()` in `intel_dsi_host_transfer()` | Already bounded (2 waits × 50 ms worst per read); a wrapper adds hang risk for zero information |
| I2C bus enumeration | Hand-rolled `/sys` walkers alone | `i2cdetect -l` + `i2cdetect -y` (archive both) | Address-probe edge cases (SMBus block, busy adapters) are solved; per-bus probing is exactly i2cdetect's job |
| sha256 kit registration | Ad-hoc `sha256sum >> MANIFEST` | `scripts/prepare_safety_kit.sh --register` | Idempotent, path-validated, `--verify` round-trip already gates 47/49 evidence |
| Diff parsing of the new section | Separate one-off parser | Extend `dsi_mmio_diff.sh` (selftest fixtures included) | Determinism + citation requirements (D-06/D-07) already engineered there |

**Key insight:** every hand-rolled alternative here re-implements either a MIPI protocol detail (packet format/FIFO/BTA) or a proven repo discipline (kit, diff determinism) — the failure modes are silent data corruption (wrong header bytes) or unauditable evidence, both of which have burned this project before (threat T-47-06 non-data classification exists precisely because of ad-hoc parsing).

## Common Pitfalls

### Pitfall 1: Return-value errno does not exist on the GLK DSI read path
**What goes wrong:** instrument annotates every read as "ret=4 OK" even when the panel is dead; TCON-02 verdict becomes meaningless.
**Why it happens:** `intel_dsi_host_transfer()` returns `4 + packet.payload_length` unconditionally; RX timeout only emits `drm_err` and proceeds to `read_data()`.
**How to avoid:** per-read post-check of `MIPI_INTR_STAT(A)` bit 29 (`GEN_READ_DATA_AVAIL`); annotate `ret` + `avail` + raw bytes; archive a dmesg timeout-line count per arm.
**Warning signs:** every read "succeeds" with ret=4 but data bytes are identical across arms or read 0x00/0xff patterns.

### Pitfall 2: `kstrtobool_from_user` rejects "2"
**What goes wrong:** `echo 2 > node` returns `-EINVAL` on the write; feature silently absent.
**Why it happens:** the existing write side parses a bool; "2" is not a bool token.
**How to avoid:** switch to `kstrtouint_from_user()` (or manual first-byte parse), accept 0/1/2, reject `>2` with `-EINVAL`, preserve `echo 1` exactly; update the capture script and its contract comment in the same change.

### Pitfall 3: mode_flags/channel residue from the VBT executor
**What goes wrong:** reads issue in HS mode or wrong VC — panel ignores them or, worse, HS contention on a link already running video.
**Why it happens:** the VBT executor mutates `dsi_device->mode_flags` and `->channel` in place per packet; whatever it last set persists.
**How to avoid:** set `mode_flags |= MIPI_DSI_MODE_LPM` and `channel = 0` at the start of every echo-2 run (as the code example shows); never assume defaults.

### Pitfall 4: reading DSI block with PLL off (machine-hang rule)
**What goes wrong:** BSpec-documented hang on BXT/GLK when DSI registers are accessed with a bad/off PLL.
**Why it happens:** same rule that already gates the MMIO walk.
**How to avoid:** gate the DCS section behind the existing `dsi_ok = !((geminilake||broxton) && !bxt_dsi_pll_is_enabled())` check; when off, annotate the skip, don't touch FIFOs. (Gate never tripped on any 47-49 capture, but it must exist.)

### Pitfall 5: i2c tracepoints miss pre-kernel GOP traffic
**What goes wrong:** conclusion over-claims "no sideband traffic ever" from kernel-only traces.
**Why it happens:** tracepoints trace i2c-core transfers of the running kernel only; GOP traffic happens before kernel start.
**How to avoid:** scope the written conclusion to kernel-era traffic; note the pre-kernel blind spot explicitly (needs Phase 53 logic analyzer) — CONTEXT already locks this framing.

### Pitfall 6: diff/capture tooling breaks on format drift
**What goes wrong:** `test_dsi_mmio_evidence.sh` or the diff selftest goes red after the new section lands.
**Why it happens:** the parser treats non-record lines inside a `# RANGE` section as warnings; a `DCS` row placed wrongly (e.g. inside a range section instead of after NAMED OVERLAY) flips classifications.
**How to avoid:** `# DCS ID READ` section strictly after the overlay; `DCS`-prefixed rows; extend `--selftest` fixtures to cover: section present on both arms, section present on one arm only, `DCS SKIP` annotation.

### Pitfall 7: resume-arm capture misses the window
**What goes wrong:** the echo-2 trigger lands after the X=Z state drifts (≥30 s late-black was the 49 discriminator; timing matters).
**Why it happens:** blind invocation must be pre-staged and one-command.
**How to avoid:** pre-copy the capture script to the device, single command + `timeout`, user runs it immediately on resume; record trigger timestamps in the session log (existing capture script already stamps).

## Code Examples

Verified patterns from official sources (all fetched this session from torvalds/linux master raw):

### RX path behavior (vlv_dsi.c) — what the instrument relies on
```c
// drivers/gpu/drm/i915/display/vlv_dsi.c (mainline, verbatim structure)
if (msg->rx_len) {
	intel_de_write(display, MIPI_INTR_STAT(display, port), GEN_READ_DATA_AVAIL);
}
/* ... write ctrl header ... */
if (msg->rx_len) {
	data_mask = GEN_READ_DATA_AVAIL;
	if (intel_de_wait_for_set_ms(display, MIPI_INTR_STAT(display, port),
				     data_mask, 50))
		drm_err(display->drm, "Timeout waiting for read data.\n");
	read_data(display, data_reg, msg->rx_buf, msg->rx_len);   /* unconditional */
}
/* XXX: fix for reads and writes */
return 4 + packet.payload_length;                                 /* always >= 4 */
```

### Bit definitions for TCON-04's §6 correction (vlv_dsi_regs.h, verbatim)
```c
#define  SPL_PKT_SENT_INTERRUPT				(1 << 30)
#define  GEN_READ_DATA_AVAIL				(1 << 29)
#define  LP_RX_TIMEOUT					(1 << 22)
#define  HS_TX_TIMEOUT					(1 << 21)
#define  LOW_CONTENTION					(1 << 19)
```
`0x40280000` = bits 30|21|19 = `SPL_PKT_SENT_INTERRUPT | HS_TX_TIMEOUT | LOW_CONTENTION`; bit 22 (0x400000) is NOT present. This is the exact text the §6 row must carry.

### VBT executor read refusal (intel_dsi_vbt.c, verbatim)
```c
case MIPI_DSI_GENERIC_READ_REQUEST_0_PARAM:
case MIPI_DSI_GENERIC_READ_REQUEST_1_PARAM:
case MIPI_DSI_GENERIC_READ_REQUEST_2_PARAM:
	ret = -EOPNOTSUPP;
	break;
/* ... */
case MIPI_DSI_DCS_READ:
	ret = -EOPNOTSUPP;
	break;
```

### Virtual device creation (intel_dsi.c, verbatim shape)
```c
/* intel_dsi_host_init(): "We should call mipi_dsi_host_register() here, but we
   don't have a host->dev ... So just use the dsi framework as a library ...
   Create the dsi devices by ourselves here too." */
device = kzalloc_obj(*device);
device->host = &host->base;
host->device = device;    /* reachable: intel_dsi->dsi_hosts[port]->device */
```

### DCS section output contract (target format)
```
# DCS ID READ
DCS 0x04 ret=4 avail=1 data=XX XX XX     <- answered (bit29 set)
DCS 0xDA ret=4 avail=0 data=00 00 00     <- timeout (bit29 clear; dmesg has timeout line)
DCS 0xDB ret=4 avail=0 data=00 00 00
DCS 0xDC ret=4 avail=0 data=00 00 00
DCS GEN00 ret=4 avail=0 data=00 00 00
```
Rows never match `^0x...=...`; the diff tooling keys answered/timeout per read per arm.

## Correction Targets (TCON-04, exact rows)

| File | Line (current) | Current text | Correction |
|------|---------|--------------|------------|
| `docs/research/DSI_MMIO_DIFF.md` §6 | 368 | `\| 0x6b004 \| bits 30/21 clear (0x00080000 baseline) \| 40280000 \| status: no LP_RX_TIMEOUT marking \|` | Replace reading with bit-accurate decode: `SPL_PKT_SENT \| HS_TX_TIMEOUT \| LOW_CONTENTION; LP_RX_TIMEOUT (bit 22) NOT set — "HS video stream never accepted by panel"` |
| `docs/research/DSI_MMIO_DIFF.md` §4.2 | 153 | `broken adds 0x40200000 — the LP_RX_TIMEOUT-marked status the prior table recorded` | Leave AS-IS unless the planner reads §5.2's correction mandate as covering §4.2 too; §5.2 (line 294) already carries the corrected decode. CONTEXT locks "fix only the 0x6b004 row label" in §6 — do not widen scope. |
| `docs/research/DSI_MMIO_DIFF.md` §6 | 363 | `0x6b010 ... LP RX timeout must be left at the boot value, not a fired real time` | Note: the register is actually `MIPI_HS_TX_TIMEOUT(A)` (0xb010 in `vlv_dsi_regs.h`); the `0xb8ea` anomaly stays flagged-open with documented reason per CONTEXT. Label fix optional; anomaly flag mandatory. |
| `docs/research/NO_CLEAN_FIX_PROOF.md` §7.1 | — | consistency check only | Verify §7.1's mechanism sentence remains cross-consistent after the §6 edit; no edit expected. |

Gate re-verification after edits: `bash scripts/test_dsi_mmio_evidence.sh` and `bash scripts/test_pitfalls_ledger.sh` must stay green (the evidence gate pins ≥10 citation anchors, exclusion table, single mechanism claim — a label-only edit preserves all).

## Supporting Script Skeleton (tcon_i2c_sweep.sh)

```bash
#!/usr/bin/env bash
# scripts/tcon_i2c_sweep.sh - Phase 50 I2C sideband sweep (TCON-03)
# Archives: bus inventory, per-bus i2cdetect, gpioinfo rail claims, dmesg PMIC lines.
# Usage: sudo tcon_i2c_sweep.sh [outdir]   (default: $SUDO_USER home + /d330_dsi_capture)
set -euo pipefail
OUTDIR="${1:-${HOME}/d330_dsi_capture}"; mkdir -p "$OUTDIR"
OUT="$OUTDIR/i2c_sweep.txt"
{
  echo "# I2C SWEEP $(date '+%F %T %z')"
  echo "== i2cdetect -l";            i2cdetect -l
  echo "== /sys/bus/i2c/devices";    for d in /sys/bus/i2c/devices/i2c-*; do echo "$d $(cat "$d/name")"; done
  for n in $(i2cdetect -l | awk '{print $1}' | sed 's/i2c-//' | sort -un); do
      echo "== i2cdetect -y $n";     i2cdetect -y "$n" || true
  done
  echo "== gpioinfo (panel/bklt/reset/pmic claims)"; gpioinfo 2>/dev/null | grep -iE "panel|bklt|reset|INT33FF|pmic" || true
  echo "== dmesg pmic/i2c";          dmesg | grep -iE "pmic|i2c_designware|gpo" || true
} > "$OUT" 2>&1
sha256sum "$OUT"
```
Dynamic bus range is honored (bus list derived from `i2cdetect -l`, not `seq 0 9`). Tracepoint capture stays in the capture session (not this script) per the locked decision that tracepoints run during the echo-2 instrument run.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | TCON candidate ID fingerprints (AUO G101EAN01.x / ILI9881C / ST7701/ST7703 / HX8394(F) / NT36672(a)) as listed in research §2.3 are MEDIUM confidence (vendor datasheets, kernel panel drivers) | TCON-02 cross-check | A successful 3-byte ID that matches none of the five still identifies nothing — verdict becomes "ID captured, no fingerprint match"; not blocking, but the datasheet-gated notes step may yield nothing |
| A2 | "generic 0x83 read" in the roadmap maps to kernel `MIPI_DSI_GENERIC_READ_REQUEST_1_PARAM` = 0x14 (data ID on wire), via `mipi_dsi_generic_read(dsi, {0x00}, 1, ...)` | TCON-01 | If a vendor literally expects wire byte 0x83 (nonstandard), the kernel enum can't produce it without a custom packet type; mitigation: the generic read is a fallback probe, DCS 0x04/0xDA-DC are primary |
| A3 | FRU 5D11A20220 → bare-glass cross-reference does not exist publicly (research §2.2, LOW/MEDIUM) | TCON-02 | A new cross-reference appearing would shortcut the DCS read entirely — harmless |
| A4 | `i2c-tools`/`libgpiod-tools` are installable on the device from the Ubuntu archive (they were not confirmed present on-device this session) | TCON-03 | If absent and no network, the sweep script degrades to sysfs-only inventory; tracepoints still work (in-kernel) |
| A5 | The deployed kernel version for this iteration will follow the existing CI input pattern; exact version is a deploy-time decision | TCON-01 | None — no research dependency |
| A6 | Reading `MIPI_INTR_STAT(A)` (0x6b004) after a DCS read to sample bit 29 is side-effect-free (W1C register: READ does not clear; only writes clear) | Pattern 2 | If reads had side effects the MMIO walk itself would already be perturbing state — contradicted by 47/49 evidence (frozen snapshots diffed cleanly) |

**If any claim above becomes load-bearing at execution: re-confirm before use.**

## Open Questions (RESOLVED)

1. **RESOLVED: Does the DSI host accept LP reads while the HS video stream is running (boot X=Y)?**
   - What we know: BTA enabled (VBT block 52); RX path implemented; reads are issued on the LP GEN channel while video runs on HS.
   - What's unclear: some hosts serialize LP access against active video; behavior on GLK untested.
   - Recommendation: proceed — worst case is timeout annotations on both arms (informative, not blocking). The bit-29 annotation makes the outcome interpretable either way.

2. **RESOLVED: How does the instrument find the `intel_dsi` encoder pointer from `struct intel_display *` in the debugfs file?**
   - What we know: the node stores `display` (from `filp->private_data`); `intel_dsi` is an encoder; `dsi_hosts[PORT_A]->device` is the read target.
   - What's unclear: the exact traversal (connector→encoder or platform device list) in the 7.0 tree — the 47 patch only used `display`.
   - Recommendation: at implementation, walk `display->mode_config` connectors for the DSI connector (`intel_connector` with `mipi` panel), or iterate encoders for `INTEL_OUTPUT_DSI`; fall back to a `drm_WARN` + SKIP annotation if none found. Small implementation-time check, not a research blocker.

3. **RESOLVED: Will `kstrtouint_from_user` accept the literal `echo 2` payload ("2\n")?**
   - Known: kernel string-to-uint helpers accept trailing newline; `echo` appends one. Low risk.
   - Recommendation: covered by the `--selftest`-style host-side format fixtures; verify in CI build + first boot-arm run.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| GitHub Actions CI (`build-kernel.yml`) | TCON-01 kernel build | ✓ (workflow present, manual dispatch) | n/a | — |
| Deploy host tools (ssh/scp/sha256sum via WSL/gitbash) | deploy | ✓ (deploy scripts proven 47-49) | n/a | — |
| Device: debugfs node `i915_dsi_regs` | TCON-01/02 | ✓ (kernel 7.0.14-d330-fix baseline carries it) | 7.0.14-d330-fix | new CI iteration extends it |
| Device: `i2c-tools` | TCON-03 | ? (not confirmed this session) | — | `apt install i2c-tools`; sysfs-only inventory as last resort |
| Device: `libgpiod-tools` (`gpioinfo`) | TCON-03 | ? (not confirmed) | — | `apt install libgpiod-tools`; dmesg/sysfs GPIO fallback |
| Device: tracefs (`/sys/kernel/tracing`) | TCON-03 tracepoints | ? (was used in 47-49 ftrace markers → likely ✓) | — | kernel cmdline `trace_event=` boot-time equivalent |
| Device: rollback deb `d47_dump_kernel.deb` sha-verified | deploy safety | ✓ (retained per deploy script contract) | — | must NOT be overwritten by incoming deb (distinct upload name) |

**Missing dependencies with no fallback:** none blocking.
**Missing dependencies with fallback:** i2c-tools/libgpiod (TCON-03 degrades to sysfs-only; conclusion must state the degradation honestly).

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | bash gate scripts (repo convention; no unit-test framework for kernel patches) |
| Config file | none — scripts are self-contained with `--selftest`/`--fixtures` modes |
| Quick run command | `bash scripts/dsi_mmio_diff.sh --selftest && bash scripts/test_dsi_mmio_evidence.sh && bash scripts/test_pitfalls_ledger.sh` |
| Full suite command | same three gates (they are the gates) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TCON-01 | echo-2 section format + script handling | static gate | `bash scripts/dsi_mmio_diff.sh --selftest` (new fixtures) + `bash scripts/test_dsi_mmio_evidence.sh` | ❌ Wave 0 (extend selftest) |
| TCON-01 | CI kernel carries the echo-2 mode | CI proof | `gh workflow run build-kernel.yml` + grep-proof step in workflow | ✅ (workflow) / ❌ (greps) |
| TCON-02 | ID-read captures both states, kit-registered | device session | `bash scripts/prepare_safety_kit.sh --verify --kit-dir docs/dumps/re_kit` after registration | ✅ |
| TCON-03 | I2C sweep archived | device session | `sudo scripts/tcon_i2c_sweep.sh` exit 0 + sha in manifest | ❌ (new script) |
| TCON-04 | §6 label corrected, gates green | static gate | `bash scripts/test_dsi_mmio_evidence.sh` | ✅ |

### Sampling Rate

- **Per task commit:** the three static gates above (< 30 s total).
- **Per wave merge:** same + `git apply --check` of the extended patch against a clean tree if available.
- **Phase gate:** CI kernel built, deployed with rollback retained, both device sessions complete, all artifacts registered, `prepare_safety_kit.sh --verify` exits 0.

### Wave 0 Gaps

- [ ] `scripts/dsi_mmio_diff.sh` selftest fixtures for the `# DCS ID READ` section (present-both / present-one-arm / SKIP annotation)
- [ ] `scripts/tcon_i2c_sweep.sh` — new file (skeleton above)
- [ ] `scripts/capture_dsi_dumps.sh` echo-2 mode + contract comment update
- [ ] CI workflow grep-proofs for the new symbols

## Security Domain

`security_enforcement: true` (config.json), ASVS level 1. This phase is kernel instrumentation + device administration on user-owned hardware; most ASVS categories do not apply.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | marginal | debugfs node is 0600 (root-only), unchanged from 47 |
| V5 Input Validation | yes (light) | debugfs write side: numeric parse, `>2` → `-EINVAL`; no unbounded copies; user-string handling via `kstrtouint_from_user` (bounded) |
| V6 Cryptography | no | — |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Debugfs write with hostile payload | Tampering | `kstrtouint_from_user` bounded parse; reject unknown modes; existing mutex/EBUSY discipline retained |
| Evidence tampering (kit) | Repudiation | `MANIFEST.sha256` + `prepare_safety_kit.sh --verify` round-trip before any verdict |
| Deploy clobbering the rollback asset | Tampering | `deploy_d330_kernel.sh` distinct incoming-name discipline (documented 2026-10-15 incident); never `rm`, sha-verified before dpkg |

## Sources

### Primary (HIGH confidence)
- mainline `drivers/gpu/drm/i915/display/vlv_dsi.c` (fetched raw this session) — RX path, unconditional `read_data()`, `return 4 + payload`, 50 ms bounded waits
- mainline `drivers/gpu/drm/i915/display/intel_dsi.c` + `intel_dsi.h` (fetched) — `intel_dsi_host_init()` virtual device ("our little hack"), `struct intel_dsi_host { ... device }`
- mainline `drivers/gpu/drm/i915/display/intel_dsi_vbt.c` (fetched) — `-EOPNOTSUPP` for all READ packet types; in-place `mode_flags`/`channel` mutation
- mainline `drivers/gpu/drm/drm_mipi_dsi.c` + `include/drm/drm_mipi_dsi.h` (fetched) — `mipi_dsi_dcs_read()`, `mipi_dsi_generic_read()`, LPM flag propagation (`MIPI_DSI_MODE_LPM` BIT(11), `MIPI_DSI_MSG_USE_LPM` BIT(1))
- mainline `drivers/gpu/drm/i915/display/vlv_dsi_regs.h` (fetched) — bit definitions: `SPL_PKT_SENT_INTERRUPT (1 << 30)`, `GEN_READ_DATA_AVAIL (1 << 29)`, `LP_RX_TIMEOUT (1 << 22)`, `HS_TX_TIMEOUT (1 << 21)`, `LOW_CONTENTION (1 << 19)`
- mainline `include/video/mipi_display.h` (fetched) — `MIPI_DCS_GET_DISPLAY_ID = 0x04`; generic read request enum 0x04/0x14/0x24; DCS_READ 0x06; absence of 0xDA/DB/DC enums
- `.planning/research/v10.0-tcon-hunt.md` (read this session) — instrument design §4, I2C facts §3.1-3.2, register map §5.2, candidate table §2.3
- `patches/d330_dsi_dump.patch`, `scripts/capture_dsi_dumps.sh`, `scripts/dsi_mmio_diff.sh`, `scripts/prepare_safety_kit.sh`, `scripts/deploy_d330_kernel.sh`, `.github/workflows/build-kernel.yml` (all read this session)

### Secondary (MEDIUM confidence)
- `.planning/research/v10.0-SUMMARY.md`, `docs/research/DSI_MMIO_DIFF.md` §5.2/§6, `docs/research/NO_CLEAN_FIX_PROOF.md` §7.1 (read this session) — X=Y/X=Z operational sets, §6 correction mandate
- On-device VBT decode (`docs/dumps/re_kit/runtime_vbt_decode.txt` via tcon-hunt citations) — BTA enabled (block 52), PMIC bus 6, block 53 element inventory

### Tertiary (LOW confidence)
- TCON candidate fingerprints + FRU 5D11A20220 cross-reference status (web-sourced in prior research; carried as Assumptions A1/A3)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every kernel symbol and behavior re-verified from mainline source this session; repo tooling read directly
- Architecture: HIGH — extension points identified in the actual patch/scripts; output contracts quoted verbatim
- Pitfalls: HIGH for Pitfalls 1-4, 6 (source-verified or contract-derived); MEDIUM for Pitfall 7 (timing window behavior inferred from 49 discipline, not re-tested)

**Research date:** 2026-10-16
**Valid until:** 30 days (kernel-tree APIs stable; CI kernel version is a deploy-time input)



