################################################################################
#
# trezor-emu
#
################################################################################

TREZOR_EMU_VERSION = 77d3264b3ca48d794acda76887740232d49acd4b
TREZOR_EMU_SITE = $(call github,trezor,trezor-firmware,$(TREZOR_EMU_VERSION))
TREZOR_EMU_LICENSE = LGPL-3.0
TREZOR_EMU_LICENSE_FILES = COPYING

TREZOR_EMU_DEPENDENCIES = python3 host-python3

# Build the Core emulator only
define TREZOR_EMU_BUILD_CMDS
	cd $(@D)/core && \
		ln -sf $(HOST_DIR)/bin/python3 $(HOST_DIR)/bin/python && \
		PATH="$(HOST_DIR)/bin:$$PATH" \
		PYTHON="$(HOST_DIR)/bin/python3" \
		make build_unix
endef

define TREZOR_EMU_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/core/build/unix/trezor-emu-core \
		$(TARGET_DIR)/usr/local/bin/trezor-emu
	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_PITLAB_WALLET_PATH)/package/trezor-emu/trezor-emu.service \
		$(TARGET_DIR)/etc/systemd/system/trezor-emu.service
	ln -sf ../trezor-emu.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/trezor-emu.service
endef

$(eval $(generic-package))
