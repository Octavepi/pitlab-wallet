#!/bin/bash

# Pi-Trezor Build System - Dynamic Multi-Board & Display Support
# Builds an air-gapped Raspberry Pi wallet appliance with Trezor Core and trezord-go

set -e

# Default values
BOARD="pi4"
DISPLAY="waveshare35a"
ROTATION="180"
ARCH=""
CROSS_COMPILE=""
DEFCONFIG=""
KERNEL_DEFCONFIG=""

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

# Help function
show_help() {
    cat << EOF
Pi-Trezor Build System - Dynamic Multi-Board & Display Support

Usage: $0 [OPTIONS]

Options:
    --board <pi3|pi4|pi5>                 Target Raspberry Pi board (default: pi4)
    --display <display_name>              Display overlay name (default: waveshare35a)
    --rotation <0|90|180|270>            Display rotation angle (default: 180)
    --help                               Show this help message

Supported displays:
    waveshare35a, waveshare32b, hdmi, vc4-kms-v3d, ili9341, ili9486, st7735r, and more
    Note: All Raspberry Pi firmware overlays are supported dynamically

Examples:
    $0 --board pi4 --display waveshare35a --rotation 90
    $0 --board pi5 --display hdmi --rotation 0
    $0 --board pi3 --display ili9341 --rotation 270

The build process will:
1. Install host dependencies
2. Cross-compile trezord-go and Trezor Core
3. Generate Buildroot configuration for the target board
4. Build the complete system image
5. Configure display and rotation settings
6. Output ready-to-flash sdcard.img

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --board)
            BOARD="$2"
            shift 2
            ;;
        --display)
            DISPLAY="$2"
            shift 2
            ;;
        --rotation)
            ROTATION="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate board selection and set build parameters
case $BOARD in
    pi3)
        ARCH="arm"
        CROSS_COMPILE="arm-linux-gnueabihf-"
        DEFCONFIG="raspberrypi3_defconfig"
        KERNEL_DEFCONFIG="bcm2709_defconfig"
        GOARCH="arm"
        GOARM="7"
        ;;
    pi4)
        ARCH="arm64"
        CROSS_COMPILE="aarch64-linux-gnu-"
        DEFCONFIG="raspberrypi4_64_defconfig"
        KERNEL_DEFCONFIG="bcm2711_defconfig"
        GOARCH="arm64"
        ;;
    pi5)
        ARCH="arm64"
        CROSS_COMPILE="aarch64-linux-gnu-"
        DEFCONFIG="raspberrypi5_defconfig"
        KERNEL_DEFCONFIG="bcm2712_defconfig"
        GOARCH="arm64"
        ;;
    *)
        log_error "Unsupported board: $BOARD"
        log_error "Supported boards: pi3, pi4, pi5"
        exit 1
        ;;
esac

# Validate rotation
case $ROTATION in
    0|90|180|270)
        ;;
    *)
        log_error "Invalid rotation: $ROTATION"
        log_error "Supported rotations: 0, 90, 180, 270"
        exit 1
        ;;
esac

log_info "Building Pi-Trezor for $BOARD with $DISPLAY display (rotation: $ROTATION°)"

# Check if we're in the right directory
if [[ ! -f "build_pi-trezor.sh" ]]; then
    log_error "Please run this script from the pi-trezor repository root"
    exit 1
fi

# Install host dependencies
install_host_deps() {
    log_step "Installing host dependencies..."
    
    # Check if running on Ubuntu/Debian
    if ! command -v apt-get &> /dev/null; then
        log_warn "This script is designed for Ubuntu/Debian systems"
        log_warn "Please install the following packages manually:"
        log_warn "  build-essential golang-go protobuf-compiler libusb-1.0-0-dev"
        log_warn "  libudev-dev libhidapi-dev gcc-aarch64-linux-gnu gcc-arm-linux-gnueabihf"
        log_warn "  rsync qemu-user-static git wget cpio unzip bc"
        read -p "Continue assuming dependencies are installed? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        return
    fi
    
    sudo apt-get update
    sudo apt-get install -y \
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
        python3-pip
}

# Initialize Buildroot submodule if needed
setup_buildroot() {
    log_step "Setting up Buildroot..."
    
    if [[ ! -f "buildroot/Makefile" ]]; then
        log_info "Initializing Buildroot submodule..."
        git submodule update --init --recursive buildroot
        cd buildroot
        # Use a stable release branch
        git checkout 2024.02.x
        cd ..
    else
        log_info "Buildroot submodule already initialized"
        cd buildroot
        git checkout 2024.02.x
        cd ..
    fi
}

# Configure Buildroot
configure_buildroot() {
    log_step "Configuring Buildroot for $BOARD..."
    
    cd buildroot
    
    # Use our custom defconfig from BR2_EXTERNAL
    make pi-trezor-${BOARD}_defconfig BR2_EXTERNAL=../br2-external
    
    # Enable additional packages if needed
    if [[ $DISPLAY == "hdmi" ]]; then
        log_info "Configuring for HDMI display..."
        # HDMI configuration is handled in post_image.sh
    fi
    
    cd ..
}

# Build the system
build_system() {
    log_step "Building system image..."
    
    cd buildroot
    
    # Export environment variables for post-build scripts
    export PI_TREZOR_BOARD=$BOARD
    export PI_TREZOR_DISPLAY=$DISPLAY
    export PI_TREZOR_ROTATION=$ROTATION
    
    # Build everything
    log_info "Starting Buildroot build process (this may take a while)..."
    make all
    
    cd ..
}

# Copy final image
copy_output() {
    log_step "Preparing final output..."
    
    mkdir -p output/images
    
    if [[ -f "buildroot/output/images/sdcard.img" ]]; then
        cp buildroot/output/images/sdcard.img output/images/
        log_info "Build complete! Image available at: output/images/sdcard.img"
        
        # Generate checksums
        cd output/images
        sha256sum sdcard.img > sdcard.img.sha256
        log_info "SHA256 checksum: $(cat sdcard.img.sha256)"
        cd ../..
    else
        log_error "Build failed - no output image found"
        exit 1
    fi
}

# Cleanup function
cleanup() {
    log_step "Cleaning up..."
    unset CGO_ENABLED GOOS GOARCH GOARM CC
    unset PI_TREZOR_BOARD PI_TREZOR_DISPLAY PI_TREZOR_ROTATION
}

# Main execution
main() {
    log_info "Pi-Trezor Build System starting..."
    log_info "Target: $BOARD | Display: $DISPLAY | Rotation: $ROTATION°"
    
    trap cleanup EXIT
    
    install_host_deps
    setup_buildroot
    configure_buildroot
    build_system
    copy_output
    
    log_info "Build completed successfully!"
    log_info "Flash the image to SD card with:"
    log_info "  sudo dd if=output/images/sdcard.img of=/dev/sdX bs=4M status=progress"
    log_info "  (Replace /dev/sdX with your SD card device)"
}

# Run main function
main "$@"