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

    # SC1 is non-vacuous only if the subject is GREEN before mutation. Without
    # this baseline a script that already exits non-zero (unrelated tooling, a
    # latent bug, or a permanently-failing harness) would ``pass'' SC1 by
    # failing for the wrong reason. Run the intact command first, require rc 0.
    local baseline_rc=0
    ( cd "$REPO_ROOT" && eval "$cmd" ) >/dev/null 2>&1 || baseline_rc=$?
    if [ "$baseline_rc" -ne 0 ]; then
        bad "SC1 $label: baseline '$cmd' already exits $baseline_rc on the intact subject"
        return 0
    fi

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
    's/no_timer_check/nowatchdog no_timer_check/'

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
    local script="$1" base out
    base="$(basename "$script")"
    [ "$base" = "test_harness_trust.sh" ] && return 0

    # code_c: comments stripped, quoted strings KEPT. Gate detection, redirect
    #         targets, and sysfs-taint tracking need the real arguments.
    # code_q: comments AND quoted strings stripped. Command-position mutation
    #         detection runs on this so assertion literals such as
    #         `grep -q "systemctl enable foo"` are not mistaken for calls.
    local code_c code_q
    code_c="$(sed -e 's/^[[:space:]]*#.*$//' "$script")"
    code_q="$(printf '%s\n' "$code_c" | sed -e "s/'[^']*'//g" -e 's/"[^"]*"//g')"

    # Command position: start of line, after a command separator, or after a
    # shell keyword (so `if systemctl ...` counts, `grep -q "..."` does not).
    local cmdpos='(^[[:space:]]*|[;&|][[:space:]]*|(if|then|do|else|elif|while|until|!)[[:space:]]+)'

    local hits="" mut_lines="" deleg_lines=""

    scan_mut() { # scan_mut LABEL REGEX  (matched on quote-stripped source)
        local label="$1" re="$2" found
        found="$(printf '%s\n' "$code_q" | grep -nE "$re" || true)"
        [ -n "$found" ] || return 0
        hits="$hits $label"
        mut_lines="$mut_lines $(printf '%s\n' "$found" | cut -d: -f1 | tr '\n' ' ')"
    }

    scan_mut systemctl "${cmdpos}systemctl[[:space:]]+(start|stop|restart|reload|try-restart|reload-or-restart|enable|disable|mask|unmask|set-default|reset-failed|daemon-reload|kill|isolate|freeze|thaw)([[:space:]]|$)"
    scan_mut fstrim "${cmdpos}fstrim([[:space:]]|$)"
    scan_mut modprobe "${cmdpos}modprobe[[:space:]]"
    scan_mut insmod "${cmdpos}insmod[[:space:]]"
    scan_mut rmmod "${cmdpos}rmmod[[:space:]]"
    scan_mut sysctl-w "${cmdpos}sysctl[[:space:]]+(-w|--write)([[:space:]]|$)"
    scan_mut rfkill "${cmdpos}rfkill[[:space:]]"
    scan_mut ip-link "${cmdpos}ip[[:space:]]+(link|addr|address|route|rule)([[:space:]]|$)"
    scan_mut mount "${cmdpos}(mount|umount)[[:space:]]"
    scan_mut mkfs "${cmdpos}mkfs([.[:space:]]|$)"
    scan_mut dd "${cmdpos}dd[[:space:]][^;&|]*if="
    scan_mut nmcli-radio "${cmdpos}nmcli[[:space:]]+radio"

    # --- Writes into /sys or /proc: a literal/quoted target, or a variable
    #     whose value derives from a /sys or /proc path. ------------------------
    out="$(printf '%s\n' "$code_c" | grep -nE "(>|>>|tee)[[:space:]]*[\"']?(/sys|/proc)/" || true)"
    if [ -n "$out" ]; then
        hits="$hits sysfs-write"
        mut_lines="$mut_lines $(printf '%s\n' "$out" | cut -d: -f1 | tr '\n' ' ')"
    fi

    # Collect variables whose value derives from a /sys or /proc path (iterative
    # to a fixpoint, so `node="$d/conservation_mode"` inherits `d`'s taint from
    # `for d in /sys/...`).
    local tainted=" " changed=1 var rhs line t
    while [ "$changed" -eq 1 ]; do
        changed=0
        while IFS= read -r line; do
            var="$(printf '%s' "$line" | sed -nE 's/^[[:space:]]*for[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)[[:space:]]+in[[:space:]].*/\1/p')"
            if [ -z "$var" ]; then
                var="$(printf '%s' "$line" | sed -nE 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=.*/\1/p')"
            fi
            [ -n "$var" ] || continue
            case " $tainted " in *" $var "*) continue ;; esac
            rhs="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*for[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]+in[[:space:]]?//; s/^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=//')"
            rhs="${rhs%\\}"
            if printf '%s' "$rhs" | grep -Eq '/sys|/proc'; then
                tainted="$tainted$var "; changed=1; continue
            fi
            for t in $tainted; do
                if printf '%s' "$rhs" | grep -qE "\\\$\{?$t\}?([^A-Za-z0-9_]|$)"; then
                    tainted="$tainted$var "; changed=1; break
                fi
            done
        done < <(printf '%s\n' "$code_c")
    done

    for t in $tainted; do
        out="$(printf '%s\n' "$code_c" | grep -nE "(^|[[:space:];])(>|>>)[[:space:]]*[\"']?\\\$\{?$t\}?[\"']?([[:space:];]|$)" || true)"
        if [ -n "$out" ]; then
            hits="$hits sysfs-write(\$$t)"
            mut_lines="$mut_lines $(printf '%s\n' "$out" | cut -d: -f1 | tr '\n' ' ')"
        fi
    done

    # --- Delegated mutations: a `tools/*` helper invoked WITH --apply carries
    #     its own gate on the invocation line. Flagged so the scan is not blind
    #     to thermals/boot_speed-style delegation. ----------------------------
    out="$(printf '%s\n' "$code_c" | grep -nE "${cmdpos}(bash|sh)[[:space:]][^;&|]*tools/[A-Za-z0-9._-]+[\"']?[[:space:]][^;&|]*--apply([[:space:]]|\$)" || true)"
    if [ -n "$out" ]; then
        hits="$hits delegated-apply"
        deleg_lines="$(printf '%s\n' "$out" | cut -d: -f1 | tr '\n' ' ')"
    fi

    [ -n "$hits" ] || return 0

    # --- Gate decision. A command-position mutator or sysfs write must sit in a
    #     branch that actually gates on the parsed --apply flag: the script must
    #     parse `--apply` (the `--apply)` case arm) AND branch on the APPLY
    #     variable before the mutation. A mention in --help or a comment no
    #     longer satisfies it. Delegated calls self-gate via --apply on the line.
    local mut_min="" guard_line handler_line gated=1
    if [ -n "${mut_lines// /}" ]; then
        mut_min="$(printf '%s\n' $mut_lines | sort -n | head -n1)"
        guard_line="$(printf '%s\n' "$code_c" | grep -nE '\[\[.*APPLY.*\]\]|\[[[:space:]]+[^]]*APPLY[^]]*\][[:space:]]' | head -n1 | cut -d: -f1)"
        handler_line="$(printf '%s\n' "$code_c" | grep -nE '(^|[[:space:]])--apply\)' | head -n1 | cut -d: -f1)"
        if [ -z "$guard_line" ] || [ -z "$handler_line" ] || [ "$guard_line" -ge "$mut_min" ]; then
            gated=0
        fi
    fi

    if [ "$gated" -eq 1 ]; then
        ok "SC2 $base: mutation(s)$hits gated by --apply"
    else
        bad "SC2 $base: mutation(s)$hits present with no --apply gate"
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
