#!/usr/bin/env bash
# ==============================================================================
# scripts/build_rnnoise_ladspa.sh
#
# Build and install librnnoise_ladspa.so so the D330 PipeWire RNNoise mic filter
# (patches/audio_dsp/etc/pipewire/pipewire.conf.d/51-lenovo-d330-rnnoise-mic.conf)
# works on hosts where no distro package ships the LADSPA plugin.
#
# Source: werman/noise-suppression-for-voice (GPL-3.0), the canonical provider of
# librnnoise_ladspa.so. It vendors xiph/rnnoise under external/rnnoise, so the
# pinned source tarball is self-contained (no git submodules, no build-time net
# beyond this one download). Download is checked against a pinned SHA-256.
#
# Everything installs under /usr/lib/ladspa (the repo's LADSPA search path).
# ==============================================================================

set -euo pipefail

RNNOISE_VERSION="1.21"
RNNOISE_TARBALL="v${RNNOISE_VERSION}.tar.gz"
RNNOISE_URL="https://github.com/werman/noise-suppression-for-voice/archive/refs/tags/${RNNOISE_TARBALL}"
RNNOISE_SHA256="7c5bb24fa6acbc98a4847b79f5a17a5eb80f81ae30d7e39b039e362d3692d6a3"
RNNOISE_SO="librnnoise_ladspa.so"

LADSPA_DIR="/usr/lib/ladspa"
WORK_DIR=""
ACTION="install"
DRY_RUN=false

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Build and install ${RNNOISE_SO} (RNNoise LADSPA denoiser) from a pinned source
release of werman/noise-suppression-for-voice v${RNNOISE_VERSION}.

Options:
  --install           Download, build and install the plugin (default).
  --uninstall         Remove ${LADSPA_DIR}/${RNNOISE_SO}.
  --dry-run           Check prerequisites and print the plan; change nothing.
  --ladspa-dir DIR    Install directory (default: ${LADSPA_DIR}).
  --work-dir DIR      Build scratch directory (default: a fresh mktemp dir,
                      removed on exit).
  -h, --help          Show this help message.

Requires: cmake, gcc, g++, make, tar, sha256sum, and curl or wget.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install)       ACTION="install" ;;
        --uninstall)     ACTION="uninstall" ;;
        --dry-run)       DRY_RUN=true ;;
        --ladspa-dir)    shift; LADSPA_DIR="${1:?--ladspa-dir needs a value}" ;;
        --work-dir)      shift; WORK_DIR="${1:?--work-dir needs a value}" ;;
        -h|--help)       usage; exit 0 ;;
        *) log_err "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

if [[ "$ACTION" == "uninstall" ]]; then
    if [ -e "${LADSPA_DIR}/${RNNOISE_SO}" ]; then
        rm -f "${LADSPA_DIR}/${RNNOISE_SO}"
        log_ok "Removed ${LADSPA_DIR}/${RNNOISE_SO}."
    else
        log_info "Nothing to remove: ${LADSPA_DIR}/${RNNOISE_SO} absent."
    fi
    exit 0
fi

# --- prerequisite tools -------------------------------------------------------
missing=()
for tool in cmake make tar sha256sum; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
done
for compiler in gcc g++; do
    command -v "$compiler" >/dev/null 2>&1 || missing+=("$compiler")
done
downloader=""
if command -v curl >/dev/null 2>&1; then
    downloader="curl"
elif command -v wget >/dev/null 2>&1; then
    downloader="wget"
else
    missing+=("curl-or-wget")
fi

if [ "${#missing[@]}" -gt 0 ]; then
    log_err "Missing build tools: ${missing[*]}"
    log_err "Debian/Ubuntu: sudo apt install cmake build-essential curl"
    log_err "Fedora: sudo dnf install cmake gcc gcc-c++ make tar curl"
    log_err "Arch: sudo pacman -S --needed cmake base-devel curl"
    exit 1
fi

