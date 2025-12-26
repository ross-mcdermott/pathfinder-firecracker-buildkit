# Pathfinder Firecracker BuildKit

A sample implementation demonstrating how to run BuildKit inside a Firecracker microVM to build Docker containers.

## Overview

This project provides a complete example of running BuildKit (Docker's next-generation builder) within a Firecracker microVM. Firecracker is a lightweight virtualization technology that enables secure, fast, and efficient execution of containerized workloads.

## Features

- **Automated Setup**: Single script execution handles all dependencies
- **Firecracker Integration**: Runs BuildKit in an isolated microVM
- **Sample Dockerfile**: Includes a simple example to build
- **End-to-End Demo**: Complete workflow from VM setup to container build

## Prerequisites

### System Requirements

- **Linux OS**: This must run on a Linux system (tested on Ubuntu)
- **KVM Support**: Hardware virtualization must be enabled
  ```bash
  # Check if KVM is available
  ls /dev/kvm
  
  # Enable KVM modules if needed
  sudo modprobe kvm kvm_intel  # For Intel CPUs
  # OR
  sudo modprobe kvm kvm_amd    # For AMD CPUs
  ```
- **User Permissions**: Your user must have access to `/dev/kvm`
  ```bash
  # Add your user to the kvm group
  sudo usermod -aG kvm $USER
  # Log out and log back in for changes to take effect
  ```

### Required Tools

The following tools must be installed on your system:

- `curl` - For downloading components
- `tar` and `gzip` - For extracting archives
- `mkfs.ext4` - For creating filesystem (usually in `e2fsprogs` package)
- `dd` - For creating disk images
- `sudo` - For mounting filesystems during rootfs creation

On Ubuntu/Debian:
```bash
sudo apt-get update
sudo apt-get install -y curl tar gzip e2fsprogs
```

## Quick Start

### Basic Demo (No BuildKit binaries)

1. **Clone the repository**:
   ```bash
   git clone https://github.com/ross-mcdermott/pathfinder-firecracker-buildkit.git
   cd pathfinder-firecracker-buildkit
   ```

2. **Check your system** (optional but recommended):
   ```bash
   ./check-system.sh
   ```
   This script verifies that your system meets all requirements.

3. **Run the sample**:
   ```bash
   ./run-sample.sh
   ```

4. **Stop the VM**:
   Press `Ctrl+C` to stop the Firecracker VM and exit

### Full Setup with BuildKit (For End-to-End Builds)

To perform actual container builds, you need to add BuildKit binaries:

1. **Download BuildKit binaries**:
   ```bash
   ./setup-buildkit.sh
   ```
   This downloads and extracts BuildKit v0.12.5 binaries.

2. **Run the enhanced sample**:
   ```bash
   ./run-sample.sh
   ```
   The script will automatically detect and include BuildKit in the VM.

3. **Configure networking** (for pulling base images):
   See the "Adding BuildKit for End-to-End Container Builds" section below for detailed networking setup.

## What the Script Does

The `run-sample.sh` script performs the following steps:

1. **Checks Requirements**: Verifies that the system has KVM support and required tools
2. **Downloads Firecracker**: Fetches the Firecracker binary (v1.7.0)
3. **Downloads Kernel**: Fetches a compatible Linux kernel for the VM
4. **Creates Rootfs**: Builds a minimal root filesystem with basic utilities
5. **Adds BuildKit** (if available): Includes BuildKit binaries and dependencies
6. **Configures VM**: Creates a Firecracker configuration file
7. **Starts VM**: Launches the Firecracker microVM
8. **Demonstrates Build**: Shows how BuildKit would be used inside the VM

## Project Structure

```
.
├── run-sample.sh          # Main execution script
├── setup-buildkit.sh      # BuildKit download helper
├── check-system.sh        # System requirements checker
├── example-build.sh       # Build workflow documentation
├── sample/
│   └── Dockerfile        # Sample Dockerfile to build
├── downloads/            # Downloaded components (created by script)
│   ├── firecracker       # Firecracker binary
│   ├── vmlinux.bin      # Linux kernel
│   └── rootfs.ext4      # Root filesystem
├── bin/                  # BuildKit binaries (created by setup-buildkit.sh)
│   ├── buildkitd         # BuildKit daemon
│   └── buildctl          # BuildKit client
├── vm-state/            # VM runtime state (created by script)
│   ├── firecracker.sock # API socket
│   ├── firecracker.log  # VM output log
│   └── vm-config.json   # VM configuration
└── README.md            # This file
```

## Sample Dockerfile

The included sample Dockerfile (`sample/Dockerfile`) creates a simple Alpine-based container:

```dockerfile
FROM alpine:3.19

RUN apk add --no-cache curl bash git

RUN echo '#!/bin/sh' > /app.sh && \
    echo 'echo "Hello from a container built by BuildKit in Firecracker!"' >> /app.sh && \
    chmod +x /app.sh

ENTRYPOINT ["/app.sh"]
```

## Architecture

```
┌─────────────────────────────────────────┐
│         Host Linux System               │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │   Firecracker MicroVM             │ │
│  │                                   │ │
│  │  ┌─────────────────────────────┐ │ │
│  │  │      BuildKit Daemon        │ │ │
│  │  │                             │ │ │
│  │  │  • Receives build requests  │ │ │
│  │  │  • Processes Dockerfile     │ │ │
│  │  │  • Builds container image   │ │ │
│  │  └─────────────────────────────┘ │ │
│  │                                   │ │
│  └───────────────────────────────────┘ │
│                                         │
│         run-sample.sh                   │
└─────────────────────────────────────────┘
```

## How It Works

### Firecracker MicroVM

Firecracker is a virtual machine monitor (VMM) that uses Linux's Kernel-based Virtual Machine (KVM) to create and manage lightweight VMs called microVMs. Key features:

- **Fast**: Boots in ~125ms
- **Secure**: Strong workload isolation
- **Lightweight**: Minimal memory footprint
- **Efficient**: Designed for serverless and container workloads

### BuildKit Integration

BuildKit is Docker's next-generation build system. Running it in Firecracker provides:

- **Isolation**: Each build runs in its own VM
- **Security**: Strong isolation between builds
- **Efficiency**: Fast VM startup enables quick build iterations
- **Scalability**: Easy to parallelize builds across VMs

### Build Process Flow

In a full implementation, the build process would work as follows:

1. **VM Preparation**: Firecracker VM boots with BuildKit daemon
2. **Build Submission**: Client submits Dockerfile via `buildctl`
3. **Build Execution**: BuildKit processes the Dockerfile inside VM
4. **Image Export**: Built image is exported from the VM
5. **Cleanup**: VM can be terminated after build completes

## Customization

### Modifying VM Resources

Edit the VM configuration in `run-sample.sh`:

```bash
# In create_vm_config() function
"vcpu_count": 2,           # Number of vCPUs
"mem_size_mib": 1024,      # Memory in MiB
```

### Using Different Kernel or Firecracker Versions

Update the version variables at the top of `run-sample.sh`:

```bash
FIRECRACKER_VERSION="v1.7.0"
KERNEL_VERSION="5.10"
```

### Building Your Own Dockerfile

Replace `sample/Dockerfile` with your own Dockerfile. The script is designed to work with any valid Dockerfile.

## Troubleshooting

### KVM Not Available

**Error**: `/dev/kvm not found`

**Solution**: Enable KVM modules:
```bash
sudo modprobe kvm kvm_intel  # Intel
# OR
sudo modprobe kvm kvm_amd    # AMD
```

### Permission Denied on /dev/kvm

**Error**: `No read/write access to /dev/kvm`

**Solution**: Add your user to the kvm group:
```bash
sudo usermod -aG kvm $USER
```
Then log out and log back in.

### VM Fails to Start

**Solution**: Check the Firecracker log file:
```bash
cat vm-state/firecracker.log
```

### Filesystem Creation Fails

**Error**: `mkfs.ext4: command not found`

**Solution**: Install e2fsprogs:
```bash
sudo apt-get install e2fsprogs
```

## Limitations

This is a **demonstration** implementation with the following limitations:

1. **Minimal Rootfs**: The root filesystem is very basic and doesn't include a full BuildKit installation
2. **No Network**: The VM doesn't have network connectivity configured
3. **No BuildKit**: BuildKit binaries are not included in the rootfs (would need to be added for full functionality)
4. **No Build Control**: The script doesn't implement the `buildctl` client to control builds

For a production implementation, you would need to:

- Build a complete rootfs with BuildKit and all dependencies
- Configure VM networking for image pulls/pushes
- Implement a client to communicate with BuildKit via the API
- Add proper error handling and recovery
- Implement image export mechanisms

## Adding BuildKit for End-to-End Container Builds

To extend this demo to perform actual container builds, you need to add BuildKit binaries to the rootfs and configure networking. Here's a complete guide:

### Step 1: Download BuildKit Binaries

BuildKit is available from the official GitHub releases:

```bash
# Set BuildKit version
BUILDKIT_VERSION="v0.12.5"

# Download BuildKit binaries
curl -L -o buildkit.tar.gz \
  "https://github.com/moby/buildkit/releases/download/${BUILDKIT_VERSION}/buildkit-${BUILDKIT_VERSION}.linux-amd64.tar.gz"

# Extract binaries
tar -xzf buildkit.tar.gz
# This creates a 'bin' directory with: buildkitd, buildctl
```

The key binaries you need are:
- **`buildkitd`**: The BuildKit daemon (runs in the VM)
- **`buildctl`**: The BuildKit client (runs on the host)

### Step 2: Modify `run-sample.sh` to Include BuildKit

Add BuildKit binaries to the rootfs by modifying the `create_rootfs()` function in `run-sample.sh`. After the section that copies busybox (around line 175), add:

```bash
# Copy BuildKit binaries if available
log "Adding BuildKit binaries..."
if [[ -f "${SCRIPT_DIR}/bin/buildkitd" ]] && [[ -f "${SCRIPT_DIR}/bin/buildctl" ]]; then
    sudo cp "${SCRIPT_DIR}/bin/buildkitd" "${mount_point}/usr/bin/"
    sudo cp "${SCRIPT_DIR}/bin/buildctl" "${mount_point}/usr/bin/"
    sudo chmod +x "${mount_point}/usr/bin/buildkitd"
    sudo chmod +x "${mount_point}/usr/bin/buildctl"
    
    # Copy required libraries (BuildKit needs these)
    sudo mkdir -p "${mount_point}/lib" "${mount_point}/lib64"
    
    # Copy essential shared libraries from host
    for lib in /lib/x86_64-linux-gnu/libc.so.6 \
               /lib/x86_64-linux-gnu/libpthread.so.0 \
               /lib/x86_64-linux-gnu/libdl.so.2 \
               /lib64/ld-linux-x86-64.so.2; do
        if [[ -f "$lib" ]]; then
            sudo cp -L "$lib" "${mount_point}/lib/"
        fi
    done
    
    # Create BuildKit directories
    sudo mkdir -p "${mount_point}/var/lib/buildkit"
    sudo mkdir -p "${mount_point}/run/buildkit"
    
    log "BuildKit binaries added successfully"
else
    log_warn "BuildKit binaries not found in ${SCRIPT_DIR}/bin/"
    log_warn "Download from: https://github.com/moby/buildkit/releases"
fi
```

### Step 3: Configure VM Networking

To allow the VM to pull base images, add networking to the Firecracker configuration. Modify the `create_vm_config()` function to include a network interface:

```bash
# Add after the VM configuration
cat > "${config_file}" << EOF
{
  "boot-source": {
    "kernel_image_path": "${DOWNLOADS_DIR}/vmlinux.bin",
    "boot_args": "console=ttyS0 reboot=k panic=1 pci=off init=/init ip=172.16.0.2::172.16.0.1:255.255.255.0::eth0:off"
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
    "mem_size_mib": 2048,
    "ht_enabled": false
  },
  "network-interfaces": [
    {
      "iface_id": "eth0",
      "guest_mac": "AA:FC:00:00:00:01",
      "host_dev_name": "tap0"
    }
  ]
}
EOF
```

Before starting Firecracker, set up the TAP device:

```bash
# Create TAP device (add this before starting Firecracker)
sudo ip tuntap add tap0 mode tap
sudo ip addr add 172.16.0.1/24 dev tap0
sudo ip link set tap0 up

# Enable IP forwarding and NAT (for internet access)
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i tap0 -o eth0 -j ACCEPT
```

### Step 4: Update the Init Script

The init script needs to properly configure networking and start BuildKit with correct options. Update the init script in `create_rootfs()`:

```bash
sudo tee "${mount_point}/init" > /dev/null << 'INITSCRIPT'
#!/bin/sh

# Mount essential filesystems
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devtmpfs none /dev
mount -t tmpfs none /tmp

# Configure network interface
ip link set eth0 up
ip addr add 172.16.0.2/24 dev eth0
ip route add default via 172.16.0.1

# Set DNS (using Google DNS)
echo "nameserver 8.8.8.8" > /etc/resolv.conf

echo "====================================="
echo "Firecracker VM with BuildKit"
echo "====================================="
echo "Network: 172.16.0.2"
echo "Gateway: 172.16.0.1"

# Check if buildkitd exists
if [ -f /usr/bin/buildkitd ]; then
    echo "Starting buildkitd..."
    mkdir -p /run/buildkit
    mkdir -p /var/lib/buildkit
    
    # Start buildkitd in the background
    /usr/bin/buildkitd \
        --addr unix:///run/buildkit/buildkitd.sock \
        --root /var/lib/buildkit \
        --oci-worker-no-process-sandbox \
        > /tmp/buildkitd.log 2>&1 &
    
    BUILDKIT_PID=$!
    echo "BuildKit started with PID $BUILDKIT_PID"
    
    # Wait for buildkit to be ready
    sleep 3
    
    if kill -0 $BUILDKIT_PID 2>/dev/null; then
        echo "BuildKit is ready!"
    else
        echo "BuildKit failed to start. Check /tmp/buildkitd.log"
        cat /tmp/buildkitd.log
    fi
else
    echo "BuildKit not found - this is a minimal demo VM"
fi

# Keep the VM running
echo "VM is running. Use buildctl from host to build containers."
sleep infinity
INITSCRIPT
```

### Step 5: Build a Container End-to-End

Once the VM is running with BuildKit installed, you can build containers from your host:

#### A. Using the VM's Unix Socket (via SSH or shared mount)

If you expose the BuildKit socket to the host (via virtio-vsock or shared directory), you can use `buildctl` directly:

```bash
# From the host machine
export BUILDKIT_HOST=unix:///path/to/shared/buildkitd.sock

# Build the sample Dockerfile
buildctl build \
    --frontend dockerfile.v0 \
    --local context=./sample \
    --local dockerfile=./sample \
    --output type=image,name=docker.io/library/sample-app:latest,push=false \
    --export-cache type=inline \
    --import-cache type=registry,ref=docker.io/library/sample-app:latest
```

#### B. Using Firecracker's API Socket

For a more integrated approach, you can communicate with BuildKit inside the VM by:

1. **Exec into the VM** (requires modifications to expose a shell)
2. **Use virtio-vsock** to create a socket bridge
3. **SSH into the VM** (requires SSH server in rootfs)

Example with direct socket access (if you mount the socket directory):

```bash
# Copy the Dockerfile into the VM via a shared volume or API
# Then run buildctl inside the VM

# Build command (run inside VM or via socket)
buildctl build \
    --frontend dockerfile.v0 \
    --local context=/path/to/context \
    --local dockerfile=/path/to/context \
    --output type=docker,name=sample-app:latest,dest=/tmp/sample-app.tar

# Export the image
docker load < /tmp/sample-app.tar
```

### Step 6: Complete Working Script

Here's a complete helper script to set up everything:

Create `setup-buildkit.sh`:

```bash
#!/bin/bash
set -e

BUILDKIT_VERSION="v0.12.5"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Downloading BuildKit ${BUILDKIT_VERSION}..."
curl -L -o "${SCRIPT_DIR}/buildkit.tar.gz" \
  "https://github.com/moby/buildkit/releases/download/${BUILDKIT_VERSION}/buildkit-${BUILDKIT_VERSION}.linux-amd64.tar.gz"

echo "Extracting BuildKit binaries..."
tar -xzf "${SCRIPT_DIR}/buildkit.tar.gz" -C "${SCRIPT_DIR}"

echo "BuildKit binaries ready in ${SCRIPT_DIR}/bin/"
ls -lh "${SCRIPT_DIR}/bin/"

echo ""
echo "Next steps:"
echo "1. Modify run-sample.sh to include BuildKit binaries (see README)"
echo "2. Configure VM networking (see README)"
echo "3. Run ./run-sample.sh to start the VM"
echo "4. Use buildctl to build containers"
```

### Testing Your Setup

1. **Download BuildKit**: Run the `setup-buildkit.sh` script
2. **Modify run-sample.sh**: Add the BuildKit installation code
3. **Configure networking**: Add TAP device setup
4. **Start the VM**: `./run-sample.sh`
5. **Verify BuildKit is running**: Check the VM logs for "BuildKit is ready!"
6. **Build a container**: Use `buildctl` to submit a build

### Troubleshooting BuildKit

**BuildKit fails to start:**
- Check `/tmp/buildkitd.log` inside the VM
- Ensure all required libraries are copied
- Verify network connectivity: `ping 8.8.8.8` from inside VM

**Cannot connect to BuildKit socket:**
- Verify the socket exists: `ls -l /run/buildkit/buildkitd.sock`
- Check BuildKit is running: `ps aux | grep buildkitd`

**Build fails to pull images:**
- Verify network configuration: `ip addr` and `ip route` in VM
- Test DNS: `nslookup google.com` from inside VM
- Check NAT/firewall rules on host

## Future Enhancements

Potential improvements for this sample:

- [ ] Include full BuildKit installation in rootfs
- [ ] Add VM networking configuration
- [ ] Implement `buildctl` integration
- [ ] Add support for exporting built images
- [ ] Create pre-built rootfs images
- [ ] Add multi-stage build examples
- [ ] Implement build caching strategies
- [ ] Add performance benchmarking
- [ ] Support for custom registries

## Resources

- [Firecracker Documentation](https://github.com/firecracker-microvm/firecracker/blob/main/docs/getting-started.md)
- [BuildKit Documentation](https://github.com/moby/buildkit)
- [KVM Documentation](https://www.linux-kvm.org/page/Documents)

## License

This is a sample project for demonstration purposes.

## Contributing

This is a sample/demonstration project. For questions or issues, please open a GitHub issue.