#!/bin/sh
# Fetch the iteration-1 capture pair into the repo kit.
cd /mnt/d/Documentos/Programming\ projects/lenovo-d330-linux-screen-fix || exit 1
SCP="scp -i $HOME/.ssh/d330_ed25519 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_d330 -o StrictHostKeyChecking=accept-new -o BatchMode=yes"
$SCP santiago@192.168.2.195:/home/santiago/d330_dsi_capture/boot_dsi_regs.txt "docs/dumps/re_kit/it1_boot_dsi_regs.txt" || exit 1
$SCP santiago@192.168.2.195:/home/santiago/d330_dsi_capture3/resume_dsi_regs.txt "docs/dumps/re_kit/it1_resume_dsi_regs.txt" || exit 1
sha256sum docs/dumps/re_kit/it1_boot_dsi_regs.txt docs/dumps/re_kit/it1_resume_dsi_regs.txt
