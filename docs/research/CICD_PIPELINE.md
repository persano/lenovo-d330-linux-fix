# Research: GitHub Actions CI/CD Release Pipeline on Lenovo D330-10IGL

## 1. Automated Release Packaging
The repository includes automated CI/CD pipelines defined in `.github/workflows/`:
1. **`build-packages.yml`**:
   - Triggers automatically when a version tag (`v*`) is pushed to git.
   - Builds Debian `.deb` package (`lenovo-d330-fix_5.0.0_all.deb`).
   - Packages the standalone DKMS kernel module into `lenovo-d330-fix-dkms.tar.gz`.
   - Computes cryptographic SHA256 checksums (`SHA256SUMS`).
   - Creates a GitHub Release and attaches the compiled artifacts for direct user download.
2. **`build-iso.yml`**:
   - Manually dispatched via GitHub Actions UI (`workflow_dispatch`).
   - Accepts a base ISO URL parameter (Ubuntu 24.04 LTS, Mint LMDE 6).
   - Runs `scripts/build_live_iso.sh` inside an ephemeral runner.
   - Generates and uploads `lenovo-d330-live-remastered.iso` and its SHA256 checksum.
