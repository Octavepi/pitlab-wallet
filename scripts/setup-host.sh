#!/bin/bash

# Pi-Trezor Host Setup Script
# Installs required dependencies for building the Pi-Trezor appliance.
# This script is intended for Debian/Ubuntu-based systems.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root or with sudo."
   exit 1
fi

# Check if running on a supported system
if ! command -v apt-get &> /dev/null; then
    log_warn "This script is designed for Debian/Ubuntu systems."
    log_warn "Please install the following packages manually for your distribution:"
    log_warn "  build-essential, golang-go, protobuf-compiler, libusb-1.0-0-dev,"
    log_warn "  libudev-dev, libhidapi-dev, gcc-aarch64-linux-gnu, gcc-arm-linux-gnueabihf,"
    log_warn "  rsync, qemu-user-static, git, wget, cpio, unzip, bc, device-tree-compiler,"
    log_warn "  python3, python3-pip, libisl-dev"
    read -p "Continue assuming dependencies are installed? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    log_step "Updating package lists..."
    apt-get update

    log_step "Installing host dependencies..."
    apt-get install -y \
        build-essential \
        golang-go \
        protobuf-compiler \
        libusb-1.0-0-dev \
        libudev-dev \
        libhidapi-dev \
        gcc-aarch64-linux-gnu \
        gcc-arm-linux-gnueabihf \
        rsync \
        qemu-user-static \
        git \
        wget \
        cpio \
        unzip \
        bc \
        device-tree-compiler \
        python3 \
        python3-pip \
        libisl-dev
fi

log_info "Host dependency installation complete."
log_info "You can now run the main build script: ./build_pi-trezor.sh"
