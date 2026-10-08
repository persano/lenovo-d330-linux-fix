# Phase 39 - Deferred / Out-of-Scope Items

Items discovered during execution that are outside this plan's file scope and were
NOT fixed here.

## Wireless Intel options outside the plan scope

- **Status:** resolved

- `patches/power/etc/modprobe.d/lenovo-d330-power.conf` no longer emits any
  `iwlwifi` option (fixed in Phase 40; the conf now only sets `i915
  enable_fbc=0 enable_psr=0`).
- `patches/power/README.md` was updated at milestone close to drop the stale
  `iwlwifi` / `pcie_aspm` / `i915 enable_rc6` list.
- Resolved at v7.0 milestone close; no action left.
