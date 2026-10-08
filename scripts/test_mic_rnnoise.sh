#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL RNNoise Microphone Suppression Verification Script
# Verifies the PipeWire filter-chain graph structure and the LADSPA noise suppressor plugin

set -euo pipefail

MODE="probe"

# LADSPA search path. Colon-separated directories; globs are allowed (e.g.
# /usr/lib/*/ladspa). Overridable so the test harness can point at a fixture dir
# without hardware (the D330_LADSPA_DIRS seam, Phase 38 SC2).
D330_LADSPA_DIRS="${D330_LADSPA_DIRS:-/usr/lib/ladspa:/usr/lib/*/ladspa}"
RNNOISE_SO="librnnoise_ladspa.so"

show_help() {
    cat << 'EOF'
Usage: scripts/test_mic_rnnoise.sh [OPTIONS]

Options:
  --probe          Inspect the RNNoise LADSPA plugin and active audio sources (default).
                   Exits non-zero when librnnoise_ladspa.so is absent.
  --dry-run        Validate the RNNoise filter-chain graph structure (non-zero on violation)
  --help           Show this help message

Environment:
  D330_LADSPA_DIRS  Colon-separated dirs searched for librnnoise_ladspa.so
                    (default: /usr/lib/ladspa:/usr/lib/*/ladspa)
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --probe)
            MODE="probe"
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
echo " Lenovo D330-10IGL RNNoise Mic Suppression Test Tool      "
echo "=========================================================="

# Search D330_LADSPA_DIRS for librnnoise_ladspa.so. Prints the resolved path and
# returns 0 on the first hit, returns 1 when the plugin is absent everywhere.
find_rnnoise_plugin() {
    local dirs="$1" d cand
    local IFS=':'
    for d in $dirs; do
        # shellcheck disable=SC2086  # $d may intentionally hold a glob
        for cand in $d/$RNNOISE_SO; do
            if [ -f "$cand" ]; then
                printf '%s\n' "$cand"
                return 0
            fi
        done
    done
    return 1
}

# ------------------------------------------------------------------------------
# Static structural validation of the RNNoise graph (Phase 38, audit M7).
# ------------------------------------------------------------------------------
validate_rnnoise_structure() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
    cd "$REPO_ROOT"

    local rnnoise_conf="patches/audio_dsp/etc/pipewire/pipewire.conf.d/51-lenovo-d330-rnnoise-mic.conf"
    local legacy_conf="patches/audio_dsp/etc/pipewire/filter-chain.conf.d/51-lenovo-d330-rnnoise-mic.conf"
    local pass=0 fail=0

    ck() {
        local desc="$1"; shift
        if "$@" >/dev/null 2>&1; then
            echo "  [PASS] $desc"; pass=$((pass + 1))
        else
            echo "  [FAIL] $desc"; fail=$((fail + 1))
        fi
    }
    ckn() {
        local desc="$1"; shift
        if "$@" >/dev/null 2>&1; then
            echo "  [FAIL] $desc (unexpected match)"; fail=$((fail + 1))
        else
            echo "  [PASS] $desc"; pass=$((pass + 1))
        fi
    }

    echo "[DRY-RUN] Validating RNNoise filter-chain graph under pipewire.conf.d..."
    ck  "rnnoise conf present under pipewire.conf.d"          test -f "$rnnoise_conf"
    ck  "uses ladspa plugin librnnoise_ladspa"                grep -q 'librnnoise_ladspa' "$rnnoise_conf"
    ck  "uses ladspa label noise_suppressor_mono"             grep -q 'noise_suppressor_mono' "$rnnoise_conf"
    ck  "exposes source node rnnoise_source_d330"             grep -q 'rnnoise_source_d330' "$rnnoise_conf"
    ck  "documents librnnoise-ladspa package dependency"      grep -q 'librnnoise-ladspa' "$rnnoise_conf"
    ckn "omits version-dependent VAD grace control"           grep -q 'Retroactive VAD Grace' "$rnnoise_conf"
    ck  "legacy filter-chain.conf.d copy removed"             test ! -e "$legacy_conf"

    echo ""
    echo "=========================================================="
    echo " RNNoise structure: passed=$pass failed=$fail"
    echo "=========================================================="
    if [ "$fail" -gt 0 ]; then
        echo "[FAIL] RNNoise graph validation failed." >&2
        return 1
    fi
    echo "[DRY-RUN] RNNoise graph validated successfully."
    return 0
}

if [[ "$MODE" == "dry-run" ]]; then
    validate_rnnoise_structure
    exit 0
fi

echo "--- 1. Checking librnnoise_ladspa Plugin ---"
plugin_path=""
if plugin_path="$(find_rnnoise_plugin "$D330_LADSPA_DIRS")"; then
    echo "  [OK] Found plugin: $plugin_path"
else
    echo "  [FAIL] librnnoise_ladspa.so not found in: $D330_LADSPA_DIRS" >&2
    echo "         Install it via: apt install librnnoise-ladspa" >&2
    exit 1
fi

echo ""
echo "--- 2. Active Audio Sources in PipeWire ---"
if command -v pw-cli >/dev/null 2>&1; then
    pw-cli list-objects Node | grep -E "(media.class.*Audio/Source|node.description)" || true
else
    echo "[INFO] pw-cli command not available."
fi

echo "=========================================================="
echo " RNNoise test complete.                                   "
echo "=========================================================="
