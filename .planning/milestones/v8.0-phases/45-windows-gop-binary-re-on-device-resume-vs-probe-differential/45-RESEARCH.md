---
phase: 45
slug: windows-gop-binary-re-on-device-resume-vs-probe-differential
created: 2026-10-12
status: researched
---

# Phase 45 Research — RE Inputs, Tooling, Device Capabilities, i915 DSI Resume Internals

## 1. Binary acquisition (Lenovo, verified URLs + hashes)

Catalog source: `https://download.lenovo.com/catalog/82H0_Win10.xml` (18 packages).

### Display driver (igdkmd64.sys carrier)

- Package XML: `https://download.lenovo.com/consumer/mobiles/3gid020fh6y37sb0_d330_igl_82h0_2_.xml`
- Installer: `https://download.lenovo.com/consumer/mobiles/3gid020fh6y37sb0.exe`
- Size: 195,814,352 bytes; SHA256: `B119E4EACB8E0CDB83C5E1CCE879AA19517B2D9E20B38BA065545EB786CF6688`
- Content: Intel VGA Driver 27.20.100.8729 (2021-12-29), targets
  `PCI\VEN_8086&DEV_3185/3184` (GLK-R UHD 600 ✓), Win10 x64, install via
  `%PACKAGEPATH%\3gid020fh6y37sb0.exe /verysilent /DIR=...` (Inno-Setup-style
  silent switches). Extraction: 7-Zip or `innoextract` (Inno Setup archives
  open with both); the driver payload contains
  `DriverStore/FileRepository/igdlh64.inf_amd64_*/igdkmd64.sys` + the INF.

### BIOS capsule (GOP + VBT carrier)

