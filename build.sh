#!/bin/bash
# PitLab Wallet Build System
# Central build script for all supported boards and configurations

set -euo pipefail
IFS=$'\n\t'

# Script constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BR2_EXTERNAL="${SCRIPT_DIR}/br2-external"
readonly BUILD_LOG="${SCRIPT_DIR}/build.log"
readonly BUILDROOT_DIR="${SCRIPT_DIR}/buildroot"
readonly OUTPUT_DIR="${SCRIPT_DIR}/output"

# Configuration paths
readonly COMMON_CONFIG_DIR="${BR2_EXTERNAL}/board/common"
readonly KERNEL_FRAGMENT="${COMMON_CONFIG_DIR}/kernel.fragment"
readonly BUSYBOX_FRAGMENT="${BR2_EXTERNAL}/configs/busybox.fragment"

# Board configurations
declare -A BOARD_CONFIGS=(
    [pi3]="pitlab-wallet-pi3_defconfig"
    [pi4]="pitlab-wallet-pi4_defconfig"
    [pi5]="pitlab-wallet-pi5_defconfig"
)

# Source common configurations
source "${COMMON_CONFIG_DIR}/lcd-drivers.sh"
source "${COMMON_CONFIG_DIR}/security-config.sh"
source "${COMMON_CONFIG_DIR}/firmware-config.sh"

# Error handling
error_handler() {
    local exit_code=$1
    local line_no=$2
    local bash_lineno=$3
    local last_cmd=$4
    local func_trace=$5

    echo -e "${RED}Build failed:${NC}" >&2
    echo "Command: $last_cmd" >&2
    echo "Line: $line_no" >&2
    echo "Exit code: $exit_code" >&2
    echo "Function trace: $func_trace" >&2
    
    # Save error details to log
    {
        echo "=== Build Error ==="
        echo "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        echo "Command: $last_cmd"
        echo "Line: $line_no"
        echo "Exit code: $exit_code"
        echo "Function trace: $func_trace"
        echo "==================="
    } >> "$BUILD_LOG"
}

# Cleanup handler
cleanup() {
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo -e "${RED}Build failed. See $BUILD_LOG for details.${NC}" >&2
    fi
    
    # Clean temporary files
    rm -rf "${OUTPUT_DIR}/tmp"
}

# Set up error handling
trap 'cleanup' EXIT
trap 'error_handler $? $LINENO $BASH_LINENO "$BASH_COMMAND" $(printf "::%s" ${FUNCNAME[@]:-})' ERR

# Output formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Initialize logging
exec 1> >(tee -a "$BUILD_LOG")
exec 2> >(tee -a "$BUILD_LOG" >&2)

# Build functions
validate_configuration() {
    local board="$1"
    local display="$2"
    
    # Validate board
    if [[ ! -v "BOARD_CONFIGS[$board]" ]]; then
        echo -e "${RED}Error: Invalid board '$board'${NC}" >&2
        echo "Supported boards: ${!BOARD_CONFIGS[*]}" >&2
        return 1
    fi
    
    # Validate display
    if ! get_display_config "$display" >/dev/null 2>&1; then
        echo -e "${RED}Error: Invalid display '$display'${NC}" >&2
        echo "Run './build.sh list-displays' to see supported displays" >&2
        return 1
    fi
}

