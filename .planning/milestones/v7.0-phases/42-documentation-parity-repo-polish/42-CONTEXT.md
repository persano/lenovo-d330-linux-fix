# Phase 42: Documentation Parity & Repository Polish - Context

**Gathered:** 2026-10-08 | **Status:** Ready (auto-accepted; slim pipeline)

<domain>
Audit M17/N1–N5/N7/N9/N10: every claim in `CHANGES_AUDIT.md`, `README.md` and the packaging recipes matches the code, and the repo is clean for release. Scope: tracked file modes, `patches/cellular_storage/etc/ModemManager/fcc-unlock.d/`, `CHANGES_AUDIT.md`, `tools/d330-*` dead code/resource handling, unused deployables, `packaging/*`, `.desktop` files, `README.md`, plus a new `scripts/test_doc_parity.sh` guard.
</domain>

<decisions>
- **N1 modes**: `git update-index --chmod=+x` every `scripts/*.sh` and `tools/*.sh` (explicit index mode change works despite `core.fileMode=false`), commit so they are tracked `100755`.
- **N2 FCC hook**: the repo cannot store a colon filename on Windows. Keep the source hook named `patches/cellular_storage/etc/ModemManager/fcc-unlock.d/8086` (real upstream CC0 content + `+x`) and have `install_dkms.sh` deploy/rename it to the ModemManager-expected `/etc/ModemManager/fcc-unlock.d/8086:7360` (a target-side colon path is fine); update the manifest accordingly. Ensure uninstall removes the `:7360` target and the manifest `--verify` tracks it.
- **M17 doc parity**: reconcile each listed contradiction against the code (select exact current values), including `enable_fbc`, `panel_orientation`, zram swappiness/BFQ, `touch-mode`, §4.5 PWM, earlyoom `code`, §5.4 FCC, §7.2 PL2 window, §7.3 `--avoid`, §7.6 wireless, §7.8 tray, §9 test count (==27), and the `power_cycle_delay_ms` 500/600 mismatch (pick the value in the C source).
- **N4 dead code**: remove `SW_LID` (`tools/d330-tablet-daemon.py:26`), unused `dev` (`lenovo-d330-wifi-resume.sh:15`), discarded `lsmod | grep` (`lenovo-d330-touchscreen-resume.sh:44`), the `except ... as e: return None` shadow (`tools/d330-ctl:35`), and the empty loop (already gone from tablet-daemon per Phase 36 — verify).
- **N5 resources**: close the `open()` handles / use context managers in `tools/d330-auto-hibernate.py:30-31` and `:48` (check `subprocess.run` return), and `tools/d330-backlight-pwm.py` read helpers; no leaked FDs.
- **Unused deployables**: deploy `tools/d330-acpi-override.sh` and `tools/d330-pen-config.sh` (add to the installer tool list + CHANGES_AUDIT §8.1) OR document them dev-only; document `patches/acpi_override/dsdt_override.asl` as a dev artifact (never compiled; `51-...cfg` guarded on `/boot/acpi-override.cpio`).
- **N9 packaging**: remove `|| true` around every `cp` in `packaging/debian/rules`, `packaging/arch/PKGBUILD`, `packaging/rpm/lenovo-d330-fix.spec` so a missing source fails the build; add a `prepare()` to `PKGBUILD` for the kernel patch `docs/DISTRO_INSTALL_GUIDE.md:51` references (or correct the doc).
- **Optional runtime deps**: declare `thermald`, `earlyoom`, `zram-generator`, `rnnoise-ladspa`/`ladspa-rnnoise`, `vainfo`, `gsettings`/desktop deps in `packaging/debian/control`, `PKGBUILD`, spec.
- **N7 .desktop hygiene**: replace `Icon=preferences-system` and drop the redundant `X-GNOME-Autostart-enabled` in the tray `.desktop`.
- **README tree**: update `README.md:94-117` to include `docs/DISTRO_INSTALL_GUIDE.md`, `.github/`, `packaging/`, and the test scripts; note the harness trust work (no longer "always pass").
- **SC1 guard**: new `scripts/test_doc_parity.sh` asserts the corrected claims (swappiness=180, `mq-deadline`, enable_fbc=0, panel_orientation present, 27 test scripts, no "1000 Hz PWM boot service", no "GTK3 tray", no "iwlwifi" wireless claim etc.) so doc drift fails CI.
- **the agent's Discretion**: exact wording, per-section decisions where the code is authoritative.
</decisions>

<code_context>
- `README.md:64,83` and usage banners say `sudo ./scripts/install_dkms.sh` while the scripts are mode `100644`.
- `patches/cellular_storage/etc/ModemManager/fcc-unlock.d/8086` tracked as empty blob; `install_dkms.sh:149-151` looks for `8086:7360`.
- `CHANGES_AUDIT.md` contradictions (see decisions). `tools/lenovo_d330_fix.c:10` power_cycle_delay_ms vs §2.1.
- Dead code + resource-handling locations listed in decisions.
- `packaging/*` `cp ... || true`; missing `prepare()`; missing deps.
- SC2 (real package build fails on a broken copy) is host-bound (no dpkg/makepkg/rpmbuild here) -> override; machine half = static assert no `|| true` around `cp` + a broken-source mutation of a rules fragment.
</code_context>

<canonical_refs>
- `.planning/ROADMAP.md` `### Phase 42:` (goal, SC1-3, full component list with file:line, Audit M17/N1–N5/N7/N9/N10)
- `.planning/phases/41-test-harness-trustworthiness/41-01-PLAN.md` (guard-suite + mutation pattern)
</canonical_refs>

<deferred>
- Real `dpkg-buildpackage`/`makepkg`/`rpmbuild` runs; publishing corrected docs.
</deferred>
