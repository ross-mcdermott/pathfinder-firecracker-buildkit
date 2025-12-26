#!/bin/bash
set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOWNLOADS_DIR="${SCRIPT_DIR}/downloads"
VM_STATE_DIR="${SCRIPT_DIR}/vm-state"
FIRECRACKER_VERSION="v1.7.0"
FIRECRACKER_MAJOR_VERSION="v1.7"
KERNEL_VERSION="5.10"

# URLs
FIRECRACKER_URL="https://github.com/firecracker-microvm/firecracker/releases/download/${FIRECRACKER_VERSION}/firecracker-${FIRECRACKER_VERSION}-x86_64.tgz"
KERNEL_URL="https://s3.amazonaws.com/spec.ccfc.min/firecracker-ci/${FIRECRACKER_MAJOR_VERSION}/${KERNEL_VERSION}/x86_64/vmlinux-${KERNEL_VERSION}.bin"

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    log "Checking system requirements..."
    
    # Check if running on Linux
    if [[ "$(uname)" != "Linux" ]]; then
        log_error "This script must be run on Linux"
        exit 1
    fi
    
    # Check for KVM support
    if [[ ! -e /dev/kvm ]]; then
        log_error "/dev/kvm not found. Make sure KVM is enabled."
        log_error "You may need to run: sudo modprobe kvm kvm_intel (or kvm_amd)"
        exit 1
    fi
    
    # Check if user has access to /dev/kvm
    if [[ ! -r /dev/kvm ]] || [[ ! -w /dev/kvm ]]; then
        log_error "No read/write access to /dev/kvm"
        log_error "You may need to add your user to the kvm group: sudo usermod -aG kvm \$USER"
        exit 1
    fi
    
    # Check for required tools
    for tool in curl tar gzip mkfs.ext4 dd; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Required tool '$tool' not found"
            exit 1
        fi
    done
    
    log "All requirements met"
}

setup_directories() {
    log "Setting up directories..."
    mkdir -p "${DOWNLOADS_DIR}"
    mkdir -p "${VM_STATE_DIR}"
}

download_firecracker() {
    local firecracker_bin="${DOWNLOADS_DIR}/firecracker"
    
    if [[ -f "${firecracker_bin}" ]]; then
        log "Firecracker binary already exists"
        return 0
    fi
    
    log "Downloading Firecracker ${FIRECRACKER_VERSION}..."
    local temp_file="${DOWNLOADS_DIR}/firecracker.tgz"
    
    curl -L -o "${temp_file}" "${FIRECRACKER_URL}"
    
    log "Extracting Firecracker..."
    tar -xzf "${temp_file}" -C "${DOWNLOADS_DIR}"
    
    # Find and move the firecracker binary
    find "${DOWNLOADS_DIR}" -name "firecracker-${FIRECRACKER_VERSION}-x86_64" -exec mv {} "${firecracker_bin}" \;
    chmod +x "${firecracker_bin}"
    
    rm -f "${temp_file}"
    log "Firecracker downloaded successfully"
}

download_kernel() {
    local kernel_file="${DOWNLOADS_DIR}/vmlinux.bin"
    
    if [[ -f "${kernel_file}" ]]; then
        log "Kernel image already exists"
        return 0
    fi
    
    log "Downloading kernel ${KERNEL_VERSION}..."
    curl -L -o "${kernel_file}" "${KERNEL_URL}"
    log "Kernel downloaded successfully"
}

create_rootfs() {
    local rootfs_file="${DOWNLOADS_DIR}/rootfs.ext4"
    
    if [[ -f "${rootfs_file}" ]]; then
        log "Rootfs already exists"
        return 0
    fi
    
    log "Creating rootfs with buildkit..."
    
    # Create a 512MB sparse file (sufficient for demo purposes)
    dd if=/dev/zero of="${rootfs_file}" bs=1M count=0 seek=512
    
    # Create ext4 filesystem
    mkfs.ext4 -F "${rootfs_file}"
    
    # Mount the filesystem
    local mount_point="${DOWNLOADS_DIR}/rootfs_mount"
    mkdir -p "${mount_point}"
    
    sudo mount -o loop "${rootfs_file}" "${mount_point}"
    
    # Create basic directory structure
    log "Setting up rootfs structure..."
    sudo mkdir -p "${mount_point}"/{bin,sbin,etc,proc,sys,dev,tmp,var,root,usr/bin,usr/sbin}
    
    # Copy essential binaries from host (Alpine-like minimal system)
    log "Copying essential binaries..."
    
    # We'll use busybox for a minimal system
    if command -v busybox &> /dev/null; then
        sudo cp "$(which busybox)" "${mount_point}/bin/"
        
        # Create busybox symlinks
        for cmd in sh ash ls cp mv rm mkdir rmdir cat echo mount umount chmod chown ln ps kill sleep; do
            sudo ln -sf /bin/busybox "${mount_point}/bin/${cmd}"
        done
    else
        log_warn "Busybox not found, using alternative approach..."
        # Copy basic utilities
        for cmd in /bin/bash /bin/sh /bin/ls /bin/cat /bin/echo /bin/mkdir /bin/rm; do
            if [[ -f "$cmd" ]]; then
                sudo cp -L "$cmd" "${mount_point}/bin/"
            fi
        done
    fi
    
    # Create init script
    log "Creating init script..."
    sudo tee "${mount_point}/init" > /dev/null << 'INITSCRIPT'
#!/bin/sh

# Mount essential filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev

# Print startup message
echo "====================================="
echo "Firecracker VM with BuildKit"
echo "====================================="

# Check if buildkitd exists
if [ -f /usr/bin/buildkitd ]; then
    echo "Starting buildkitd..."
    /usr/bin/buildkitd --addr unix:///run/buildkit/buildkitd.sock &
    BUILDKIT_PID=$!
    
    # Wait for buildkit to be ready
    sleep 5
    
    echo "BuildKit started with PID $BUILDKIT_PID"
    echo "Ready to build containers!"
else
    echo "BuildKit not found in this rootfs"
    echo "This is a minimal demonstration VM"
fi

# Keep the VM running
echo "VM is running. This demo VM will sleep..."
sleep infinity
INITSCRIPT
    
    sudo chmod +x "${mount_point}/init"
    
    # Create a simple inittab for demonstration
    sudo tee "${mount_point}/etc/inittab" > /dev/null << 'EOF'
::sysinit:/init
EOF
    
    # Unmount
    sudo umount "${mount_point}"
    rmdir "${mount_point}"
    
    log "Rootfs created successfully"
}

