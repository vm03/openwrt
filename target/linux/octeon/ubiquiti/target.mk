#
# Copyright (C) 2015 OpenWrt.org
# Copyright (C) 2017 LEDE project
#

SUBTARGET:=ubiquiti
BOARDNAME:=Ubiquiti ER and ERLITE Octeon based systems

define Target/Description
        Build firmware image for Ubiquiti octeon based devices
endef

DEFAULT_PACKAGES += mkf2fs e2fsprogs
