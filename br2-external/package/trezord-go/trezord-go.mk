################################################################################
#
# trezord-go
#
################################################################################

TREZORD_GO_VERSION = v2.0.33
TREZORD_GO_SITE = $(call github,trezor,trezord-go,$(TREZORD_GO_VERSION))
TREZORD_GO_LICENSE = LGPL-3.0
TREZORD_GO_LICENSE_FILES = COPYING

TREZORD_GO_DEPENDENCIES = host-go libusb eudev hidapi

# Build with Go
TREZORD_GO_MAKE_ENV = \
	$(GO_TARGET_ENV) \
	CGO_ENABLED=1 \
	GOOS=linux \
	GOARCH=$(GO_GOARCH) \
	CC=$(TARGET_CC) \
	CXX=$(TARGET_CXX) \
	CGO_CFLAGS="$(TARGET_CFLAGS)" \
	CGO_LDFLAGS="$(TARGET_LDFLAGS)" \
	GOPROXY=https://proxy.golang.org,direct

define TREZORD_GO_BUILD_CMDS
	cd $(@D) && $(TREZORD_GO_MAKE_ENV) $(HOST_DIR)/bin/go build \
		-o trezord \
		-ldflags "-s -w" \
		.
endef

define TREZORD_GO_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/trezord \
		$(TARGET_DIR)/usr/local/bin/trezord
endef

$(eval $(golang-package))
