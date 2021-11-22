#!/usr/bin/env bash

# ----------
# Developer: Recai Almaz (muddessir@outlook.com)
# ----------

source /etc/framework/conf/paths.h

# eger scp ile baglanti kuramiyorsak asagidaki dosyalari yanlislikla silmeyelim
# diye once bir tane test dosyasi download ediyoruz baglanti varsa devam ediyoruz.

scp -r master:$workdir/distro/etc/framework/tree.log /tmp || {
	exit 1;
}

# eski dosyalari silmeyince karisabiliyor.
rm -rf /etc/initramfs-tools/
rm -rf $workdir && mkdir -p $workdir

scp -r master:$workdir/distro/* /

[[ "$repo" == "yes" ]] && {
	scp master:$workdir/repo/buster/armhf/* /var/cache/apt/archives/;
}

[[ "$desktop" == "yes" ]] && {
	cp -r /etc/framework/files/desktop/* /;
}

[[ "$dev" == "yes" ]] && {
	cp -r /etc/framework/files/dev/* /;
}

[[ "$boot" == "yes" ]] && {
	mountpoint /boot && scp master:$workdir/sysroots/boot/* /boot && rm -f /boot/{initrd.cpio,boot.cmd};
}

if [[ "$uboot" == "yes" ]]
then
	block_dev=`lsblk -dpno pkname $(findmnt /boot -o SOURCE -n)`

	[[ ! -z "$block_dev" ]] && {
		scp master:$workdir/sysroots/boot/u-boot.imx /boot;
		dd if=/boot/u-boot.imx of=$block_dev bs=512 seek=2 conv=fsync;
	}
fi

[[ "$modules" == "yes" ]] && {
	rm -rf /lib/modules;
	scp -r master:$workdir/sysroots/lib/modules /lib;
}