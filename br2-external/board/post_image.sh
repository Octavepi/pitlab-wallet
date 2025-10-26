#!/bin/bash
# PitLab Wallet post-image script
# Configures boot files and creates the final SD card image

set -euo pipefail
IFS=$'\n\t'

# Script constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMMON_DIR="${SCRIPT_DIR}/common"
readonly LOG_FILE="post_image.log"

# Source common configurations
declare -a REQUIRED_CONFIGS=(
    "firmware-config.sh"
    "security-config.sh"
    "kernel-config.sh"
    "lcd-drivers.sh"
)

source_configs() {
    local missing_configs=()
    
    for config in "${REQUIRED_CONFIGS[@]}"; do
        if [[ -f "${COMMON_DIR}/${config}" ]]; then
            source "${COMMON_DIR}/${config}"
        else
            missing_configs+=("${config}")
        fi
    done
    
    if ((${#missing_configs[@]} > 0)); then
        echo "ERROR: Missing required configuration files:" >&2
        printf "%s\n" "${missing_configs[@]}" >&2
        exit 1
    fi
}

# Error handling
error_handler() {
    local exit_code=$1
    local line_no=$2
    local bash_lineno=$3
    local last_cmd=$4
    local func_trace=$5

    {
        echo "Error in post_image.sh:"
        echo "Command: $last_cmd"
        echo "Line: $line_no"
        echo "Exit code: $exit_code"
        echo "Function trace: $func_trace"
        echo "Date: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    } >&2
    
    exit "$exit_code"
}

trap 'error_handler $? $LINENO $BASH_LINENO "$BASH_COMMAND" $(printf "::%s" ${FUNCNAME[@]:-})' ERR

# Argument validation
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <images-dir> <br2-external-path>" >&2
    exit 1
fi

readonly IMAGES_DIR="$1"
readonly BR2_EXTERNAL_PATH="$2"

# Build configuration
readonly BOARD="${PITLAB_WALLET_BOARD:-pi4}"
readonly DISPLAY="${PITLAB_DISPLAY:-${PITLAB_WALLET_DISPLAY:-lcd35}}"
readonly ROTATION="${PITLAB_ROTATION:-${PITLAB_WALLET_ROTATION:-90}}"

# Initialize logging
exec 1> >(tee -a "${IMAGES_DIR}/${LOG_FILE}")
exec 2> >(tee -a "${IMAGES_DIR}/${LOG_FILE}" >&2)

echo "PitLab Wallet post-image script running..."
echo "Images directory: $IMAGES_DIR"
echo "Board: $BOARD"
echo "Display: $DISPLAY"
echo "Rotation: $ROTATION"

# Source configurations
source_configs

# Configure boot partition
configure_boot() {
    local boot_dir="$1"
    
    echo "Configuring boot partition..."
    
    # Copy board-specific kernel and device tree files
    case "$BOARD" in
        pi3)
            cp "${IMAGES_DIR}/Image" "${boot_dir}/kernel8.img"
            cp "${IMAGES_DIR}/bcm2710-rpi-3-b.dtb" "${boot_dir}/"
            cp "${IMAGES_DIR}/bcm2710-rpi-3-b-plus.dtb" "${boot_dir}/"
            ;;
        pi4)
            cp "${IMAGES_DIR}/Image" "${boot_dir}/kernel8.img"
            cp "${IMAGES_DIR}/bcm2711-rpi-4-b.dtb" "${boot_dir}/"
            ;;
        pi5)
            cp "${IMAGES_DIR}/Image" "${boot_dir}/kernel_2712.img"
            cp "${IMAGES_DIR}/broadcom/2712-rpi5.dtb" "${boot_dir}/bcm2712-rpi-5.dtb"
            ;;
        *)
            echo "ERROR: Unsupported board $BOARD" >&2
            exit 1
            ;;
    esac
    
    # Configure display
    local config=$(get_display_config "$DISPLAY" "$BOARD")
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Invalid display configuration for $DISPLAY" >&2
        exit 1
    fi
    
    configure_display "$DISPLAY" "$BOARD" "${boot_dir}/config.txt" "$ROTATION"
}

