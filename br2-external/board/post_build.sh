#!/bin/bash
# PitLab Wallet post-build script
# Performs final rootfs customization and security hardening

set -euo pipefail
IFS=$'\n\t'

# Script constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly COMMON_DIR="${SCRIPT_DIR}/common"

# Source required configurations
for config in security-config.sh firmware-config.sh kernel-config.sh; do
    if [[ -f "${COMMON_DIR}/${config}" ]]; then
        source "${COMMON_DIR}/${config}"
    else
        echo "ERROR: Required configuration ${config} not found!" >&2
        exit 1
    fi
done

# Argument validation
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <target-dir> <br2-external-path>" >&2
    exit 1
fi

readonly TARGET_DIR="$1"
readonly BR2_EXTERNAL_PATH="$2"

# Initialize logging
exec 1> >(tee -a "${TARGET_DIR}/var/log/post-build.log")

# Accept selected display/touchscreen driver from environment or argument
SELECTED_DRIVER="${PITLAB_WALLET_DISPLAY:-waveshare35a}"
echo "Selected display/touchscreen driver: $SELECTED_DRIVER"

# Pruning display/touchscreen modules is disabled by default to avoid breaking dependencies.
# If you want to prune kernel modules, implement an explicit mapping from overlay to module names first.
# echo "Module pruning skipped for safety."

# Remove non-essential init scripts (keep only S* init scripts for our services)
# BusyBox init will auto-run scripts in /etc/init.d/S* at boot

# Essential files and directories that must be preserved
readonly ESSENTIAL_FILES=(
    # Core system binaries
    "/bin/bash"
    "/bin/sh"
    "/usr/bin/env"
    "/usr/bin/python3"
    
    # Critical daemons and utilities
    "/usr/sbin/udevd"
    "/usr/sbin/udevadm"
    
    # PitLab Wallet specific binaries
    "/usr/local/bin/trezord"
    "/usr/local/bin/trezor-emu"
    "/usr/local/bin/touchscreen-setup.sh"
    "/usr/local/bin/touchscreen-calibration-once.sh"
    "/usr/local/bin/ts-uinput.sh"
    "/usr/local/bin/calibrate-touchscreen"
    "/usr/local/bin/test-touchscreen"
)

# Remove non-essential files while preserving critical components
cleanup_filesystem() {
    local target_dir="$1"
    
    echo "Cleaning up filesystem..."
    
    # Create list of essential files for fast lookup
    local tmpfile=$(mktemp)
    printf "%s\n" "${ESSENTIAL_FILES[@]}" > "$tmpfile"
    
    # Remove non-essential files while preserving required ones
    find "$target_dir/usr/sbin" "$target_dir/usr/local/bin" -type f | while read -r file; do
        rel_path="${file#$target_dir}"
        if ! grep -q "^${rel_path}$" "$tmpfile"; then
            rm -f "$file"
        fi
    done
    
    rm -f "$tmpfile"
}

# Apply security hardening
apply_security_hardening() {
    local target_dir="$1"
    
    echo "Applying security hardening..."
    
    # Set secure permissions on sensitive files and directories
    for path_spec in "${SECURE_PATHS[@]}"; do
        IFS=: read -r path mode <<< "$path_spec"
        path="${target_dir}${path}"
        if [[ -e "$path" ]]; then
            chmod "$mode" "$path"
            echo "Setting permissions $mode on $path"
        fi
    done
    
    # Configure kernel security parameters
    local cmdline_file="${target_dir}/boot/cmdline.txt"
    if [[ -f "$cmdline_file" ]]; then
        # Start with common parameters
        local security_params="${COMMON_SECURITY_PARAMS[*]}"
        
        # Add board-specific parameters if available
        local board="${PITLAB_WALLET_BOARD:-pi4}"
        if [[ -n "${BOARD_SECURITY_PARAMS[$board]:-}" ]]; then
            security_params+=" ${BOARD_SECURITY_PARAMS[$board]}"
        fi
        
        # Update cmdline.txt
        sed -i "s|$| ${security_params}|" "$cmdline_file"
    fi
    
    # Configure USB device whitelist
    local udev_rules="${target_dir}/etc/udev/rules.d/99-pitlab-wallet-usb.rules"
    {
        echo "# PitLab Wallet USB device whitelist"
        echo "# Only allowed devices can be accessed"
        for device in "${USB_WHITELIST[@]}"; do
            IFS=: read -r vid pid name <<< "$device"
            echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"${vid#0x}\", ATTR{idProduct}==\"${pid#0x}\", TAG+=\"uaccess\", GROUP=\"plugdev\", MODE=\"0660\" # $name"
        done
    } > "$udev_rules"
}

