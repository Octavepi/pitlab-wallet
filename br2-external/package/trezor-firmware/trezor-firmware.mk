################################################################################
#
# trezor-firmware
#
################################################################################

TREZOR_FIRMWARE_VERSION = v2.7.1
TREZOR_FIRMWARE_SITE = $(call github,trezor,trezor-firmware,$(TREZOR_FIRMWARE_VERSION))
TREZOR_FIRMWARE_LICENSE = LGPL-3.0
TREZOR_FIRMWARE_LICENSE_FILES = COPYING

TREZOR_FIRMWARE_DEPENDENCIES = python3 host-python-pipenv

# Build the Core emulator
define TREZOR_FIRMWARE_BUILD_CMDS
	cd $(@D)/core && \
		$(HOST_DIR)/bin/pipenv install && \
		$(HOST_DIR)/bin/pipenv run make build_unix
endef

define TREZOR_FIRMWARE_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/core/build/unix/trezor-emu-core \
		$(TARGET_DIR)/usr/local/bin/trezor-emu
	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_PI_TREZOR_PATH)/package/trezor-firmware/trezor-emu.service \
		$(TARGET_DIR)/etc/systemd/system/trezor-emu.service
	ln -sf ../trezor-emu.service \
		$(TARGET_DIR)/etc/systemd/system/graphical.target.wants/trezor-emu.service
endef

$(eval $(generic-package))
