#!/bin/sh
# Common firmware configuration for PitLab Wallet
# This script provides unified firmware handling across all supported boards

# Firmware version mapping
PI3_FIRMWARE="1.20250101"
PI4_FIRMWARE="1.20250101"
PI5_FIRMWARE="1.20250101"

# Board-specific firmware files
declare -A FIRMWARE_FILES
FIRMWARE_FILES["pi3"]="bootcode.bin start.elf fixup.dat"
FIRMWARE_FILES["pi4"]="bootcode.bin start4.elf fixup4.dat"
FIRMWARE_FILES["pi5"]="bootcode.bin start5.elf fixup5.dat"

# Device Tree files by board
declare -A DTB_FILES
DTB_FILES["pi3"]="bcm2710-rpi-3-b.dtb bcm2710-rpi-3-b-plus.dtb bcm2710-rpi-cm3.dtb"
DTB_FILES["pi4"]="bcm2711-rpi-4-b.dtb bcm2711-rpi-400.dtb bcm2711-rpi-cm4.dtb bcm2711-rpi-cm4s.dtb"
DTB_FILES["pi5"]="bcm2712-rpi-5-b.dtb"

# Memory configurations
declare -A MEMORY_CONFIG
MEMORY_CONFIG["pi3"]="gpu_mem=64"
MEMORY_CONFIG["pi4"]="gpu_mem=128"
MEMORY_CONFIG["pi5"]="gpu_mem=512 total_mem=8192"

# Display configurations
declare -A DISPLAY_CONFIG
DISPLAY_CONFIG["common"]="max_usb_current=1 hdmi_force_hotplug=1"
DISPLAY_CONFIG["pi3"]="config_hdmi_boost=4"
DISPLAY_CONFIG["pi4"]="config_hdmi_boost=5"
DISPLAY_CONFIG["pi5"]="hdmi_enable_4kp60=1"

# Security settings
declare -A SECURITY_CONFIG
SECURITY_CONFIG["common"]="disable_overscan=1 disable_splash=1 boot_delay=0"
SECURITY_CONFIG["pi3"]="arm_64bit=1 disable_commandline_tags=1"
SECURITY_CONFIG["pi4"]="arm_64bit=1 disable_commandline_tags=1"
SECURITY_CONFIG["pi5"]="arm_64bit=1 disable_commandline_tags=1 secure_boot=1"

# Get firmware files for board
get_firmware_files() {
    local board=$1
    echo "${FIRMWARE_FILES[$board]}"
}

# Get DTB files for board
get_dtb_files() {
    local board=$1
    echo "${DTB_FILES[$board]}"
}

# Get memory configuration
get_memory_config() {
    local board=$1
    echo "${MEMORY_CONFIG[$board]}"
}

# Get display configuration
get_display_config() {
    local board=$1
    echo "${DISPLAY_CONFIG[common]} ${DISPLAY_CONFIG[$board]}"
}

# Get security configuration
get_security_config() {
    local board=$1
    echo "${SECURITY_CONFIG[common]} ${SECURITY_CONFIG[$board]}"
}

# Get firmware version
get_firmware_version() {
    local board=$1
    case $board in
        pi3) echo "$PI3_FIRMWARE" ;;
        pi4) echo "$PI4_FIRMWARE" ;;
        pi5) echo "$PI5_FIRMWARE" ;;
        *) echo "unknown" ;;
    esac
}

# Validate required firmware files
validate_firmware() {
    local board=$1
    local firmware_dir=$2
    local missing=0
    
    for file in $(get_firmware_files "$board"); do
        if [ ! -f "$firmware_dir/$file" ]; then
            echo "Missing firmware file: $file" >&2
            missing=1
        fi
    done
    
    return $missing
}