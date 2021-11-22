# ----------
# Developer: Recai Almaz (muddessir@outlook.com)
# ----------

echo "[>] --------------------------"
echo "[>] ra technology 2021"

# environment: uboot kaynak kodlarinda env_file env.cmd olarak tanimlandi.
# eger env elle yuklenip degistirildiyse, tekrar burada yukleyip override etmemek icin
# env_is_loaded degiskeni kullanilmakta.

if test "${env_is_loaded}" != "yes"
then
	if fatload mmc ${mmcdev}:${mmcpart} ${loadaddr} ${env_file}; then
		env import -t ${loadaddr} ${filesize} && echo "[+] environment yuklendi."
	else
		echo "[-] environment yukleme basarisiz."
	fi
fi

# root file system istenirse readonly olarak acilabiliyor.
setenv cmdline_append "${cmdline_append} ${silent} protected_rootfs=${protected_rootfs}"

# eger sdcard'tan boot edilmisse burada butun loglari ekrana vermemiz gerekli
if test "${mmcdev}" = "0"
then
	if test "${master_image}" = "yes"; then
		setenv console_append "${console_append} master_image=yes"
	else
		setenv console ttymxc0
		setenv console_append "${console_append} console=tty1,115200"
	fi
fi

# sistemi boot ederken initrd hangi mmc disk ile baslatildigini
# tespit edip master image ile diski formatlamaya karar veriyor.
setenv cmdline_append "${cmdline_append} mmcdev=${mmcdev} fbcon=rotate:${rotate}"
setenv boot_mmc_args "${console_append} console=${console},${baudrate} ${smp} root=${mmcroot} ${cmdline_append}"
setenv boot_nfs_args "${console_append} console=${console},${baudrate} ${smp} root=/dev/nfs ${cmdline_append} nfsroot=${serverip}:${nfsroot},v3,tcp rw ip=dhcp"

if test "${boot_mode}" = "default"; 
then
	echo "[>] mmc ile boot ediliyor."
	
	# kernel
	fatload mmc ${mmcdev}:${mmcpart} ${loadaddr} ${image} && echo "[+] kernel yuklendi."

	# initrd
	if test "${initrd}" != "no"; then
		fatload mmc ${mmcdev}:${mmcpart} ${initrd_addr} ${initrd_file} && echo "[+] initrd yuklendi."
	fi

	# device-tree
	fatload mmc ${mmcdev}:${mmcpart} ${fdt_addr} ${devtree_file} && echo "[+] device-tree yuklendi."
	
	setenv bootargs ${boot_mmc_args}
fi

# not: ${get_cmd} komutu uboot kaynak kodlarinda tanimli. eger env icerisindeki
# ip_dyn degiskeni yes ise dhcp ile ile ip alip akabinde network download islemi
# yaparken tanimli degilse ipaddr olarak tanimlanan ip ile network down. yapar.

if test "${ip_dyn}" = "yes"; then
	setenv get_cmd "dhcp"
else
	setenv get_cmd "tftp"
fi

if test "${boot_mode}" = "nfs"
then
	echo "[>] network uzerinden boot ediliyor."

	${get_cmd} ${loadaddr} ${image}
	${get_cmd} ${fdt_addr} ${devtree_file}

	if test "${initrd}" != "no";
	then
		${get_cmd} ${initrd_addr} ${initrd_file}
	fi
	
	setenv bootargs ${boot_nfs_args}
fi

# nfs hem kernel hem de rootfs'i network uzerinden boot ederken
# tftp yalnizca kernel, device-tree ve initrd'yi network ile
# indirir rootfs olarak som ustunde mevcut olani kullanir.

if test "${boot_mode}" = "tftp"
then
	echo "[>] kernel network uzerinden indiriliyor."

	${get_cmd} ${loadaddr} ${image}
	${get_cmd} ${fdt_addr} ${devtree_file}

	if test "${initrd}" != "no"; then
		${get_cmd} ${initrd_addr} ${initrd_file}
	fi

	setenv bootargs ${boot_mmc_args}
fi

if test "${initrd}" != "no"; then
	bootz ${loadaddr} ${initrd_addr} ${fdt_addr}
else
	bootz ${loadaddr} - ${fdt_addr}
fi

echo "[>] --------------------------"
