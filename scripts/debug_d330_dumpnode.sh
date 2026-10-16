#!/bin/sh
# Debug: dump node read (visible stderr) + dmesg markers
cd /mnt/d/Documentos/Programming\ projects/lenovo-d330-linux-screen-fix || exit 1
SSH="ssh -i $HOME/.ssh/d330_ed25519 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_d330 -o StrictHostKeyChecking=accept-new -o BatchMode=yes santiago@192.168.2.195"
$SSH 'echo Persano2949 | sudo -S -p "" cat /sys/kernel/debug/dri/0000:00:02.0/i915_dsi_regs; echo "rc=$?"; echo Persano2949 | sudo -S -p "" sh -c "dmesg | grep -i -E "d330_dsi|dsi_regs|bxt_dsi_pll_is_enabled" | tail -8"'
