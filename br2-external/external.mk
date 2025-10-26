# PitLab Wallet external package definitions

# Display Support
include $(BR2_EXTERNAL_PITLAB_WALLET_PATH)/package/rpi-fbcp/rpi-fbcp.mk

# Hardware Security
include $(BR2_EXTERNAL_PITLAB_WALLET_PATH)/package/trezord-go/trezord-go.mk
include $(BR2_EXTERNAL_PITLAB_WALLET_PATH)/package/trezor-emu/trezor-emu.mk

# Common package infrastructure
define PITLAB_WALLET_INSTALL_INIT_SYSTEMD
    $(INSTALL) -D -m 0644 $(BR2_EXTERNAL_PITLAB_WALLET_PATH)/package/pitlab-wallet/init/trezord.service \
        $(TARGET_DIR)/usr/lib/systemd/system/trezord.service
    $(INSTALL) -D -m 0644 $(BR2_EXTERNAL_PITLAB_WALLET_PATH)/package/pitlab-wallet/init/fbcp.service \
        $(TARGET_DIR)/usr/lib/systemd/system/fbcp.service
endef

# Board-specific package selection
ifeq ($(BR2_PACKAGE_PITLAB_WALLET),y)
    PITLAB_WALLET_DEPENDENCIES += trezord-go
    
    ifeq ($(BR2_PACKAGE_PITLAB_WALLET_DISPLAY),y)
        PITLAB_WALLET_DEPENDENCIES += rpi-fbcp
    endif
    
    ifeq ($(BR2_PACKAGE_PITLAB_WALLET_EMULATOR),y)
        PITLAB_WALLET_DEPENDENCIES += trezor-emu
    endif
endif