# Configure system services
configure_services() {
    local target_dir="$1"
    
    echo "Configuring system services..."
    
    # Create systemd service directory if it doesn't exist
    mkdir -p "${target_dir}/etc/systemd/system"
    
    # Configure trezord service
    cat > "${target_dir}/etc/systemd/system/trezord.service" << 'EOF'
[Unit]
Description=Trezor Bridge Daemon
After=network.target
ConditionPathExists=/usr/local/bin/trezord

[Service]
Type=simple
ExecStart=/usr/local/bin/trezord
Restart=always
RestartSec=1
User=trezord
Group=plugdev

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable required services
    ln -sf "/etc/systemd/system/trezord.service" \
        "${target_dir}/etc/systemd/system/multi-user.target.wants/trezord.service"
}

# Main execution
main() {
    echo "Running PitLab Wallet post-build script..."
    echo "Target directory: $TARGET_DIR"
    echo "BR2_EXTERNAL path: $BR2_EXTERNAL_PATH"
    
    cleanup_filesystem "$TARGET_DIR"
    apply_security_hardening "$TARGET_DIR"
    configure_services "$TARGET_DIR"
    
    echo "Post-build script completed successfully"
}

# Run main function
main
    ! -name 'airgap-firewall.sh' \
    ! -name 'pitlab-wallet-splash.sh' \
    -exec rm -f {} + 2>/dev/null || true

# Create necessary directories
mkdir -p "$TARGET_DIR/tmp"
mkdir -p "$TARGET_DIR/var/log"
mkdir -p "$TARGET_DIR/var/lib/trezor"
mkdir -p "$TARGET_DIR/run"
mkdir -p "$TARGET_DIR/dev"

# Set up tmpfs mount points in fstab
cat >> "$TARGET_DIR/etc/fstab" << EOF

# PitLab Wallet tmpfs mounts for security
tmpfs /tmp tmpfs defaults,nodev,nosuid,noexec,size=64M 0 0
tmpfs /var/log tmpfs defaults,nodev,nosuid,noexec,size=32M 0 0
tmpfs /run tmpfs defaults,nodev,nosuid,noexec,size=32M 0 0
EOF

# Create trezor user for running services
echo 'trezor:x:1000:1000:Trezor User:/var/lib/trezor:/bin/false' >> "$TARGET_DIR/etc/passwd"
echo 'trezor:x:1000:' >> "$TARGET_DIR/etc/group"

# Set proper permissions for trezor directories
chmod 775 "$TARGET_DIR/var/lib/trezor"

# Ensure proper permissions for PitLab Wallet binaries
if [ -f "$TARGET_DIR/usr/local/bin/trezord" ]; then
    chmod 755 "$TARGET_DIR/usr/local/bin/trezord"
fi

if [ -f "$TARGET_DIR/usr/local/bin/trezor-emu" ]; then
    chmod 755 "$TARGET_DIR/usr/local/bin/trezor-emu"
fi

# Note: ownership will be set by Buildroot's target finalization

# Disable root login for security
sed -i 's/^root:[^:]*:/root:*:/' "$TARGET_DIR/etc/shadow" || true

# Create a simple motd
cat > "$TARGET_DIR/etc/motd" << 'EOF'
PitLab Wallet
=============

Air-Gapped Hardware Wallet Appliance

This is a PitLab Wallet system running Trezor Core emulator
and trezord-go bridge for secure cryptocurrency operations.

⚠️  This system is designed to be completely air-gapped.
⚠️  Do not connect to any networks for security.

Status:
- USB Trezor Bridge: /etc/init.d/S90trezord status
- Trezor Emulator: /etc/init.d/S91trezor-emu status
- Touchscreen: ls /dev/input/

Connect via Trezor Suite over USB only.
EOF

# Network isolation is handled by airgap-firewall init script at runtime
rm -f "$TARGET_DIR/etc/wpa_supplicant/"* 2>/dev/null || true
rm -f "$TARGET_DIR/etc/dhcpcd.conf" 2>/dev/null || true

# Ensure all init.d scripts are executable
chmod +x "$TARGET_DIR/etc/init.d/S"* 2>/dev/null || true

echo "PitLab Wallet post-build script completed successfully"