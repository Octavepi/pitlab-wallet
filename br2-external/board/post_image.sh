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

# Ensure rpi-firmware contents are at the root of the boot partition layout
# Buildroot typically drops firmware into images/rpi-firmware; flatten it for genimage
if [ -d "$IMAGES_DIR/rpi-firmware" ]; then
    # Copy firmware blobs (start*.elf, fixup*.dat, etc.) to images root
    cp -a "$IMAGES_DIR/rpi-firmware/"* "$IMAGES_DIR/" 2>/dev/null || true
    # Ensure overlays directory is present at images root
    if [ -d "$IMAGES_DIR/rpi-firmware/overlays" ] && [ ! -d "$IMAGES_DIR/overlays" ]; then
        cp -a "$IMAGES_DIR/rpi-firmware/overlays" "$IMAGES_DIR/overlays"
    fi
fi

# Create basic config.txt
cat > "$IMAGES_DIR/config.txt" << EOF
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

# Security settings
enable_gic=1
arm_64bit=1

EOF

# Create basic cmdline.txt
cat > "$IMAGES_DIR/cmdline.txt" << 'EOF'
console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline fsck.repair=yes rootwait quiet logo.nologo modules_load=dwc2,g_ether fbcon=map:1
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
        # For all other displays, choose an appropriate overlay
        # Map known vendor names to firmware overlay candidates
        CANDIDATES=()
        case "$DISPLAY" in
            jun-electron*|jun-electron-35*|jun-electron-3.5* )
                # Jun-Electron 3.5" usually ili9486 + XPT2046
                CANDIDATES=(waveshare35a pitft35-resistive rpi-display)
                ;;
            waveshare35a|waveshare35b|pitft35-resistive|rpi-display)
                CANDIDATES=("$DISPLAY")
                ;;
            *)
                # Fallbacks for unknown names
                CANDIDATES=("$DISPLAY" waveshare35a pitft35-resistive rpi-display)
                ;;
        esac

        # Pick first available overlay from candidates
        SELECTED_OVERLAY=""
        for ov in "${CANDIDATES[@]}"; do
            if [ -f "$IMAGES_DIR/overlays/${ov}.dtbo" ]; then
                SELECTED_OVERLAY="$ov"
                break
            fi
        done

        if [ -z "$SELECTED_OVERLAY" ]; then
                echo "WARNING: No matching overlay found for '$DISPLAY'. Available overlays include:" >&2
                ls -1 "$IMAGES_DIR/overlays" 2>/dev/null | head -50 | sed 's/^/  - /' >&2 || true
                # Still write the requested name; firmware will ignore if missing.
                SELECTED_OVERLAY="$DISPLAY"
        fi

        cat >> "$IMAGES_DIR/config.txt" << EOF

# SPI Display Configuration: $DISPLAY
dtoverlay=$SELECTED_OVERLAY,rotate=$ROTATION,speed=32000000,fps=60
# Common 3.5" TFT resolution
framebuffer_width=480
framebuffer_height=320
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
    for f in start.elf start4.elf fixup.dat fixup4.dat Image config.txt cmdline.txt; do
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