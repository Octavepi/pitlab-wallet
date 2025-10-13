#!/bin/bash

# Pi-Trezor post-build script
# This script runs after the root filesystem is built but before creating the final image

set -e

TARGET_DIR="$1"
BR2_EXTERNAL_PATH="$2"

echo "Pi-Trezor post-build script running..."
echo "Target directory: $TARGET_DIR"
echo "BR2_EXTERNAL path: $BR2_EXTERNAL_PATH"

# Create necessary directories
mkdir -p "$TARGET_DIR/tmp"
mkdir -p "$TARGET_DIR/var/log"
mkdir -p "$TARGET_DIR/var/lib/trezor"
mkdir -p "$TARGET_DIR/run"
mkdir -p "$TARGET_DIR/dev"

# Set up tmpfs mount points in fstab
cat >> "$TARGET_DIR/etc/fstab" << EOF

# Pi-Trezor tmpfs mounts for security
tmpfs /tmp tmpfs defaults,nodev,nosuid,noexec,size=64M 0 0
tmpfs /var/log tmpfs defaults,nodev,nosuid,noexec,size=32M 0 0
tmpfs /run tmpfs defaults,nodev,nosuid,noexec,size=32M 0 0
EOF

# Create trezor user for running services
echo 'trezor:x:1000:1000:Trezor User:/var/lib/trezor:/bin/false' >> "$TARGET_DIR/etc/passwd"
echo 'trezor:x:1000:' >> "$TARGET_DIR/etc/group"

# Set proper ownership for trezor directories
chown -R 1000:1000 "$TARGET_DIR/var/lib/trezor" || true

# Ensure proper permissions for Pi-Trezor binaries
if [ -f "$TARGET_DIR/usr/local/bin/trezord" ]; then
    chmod 755 "$TARGET_DIR/usr/local/bin/trezord"
    chown root:root "$TARGET_DIR/usr/local/bin/trezord"
fi

if [ -f "$TARGET_DIR/usr/local/bin/trezor-emu" ]; then
    chmod 755 "$TARGET_DIR/usr/local/bin/trezor-emu"
    chown root:root "$TARGET_DIR/usr/local/bin/trezor-emu"
fi

# Disable root login for security
sed -i 's/^root:[^:]*:/root:*:/' "$TARGET_DIR/etc/shadow" || true

# Create a simple motd
cat > "$TARGET_DIR/etc/motd" << 'EOF'
 ____  _   _____                          
|  _ \(_) |_   _| __ ___ _______ _ __ 
| |_) | |   | || '__/ _ \_  / _ \ '__|
|  __/| |   | || | |  __// / (_) | |   
|_|   |_|   |_||_|  \___/___\___/|_|   

Air-Gapped Hardware Wallet Appliance
=====================================

This is a Pi-Trezor system running Trezor Core emulator
and trezord-go bridge for secure cryptocurrency operations.

⚠️  This system is designed to be completely air-gapped.
⚠️  Do not connect to any networks for security.

Status:
- USB Trezor Bridge: systemctl status trezord
- Trezor Emulator: systemctl status trezor-emu
- Touchscreen: ls /dev/input/

Connect via Trezor Suite over USB only.
EOF

# Remove any network configuration files that might exist
rm -f "$TARGET_DIR/etc/systemd/network/"* || true
rm -f "$TARGET_DIR/etc/wpa_supplicant/"* || true

# Disable systemd networking services
if [ -d "$TARGET_DIR/etc/systemd/system" ]; then
    # Create mask files to completely disable network services
    for service in networking dhcpcd wpa_supplicant systemd-networkd systemd-resolved; do
        ln -sf /dev/null "$TARGET_DIR/etc/systemd/system/${service}.service" || true
    done
fi

echo "Pi-Trezor post-build script completed successfully"