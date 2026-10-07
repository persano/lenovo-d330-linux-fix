# Research: Lenovo VPC2004 ACPI Platform Controls on D330-10IGL

## 1. ACPI Device `VPC2004` & `ideapad_laptop`
Lenovo consumer laptops and 2-in-1 detachables implement OEM hardware controls inside the ACPI namespace under device `\_SB.VPC2004` (Vendor Product Code 2004).

In the Linux kernel, this is serviced by the platform driver `ideapad_laptop` (`drivers/platform/x86/ideapad-laptop.c`).

## 2. Key Capabilities
1. **Battery Conservation Mode (`conservation_mode`)**:
   - Limits battery state of charge (SoC) to approximately 55% - 60%.
   - Reduces lithium polymer electrolyte degradation when the tablet is continuously docked or on AC power.
   - Value `1`: Enabled (stops charging at 60%). Value `0`: Disabled (charges to 100%).
2. **Function Lock (`fn_lock`)**:
   - Inverts behavior of top-row keys (F1-F12 vs volume/brightness/airplane hotkeys).
   - Value `1`: F1-F12 active by default. Value `0`: Special media actions active by default.
3. **CLI Management (`tools/d330-ctl`)**:
   - Unified command line utility supporting status display, toggling, and state persistence to `/etc/d330-hardware-state.json`.
