#!/usr/bin/env bash
# ==============================================================================
# scripts/test_harness_trust.sh
#
# Meta-guard for the D330 test harness (Phase 41, audit M12/N8).
#
# SC1 - a failing check must be able to fail the run. This suite temporarily
#       breaks the *subject* of five representative `test_*.sh` scripts (the
#       config / module / token each one validates), asserts the script exits
#       NON-ZERO, then restores the subject and asserts the tree is clean again.
#       It never leaves the working tree dirty.
#
# SC2 - no `scripts/test_*.sh` may mutate the system (systemctl state changes,
#       fstrim, modprobe, nmcli radio, or writes under /sys or /proc/sys)
#       unless the script carries an explicit `--apply` gate. Mutations are
#       detected on comment/quote-stripped source so assertion string literals
#       such as `grep -q "systemctl enable foo"` are not mistaken for calls.
#
# Exits non-zero if any SC1 case still passes with a broken subject, or if any
# SC2 script mutates the system without an `--apply` gate.
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

echo "=========================================================="
echo " Lenovo D330 Test-Harness Trust Meta-Guard (SC1 + SC2)    "
echo "=========================================================="

passed=0
failed=0
ok()  { echo "  [PASS] $1"; passed=$((passed + 1)); }
bad() { echo "  [FAIL] $1"; failed=$((failed + 1)); }

# ------------------------------------------------------------------------------
# Backup / restore plumbing. Every mutated file is snapshotted before the
# mutation; the trap restores all snapshots on exit so an early abort can never
# leave the tree dirty.
# ------------------------------------------------------------------------------
BACKUP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/d330_harness_trust.XXXXXX")"
RESTORE_FILES=()
RESTORE_BACKUPS=()

restore_all() {
    local i
    for i in "${!RESTORE_FILES[@]}"; do
        if [ -n "${RESTORE_FILES[$i]:-}" ] && [ -f "${RESTORE_BACKUPS[$i]:-}" ]; then
            cp -p "${RESTORE_BACKUPS[$i]}" "${RESTORE_FILES[$i]}" 2>/dev/null || true
        fi
    done
    rm -rf "$BACKUP_DIR"
}
trap restore_all EXIT

# sc1_case LABEL TEST_CMD SUBJECT_REL SED_EXPR
#   Break SUBJECT_REL with SED_EXPR, run TEST_CMD, assert it exits non-zero,
#   restore the subject, and assert the tree is clean for that path.
sc1_case() {
    local label="$1" cmd="$2" rel="$3" sedexpr="$4"
    local abs="$REPO_ROOT/$rel"
    local backup="$BACKUP_DIR/$(printf '%s' "$label" | tr -c 'A-Za-z0-9._-' '_')"

    if [ ! -f "$abs" ]; then
        bad "SC1 $label: subject file missing: $rel"
        return 0
    fi
    if ! cp -p "$abs" "$backup"; then
        bad "SC1 $label: could not snapshot $rel"
        return 0
    fi
    RESTORE_FILES+=("$abs")
    RESTORE_BACKUPS+=("$backup")

    # Record whether the path was already dirty (e.g. a CRLF working copy that a
    # WSL git sees as modified). Only a transition clean->dirty is our fault.
    local pre_dirty=0
    git -C "$REPO_ROOT" diff --quiet -- "$rel" || pre_dirty=1

    if ! sed -i "$sedexpr" "$abs"; then
        bad "SC1 $label: sed mutation failed on $rel"
        cp -p "$backup" "$abs"
        return 0
    fi
    if cmp -s "$abs" "$backup"; then
        bad "SC1 $label: mutation was a no-op on $rel (nothing to break)"
        return 0
    fi

    local rc=0
    ( cd "$REPO_ROOT" && eval "$cmd" ) >/dev/null 2>&1 || rc=$?

    # Restore byte-for-byte from the snapshot; the snapshot is the authority
    # (git diff would flag a pre-existing CRLF/LF disagreement, not our edit).
    cp -p "$backup" "$abs"
    if ! cmp -s "$abs" "$backup"; then
        bad "SC1 $label: restore of $rel did not reproduce the original bytes"
        return 0
    fi
    if [ "$pre_dirty" -eq 0 ] && ! git -C "$REPO_ROOT" diff --quiet -- "$rel"; then
        bad "SC1 $label: working tree dirty after restoring $rel"
        return 0
    fi

    if [ "$rc" -ne 0 ]; then
        ok "SC1 $label: broken subject -> '$cmd' exits $rc, tree restored"
    else
        bad "SC1 $label: '$cmd' still exits 0 with a broken subject"
    fi
}

