# Phase 33: Low-Battery Hibernate Feasibility — Validation Strategy

**Created:** 2026-10-08 (plan-phase step 6)
**ASVS level:** 1, **block on:** high (workflow.security_enforcement active)

## Security Validation

Threat model must appear in each PLAN.md `<threat_model>` block. Level-1 scope for this phase:

| Threat | Mitigation / validation |
|---|---|
| World-readable swapfile (RAM contents leak) | `chmod 600` + ownership root before `mkswap`; test asserts mode |
| Installer silently corrupts GRUB config | grub.d snippet append is idempotent (grep before write); `grub-mkconfig` only when grub detected; failure → non-zero + manual-step message, never partial edit of `/etc/default/grub` |
| Command injection / unsafe exec in daemon | keep `subprocess.run([...])` list form (no `shell=True`); no string interpolation of battery values into commands |
| False safety net (audit C3 root cause) | refuse path must be loud: `[ERROR]` log + suspend fallback; never print success unless hibernate genuinely invoked with valid resume device |
| Sizing logic abuse (free-space guard) | clamp RAM-derived size to [4 GB, 8 GB]; skip creation (not shrink root) when free space insufficient; `[WARN]` + non-fatal |

Blocking threshold: any **high** finding blocks the phase; medium → fix in code review.

## Functional Validation

1. **Static gates:** `bash -n` on every touched shell file; `python3 -m py_compile tools/d330-auto-hibernate.py`; grep-based consistency check (service `ExecStart` path == installed path in `scripts/install_dkms.sh`).
2. **Unit tests (new suite, repo convention `scripts/test_*.sh`):** daemon logic tested with fake `/proc/swaps` (env-var override `D330_PROC_SWAPS` for tests only) covering: zram-only → refuse + suspend fallback + `[ERROR]`; non-zram present → proceed; `--dry-run` reports every swap area + resume-device verdict; free-space guard skip; clamp bounds.
3. **Harness integration:** `scripts/test_storage_cellular.sh --dry-run` remains rc=0 and delegates the new suite (same pattern as `test_microsd_guards.sh` in phase 32).
4. **Service/unit static assertions:** `Type=oneshot` present; enable line present in `install_dkms.sh`, deb `postinst`, rpm `%post`; udev glob comment present; `systemd-analyze verify` on the unit file (WSL, non-root — expect load warnings only, syntax errors block).
5. **Coarse dry-run:** `d330-auto-hibernate.py --dry-run` executes in this environment and prints swap situation without executing hibernate.

## On-Target / Human Acceptance (deferred, must be flagged in VERIFICATION.md)

- Real `systemctl hibernate` → power cycle → resume completes (research risk R1: initramfs-tools swap-file resume; criterion 1 cannot be proven from CI).
- Fresh `--install` run shows service `enabled` (criterion 3) on device.
- GRUB regeneration on a grub-provisioned target; manual-step path on non-GRUB target.

These map to UAT items with machine-checked equivalents where possible (phase 32 pattern: probe scripts + VERIFICATION.md `overrides:` entries + `phase uat-passed`).
