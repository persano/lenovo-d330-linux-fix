#!/bin/sh
# ==============================================================================
# scripts/deploy_d330_kernel.sh
#
# Host-side deploy of a CI-built kernel .deb to the D330 (santiago-D330) with an
# unbreakable rollback guard (plan 48-02, task 1; FIX-02).
#
# Deploy discipline enforced here:
#   1. The NEW deb is sha256-verified on the host BEFORE anything touches ssh.
#   2. The ROLLBACK deb is verified on the device (exists + sha matches the
#      recorded constant) BEFORE any dpkg -i. Missing/mismatch = hard fail.
#   3. The uploaded copy is re-verified on the device (scp corruption guard)
#      BEFORE dpkg -i.
#   4. Only then: dpkg -i (scripted sudo, password via stdin), reboot, wait for
#      ssh to return, and print the rollback command as a reminder.
#
# The rollback asset is NEVER removed, moved, or overwritten by this script.
# There is no `rm` anywhere in this file.
#
# Credential handling (threat model: no credential leakage in logs/files):
#   The device sudo password is NEVER stored in this file and NEVER echoed to
#   output. It is read at runtime from (in order):
#     - env var D330_SUDO_PW            (recommended for scripted/CI-adjacent runs)
#     - hidden interactive prompt       (terminal echo disabled via stty)
#     - one stdin line                  (when stdin is not a tty)
#   It is only ever piped into `ssh ... "sudo -S -p '' ..."` stdin, so it never
#   appears on a command line, in a log, or in a file.
#
# Usage:
#   deploy_d330_kernel.sh <local-deb> <expected-sha256>
#
#   <local-deb>         path to the CI-built kernel image .deb
#   <expected-sha256>   64 hex chars; the sha256 announced by CI (gh run/artifact)
#
# Environment:
#   DRY_RUN=1                skip ALL ssh/scp (no device side effects); still
#                            exercises every local sha check. The rollback
#                            check is simulated from D330_FAKE_ROLLBACK_SHA:
#                              unset        -> simulate the recorded constant
#                                              (the pass path)
#                              MISSING      -> simulate the asset missing
#                              <64-hex>     -> simulate that remote-computed sha
#                            Test-only; ignored completely in real mode.
#   D330_SUDO_PW             device sudo password (see credential handling)
#
# Rollback constant provenance: captured live from the device via
# `ssh santiago-D330 sha256sum` on 2026-10-14, cross-checked against the repo
# record (docs/research/RESUME_VS_RELOAD_DIFFERENTIAL.md:155,
# 47-03-SUMMARY.md).
# ==============================================================================

set -eu

# Device alias/endpoint override: when the invoking shell cannot resolve the
# mDNS alias (WSL interop), pass D330_DEVICE="santiago@<ip>" plus
# D330_SSH_OPTS with the identity/known-hosts flags the alias normally
# supplies. Empty default keeps the documented alias.
DEVICE="${D330_DEVICE:-santiago-D330}"
SSH_OPTS="${D330_SSH_OPTS:-}"
# Rollback asset: the proven-bootable previous kernel deb on the device. The
# original constant (linux-image-7.0.14-d330-fix, sha 20dc04db…9e91) was
# CLOBBERED on 2026-10-15 by this script's own upload (name collision: the
# uploaded deb had the same basename as the rollback asset). The asset was
# re-established as d47_dump_kernel.deb (the 47-era dump kernel, sha
# ba47df8d…87be, verified on device). Future deploys upload to a distinct
# incoming name so the rollback asset is never overwritten again.
# Override per deploy with D330_ROLLBACK_DEB / D330_ROLLBACK_SHA (e.g. the
# previous iteration's deb, which this script now preserves under its
# incoming name).
ROLLBACK_DEB="${D330_ROLLBACK_DEB:-/home/santiago/d47_dump_kernel.deb}"
ROLLBACK_SHA="${D330_ROLLBACK_SHA:-ba47df8dd595c87649ce2a91a9e087e9cd90c20e166eee44f302dd1876fe87be}"

