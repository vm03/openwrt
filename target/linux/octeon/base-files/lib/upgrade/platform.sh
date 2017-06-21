#
# Copyright (C) 2014 OpenWrt.org
#

# TODO: split up into appropriate files
get_magic_at() {
        local mtddev=$1
        local pos=$2
        dd bs=1 count=2 skip=$pos if=$mtddev 2>/dev/null | hexdump -v -n 4 -e '1/1 "%02x"'
}

dap_check_image() {
	local model=$(cat /tmp/sysinfo/model)

	case "$model" in
	DAP-2590-A1)
		hdr_start_want="7761706e6430325f646b62735f646170323539300000000000000000000000002103082021030820"
		hdr_flags_want="0100000000000000"
		;;
	*)
		echo "Sysupgrade is not yet supported on $model."
		return 1
		;;
	esac

	local hdr_start=$(dd if="$1" bs=4 count=10 2>/dev/null | hexdump -v -n 40 -e '1/1 "%02x"')
	if [ -z "$hdr_start" ]; then
		echo "Could not get start of header"
		return 1
	fi

	local hdr_flags=$(dd if="$1" bs=4 skip=18 count=2 2>/dev/null | hexdump -v -n 8 -e '1/1 "%02x"')
	if [ -z "$hdr_flags" ]; then
		echo "Could not get header flags"
		return 1
	fi

	[ "$hdr_start" != "$hdr_start_want" -o "$hdr_flags" != "$hdr_flags_want" ] && {
		echo "Not a $model image."
		return 1
	}

	# Check the header has a valid factory image checksum
	local hdr_md5_want=$( (dd if="$1" bs=4 skip=27 count=9 2> /dev/null; dd if="$1" bs=160 skip=1 2> /dev/null) | md5sum -)
	hdr_md5_want="${hdr_md5_want%% *}"

	local hdr_md5=$(dd if="$1" bs=4 skip=36 count=4 2> /dev/null | hexdump -v -n 16 -e '1/1 "%02x"')

        if [ -n "$hdr_md5" -a -n "$hdr_md5_want" ] && [ "$hdr_md5" = "$hdr_md5_want" ]; then
            return 0
	fi

	echo "Image file checksum incorrect."
	return 1
}

dap_do_flash_fixwrgg() {
	local sq_offset=$(hexdump -v -e '1/0 "%_ax" 1/4 " %04x" 1/65532 "\n"' "$1" | grep '0000 68737173')
	sq_offset="0x${sq_offset%% 68737173}"

	local append=""
	[ -f "$CONF_TAR" -a "$SAVE_CONFIG" -eq 1 ] && append="-j $CONF_TAR"

	echo "Writing $1 to 'firmware'"
        mtd $append write $1 firmware || return $?
	echo "Fixing header to keep bootloader from checksumming filesystems"
	mtd -r -c $sq_offset fixwrgg firmware || return $?
	return 0
}

dap_do_upgrade() {
	local factory_img="$1"
	local model=$(cat /tmp/sysinfo/model)

	case "$model" in
	DAP-2590-A1)
		dap_do_flash_fixwrgg $factory_img
		return $?
		;;
	*)
		return 1
		;;
	esac
}

platform_get_rootfs() {
	local rootfsdev

	if read cmdline < /proc/cmdline; then
		case "$cmdline" in
			*block2mtd=*)
				rootfsdev="${cmdline##*block2mtd=}"
				rootfsdev="${rootfsdev%%,*}"
			;;
			*root=*)
				rootfsdev="${cmdline##*root=}"
				rootfsdev="${rootfsdev%% *}"
			;;
		esac

		echo "${rootfsdev}"
	fi
}

platform_copy_config() {
	case "$(board_name)" in
	erlite)
		mount -t vfat /dev/sda1 /mnt
		cp -af "$CONF_TAR" /mnt/
		umount /mnt
		;;
	esac
}

platform_do_flash() {
	local tar_file=$1
	local board=$2
	local kernel=$3
	local rootfs=$4

	mkdir -p /boot
	mount -t vfat /dev/$kernel /boot

	[ -f /boot/vmlinux.64 -a ! -L /boot/vmlinux.64 ] && {
		mv /boot/vmlinux.64 /boot/vmlinux.64.previous
		mv /boot/vmlinux.64.md5 /boot/vmlinux.64.md5.previous
	}

	echo "flashing kernel to /dev/$kernel"
	tar xf $tar_file sysupgrade-$board/kernel -O > /boot/vmlinux.64
	md5sum /boot/vmlinux.64 | cut -f1 -d " " > /boot/vmlinux.64.md5
	echo "flashing rootfs to ${rootfs}"
	tar xf $tar_file sysupgrade-$board/root -O | dd of="${rootfs}" bs=4096
	sync
	umount /boot
}

platform_do_upgrade() {
	local tar_file="$1"
	local board=$(board_name)
	local rootfs="$(platform_get_rootfs)"
	local kernel=

	[ -b "${rootfs}" ] || return 1
	case "$board" in
	er)
		kernel=mmcblk0p1
		;;
	erlite)
		kernel=sda1
		;;
	wapnd02)
		dap_do_upgrade $1
		return $?
		;;
	*)
		return 1
	esac

	platform_do_flash $tar_file $board $kernel $rootfs

	return 0
}

platform_check_image() {
	local board=$(board_name)

	case "$board" in
	er | \
	erlite)
		local tar_file="$1"
		local kernel_length=`(tar xf $tar_file sysupgrade-$board/kernel -O | wc -c) 2> /dev/null`
		local rootfs_length=`(tar xf $tar_file sysupgrade-$board/root -O | wc -c) 2> /dev/null`
		[ "$kernel_length" = 0 -o "$rootfs_length" = 0 ] && {
			echo "The upgrade image is corrupt."
			return 1
		}
		return 0
		;;
	wapnd02)
		dap_check_image $1
		return $?
		;;
	esac

	echo "Sysupgrade is not yet supported on $board."
	return 1
}
