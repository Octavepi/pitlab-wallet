#!/bin/bash

# PitLab Wallet post-image script
# Dynamically configures display overlays and finalizes the SD card image

set -e

IMAGES_DIR="$1"
BR2_EXTERNAL_PATH="$2"

# Get environment variables set by build script
BOARD="${PITLAB_WALLET_BOARD:-pi4}"
DISPLAY="${PITLAB_DISPLAY:-${PITLAB_WALLET_DISPLAY:-lcd35}}"
ROTATION="${PITLAB_ROTATION:-${PITLAB_WALLET_ROTATION:-90}}"
LCD_SHOW_DIR="${PITLAB_LCD_SHOW_DIR:-}"

# Source the LCD driver database
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/common/lcd-drivers.sh" ]; then
    source "$SCRIPT_DIR/common/lcd-drivers.sh"
else
    echo "WARNING: lcd-drivers.sh not found. Display configuration may be limited."
fi

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

# Copy kernel Image and DTB files from kernel build to images root
# Kernel build places them in arch/arm64/boot/ or arch/arm/boot/
LINUX_BUILD_DIR="${IMAGES_DIR}/../build/linux-custom"
if [ -d "$LINUX_BUILD_DIR" ]; then
    # Copy kernel Image
    for img_path in "$LINUX_BUILD_DIR/arch/arm64/boot/Image" "$LINUX_BUILD_DIR/arch/arm/boot/zImage"; do
        if [ -f "$img_path" ]; then
            echo "Copying kernel Image from $img_path to $IMAGES_DIR/Image"
            cp -f "$img_path" "$IMAGES_DIR/Image" 2>/dev/null || true
            break
        fi
    done
    
    # Copy DTB files
    for dtb_dir in "$LINUX_BUILD_DIR/arch/arm64/boot/dts/broadcom" "$LINUX_BUILD_DIR/arch/arm/boot/dts/broadcom"; do
        if [ -d "$dtb_dir" ]; then
            echo "Copying DTBs from $dtb_dir to $IMAGES_DIR/"
            cp -f "$dtb_dir"/bcm*.dtb "$IMAGES_DIR/" 2>/dev/null || true
            break
        fi
    done
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

# Security settings
enable_gic=1
arm_64bit=1


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
    local overlay="" width="" height="" touch="" params=""
    if command -v parse_display_config &> /dev/null; then
        eval $(parse_display_config "$DISPLAY_INFO")
    fi
    
    # Copy device tree overlay from lcd-show if available; otherwise try built-in overlays
    if [ -n "$overlay" ]; then
        if [ -n "$LCD_SHOW_DIR" ] && [ -f "$LCD_SHOW_DIR/usr/${overlay}-overlay.dtb" ]; then
            mkdir -p "$IMAGES_DIR/overlays"
            cp "$LCD_SHOW_DIR/usr/${overlay}-overlay.dtb" "$IMAGES_DIR/overlays/${overlay}.dtbo"
            echo "Copied overlay: ${overlay}-overlay.dtb"
        elif [ -d "$IMAGES_DIR/overlays" ] && [ -f "$IMAGES_DIR/overlays/${overlay}.dtbo" ]; then
            echo "Using built-in firmware overlay: ${overlay}.dtbo"
        else
            echo "WARNING: Overlay ${overlay}.dtbo not found in lcd-show or firmware overlays"
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
    
    # Configure touchscreen calibration if possible
    if [ -n "$touch" ] && [ "$touch" != "none" ]; then
        mkdir -p "$IMAGES_DIR/firmware/xorg.conf.d"
        if [ -n "$LCD_SHOW_DIR" ]; then
            CALIB_FILE="$LCD_SHOW_DIR/usr/99-calibration.conf-${DISPLAY#lcd}-$ROTATION"
            if [ -f "$CALIB_FILE" ]; then
                cp "$CALIB_FILE" "$IMAGES_DIR/firmware/xorg.conf.d/99-calibration.conf"
                echo "Copied touch calibration: $(basename "$CALIB_FILE")"
            fi
        else
            echo "Note: No lcd-show repo present; using libinput defaults for touch"
        fi
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
    
    # Copy FBCP binary from lcd-show if available
    if [ -n "$LCD_SHOW_DIR" ] && [ -f "$LCD_SHOW_DIR/usr/rpi-fbcp/fbcp" ]; then
        mkdir -p "$IMAGES_DIR/firmware/fbcp"
        cp "$LCD_SHOW_DIR/usr/rpi-fbcp/fbcp" "$IMAGES_DIR/firmware/fbcp/"
        echo "  ✓ Copied FBCP binary from lcd-show"
    else
        echo "  ⚠ Warning: FBCP binary not found in lcd-show, display may not work"
        echo "  ⚠ FBCP is required for SPI displays to function properly"
    fi
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