log_info() { echo "[INFO] $*"; }
log_ok()   { echo "[OK] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_err()  { echo "[ERROR] $*" >&2; }

usage() {
    cat <<EOF
Usage: $(basename "$0") <local-deb> <expected-sha256>

Deploy a CI-built kernel .deb to the D330 behind a verified rollback guard:
local sha verify -> on-device rollback verify -> scp -> on-device sha verify
-> dpkg -i (scripted sudo, password via stdin) -> reboot -> wait for ssh.

  local-deb         path to the CI-built kernel image .deb
  expected-sha256   64 hex chars announced by CI

Env: DRY_RUN=1 (no ssh/scp; simulate the rollback check from
D330_FAKE_ROLLBACK_SHA: unset=recorded constant, MISSING=asset missing,
<64-hex>=that sha), D330_SUDO_PW (device sudo password; prompted if unset).

The script never deletes the rollback deb:
$ROLLBACK_DEB (sha256 ${ROLLBACK_SHA}).
EOF
}

fail() {
    log_err "$@"
    exit 1
}

# is_sha <string>: true when it is exactly 64 lowercase hex chars.
is_sha() {
    printf '%s' "$1" | grep -Eq '^[0-9a-f]{64}$'
}

# sha_of <file>: prints lowercase sha256, or empty on failure.
sha_of() {
    sha256sum "$1" 2>/dev/null | awk '{print tolower($1)}'
}

print_rollback_reminder() {
    echo "[ROLLBACK] if this kernel misbehaves, restore the known-good kernel:"
    echo "[ROLLBACK]   echo '<device-sudo-password>' | ssh $DEVICE \"sudo -S -p '' dpkg -i $ROLLBACK_DEB\""
    echo "[ROLLBACK]   echo '<device-sudo-password>' | ssh $DEVICE \"sudo -S -p '' reboot\""
    echo "[ROLLBACK] rollback deb sha256: $ROLLBACK_SHA"
    echo "[ROLLBACK] this script never removes it."
}

# ---- args --------------------------------------------------------------------
[ $# -eq 2 ] || { usage; exit 2; }
LOCAL_DEB="$1"
EXP_SHA="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')"
DRY_RUN="${DRY_RUN:-0}"

[ -f "$LOCAL_DEB" ] || fail "local deb not found: $LOCAL_DEB"
is_sha "$EXP_SHA" || fail "expected-sha256 is not 64 hex chars: '$2'"

# ---- step 1: verify the NEW deb on the host (BEFORE any ssh) -----------------
log_info "step 1/6: sha256 of local deb $LOCAL_DEB"
GOT_SHA="$(sha_of "$LOCAL_DEB")"
[ -n "$GOT_SHA" ] || fail "sha256sum failed on $LOCAL_DEB (is sha256sum installed?)"
if [ "$GOT_SHA" != "$EXP_SHA" ]; then
    log_err "LOCAL DEB SHA MISMATCH - refusing to touch the device"
    log_err "  expected: $EXP_SHA"
    log_err "  actual:   $GOT_SHA"
    log_err "(a wrong/trimmed/corrupted artifact; re-download from CI and compare against the gh-announced hash)"
    exit 1
fi
log_ok "local deb sha verified: $GOT_SHA"

# ---- step 2: verify the ROLLBACK asset on the device -------------------------
log_info "step 2/6: rollback asset verify on device ($DEVICE)"
if [ "$DRY_RUN" = "1" ]; then
    case "${D330_FAKE_ROLLBACK_SHA+set}" in
        set) ROLLBACK_GOT="$D330_FAKE_ROLLBACK_SHA" ;;
        *)   ROLLBACK_GOT="$ROLLBACK_SHA" ;;
    esac
    if [ "$ROLLBACK_GOT" = "MISSING" ]; then
        fail "[DRY-RUN] rollback asset MISSING on device: $ROLLBACK_DEB (simulated)"
    fi
else
    ROLLBACK_GOT="$(ssh $SSH_OPTS -o BatchMode=yes -o ConnectTimeout=15 "$DEVICE" \
        "sha256sum '$ROLLBACK_DEB'" 2>/dev/null | awk '{print tolower($1)}' || true)"
fi
if [ -z "$ROLLBACK_GOT" ] || ! is_sha "$ROLLBACK_GOT"; then
    log_err "ROLLBACK ASSET MISSING OR UNREADABLE on device: $ROLLBACK_DEB"
    log_err "refusing to deploy: without a verified rollback a broken kernel is unrecoverable"
    exit 1
fi
if [ "$ROLLBACK_GOT" != "$ROLLBACK_SHA" ]; then
    log_err "ROLLBACK ASSET SHA MISMATCH on device: $ROLLBACK_DEB"
    log_err "  recorded: $ROLLBACK_SHA"
    log_err "  actual:   $ROLLBACK_GOT"
    log_err "refusing to deploy: the recovery asset cannot be trusted"
    exit 1
fi
log_ok "rollback asset verified: $ROLLBACK_DEB"

