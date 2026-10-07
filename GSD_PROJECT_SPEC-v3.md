# MASTER TASK SPECIFICATION: Lenovo IdeaPad D330-10IGL Linux Display & Power Parity Project

## 1. Executive Mission & Autonomous Goal

You are an expert embedded Linux graphics driver engineer, reverse engineer, and autonomous software development agent. You are operating in **Full GSD (Get Stuff Done) Autonomous Mode**.

Your goal is to self-initialize this project repository, manage its state using GSD skills, create a private GitHub repository for tracking, and autonomously execute a multi-phase investigation and patch development process to resolve the display resume failure on the **Lenovo IdeaPad D330-10IGL** (Gemini Lake Refresh / Type 82H0, Intel Celeron N4020/N4120, Intel UHD Graphics 600).

---

## 2. GSD Autonomous Operating Protocol & Bootstrapping

When this specification is loaded, **do not halt or ask for step-by-step confirmation for phase transitions**. Use your internal GSD skill set / harness to manage execution flow.

### Step 2.1: Private GitHub Repository Provisioning
1. Initialize local Git repository: `git init -b main`
2. Create `.gitignore` ignoring build artifacts, raw binary dumps, temporary logs, and driver installers:
   ```text
   .gsd/work/
   docs/dumps/raw/
   drivers_base/*.exe
   drivers_base/*.zip
   *.o
   *.ko
   *.so
   ```
3. Provision a **Private GitHub Repository** using GitHub CLI (`gh`):
   `gh repo create lenovo-d330-linux-fix --private --source=. --remote=origin`
4. Stage initial files and push:
   `git add . && git commit -m "feat: initialize GSD project structure and master spec" && git push -u origin main`

### Step 2.2: GSD State & Harness Setup
Initialize the persistent GSD state tracking system inside `.gsd/`:
- **`.gsd/PROJECT.md`**: Master project manifest, architecture goals, target specs, definition of done.
- **`.gsd/STATE.md`**: Current active state, phase progression, active blockers, immediate next action.
- **`.gsd/CONTEXT.md`**: Accumulated hardware telemetry, verified constraints, ACPI method maps, hypothesis tree.
- **`.gsd/ROADMAP.md`**: Phase checklist with pass/fail criteria.
- **`.gsd/WORKLOG.md`**: Execution history, tool outputs, git commits, and research notes.

---

## 3. Autonomous Multi-Phase Execution Roadmap

### Phase 0: Project & Repository Setup
- Bootstrap repository folder layout:
  ```text
  ├── .gsd/                 # GSD state tracking files
  ├── docs/
  │   ├── research/        # Community findings, kernel bugzilla entries, GitHub notes
  │   ├── dumps/           # ACPI DSDT, VBT binary, EDID, dmesg logs
  │   └── windows_analysis/# INF parameters, decompiled pseudocode, driver hooks
  ├── drivers_base/        # Official Lenovo Windows driver baseline binaries
  ├── patches/             # DRM kernel patches and DKMS module configs
  ├── scripts/             # Automation tools (SSH telemetry, driver fetching, test loops)
  └── tools/               # REA scripts, Ghidra decompilation helpers
  ```
- Commit and push Phase 0 setup to private GitHub remote.

### Phase 1: Community Research & Prior Art Ingestion
- Deeply inspect prior work and community scripts, explicitly including:
  * **Repository**: `https://github.com/lucasgabmoreno/linuxmint_lenovod330`
  * Analyze `lenovod330-refreshscreen.sh` workaround (X11 screen re-enable/orientation hacks).
  * Document systemd sleep target masking (`systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target`).
  * Document GRUB parameters (`video=efifb:nobgrt`, `i915.enable_psr=0`, `i915.enable_fbc=0`).
  * Catalog accelerometer/sensor mount matrix rules (`BOSC0200` sensor in `/lib/udev/hwdb.d/60-sensor.hwdb`).
- Store analysis in `docs/research/COMMUNITY_FINDINGS.md`.

### Phase 2: Official Lenovo Windows Driver Baseline Acquisition
- Create `scripts/acquire_lenovo_drivers.sh` to download and unpack official Lenovo D330-10IGL (Type 82H0) Windows driver packages into `drivers_base/`:
  * **Intel Graphics Driver**: Extract `igdkmd64.sys` and INF configurations.
  * **Lenovo Mode Transition / HID Event Filter Driver**: `DS545445` package.
  * **Intel Serial IO / GPIO Driver**: Pin mapping and ACPI GPIO resources.
  * **System BIOS / ACPI Updates**: Extract raw BIOS binaries for ACPI DSDT/SSDT table analysis.

### Phase 3: Hardware Telemetry & ACPI Extraction
- Generate `scripts/extract_telemetry.sh` to automate remote collection over SSH from the target tablet:
  * Decompile ACPI tables (`DSDT`, `SSDT`) using `iasl -d`.
  * Extract Intel VBT (`/sys/kernel/debug/dri/0/i915_vbt`) and decode via `intel_vbt_decode`.
  * Log panel connector types (eDP vs MIPI-DSI) and panel power sequence timing targets.

### Phase 4: Differential Analysis & Reverse Engineering (Ghidra + REA)
- Analyze `igdkmd64.sys` power transition callbacks (`DXGKDDI_SETPOWERSTATE`, `PanelPowerCycleDelay`).
- Compare Windows DSI/eDP timing constants and GPIO panel enable sequences against Linux `i915` driver behavior (`intel_pps.c`, `intel_dsi_vbt.c`).
- Document discrepancies in `docs/windows_analysis/RESUME_SEQUENCE.md`.

### Phase 5: Patch Generation & DKMS Delivery
- Develop a targeted Linux kernel patch or DKMS module:
  * DMI quirk match for Lenovo D330-10IGL (`82H0`).
  * Enforce correct Panel Power Cycle delay and orientation quirks in DRM subsystem.
- Package as `patches/d330_display_resume_fix.patch` and build a standalone DKMS installer.
- Push final code, documentation, and patch deliverables to the private GitHub repository.

---

## 4. Autonomous State Transition Rule
After completing each step, automatically update `.gsd/STATE.md` and `.gsd/WORKLOG.md`, stage changes with `git add`, create a semantic git commit, push to GitHub, and advance to the next phase without waiting for manual prompts.
