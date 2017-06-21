#
# Copyright (C) 2015 OpenWrt.org
# Copyright (C) 2017 LEDE project
#

SUBTARGET:=dap
BOARDNAME:=Octeon based D-LINK DAP models

define Target/Description
        Build factory image for D-LINK DAP models with Octeon processors
	NOTE: sysupgrade just uses factory images on these models
endef
