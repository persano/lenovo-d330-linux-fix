#!/usr/bin/env python3
"""
tools/compare_pps_timings.py

Differential State Machine & Timing Analyzer for Intel PPS (Panel Power Sequencing)
Compares Windows Driver (igdkmd64.sys) vs Upstream Linux i915 (intel_pps.c)
Target: Lenovo IdeaPad D330-10IGL (Type 82H0, UHD 600 GLK-R, 800x1280 IVO/BOE Panel)

Model parameters:
- t1_t3: Power on to AUX/link training ready (VDD -> signal)
- t4: Signal on to backlight enable
- t5: Backlight disable to signal disable
- t6: Signal disable to power off (VDD low)
- t11_t12: Power cycle delay (Minimum VDD low time before power on allowed)
"""

import sys
from dataclasses import dataclass
from typing import Dict


@dataclass
class PPSTimings:
    source: str
    t1_t3_power_up_ms: int
    t4_backlight_on_ms: int
    t5_backlight_off_ms: int
    t6_power_down_ms: int
    t11_t12_power_cycle_ms: int
    psr_enabled: bool
    fbc_enabled: bool


# Canonical Timings
WINDOWS_WDDM_BASELINE = PPSTimings(
    source="Windows WDDM 2.7 / igdkmd64.sys (Lenovo OEM INF)",
    t1_t3_power_up_ms=50,
    t4_backlight_on_ms=200,
    t5_backlight_off_ms=200,
    t6_power_down_ms=50,
    t11_t12_power_cycle_ms=500,  # CRITICAL: 500 ms minimum TCON power cycle
    psr_enabled=False,           # Disabled in OEM FeatureTestControl
    fbc_enabled=False,
)

LINUX_DEFAULT_I915 = PPSTimings(
    source="Linux Upstream i915 (VBT Default / intel_pps.c)",
    t1_t3_power_up_ms=50,
    t4_backlight_on_ms=200,
    t5_backlight_off_ms=200,
    t6_power_down_ms=50,
    t11_t12_power_cycle_ms=200,  # DEFICIENT: 200 ms violates TCON minimum off time
    psr_enabled=True,            # Enabled by default on GLK (causes pipe lockup)
    fbc_enabled=True,
)

PROPOSED_PATCH_TIMINGS = PPSTimings(
    source="Proposed Kernel Patch / DKMS Quirk (lenovo-d330-fix)",
    t1_t3_power_up_ms=50,
    t4_backlight_on_ms=200,
    t5_backlight_off_ms=200,
    t6_power_down_ms=50,
    t11_t12_power_cycle_ms=600,  # 600 ms safe margin exceeding TCON requirement
    psr_enabled=False,           # Quirky GLK PSR disabled
    fbc_enabled=False,
)


def evaluate_timing_safety(timings: PPSTimings) -> Dict[str, str]:
    verdicts = {}
    # Check t11_t12
    if timings.t11_t12_power_cycle_ms < 500:
        verdicts["t11_t12"] = (
            f"CRITICAL VIOLATION: {timings.t11_t12_power_cycle_ms}ms < 500ms. "
            "TCON residual charge causes latch-up failure on resume."
        )
    else:
        verdicts["t11_t12"] = (
            f"SAFE: {timings.t11_t12_power_cycle_ms}ms >= 500ms. "
            "Sufficient discharge period for internal timing controller."
        )

    # Check PSR
    if timings.psr_enabled:
        verdicts["psr"] = (
            "RISK: PSR enabled on Gemini Lake Refresh with portrait panel. "
            "Known hardware pipe lockup upon DC6/S0ix resume."
        )
    else:
        verdicts["psr"] = "SAFE: PSR disabled."

    return verdicts


def print_comparison():
    print("=" * 80)
    print(" PPS (Panel Power Sequencing) Timing Differential Matrix: Lenovo D330-10IGL")
    print("=" * 80)

    models = [WINDOWS_WDDM_BASELINE, LINUX_DEFAULT_I915, PROPOSED_PATCH_TIMINGS]

    header_fmt = "{:<45} | {:<10} | {:<10} | {:<10} | {:<10}"
    print(header_fmt.format("Configuration Profile", "t1_t3 (ms)", "t4 (ms)", "t11_t12 (ms)", "PSR"))
    print("-" * 80)

    for m in models:
        psr_str = "ON" if m.psr_enabled else "OFF"
        print(
            header_fmt.format(
                m.source[:45],
                m.t1_t3_power_up_ms,
                m.t4_backlight_on_ms,
                m.t11_t12_power_cycle_ms,
                psr_str,
            )
        )

    print("\n" + "=" * 80)
    print(" Behavioral Evaluation & Failure Mode Analysis")
    print("=" * 80)

    for m in models:
        print(f"\n[*] Profile: {m.source}")
        v = evaluate_timing_safety(m)
        for k, text in v.items():
            print(f"    - [{k}]: {text}")


if __name__ == "__main__":
    print_comparison()
