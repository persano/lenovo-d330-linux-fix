#!/bin/sh
# Restore the panel via the user's proven reload workaround (unbind/bind i915).
cd /mnt/d/Documentos/Programming\ projects/lenovo-d330-linux-screen-fix || exit 1
ssh -i $HOME/.ssh/d330_ed25519 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_d330 -o StrictHostKeyChecking=accept-new -o BatchMode=yes santiago@192.168.2.195 'echo Persano2949 | sudo -S -p "" bash /home/santiago/d330-display-reload.sh 2>&1 | tail -5'
