# == AI INSTRUCTION: FULL Pi-Trezor BUILD SYSTEM (Dynamic Multi-Board & Display) ==
# Goal:
#   Build a reproducible GitHub repository that cross-compiles and packages an
#   air-gapped Raspberry Pi wallet appliance called Pi-Trezor.
#   It runs the Trezor Core (emulator) and trezord-go bridge on a minimal
#   Buildroot OS, boots directly into those services, and exposes only USB
#   for Trezor Suite integration.

# --- Build environment ---
#   Host: Ubuntu 24.04 (Noble) on Sony VAIO
#   Target: Raspberry Pi 3 / 4 / 5 (ARM 32-bit or 64-bit)
#   Cross-compile: aarch64-linux-gnu or arm-linux-gnueabihf

# --- Build script behavior ---
#   build_pi-trezor.sh must accept:
#       --board <pi3|pi4|pi5>
#       --display <waveshare35a|waveshare32b|hdmi|vc4-kms-v3d|custom>
#       --rotation <0|90|180|270>
#
#   Example:
#       ./build_pi-trezor.sh --board pi4 --display waveshare35a --rotation 90
#
#   Defaults:
#       board = pi4
#       display = waveshare35a
#       rotation = 180
#
#   Responsibilities:
#     • Install host deps (build-essential, golang-go, protobuf-compiler,
#        libusb-1.0-0-dev, libudev-dev, libhidapi-dev, gcc-aarch64-linux-gnu,
#        rsync, qemu-user-static)
#     • Cross-compile trezord-go → GOOS=linux GOARCH=arm64
#     • Cross-compile Trezor Core (emulator) → make ARCH=arm64 BOARD=unix CROSS_COMPILE=aarch64-linux-gnu-
#     • Copy both binaries into overlay/usr/local/bin/
#     • Select the proper Buildroot defconfig for the chosen board
#     • Include Raspberry Pi firmware, kernel, overlays, and touchscreen drivers
#     • Invoke post_image.sh to patch /boot/config.txt with dtoverlay + rotation
#     • Output image under ./output/images/sdcard.img

# --- Buildroot configuration requirements ---
#   Always enable:
#       BR2_PACKAGE_RPI_FIRMWARE=y
#       BR2_PACKAGE_RPI_USERLAND=y
#       BR2_LINUX_KERNEL_CUSTOM_VERSION_VALUE="6.6"
#       BR2_LINUX_KERNEL_USE_DEFCONFIG=y
#       BR2_TARGET_ROOTFS_READ_ONLY=y
#       BR2_PACKAGE_SYSTEMD=y
#       BR2_PACKAGE_LIBUSB=y
#       BR2_PACKAGE_LIBUDEV=y
#       BR2_PACKAGE_LIBHIDAPI=y
#       BR2_PACKAGE_TSLIB=y
#       BR2_PACKAGE_INPUTATTACH=y
#       Disable all networking (no SSH, Wi-Fi, Ethernet, DHCP, etc.)

# --- Kernel touchscreen fragment ---
#   kernel_touchscreen.fragment adds:
#       CONFIG_INPUT_TOUCHSCREEN=y
#       CONFIG_TOUCHSCREEN_ADS7846=y
#       CONFIG_FB_TFT=y
#       CONFIG_FB_TFT_ILI9341=y
#   Included via:
#       BR2_LINUX_KERNEL_CONFIG_FRAGMENT_FILES="configs/kernel_touchscreen.fragment"

# --- Mapping table (for Copilot reference) ---
#   | Board | Buildroot defconfig            | Kernel defconfig    | DT base | Notes |
#   |-------|--------------------------------|---------------------|---------|--------|
#   | pi3   | raspberrypi3_defconfig        | bcm2709_defconfig   | bcm2709 | 32-bit |
#   | pi4   | raspberrypi4_64_defconfig    | bcm2711_defconfig   | bcm2711 | 64-bit |
#   | pi5   | raspberrypi5_defconfig       | bcm2712_defconfig   | bcm2712 | 64-bit |

# --- Overlay / firmware handling rules ---
#   • Always include Raspberry Pi kernel and firmware so /boot/overlays/ contains all .dtbo files.
#   • build_pi-trezor.sh accepts --board, --display, --rotation arguments.
#   • No static list of displays is needed because rpi-firmware supplies every overlay.

#   post_image.sh must:
#     1️⃣ Mount the boot partition of the built image.
#     2️⃣ Remove any existing dtoverlay lines to prevent bloat:
#           sed -i '/^dtoverlay=/d' config.txt
#     3️⃣ Verify that /boot/overlays/${DISPLAY}.dtbo exists.
#           • If exists → append:
#              dtoverlay=${DISPLAY},rotate=${ROTATION},speed=32000000,fps=60
#           • If not exists → warn and skip overlay injection.
#     4️⃣ If display == hdmi → append:
#           dtoverlay=vc4-kms-v3d
#           hdmi_force_hotplug=1
#           framebuffer_width=800
#           framebuffer_height=480
#     5️⃣ Unmount, sync, finalize image.

#   • Result: the image retains only the selected overlay and rotation settings,
#      with no unnecessary entries or files left behind.

#   • Example:
#       ./build_pi-trezor.sh --board pi5 --display ili9341 --rotation 270
#       → post_image.sh injects:
#           dtoverlay=ili9341,rotate=270,speed=32000000,fps=60
#           (and removes others)

# --- Udev rules additions ---
#   51-trezor.rules → standard Trezor USB IDs
#   95-touchscreen.rules → link touchscreen device nodes (e.g. /dev/input/touchscreen)

# --- Touchscreen calibration ---
#   Include tslib + ts_calibrate binary.
#   Add systemd service to run calibration on first boot.

# --- Security / hardening ---
#   • Rootfs read-only
#   • /tmp and /var/log as tmpfs
#   • No network modules compiled
#   • modules_disabled=1 after boot
#   • No root password / console-only access
#   • trezord-go + trezor-emu autostart
#   • Passphrase acts as software secure element
#   • Entire system offline (USB only)

# --- Expected output ---
#   • ./build_pi-trezor.sh builds everything for the specified board/display/rotation.
#   • ./output/images/sdcard.img ready to flash.
#   • Pi boots → starts trezord-go + trezor-emu + touchscreen UI.
#   • Recognized by Trezor Suite over USB.

# --- Optional extras for Copilot ---
#   • GitHub Actions workflow for automated reproducible builds.
#   • Hash verification script for sdcard.img.

# --- Copilot Objective ---
#   Generate the correct repository layout, all scripts, overlay files, config fragments, and documentation so that:
#     1️⃣ build_pi-trezor.sh handles arguments for board, display, rotation.
#     2️⃣ post_image.sh injects dtoverlay and rotation dynamically and cleans others.
#     3️⃣ kernel_touchscreen.fragment enables drivers.
#     4️⃣ Overlay + systemd units autostart trezord-go and trezor-emu.
#     5️⃣ Final image is air-gapped, reproducible, and touchscreen-functional on boot.

# === END INSTRUCTION ===