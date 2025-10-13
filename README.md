# Pi-Trezor: Air-Gapped Hardware Wallet Appliance

[![Build Status](https://github.com/Octavepi/pi-trezor/workflows/Build/badge.svg)](https://github.com/Octavepi/pi-trezor/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Pi-Trezor is a reproducible, air-gapped Raspberry Pi appliance that runs Trezor Core (emulator) and trezord-go bridge on a minimal Buildroot-based OS. It provides hardware wallet functionality with touchscreen support and integrates seamlessly with Trezor Suite over USB.

## 🔐 Security Features

- **Completely Air-Gapped**: No network connectivity (Wi-Fi, Ethernet, Bluetooth disabled)
- **Read-Only Root Filesystem**: Prevents tampering with system files
- **Minimal Attack Surface**: Only essential services and packages included
- **Hardware Security**: Leverages Raspberry Pi security features
- **USB-Only Communication**: Connect only to Trezor Suite via USB
- **Reproducible Builds**: Deterministic build process for verification

## 🎯 Supported Hardware

### Raspberry Pi Models
- **Raspberry Pi 3** (32-bit ARM, armhf)
- **Raspberry Pi 4** (64-bit ARM, aarch64) ⭐ Recommended
- **Raspberry Pi 5** (64-bit ARM, aarch64)

### Display Support
- **Waveshare 3.5" A/B/C** (waveshare35a, waveshare35b, waveshare35c)
- **Waveshare 3.2" B** (waveshare32b)
- **ILI9341-based displays** (ili9341)
- **ILI9486-based displays** (ili9486)
- **ST7735R-based displays** (st7735r)
- **HDMI displays** (hdmi)
- **Any Raspberry Pi firmware overlay** (custom names supported)

### Display Orientations
- **0°, 90°, 180°, 270°** rotation support
- Automatic touchscreen calibration
- Optimized for portrait and landscape modes

## 🚀 Quick Start

### Prerequisites

**Host System Requirements:**
- Ubuntu 24.04 LTS (recommended) or compatible Debian-based system
- 8GB+ RAM (for parallel compilation)
- 20GB+ free disk space
- Internet connection (for initial dependencies and source code)

### Build Your Pi-Trezor

1. **Clone the Repository**
   ```bash
   git clone https://github.com/Octavepi/pi-trezor.git
   cd pi-trezor
   ```

2. **Build for Your Hardware**
   ```bash
   # Raspberry Pi 4 with Waveshare 3.5" display (default configuration)
   ./build_pi-trezor.sh
   
   # Raspberry Pi 5 with HDMI display
   ./build_pi-trezor.sh --board pi5 --display hdmi --rotation 0
   
   # Raspberry Pi 3 with ILI9341 display, 270° rotation
   ./build_pi-trezor.sh --board pi3 --display ili9341 --rotation 270
   ```

3. **Flash to SD Card**
   ```bash
   # Find your SD card device (e.g., /dev/sdb, /dev/mmcblk0)
   lsblk
   
   # Flash the image (replace /dev/sdX with your device)
   sudo dd if=output/images/sdcard.img of=/dev/sdX bs=4M status=progress
   sudo sync
   ```

4. **Boot Your Pi-Trezor**
   - Insert the SD card into your Raspberry Pi
   - Connect your display (if not HDMI)
   - Power on the Pi
   - The system will automatically start Trezor services

## 📖 Build Options

### Command Line Arguments

```bash
./build_pi-trezor.sh [OPTIONS]

Options:
  --board <pi3|pi4|pi5>              Target Raspberry Pi board (default: pi4)
  --display <display_name>           Display overlay name (default: waveshare35a)  
  --rotation <0|90|180|270>          Display rotation (default: 180)
  --help                             Show help message

Examples:
  ./build_pi-trezor.sh --board pi4 --display waveshare35a --rotation 90
  ./build_pi-trezor.sh --board pi5 --display hdmi --rotation 0
  ./build_pi-trezor.sh --board pi3 --display ili9341 --rotation 270
```

### Available Display Overlays

The system supports any display overlay provided by the Raspberry Pi firmware. Common options include:

| Display Type | Overlay Name | Notes |
|--------------|--------------|--------|
| Waveshare 3.5" A | `waveshare35a` | Most common, resistive touch |
| Waveshare 3.5" B | `waveshare35b` | Capacitive touch variant |
| Waveshare 3.2" B | `waveshare32b` | Smaller form factor |
| ILI9341 | `ili9341` | Generic 3.2" SPI display |
| ILI9486 | `ili9486` | Generic 3.5" SPI display |
| ST7735R | `st7735r` | Generic 1.8" SPI display |
| HDMI | `hdmi` | Standard HDMI output |
| VC4 KMS | `vc4-kms-v3d` | Modern DRM/KMS driver |

## 🔧 Usage Guide

### First Boot Setup

1. **System Initialization**
   - Pi-Trezor boots automatically to a console
   - Touchscreen calibration may be required
   - Trezor services start automatically

2. **Touchscreen Calibration** (if needed)
   ```bash
   # Run calibration utility
   calibrate-touchscreen
   
   # Test touchscreen input
   test-touchscreen
   ```

3. **Service Status Check**
   ```bash
   # Check Trezor bridge status
   systemctl status trezord
   
   # Check Trezor emulator status  
   systemctl status trezor-emu
   
   # View service logs
   journalctl -u trezord -f
   journalctl -u trezor-emu -f
   ```

### Connecting to Trezor Suite

1. **Install Trezor Suite** on your main computer
   - Download from [trezor.io/trezor-suite](https://trezor.io/trezor-suite)
   - Install on Windows, macOS, or Linux

2. **Connect Pi-Trezor**
   - Use a USB cable to connect Pi to your computer
   - Pi-Trezor appears as a Trezor device
   - No additional drivers needed

3. **Initialize Wallet**
   - Follow Trezor Suite setup wizard
   - Generate new seed or recover existing wallet
   - Set up PIN and passphrase protection

### Maintenance and Updates

#### Service Management
```bash
# Restart Trezor services
sudo systemctl restart trezord trezor-emu

# Stop services (for maintenance)
sudo systemctl stop trezord trezor-emu

# Enable/disable autostart
sudo systemctl enable/disable trezord trezor-emu
```

#### Log Files
```bash
# System logs
sudo journalctl -u trezord
sudo journalctl -u trezor-emu
sudo journalctl -u touchscreen-setup

# Trezor bridge log
sudo tail -f /var/log/trezord.log

# Touchscreen setup log
sudo tail -f /var/log/touchscreen-setup.log
```

#### System Information
```bash
# Display hardware info
cat /proc/cpuinfo
lsusb
ls -la /dev/input/

# Display configuration
cat /boot/config.txt
cat /etc/ts.conf

# Service status
systemctl list-units --type=service --state=running
```

## 🏗️ Development

### Repository Structure

```
pi-trezor/
├── build_pi-trezor.sh           # Main build script
├── README.md                    # This file
├── configs/                     # Buildroot configurations
│   ├── external.desc            # BR2_EXTERNAL descriptor
│   ├── pi-trezor-pi3_defconfig  # Pi 3 configuration
│   ├── pi-trezor-pi4_defconfig  # Pi 4 configuration
│   ├── pi-trezor-pi5_defconfig  # Pi 5 configuration
│   ├── kernel_touchscreen.fragment # Kernel touchscreen drivers
│   └── busybox.fragment         # BusyBox security settings
├── board/                       # Build scripts
│   ├── post_build.sh            # Post-build customization
│   └── post_image.sh            # Image finalization
├── overlay/                     # Root filesystem overlay
│   ├── etc/systemd/system/      # Systemd service files
│   ├── etc/udev/rules.d/        # Udev device rules
│   └── usr/local/bin/           # Custom scripts and binaries
└── .github/workflows/           # CI/CD automation
```

### Build Process Details

1. **Dependency Installation**
   - Host build tools (GCC, Go, protobuf)
   - Cross-compilation toolchains
   - Raspberry Pi firmware tools

2. **Source Code Compilation**
   - `trezord-go`: Cross-compiled Go binary for ARM/ARM64
   - `trezor-firmware`: Core emulator compiled for target architecture
   - Custom scripts and configurations

3. **Buildroot System Assembly**
   - Minimal Linux kernel with touchscreen drivers
   - Systemd-based init system (networking disabled)
   - Security-hardened BusyBox utilities
   - USB and display drivers only

4. **Image Generation**
   - Boot partition with firmware and device trees
   - Root filesystem with Trezor binaries
   - Dynamic display overlay injection
   - Final SD card image with proper partitioning

### Customization

#### Adding New Display Support

1. **Check Raspberry Pi Firmware Overlays**
   ```bash
   # List available overlays
   ls /boot/overlays/*.dtbo
   ```

2. **Use Custom Overlay Name**
   ```bash
   ./build_pi-trezor.sh --display your-overlay-name
   ```

3. **Test Display Configuration**
   - Boot with new overlay
   - Check `/var/log/touchscreen-setup.log`
   - Run calibration if needed

#### Modifying Security Settings

Edit configurations in `configs/` directory:
- `busybox.fragment`: BusyBox feature disable/enable
- `kernel_touchscreen.fragment`: Kernel driver selection
- `*_defconfig`: Buildroot package selection

#### Adding Custom Services

1. Create service file in `overlay/etc/systemd/system/`
2. Add enable symlink in appropriate `.target.wants/` directory
3. Test with `systemctl status your-service`

### Contributing

1. **Fork the Repository**
2. **Create Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Test Your Changes**
   ```bash
   ./build_pi-trezor.sh --board pi4 --display waveshare35a
   ```
4. **Submit Pull Request**

Please ensure your contributions:
- Maintain air-gapped security model
- Include documentation updates
- Pass CI/CD validation
- Follow existing code style

## 🛡️ Security Considerations

### Air-Gap Verification

Pi-Trezor is designed to be completely offline. Verify air-gap status:

```bash
# Check for network interfaces (should show only 'lo')
ip link show

# Verify no network services
systemctl list-units --type=service | grep -i network

# Check for disabled wireless
rfkill list all
```

### Threat Model

**Protected Against:**
- Network-based attacks (no connectivity)
- Remote code execution via services
- Unauthorized system modifications (read-only filesystem)
- USB malware (limited USB functionality)

**Not Protected Against:**
- Physical device tampering
- Supply chain attacks on SD card/hardware
- Side-channel attacks on cryptographic operations
- Malicious USB host computers

### Security Recommendations

1. **Verify Build Integrity**
   ```bash
   # Check image checksum
   sha256sum output/images/sdcard.img
   ```

2. **Use Dedicated Hardware**
   - Dedicate Pi exclusively for wallet operations
   - Use tamper-evident enclosures
   - Store in secure physical location

3. **Regular Security Practices**
   - Keep seed phrase secure and offline
   - Use strong PIN and passphrase
   - Verify transaction details on device
   - Maintain operational security when connecting to computers

## 📋 Troubleshooting

### Common Issues

#### Build Failures

**Problem**: Build fails with dependency errors
```bash
# Solution: Update host system and retry
sudo apt update && sudo apt upgrade
./build_pi-trezor.sh --board pi4
```

**Problem**: Cross-compilation errors
```bash
# Solution: Clean build environment
rm -rf buildroot/output
./build_pi-trezor.sh --board pi4
```

#### Display Issues

**Problem**: Display not working
```bash
# Check boot configuration
cat /boot/config.txt | grep dtoverlay

# Verify display overlay exists
ls /boot/overlays/waveshare35a.dtbo

# Check kernel messages
dmesg | grep -i display
```

**Problem**: Touchscreen not responsive
```bash
# List input devices
ls -la /dev/input/

# Test touchscreen detection
evtest /dev/input/event0

# Recalibrate
calibrate-touchscreen
```

#### Service Issues

**Problem**: Trezor services not starting
```bash
# Check service status
systemctl status trezord trezor-emu

# Check logs
journalctl -u trezord -n 50
journalctl -u trezor-emu -n 50

# Restart services
sudo systemctl restart trezord trezor-emu
```

#### USB Connection Issues

**Problem**: Trezor Suite not detecting device
```bash
# Check USB device enumeration
lsusb

# Verify udev rules
udevadm info --query=all --name=/dev/bus/usb/001/002

# Check trezord bridge
curl http://127.0.0.1:21325/
```

### Getting Help

1. **Check System Logs**
   ```bash
   journalctl -b | grep -i error
   dmesg | tail -50
   ```

2. **Gather System Information**
   ```bash
   # Create debug report
   {
     echo "=== Pi-Trezor Debug Report ==="
     echo "Date: $(date)"
     echo "Board: $(cat /proc/cpuinfo | grep Model)"
     echo "Kernel: $(uname -a)"
     echo "Services:"
     systemctl status trezord trezor-emu --no-pager
     echo "USB Devices:"
     lsusb
     echo "Input Devices:"
     ls -la /dev/input/
     echo "Display Config:"
     cat /boot/config.txt
   } > debug-report.txt
   ```

3. **Community Support**
   - GitHub Issues: [Report bugs and ask questions](https://github.com/Octavepi/pi-trezor/issues)
   - Discussions: [Community discussions and tips](https://github.com/Octavepi/pi-trezor/discussions)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Trezor Team**: For the excellent Trezor firmware and bridge software
- **Buildroot Community**: For the embedded Linux build system
- **Raspberry Pi Foundation**: For the amazing single-board computer platform
- **Contributors**: All the developers who have contributed to this project

## ⚠️ Disclaimer

Pi-Trezor is provided as-is for educational and experimental purposes. While designed with security in mind, no cryptocurrency wallet can be 100% secure. Users assume all risks associated with cryptocurrency storage and transactions. Always verify transactions on the device display and maintain proper security practices.

For production use with significant funds, consider official Trezor hardware wallets from [trezor.io](https://trezor.io).

---

**Built with ❤️ for the cryptocurrency community**