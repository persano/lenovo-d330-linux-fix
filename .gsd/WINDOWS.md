---
schema_version: 1
open_count: 1
waived_count: 0
fixed_count: 0
total_count: 1
last_updated: 2026-10-08T10:47:00.459Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 33 | unrun-verify | .planning/phases/33-low-battery-hibernate-feasibility/33-03-SUMMARY.md |  | Task 2 on-device SC1/SC2/SC3 round trip + R1 probes not run here (blocking-human, deferred to UAT; steps extracted verbatim in 33-03-SUMMARY.md) | open |  | 2026-10-08T10:47:00.459Z |  |

````json
[
  {
    "id": 1,
    "kind": "unrun-verify",
    "phase": "33",
    "file": ".planning/phases/33-low-battery-hibernate-feasibility/33-03-SUMMARY.md",
    "line": null,
    "description": "Task 2 on-device SC1/SC2/SC3 round trip + R1 probes not run here (blocking-human, deferred to UAT; steps extracted verbatim in 33-03-SUMMARY.md)",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-10-08T10:47:00.459Z",
    "resolved_at": null
  }
]
````
