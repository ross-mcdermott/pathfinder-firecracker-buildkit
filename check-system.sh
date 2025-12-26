#!/bin/bash
# System readiness checker for Firecracker BuildKit sample

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Firecracker BuildKit - System Check"
echo "=========================================="
echo ""

ERRORS=0
WARNINGS=0

# Check 1: Operating System
echo -n "Checking OS... "
if [[ "$(uname)" == "Linux" ]]; then
    echo -e "${GREEN}✓ Linux${NC}"
else
    echo -e "${RED}✗ Not Linux (found $(uname))${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Check 2: KVM device
echo -n "Checking KVM device... "
if [[ -e /dev/kvm ]]; then
    echo -e "${GREEN}✓ /dev/kvm exists${NC}"
else
    echo -e "${RED}✗ /dev/kvm not found${NC}"
    echo "  Run: sudo modprobe kvm kvm_intel  # or kvm_amd for AMD"
    ERRORS=$((ERRORS + 1))
fi

# Check 3: KVM permissions
echo -n "Checking KVM permissions... "
if [[ -r /dev/kvm ]] && [[ -w /dev/kvm ]]; then
    echo -e "${GREEN}✓ Read/write access to /dev/kvm${NC}"
else
    echo -e "${RED}✗ No read/write access to /dev/kvm${NC}"
    echo "  Run: sudo usermod -aG kvm \$USER"
    echo "  Then log out and log back in"
    ERRORS=$((ERRORS + 1))
fi

# Check 4: Required commands
echo ""
echo "Checking required tools:"
for tool in curl tar gzip mkfs.ext4 dd sudo; do
    echo -n "  - $tool... "
    if command -v "$tool" &> /dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ not found${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check 5: Recommended tools
echo ""
echo "Checking recommended tools:"
for tool in busybox; do
    echo -n "  - $tool... "
    if command -v "$tool" &> /dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠ not found (optional)${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
done

# Check 6: Disk space
echo ""
echo -n "Checking disk space... "
AVAILABLE=$(df . | tail -1 | awk '{print $4}')
REQUIRED=$((2 * 1024 * 1024))  # 2GB in KB
if [[ $AVAILABLE -gt $REQUIRED ]]; then
    echo -e "${GREEN}✓ $(($AVAILABLE / 1024 / 1024))GB available${NC}"
else
    echo -e "${YELLOW}⚠ Only $(($AVAILABLE / 1024 / 1024))GB available, 2GB+ recommended${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# Summary
echo ""
echo "=========================================="
if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓ System is ready!${NC}"
    echo ""
    echo "You can run the sample with:"
    echo "  ./run-sample.sh"
    exit 0
else
    echo -e "${RED}✗ Found $ERRORS error(s)${NC}"
    if [[ $WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}⚠ Found $WARNINGS warning(s)${NC}"
    fi
    echo ""
    echo "Please fix the errors above before running the sample."
    exit 1
fi
