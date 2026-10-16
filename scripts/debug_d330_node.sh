#!/bin/sh
cd /mnt/d/Documentos/Programming\ projects/lenovo-d330-linux-screen-fix || exit 1
SSH="ssh -i $HOME/.ssh/d330_ed25519 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_d330 -o StrictHostKeyChecking=accept-new -o BatchMode=yes santiago@192.168.2.195"
$SSH 'echo Persano2949 | sudo -S -p "" sh -c "ls /sys/kernel/debug/dri/0/ | head -20; echo ----; find /sys/kernel/debug/dri -name i915_dsi_regs 2>/dev/null; echo ----; find /sys/kernel/debug -name i915_dsi_regs 2>/dev/null; echo ----; dmesg | egrep -i -e dsi_regs -e dump -e d330 | tail -6"'
