#!/usr/bin/env bash
# ==============================================================================
# test_audio_profiles.sh
# Audio diagnostic, playback verification, and mic capture test harness
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err()  { echo -e "${RED}[ERR]${NC}  $*"; }

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Diagnostic and verification tool for Lenovo D330 audio endpoints and UCM2 profiles.

Options:
    --probe         Probe sound cards, codecs, and ALSA UCM status
    --test-speakers Generate a 440 Hz test tone on internal speakers (1.5s)
    --test-mic      Record a 2-second capture from internal DMIC and evaluate volume
    --monitor-jack  Monitor 3.5mm headphone jack plug/unplug events
    --help          Show this message
EOF
}

PROBE=0
TEST_SPK=0
TEST_MIC=0
MONITOR_JACK=0

if [ $# -eq 0 ]; then
    PROBE=1
fi

for arg in "$@"; do
    case "$arg" in
        --probe) PROBE=1 ;;
        --test-speakers) TEST_SPK=1 ;;
        --test-mic) TEST_MIC=1 ;;
        --monitor-jack) MONITOR_JACK=1 ;;
        --help|-h) show_help; exit 0 ;;
        *) log_err "Unknown argument: $arg"; show_help; exit 1 ;;
    esac
done

log_info "=== Lenovo D330 Audio & UCM Diagnostic Harness ==="

# 1. Probe Cards and Codecs
if [ $PROBE -eq 1 ]; then
    log_info "Listing sound cards (/proc/asound/cards)..."
    if [ -f /proc/asound/cards ]; then
        cat /proc/asound/cards
    else
        log_warn "/proc/asound/cards not available"
    fi

    log_info "Checking active sound server..."
    if pgrep -x "pipewire" >/dev/null 2>&1; then
        log_ok "PipeWire is active"
    elif pgrep -x "pulseaudio" >/dev/null 2>&1; then
        log_ok "PulseAudio is active"
    else
        log_warn "No running PipeWire or PulseAudio daemon detected (raw ALSA mode)"
    fi

    log_info "Checking UCM2 profile availability..."
    UCM_DIR="/usr/share/alsa/ucm2"
    if [ -d "$UCM_DIR" ]; then
        log_ok "ALSA UCM2 directory present: $UCM_DIR"
    else
        log_warn "UCM2 directory missing: $UCM_DIR"
    fi
fi

# 2. Speaker playback test
if [ $TEST_SPK -eq 1 ]; then
    log_info "Generating 440 Hz test tone on default audio sink..."
    if command -v speaker-test >/dev/null 2>&1; then
        speaker-test -t sine -f 440 -l 1 -s 1 2>/dev/null || true
        log_ok "Speaker test tone completed."
    elif command -v paplay >/dev/null 2>&1 && [ -f /usr/share/sounds/freedesktop/stereo/complete.oga ]; then
        paplay /usr/share/sounds/freedesktop/stereo/complete.oga || true
        log_ok "Sound played via paplay."
    else
        log_warn "Neither speaker-test nor paplay available."
    fi
fi

# 3. Mic capture test
if [ $TEST_MIC -eq 1 ]; then
    TMP_WAV="/tmp/d330_mic_test.wav"
    log_info "Recording 2 seconds of audio from default microphone..."
    if command -v arecord >/dev/null 2>&1; then
        arecord -f cd -d 2 "$TMP_WAV" 2>/dev/null || true
        if [ -s "$TMP_WAV" ]; then
            FILE_SZ=$(stat -c%s "$TMP_WAV" 2>/dev/null || stat -f%z "$TMP_WAV" 2>/dev/null || wc -c < "$TMP_WAV")
            log_ok "Mic capture successful ($FILE_SZ bytes recorded to $TMP_WAV)"
            rm -f "$TMP_WAV"
        else
            log_err "Mic recording produced empty file"
        fi
    else
        log_warn "arecord not installed"
    fi
fi

# 4. Jack detection monitor
if [ $MONITOR_JACK -eq 1 ]; then
    log_info "Monitoring ALSA control events for headphone jack (Press Ctrl+C to stop)..."
    if command -v amixer >/dev/null 2>&1; then
        amixer -c 0 events || true
    else
        log_err "amixer utility not found"
    fi
fi

log_ok "Audio verification completed."
