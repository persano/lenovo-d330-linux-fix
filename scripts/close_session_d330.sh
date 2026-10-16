#!/bin/sh
# Close-out suspend/resume session for cycle N (49-01), session-3 pattern verbatim.
# One arg: cycle number N (1..3). LOG and CAPDIR derive from N:
#   LOG    /home/santiago/d330_resume_session_close$N.log
#   CAPDIR /home/santiago/d330_dsi_capture_close$N
# Staged via scp to /home/santiago/close_session_d330.sh and run under
# scripted sudo (echo <pw> | sudo -S -p '' sh /home/santiago/close_session_d330.sh N).
# v9.0 binding rule: never invoke this without the per-cycle user authorization
# granted at the orchestrator's checkpoint — the rtcwake trigger is the gated step.
N="$1"
case "$N" in
    ''|*[!0-9]*) echo "usage: close_session_d330.sh <cycle-number>" >&2; exit 2 ;;
esac
LOG=/home/santiago/d330_resume_session_close$N.log
CAPDIR=/home/santiago/d330_dsi_capture_close$N
: > "$LOG"
exec >>"$LOG" 2>&1
systemd-inhibit --what=idle:sleep:handle-lid-switch sh -c "
echo \"=== close$N start \$(date +%T)\"
echo \"[1] inhibit held\"
echo \"[2] rtcwake suspending \$(date +%T)\"
rtcwake -m mem -s 45
echo \"[3] woke \$(date +%T)\"
/usr/local/bin/capture_dsi_dumps.sh resume $CAPDIR
echo \"[4] done \$(date +%T)\"
"
