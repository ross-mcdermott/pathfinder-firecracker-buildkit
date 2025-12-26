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

## What the Script Does

The `run-sample.sh` script performs the following steps:

1. **Checks Requirements**: Verifies that the system has KVM support and required tools
2. **Downloads Firecracker**: Fetches the Firecracker binary (v1.7.0)
3. **Downloads Kernel**: Fetches a compatible Linux kernel for the VM
4. **Creates Rootfs**: Builds a minimal root filesystem with basic utilities
5. **Configures VM**: Creates a Firecracker configuration file
6. **Starts VM**: Launches the Firecracker microVM
7. **Demonstrates Build**: Shows how BuildKit would be used inside the VM

## Project Structure

```
.
├── run-sample.sh          # Main execution script
├── check-system.sh        # System requirements checker
├── sample/
│   └── Dockerfile        # Sample Dockerfile to build
├── downloads/            # Downloaded components (created by script)
│   ├── firecracker       # Firecracker binary
│   ├── vmlinux.bin      # Linux kernel
│   └── rootfs.ext4      # Root filesystem
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