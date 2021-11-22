#!/usr/bin/env bash

# ----------
# Developer: Recai Almaz (muddessir@outlook.com)
# ----------

source /etc/framework/conf/paths.h

dir_rd="/tmp/initrd/"

# qemu'da 5.x kernel kullanirken ona ait modulleri yuklemek gerekebilir.
[[ -z "$kernel" ]] && kernel="5.10.78-rt55"

mkdir -p $dir_rd && {
	mkinitramfs -v -o $dir_rd/initrd.cpio $kernel;
	mkimage -A arm -O linux -T ramdisk -C gzip -n "Initrd file system" -d $dir_rd/initrd.cpio $dir_rd/initrd.uboot;
	mountpoint /boot && cp $dir_rd/initrd.uboot /boot;
}

[[ "${sync}" != "no" ]] && {
	scp $dir_rd/initrd.cpio $dir_rd/initrd.uboot master:$workdir/sysroots/boot;
}

exit 0
