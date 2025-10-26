################################################################################
#
# trezor-emu
#
################################################################################

TREZOR_EMU_VERSION = 2.0.0
TREZOR_EMU_SITE = $(TREZOR_EMU_PKGDIR)/src
TREZOR_EMU_SITE_METHOD = local
TREZOR_EMU_LICENSE = LGPL-3.0
TREZOR_EMU_LICENSE_FILES = COPYING
TREZOR_EMU_INSTALL_STAGING = YES

# Dependencies for display, input, and crypto
TREZOR_EMU_DEPENDENCIES = \
	sdl2 \
	sdl2_image \
	sdl2_ttf \
	libusb \
	hidapi \
	libsodium \
	openssl

# Required for proper display and input handling
TREZOR_EMU_CONF_ENV = \
	SDL_VIDEODRIVER=fbcon \
	SDL_FBDEV=/dev/fb0 \
	TSLIB_TSDEVICE=/dev/input/event0

# Build flags for security and optimization
TREZOR_EMU_CONF_OPTS = \
	-DCMAKE_BUILD_TYPE=Release \
	-DUSE_LIBUSB=ON \
	-DUSE_HIDAPI=ON \
	-DUSE_SDL=ON \
	-DUSE_SODIUM=ON

define TREZOR_EMU_BUILD_CMDS
	$(MAKE) CC="$(TARGET_CC)" CFLAGS="$(TARGET_CFLAGS)" LDFLAGS="$(TARGET_LDFLAGS)" -C $(@D) all
endef

define TREZOR_EMU_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/trezor-emu $(TARGET_DIR)/usr/bin/trezor-emu
endef

$(eval $(generic-package))
