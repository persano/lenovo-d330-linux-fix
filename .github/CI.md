# GitHub Actions CI/CD for Lenovo IdeaPad D330-10IGL

Contains automated build and release workflows:
- `workflows/build-packages.yml`: builds the Debian (`.deb`), RPM (`.rpm`) and
  Arch Linux (`pkg.tar.zst`) packages plus the DKMS source tarball, and
  publishes them all as a GitHub release on a `v*` tag push. Also runnable
  manually via `workflow_dispatch`.
- `workflows/build-iso.yml`: builds a remastered bootable Live ISO image
  (manual dispatch).

The project README lives at the repository root (`README.md`).
