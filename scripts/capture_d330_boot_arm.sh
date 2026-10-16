#!/bin/sh
# Boot-arm capture (48-02 task 3, pre-suspend), correct invocation: helper
# takes an arm argument. Then stage into the repo kit.
cd /mnt/d/Documentos/Programming\ projects/lenovo-d330-linux-screen-fix || exit 1
SSH="ssh -i $HOME/.ssh/d330_ed25519 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_d330 -o StrictHostKeyChecking=accept-new -o BatchMode=yes santiago@192.168.2.195"
$SSH 'echo Persano2949 | sudo -S -p "" bash /usr/local/bin/capture_dsi_dumps.sh boot 2>&1 | tail -8; ls -lat /home/santiago/ | grep d330_dsi_capture | head -3'
