#!/bin/sh
cd /mnt/d/Documentos/Programming\ projects/lenovo-d330-linux-screen-fix || exit 1
SSH="ssh -i $HOME/.ssh/d330_ed25519 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_d330 -o StrictHostKeyChecking=accept-new -o BatchMode=yes santiago@192.168.2.195"
$SSH 'echo Persano2949 | sudo -S -p "" sh -c "ls /sys/kernel/debug/dri/; echo ----; ls /sys/class/drm/ | head -8; echo ----; dmesg | egrep -i -e i915 -e unbind -e rebind -e probe | tail -14"'
