#!/bin/bash

# ----------
# Developer: Recai Almaz (muddessir@outlook.com)
# ----------

for x in $(cat /proc/cmdline)
do
	case $x in
		root=*)
			export root_fs=${x#root=}
		;;
		nfsroot=*)
			export nfsroot=${x#nfsroot=}
		;;
		protected_rootfs=*)
			export protected_rootfs=${x#protected_rootfs=}
		;;
		update_system=*)
			export update_system=${x#update_system=}
		;;
		no_wait=*)
			export no_wait=${x#no_wait=}
		;;
		automount=*)
			export automount=${x#automount=}
		;;
		master_image=*)
			export master_image=${x#master_image=}
		;;
		clone_emmc_to=*)
			export clone_emmc_to=${x#clone_emmc_to=}
		;;
		overlay_max_size=*)
			export overlay_max_size=${x#overlay_max_size=}
		;;
		mmcdev=*)
			export mmcdev=${x#mmcdev=}

			# eger cihaz sdcard ile boot edilirse ve kernel parametrelerinde
			# master_image=no degilse bu durumda degiskeni set ediyoruz ki
			# zb-update modulu master_image modunda acilsin. bkz: zb-update

			[[ "$mmcdev" == "0" && $(util_check_is_empty "$master_image") ]] && {
				export master_image=yes;
			}
		;;
	esac
done

# nfs uzerinden boot ediliyorsa haliyle update-system'in calismasina gerek yok.
if ! util_check_is_empty $nfsroot || [[ "$master_image" == "yes" ]]
then
	return 0
fi

# root_block_device degiskeni root_fs partitionunun hangi aygita bagli oldunu
# yani aygitin kendisinin ismini tespit eder. ornegin /dev/mmcblk2p2 isimli
# partition'un block_device_name'i /dev/mmcblk2 iken /dev/vda2 isimli 
# partitionun ise /dev/vda'dir. bu degiskeni kullanma sebebimiz /boot ve /home
# isimli klasorleri mount ederken dogru partitionu bulabilmek.
export root_block_device=$(lsblk -dpno pkname "$root_fs" 2>>$logfile)

util_check_is_empty $root_block_device && {
	println "error" "root_block_device tespit edilemedi.";
}

echo $root_block_device | grep -q "/dev/mmcblk" && {
	boot_fs="${root_block_device}p1";
	home_fs="${root_block_device}p3";
}

echo $root_block_device | grep -q "/dev/vda" && {
	boot_fs="/dev/vda1";
	home_fs="/dev/vda3";
}

echo $root_block_device | grep -q "/dev/hda" && {
	boot_fs="/dev/hda1";
	home_fs="/dev/hda3";
}

echo $root_block_device | grep -q "/dev/sda" && {
	boot_fs="/dev/sda1";
	home_fs="/dev/sda3";
}

[[ $(util_check_is_empty $boot_fs) || $(util_check_is_empty $root_fs) ]] && {
	println "error" "boot ve home partitionlar 'root_fs=$root_fs' ile tespit edilemedi.";
}

export boot_fs
export home_fs