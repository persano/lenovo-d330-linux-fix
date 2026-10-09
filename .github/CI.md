# GitHub Actions CI/CD for Lenovo IdeaPad D330-10IGL

Contains automated build and release workflows:
- `workflows/build-packages.yml`: builds the Debian (`.deb`), RPM (`.rpm`) and
  Arch Linux (`pkg.tar.zst`) packages plus the DKMS source tarball, and
  publishes them all as a GitHub release on a `v*` tag push. Also runnable
  manually via `workflow_dispatch`.
- `workflows/build-iso.yml`: builds a remastered bootable Live ISO image
  (manual dispatch).
- `workflows/build-kernel.yml`: builds the **patched kernel** `.deb` for one
  specific Ubuntu kernel version in CI (manual dispatch, inputs
  `kernel_version` + `ubuntu_release`), so the tablet never has to compile a
  kernel. Publishes `linux-image-*-d330-fix_*.deb` under a `kernel-<version>`
  release.
- `workflows/lint-workflows.yml`: runs `actionlint` on the workflow files so a
  schema-invalid workflow cannot be merged (a bad one shows up as a failed,
  job-less run named after the file).

The project README lives at the repository root (`README.md`).
