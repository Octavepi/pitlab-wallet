#!/bin/bash

# PitLab Wallet post-build script
# This script runs after the root filesystem is built but before creating the final image

set -e

TARGET_DIR="$1"
BR2_EXTERNAL_PATH="$2"

echo "PitLab Wallet post-build script running..."
echo "Target directory: $TARGET_DIR"
echo "BR2_EXTERNAL path: $BR2_EXTERNAL_PATH"

# Accept selected display/touchscreen driver from environment or argument
SELECTED_DRIVER="${PI_TREZOR_DISPLAY:-waveshare35a}"
echo "Selected display/touchscreen driver: $SELECTED_DRIVER"

# Pruning display/touchscreen modules is disabled by default to avoid breaking dependencies.
# If you want to prune kernel modules, implement an explicit mapping from overlay to module names first.
# echo "Module pruning skipped for safety."


# Remove non-essential systemd services (keep only trezord, trezor-emu, touchscreen-setup, airgap-firewall, systemd core)
if [ -d "$TARGET_DIR/etc/systemd/system" ]; then
    for svc in $(ls "$TARGET_DIR/etc/systemd/system" | grep ".service" | grep -v -E 'trezord|trezor-emu|touchscreen-setup|airgap-firewall|systemd|local-fs|multi-user|graphical|basic|getty|journald|udevd|user-sessions|tmpfiles|sysinit|dbus|logind'); do
        rm -f "$TARGET_DIR/etc/systemd/system/$svc"
    done
fi

# Remove non-essential packages cautiously. Avoid blanket deletions in /usr/bin as it may contain critical symlinks (e.g., /usr/bin/env).
# Keep /usr/bin intact to prevent breaking base utilities.

# In /usr/sbin, keep core daemons and udevadm, avoid aggressive pruning.
find "$TARGET_DIR/usr/sbin" -type f \
    ! -name 'systemd*' \
    ! -name 'udevd' \
    ! -name 'udevadm' \
    ! -name 'journald' \
    ! -name 'logind' \
    ! -name 'dbus-daemon' \
    -exec rm -f {} +

# In /usr/local/bin, keep PitLab Wallet binaries and touch utilities; remove anything else that sneaks in.
find "$TARGET_DIR/usr/local/bin" -type f \
    ! -name 'trezord' \
    ! -name 'trezor-emu' \
    ! -name 'touchscreen-setup.sh' \
    ! -name 'touchscreen-calibration-once.sh' \
    ! -name 'ts-uinput.sh' \
    ! -name 'calibrate-touchscreen' \
    ! -name 'test-touchscreen' \
    ! -name 'airgap-firewall.sh' \
    -exec rm -f {} +

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

# Set proper ownership for trezor directories
chown -R 1000:1000 "$TARGET_DIR/var/lib/trezor" || true

# Ensure proper permissions for PitLab Wallet binaries
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
PitLab Wallet
=============

Air-Gapped Hardware Wallet Appliance

This is a PitLab Wallet system running Trezor Core emulator
and trezord-go bridge for secure cryptocurrency operations.

⚠️  This system is designed to be completely air-gapped.
⚠️  Do not connect to any networks for security.

Status:
- USB Trezor Bridge: systemctl status trezord
- Trezor Emulator: systemctl status trezor-emu
- Touchscreen: ls /dev/input/

Connect via Trezor Suite over USB only.
EOF

# Network isolation is handled by airgap-firewall.service at runtime
# Only remove config files at build time, service management at runtime
rm -f "$TARGET_DIR/etc/systemd/network/"* || true
rm -f "$TARGET_DIR/etc/wpa_supplicant/"* || true
rm -f "$TARGET_DIR/etc/dhcpcd.conf" || true

# Mask all getty services to prevent login prompts
for svc in $(ls "$TARGET_DIR/lib/systemd/system/" | grep getty@); do
    ln -sf /dev/null "$TARGET_DIR/etc/systemd/system/$svc"
done

# Enable splash service at boot
ln -sf ../pitlab-wallet-splash.service "$TARGET_DIR/etc/systemd/system/graphical.target.wants/pitlab-wallet-splash.service"

echo "PitLab Wallet post-build script completed successfully"