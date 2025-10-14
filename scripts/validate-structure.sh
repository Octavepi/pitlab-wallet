#!/bin/bash

# PitLab Wallet Repository Structure Validation Script
# Verifies that all required files and directories are present

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "PitLab Wallet Repository Structure Validation"
echo "=========================================="
echo

cd "$REPO_ROOT"

ERRORS=0

# Function to check if a file exists
check_file() {
    if [ ! -f "$1" ]; then
        echo "❌ Missing file: $1"
        ((ERRORS++))
        return 1
    else
        echo "✅ Found: $1"
        return 0
    fi
}

# Function to check if a directory exists
check_dir() {
    if [ ! -d "$1" ]; then
        echo "❌ Missing directory: $1"
        ((ERRORS++))
        return 1
    else
        echo "✅ Found: $1"
        return 0
    fi
}

echo "Checking root files..."
check_file "README.md"
check_file "LICENSE"
check_file "CONTRIBUTING.md"
check_file "SECURITY.md"
check_file "build.sh"
check_file ".gitignore"

echo
echo "Checking br2-external structure..."
check_dir "br2-external"
check_file "br2-external/external.desc"
check_file "br2-external/external.mk"
check_file "br2-external/Config.in"

echo
echo "Checking br2-external/configs..."
check_dir "br2-external/configs"
check_file "br2-external/configs/pitlab-wallet-pi3_defconfig"
check_file "br2-external/configs/pitlab-wallet-pi4_defconfig"
check_file "br2-external/configs/pitlab-wallet-pi5_defconfig"
check_file "br2-external/configs/kernel_touchscreen.fragment"
check_file "br2-external/configs/busybox.fragment"

echo
echo "Checking br2-external/board..."
check_dir "br2-external/board"
check_file "br2-external/board/post_build.sh"
check_file "br2-external/board/post_image.sh"
check_file "br2-external/board/genimage.cfg"

echo
echo "Checking br2-external/package..."
check_dir "br2-external/package"
check_dir "br2-external/package/trezord-go"
check_file "br2-external/package/trezord-go/Config.in"
check_file "br2-external/package/trezord-go/trezord-go.mk"
check_file "br2-external/package/trezord-go/trezord.service"

echo "Trezor firmware checks removed."

echo
echo "Checking overlay structure..."
check_dir "overlay"
check_dir "overlay/etc/systemd/system"
check_dir "overlay/etc/systemd/system/multi-user.target.wants"
check_dir "overlay/etc/systemd/system/graphical.target.wants"
check_dir "overlay/etc/udev/rules.d"
check_dir "overlay/usr/local/bin"

# Main service files are trezor-emu.service and trezord.service
check_file "overlay/etc/systemd/system/touchscreen-setup.service"
check_file "overlay/etc/systemd/system/trezord.service"
check_file "overlay/etc/systemd/system/trezor-emu.service"
check_file "overlay/etc/udev/rules.d/51-trezor.rules"
check_file "overlay/usr/local/bin/touchscreen-setup.sh"

echo
echo "Checking CI/CD..."
check_dir ".github/workflows"
check_file ".github/workflows/build.yml"

echo
echo "Validating build script is executable..."
if [ -x "build.sh" ]; then
    echo "✅ build.sh is executable"
else
    echo "❌ build.sh is not executable"
    ((ERRORS++))
fi

echo
echo "Validating overlay scripts are executable..."
for script in overlay/usr/local/bin/*.sh; do
    if [ -x "$script" ]; then
        echo "✅ $script is executable"
    else
        echo "❌ $script is not executable"
        ((ERRORS++))
    fi
done

echo
echo "Checking for duplicate external.desc (should not exist in configs/)..."
if [ -f "br2-external/configs/external.desc" ]; then
    echo "❌ Duplicate external.desc found in br2-external/configs/"
    ((ERRORS++))
else
    echo "✅ No duplicate external.desc in configs/"
fi

echo
echo "=========================================="
if [ $ERRORS -eq 0 ]; then
    echo "✅ All validation checks passed!"
    echo "Repository structure is correct."
    exit 0
else
    echo "❌ Found $ERRORS error(s)"
    echo "Please fix the issues above."
    exit 1
fi