# ---- DRY-RUN exit: everything below would touch the device -------------------
if [ "$DRY_RUN" = "1" ]; then
    RDEB_NAME="$(basename "$LOCAL_DEB")"
    echo "[DRY-RUN] would scp '$LOCAL_DEB' -> $DEVICE:/home/santiago/$RDEB_NAME"
    echo "[DRY-RUN] would re-verify its sha256 on device, then:"
    echo "[DRY-RUN]   ssh $DEVICE \"sudo -S -p '' dpkg -i /home/santiago/$RDEB_NAME\""
    echo "[DRY-RUN]   ssh $DEVICE \"sudo -S -p '' reboot\"   (then wait for ssh, up to 300 s)"
    print_rollback_reminder
    echo "[DRY-RUN] no device changes were made."
    exit 0
fi

# ---- credential handling (never stored, never echoed) ------------------------
PW=""
if [ -n "${D330_SUDO_PW:-}" ]; then
    PW="$D330_SUDO_PW"
elif [ -t 0 ]; then
    printf 'device sudo password (input hidden): ' >&2
    STTY_SAVED="$(stty -g 2>/dev/null || true)"
    stty -echo 2>/dev/null || true
    IFS= read -r PW || true
    if [ -n "$STTY_SAVED" ]; then stty "$STTY_SAVED" 2>/dev/null || true; fi
    printf '\n' >&2
else
    IFS= read -r PW || true
fi
[ -n "$PW" ] || fail "no device sudo password (set D330_SUDO_PW or type one)"

# ---- step 3: scp the deb to the device ---------------------------------------
# Distinct incoming name keyed to the deb's own sha: never collides with the
# rollback asset (the 2026-10-15 clobber incident), and the uploaded copy is
# KEPT after dpkg -i so it can serve as the next deploy's rollback target.
RDEB_NAME="deploy_incoming_$(printf '%s' "$GOT_SHA" | cut -c1-12).deb"
RDEB="/home/santiago/$RDEB_NAME"
log_info "step 3/6: scp $LOCAL_DEB -> $DEVICE:$RDEB"
scp $SSH_OPTS -o BatchMode=yes "$LOCAL_DEB" "$DEVICE:$RDEB" || fail "scp failed"

# ---- step 4: re-verify the uploaded copy on the device -----------------------
log_info "step 4/6: device-side sha256 of uploaded deb"
UP_SHA="$(ssh $SSH_OPTS -o BatchMode=yes -o ConnectTimeout=15 "$DEVICE" \
    "sha256sum '$RDEB'" 2>/dev/null | awk '{print tolower($1)}' || true)"
if [ "$UP_SHA" != "$GOT_SHA" ]; then
    log_err "uploaded deb sha mismatch on device (scp corruption?):"
    log_err "  expected: $GOT_SHA"
    log_err "  actual:   ${UP_SHA:-<none>}"
    log_err "nothing was installed; remove nothing by hand - just re-run this script"
    exit 1
fi
log_ok "uploaded deb sha verified on device: $UP_SHA"

# ---- step 5: dpkg -i via scripted sudo (password via stdin only) -------------
log_info "step 5/6: dpkg -i $RDEB (password via ssh stdin)"
if ! printf '%s\n' "$PW" | ssh $SSH_OPTS -o BatchMode=yes "$DEVICE" "sudo -S -p '' dpkg -i '$RDEB'"; then
    log_err "dpkg -i FAILED on device - the previous kernel should still be in place"
    print_rollback_reminder
    exit 1
fi
log_ok "kernel package installed"

# ---- step 6: reboot and wait for ssh -----------------------------------------
log_info "step 6/6: rebooting device and waiting for ssh (up to 300 s)"
if ! printf '%s\n' "$PW" | ssh $SSH_OPTS -o BatchMode=yes "$DEVICE" "sudo -S -p '' reboot" 2>/dev/null; then
    # Non-zero here is expected: the connection drops mid-reboot.
    log_warn "reboot ssh returned non-zero (connection drop during reboot is expected)"
fi
UP=""
i=0
while [ "$i" -lt 60 ]; do
    if ssh $SSH_OPTS -o BatchMode=yes -o ConnectTimeout=10 "$DEVICE" true 2>/dev/null; then
        UP=1
        break
    fi
    sleep 5
    i=$((i + 1))
done
if [ -z "$UP" ]; then
    log_err "device did NOT return on ssh within 300 s of reboot"
    log_err "if it never comes back, the rollback deb below restores the known-good kernel"
    print_rollback_reminder
    exit 1
fi
log_ok "device is back on ssh (next: verify uname -r, run by the caller)"

print_rollback_reminder
log_ok "deploy complete: $RDEB_NAME (sha256 $GOT_SHA) installed and device rebooted"
exit 0
