################################################################################
#
# trezord-go
#
################################################################################

TREZORD_GO_VERSION = v2.0.33
TREZORD_GO_SITE = $(call github,trezor,trezord-go,$(TREZORD_GO_VERSION))
TREZORD_GO_LICENSE = LGPL-3.0
TREZORD_GO_LICENSE_FILES = COPYING

TREZORD_GO_DEPENDENCIES = host-go libusb libudev libhidapi

# Build with Go
TREZORD_GO_GOPATH = $(@D)/_gopath
TREZORD_GO_MAKE_ENV = \
	$(GO_TARGET_ENV) \
	CGO_ENABLED=1 \
	GOPATH=$(TREZORD_GO_GOPATH) \
	PATH=$(TREZORD_GO_GOPATH)/bin:$(BR_PATH)

define TREZORD_GO_BUILD_CMDS
	$(TREZORD_GO_MAKE_ENV) $(GO) build \
		-o $(@D)/trezord \
		-ldflags "-s -w" \
		$(@D)
endef

define TREZORD_GO_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/trezord \
		$(TARGET_DIR)/usr/local/bin/trezord
	$(INSTALL) -D -m 0644 $(BR2_EXTERNAL_PI_TREZOR_PATH)/package/trezord-go/trezord.service \
		$(TARGET_DIR)/etc/systemd/system/trezord.service
	ln -sf ../trezord.service \
		$(TARGET_DIR)/etc/systemd/system/multi-user.target.wants/trezord.service
endef

$(eval $(golang-package))