# ------------------------------------------------------------------------------
# SC1: five representative scripts, each driven by breaking its own subject.
# ------------------------------------------------------------------------------
sc1_case "audio-dsp" \
    "bash scripts/test_audio_dsp.sh --dry-run" \
    "patches/audio_dsp/etc/pipewire/pipewire.conf.d/50-lenovo-d330-speaker-dsp.conf" \
    's/label = bq_highpass/label = bq_bogus/'

sc1_case "wireless-coex" \
    "bash scripts/test_wireless_coex.sh --dry-run" \
    "patches/wireless/etc/modprobe.d/lenovo-d330-wireless.conf" \
    's/rtw88_core/rtw88_bogus/'

sc1_case "udev-hwdb-match" \
    "bash scripts/test_udev_hwdb_match.sh" \
    "patches/dkms/etc/udev/hwdb.d/61-lenovo-d330-sensor.hwdb" \
    's/pn82H0/pnXX00/'

sc1_case "power-stack" \
    "bash scripts/test_power_stack.sh" \
    "patches/fastboot/etc/default/grub.d/52-lenovo-d330-fastboot.cfg" \
    's/softlockup_panic=1/softlockup_panic=0/'

sc1_case "tray-applet" \
    "bash scripts/test_tray_applet.sh" \
    "patches/hardware_controls/etc/xdg/autostart/d330-tray.desktop" \
    's|^Exec=.*|Exec=/usr/local/bin/d330-tray-bogus|'

# ------------------------------------------------------------------------------
# SC2: static mutation-gate scan over every test script (excluding this file).
# Comment and quoted-string content is stripped first so assertion literals are
# not counted as invocations.
# ------------------------------------------------------------------------------
echo ""
echo "--- SC2: no system mutation without an --apply gate ---"

sc2_scan_one() {
    local script="$1" base stripped hits
    base="$(basename "$script")"
    [ "$base" = "test_harness_trust.sh" ] && return 0

    stripped="$(sed -e 's/^[[:space:]]*#.*$//' -e "s/'[^']*'//g" -e 's/"[^"]*"//g' "$script")"

    # Match only command-position invocations (start of line, after a command
    # separator, or after a shell keyword). Help-text/heredoc prose such as
    # "Validate the modprobe conf" is not a command and must not trip the scan.
    local cmdpos='(^[[:space:]]*|[;&|][[:space:]]*|(if|then|do|else|elif|while|until|!)[[:space:]]+)'

    hits=""
    if printf '%s\n' "$stripped" | grep -Eq "${cmdpos}systemctl[[:space:]]+(start|stop|restart|reload|try-restart|reload-or-restart|enable|disable|mask|unmask|set-default|reset-failed|daemon-reload|kill|isolate|freeze|thaw)([[:space:]]|$)"; then
        hits="$hits systemctl"
    fi
    if printf '%s\n' "$stripped" | grep -Eq "${cmdpos}fstrim([[:space:]]|$)"; then
        hits="$hits fstrim"
    fi
    if printf '%s\n' "$stripped" | grep -Eq "${cmdpos}modprobe[[:space:]]"; then
        hits="$hits modprobe"
    fi
    if printf '%s\n' "$stripped" | grep -Eq '(>|>>|tee)[[:space:]]*/sys/|(>|>>|tee)[[:space:]]*/proc/sys/'; then
        hits="$hits sysfs-write"
    fi
    if printf '%s\n' "$stripped" | grep -Eq "${cmdpos}nmcli[[:space:]]+radio"; then
        hits="$hits nmcli-radio"
    fi

    if [ -n "$hits" ]; then
        if grep -Fq -- '--apply' "$script"; then
            ok "SC2 $base: mutation(s)$hits gated by --apply"
        else
            bad "SC2 $base: mutation(s)$hits present with no --apply gate"
        fi
    fi
    return 0
}

for script in "$REPO_ROOT"/scripts/test_*.sh; do
    [ -f "$script" ] || continue
    sc2_scan_one "$script"
done

# ------------------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------------------
echo ""
echo "=========================================================="
echo " Harness-trust meta-guard summary: passed=$passed failed=$failed"
echo "=========================================================="

if [ "$failed" -gt 0 ]; then
    echo "RESULT: FAIL" >&2
    exit 1
fi
echo "RESULT: PASS"
exit 0