prepare_build_environment() {
    echo -e "${BLUE}Preparing build environment...${NC}"
    
    # Create required directories
    mkdir -p "${OUTPUT_DIR}"
    
    # Initialize Buildroot if needed
    if [[ ! -f "${BUILDROOT_DIR}/Makefile" ]]; then
        echo -e "${YELLOW}Initializing Buildroot...${NC}"
        git submodule update --init
    fi
    
    # Apply any pending patches
    if [[ -d "${BR2_EXTERNAL}/patches" ]]; then
        for patch in "${BR2_EXTERNAL}"/patches/*.patch; do
            if [[ -f "$patch" ]]; then
                echo "Applying patch: $(basename "$patch")"
                patch -d "$BUILDROOT_DIR" -p1 < "$patch"
            fi
        done
    fi
}

build_image() {
    local board="$1"
    local display="$2"
    local config="${BOARD_CONFIGS[$board]}"
    
    echo -e "${BLUE}Building PitLab Wallet for $board with $display display...${NC}"
    
    # Export build variables
    export PITLAB_WALLET_BOARD="$board"
    export PITLAB_WALLET_DISPLAY="$display"
    
    # Configure and build
    make -C "$BUILDROOT_DIR" O="$OUTPUT_DIR" \
        BR2_EXTERNAL="$BR2_EXTERNAL" \
        "$config" || return 1
    
    make -C "$BUILDROOT_DIR" O="$OUTPUT_DIR" || return 1
    
    echo -e "${GREEN}Build completed successfully!${NC}"
    echo "Image location: ${OUTPUT_DIR}/images/pitlab-wallet-${board}.img"
}

show_usage() {
    cat << EOF
Usage: $0 [options] <board> <display>

Build PitLab Wallet firmware image.

Options:
    --clean         Clean build directory before building
    --help         Show this help message
    list-boards    List supported boards
    list-displays  List supported displays

Supported boards:
$(printf "    %s\n" "${!BOARD_CONFIGS[@]}" | sort)

Example:
    $0 pi4 lcd35     Build for Raspberry Pi 4 with LCD35 display
EOF
}

# Main execution
main() {
    # Parse arguments
    case "${1:-}" in
        --help)
            show_usage
            exit 0
            ;;
        --clean)
            echo -e "${BLUE}Cleaning build directory...${NC}"
            rm -rf "${OUTPUT_DIR}"
            shift
            ;;
        list-boards)
            echo "Supported boards:"
            printf "%s\n" "${!BOARD_CONFIGS[@]}" | sort
            exit 0
            ;;
        list-displays)
            list_displays
            exit 0
            ;;
    esac
    
    # Validate arguments
    if [[ $# -lt 2 ]]; then
        show_usage
        exit 1
    fi
    
    local board="$1"
    local display="$2"
    
    # Validate configuration
    validate_configuration "$board" "$display"
    
    # Prepare environment
    prepare_build_environment
    
    # Build image
    build_image "$board" "$display"
}

# Run main function
main "$@"
log_info() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${GREEN}[INFO]${NC} $1" | tee -a "$BUILD_LOG"
}

log_warn() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}[WARN]${NC} $1" | tee -a "$BUILD_LOG"
}

log_error() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${RED}[ERROR]${NC} $1" | tee -a "$BUILD_LOG"
}

log_step() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${BLUE}[STEP]${NC} ${BOLD}$1${NC}" | tee -a "$BUILD_LOG"
}

log_debug() {
    if [ "${DEBUG:-0}" = "1" ]; then
        echo -e "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] $1" >> "$BUILD_LOG"
    fi
}

# Check required dependencies
check_dependencies() {
    local missing_deps=()
    
    # Essential build tools
    for cmd in make gcc g++ git wget cpio unzip rsync bc; do
        if ! command -v $cmd >/dev/null 2>&1; then
            missing_deps+=($cmd)
        fi
    done
    
    # Check for required libraries
    for lib in libncurses-dev; do
        if ! dpkg -l | grep -q "^ii.*$lib"; then
            missing_deps+=($lib)
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install missing dependencies and try again"
        log_info "You can use: sudo apt-get install ${missing_deps[*]}"
        exit 1
    fi
    
    log_info "All required dependencies are installed"
}

# Validate build configuration
validate_config() {
    local valid_boards=("pi3" "pi4" "pi5")
    local valid_displays=("lcd35" "hdmi")
    local valid_rotations=("0" "90" "180" "270")
    
    if [[ ! " ${valid_boards[@]} " =~ " ${BOARD} " ]]; then
        log_error "Invalid board: $BOARD. Must be one of: ${valid_boards[*]}"
        exit 1
    fi
    
    if [[ ! " ${valid_displays[@]} " =~ " ${DISPLAY} " ]]; then
        log_error "Invalid display: $DISPLAY. Must be one of: ${valid_displays[*]}"
        exit 1
    fi
    
    if [[ ! " ${valid_rotations[@]} " =~ " ${ROTATION} " ]]; then
        log_error "Invalid rotation: $ROTATION. Must be one of: ${valid_rotations[*]}"
        exit 1
    fi
    
    # Verify buildroot configuration
    local defconfig="br2-external/configs/pitlab-wallet-${BOARD}_defconfig"
    if [ ! -f "$defconfig" ]; then
        log_error "Missing defconfig for board ${BOARD}: $defconfig"
        exit 1
    fi
    
    # Verify kernel config
    local kernel_config="br2-external/board/linux-${BOARD}.config"
    if [ ! -f "$kernel_config" ]; then
        log_error "Missing kernel config for board ${BOARD}: $kernel_config"
        exit 1
    fi
    
    # Check for required overlay files
    if [ "$DISPLAY" != "hdmi" ]; then
        local display_overlay="br2-external/board/common/pitlab-display-rotation-overlay.dts"
        if [ ! -f "$display_overlay" ]; then
            log_error "Missing display rotation overlay: $display_overlay"
            exit 1
        fi
        
        if [ "$BOARD" = "pi5" ]; then
            local pi5_overlay="br2-external/board/common/pitlab-display-rotation-pi5-overlay.dts"
            if [ ! -f "$pi5_overlay" ]; then
                log_error "Missing Pi5 display rotation overlay: $pi5_overlay"
                exit 1
            fi
        fi
    fi
    
    # Verify key scripts exist
    local required_scripts=(
        "br2-external/board/post_build.sh"
        "br2-external/board/post_image.sh"
        "br2-external/board/genimage.cfg"
    )
    
    for script in "${required_scripts[@]}"; do
        if [ ! -f "$script" ]; then
            log_error "Missing required script: $script"
            exit 1
        fi
    done
    
    # Validate board-specific configuration
    if ! validate_board_config "$BOARD"; then
        log_error "Board-specific validation failed for $BOARD"
        exit 1
    fi

    log_info "Build configuration validated"
}

# Default values
BOARD="pi4"
DISPLAY="lcd35"
ROTATION="90"
CLEAN=0
DISTCLEAN=0
BUILD_LOG="build_$(date +%Y%m%d_%H%M%S).log"
# Note: Toolchain and kernel defconfigs are handled by Buildroot defconfigs.

# Board-specific configuration validation
validate_board_config() {
    local board="$1"
    
    case "$board" in
        pi5)
            # Check Pi5-specific requirements
            if [ ! -f "br2-external/board/common/pitlab-display-rotation-pi5-overlay.dts" ]; then
                log_error "Missing Pi5 display overlay"
                return 1
            fi
            
            # Verify Pi5 firmware availability
            local pi5_files=("start5.elf" "fixup5.dat" "bcm2712-rpi-5-b.dtb")
            for file in "${pi5_files[@]}"; do
                if [ ! -f "buildroot/output/images/$file" ]; then
                    log_warn "Missing Pi5 firmware file: $file (will be downloaded during build)"
                fi
            done
            
            # Check Pi5 kernel config options
            local kernel_config="br2-external/board/linux-pi5.config"
            if ! grep -q "CONFIG_BCM2712_IOMMU=y" "$kernel_config"; then
                log_error "Pi5 kernel config missing required IOMMU support"
                return 1
            fi
            ;;
        *)
            ;;
    esac
    
    return 0
}

# Error handler function
error_handler() {
    local exit_code=$1
    local line_no=$2
    local bash_lineno=$3
    local last_cmd=$4
    local func_trace=$5

    log_error "Error in build script at line $line_no"
    log_error "Last command: $last_cmd"
    log_error "Exit code: $exit_code"
    
    if [ -f "$BUILD_LOG" ]; then
        log_info "Build log available at: $BUILD_LOG"
        log_info "Last 10 lines of build log:"
        tail -n 10 "$BUILD_LOG"
    fi
}

# Cleanup function
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Build failed with exit code $exit_code"
        if [ -f "$BUILD_LOG" ]; then
            log_info "See $BUILD_LOG for details"
        fi
    else
        log_info "Build completed successfully"
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --board=*)
                BOARD="${1#*=}"
                ;;
            --display=*)
                DISPLAY="${1#*=}"
                ;;
            --rotation=*)
                ROTATION="${1#*=}"
                ;;
            --clean)
                CLEAN=1
                ;;
            --distclean)
                DISTCLEAN=1
                ;;
            --debug)
                DEBUG=1
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
}

# Main build process
main() {
    log_step "Starting PitLab Wallet build system"
    log_info "Board: $BOARD"
    log_info "Display: $DISPLAY"
    log_info "Rotation: $ROTATION"
    
    # Check dependencies and validate configuration
    check_dependencies
    validate_config
    
    if [ $DISTCLEAN -eq 1 ]; then
        log_step "Performing distclean"
        make -C buildroot distclean
    fi
    
    if [ $CLEAN -eq 1 ]; then
        log_step "Performing clean"
        make -C buildroot clean
    fi

    # Setup buildroot configuration
    log_step "Configuring buildroot for board: $BOARD"
    defconfig="br2-external/configs/pitlab-wallet-${BOARD}_defconfig"
    if [ ! -f "$defconfig" ]; then
        log_error "Defconfig not found: $defconfig"
        exit 1
    fi
    
    make -C buildroot BR2_EXTERNAL=../br2-external "pitlab-wallet-${BOARD}_defconfig"
    
    # Build system
    log_step "Building system image"
    make -C buildroot
    
    if [ $? -eq 0 ]; then
        log_step "Build completed successfully"
        log_info "Output images available in: output/images/"
    else
        log_error "Build failed"
        exit 1
    fi
}

# Show help message
show_help() {
    cat << EOF
PitLab Wallet Build System

Usage: $0 [options]

Options:
  --board=<pi3|pi4|pi5>     Target board (default: pi4)
  --display=<lcd35|hdmi>    Display type (default: lcd35)
  --rotation=<0|90|180|270> Display rotation (default: 90)
  --clean                   Clean build
  --distclean              Clean everything
  --debug                  Enable debug output
  --help                   Show this help message

EOF
}

# Main script execution
parse_args "$@"
main
}

log_step() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${BLUE}[STEP]${NC} ${BOLD}$1${NC}" | tee -a "$BUILD_LOG"
}

log_debug() {
    if [ "${DEBUG:-0}" = "1" ]; then
        echo -e "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] $1" >> "$BUILD_LOG"
    fi
}

# Help function
show_help() {
    cat << EOF
 PitLab Wallet Build System - Dynamic Multi-Board & Display Support

Usage: $0 [OPTIONS]

Positional usage:
    $0 [BOARD] [DISPLAY] [ROTATION] [FLAGS]
        BOARD    : pi3 | pi4 | pi5 (default: pi4)
        DISPLAY  : LCD driver name (default: lcd35)
        ROTATION : 0 | 90 | 180 | 270 (default: 90)
        FLAGS    : -c | --clean | -dc | --distclean

Options:
    --board <pi3|pi4|pi5>                 Target Raspberry Pi board (default: pi4)
    --display <display_name>              Display driver name (default: lcd35)
    --rotation <0|90|180|270>            Display rotation angle (default: 90)
    --clean|-c                           Wipe Buildroot output and rebuild from scratch
    --distclean|-dc                      Remove Buildroot download cache (dl) as well; implies --clean
    --list-displays                      List all supported LCD displays
    --help                               Show this help message

Supported displays:
    lcd35 (3.5" GPIO/SPI) - Jun-Electron 3.5" compatible
    lcd32, lcd28, lcd24 (2.4-3.2" GPIO/SPI displays)
    lcd5, lcd7b, lcd7c (5-7" HDMI displays)
    mhs35, mhs32, mhs24 (MHS series)
    hdmi (standard HDMI output)
    
    Run: ./build.sh --list-displays for full list

Examples:
    # Positional
    $0 pi4 lcd35 90
    $0 pi5 hdmi 0 -c
    $0 pi4 lcd35 180 -dc
    
    # Long options
    $0 --board pi4 --display lcd35 --rotation 90
    $0 --board pi5 --display hdmi --rotation 0
    $0 --board pi3 --display lcd7b --rotation 0

The build process will:
1. Install host dependencies
2. Cross-compile trezord-go and Trezor Core
3. Generate Buildroot configuration for the target board
4. Build the complete system image
5. Configure display and rotation settings
6. Output ready-to-flash sdcard.img

EOF
}

# Source helper scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/check_dependencies.sh"

# Initial checks
validate_dependencies
check_disk_space

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
        --list-displays)
            source br2-external/board/common/lcd-drivers.sh
            list_displays
            exit 0 ;;
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

log_info "Building PitLab Wallet for $BOARD with $DISPLAY display (rotation: $ROTATION°)"

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
if [[ ! -f "build.sh" ]]; then
    log_error "Please run this script from the repository root (where build.sh resides)"
    exit 1
fi

# Download and extract Buildroot tarball if needed
setup_buildroot() {
    log_step "Setting up Buildroot..."
    BUILDROOT_VERSION="2024.02"
    BUILDROOT_TARBALL="buildroot-${BUILDROOT_VERSION}.tar.gz"
    BUILDROOT_URL="https://buildroot.org/downloads/${BUILDROOT_TARBALL}"
    if [[ ! -d "buildroot" ]]; then
        log_info "Downloading Buildroot ${BUILDROOT_VERSION} release tarball..."
        wget -O "$BUILDROOT_TARBALL" "$BUILDROOT_URL"
        tar -xzf "$BUILDROOT_TARBALL"
        mv "buildroot-${BUILDROOT_VERSION}" buildroot
        rm "$BUILDROOT_TARBALL"
    else
        log_info "Buildroot directory already exists"
    fi
}

# Configure Buildroot
configure_buildroot() {
    log_step "Configuring Buildroot for $BOARD..."
    
    cd buildroot
    
    # Use our custom defconfig from BR2_EXTERNAL
    make pitlab-wallet-${BOARD}_defconfig BR2_EXTERNAL=../br2-external O="${BR_OUTPUT_DIR}"
    
    log_info "Display configuration: $DISPLAY @ $ROTATION°"
    
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
    
    # Export environment variables for post-build and post-image scripts
    export PITLAB_WALLET_BOARD=$BOARD
    export PITLAB_WALLET_DISPLAY=$DISPLAY
    export PITLAB_WALLET_ROTATION=$ROTATION
    export PITLAB_DISPLAY=$DISPLAY
    export PITLAB_ROTATION=$ROTATION
    
    # Optimize downloads with faster primary sites
    export BR2_PRIMARY_SITE="https://mirror.cedia.org.ec"
    
    # Build everything with parallel compilation
    NPROC=$(nproc)
    log_info "Starting Buildroot build process with $NPROC parallel jobs (this may take a while)..."
    log_info "Using optimized download mirrors for faster builds..."
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
    unset PITLAB_WALLET_BOARD PITLAB_WALLET_DISPLAY PITLAB_WALLET_ROTATION
    unset PITLAB_DISPLAY PITLAB_ROTATION
}

# Main execution
main() {
    log_info "PitLab Wallet Build System starting..."
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

}