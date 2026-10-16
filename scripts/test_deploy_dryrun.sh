#!/bin/sh
# DRY_RUN regression test for the patched deploy script (rollback-clobber fix).
cd /mnt/d/Documentos/Programming\ projects/lenovo-d330-linux-screen-fix || exit 1
DUMMY=$(mktemp)
head -c 100000 /dev/urandom > "$DUMMY"
SHA=$(sha256sum "$DUMMY" | cut -d' ' -f1)
echo "== fail path: sha mismatch =="
DRY_RUN=1 bash scripts/deploy_d330_kernel.sh "$DUMMY" 0000000000000000000000000000000000000000000000000000000000000000 2>&1 | tail -2
echo "rc=$?"
echo "== fail path: rollback missing =="
DRY_RUN=1 D330_FAKE_ROLLBACK_SHA=MISSING bash scripts/deploy_d330_kernel.sh "$DUMMY" "$SHA" 2>&1 | tail -2
echo "rc=$?"
echo "== pass path (dry-run) =="
DRY_RUN=1 bash scripts/deploy_d330_kernel.sh "$DUMMY" "$SHA" 2>&1 | tail -6
echo "rc=$?"
rm -f "$DUMMY"
