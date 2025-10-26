#!/bin/bash
# Validate firmware image integrity and security requirements

set -euo pipefail
IFS=$'\n\t'

# Script constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SECURE_BOOT_KEY="${SCRIPT_DIR}/../keys/secure-boot.key"
readonly MIN_IMAGE_SIZE=$((256*1024*1024))  # 256MB
readonly MAX_IMAGE_SIZE=$((8*1024*1024*1024))  # 8GB

# Security checks
validate_security() {
    local image="$1"
    
    echo "Performing security validation..."
    
    # Check for root-owned files
    if find "$image" -type f -user root -print -quit | grep -q .; then
        echo "ERROR: Found root-owned files in image" >&2
        return 1
    fi
    
    # Verify permissions on sensitive files
    for file in /etc/shadow /etc/ssl/private /etc/crypto; do
        if [[ -e "${image}${file}" ]]; then
            local perms=$(stat -c %a "${image}${file}")
            if ((perms & 0077)); then
                echo "ERROR: Insecure permissions $perms on $file" >&2
                return 1
            fi
        fi
    done
    
    # Check for common security misconfigurations
    if grep -q "PermitRootLogin yes" "${image}/etc/ssh/sshd_config" 2>/dev/null; then
        echo "ERROR: Root login is enabled" >&2
        return 1
    fi
}

# Hardware compatibility checks
validate_hardware() {
    local image="$1"
    local board="$2"
    
    echo "Validating hardware compatibility..."
    
    # Check kernel version matches board
    local kernel_ver=$(strings "${image}/boot/kernel8.img" | grep -E "^Linux version" | head -1)
    case "$board" in
        pi3|pi4)
            if ! echo "$kernel_ver" | grep -q "bcm27"; then
                echo "ERROR: Invalid kernel for $board" >&2
                return 1
            fi
            ;;
        pi5)
            if ! echo "$kernel_ver" | grep -q "bcm2712"; then
                echo "ERROR: Invalid kernel for pi5" >&2
                return 1
            fi
            ;;
    esac
}

# Firmware validation
validate_firmware() {
    local image="$1"
    local board="$2"
    
    echo "Validating firmware image..."
    
    # Check image size
    local size=$(stat -L -c %s "$image")
    if ((size < MIN_IMAGE_SIZE || size > MAX_IMAGE_SIZE)); then
        echo "ERROR: Image size $size is outside acceptable range" >&2
        return 1
    fi
    
    # Validate partitions
    if ! sfdisk -l "$image" | grep -q "Linux$"; then
        echo "ERROR: Missing root partition" >&2
        return 1
    fi
    
    # Check filesystem
    if ! fsck.ext4 -n "${image}2" >/dev/null 2>&1; then
        echo "ERROR: Root filesystem errors detected" >&2
        return 1
    fi
}

# Configuration validation
validate_config() {
    local image="$1"
    local config="${image}/boot/config.txt"
    
    echo "Validating configuration..."
    
    # Check required settings
    local required_settings=(
        "dtparam=spi=on"
        "dtparam=i2c_arm=on"
        "max_usb_current=1"
    )
    
    for setting in "${required_settings[@]}"; do
        if ! grep -q "^$setting" "$config"; then
            echo "ERROR: Missing required setting: $setting" >&2
            return 1
        fi
    done
}

# Usage
usage() {
    cat << EOF
Usage: $0 <image-file> <board-type>

Validate PitLab Wallet firmware image

Arguments:
    image-file  Path to firmware image
    board-type  Board type (pi3, pi4, pi5)

Example:
    $0 output/images/pitlab-wallet-pi4.img pi4
EOF
    exit 1
}

# Main execution
main() {
    if [[ $# -ne 2 ]]; then
        usage
    fi
    
    local image="$1"
    local board="$2"
    
    if [[ ! -f "$image" ]]; then
        echo "ERROR: Image file not found: $image" >&2
        exit 1
    fi
    
    echo "Validating image: $image"
    echo "Board type: $board"
    
    validate_security "$image" || exit 1
    validate_hardware "$image" "$board" || exit 1
    validate_firmware "$image" "$board" || exit 1
    validate_config "$image" || exit 1
    
    echo "Validation completed successfully"
}

# Run main function
main "$@"