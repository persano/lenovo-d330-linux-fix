# Phase 39 - Deferred / Out-of-Scope Items

Items discovered during execution that are outside this plan's file scope and were
NOT fixed here.

## Wireless Intel options outside the plan scope

- `patches/power/etc/modprobe.d/lenovo-d330-power.conf` still configures
  `options iwlwifi power_save=1 d0i3_disable=0 uapsd_disable=0`.
- `patches/power/README.md` lists it as an intended power option.
- The D330-10IGL has no Intel wireless (Realtek RTL8821CE only), so this is the
  same class of defect as Phase 39 Task 1 - a modprobe option targeting an
  absent module. It is out of this plan's declared `files_modified` scope.
- Suggested owner: a later phase in the M8/M9/M10/M15/M16 audit remediation
  (Phase 40-42); confirm the audit ID before acting.