# Create the SD card image
create_sdcard_image() {
    echo "Creating SD card image..."
    
    local genimage_cfg="${BR2_EXTERNAL_PATH}/board/genimage.cfg"
    local genimage_tmp="${IMAGES_DIR}/genimage.tmp"
    
    # Create genimage configuration
    sed -e "s/%BOARD%/${BOARD}/g" \
        -e "s/%DISPLAY%/${DISPLAY}/g" \
        "$genimage_cfg" > "${genimage_tmp}/genimage.cfg"
    
    # Run genimage
    genimage \
        --rootpath "${IMAGES_DIR}/rootfs" \
        --tmppath "${genimage_tmp}" \
        --inputpath "${IMAGES_DIR}" \
        --outputpath "${IMAGES_DIR}" \
        --config "${genimage_tmp}/genimage.cfg"
}

# Verify image
verify_image() {
    local image="$1"
    
    echo "Verifying image integrity..."
    
    # Generate checksums
    sha256sum "$image" > "${image}.sha256"
    sha512sum "$image" > "${image}.sha512"
    
    # Verify image size
    local size=$(stat -L -c %s "$image")
    local min_size=$((1024*1024*1024)) # 1GB
    local max_size=$((8*1024*1024*1024)) # 8GB
    
    if [[ $size -lt $min_size || $size -gt $max_size ]]; then
        echo "ERROR: Image size $size bytes is outside acceptable range" >&2
        exit 1
    fi
}

# Main execution
main() {
    # Create temporary directories
    local boot_dir="${IMAGES_DIR}/boot"
    mkdir -p "$boot_dir"
    
    # Configure boot files
    configure_boot "$boot_dir"
    
    # Create SD card image
    create_sdcard_image
    
    # Verify final image
    verify_image "${IMAGES_DIR}/pitlab-wallet-${BOARD}.img"
    
    echo "Post-image script completed successfully"
}

# Run main function
main
echo "Board: $BOARD"
echo "Display: $DISPLAY"  
echo "Rotation: $ROTATION"

# Clean up old image files
rm -f "$IMAGES_DIR"/sdcard.img* "$IMAGES_DIR"/boot.vfat 2>/dev/null || true

# Use the genimage configuration from br2-external
GENIMAGE_CFG="${BR2_EXTERNAL_PATH}/board/genimage.cfg"

