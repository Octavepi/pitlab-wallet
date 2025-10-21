################################################################################
#
# rpi-fbcp
#
################################################################################

RPI_FBCP_VERSION = 20160602
RPI_FBCP_SITE = $(call github,tasanakorn,rpi-fbcp,$(RPI_FBCP_VERSION))
RPI_FBCP_LICENSE = MIT
RPI_FBCP_LICENSE_FILES = LICENSE
RPI_FBCP_DEPENDENCIES = rpi-userland

define RPI_FBCP_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D) \
		CFLAGS="$(TARGET_CFLAGS) -I$(STAGING_DIR)/usr/include -I$(STAGING_DIR)/usr/include/interface/vcos/pthreads -I$(STAGING_DIR)/usr/include/interface/vmcs_host/linux" \
		LDFLAGS="$(TARGET_LDFLAGS) -L$(STAGING_DIR)/usr/lib"
endef

define RPI_FBCP_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/fbcp $(TARGET_DIR)/usr/local/bin/fbcp
endef

$(eval $(generic-package))
