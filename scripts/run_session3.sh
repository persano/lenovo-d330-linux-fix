#!/bin/sh
# Stage session3 on the device and run it synchronously (~60 s), then show the log.
cd /mnt/d/Documentos/Programming\ projects/lenovo-d330-linux-screen-fix || exit 1
SSH="ssh -i $HOME/.ssh/d330_ed25519 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_d330 -o StrictHostKeyChecking=accept-new -o BatchMode=yes santiago@192.168.2.195"
scp -i $HOME/.ssh/d330_ed25519 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_d330 -o StrictHostKeyChecking=accept-new -o BatchMode=yes scripts/session3_d330.sh santiago@192.168.2.195:/home/santiago/session3_d330.sh || exit 1
$SSH 'echo Persano2949 | sudo -S -p "" sh /home/santiago/session3_d330.sh; echo ---- LOG ----; tail -14 /home/santiago/d330_resume_session3.log; sha256sum /home/santiago/d330_dsi_capture3/resume_dsi_regs.txt 2>/dev/null'