# --- dry run ------------------------------------------------------------------
if [ "$DRY_RUN" = true ]; then
    log_info "[DRY-RUN] Tools present (cmake, gcc, g++, make, tar, sha256sum, ${downloader})."
    log_info "[DRY-RUN] Would download: ${RNNOISE_URL}"
    log_info "[DRY-RUN] Would verify SHA-256: ${RNNOISE_SHA256}"
    log_info "[DRY-RUN] Would build LADSPA plugin only and install ${LADSPA_DIR}/${RNNOISE_SO}."
    exit 0
fi

# --- install-dir writability --------------------------------------------------
if [ ! -d "$LADSPA_DIR" ]; then
    if ! mkdir -p "$LADSPA_DIR" 2>/dev/null; then
        log_err "Cannot create ${LADSPA_DIR}; re-run with sudo or pass --ladspa-dir."
        exit 1
    fi
fi
if [ ! -w "$LADSPA_DIR" ]; then
    log_err "${LADSPA_DIR} is not writable; re-run with sudo or pass --ladspa-dir."
    exit 1
fi

# --- scratch dir --------------------------------------------------------------
cleanup_work=false
if [ -z "$WORK_DIR" ]; then
    WORK_DIR="$(mktemp -d)"
    cleanup_work=true
fi
cleanup() { [ "$cleanup_work" = true ] && rm -rf "$WORK_DIR"; }
trap cleanup EXIT
mkdir -p "$WORK_DIR"

# --- download + verify --------------------------------------------------------
log_info "Downloading ${RNNOISE_URL}..."
if [ "$downloader" = "curl" ]; then
    curl -fsSL -o "${WORK_DIR}/${RNNOISE_TARBALL}" "$RNNOISE_URL"
else
    wget -q -O "${WORK_DIR}/${RNNOISE_TARBALL}" "$RNNOISE_URL"
fi

log_info "Verifying SHA-256..."
if ! echo "${RNNOISE_SHA256}  ${WORK_DIR}/${RNNOISE_TARBALL}" | sha256sum -c -; then
    log_err "SHA-256 mismatch for ${RNNOISE_TARBALL}; aborting."
    exit 1
fi
log_ok "Checksum verified."

# --- build --------------------------------------------------------------------
log_info "Extracting..."
mkdir -p "${WORK_DIR}/src"
tar -xzf "${WORK_DIR}/${RNNOISE_TARBALL}" -C "${WORK_DIR}/src"
SRC="${WORK_DIR}/src/noise-suppression-for-voice-${RNNOISE_VERSION}"
[ -d "$SRC" ] || { log_err "Expected source dir not found: $SRC"; exit 1; }

jobs="$( { command -v nproc >/dev/null 2>&1 && nproc; } || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)"

log_info "Configuring (LADSPA plugin only)..."
cmake -S "$SRC" -B "${WORK_DIR}/build" >/dev/null \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_LADSPA_PLUGIN=ON \
    -DBUILD_VST_PLUGIN=OFF -DBUILD_VST3_PLUGIN=OFF -DBUILD_LV2_PLUGIN=OFF \
    -DBUILD_AU_PLUGIN=OFF -DBUILD_AUV3_PLUGIN=OFF -DBUILD_TESTS=OFF \
    -DCMAKE_INSTALL_PREFIX="${WORK_DIR}/install"

log_info "Building with ${jobs} job(s)..."
cmake --build "${WORK_DIR}/build" -j"${jobs}" >/dev/null

log_info "Staging install..."
cmake --install "${WORK_DIR}/build" >/dev/null
built="${WORK_DIR}/install/lib/ladspa/${RNNOISE_SO}"
[ -f "$built" ] || { log_err "Build did not produce ${RNNOISE_SO}"; exit 1; }

log_info "Installing to ${LADSPA_DIR}..."
install -m 644 "$built" "${LADSPA_DIR}/${RNNOISE_SO}"

echo "================================================================================"
log_ok "Installed ${LADSPA_DIR}/${RNNOISE_SO}."
log_info "Restart PipeWire to load the denoiser graph: systemctl --user restart pipewire pipewire-pulse"
log_info "Then verify with: scripts/test_mic_rnnoise.sh --probe"
echo "================================================================================"
