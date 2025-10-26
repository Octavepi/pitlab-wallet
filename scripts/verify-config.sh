#!/bin/bash
# Configuration verification script for PitLab Wallet
# This script verifies that all configurations are complete and consistent

# Source common configurations
SCRIPT_DIR="$(dirname "$0")"
. "${SCRIPT_DIR}/../br2-external/board/common/firmware-config.sh"
. "${SCRIPT_DIR}/../br2-external/board/common/security-config.sh"
. "${SCRIPT_DIR}/../br2-external/board/common/kernel-config.sh"
. "${SCRIPT_DIR}/../br2-external/board/common/display-config.sh"

# Initialize error counter
ERRORS=0

# Verify file presence and permissions
verify_files() {
    local required_files=(
        "br2-external/board/post_build.sh"
        "br2-external/board/post_image.sh"
        "br2-external/board/genimage.cfg"
        "br2-external/configs/busybox.fragment"
        "br2-external/configs/kernel_touchscreen.fragment"
        "overlay/etc/init.d/S90trezord"
        "overlay/etc/init.d/S91trezor-emu"
        "overlay/etc/udev/rules.d/51-trezor.rules"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            echo "ERROR: Missing required file: $file"
            ERRORS=$((ERRORS + 1))
        fi
    done
}

# Verify package configurations
verify_packages() {
    local defconfigs=(
        "br2-external/configs/pitlab-wallet-pi3_defconfig"
        "br2-external/configs/pitlab-wallet-pi4_defconfig"
        "br2-external/configs/pitlab-wallet-pi5_defconfig"
    )
    
    local required_packages=(
        "BR2_PACKAGE_TREZORD_GO=y"
        "BR2_PACKAGE_TREZOR_EMU=y"
        "BR2_PACKAGE_RPI_FIRMWARE=y"
        "BR2_PACKAGE_LIBUSB=y"
        "BR2_PACKAGE_HIDAPI=y"
    )
    
    for config in "${defconfigs[@]}"; do
        echo "Checking $config..."
        for pkg in "${required_packages[@]}"; do
            if ! grep -q "^$pkg" "$config"; then
                echo "ERROR: Missing package in $config: $pkg"
                ERRORS=$((ERRORS + 1))
            fi
        done
    done
}

# Verify kernel configurations
verify_kernel_configs() {
    local boards=("pi3" "pi4" "pi5")
    
    for board in "${boards[@]}"; do
        local kernel_config="br2-external/board/linux-${board}.config"
        if [ ! -f "$kernel_config" ]; then
            echo "ERROR: Missing kernel config for $board"
            ERRORS=$((ERRORS + 1))
            continue
        fi
        
        if ! validate_kernel_config "$kernel_config"; then
            echo "ERROR: Invalid kernel configuration in $kernel_config"
            ERRORS=$((ERRORS + 1))
        fi
    done
}

# Verify security configurations
verify_security() {
    local security_files=(
        "overlay/etc/init.d/S10airgap-firewall"
        "overlay/etc/sysctl.d/99-security.conf"
    )
    
    for file in "${security_files[@]}"; do
        if [ ! -f "$file" ]; then
            echo "ERROR: Missing security file: $file"
            ERRORS=$((ERRORS + 1))
        fi
    done
}

# Verify display configurations
verify_display() {
    local displays=("lcd35" "hdmi")
    local boards=("pi3" "pi4" "pi5")
    
    for display in "${displays[@]}"; do
        local config=$(get_display_config "$display")
        if [ -z "$config" ]; then
            echo "ERROR: Missing configuration for display: $display"
            ERRORS=$((ERRORS + 1))
        fi
    done
    
    for board in "${boards[@]}"; do
        local opts=$(get_board_display_opts "$board")
        if [ -z "$opts" ]; then
            echo "ERROR: Missing display options for board: $board"
            ERRORS=$((ERRORS + 1))
        fi
    done
}

# Verify firmware configurations
verify_firmware() {
    local boards=("pi3" "pi4" "pi5")
    
    for board in "${boards[@]}"; do
        if ! validate_firmware "$board" "buildroot/output/images"; then
            echo "ERROR: Invalid firmware configuration for $board"
            ERRORS=$((ERRORS + 1))
        fi
    done
}

# Main verification
echo "Starting PitLab Wallet configuration verification..."

verify_files
verify_packages
verify_kernel_configs
verify_security
verify_display
verify_firmware

if [ $ERRORS -eq 0 ]; then
    echo "✅ All configurations verified successfully!"
    exit 0
else
    echo "❌ Found $ERRORS configuration errors!"
    exit 1
fi