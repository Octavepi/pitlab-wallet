#!/bin/bash

# Pi-Trezor Build System - Dynamic Multi-Board & Display Support
# Builds an air-gapped Raspberry Pi wallet appliance with Trezor Core and trezord-go

set -e

# Default values
BOARD="pi4"
DISPLAY="waveshare35a"
ROTATION="180"
CLEAN=0
DISTCLEAN=0
# Note: Toolchain and kernel defconfigs are handled by Buildroot defconfigs.

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

Positional usage:
    $0 [BOARD] [DISPLAY] [ROTATION] [FLAGS]
        BOARD    : pi3 | pi4 | pi5 (default: pi4)
        DISPLAY  : display overlay name (default: waveshare35a)
        ROTATION : 0 | 90 | 180 | 270 (default: 180)
        FLAGS    : -c | --clean | -dc | --distclean

Options:
    --board <pi3|pi4|pi5>                 Target Raspberry Pi board (default: pi4)
    --display <display_name>              Display overlay name (default: waveshare35a)
    --rotation <0|90|180|270>            Display rotation angle (default: 180)
    --clean|-c                           Wipe Buildroot output and rebuild from scratch
    --distclean|-dc                      Remove Buildroot download cache (dl) as well; implies --clean
    --help                               Show this help message

Supported displays:
    waveshare35a, waveshare32b, hdmi, vc4-kms-v3d, ili9341, ili9486, st7735r, and more
    Note: All Raspberry Pi firmware overlays are supported dynamically

Examples:
    # Positional
    $0 pi4 waveshare35a 90
    $0 pi5 hdmi 0 -c
    $0 pi4 waveshare35a 180 -dc
    
    # Long options (still supported)
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

# Parse command line arguments (support both positional and long options)
POSITIONAL_COUNT=0
while [[ $# -gt 0 ]]; do
    case $1 in
        # Long options
        --board)
            BOARD="$2"; shift 2 ;;
        --display)
            DISPLAY="$2"; shift 2 ;;
        --rotation)
            ROTATION="$2"; shift 2 ;;
        --clean|-c)
            CLEAN=1; shift 1 ;;
        --distclean|-dc)
            DISTCLEAN=1; CLEAN=1; shift 1 ;;
        --help|-h)
            show_help; exit 0 ;;
        # Positional args
        -*)
            log_error "Unknown flag: $1"; show_help; exit 1 ;;
        *)
            if [[ $POSITIONAL_COUNT -eq 0 ]]; then
                BOARD="$1"
            elif [[ $POSITIONAL_COUNT -eq 1 ]]; then
                DISPLAY="$1"
            elif [[ $POSITIONAL_COUNT -eq 2 ]]; then
                ROTATION="$1"
            else
                log_error "Unexpected extra argument: $1"; show_help; exit 1
            fi
            POSITIONAL_COUNT=$((POSITIONAL_COUNT+1))
            shift 1 ;;
    esac
done

# Validate board selection and set build parameters
case $BOARD in
    pi3)
        # Buildroot handles toolchain; no external CROSS_COMPILE needed
        ;;
    pi4)
        # Buildroot handles toolchain; no external CROSS_COMPILE needed
        ;;
    pi5)
        # Buildroot handles toolchain; no external CROSS_COMPILE needed
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

# Derive per-config Buildroot output directory (relative to buildroot/)
OUTPUT_SUFFIX="${BOARD}_${DISPLAY}_${ROTATION}"
BR_OUTPUT_DIR="output/${OUTPUT_SUFFIX}"

# Check for essential host dependencies
check_host_deps() {
    log_step "Checking for essential host dependencies..."
    local missing_deps=()
    local deps=(
        "make"
        "gcc"
        "go"
        "protoc"
        "git"
        "wget"
        "cpio"
        "unzip"
        "bc"
        "dtc"
        "python3"
    )

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing host dependencies: ${missing_deps[*]}. Please run 'sudo ./scripts/setup-host.sh' to install them."
        exit 1
    fi
    log_info "All essential dependencies are installed."
}

check_host_deps

# Check if we're in the right directory
if [[ ! -f "build_pi-trezor.sh" ]]; then
    log_error "Please run this script from the pi-trezor repository root"
    exit 1
fi

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
    make pi-trezor-${BOARD}_defconfig BR2_EXTERNAL=../br2-external O="${BR_OUTPUT_DIR}"
    
    # Enable additional packages if needed
    if [[ $DISPLAY == "hdmi" ]]; then
        log_info "Configuring for HDMI display..."
        # HDMI configuration is handled in post_image.sh
    fi
    
    cd ..
}

# Clean previous build output if requested
clean_build_output() {
    if [[ "$CLEAN" -eq 1 ]]; then
        log_step "Cleaning previous build output..."
        if [[ -d "buildroot/${BR_OUTPUT_DIR}" ]]; then
            rm -rf "buildroot/${BR_OUTPUT_DIR}"
            log_info "Removed buildroot/${BR_OUTPUT_DIR}"
        else
            log_info "No existing buildroot/${BR_OUTPUT_DIR} directory to remove"
        fi
        # Intentionally do NOT remove output/images to preserve previously built images
    fi
}

# Distclean removes the Buildroot download cache as well (forces re-download of sources)
distclean() {
    if [[ "$DISTCLEAN" -eq 1 ]]; then
        log_step "Performing distclean (removing Buildroot download cache)..."
        if [[ -d "buildroot/dl" ]]; then
            rm -rf buildroot/dl
            log_info "Removed buildroot/dl (download cache)"
        else
            log_info "No existing buildroot/dl directory to remove"
        fi
        # Also ensure per-config output is removed
        if [[ -d "buildroot/${BR_OUTPUT_DIR}" ]]; then
            rm -rf "buildroot/${BR_OUTPUT_DIR}"
            log_info "Removed buildroot/${BR_OUTPUT_DIR} (per-config output)"
        fi
    fi
}

# Build the system
build_system() {
    log_step "Building system image..."
    
    cd buildroot
    
    # Export environment variables for post-build scripts
    export PI_TREZOR_BOARD=$BOARD
    export PI_TREZOR_DISPLAY=$DISPLAY
    export PI_TREZOR_ROTATION=$ROTATION
    
    # Build everything with parallel compilation
    NPROC=$(nproc)
    log_info "Starting Buildroot build process with $NPROC parallel jobs (this may take a while)..."
    make -j$NPROC all O="${BR_OUTPUT_DIR}"
    
    cd ..
}

# Copy final image
copy_output() {
    log_step "Preparing final output..."
    
    mkdir -p output/images
    
    if [[ -f "buildroot/${BR_OUTPUT_DIR}/images/sdcard.img" ]]; then
        cp "buildroot/${BR_OUTPUT_DIR}/images/sdcard.img" output/images/
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
    
    setup_buildroot
    clean_build_output
    distclean
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