#!/bin/sh
# One-shot deploy wrapper, iteration 2 (plan 48-02 loop, run 2).
# Rollback target: the it1 fix kernel deb preserved on device
# (linux-image-7.0.14-d330-fix_7.0.14-1_amd64.deb, sha 43b2e7c2…8932) —
# per the hardened script, uploads land on a sha-keyed incoming name so this
# file survives.
cd /mnt/d/Documentos/Programming\ projects/lenovo-d330-linux-screen-fix || exit 1
export D330_SUDO_PW="Persano2949"
export D330_DEVICE="santiago@192.168.2.195"
export D330_SSH_OPTS="-i $HOME/.ssh/d330_ed25519 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_d330 -o StrictHostKeyChecking=accept-new"
export D330_ROLLBACK_DEB="/home/santiago/linux-image-7.0.14-d330-fix_7.0.14-1_amd64.deb"
export D330_ROLLBACK_SHA="43b2e7c2ae8646fc10faf15e4379c0c375bb91dac35c36a06a9443d36cd89332"
exec bash scripts/deploy_d330_kernel.sh \
  "/mnt/c/Users/Familia/AppData/Local/Temp/opencode/48-artifact/it2/kernel-deb/linux-image-7.0.14-d330-fix_7.0.14-1_amd64.deb" \
  "FEA98E575AD2D2AA5AAD0728B1C3C6855E7C14BE9FE4D36C0D9A62704D1DC876"