- Package XML: `https://download.lenovo.com/consumer/mobiles/g0cn14ww_2_.xml`
- Installer: `https://download.lenovo.com/consumer/mobiles/g0cn14ww.exe`
- Size: 6,765,280 bytes; SHA256: `CB09960055C522A36BFFA5913897F0E41B90CC393F37E0B56A1A25BE44058D11`
- Content: BIOS Update Utility G0CN14WW (2023-10-27). The updater carries
  the BIOS image/capsule; 7-Zip opens the exe (UEFI capsule layout); the
  GOP driver + VBT live in the UEFI firmware volumes. UEFITool NE
  (https://github.com/LongSoft/UEFIToolNE or the classic UEFITool) or
  python `uefi_firmware` parse the volumes and extract PE32 EFI drivers.
- Cross-check and ground truth: the on-device SPI dump (below) — the
  shipped (running) firmware is what booted the panel, so the dump is the
  authoritative GOP/VBT source; the Lenovo capsule is the convenience copy.

## 2. Ghidra headless (WRE-01 tooling)

- Latest release: **Ghidra 12.1.4** (2026-09-21), asset
  `ghidra_12.1.4_PUBLIC_20260921.zip`, 569,649,598 bytes, SHA256
  `ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db`
  (https://github.com/NationalSecurityAgency/ghidra/releases/tag/Ghidra_12.1.4_build).
- Requires JDK 21+ (Ghidra 11.2+ dropped JDK 17; 12.x needs 21 — pinned by
  the Getting Started doc). Install JDK 21 (Temurin) + unzip Ghidra on the
  host.
- Headless workflow (the REA pattern): `support/analyzeHeadless.bat`
  with `-import <binary> -project <name> -postScript <script>`, or import
  + `-processor` pipelines; the LLM (GLM 5.3 Flash, i.e. this agent) drives
  iterative passes: auto-analysis → decompile target functions
  (`DxgkDdiSetPowerState` DDI table, PPS timing constants, MIPI sequence
  table) → evidence ledger with file+address+bytes citations. PE32 EFI
  modules (GOP) decompile the same way after the FV extract.
- Existing repo skeleton `tools/analyze_igdkmd64.py` (imports/strings/INF
  params + known WDDM registry parameter names) remains useful for the
  static strings/imports pass before/alongside Ghidra.

## 3. VBT decoding (WRE-03 tooling)

- **`intel_vbt_decode` IS INSTALLED ON THE DEVICE** (`/usr/bin/
  intel_vbt_decode`, from intel-gpu-tools). It prints the full VBT:
  DSI link config (single/dual link, ports), MIPI sequence version, PPS
  delays, panel name. Decode on-device over SSH, no transfer needed.
- VBT location in the SPI dump: BIOS region, `$VBT` signature (search the
  8 MB dump for `VBT` at a 16-byte-ish boundary, or extract via the
  capsule first). `grep -abo '$VBT'` on the dump finds it; carve from the
  VBT header (`$VBT` + version + size fields).
- Alternative carrier: the OpRegion mailbox (VBT also lives there at
  runtime) — not needed given the SPI route works.

## 4. Device verification results (SSH, 2026-10-12)

- **SPI flash exposed as MTD, read-only path available**: `/dev/mtd0`,
  `/dev/mtd0ro`, `mtd0: 00800000 00001000 "BIOS"` (8 MiB SPI NOR,
  `spi_nor` module loaded). Dump = `dd if=/dev/mtd0ro of=/tmp/spi.bin`
  (kernel-provided read-only device; no flashrom needed and no write path
  — the safest possible dump route).
- `flashrom` NOT installed (`command -v` empty) — unnecessary given mtd0ro.
- **`intel_vbt_decode` present** at `/usr/bin/intel_vbt_decode`.
- Backlight sysfs exists and is panel-bound:
  `/sys/class/backlight/intel_backlight -> .../card1-DSI-1/intel_backlight`
  (brightness/actual_brightness/bl_power readable per arm — the phase 44
  "unmeasurable verdict" gap has a register-level channel).
- Source tree `~/d330-kernel/linux-7.0.0/drivers/gpu/drm/i915/display/`
  contains the DSI/PPS/quirk surface AND the prior Option-2 experiment
  artifacts: `intel_pps.c` (+ `.orig`), `vlv_dsi.c` (+ `.orig`, `.dphy`,
  `.preclk`, `.predcs`), `intel_dsi.c`, `intel_dsi_vbt.c` (+ defs header),
  `intel_dsi_dcs_backlight.c`, `intel_quirks.c`, `icl_dsi.c`, `vlv_dsi_pll.c`.
  The current `intel_pps.c` is the PATCHED one (the Option 2 PPS clamp);
  the `.orig`/variant files are the prior attempts — the fix iteration
  starts from this tree's current state via CI (`build-kernel.yml`).
- `/sys/kernel/debug/dri/0/` needs sudo+debugfs (not mounted for the
  unprivileged listing) — use sudo -S over SSH for debugfs reads.

## 5. i915 v7.0 DSI resume internals (where a DMI-gated change lands)

- DSI teardown/restore: `vlv_dsi.c` (VLV/GLK DSI host `prepare/enable`,
  `shutdown`, `resume` paths), `intel_dsi_vbt.c` (VBT MIPI sequences 0-6
  executed via `intel_dsi_vbt_exec_sequence`, incl. the LP/HS lane state
  transitions on power on/off), `intel_dsi.c` (common DSI
  enable/disable/backlight), `intel_dsi_dcs_backlight.c` (DCS backlight on
  this panel class), `intel_pps.c` (panel power sequencing delays —
  already carries the Option 2 clamp patch), `intel_quirks.c` (DMI-gated
  quirk precedent: `quirk_set_*` hooks incl. PPS override patterns and
  `intel_..._quirks` table matched on DMI strings).
- The differential's question in code terms: what does the unbind/bind
  reload (full i915 probe: `intel_dsi_prepare` → VBT panel-power-on
  sequences → DPHY init → PPS assert) do that the S3 resume path
  (`intel_dsi_pre_enable` from `d3cold`-restored state, possibly skipping
  VBT power-on because the driver thinks power never went away) does not.
  Prime suspects per prior docs: skipped VBT MIPI power-on sequences on
  resume vs. on probe; DSI C clock divider / readout state
  (`615c8ec48621` area, ruled out as differentiator but same file family);
  PPS delays on the VDD rail (Option 2 clamp already attempted — its
  variants are IN the tree and its outcome is recorded in the ledger).
- ftrace/registers for the differential: the five display register ranges
  named by RESUME_CAPTURE_PROTOCOL.md (DSI TX/DPHY, PPS/PPWR, pipe/CRTC,
  backlight PWM/BLM, and the DSI C clock divider block) map to MMIO in the
  i915 display engine — captured via ftrace function graph on the
  `intel_dsi*`/`intel_pps*`/`vlv_dsi*` symbols plus MMIO traces (per the
  protocol doc), NOT via log greps (logs are clean — established).

## 6. WDDM/GOP literature (background, prior repo docs)

- `docs/windows_analysis/RESUME_SEQUENCE.md` — WDDM power-state callback
  flow (DxgkDdiSetPowerState D0→D3/D3→D0 with QPC-timestamped
  PanelPowerCycleDelay enforcement, INF registry PPS values). Marked
  SUPERSEDED for its eDP/PPS-timing CONCLUSION, still valid as WDDM
  background for what to look for in the binary.
- `docs/research/DISPLAY_RESUME_CCS_MODIFIER.md`,
  `docs/research/DSI_RESUME_TRACE_ANALYSIS.md` — the established failure
  model (DSI + rotation/CCS modifier, reload-only recovery, trace taken on
  device), the ground truth the RE must not contradict.
- Phase 44 survey: DSI resume-blank acknowledged unaddressed upstream
  (Jinman Ma, Aug 2026) — the RE findings have an interested audience.

## 7. Pitfalls (phase-specific)

- The SPI dump is the AUTHORITY for VBT/GOP (it is the firmware that
  actually boots the panel); the Lenovo BIOS capsule may carry a NEWER
  G0CN14WW image than the device's installed BIOS — version-match before
  comparing, and prefer the on-device dump for "what Windows sees".
- Driver 27.20.100.8729 is from 2021 — a newer igdkmd64 may exist in the
  Intel generic package; for DMI/INF-specific evidence the LENOVO bundle
  is the right artifact (it carries the OEM INF with the panel params).
- `/dev/mtd0ro` is safe; NEVER open `/dev/mtd0` rw and never flash.
- Kernel-log greps cannot observe the failure (clean logs, phase 44) — all
  differential evidence must come from ftrace/MMIO/sysfs (backlight
  brightness level per arm) plus the user-independent state probes.
- The eMMC index flips across boots; address the root partition by UUID.
- The reload hook is NOT installed on the device (stock recovery absent);
  the differential's "reload arm" triggers the unbind/bind MANUALLY over
  SSH, exactly like the proven recovery.
- CI-built fix kernels deploy like 7.0.14-d330-fix did; iteration budget:
  5 (user-approved); after that ROOT-04 closes the milestone on the
  packaged recovery.
