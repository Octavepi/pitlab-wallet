#!/bin/bash
# Common kernel configuration for PitLab Wallet
# This script manages kernel configurations across all supported boards

# Kernel version for each board
declare -A KERNEL_VERSIONS
KERNEL_VERSIONS["pi3"]="6.6.0"
KERNEL_VERSIONS["pi4"]="6.6.0"
KERNEL_VERSIONS["pi5"]="6.6.0"

# Common kernel configuration options
COMMON_CONFIG=(
    # Security features
    "CONFIG_SECURITY=y"
    "CONFIG_SECURITY_LOCKDOWN_LSM=y"
    "CONFIG_SECURITY_LOCKDOWN_LSM_EARLY=y"
    "CONFIG_SECURITY_SELINUX=y"
    "CONFIG_AUDIT=y"
    
    # Memory protection
    "CONFIG_STRICT_KERNEL_RWX=y"
    "CONFIG_STRICT_MODULE_RWX=y"
    "CONFIG_RANDOMIZE_BASE=y"
    "CONFIG_RANDOMIZE_MEMORY=y"
    
    # Boot parameters
    "CONFIG_CMDLINE_BOOL=y"
    "CONFIG_CMDLINE=\"console=serial0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 rootwait\""
    
    # Air-gap features
    "# CONFIG_WIRELESS is not set"
    "# CONFIG_WLAN is not set"
    "# CONFIG_BT is not set"
    
    # Required drivers
    "CONFIG_SPI=y"
    "CONFIG_I2C=y"
    "CONFIG_USB_GADGET=y"
    "CONFIG_USB_CONFIGFS=y"
    "CONFIG_USB_CONFIGFS_F_HID=y"
)

# Board-specific kernel configurations
declare -A BOARD_CONFIG
BOARD_CONFIG["pi3"]=(
    "CONFIG_BCM2835=y"
    "CONFIG_ARM64=y"
    "CONFIG_ARCH_BCM2835=y"
)

BOARD_CONFIG["pi4"]=(
    "CONFIG_BCM2835=y"
    "CONFIG_ARM64=y"
    "CONFIG_ARCH_BCM2835=y"
    "CONFIG_ARCH_BCM2711=y"
)

BOARD_CONFIG["pi5"]=(
    "CONFIG_BCM2835=y"
    "CONFIG_ARM64=y"
    "CONFIG_ARCH_BCM2835=y"
    "CONFIG_ARCH_BCM2712=y"
    "CONFIG_BCM2712_IOMMU=y"
)

# Get kernel version for board
get_kernel_version() {
    local board=$1
    echo "${KERNEL_VERSIONS[$board]}"
}

# Generate kernel configuration
generate_kernel_config() {
    local board=$1
    local output_file=$2
    local temp_file="${output_file}.tmp"
    
    # Start with default configuration
    make ARCH=arm64 bcm${board}_defconfig O="$(dirname "$output_file")"
    
    # Add common configurations
    for config in "${COMMON_CONFIG[@]}"; do
        echo "$config" >> "$temp_file"
    done
    
    # Add board-specific configurations
    for config in "${BOARD_CONFIG[$board]}"; do
        echo "$config" >> "$temp_file"
    done
    
    # Merge configurations
    ./scripts/kconfig/merge_config.sh -m "$output_file" "$temp_file"
    rm "$temp_file"
}

# Validate kernel configuration
validate_kernel_config() {
    local config_file=$1
    local errors=0
    
    # Check required configurations
    for config in "${COMMON_CONFIG[@]}"; do
        if ! grep -q "^${config}$" "$config_file"; then
            echo "Missing required config: $config" >&2
            errors=$((errors + 1))
        fi
    done
    
    return $errors
}

# Update kernel configuration fragment
update_kernel_fragment() {
    local board=$1
    local fragment_file=$2
    
    # Clear existing fragment
    > "$fragment_file"
    
    # Add board-specific configurations
    for config in "${BOARD_CONFIG[$board]}"; do
        echo "$config" >> "$fragment_file"
    done
}