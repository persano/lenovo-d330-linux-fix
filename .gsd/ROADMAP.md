# ROADMAP: Lenovo D330-10IGL Display & Power Parity Project

## Phase 0: Project & Repository Setup
- [x] Create project layout and directories
- [x] Configure `.gitignore`
- [x] Initialize Git repository with `main` branch
- [x] Provision private GitHub repository (`lenovo-d330-linux-fix`)
- [x] Initialize GSD harness files (`PROJECT.md`, `STATE.md`, `CONTEXT.md`, `ROADMAP.md`, `WORKLOG.md`)
- [x] Initial commit and push

## Phase 1: Community Research & Prior Art Ingestion
- [x] Inspect `lucasgabmoreno/linuxmint_lenovod330` repository
- [x] Analyze `lenovod330-refreshscreen.sh` workaround script
- [x] Analyze systemd suspend masking workarounds
- [x] Analyze kernel command line parameters (`video=efifb:nobgrt`, `i915.enable_psr=0`, `i915.enable_fbc=0`)
- [x] Analyze sensor orientation quirks (`BOSC0200` in `/lib/udev/hwdb.d/60-sensor.hwdb`)
- [x] Document findings in `docs/research/COMMUNITY_FINDINGS.md`
- [x] Commit and push Phase 1

## Phase 2: Official Lenovo Windows Driver Baseline Acquisition
- [x] Create `scripts/acquire_lenovo_drivers.sh` with automated fetching & extraction logic
- [x] Target packages: Intel Graphics (`igdkmd64.sys`), Lenovo Mode Transition (`DS545445`), Serial IO / GPIO (`DS545448`), BIOS update (`DS545459`)
- [x] Implement robust unpackers (`innoextract`, `7z`, cabextract)
- [x] Verify script syntax and instructions
- [x] Commit and push Phase 2

## Phase 3: Hardware Telemetry & ACPI Extraction
- [x] Create `scripts/extract_telemetry.sh` for remote target extraction
- [x] Implement ACPI tables dump and disassembly (`acpidump`, `iasl -d`)
- [x] Implement VBT extraction and decoding (`intel_vbt_decode`)
- [x] Implement EDID, DRM modes, PPS timing target extraction
- [x] Document usage and extraction steps (`docs/dumps/README.md`)
- [x] Commit and push Phase 3

## Phase 4: Differential Analysis & Reverse Engineering (Ghidra + REA)
- [x] Analyze `igdkmd64.sys` power transition callbacks
- [x] Extract panel power sequence timing tables and GPIO definitions
- [x] Document discrepancies in `docs/windows_analysis/RESUME_SEQUENCE.md`
- [x] Commit and push Phase 4

## Phase 5: Patch Generation & DKMS Delivery
- [ ] Formulate DMI quirk table patch for `82H0`
- [ ] Package DRM kernel patch and DKMS module
- [ ] Commit and push Phase 5 deliverables
