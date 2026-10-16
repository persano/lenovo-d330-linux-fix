#!/bin/sh
cd /mnt/d/Documentos/Programming\ projects/lenovo-d330-linux-screen-fix || exit 1
ssh -i $HOME/.ssh/d330_ed25519 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_d330 -o StrictHostKeyChecking=accept-new -o BatchMode=yes santiago@192.168.2.195 'cat /home/santiago/d330_resume_session2.sh'
