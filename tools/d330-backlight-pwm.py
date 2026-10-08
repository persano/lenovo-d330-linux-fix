#!/usr/bin/env python3
"""
Lenovo IdeaPad D330-10IGL Backlight PWM Frequency Scaling Utility
Increases PWM dimming frequency from the OEM default (200 Hz) toward 1000 Hz
to eliminate eye strain, headaches, and visible flicker at low brightness.

Honesty contract: `--apply` only reports success after a real PCH/GMCH PWM
register write that is confirmed by an `intel_reg` read-back delta. Without
`intel_reg` it prints an explicit `[SKIP]` and exits non-zero. It never prints
an unconditional `[OK]` for an operation that performed no write.
"""

import sys
import os
import shutil
import subprocess

TARGET_PWM_HZ = 1000

# PCH/GMCH backlight PWM registers to probe, in order of preference:
# name -> MMIO address (as documented in intel-gpu-tools / i915 regs).
# BLC_PWM_PCH_CTL2 holds the PCH duty/period fields; BXT_BLC_PWM_FREQ1 is the
# Broxton/Gemini-Lake backlight frequency register.
PWM_REGISTERS = (
    ("BLC_PWM_PCH_CTL2", 0xC8254),
    ("BXT_BLC_PWM_FREQ1", 0xC8258),
)

# PCH raw clock reference (Hz) used to derive the divider for TARGET_PWM_HZ.
PCH_RAWCLK_HZ = 24000000


def get_current_backlight_driver():
    path = "/sys/class/backlight"
    if os.path.isdir(path):
        entries = os.listdir(path)
        if entries:
            return entries[0]
    return "intel_backlight"


def check_flicker_status():
    # Read-only inspection; performs no register access.
    driver = get_current_backlight_driver()
    base = f"/sys/class/backlight/{driver}"
    if not os.path.exists(base):
        print(f"[INFO] Backlight interface {base} not found.")
        return

    cur_b = open(f"{base}/brightness").read().strip() if os.path.exists(f"{base}/brightness") else "N/A"
    max_b = open(f"{base}/max_brightness").read().strip() if os.path.exists(f"{base}/max_brightness") else "N/A"
    print(f"Backlight Interface: {driver}")
    print(f"  - Current Brightness: {cur_b} / {max_b}")
    print(f"  - Target PWM Frequency: {TARGET_PWM_HZ} Hz (Anti-Flicker)")


def find_intel_reg():
    """Locate the intel_reg tool; honour an explicit env override."""
    for var in ("D330_INTEL_REG", "INTEL_REG"):
        override = os.environ.get(var)
        if override:
            return override
    return shutil.which("intel_reg")


def read_register(tool, address):
    """Return the integer value at `address`, or None if unreadable."""
    try:
        proc = subprocess.run(
            [tool, "read", f"0x{address:X}"],
            capture_output=True, text=True, timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if proc.returncode != 0:
        return None
    for token in proc.stdout.replace("=", " ").split():
        if token.lower().startswith("0x"):
            try:
                return int(token, 16)
            except ValueError:
                continue
    return None


def write_register(tool, address, value):
    """Return True when intel_reg reports a successful write."""
    try:
        proc = subprocess.run(
            [tool, "write", f"0x{address:X}", f"0x{value:X}"],
            capture_output=True, text=True, timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return False
    return proc.returncode == 0


def apply_pwm_tuning():
    tool = find_intel_reg()
    if not tool:
        # Honest skip: no register was read or written.
        print("[SKIP] intel_reg not available; no PWM register written.")
        sys.exit(2)

    divider = max(1, PCH_RAWCLK_HZ // TARGET_PWM_HZ)

    for name, address in PWM_REGISTERS:
        before = read_register(tool, address)
        if before is None:
            continue  # register not present on this platform; try the next

        # Preserve the upper control bits, replace the low 16-bit divider field.
        target = (before & ~0xFFFF) | (divider & 0xFFFF)
        if not write_register(tool, address, target):
            print(f"[FAIL] PWM register {name} write not confirmed by intel_reg")
            sys.exit(1)

        after = read_register(tool, address)
        if after is None:
            print(f"[FAIL] PWM register {name} read-back failed; cannot verify write")
            sys.exit(1)

        if after != before:
            print(f"[OK] PWM {name}: 0x{before:08X} -> 0x{after:08X}")
            return

        print(f"[FAIL] PWM register unchanged at {name} (0x{before:08X}); divider already {divider}?")
        sys.exit(1)

    print("[FAIL] no known PWM register readable via intel_reg; nothing written")
    sys.exit(1)


def main():
    if len(sys.argv) > 1 and sys.argv[1] in ("--apply", "-a"):
        apply_pwm_tuning()
    else:
        check_flicker_status()


if __name__ == "__main__":
    main()
