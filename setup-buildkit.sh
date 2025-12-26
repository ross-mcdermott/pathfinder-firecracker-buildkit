#!/bin/bash
set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

BUILDKIT_VERSION="v0.12.5"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "=============================================="
echo "BuildKit Setup for Firecracker"
echo "=============================================="
echo ""

# Check if already downloaded
if [[ -d "${SCRIPT_DIR}/bin" ]] && [[ -f "${SCRIPT_DIR}/bin/buildkitd" ]]; then
    log "BuildKit binaries already exist in ${SCRIPT_DIR}/bin/"
    log "To re-download, delete the bin/ directory first"
    echo ""
    ls -lh "${SCRIPT_DIR}/bin/"
    exit 0
fi

log "Downloading BuildKit ${BUILDKIT_VERSION}..."
if ! curl -fL -o "${SCRIPT_DIR}/buildkit.tar.gz" \
  "https://github.com/moby/buildkit/releases/download/${BUILDKIT_VERSION}/buildkit-${BUILDKIT_VERSION}.linux-amd64.tar.gz"; then
    log_error "Failed to download BuildKit"
    exit 1
fi

log "Extracting BuildKit binaries..."
if ! tar -xzf "${SCRIPT_DIR}/buildkit.tar.gz" -C "${SCRIPT_DIR}"; then
    log_error "Failed to extract BuildKit archive"
    exit 1
fi

# Clean up archive
rm -f "${SCRIPT_DIR}/buildkit.tar.gz"

log "BuildKit binaries ready in ${SCRIPT_DIR}/bin/"
echo ""
ls -lh "${SCRIPT_DIR}/bin/"

echo ""
echo "=============================================="
log "BuildKit downloaded successfully!"
echo "=============================================="
echo ""
echo "The following binaries are now available:"
echo "  - buildkitd: BuildKit daemon (for the VM)"
echo "  - buildctl: BuildKit client (for the host)"
echo ""
echo "Next steps to enable end-to-end container builds:"
echo ""
echo "1. The run-sample.sh script will automatically detect and"
echo "   use these binaries when creating the VM rootfs"
echo ""
echo "2. For networking support (required for pulling base images),"
echo "   see the 'Adding BuildKit for End-to-End Container Builds'"
echo "   section in README.md"
echo ""
echo "3. Run: ./run-sample.sh"
echo ""
echo "For detailed instructions, see README.md"