# Ensure rpi-firmware contents are at the root of the boot partition
# Buildroot typically drops firmware into images/rpi-firmware
if [ -d "$IMAGES_DIR/rpi-firmware" ]; then
    # Copy firmware blobs (bootcode.bin, start*.elf, fixup*.dat) to boot root
    cp -a "$IMAGES_DIR/rpi-firmware"/*.bin "$IMAGES_DIR/" 2>/dev/null || true
    cp -a "$IMAGES_DIR/rpi-firmware"/start*.elf "$IMAGES_DIR/" 2>/dev/null || true
    cp -a "$IMAGES_DIR/rpi-firmware"/fixup*.dat "$IMAGES_DIR/" 2>/dev/null || true
    # Ensure overlays directory is present at root
    if [ -d "$IMAGES_DIR/rpi-firmware/overlays" ] && [ ! -d "$IMAGES_DIR/overlays" ]; then
        cp -a "$IMAGES_DIR/rpi-firmware/overlays" "$IMAGES_DIR/overlays"
    fi
fi

# Copy kernel Image and DTB files from kernel build to images root
# Kernel build places them in arch/arm64/boot/ or arch/arm/boot/
LINUX_BUILD_DIR="${IMAGES_DIR}/../build/linux-custom"

# Track whether the built kernel is 64-bit (1) or 32-bit (0)
ARM64_MODE=0

if [ -d "$LINUX_BUILD_DIR" ]; then
    # Copy kernel Image (prefer 64-bit Image if present; otherwise 32-bit zImage)
    if [ -f "$LINUX_BUILD_DIR/arch/arm64/boot/Image" ]; then
        echo "Copying 64-bit kernel Image to $IMAGES_DIR/Image"
        cp -f "$LINUX_BUILD_DIR/arch/arm64/boot/Image" "$IMAGES_DIR/Image" 2>/dev/null || true
        ARM64_MODE=1
    elif [ -f "$LINUX_BUILD_DIR/arch/arm/boot/zImage" ]; then
        echo "Copying 32-bit kernel zImage to $IMAGES_DIR/Image"
        cp -f "$LINUX_BUILD_DIR/arch/arm/boot/zImage" "$IMAGES_DIR/Image" 2>/dev/null || true
        ARM64_MODE=0
    fi

    # Copy DTB files
    if [ "$ARM64_MODE" = "1" ] && [ -d "$LINUX_BUILD_DIR/arch/arm64/boot/dts/broadcom" ]; then
        echo "Copying DTBs (arm64) to $IMAGES_DIR/"
        cp -f "$LINUX_BUILD_DIR/arch/arm64/boot/dts/broadcom"/bcm*.dtb "$IMAGES_DIR/" 2>/dev/null || true
        
        # Compile and install display rotation overlay
        DTC="$LINUX_BUILD_DIR/scripts/dtc/dtc"
        if [ -x "$DTC" ]; then
            echo "Compiling display rotation overlay..."
            OVERLAY_SRC="${BR2_EXTERNAL_PATH}/board/common/pitlab-display-rotation-overlay.dts"
            OVERLAY_DTB="$IMAGES_DIR/overlays/pitlab-display-rotation.dtbo"
            mkdir -p "$IMAGES_DIR/overlays"
            $DTC -@ -I dts -O dtb -o "$OVERLAY_DTB" "$OVERLAY_SRC"
        fi
    elif [ -d "$LINUX_BUILD_DIR/arch/arm/boot/dts/broadcom" ]; then
        echo "Copying DTBs (arm) to $IMAGES_DIR/"
        cp -f "$LINUX_BUILD_DIR/arch/arm/boot/dts/broadcom"/bcm*.dtb "$IMAGES_DIR/" 2>/dev/null || true
    fi
fi

# Create firmware directory for boot config files
mkdir -p "$IMAGES_DIR/firmware"

# Create boot partition config.txt in firmware/
cat > "$IMAGES_DIR/firmware/config.txt" << EOF
# PitLab Wallet Configuration
# Generated for $BOARD with $DISPLAY display

# Basic Pi configuration
gpu_mem=64
disable_overscan=1
enable_uart=1
dtoverlay=disable-bt  # free PL011 for serial console
kernel=Image

# Boot optimization
boot_delay=0
disable_splash=1

# Security/CPU mode
enable_gic=1
arm_64bit=${ARM64_MODE}

# Pi5-specific configuration
if [ "$BOARD" = "pi5" ]; then
    total_mem=8192
    gpu_mem=512
    spi_dma_rx_buffer_size=65536
    spi_dma_tx_buffer_size=65536
    over_voltage=5
else
    gpu_mem=64
fi

# Common display settings
max_usb_current=1
display_hdmi_rotate=${ROTATION}

# LCD driver configuration
if [ "$DISPLAY" != "hdmi" ]; then
    # Enable SPI interface with proper DMA settings for Pi5
    if [ "$BOARD" = "pi5" ]; then
        dtparam=spi=on,dma_buf_size=65536,fifo_depth=64
    else
        dtparam=spi=on
    fi
    
    # Add the display overlay based on selection
    dtoverlay=${DISPLAY}
    
    # Set LCD rotation with hardware-specific settings
    if [ "$BOARD" = "pi5" ]; then
        dtoverlay=pitlab-display-rotation-pi5,rotation=${ROTATION}
        # Pi5-specific display tweaks for better performance
        lcd_speed=100000000
        lcd_rotate_simple=1
    else
        dtoverlay=pitlab-display-rotation,rotation=${ROTATION}
    fi
fi
hdmi_force_hotplug=1
config_hdmi_boost=5

# Disable unused interfaces for security
dtparam=audio=off
dtparam=spi=on
dtparam=i2c_arm=on

# Framebuffer console on first framebuffer if present
framebuffer_depth=32
disable_fw_kms_setup=1

# USB gadget mode - Pi acts as Trezor hardware wallet device
dtoverlay=dwc2
dtparam=dr_mode=peripheral

# Disable activity LEDs for stealth operation
dtparam=act_led_trigger=none
dtparam=pwr_led_trigger=none
EOF

# Create boot partition cmdline.txt in firmware/
cat > "$IMAGES_DIR/firmware/cmdline.txt" << 'EOF'
console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait quiet logo.nologo modules_load=dwc2,g_ether fbcon=map:1
EOF

# Configure display-specific settings using LCD driver database
echo "" >> "$IMAGES_DIR/firmware/config.txt"
echo "# Display configuration for $DISPLAY" >> "$IMAGES_DIR/firmware/config.txt"

# Try to get display config from database
DISPLAY_INFO=""
SELECTED_OVERLAY=""
if command -v get_display_config &> /dev/null; then
    DISPLAY_INFO=$(get_display_config "$DISPLAY")
fi

if [ "$DISPLAY" = "hdmi" ]; then
    cat >> "$IMAGES_DIR/firmware/config.txt" << EOF
# HDMI Display Configuration
dtoverlay=vc4-kms-v3d
hdmi_force_hotplug=1
framebuffer_width=800
framebuffer_height=480
hdmi_group=2
hdmi_mode=87
hdmi_cvt=800 480 60 6 0 0 0
EOF
    SELECTED_OVERLAY="hdmi"
elif [ -n "$DISPLAY_INFO" ]; then
    # Parse display configuration from database
    overlay="" width="" height="" touch="" params=""
    if command -v parse_display_config &> /dev/null; then
        eval $(parse_display_config "$DISPLAY_INFO")
    fi
    
    # Copy device tree overlay from firmware overlays (included in rpi-firmware package)
    if [ -n "$overlay" ]; then
        if [ -d "$IMAGES_DIR/overlays" ] && [ -f "$IMAGES_DIR/overlays/${overlay}.dtbo" ]; then
            echo "Using built-in firmware overlay: ${overlay}.dtbo"
        else
            echo "WARNING: Overlay ${overlay}.dtbo not found in firmware overlays"
        fi
    fi
    
    SELECTED_OVERLAY="$overlay"
    
    # Configure based on display properties
    if [ -n "$overlay" ] && [ "$overlay" != "none" ]; then
        cat >> "$IMAGES_DIR/firmware/config.txt" << EOF
# SPI Display Configuration: $DISPLAY (from lcd-drivers database)
dtoverlay=$overlay,rotate=$ROTATION
EOF
        if [ -n "$width" ] && [ -n "$height" ]; then
            cat >> "$IMAGES_DIR/firmware/config.txt" << EOF
hdmi_cvt=$width $height 60 6 0 0 0
hdmi_group=2
hdmi_mode=87
framebuffer_width=$width
framebuffer_height=$height
EOF
        fi
        
        # Add extra parameters if specified
        if [ -n "$params" ]; then
            echo "$params" >> "$IMAGES_DIR/firmware/config.txt"
        fi
    fi
    
    # Configure touchscreen calibration using libinput defaults
    if [ -n "$touch" ] && [ "$touch" != "none" ]; then
        mkdir -p "$IMAGES_DIR/firmware/xorg.conf.d"
        echo "Note: Using libinput defaults for touchscreen ($touch type)"
    fi
else
    # Display not in database - warn and use basic configuration
    echo "WARNING: Display '$DISPLAY' not found in LCD driver database" >&2
    echo "WARNING: Using basic overlay configuration (may not work)" >&2
    echo "WARNING: Run './build.sh --list-displays' to see supported displays" >&2
    
    SELECTED_OVERLAY="$DISPLAY"
    
    # Try basic overlay configuration
    cat >> "$IMAGES_DIR/firmware/config.txt" << EOF
# Display Configuration: $DISPLAY (not in database, using basic config)
dtoverlay=$DISPLAY,rotate=$ROTATION
framebuffer_width=480
framebuffer_height=320
EOF
fi

# Configure FBCP (Framebuffer Copy) for SPI displays
if command -v needs_fbcp &> /dev/null && needs_fbcp "$DISPLAY"; then
    echo "Configuring FBCP for SPI display $DISPLAY..."
    
    # Create rc.local for FBCP startup
    # FBCP is built by Buildroot (BR2_PACKAGE_RPI_FBCP) and installed to /usr/local/bin/fbcp
    RC_LOCAL_FILE="$IMAGES_DIR/firmware/rc.local"
    cat > "$RC_LOCAL_FILE" << 'EORC'
#!/bin/sh -e
#
# rc.local - PITLAB Wallet startup script
# This script is executed at the end of each multiuser runlevel.

# Start framebuffer copy for SPI display
if [ -x /usr/local/bin/fbcp ]; then
    /usr/local/bin/fbcp &
fi

exit 0
EORC
    chmod +x "$RC_LOCAL_FILE"
    echo "  ✓ Created rc.local with FBCP startup"
    echo "  ℹ FBCP will be built by Buildroot (BR2_PACKAGE_RPI_FBCP)"
else
    echo "Display $DISPLAY does not require FBCP (HDMI or direct display)"
fi

echo "Generating SD card image with genimage..."

# Use a temp directory outside of IMAGES_DIR to avoid recursive copy issues
GENIMAGE_TMP="$(dirname "$IMAGES_DIR")/genimage.tmp"

# Clean up any existing temp directory first
rm -rf "$GENIMAGE_TMP"

# Build a dynamic genimage configuration to include all present DTBs, overlays, and firmware files
CFG="$IMAGES_DIR/genimage.auto.cfg"
cat > "$CFG" << 'EOF_GEN'
image boot.vfat {
    vfat {
        extraargs = "-n boot"
    }
    size = 32M
}

image sdcard.img {
    hdimage { }

    partition boot {
        partition-type = 0xC
        bootable = "true"
        image = "boot.vfat"
    }

    partition rootfs {
        partition-type = 0x83
        image = "rootfs.ext4"
    }
}
EOF_GEN

# Helper to append a file entry into boot.vfat with source path and destination name
append_file_entry() {
    local src="$1"   # relative to IMAGES_DIR
    local name="$2"  # path inside the VFAT
    # sanitize name default
    if [ -z "$name" ]; then name="$(basename "$src")"; fi
    # Append to vfat section by inserting before closing braces using a here-doc and sed
    awk -v src="$src" -v name="$name" '
        BEGIN{printed=0}
        {
            print $0
            if (!printed && $0 ~ /^\s*vfat\s*\{/){
                print "    file " name " {"
                print "      image = \"" src "\""
                print "    }"
                printed=1
            }
        }
    ' "$CFG" > "$CFG.tmp" && mv "$CFG.tmp" "$CFG"
}

# Include kernel Image
if [ -f "$IMAGES_DIR/Image" ]; then
    append_file_entry "Image" "Image"
fi

# Include firmware directory (will contain config.txt and cmdline.txt)
if [ -d "$IMAGES_DIR/firmware" ]; then
    append_file_entry "firmware" "firmware"
fi

# Include firmware blobs if present
for f in start.elf start4.elf start_cd.elf start_db.elf start_x.elf \
                 fixup.dat fixup4.dat fixup_cd.dat fixup_db.dat fixup_x.dat; do
    if [ -f "$IMAGES_DIR/$f" ]; then
        append_file_entry "$f" "$f"
    fi
done

# Include all DTBs: flatten from any subdir (e.g., broadcom/) to root of boot
while IFS= read -r -d '' dtb; do
    rel="${dtb#$IMAGES_DIR/}"
    base="$(basename "$dtb")"
    append_file_entry "$rel" "$base"
done < <(find "$IMAGES_DIR" -maxdepth 2 -type f -name "*.dtb" -print0)

# Include overlays directory with all .dtbo files
if [ -d "$IMAGES_DIR/overlays" ]; then
    append_file_entry "overlays" "overlays"
fi

# Use auto-generated config instead of the static one
GENIMAGE_CFG="$CFG"

# Generate the final image
genimage \
    --rootpath "$IMAGES_DIR" \
    --tmppath "$GENIMAGE_TMP" \
    --inputpath "$IMAGES_DIR" \
    --outputpath "$IMAGES_DIR" \
    --config "$GENIMAGE_CFG"

# Clean up temporary files
rm -rf "$GENIMAGE_TMP"

# Verify the generated image
if [ -f "$IMAGES_DIR/sdcard.img" ]; then
    IMAGE_SIZE=$(du -h "$IMAGES_DIR/sdcard.img" | cut -f1)
    echo "✅ Successfully generated sdcard.img ($IMAGE_SIZE)"
    echo "✅ Display: $DISPLAY with $ROTATION° rotation"
    echo "✅ Ready to flash to SD card"
else
    echo "❌ Failed to generate sdcard.img"
    exit 1
fi

# Copy final image to repository output/images for easy pickup
REPO_ROOT="$(cd "${BR2_EXTERNAL_PATH}"/.. && pwd)"
FINAL_OUT_DIR="$REPO_ROOT/output/images"
mkdir -p "$FINAL_OUT_DIR"
if cp -f "$IMAGES_DIR/sdcard.img" "$FINAL_OUT_DIR/"; then
    echo "✅ Copied final image to: $FINAL_OUT_DIR/sdcard.img"
else
    echo "⚠️  Warning: Could not copy final image to $FINAL_OUT_DIR"
fi

# Write a BOOTINFO.txt to assist headless debugging
{
    echo "=== PitLab Wallet Boot Info ==="
    echo "Date: $(date)"
    echo "Board: $BOARD"
    echo "Display: $DISPLAY"
        echo "Overlay selected: ${SELECTED_OVERLAY:-n/a}"
    echo "Rotation: $ROTATION"
    echo
    echo "Boot files present:"
    for f in start.elf start4.elf fixup.dat fixup4.dat Image firmware/config.txt firmware/cmdline.txt; do
        if [ -f "$IMAGES_DIR/$f" ]; then echo "  [x] $f"; else echo "  [ ] $f"; fi
    done
    echo
    echo "DTBs present (Pi4):"
    for d in bcm2711-rpi-4-b.dtb bcm2711-rpi-400.dtb bcm2711-rpi-cm4.dtb bcm2711-rpi-cm4s.dtb; do
        if [ -f "$IMAGES_DIR/$d" ]; then echo "  [x] $d"; fi
    done
    echo
    echo "Overlays directory:"
    if [ -d "$IMAGES_DIR/overlays" ]; then
        echo "  overlays/ exists"
        if [ -f "$IMAGES_DIR/overlays/${DISPLAY}.dtbo" ]; then
            echo "  [x] overlays/${DISPLAY}.dtbo"
        else
            echo "  [ ] overlays/${DISPLAY}.dtbo (missing)"
            echo "  Available overlays (first 20):"
            ls -1 "$IMAGES_DIR/overlays" | head -20 | sed 's/^/    - /'
        fi
    else
        echo "  overlays/ missing"
    fi
    echo
    echo "Serial console: 115200 8N1 on GPIO14 (TXD), GPIO15 (RXD), GND."
    echo "Set enable_uart=1 and dtoverlay=disable-bt (applied)."
} > "$IMAGES_DIR/BOOTINFO.txt"

# Create a summary file
cat > "$IMAGES_DIR/build-info.txt" << EOF
PitLab Wallet Build Information
==========================

Build Date: $(date)
Board: $BOARD  
Display: $DISPLAY
Rotation: $ROTATION°

Files Generated:
- sdcard.img (Ready to flash)
- boot.vfat (Boot partition)
- rootfs.ext4 (Root filesystem) 

Flash Command:
sudo dd if=sdcard.img of=/dev/sdX bs=4M status=progress
(Replace /dev/sdX with your SD card device)

Note: This is an air-gapped system. Do not connect to networks.
EOF

echo "PitLab Wallet post-image script completed successfully"