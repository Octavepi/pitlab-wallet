#!/bin/bash

# PitLab Wallet post-image script
# Dynamically configures display overlays and finalizes the SD card image

set -e

IMAGES_DIR="$1"
BR2_EXTERNAL_PATH="$2"

# Get environment variables set by build script
BOARD="${PITLAB_WALLET_BOARD:-pi4}"
DISPLAY="${PITLAB_WALLET_DISPLAY:-waveshare35a}"
ROTATION="${PITLAB_WALLET_ROTATION:-180}"

echo "PitLab Wallet post-image script running..."
echo "Images directory: $IMAGES_DIR"
echo "Board: $BOARD"
echo "Display: $DISPLAY"  
echo "Rotation: $ROTATION"

# Use the genimage configuration from br2-external
GENIMAGE_CFG="${BR2_EXTERNAL_PATH}/board/genimage.cfg"

# Create boot partition directory structure if it doesn't exist
mkdir -p "$IMAGES_DIR/rpi-firmware"

# Create basic config.txt
cat > "$IMAGES_DIR/config.txt" << EOF
# PitLab Wallet Configuration
# Generated for $BOARD with $DISPLAY display

# Basic Pi configuration
gpu_mem=64
disable_overscan=1
enable_uart=0

# Boot optimization
boot_delay=0
disable_splash=1

# Security settings
enable_gic=1
arm_64bit=1

EOF

# Create basic cmdline.txt
cat > "$IMAGES_DIR/cmdline.txt" << 'EOF'
console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait quiet logo.nologo modules_load=dwc2,g_ether
EOF

# Configure display-specific settings
echo "# Display configuration for $DISPLAY" >> "$IMAGES_DIR/config.txt"

if [ "$DISPLAY" = "hdmi" ]; then
    cat >> "$IMAGES_DIR/config.txt" << EOF

# HDMI Display Configuration
dtoverlay=vc4-kms-v3d
hdmi_force_hotplug=1
framebuffer_width=800
framebuffer_height=480
hdmi_group=2
hdmi_mode=87
hdmi_cvt=800 480 60 6 0 0 0
EOF
else
    # For all other displays, use device tree overlay
    cat >> "$IMAGES_DIR/config.txt" << EOF

# SPI Display Configuration: $DISPLAY
dtoverlay=$DISPLAY,rotate=$ROTATION,speed=32000000,fps=60
EOF
fi

# Add common display settings
cat >> "$IMAGES_DIR/config.txt" << EOF

# Common display settings
max_usb_current=1
hdmi_force_hotplug=1
config_hdmi_boost=5

# Disable unused interfaces for security
dtparam=audio=off
dtparam=spi=on
dtparam=i2c_arm=on

# USB gadget mode - Pi acts as Trezor hardware wallet device
dtoverlay=dwc2
dtparam=dr_mode=peripheral

# Disable activity LEDs for stealth operation
dtparam=act_led_trigger=none
dtparam=pwr_led_trigger=none
EOF

echo "Generating SD card image with genimage..."

# Use a temp directory outside of IMAGES_DIR to avoid recursive copy issues
GENIMAGE_TMP="$(dirname "$IMAGES_DIR")/genimage.tmp"

# Clean up any existing temp directory first
rm -rf "$GENIMAGE_TMP"

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