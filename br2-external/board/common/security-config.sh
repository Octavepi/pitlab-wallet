#!/bin/bash
# Common security configuration for PitLab Wallet
# Central security policy management for all supported boards

# Constants
readonly SECURE_PATHS=(
    "/etc/ssl:0700"
    "/etc/crypto:0700"
    "/var/lib/trezor:0700"
    "/etc/passwd:0644"
    "/etc/shadow:0600"
    "/etc/init.d/S*:0755"
    "/usr/local/bin/*:0755"
)

# Common kernel security parameters (applied to all boards)
readonly COMMON_SECURITY_PARAMS=(
    "slab_nomerge"
    "init_on_alloc=1"
    "init_on_free=1"
    "page_alloc.shuffle=1"
    "randomize_kstack_offset=1"
)

# Board-specific security parameters
declare -A BOARD_SECURITY_PARAMS=(
    [pi3]="mitigations=auto"
    [pi4]="mitigations=auto,nosmt"
    [pi5]="mitigations=auto,nosmt spectre_v2=on spec_store_bypass_disable=on"
)

# USB device whitelist (Trezor devices only)
readonly USB_WHITELIST=(
    "0x534c:0x0001:Trezor One"
    "0x1209:0x53c1:Trezor T"
    "0x1209:0x53c0:Trezor Model One"
)

# Network security (disable all networking)
BLOCKED_MODULES=(
    "bluetooth"
    "btusb"
    "wifi"
    "cfg80211"
    "rfkill"
    "af_packet"
)

# Secure filesystem mounts
SECURE_MOUNTS=(
    "/tmp:noexec,nosuid,nodev"
    "/var/tmp:noexec,nosuid,nodev"
    "/dev/shm:noexec,nosuid,nodev"
    "/proc:hidepid=2"
)

# Apply file permissions
secure_permissions() {
    # Set restrictive umask
    umask 027
    
    # Secure directories
    for dir in $SECURE_DIRS; do
        if [ -d "$dir" ]; then
            chmod 750 "$dir"
            chown root:root "$dir"
        fi
    done
    
    # Secure files
    for file in $SECURE_FILES; do
        if [ -f "$file" ]; then
            chmod 750 "$file"
            chown root:root "$file"
        fi
    done
    
    # Special cases
    chmod 400 /etc/shadow
    chmod 644 /etc/passwd
    chmod 644 /etc/group
}

# Configure kernel parameters
get_kernel_params() {
    local board=$1
    echo "${KERNEL_PARAMS[common]} ${KERNEL_PARAMS[$board]}"
}

# Configure USB device whitelist
configure_usb_whitelist() {
    local rules_file="/etc/udev/rules.d/51-trezor.rules"
    
    # Clear existing rules
    > "$rules_file"
    
    # Add whitelisted devices
    for device in "${ALLOWED_USB_DEVICES[@]}"; do
        local vendor=${device%:*}
        local product=${device#*:}
        echo "SUBSYSTEM==\"usb\", ATTR{idVendor}==\"$vendor\", ATTR{idProduct}==\"$product\", TAG+=\"uaccess\"" >> "$rules_file"
    done
}

# Block unwanted kernel modules
block_modules() {
    local blacklist_file="/etc/modprobe.d/pitlab-blacklist.conf"
    
    # Clear existing blacklist
    > "$blacklist_file"
    
    # Add blocked modules
    for module in "${BLOCKED_MODULES[@]}"; do
        echo "blacklist $module" >> "$blacklist_file"
        echo "install $module /bin/false" >> "$blacklist_file"
    done
}

# Configure secure mounts
configure_mounts() {
    local fstab_file="/etc/fstab"
    
    # Add secure mount options
    for mount in "${SECURE_MOUNTS[@]}"; do
        local mountpoint=${mount%:*}
        local options=${mount#*:}
        sed -i "\\#${mountpoint}#s#defaults#defaults,${options}#" "$fstab_file"
    done
}

# Main security configuration
configure_security() {
    secure_permissions
    configure_usb_whitelist
    block_modules
    configure_mounts
}