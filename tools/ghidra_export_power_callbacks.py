# tools/ghidra_export_power_callbacks.py
# Ghidra Headless script to locate and decompile WDDM DDI power callbacks
# in igdkmd64.sys (Intel Graphics Kernel Mode Driver).
#
# Usage:
#   analyzeHeadless <project_dir> <project_name> -import drivers_base/vga_intel/igdkmd64.sys \
#       -postScript tools/ghidra_export_power_callbacks.py \
#       -scriptPath tools/
#
# Target: Lenovo D330-10IGL (Type 82H0 / GLK-R UHD Graphics 600)

import json
import os

try:
    from ghidra.app.decompiler import DecompInterface
    from ghidra.program.model.symbol import SymbolType
    from ghidra.util.task import ConsoleTaskMonitor
    IS_GHIDRA = True
except ImportError:
    IS_GHIDRA = False


def run_ghidra_analysis():
    monitor = ConsoleTaskMonitor()
    decomp = DecompInterface()
    decomp.openProgram(currentProgram)

    results = {
        "program": currentProgram.getName(),
        "image_base": hex(currentProgram.getImageBase().getOffset()),
        "power_callbacks": [],
        "pps_references": []
    }

    target_symbols = [
        "DxgkDdiSetPowerState",
        "DxgkDdiResetDevice",
        "DxgkDdiStartDevice",
        "DxgkDdiStopDevice",
        "DxgkCbAcquirePostDisplayOwnership",
        "DxgkCbCompletePowerTransition"
    ]

    symbol_table = currentProgram.getSymbolTable()
    for sym_name in target_symbols:
        for sym in symbol_table.getSymbols(sym_name):
            func = getFunctionAt(sym.getAddress())
            if func is not None:
                d_res = decomp.decompileFunction(func, 60, monitor)
                c_code = d_res.getDecompiledFunction().getC() if d_res.decompileCompleted() else "DECOMPILE_FAILED"
                results["power_callbacks"].append({
                    "name": sym_name,
                    "address": hex(sym.getAddress().getOffset()),
                    "c_pseudocode": c_code[:2000] # First 2KB
                })

    output_path = os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "docs", "windows_analysis", "ghidra_decompiled_callbacks.json")
    with open(output_path, "w") as f:
        json.dump(results, f, indent=2)

    print("[+] Ghidra power callback extraction complete: %s" % output_path)


if __name__ == "__main__":
    if IS_GHIDRA:
        run_ghidra_analysis()
    else:
        print("[*] ghidra_export_power_callbacks.py: Ghidra environment not active.")
        print("[*] This script is invoked by Ghidra analyzeHeadless runner.")
