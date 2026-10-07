# Hardware Telemetry & ACPI Extraction Guide

## Overview
This directory stores hardware dumps, ACPI AML/DSL tables, Intel VBT (Video BIOS Tables), EDID dumps, and Linux kernel graphics telemetry collected from the **Lenovo IdeaPad D330-10IGL (Type 82H0)**.

Extraction is automated via [`scripts/extract_telemetry.sh`](../../scripts/extract_telemetry.sh).

---

## 1. Prerequisites on Target / Host
On the target device (or remote Linux environment), ensure the following tools are installed:
```bash
sudo apt update && sudo apt install -y \
    acpica-tools \
    intel-gpu-tools \
    edid-decode \
    pciutils \
    usbutils \
    dmidecode
```

*Note*:
- `acpica-tools` provides `acpidump` and `iasl` for disassembling AML bytecode into readable ASL (`.dsl`).
- `intel-gpu-tools` provides `intel_vbt_decode` for decoding binary VBT structures.
- `edid-decode` provides parsing for panel EDID blocks.

---

## 2. Extraction Usage

### Option A: Direct Local Execution (on the D330 tablet)
Boot the target tablet into Linux (e.g. LMDE / Ubuntu live USB or installed system) and run:
```bash
sudo ./scripts/extract_telemetry.sh --local
```

### Option B: Remote Execution via SSH (from development workstation)
If the D330 tablet is booted with SSH enabled on the local network:
```bash
./scripts/extract_telemetry.sh --host <username>@<tablet-ip-address>
```
With custom port or SSH key:
```bash
./scripts/extract_telemetry.sh --host mint@192.168.1.50 -p 22 -i ~/.ssh/id_rsa
```

---

## 3. Telemetry Bundle Structure
Each run creates a timestamped folder `docs/dumps/telemetry_<YYYYMMDD_HHMMSS>/`:

```text
telemetry_<timestamp>/
├── acpi/
│   ├── raw/                 # Raw binary AML tables (/sys/firmware/acpi/tables/)
│   │   ├── DSDT
│   │   ├── SSDT1, SSDT2...
│   │   └── BGRT, FACP, etc.
│   ├── dsl/                 # Decompiled ASL source (*.dsl) via iasl -d
│   ├── acpidump.bin         # Combined binary ACPI dump
│   └── acpidump.txt         # ASCII hex ACPI dump
├── drm/
│   ├── card0-eDP-1/         # Connector modes, status, enabled, raw EDID
│   │   └── edid_decoded.txt # Parsed EDID timing descriptors
│   ├── i915_display_info.txt# Full DRM display pipeline state and CRTC timing
│   ├── i915_panel_pwr_state.txt # Current PPS power sequencer state
│   ├── i915_power_well_info.txt # PG1, PG2, DDI power well states
│   └── i915_opregion.bin    # ACPI OpRegion binary
├── vbt/
│   ├── i915_vbt.bin         # Raw Intel Video BIOS Table extracted from debugfs
│   └── vbt_decoded.txt      # Decoded panel sequences, GPIOs, and DSI blocks
├── sensors/
│   ├── gpio_debugfs.txt     # GPIO pin state and direction from /sys/kernel/debug/gpio
│   └── iio_devices.txt      # BOSC0200 accelerometer axes and mount matrix
├── power/
│   ├── sys_power_state.txt  # Supported ACPI sleep states (s2idle, deep)
│   └── sys_mem_sleep.txt    # Current mem_sleep default
└── logs/
    ├── dmesg_boot.txt       # Kernel boot log with timestamps
    ├── cmdline.txt          # Active kernel command line
    ├── lspci.txt            # Verbose PCI device tree
    └── uname.txt            # Kernel version and architecture
```

---

## 4. Reverse Engineering Checkpoints
When analyzing the dump:
1. **DSDT/SSDT Analysis**:
   - Check `\_SB.PCI0.RP04` for duplicate symbol definitions (`AE_ALREADY_EXISTS`).
   - Identify GPIO controller resources (`\_SB.PCI0.GPI0`) and panel power enable pins (`EN_VDD`, `EN_BL`, `RST_N`).
2. **VBT Analysis**:
   - Examine `vbt_decoded.txt` for:
     * Panel Type (`MIPI-DSI` vs `eDP`).
     * Power Sequencing Delays: `t1_t2` (Power to HPD), `t3` (HPD to Link), `t7_t9` (Link to Backlight), `t11_t12` (Power Cycle delay).
     * Backlight PWM frequency and controller type.
3. **GPIO Pin Map**:
   - Compare `gpio_debugfs.txt` against Windows INF/ACPI pin assignments to verify if the panel reset or power pin is held low during Linux resume.
