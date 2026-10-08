#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL MicroSD & Cellular LTE Verification Script
# Verifies secondary MicroSD block device and Intel XMM 7360 LTE modem

set -euo pipefail

# CWD anchoring: resolve the repo root from this script's own location so the
# tools/ and patches/ references below work from any working directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

MODE="probe"

show_help() {
    cat << 'EOF'
Usage: scripts/test_storage_cellular.sh [OPTIONS]

Options:
  --probe          Inspect MicroSD card slot and LTE modem state (default)
  --test-microsd   Alias for --probe (read-only MicroSD probe, kept for compatibility)
  --dry-run        Validate scripts and configs without modifying hardware
  --help           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --probe)
            MODE="probe"
            shift
            ;;
        --test-microsd)
            MODE="test-microsd"
            shift
            ;;
        --dry-run)
            MODE="dry-run"
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

echo "=========================================================="
echo " Lenovo D330-10IGL MicroSD & LTE Cellular Test Tool       "
echo "=========================================================="

if [[ "$MODE" == "dry-run" ]]; then
    echo "[DRY-RUN] Verifying MicroSD tool and Cellular configurations..."
    # New lines anchor via SCRIPT_DIR/REPO_ROOT (test_resume_loop.sh pattern);
    # existing cwd-relative lines elsewhere are left alone (Phase 41 owns that).
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
    cd "$REPO_ROOT"

    for f in tools/d330-microsd-setup.sh scripts/test_microsd_guards.sh scripts/test_hibernate_guards.sh scripts/test_display_fix_guards.sh scripts/test_installer_symmetry.sh scripts/test_noop_guards.sh scripts/test_audio_dsp.sh scripts/test_mic_rnnoise.sh scripts/test_udev_hwdb_match.sh scripts/test_power_stack.sh scripts/test_wireless_coex.sh scripts/test_storage_cellular.sh; do
        if bash -n "$f"; then
            echo "[OK] bash -n $f"
        else
            echo "[FAIL] bash -n $f" >&2
            exit 1
        fi
    done

    # Guard suite: its non-zero exit propagates under set -e, so any failing
    # case fails this mode; its passed=N failed=M summary flows into this output.
    bash scripts/test_microsd_guards.sh

    # Display-resume guard suite (Phase 34, 10 static cases): same contract as
    # the microsd suite above - its non-zero exit propagates under set -e, so
    # any failing case fails this mode; its passed=N failed=M summary flows
    # into this output.
    bash scripts/test_display_fix_guards.sh

    # Hibernate guard suite: same contract as the microsd suite above - its
    # non-zero exit propagates under set -e, so any failing case fails this
    # mode; its passed=N failed=M summary flows into this output.
    bash scripts/test_hibernate_guards.sh

    # Installer symmetry guard suite (Phase 35, 16 cases): same contract as the
    # suites above - its non-zero exit propagates under set -e, so any failing
    # case fails this mode; its passed=N failed=M summary flows into this output.
    bash scripts/test_installer_symmetry.sh

    # No-op / honesty guard suite (Phase 37): asserts no shipped tool reports
    # success for work it did not do (PWM service gone, --apply false-success
    # and sensor-filter liveness). Same contract as the suites above.
    bash scripts/test_noop_guards.sh

    # Speaker DSP structural validator (Phase 38): validates the speaker graph
    # under pipewire.conf.d non-vacuously. Same contract as the suites above -
    # its non-zero exit propagates under set -e.
    bash scripts/test_audio_dsp.sh --dry-run

    # RNNoise structural validator (Phase 38): validates the mic graph under
    # pipewire.conf.d. Same contract as the suites above.
    bash scripts/test_mic_rnnoise.sh --dry-run

    # RNNoise SC2 (Phase 38): with the LADSPA plugin absent the probe MUST exit
    # non-zero AND emit the missing-plugin diagnostic. Assert both, so a
    # missing/crashing script (any non-zero exit) cannot be counted as SC2-passing.
    sc2_out=""
    if sc2_out="$(D330_LADSPA_DIRS="/nonexistent-empty-ladspa" bash scripts/test_mic_rnnoise.sh --probe 2>&1)"; then
        echo "[FAIL] RNNoise probe passed with librnnoise_ladspa.so absent (SC2)" >&2
        exit 1
    fi
    if ! printf '%s\n' "$sc2_out" | grep -q 'librnnoise_ladspa.so not found'; then
        echo "[FAIL] RNNoise probe exited non-zero without the missing-plugin diagnostic (SC2)" >&2
        printf '%s\n' "$sc2_out" >&2
        exit 1
    fi
    echo "[OK] RNNoise probe fails closed when librnnoise_ladspa.so is absent"

    # udev/hwdb/wireless match-string guard suite (Phase 39): asserts every
    # match string equals a real D330 string and no modprobe option targets an
    # absent module. Same contract as the suites above - its non-zero exit
    # propagates under set -e; its passed=N failed=M summary flows into output.
    bash scripts/test_udev_hwdb_match.sh

    # Power-stack single-writer guard suite (Phase 40): asserts the CPU perf cap
    # is AC-aware, the udev runtime-PM rule is scoped off TLP's turf, no rejected
    # GPU frequency, no nowatchdog, and the thermal numeric guard. Same contract
    # as the suites above - its non-zero exit propagates under set -e; its
    # passed=N failed=M summary flows into this output.
    bash scripts/test_power_stack.sh

    # Wireless modprobe-conf validator (Phase 39, SC3): `--dry-run` parses the
    # conf and exits non-zero on an unknown module name or a missing in-tree
    # `rtw88_8821ce`. Same contract as the suites above.
    bash scripts/test_wireless_coex.sh --dry-run

    # Cellular packaging inventory: resolve the real FCC-unlock hook instead of
    # printing a hardcoded path that does not exist.
    shopt -s nullglob
    fcc_files=(patches/cellular_storage/etc/ModemManager/fcc-unlock.d/*)
    shopt -u nullglob
    if [ "${#fcc_files[@]}" -eq 0 ]; then
        echo "[FAIL] No ModemManager FCC unlock hook under patches/cellular_storage/etc/ModemManager/fcc-unlock.d/" >&2
        exit 1
    fi
    for f in "${fcc_files[@]}"; do
        if [ -s "$f" ]; then
            echo "[OK] ModemManager FCC unlock hook: $f"
        else
            echo "[INFO] ModemManager FCC unlock hook present but empty: $f"
        fi
    done
    echo "[OK] Cellular Rules: patches/cellular_storage/etc/udev/rules.d/78-lenovo-d330-cellular.rules"
    echo "[OK] dry-run verification complete"
    exit 0
fi

case "$MODE" in
    probe)
        echo "--- 1. MicroSD Storage State ---"
        bash "$SCRIPT_DIR/tools/d330-microsd-setup.sh" --probe

        echo ""
        echo "--- 2. LTE Cellular Modem State ---"
        if lspci -d 8086:7360 >/dev/null 2>&1; then
            echo "[OK] Intel XMM 7360 LTE modem detected on PCI bus:"
            lspci -d 8086:7360
            if command -v mmcli >/dev/null 2>&1; then
                mmcli -L || true
            fi
        else
            echo "[INFO] No PCI 8086:7360 LTE modem found (Wi-Fi only SKU or disabled in BIOS)."
        fi
        ;;
    test-microsd)
        # Honest alias: --test-microsd performs the same read-only MicroSD probe
        # as --probe; it is retained for backwards compatibility (documented in
        # --help) rather than pretending to be a distinct test.
        echo "--- MicroSD Probe (--test-microsd alias of --probe) ---"
        bash "$SCRIPT_DIR/tools/d330-microsd-setup.sh" --probe
        ;;
esac

echo "=========================================================="
echo " Test completed.                                          "
echo "=========================================================="
