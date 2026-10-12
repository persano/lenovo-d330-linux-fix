#!/usr/bin/env bash
# ==============================================================================
# scripts/prepare_safety_kit.sh
#
# Off-device safety-kit staging utility (Phase 43, GUARD-03).
#
# Deliberately NOT named test_*: this is a mutating repo-side utility (it only
# writes inside the kit dir), so the harness --apply meta-guard does not apply.
# It never touches the running system.
#
# Modes:
#   --register FILE   Add/update FILE's sha256 line in the kit MANIFEST.sha256
#                     (idempotent: an existing line for the same kit-relative
#                     path is replaced, never duplicated). FILE must resolve to
#                     a path inside the kit dir (give a kit-relative name or a
#                     path under --kit-dir).
#   --verify          Run sha256sum -c on MANIFEST.sha256 from inside the kit
#                     dir; exits non-zero on any mismatch.
#   --dry-run         Validate kit-side prerequisites (sha256sum present, kit
#                     dir writable, build_live_iso.sh present), then run
#                     scripts/build_live_iso.sh --dry-run and report its result
#                     informationally (ISO toolchain presence is validated at
#                     runbook time on the build machine and does not fail the
#                     kit dry-run).
#   --kit-dir DIR     Kit directory (default: docs/dumps/safety_kit).
#   --help            Usage.
#
# Kit artifacts are gitignored; MANIFEST.sha256 stays committable (see
# docs/research/RESUME_CAPTURE_PROTOCOL.md kit-staging section).
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

KIT_DIR="docs/dumps/safety_kit"
REG_FILES=()
MODE=""

log_info() { echo "[INFO] $*"; }
log_ok()   { echo "[OK] $*"; }
log_warn() { echo "[WARN] $*"; }
log_err()  { echo "[ERROR] $*" >&2; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Stage and verify the off-device D330 safety kit (golden module, live ISO,
VBT/GOP dumps, checksummed source tree) under one MANIFEST.sha256.

Options:
  --kit-dir DIR    Kit directory (default: docs/dumps/safety_kit)
  --register FILE  Register/refresh FILE's checksum line in MANIFEST.sha256
                   (repeatable; FILE must live inside the kit dir)
  --verify         Verify every artifact against MANIFEST.sha256 (sha256sum -c)
  --dry-run        Validate kit-side prerequisites; reports the ISO toolchain
                   dry-run result informationally without failing kit checks
  --help           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --kit-dir)
            [ $# -ge 2 ] || { log_err "--kit-dir requires a value"; exit 1; }
            KIT_DIR="$2"; shift 2 ;;
        --register)
            [ $# -ge 2 ] || { log_err "--register requires a file argument"; exit 1; }
            MODE="register"
            REG_FILES+=("$2"); shift 2 ;;
        --verify)
            MODE="verify"; shift ;;
        --dry-run)
            MODE="dry-run"; shift ;;
        -h|--help)
            usage; exit 0 ;;
        *)
            log_err "Unknown option: $1"; usage; exit 1 ;;
    esac
done

[ -n "$MODE" ] || { usage; exit 0; }

manifest_path() {
    printf '%s\n' "${KIT_DIR%/}/MANIFEST.sha256"
}

# Replace the manifest line for the same kit-relative path (regex-free suffix
# match: "<hash>  <rel>"), then append. Idempotent re-register.
register_one() {
    local f="$1" abs="" rel=""
    mkdir -p "$KIT_DIR"
    if [ -f "$f" ]; then
        abs="$f"
    elif [ -f "${KIT_DIR%/}/$f" ]; then
        abs="${KIT_DIR%/}/$f"
    fi
    if [ -z "$abs" ]; then
        log_err "register: artifact not found (place it inside the kit dir first): $f"
        exit 1
    fi
    case "$abs" in
        "${KIT_DIR%/}"/*) rel="${abs#"${KIT_DIR%/}/"}" ;;
        *)
            log_err "register: artifact must be inside the kit dir ($KIT_DIR): $abs"
            exit 1 ;;
    esac
    case "$rel" in
        /*|*..*|"")
            log_err "register: refusing unsafe kit-relative path: $rel"
            exit 1 ;;
    esac
    local hash
    hash="$(sha256sum "$abs" | awk '{print $1}')"
    local manifest
    manifest="$(manifest_path)"
    if [ -f "$manifest" ]; then
        local tmp="${manifest}.tmp"
        awk -v rel="$rel" '
            {
                m = length(rel) + 2
                if (length($0) >= m && substr($0, length($0) - m + 1) == "  " rel) next
                print
            }
        ' "$manifest" > "$tmp"
        mv "$tmp" "$manifest"
    fi
    printf '%s  %s\n' "$hash" "$rel" >> "$manifest"
    log_ok "registered $rel ($hash) into $manifest"
}

do_register() {
    local f
    for f in "${REG_FILES[@]}"; do
        register_one "$f"
    done
}

do_verify() {
    local manifest
    manifest="$(manifest_path)"
    if [ ! -f "$manifest" ]; then
        log_err "verify: manifest missing: $manifest (register artifacts first)"
        exit 1
    fi
    if (cd "$KIT_DIR" && sha256sum -c MANIFEST.sha256); then
        log_ok "safety kit verified: all artifacts match $manifest"
    else
        log_err "verify: safety kit FAILED checksum verification against $manifest"
        exit 1
    fi
}

do_dry_run() {
    if ! command -v sha256sum >/dev/null 2>&1; then
        log_err "dry-run: sha256sum not available"
        exit 1
    fi
    log_ok "dry-run: sha256sum present"
    mkdir -p "$KIT_DIR"
    local probe="${KIT_DIR%/}/.write_probe.$$"
    if : > "$probe" 2>/dev/null; then
        rm -f "$probe"
        log_ok "dry-run: kit dir writable: $KIT_DIR"
    else
        log_err "dry-run: kit dir not writable: $KIT_DIR"
        exit 1
    fi
    if [ -f scripts/build_live_iso.sh ]; then
        log_ok "dry-run: scripts/build_live_iso.sh present"
    else
        log_err "dry-run: scripts/build_live_iso.sh missing"
        exit 1
    fi
    local iso_rc=0
    bash scripts/build_live_iso.sh --dry-run || iso_rc=$?
    if [ "$iso_rc" -eq 0 ]; then
        log_ok "dry-run: ISO toolchain dry-run passed (informational)"
    else
        log_warn "dry-run: ISO toolchain dry-run exited $iso_rc; ISO toolchain presence is validated at runbook time on the build machine (kit-side checks unaffected)"
    fi
    log_ok "dry-run: kit-side checks passed"
}

case "$MODE" in
    register) do_register ;;
    verify)   do_verify ;;
    dry-run)  do_dry_run ;;
esac

exit 0
