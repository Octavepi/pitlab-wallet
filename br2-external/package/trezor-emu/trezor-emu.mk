################################################################################
#
# trezor-emu
#
################################################################################

TREZOR_EMU_VERSION = 1.0
TREZOR_EMU_SITE = $(TREZOR_EMU_PKGDIR)/src
TREZOR_EMU_SITE_METHOD = local
TREZOR_EMU_LICENSE = LGPL-3.0
TREZOR_EMU_LICENSE_FILES = COPYING

TREZOR_EMU_DEPENDENCIES = sdl2 sdl2_image

define TREZOR_EMU_BUILD_CMDS
	$(MAKE) CC="$(TARGET_CC)" CFLAGS="$(TARGET_CFLAGS)" LDFLAGS="$(TARGET_LDFLAGS)" -C $(@D) all
endef

define TREZOR_EMU_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/trezor-emu $(TARGET_DIR)/usr/bin/trezor-emu
endef

$(eval $(generic-package))
