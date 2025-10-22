################################################################################
#
# trezor-emu
#
################################################################################

TREZOR_EMU_VERSION = 77d3264b3ca48d794acda76887740232d49acd4b
TREZOR_EMU_SITE = $(call github,trezor,trezor-firmware,$(TREZOR_EMU_VERSION))
TREZOR_EMU_LICENSE = LGPL-3.0
TREZOR_EMU_LICENSE_FILES = COPYING

TREZOR_EMU_DEPENDENCIES = host-python3

# Build the Core emulator only
define TREZOR_EMU_BUILD_CMDS
	cd $(@D)/core && \
		PYTHON="python3" \
		make build_unix
endef

define TREZOR_EMU_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/core/build/unix/trezor-emu-core \
		$(TARGET_DIR)/usr/local/bin/trezor-emu
endef

$(eval $(generic-package))
