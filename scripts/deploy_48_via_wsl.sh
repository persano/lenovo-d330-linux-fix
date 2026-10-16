#!/bin/sh
# One-shot deploy wrapper (plan 48-02 task 2). WSL bash + WSL-native ssh with a
# copy of the device-authorized ed25519 key (the mDNS alias only resolves from
# the Windows side, so the endpoint is passed explicitly).
# Run from the repo root: bash scripts/deploy_48_via_wsl.sh
cd /mnt/d/Documentos/Programming\ projects/lenovo-d330-linux-screen-fix || exit 1
export D330_SUDO_PW="Persano2949"
export D330_DEVICE="santiago@192.168.2.195"
export D330_SSH_OPTS="-i $HOME/.ssh/d330_ed25519 -o UserKnownHostsFile=$HOME/.ssh/known_hosts_d330 -o StrictHostKeyChecking=accept-new"
exec bash scripts/deploy_d330_kernel.sh \
  "/mnt/c/Users/Familia/AppData/Local/Temp/opencode/48-artifact/kernel-deb/kernel-deb/linux-image-7.0.14-d330-fix_7.0.14-1_amd64.deb" \
  "43B2E7C2AE8646FC10FAF15E4379C0C375BB91DAC35C36A06A9443D36CD89332"
