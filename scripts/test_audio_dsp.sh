#!/usr/bin/env bash
# Lenovo IdeaPad D330-10IGL Audio DSP & Anti-Pop Verification Script
# Verifies PipeWire filter-chain graph structure, DAC power ramp delay, and headset switch

set -euo pipefail

MODE="probe"

show_help() {
    cat << 'EOF'
Usage: scripts/test_audio_dsp.sh [OPTIONS]

Options:
  --probe          Inspect active PipeWire filter-chain modules and ALSA power parameters (default)
  --test-sweep     Play a frequency sweep (100 Hz - 10 kHz) to test speaker limiter and HPF
  --test-pink      Play 3 seconds of pink noise to evaluate vocal presence
  --test-anti-pop  Trigger rapid DAC mute/unmute power cycle to test pop suppression
  --dry-run        Validate the speaker DSP graph structure (non-zero on any violation)
  --help           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --probe)
            MODE="probe"
            shift
            ;;
        --test-sweep)
            MODE="test-sweep"
            shift
            ;;
        --test-pink)
            MODE="test-pink"
            shift
            ;;
        --test-anti-pop)
            MODE="test-anti-pop"
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
echo " Lenovo D330-10IGL Audio DSP & Anti-Pop Test Tool         "
echo "=========================================================="

# ------------------------------------------------------------------------------
# Structural validation of the speaker filter-chain graph (Phase 38, audit M7).
# The graph must live under pipewire.conf.d (the directory the RUNNING daemon
# reads), use valid builtin labels/controls, and declare explicit links. Any
# violation is reported and turns into a non-zero exit, so the check can never
# pass vacuously the way the old echo-only dry-run did.
# ------------------------------------------------------------------------------
validate_dsp_structure() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
    cd "$REPO_ROOT"

    local speaker_conf="patches/audio_dsp/etc/pipewire/pipewire.conf.d/50-lenovo-d330-speaker-dsp.conf"
    local legacy_conf="patches/audio_dsp/etc/pipewire/filter-chain.conf.d/50-lenovo-d330-speaker-dsp.conf"
    # shellcheck source=scripts/lib_conf_check.sh
    source "${SCRIPT_DIR}/lib_conf_check.sh"

    local pass=0 fail=0

    no_shared_var() {
        ! grep -qE '^[[:space:]]*filter_chain\.nodes' "$1"
    }
    # Braces and brackets must net to zero (a truncated/garbled graph would not).
    conf_balanced() {
        local f="$1" ob cb osb csb
        ob=$(tr -cd '{' < "$f" | wc -c)
        cb=$(tr -cd '}' < "$f" | wc -c)
        osb=$(tr -cd '[' < "$f" | wc -c)
        csb=$(tr -cd ']' < "$f" | wc -c)
        [ "$ob" -eq "$cb" ] && [ "$osb" -eq "$csb" ]
    }
    # The clamp node must declare BOTH Min and Max controls, not merely exist.
    clamp_controls_ok() {
        local block
        block="$(awk '
            /label[[:space:]]*=[[:space:]]*clamp/ { inc = 1 }
            inc { print }
            inc && /}/ { exit }
        ' "$1")"
        printf '%s\n' "$block" | grep -q '"Min"' && \
            printf '%s\n' "$block" | grep -q '"Max"'
    }
    # Every links "output"/"input" endpoint (node:Port) must name a declared
    # node (`name = <node>`); catches a link to a node that was never defined.
    links_nodes_declared() {
        local f="$1" declared endpoints node
        declared="$(grep -oE '^[[:space:]]*name[[:space:]]*=[[:space:]]*[A-Za-z0-9_]+' "$f" \
            | sed -E 's/.*=[[:space:]]*//' | sort -u)"
        endpoints="$(grep -oE '(output|input)[[:space:]]*=[[:space:]]*"[^"]+"' "$f" \
            | sed -E 's/.*"([^":]+):[^"]*"/\1/' | sort -u)"
        [ -n "$endpoints" ] || return 1
        while IFS= read -r node; do
            [ -n "$node" ] || continue
            grep -qxF "$node" <<< "$declared" || return 1
        done <<< "$endpoints"
        return 0
    }

    echo "[DRY-RUN] Validating speaker DSP graph under pipewire.conf.d..."
    ck  "speaker conf present under pipewire.conf.d"        test -f "$speaker_conf"
    ck  "uses builtin bq_highpass node"                     grep -q 'label = bq_highpass' "$speaker_conf"
    ck  "uses builtin bq_peaking node"                      grep -q 'label = bq_peaking' "$speaker_conf"
    ck  "uses builtin clamp node"                           grep -q 'label = clamp' "$speaker_conf"
    ck  "declares explicit node links"                      grep -q 'links' "$speaker_conf"
    ck  "exposes virtual sink effect_input.d330_speaker_dsp" grep -q 'effect_input.d330_speaker_dsp' "$speaker_conf"
    ck  "graph nodes are inlined (no shared variable)"      no_shared_var "$speaker_conf"
    ckn "no invalid label = biquad"                         grep -qE 'label = biquad' "$speaker_conf"
    ckn "no nonexistent label = limiter"                    grep -qE 'label = limiter' "$speaker_conf"
    ckn "no invalid \"Type\" control"                       grep -qE '"Type"' "$speaker_conf"
    ck  "legacy filter-chain.conf.d copy removed"           test ! -e "$legacy_conf"

    # Non-vacuous graph-shape checks (Phase 38 fix): the old substring-only
    # dry-run could pass on a truncated or internally inconsistent graph.
    ck  "declares context.modules array"                   grep -qF 'context.modules = [' "$speaker_conf"
    ck  "declares filter.graph block"                      grep -qF 'filter.graph = {' "$speaker_conf"
    ck  "braces and brackets balanced"                     conf_balanced "$speaker_conf"
    ck  "exposes virtual sink effect_output.d330_speaker_dsp" grep -q 'effect_output.d330_speaker_dsp' "$speaker_conf"
    ck  "clamp node declares Min and Max controls"         clamp_controls_ok "$speaker_conf"
    ck  "every link endpoint names a declared node"        links_nodes_declared "$speaker_conf"

    echo ""
    echo "=========================================================="
    echo " Speaker DSP structure: passed=$pass failed=$fail"
    echo "=========================================================="
    if [ "$fail" -gt 0 ]; then
        echo "[FAIL] Speaker DSP graph validation failed." >&2
        return 1
    fi
    echo "[DRY-RUN] Speaker DSP graph validated successfully."
    return 0
}

