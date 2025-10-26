################################################################################
#
# trezord-go
#
################################################################################

TREZORD_GO_VERSION = v2.0.33
TREZORD_GO_SITE = $(call github,trezor,trezord-go,$(TREZORD_GO_VERSION))
TREZORD_GO_LICENSE = LGPL-3.0
TREZORD_GO_LICENSE_FILES = COPYING

TREZORD_GO_DEPENDENCIES = \
	host-go \
	libusb \
	eudev \
	hidapi \
	libsodium \
	openssl \
	zlib

TREZORD_GO_GOMOD = github.com/trezor/trezord-go

# Ensure reproducible builds and proper version info
TREZORD_GO_BUILD_TARGETS = version.go

# Build with Go and security flags
TREZORD_GO_MAKE_ENV = \
	$(GO_TARGET_ENV) \
	CGO_ENABLED=1 \
	GOOS=linux \
	GOARCH=$(GO_GOARCH) \
	CC=$(TARGET_CC) \
	CXX=$(TARGET_CXX) \
	CGO_CFLAGS="$(TARGET_CFLAGS) -D_FORTIFY_SOURCE=2 -fstack-protector-strong" \
	CGO_LDFLAGS="$(TARGET_LDFLAGS) -Wl,-z,now -Wl,-z,relro" \
	GOPROXY=https://proxy.golang.org,direct \
	GO111MODULE=on \
	VERSION=$(TREZORD_GO_VERSION)

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