create_vm_config() {
    local config_file="${VM_STATE_DIR}/vm-config.json"
    local socket_path="${VM_STATE_DIR}/firecracker.sock"
    
    log "Creating VM configuration..."
    
    cat > "${config_file}" << EOF
{
  "boot-source": {
    "kernel_image_path": "${DOWNLOADS_DIR}/vmlinux.bin",
    "boot_args": "console=ttyS0 reboot=k panic=1 pci=off init=/init"
  },
  "drives": [
    {
      "drive_id": "rootfs",
      "path_on_host": "${DOWNLOADS_DIR}/rootfs.ext4",
      "is_root_device": true,
      "is_read_only": false
    }
  ],
  "machine-config": {
    "vcpu_count": 2,
    "mem_size_mib": 1024,
    "ht_enabled": false
  },
  "network-interfaces": []
}
EOF
    
    log "VM configuration created at ${config_file}"
    echo "${config_file}"
}

start_firecracker_vm() {
    local firecracker_bin="${DOWNLOADS_DIR}/firecracker"
    local socket_path="${VM_STATE_DIR}/firecracker.sock"
    local config_file="$1"
    local log_file="${VM_STATE_DIR}/firecracker.log"
    
    # Clean up old socket if exists
    rm -f "${socket_path}"
    
    log "Starting Firecracker VM..."
    log "Log file: ${log_file}"
    
    # Start Firecracker in the background
    "${firecracker_bin}" \
        --api-sock "${socket_path}" \
        --config-file "${config_file}" \
        > "${log_file}" 2>&1 &
    
    local fc_pid=$!
    echo "${fc_pid}" > "${VM_STATE_DIR}/firecracker.pid"
    
    log "Firecracker started with PID ${fc_pid}"
    log "VM is booting... (this may take a few seconds)"
    
    # Wait a bit for the VM to boot
    sleep 10
    
    # Check if still running
    if ! kill -0 "${fc_pid}" 2>/dev/null; then
        log_error "Firecracker process died. Check ${log_file} for details"
        cat "${log_file}"
        exit 1
    fi
    
    log "VM is running!"
    log ""
    log "To see VM output: tail -f ${log_file}"
    log "To stop VM: kill ${fc_pid}"
    
    return 0
}

build_sample_dockerfile() {
    log ""
    log "====================================="
    log "Build Demonstration"
    log "====================================="
    log ""
    log "In a full implementation, buildkit would be running inside the VM"
    log "and we would use 'buildctl' to submit the build job."
    log ""
    log "Sample Dockerfile location: ${SCRIPT_DIR}/sample/Dockerfile"
    log ""
    log "The Dockerfile would be built inside the Firecracker VM using:"
    log "  buildctl build --frontend dockerfile.v0 --local context=. --local dockerfile=."
    log ""
}

cleanup() {
    log ""
    log "Cleaning up..."
    
    if [[ -f "${VM_STATE_DIR}/firecracker.pid" ]]; then
        local pid=$(cat "${VM_STATE_DIR}/firecracker.pid")
        if kill -0 "${pid}" 2>/dev/null; then
            log "Stopping Firecracker VM (PID ${pid})..."
            kill "${pid}" 2>/dev/null || true
            sleep 2
            kill -9 "${pid}" 2>/dev/null || true
        fi
        rm -f "${VM_STATE_DIR}/firecracker.pid"
    fi
    
    rm -f "${VM_STATE_DIR}/firecracker.sock"
}

main() {
    log "====================================="
    log "Firecracker + BuildKit Sample"
    log "====================================="
    log ""
    
    # Set trap to cleanup on exit
    trap cleanup EXIT INT TERM
    
    # Check system requirements
    check_requirements
    
    # Setup directories
    setup_directories
    
    # Download required components
    download_firecracker
    download_kernel
    
    # Create rootfs
    create_rootfs
    
    # Create VM configuration
    config_file=$(create_vm_config)
    
    # Start Firecracker VM
    start_firecracker_vm "${config_file}"
    
    # Show build information
    build_sample_dockerfile
    
    # Keep running to show VM output
    log ""
    log "Press Ctrl+C to stop the VM and exit"
    log ""
    
    # Wait and show logs
    sleep 5
    if [[ -f "${VM_STATE_DIR}/firecracker.log" ]]; then
        log "VM output:"
        tail -f "${VM_STATE_DIR}/firecracker.log"
    else
        log "Waiting... VM is running"
        sleep infinity
    fi
}

# Run main function
main "$@"
