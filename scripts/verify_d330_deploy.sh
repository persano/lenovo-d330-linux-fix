#!/bin/sh
# Device verify (post-deploy, plan 48-02 task 2):
#   1. running kernel = deployed sha (uname)
#   2. dump node live via the exact capture-script glob
#   3. rollback asset candidates on device + shas
cd /mnt/d/Documentos/Programming\ projects/lenovo-d330-linux-screen-fix || exit 1
SSH="ssh -i $HOME/.ssh/d330_ed25519 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_d330 -o StrictHostKeyChecking=accept-new -o BatchMode=yes santiago@192.168.2.195"
$SSH 'uname -r; echo Persano2949 | sudo -S -p "" sh -c "cat /sys/kernel/debug/dri/0000:00:02.0/i915_dsi_regs" | wc -c; echo Persano2949 | sudo -S -p "" sh -c "head -5 /sys/kernel/debug/dri/0000:00:02.0/i915_dsi_regs"; echo Persano2949 | sudo -S -p "" sh -c "cat /sys/kernel/debug/dri/0000:00:02.0/i915_dsi_regs" | wc -l'
