# Contributing to PitLab Wallet

Thank you for your interest in contributing to PitLab Wallet! This document provides guidelines and information for contributors.

## 🎯 Project Goals

PitLab Wallet aims to provide a **reproducible, secure, air-gapped hardware wallet appliance** based on:
- Trezor Core (emulator) for wallet functionality
- trezord-go bridge for USB communication with Trezor Suite
- Minimal Buildroot-based Linux OS
- Complete network isolation for security

## 📋 Ways to Contribute

### Reporting Issues
- **Security vulnerabilities**: Please report privately via GitHub Security Advisories
- **Bugs**: Open an issue with detailed reproduction steps
- **Feature requests**: Open an issue describing the use case and benefits

### Code Contributions

1. **Fork the repository** and create a feature branch
2. **Make focused changes** addressing a single issue or feature
3. **Test thoroughly** on actual hardware if possible
4. **Submit a pull request** with a clear description

## 🏗️ Development Setup

### Prerequisites
- Ubuntu 24.04 LTS or compatible Debian-based system
- 8GB+ RAM, 20GB+ disk space
- Basic understanding of:
  - Buildroot embedded Linux system
  - Bash scripting
  - Linux systemd services
  - Cross-compilation

### Building PitLab Wallet from Source

```bash
# Clone the repo
git clone https://github.com/Octavepi/pitlab-wallet.git
cd pitlab-wallet

# Run the build
./build.sh --board pi4 --display waveshare35a
```

### Repository Structure

The project uses Buildroot's BR2_EXTERNAL mechanism:

- **`br2-external/`**: Buildroot external tree
  - `configs/`: Board-specific defconfig files
  - `package/`: Custom package definitions (trezord-go, trezor-firmware)
  - `board/`: Build scripts (post_build.sh, post_image.sh)
- **`overlay/`**: Root filesystem overlay (systemd services, udev rules, scripts)
- **`build.sh`**: Main build orchestration script

## 🔧 Making Changes

### Adding Display Support

1. Add display overlay configuration in `br2-external/board/post_image.sh`
2. Test the display overlay on actual hardware
3. Update README.md with new display in supported list

### Modifying Packages

**trezord-go package** (`br2-external/package/trezord-go/`):
- Update version in `trezord-go.mk`
- Rebuild: `cd buildroot && make trezord-go-rebuild`

**trezor-firmware package** (`br2-external/package/trezor-firmware/`):
- Update version in `trezor-firmware.mk`
- Rebuild: `cd buildroot && make trezor-firmware-rebuild`

### Security-Sensitive Changes

⚠️ **Extra caution required** when modifying:
- Network-related configurations (must remain disabled)
- Systemd service security settings
- File permissions and ownership
- udev rules for USB device access
- BusyBox configuration (security hardening)

## 🧪 Testing

### Manual Testing
1. Build the image for your target board
2. Flash to SD card and boot on actual hardware
3. Verify:
   - Display output and touchscreen work
   - Trezor services start: `systemctl status trezor-emu trezord`
   - USB connection to Trezor Suite works
   - No network interfaces: `ip link show` (should only show `lo`)

### CI/CD Testing
- GitHub Actions automatically builds and tests all supported configurations
- PRs must pass all CI checks before merge

## 📝 Commit Guidelines

### Commit Messages
Use clear, descriptive commit messages:

```
Brief summary (50 chars or less)

More detailed explanation if needed. Wrap at 72 characters.
Explain what changed and why, not how (code shows how).

Fixes: #123
```

### Types of Changes
- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **refactor**: Code refactoring without behavior change
- **security**: Security-related improvements
- **ci**: CI/CD configuration changes

## 🛡️ Security Guidelines

### Air-Gap Requirements
- **NEVER** add network functionality
- **DO NOT** include packages with network capabilities
- Verify `BR2_PACKAGE_*` network packages remain disabled

### Code Review Checklist
- [ ] No hardcoded credentials or secrets
- [ ] No network-related code or commands
- [ ] Systemd services have appropriate security settings
- [ ] File permissions follow least-privilege principle
- [ ] Changes don't weaken existing security features

## 📄 License

By contributing, you agree that your contributions will be licensed under the same MIT License that covers the project. See [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

PitLab Wallet builds upon the excellent work of:
- [Trezor](https://trezor.io/) - Hardware wallet firmware and bridge
- [Buildroot](https://buildroot.org/) - Embedded Linux build system
- [Raspberry Pi](https://www.raspberrypi.org/) - Affordable hardware platform

## 📞 Contact

- **Issues**: [GitHub Issues](https://github.com/Octavepi/pitlab-wallet/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Octavepi/pitlab-wallet/discussions)
- **Security**: Use GitHub Security Advisories for vulnerability reports

---

Thank you for helping make PitLab Wallet better! 🚀
