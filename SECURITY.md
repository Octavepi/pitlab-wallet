# Security Policy

## Overview

Pi-Trezor is designed as an **air-gapped hardware wallet appliance** with security as the primary focus. This document outlines the security model, known limitations, and reporting procedures.

## Security Model

### Protected Against

✅ **Network-based attacks**
- No Wi-Fi, Ethernet, or Bluetooth connectivity
- All networking packages disabled at build time
- Systemd networking services masked

✅ **Remote code execution**
- No network services running
- Minimal attack surface (essential services only)
- Read-only root filesystem

✅ **Unauthorized modifications**
- Read-only root filesystem prevents runtime tampering
- Reproducible builds enable verification
- Cryptographic checksums for all images

✅ **USB malware** (limited)
- Only Trezor-specific USB access via udev rules
- Minimal USB driver support
- No USB storage automounting

### NOT Protected Against

⚠️ **Physical device tampering**
- Physical access allows SD card replacement
- Boot chain not cryptographically verified
- No secure boot implementation

⚠️ **Supply chain attacks**
- SD card or hardware could be compromised before receipt
- Build system dependencies from upstream sources
- Raspberry Pi firmware is proprietary

⚠️ **Side-channel attacks**
- Power analysis
- Electromagnetic emissions
- Timing attacks on cryptographic operations

⚠️ **Malicious USB host**
- Host computer could be compromised
- USB protocol attacks possible
- Man-in-the-middle between device and Trezor Suite

⚠️ **Display-based attacks**
- Screen capture by external devices
- Visual observation of sensitive data

## Security Best Practices

### For Users

1. **Build from Source**
   ```bash
   # Clone and verify the repository
   git clone https://github.com/Octavepi/pi-trezor.git
   cd pi-trezor
   git verify-commit HEAD  # If GPG-signed
   
   # Build your own image
   ./build_pi-trezor.sh --board pi4 --display waveshare35a
   ```

2. **Verify Image Checksums**
   ```bash
   # After downloading a pre-built image
   sha256sum -c pi-trezor-*.img.sha256
   ```

3. **Secure Physical Access**
   - Keep device in a secure location
   - Use tamper-evident seals on SD card slot
   - Monitor for unauthorized physical access

4. **Trusted USB Host**
   - Only connect to trusted computers
   - Use air-gapped computer for signing transactions
   - Verify transaction details on device display

5. **Air-Gap Verification**
   ```bash
   # On the device, verify no network interfaces
   ip link show  # Should only show 'lo'
   
   # Check for disabled services
   systemctl list-units --type=service | grep -i network
   
   # Verify wireless is disabled
   rfkill list all
   ```

### For Developers

1. **Security-Sensitive Changes**
   - NEVER add network functionality
   - Maintain read-only root filesystem
   - Preserve systemd service security settings
   - Follow principle of least privilege

2. **Code Review Checklist**
   - [ ] No network-related packages or code
   - [ ] No hardcoded secrets or credentials
   - [ ] Proper file permissions (least privilege)
   - [ ] Systemd service security directives maintained
   - [ ] Build process remains reproducible

3. **Testing Security**
   ```bash
   # Verify networking disabled
   grep -r "BR2_PACKAGE_.*NETWORK\|DHCP\|WIRELESS" br2-external/configs/
   
   # Check for network commands
   grep -r "wget\|curl\|ssh\|ftp" br2-external/ overlay/
   
   # Validate systemd services
   grep -r "PrivateNetwork\|ProtectSystem" overlay/etc/systemd/system/
   ```

## Reproducible Builds

Pi-Trezor aims for reproducible builds to enable verification:

1. **Fixed Versions**
   - Buildroot: `2024.02.x` branch
   - Trezord-go: Tagged release versions
   - Trezor-firmware: Tagged release versions

2. **Verifying Builds**
   ```bash
   # Two independent builds should produce identical images
   ./build_pi-trezor.sh --board pi4
   sha256sum output/images/sdcard.img > build1.sha256
   
   # Clean and rebuild
   rm -rf buildroot/output output/
   ./build_pi-trezor.sh --board pi4
   sha256sum output/images/sdcard.img > build2.sha256
   
   # Compare (should be identical for reproducible build)
   diff build1.sha256 build2.sha256
   ```

3. **Known Non-Determinism**
   - Build timestamps in some packages
   - Python bytecode may vary
   - Buildroot host dependencies can affect output

## Vulnerability Disclosure

### Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **DO NOT** create a public GitHub issue
2. Use [GitHub Security Advisories](https://github.com/Octavepi/pi-trezor/security/advisories/new)
3. Or email: [security contact - to be added]

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if available)
- Your contact information (optional)

### Response Timeline

- **Acknowledgment**: Within 72 hours
- **Initial Assessment**: Within 1 week
- **Fix Development**: Varies by severity
- **Public Disclosure**: After fix is released

### Severity Ratings

**Critical**: Remote code execution, network bypass, credential exposure
**High**: Local privilege escalation, physical security bypass
**Medium**: Denial of service, information disclosure
**Low**: Configuration issues, minor information leaks

## Security Advisories

Security advisories will be published via:
- GitHub Security Advisories
- Repository SECURITY.md updates
- Release notes for patched versions

## Security Updates

### Applying Updates

Pi-Trezor uses an immutable OS design:

```bash
# Security updates require rebuilding and reflashing
git pull origin main
./build_pi-trezor.sh --board pi4
sudo dd if=output/images/sdcard.img of=/dev/sdX bs=4M
```

### Update Policy

- **Critical/High**: Patched within 2 weeks
- **Medium**: Patched in next planned release
- **Low**: Addressed as schedule permits

## Cryptographic Verification

### Signing (Future Enhancement)

Future releases may include:
- GPG-signed commits and tags
- Signed release artifacts
- Code signing for binaries

### Checksums

All release images include SHA256 checksums:
```bash
sha256sum -c pi-trezor-*.img.sha256
```

## Additional Resources

- [Trezor Security](https://trezor.io/learn/a/trezor-hardware-security)
- [Buildroot Security](https://buildroot.org/downloads/manual/manual.html#_security)
- [Raspberry Pi Security](https://www.raspberrypi.com/documentation/computers/configuration.html#securing-your-raspberry-pi)

## Disclaimer

Pi-Trezor is provided "as is" without warranty. Users assume all risks associated with its use for cryptocurrency storage. Always maintain proper backups of recovery seeds and test with small amounts first.

---

Last Updated: 2025-01-13
