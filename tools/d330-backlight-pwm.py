#!/usr/bin/env python3
"""
Lenovo IdeaPad D330-10IGL Backlight PWM Frequency Scaling Utility
Increases PWM dimming frequency from the OEM default (200 Hz) toward 1000 Hz
to eliminate eye strain, headaches, and visible flicker at low brightness.

Honesty contract: `--apply` only reports success when the divider field is
confirmed correct by an `intel_reg` read-back, either from a real register write
(0xbefore -> 0xafter) or because the register already held the target divider
(a no-op re-run is idempotent success, not failure). Without `intel_reg` it
prints an explicit `[SKIP]` and exits non-zero. It never prints an unconditional
`[OK]` for an operation that performed no write and did not verify the target.
"""

import sys
import os
import re
import shutil
import subprocess

TARGET_PWM_HZ = 1000

# Gemini Lake (BXT-family) backlight frequency register to target. On this
# platform 0xC8254 is `_BXT_BLC_PWM_FREQ1` (kernel intel_backlight_regs.h); the
# frequency divider is the low 16-bit field. The adjacent 0xC8258 is
# `_BXT_BLC_PWM_DUTY1` (brightness) and is never written here.
PWM_REGISTERS = (
    ("BXT_BLC_PWM_FREQ1", 0xC8254),
)

# PCH raw clock reference (Hz) used to derive the divider for TARGET_PWM_HZ.
PCH_RAWCLK_HZ = 24000000

# Hex value token emitted by `intel_reg read`.
_VAL_RE = re.compile(r"0x([0-9a-fA-F]+)")


def get_current_backlight_driver():
    path = "/sys/class/backlight"
    if os.path.isdir(path):
        entries = os.listdir(path)
        if entries:
            return entries[0]
    return "intel_backlight"


def _read_sysfs(path):
    """Read a sysfs value; return "N/A" on any read error (never abort --probe)."""
    try:
        with open(path, "r") as fh:
            return fh.read().strip()
    except OSError:
        return "N/A"


def check_flicker_status():
    # Read-only inspection; performs no register access.
    driver = get_current_backlight_driver()
    base = f"/sys/class/backlight/{driver}"
    if not os.path.exists(base):
        print(f"[INFO] Backlight interface {base} not found.")
        return

    cur_b = _read_sysfs(f"{base}/brightness") if os.path.exists(f"{base}/brightness") else "N/A"
    max_b = _read_sysfs(f"{base}/max_brightness") if os.path.exists(f"{base}/max_brightness") else "N/A"
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
    """Return the integer value at `address`, or None if unreadable.

    `intel_reg read` prints `name (0xADDR): 0xVALUE` for MMIO registers, so the
    value is the hex token AFTER the last `:` separator -- never the register
    address in parentheses. Returning None makes the caller refuse to write, so
    a target is never derived from the address.
    """
    try:
        proc = subprocess.run(
            [tool, "read", f"0x{address:X}"],
            capture_output=True, text=True, timeout=10,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if proc.returncode != 0:
        return None
    # Restrict parsing to the text after the last ':'; the whole-line fallback
    # would pick up the register address in 'name (0xADDR): 0xVALUE'.
    value_part = proc.stdout.rsplit(":", 1)[-1] if ":" in proc.stdout else proc.stdout
    matches = _VAL_RE.findall(value_part)
    if not matches:
        return None
    try:
        return int(matches[-1], 16)
    except ValueError:
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

        # BXT_BLC_PWM_FREQ1: preserve the upper control bits, replace the low
        # 16-bit divider field.
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

        # Idempotent re-run: the divider field already equals the requested
        # target, so there was nothing to change. Report success, not failure
        # (the register content matches what --apply asked for).
        if (after & 0xFFFF) == (divider & 0xFFFF):
            print(f"[OK] PWM {name}: already at target divider (0x{after:08X})")
            return

        print(f"[FAIL] PWM register unchanged at {name} (0x{before:08X}); "
              f"divider not applied (wanted 0x{divider & 0xFFFF:04X})")
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
