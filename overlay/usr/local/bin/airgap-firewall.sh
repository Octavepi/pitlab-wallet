#!/bin/bash

# Pi-Trezor Air-Gap Firewall Service
# Enforces complete network isolation even if physical connections exist

set -e

LOG_FILE="/var/log/airgap-firewall.log"

log_message() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

log_message "Pi-Trezor Air-Gap Firewall starting..."

# Disable all network interfaces except loopback
for iface in $(ip link show | grep -E '^[0-9]+: ' | awk -F': ' '{print $2}' | grep -v lo); do
    if [[ "$iface" =~ ^(eth|wlan|wifi|bt|bluetooth) ]]; then
        log_message "Disabling network interface: $iface"
        ip link set "$iface" down 2>/dev/null || true
        ip addr flush dev "$iface" 2>/dev/null || true
    fi
done

# Block all network traffic with iptables (defense in depth)
iptables -P INPUT DROP
iptables -P FORWARD DROP  
iptables -P OUTPUT DROP

# Allow only loopback traffic
iptables -I INPUT 1 -i lo -j ACCEPT
iptables -I OUTPUT 1 -o lo -j ACCEPT

# Block all IPv6 traffic
ip6tables -P INPUT DROP 2>/dev/null || true
ip6tables -P FORWARD DROP 2>/dev/null || true
ip6tables -P OUTPUT DROP 2>/dev/null || true

# Disable kernel IP forwarding
echo 0 > /proc/sys/net/ipv4/ip_forward 2>/dev/null || true
echo 0 > /proc/sys/net/ipv6/conf/all/forwarding 2>/dev/null || true

# Kill any network-related processes that might be running
for proc in dhcpcd wpa_supplicant NetworkManager connman systemd-networkd systemd-resolved; do
    pkill -9 "$proc" 2>/dev/null || true
done

# Mask network services to prevent them from starting
systemctl mask networking dhcpcd wpa_supplicant systemd-networkd systemd-resolved 2>/dev/null || true

# Continuously monitor and re-disable any network interfaces
while true; do
    for iface in $(ip link show | grep -E '^[0-9]+: ' | awk -F': ' '{print $2}' | grep -v lo); do
        if [[ "$iface" =~ ^(eth|wlan|wifi|bt|bluetooth) ]]; then
            # Check if interface came up
            if ip link show "$iface" | grep -q "state UP"; then
                log_message "WARNING: Network interface $iface came up! Disabling immediately."
                ip link set "$iface" down 2>/dev/null || true
                ip addr flush dev "$iface" 2>/dev/null || true
            fi
        fi
    done
    
    # Check firewall rules are still in place
    if ! iptables -L | grep -q "DROP.*all"; then
        log_message "WARNING: Firewall rules missing! Reinstalling."
        iptables -P INPUT DROP
        iptables -P FORWARD DROP
        iptables -P OUTPUT DROP
        iptables -I INPUT 1 -i lo -j ACCEPT
        iptables -I OUTPUT 1 -o lo -j ACCEPT
    fi
    
    sleep 5
done