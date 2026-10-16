#!/bin/sh
# Iteration-1 suspend/resume session (48-02 task 3), session-2 pattern.
LOG=/home/santiago/d330_resume_session3.log
CAPDIR=/home/santiago/d330_dsi_capture3
: > "$LOG"
exec >>"$LOG" 2>&1
systemd-inhibit --what=idle:sleep:handle-lid-switch sh -c "
echo \"=== session3 start \$(date +%T)\"
echo \"[1] inhibit held\"
echo \"[2] rtcwake suspending \$(date +%T)\"
rtcwake -m mem -s 45
echo \"[3] woke \$(date +%T)\"
/usr/local/bin/capture_dsi_dumps.sh resume $CAPDIR
echo \"[4] done \$(date +%T)\"
"
