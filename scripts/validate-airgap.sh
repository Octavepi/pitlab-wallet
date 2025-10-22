#!/bin/bash

# PitLab Wallet Air-Gap Validation Script
# Verifies that the configuration maintains air-gap security

set -e

DEFCONFIG_DIR="br2-external/configs"
EXIT_CODE=0

log_error() {
    echo "❌ ERROR: $1" >&2
    EXIT_CODE=1
}

log_warn() {
    echo "⚠️  WARNING: $1" >&2
}

log_ok() {
    echo "✅ OK: $1"
}

echo "🔍 Validating PitLab Wallet Air-Gap Configuration..."

# Check for prohibited networking packages
PROHIBITED_PACKAGES=(
    "BR2_PACKAGE_DROPBEAR=y"
    "BR2_PACKAGE_OPENSSH=y"
    "BR2_PACKAGE_DHCPCD=y"
    "BR2_PACKAGE_WPA_SUPPLICANT=y"
    "BR2_PACKAGE_WIRELESS_TOOLS=y"
    "BR2_PACKAGE_NTP=y"
    "BR2_PACKAGE_CONNMAN=y"
    "BR2_PACKAGE_AVAHI=y"
)

find "$DEFCONFIG_DIR" -name "pitlab-wallet-*.defconfig" | while read -r config; do
    
    echo "Checking $(basename "$config")..."
    
    for pkg in "${PROHIBITED_PACKAGES[@]}"; do
        if grep -q "^$pkg" "$config"; then
            log_error "Prohibited package found in $(basename "$config"): $pkg"
        fi
    done
    
    # Check for required air-gap packages
    if ! grep -q "BR2_PACKAGE_IPTABLES=y" "$config"; then
        log_error "Missing firewall package in $(basename "$config"): BR2_PACKAGE_IPTABLES"
    fi
    
    if ! grep -q "BR2_PACKAGE_TREZORD_GO=y" "$config"; then
        log_error "Missing Trezor bridge in $(basename "$config"): BR2_PACKAGE_TREZORD_GO"
    fi
    
    if ! grep -q "BR2_PACKAGE_TREZOR_EMU=y" "$config"; then
        log_error "Missing Trezor emulator in $(basename "$config"): BR2_PACKAGE_TREZOR_EMU"
    fi
    
    log_ok "$(basename "$config") validated successfully"
done

# Check Config.in includes all packages
if ! grep -q "trezor-emu/Config.in" br2-external/Config.in; then
    log_error "Missing trezor-emu in br2-external/Config.in"
fi

if [ $EXIT_CODE -eq 0 ]; then
    log_ok "All air-gap validation checks passed!"
else
    log_error "Air-gap validation failed!"
fi

exit $EXIT_CODE