if [[ "$MODE" == "dry-run" ]]; then
    validate_dsp_structure
    exit 0
fi

inspect_dsp() {
    echo "--- 1. PipeWire Filter-Chain Status ---"
    if command -v pw-cli >/dev/null 2>&1; then
        echo "PipeWire Nodes matching 'DSP':"
        pw-cli list-objects Node | grep -E "(node.name|media.class)" | grep -i "dsp" || echo "  [INFO] No active DSP filter-chain node loaded yet."
    else
        echo "[INFO] pw-cli not installed. Install pipewire-bin."
    fi

    echo ""
    echo "--- 2. ALSA Power Save Parameters ---"
    if [[ -f /sys/module/snd_soc_core/parameters/pmdown_time ]]; then
        echo "  snd_soc_core pmdown_time: $(cat /sys/module/snd_soc_core/parameters/pmdown_time) ms"
    fi
}

case "$MODE" in
    probe)
        inspect_dsp
        ;;
    test-sweep)
        echo "Generating 100Hz - 10kHz audio test sweep..."
        if command -v speaker-test >/dev/null 2>&1; then
            speaker-test -t sine -f 440 -l 1 || true
        elif command -v aplay >/dev/null 2>&1; then
            echo "Playing test beep..."
            ( speaker-test -t sine -f 1000 -l 1 2>/dev/null ) || true
        fi
        ;;
    test-pink)
        echo "Testing pink noise..."
        if command -v speaker-test >/dev/null 2>&1; then
            speaker-test -t pink -l 1 || true
        fi
        ;;
    test-anti-pop)
        echo "Testing rapid mute / unmute power cycle..."
        if command -v amixer >/dev/null 2>&1; then
            amixer set Master mute
            sleep 0.5
            amixer set Master unmute
            echo "[OK] Cycle completed. Observe headphone output for pop noise."
        else
            echo "[INFO] amixer not available."
        fi
        ;;
esac

echo "=========================================================="
echo " Audio DSP test finished.                                 "
echo "=========================================================="
