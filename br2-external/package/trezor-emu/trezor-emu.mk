################################################################################
#
# trezor-emu
#
################################################################################

TREZOR_EMU_VERSION = 77d3264b3ca48d794acda76887740232d49acd4b
TREZOR_EMU_SITE = $(call github,trezor,trezor-firmware,$(TREZOR_EMU_VERSION))
TREZOR_EMU_LICENSE = LGPL-3.0
TREZOR_EMU_LICENSE_FILES = COPYING

TREZOR_EMU_DEPENDENCIES = host-python3 host-python-setuptools host-python-pip host-openssl

# Pre-build steps to ensure layout parser is available
define TREZOR_EMU_CONFIGURE_CMDS
	cd $(@D)/core && \
		$(HOST_DIR)/bin/python3 -m pip install --no-deps --target=$(HOST_DIR)/lib/python3.11/site-packages click protobuf && \
		PYTHONPATH=$(HOST_DIR)/lib/python3.11/site-packages \
		$(HOST_DIR)/bin/python3 ./tools/make_utterances.py
endef

# Build the Core emulator only
define TREZOR_EMU_BUILD_CMDS
	cd $(@D)/core && \
		PATH=$(BR_PATH) \
		PYTHON=$(HOST_DIR)/bin/python3 \
		PYTHON_PATH=$(HOST_DIR)/lib/python3.11/site-packages \
		make build_unix
endef

define TREZOR_EMU_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/core/build/unix/trezor-emu-core \
		$(TARGET_DIR)/usr/local/bin/trezor-emu
endef

$(eval $(generic-package))
