#
# Copyright (C) 2009-2010 OpenWrt.org
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

# Ubiquiti.  Uses a removable flash drive.

define Device/Default
  PROFILES = Default $$(DEVICE_NAME)
  KERNEL_NAME := vmlinux.elf
  KERNEL_INITRAMFS_NAME := vmlinux-initramfs.elf
  KERNEL := kernel-bin | strip-kernel | patch-cmdline
  IMAGES := sysupgrade.tar
  IMAGE/sysupgrade.tar/squashfs := append-rootfs | pad-extra 128k | sysupgrade-tar rootfs=$$$$@
  IMAGE/sysupgrade.tar := sysupgrade-tar
endef

define Build/strip-kernel
	# Workaround pre-SDK-1.9.0 u-boot versions not handling the .notes section
	$(TARGET_CROSS)strip -R .notes $@ -o $@.stripped && mv $@.stripped $@
endef

define Device/generic
  FILESYSTEMS := ext4
  DEVICE_TITLE := Generic
endef
ifeq ($(SUBTARGET),ubiquiti)
TARGET_DEVICES += generic
endif

ER_CMDLINE:=-mtdparts=phys_mapped_flash:640k(boot0)ro,640k(boot1)ro,64k(eeprom)ro root=/dev/mmcblk0p2 rootfstype=squashfs,ext4 rootwait
define Device/er
  CMDLINE := $(ER_CMDLINE) 
  DEVICE_TITLE := Ubiquiti EdgeRouter
endef
ifeq ($(SUBTARGET),ubiquiti)
  TARGET_DEVICES += er
endif

ERLITE_CMDLINE:=-mtdparts=phys_mapped_flash:512k(boot0)ro,512k(boot1)ro,64k(eeprom)ro root=/dev/sda2 rootfstype=squashfs,ext4 rootwait
define Device/erlite
  CMDLINE := $(ERLITE_CMDLINE) 
  DEVICE_TITLE := Ubiquiti EdgeRouter Lite
endef
ifeq ($(SUBTARGET),ubiquiti)
  TARGET_DEVICES += erlite
endif

# D-LINK DAP.  Uses a WRGG-style factory image.

define Build/mkwrggimg
        $(STAGING_DIR_HOST)/bin/mkwrggimg -b -f 1 \
                -i $@ -o $@.imghdr -d /dev/mtdblock/1 \
                -m $(BOARDNAME) -s $(DAP_SIGNATURE) \
                -v LEDE -B $(REVISION)
        mv $@.imghdr $@
endef

define Build/wrgg-pad-rootfs
  # DAP-2590 can have an eraseblock size of either 64k or 128k depending
  # on the production run.  Those shipped with v1.20 firmware use 128k.
  $(STAGING_DIR_HOST)/bin/padjffs2 $(IMAGE_ROOTFS) -c 64 128 >>$@
endef

define Device/dap-2590-a2
  DEVICE_TITLE := D-Link DAP-2590 rev. A2
  DEVICE_PACKAGES := kmod-ath9k
  BOARDNAME = DAP-2590-A1
  # No need for a sysupgrade.bin, we taught sysupgrade to work with factory images
  IMAGES := factory.img
  IMAGE_SIZE = 15616k

  # TODO: Figure out a tighter upper bound on the lzma to not waste space
  # after the kernel.  Will have to produce the lzma, pad for possible compression
  # differences as the cmdline needs to be altered to tighten rootfs partition,
  # then build the real image with the new cmdline.

  # langpack and perhaps misc might be safe to alter
  # ...the latter because it is a subpartition of the OEM "upgrade" partition
  MTDPARTS = phys_mapped_flash:13568k@2688k(rootfs),15616k@640k(firmware),128k@384k(rgdb)ro,128k@256k(bdcfg)ro,128k@512k(langpack),128k@16256k(misc)ro,16384k@0k(flash)ro,256k@0k(bootloader)ro,128k@256k(bootconfig)ro

  CONSOLE = ttyS0,115200
  CMDLINE := board=$$(BOARDNAME) mtdparts=$$(MTDPARTS) console=$$(CONSOLE) netconsole=4444@192.168.1.50/,4444@192.168.1.250/ root=/dev/mtdblock0 debug
  DAP_SIGNATURE := wapnd02_dkbs_dap2590
  DEVICE_VARS += DAP_SIGNATURE CMDLINE
  KERNEL := kernel-bin | strip-kernel | patch-cmdline | lzma
  KERNEL_INITRAMFS := $$(KERNEL) | mkwrggimg

  IMAGE/factory.img = append-kernel | pad-offset 2097152 160 | check-size 2097152 | append-rootfs | wrgg-pad-rootfs | mkwrggimg | check-size $$$$(IMAGE_SIZE)

endef
ifeq ($(SUBTARGET),dap)
  TARGET_DEVICES += dap-2590-a2
endif

$(eval $(call BuildImage))
