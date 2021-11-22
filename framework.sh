#!/bin/bash

# ----------
# Developer: Recai Almaz (muddessir@outlook.com)
# TODO: encrypt ve tar ile compress etme islemleri fonksiyonlara tasinacak.
# ----------

# butun dosyalarin bulundugu klasoru mutlaka buraya hardcoded olarak tebdiren
# yaziyoruz ki farkli dizinlerden dosyalara erisirken path hatasi ile karsilasmayalim.
export workdir="/opt/framework"

source $workdir/include/lib.h
source $workdir/include/functions.h

case ${1} in
	--help)
		usage
		exit $success
	;;
	--workdir)
		echo "export workdir=$workdir"
		exit $success
	;;
	--source)
		echo "source $workdir/framework.sh $(util_nvl $2 'dev') source"
		exit $success
	;;
	--prepare)
		bash -c "$workdir/framework.sh core do_prepare_host"
		exit $success
	;;
esac

# butun degiskenlerin tanimli oldugu header
source $workdir/include/header.h

# usage: `./framework.sh desktop do_bootstrap do_second_stage do_create_img do_run_qemu`
function main() {

	[[ "$1" != "core" && "$1" != "desktop" && "$1" != "dev" ]] && {
		println "error" "bu script'in ilk parametresi distro tipi olmali. yani 'core' 'desktop' veya 'dev'.";
		exit $failed;
	}

	# `framework --source` komutu calistirilinca bu script
	# aktif terminale include ediliyor dolayisiyla butun degiskenler
	# o terminalde kullanilabiliyor. ornegin cd $workdir dedigimizde 
	# framework klasorune gidiyoruz.
	[[ "$2" == "source" ]] && {
		return $success;
	}

	# scripte girilen parametrelerin 
	# ilki haric hepsi anlamina gelir.
	args=${@:2}

	# argument parser
	for item in $args
	do
		# girilen parametre = iceriyorsa
		# parametreyi bu scriptte kullanilacak bir degisken
		# olarak set eder.
		if [[ "$item" == *"="* ]]
		then
			local param="${item%=*}"
			local value="${item#$param=}"
			export "$param"="$value"
		else
			run_as_function=$(util_trim "$run_as_function $item")
		fi
	done

	# frameworkun calismasi icin gerekli olan programlarin yuklu olup
	# olmadigini check eder. not: do_prepare_host calistirilirken gerek yok.
	if echo "$run_as_function" | grep -q 'do_prepare_host'
	then
		do_prepare_host

		# do_prepare_host yapiyoruz asagida tekrar yapmamak icin string remove islemidir.
		run_as_function=${run_as_function//do_prepare_host/}
	else
		do_sanity_check || return $failed;
	fi

	# girilen fonksiyonlari teker teker cagirir.
	for i in $run_as_function; do
		type "${i}" &>/dev/null && ${i}
	done;
}

# framework'un calisabilmesi icin gerekli olan package'lar
function do_prepare_host() {

	sudo apt-get install -y -m build-essential jq debootstrap dosfstools \
		remmina openvpn dialog pv git minicom bc lzop tree parted openssl tar \
		debian-archive-keyring binfmt-support \
		qemu-system-arm qemu-kvm qemu-user qemu-user-static u-boot-tools \
		rpcbind tftpd libsdl2-dev libsdl2-2.0-0 \
		gdb-multiarch gcc-aarch64-linux-gnu gcc-8-arm-linux-gnueabihf g++-8-arm-linux-gnueabihf \
		pkg-config-arm-linux-gnueabihf pkg-config-arm-linux-gnueabi \
		;

	# nfs ve tftp ile network uzerinden cihazlari boot etmek icin
	# yaptigimiz ayarlari icerir.
	sudo cp -r $workdir/host/* /

	# bu framework'u usr/bin altina linkleyip bash_completion atiyoruz ki
	# her yerden erisebilelim ve path sorunumunuz olmasin.
	sudo rm -f /usr/bin/framework
	sudo ln -s $workdir/framework.sh /usr/bin/framework

	echo ""
	println "warning" "####################################################################### "
	println "info" "bu uygulama cok fazla sudo kullaniyor haliyle her seferinde terminalden"
	println "info" "sifre girmemek icin /etc/sudoers dosyasina asagidaki ifadeyi ekleyiniz"
	println "info" "YOUR_USERNAME_HERE ALL=(ALL) NOPASSWD: ALL"
	println "info" "https://askubuntu.com/questions/147241/execute-sudo-without-password#147265"
	println "warning" "####################################################################### "
	echo ""
}

# debian tabanli distro olusturma islemi
function do_bootstrap() {

	# debootstrap ile daha once kurulum yapildiysa ayni klasoru yanlislikla bozmayalim.
	count_of_files_in_rootfs=$(ls $rootfs_dir/ | wc -l)

	[[ $count_of_files_in_rootfs -gt 10 ]] && {
		println "error" "zaten kurulum yapilmis.";
		return $failed;
	}

	packages="bash-completion,gawk,tar,sudo,pv,dialog,mc,tree,jq,wget,nano,file,fuse,libfuse2"
	packages="$packages,cron,apt-utils,locales,logrotate,console-data,console-setup,tzdata"
	packages="$packages,udev,hwinfo,usbutils,dbus,net-tools,screen,minicom,dosfstools,parted,acpid"
	packages="$packages,network-manager,iputils-ping,wireless-tools,isc-dhcp-client,wvdial"
	packages="$packages,python3,openssl,openssh-server,dconf-cli"
	
	[[ "$release_name" != "jessie" ]] && {
		packages="$packages,gpg,neofetch";
	}

	# distro icinden cikarilacak paketler. bunlari daha sonra istege gore yukleyecegiz
	exclude="openssh-sftp-server,rsyslog"
	variant="minbase"

	# olusacak distroya gore farkli imajlar mevcut.
	case $distro_type in
		dev)
			packages="$packages,build-essential,u-boot-tools,initramfs-tools,mtd-utils"
			packages="$packages,git,cmake,meson,libsqlite3-0,libsqlite3-dev,pkg-config"
			variant="buildd"
		;;
	esac

	# parametre girilince extract etmez.
	# repodan sadece deb indirmek icin kullaniyoruz.
	[[ "$download_only" == "1" ]] && foreign="--download-only" || foreign="--foreign"

	# eger extra_packeges parametresi bu script cagrilirken export ile set 
	# edilmisse onlari kurar. genelde yukariya hardcode olarak yazilmak
	# istemedigimiz uygulamalari test ederken kullaniyoruz.
	util_check_is_empty "$extra_packages" || packages="$packages,$extra_packages"

	# distroyu ubuntu veya debian olarak secmek mumkun. ubuntu tabanli test edilmedi.
	if [[ "$base" == "ubuntu" ]]
	then
		components="main,multiverse,universe"
		repo="http://ports.ubuntu.com/ubuntu-ports"
	elif [[ "$base" == "ubuntu-old" ]]
	then
		components="main,multiverse,universe"
		repo="http://old-releases.ubuntu.com/ubuntu/"
		packages=$(util_replace_str "$packages" ",meson")
		packages=$(util_replace_str "$packages" ",gpg")
		packages=$(util_replace_str "$packages" ",jq")
		packages=$(util_replace_str "$packages" ",neofetch")
		packages=$(util_replace_str "$packages" ",dconf-cli")
	else
		components="main,contrib"
		repo="https://deb.debian.org/debian"
	fi

	# klasor mevcut degilse
	mkdir -p $workdir/repo/$release_name/$arch;
	bootstrap_arch=$arch

	[[ "$arch" == "aarch64" ]] && {
		bootstrap_arch="arm64";
	}

	eval "sudo debootstrap " \
		"--components=$components " \
		"--no-check-certificate --no-check-gpg " \
		"--verbose $foreign " \
		"--arch=$bootstrap_arch " \
		"--variant=$variant " \
		"--cache-dir=$workdir/repo/$release_name/$arch " \
		"--include=$packages " \
		"--exclude=$exclude $release_name $rootfs_dir $repo " \
	|| return $failed

	return $success
}

# do_bootstrap calistiktan sonra olusan isletim sistemi arm oldugu icin
# chroot ile second-stage denilen islem yapilarak kurulum tamamlaniyor.
function do_second_stage() {

	# chroot ile second-stage yapilmak istenirse bu binary gerekli.
	local qemu_static="/usr/bin/qemu-arm-static"

	[[ "$arch" != "armhf" ]] && {
		qemu_static="/usr/bin/qemu-${arch}-static";
	}

	sudo cp "$qemu_static" $rootfs_dir/usr/bin/
	sudo cp "$workdir/distro/etc/apt/sources-$release_name.ls" $rootfs_dir/etc/apt/sources.list

	sudo chroot $rootfs_dir /bin/bash -c " \
		export LANGUAGE=en_US.UTF-8;
		export LANG=en_US.UTF-8;
		if [[ -e /debootstrap/debootstrap ]]
		then
			/debootstrap/debootstrap --second-stage --verbose;
			dpkg-reconfigure -f noninteractive tzdata;
			sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen;
			sed -i -e 's/# tr_TR.UTF-8 UTF-8/tr_TR.UTF-8 UTF-8/' /etc/locale.gen;
			echo 'LANG=\"en_US.UTF-8\"'>/etc/default/locale;
			dpkg-reconfigure --frontend=noninteractive locales;
			update-locale LANG=en_US.UTF-8;
			echo 'Europe/Istanbul' > /etc/timezone;
			unlink /etc/localtime && ln -s /usr/share/zoneinfo/Etc/GMT-3 /etc/localtime;
			passwd -d root;
			dpkg --configure -a;
		fi;
	echo 'finish.';"

	# distro'ya ait ozellestirilmis dosyalar.
	[[ -d $workdir/distro/ ]] && sudo cp -r $workdir/distro/* $rootfs_dir/ >/dev/null

	# kernel modulleri
	[[ -d $workdir/sysroots/lib/modules/$kernel_version ]] && {
		sudo cp -r $workdir/sysroots/lib/* $rootfs_dir/lib;
	}

	# hangi distroyu olusturuyorsak onun image.sign dosyasina onu yaziyoruz.
	value=$(eval "sudo jq '.distro_type = \""$distro_type"\"' $rootfs_dir/var/system/image.sys")
	
	util_check_is_empty $value || {
		echo $value | sudo tee $rootfs_dir/var/system/image.sys >/dev/null;
	}

	#sudo sed -i "s/buster/$release_name/g" $rootfs_dir/etc/apt/sources.list

	sudo chroot $rootfs_dir /bin/bash -c "/etc/framework/first-boot-core.sh";

	return $success
}

# hem sdcard'lara yazilan hem de qemu ile kullandigimiz disk'i olusturur. fonksiyon 
# default olarak 8 gb'lik disk olusturuyor. bir alttaki komut ile 4 gb'lik olusturabiliriz.
# sdcard_bootpart_size='100MiB' sdcard_total_size=3600MiB ./framework.sh desktop do_create_sdcard
# bu sdcard varsayilan olarak $workdir/sysroots/$release_name/ klasorundeki sysrootu kullaniyor
# fakat mevcut bir isodan kopyalanmasi icin $where degiskenini asagida inceleyiniz.
function do_create_sdcard() {

	# rootfs_dir yerine /mnt/nfs/p2 gibi mount edilmis klasorlerden
	# sdcard olusturmak mumkun olur.
	util_check_is_empty $where && where="$rootfs_dir"

	# eger sysroot klasoru bos ise olusturabilecegimiz bir image yok. ilk once
	# do_bootstrap ve do_second_stage ile debian tabanli distro olusturunuz.
	[[ ! -d $where/var ]] && {
		println "error" "sysroot bulunamadi: $where/var";
		return $failed;
	}

	[[ -f $sdcard_iso ]] && {
		println "error" "$sdcard_iso dosyasi zaten mevcut.";
		return $failed;
	}

	sudo umount $workdir/mnt/iso/{p1,p2,p3} $loop_dev{p1,p2,p3} &>/dev/null
	sudo mkdir -p $workdir/mnt/iso/{p1,p2,p3}

	# asagidaki sekilde cagrilinca verilen boyuta gore sdcard olusur.
	# usage: `sdcard_total_size=3600M sdcard_bootpart_size=100MiB ./framework.sh desktop do_create_sdcard`
	util_check_is_empty $sdcard_total_size && sdcard_total_size='7300M'
	util_check_is_empty $sdcard_bootpart_size && sdcard_bootpart_size='200M'

	sudo rm -f $sdcard_iso
	sudo dd if=/dev/zero of=$sdcard_iso bs=1 count=0 seek=$sdcard_total_size

	# bos bir tane iso dosyasini 3 partition olarak sekilde olusturuyoruz.
	sudo parted --script $sdcard_iso \
		mklabel msdos \
		mkpart primary fat32 10MiB "$sdcard_bootpart_size" \
		mkpart primary ext4 "$sdcard_bootpart_size" 80% \
		mkpart primary ext4 80% 100%;

	
	# olusturma islemi basarili ise bu partitionlari formatliyoruz.
	[[ ! $? -eq $success ]] && { println "error" "failed."; return $failed; }

	# bu image'i loopback device olarak mount edip
	sudo losetup -d $loop_dev &>/dev/null
	sudo losetup $loop_dev $sdcard_iso -P

	# fat32 ve ext4 olarak formatliyoruz.
	sudo mkdosfs -F 32 ${loop_dev}p1
	echo y | sudo mkfs.ext4 ${loop_dev}p2
	echo y | sudo mkfs.ext4 ${loop_dev}p3

	# yeni sdcard.iso olusturmak yerine mevcut bir sdcard icindeki boot dosyalarini
	# guncellemek icin bu fonksiyonu bazen tek basina calistirmamiz gerekiyor.
	# o yuzden ayri bir fonksiyon olarak tanimlandi.
	export where=$where;
	do="rootfs" do_update_sdcard; {
		unset where;
	}

	return $success
}

# sdcard daha once olusturulmus ise bu fonksiyon mount edip
# boot partition ve etc altindaki dosyalari /opt/framework
# icinde bulunan son halleri ile gunceller. onemli not: rootfs'e karismaz.
function do_update_sdcard() {

	# tek seferde her 3 distroyu guncellemek icin
	[[ "$all" == "yes" ]] && {
		bash -c "$workdir/framework.sh core do_update_sdcard sync=yes all=no ";
		bash -c "$workdir/framework.sh desktop do_update_sdcard sync=yes all=no ";
		bash -c "$workdir/framework.sh dev do_update_sdcard sync=yes all=no ";
		return $success;
	}

	# daha once mount edilmisse tedbiren kapatiyoruz.
	sudo losetup -d $loop_dev &>/dev/null;
	sudo umount $workdir/mnt/iso/{p1,p2,p3} $loop_dev{p1,p2,p3} &>/dev/null;
	sudo chown $USER:$USER $sdcard_iso $loop_dev{p1,p2,p3} &>/dev/null

	sudo losetup $loop_dev $sdcard_iso -P 2>/dev/null || { println "error" "loop failed"; return $failed; }
	sudo mount -o loop ${loop_dev}p1 $workdir/mnt/iso/p1 || { println "error" "loop failed"; return $failed; }
	sudo mount -o loop ${loop_dev}p2 $workdir/mnt/iso/p2 || { println "error" "loop failed"; return $failed; }
	sudo mount -o loop ${loop_dev}p3 $workdir/mnt/iso/p3 || { println "error" "loop failed"; return $failed; }

	# bu asamada artik butun calismalarimizi bu sdcard'a kopyalayabiliriz.

	# ilk once u-boot.imx dosyasini burn ediyoruz. akabinde kernel ve rootfs kopyalaniyor.
	[[ -f $machine_dir/u-boot.imx ]] && sudo dd if=$machine_dir/u-boot.imx of=$loop_dev bs=512 seek=2 conv=fsync
	sudo cp -r $machine_dir/boot/* $workdir/mnt/iso/p1

	# bu dosya mkimage ile uboota uygun hale getirilmemis. uygun olan boot.scr
	sudo rm -f $workdir/mnt/iso/p1/{boot.cmd,initrd.cpio}
	
	[[ "$do" == "rootfs" ]] && {
		# preserve demeyince lightdm gibi user klasorleri hata veriyor.
		println "info" "rootfs kopyalaniyor.";
		sudo cp -r --preserve=all $where/* $workdir/mnt/iso/p2/;
	}

	if [[ "$sync" == "yes" ]]
	then
		println "info" "sync.";
		sudo rm -rf $workdir/mnt/iso/p2/etc/{framework,initramfs-tools}
		tree -a $workdir/distro/ > $workdir/distro/etc/framework/tree.log
		sudo cp -r $workdir/distro/. $workdir/mnt/iso/p2/
		sudo cp -r $workdir/distro/etc/framework/files/$distro_type/. $workdir/mnt/iso/p2/
		sudo cp -r $workdir/distro/etc/skel/. $workdir/mnt/iso/p2/root/

		if [[ "$distro_type" != "dev" ]]
		then
			echo '' | sudo tee $workdir/mnt/iso/p2/root/.bash_history
			sudo rm -rf $workdir/mnt/iso/p2/etc/initramfs-tools \
				$workdir/mnt/iso/p2/etc/framework/{{first-boot*,create-initrd,sync,clean}.sh,{conf,files}}
		fi
	fi

	sync; {
		sudo losetup -d $loop_dev &>/dev/null;
		sudo umount $workdir/mnt/iso/{p1,p2,p3} $loop_dev{p1,p2,p3} &>/dev/null;
	}

	return $success
}

# cihazlara yuklenecek olan nihai imajlari ve yukleme islemini yapacak master-image
# dedigimiz diski olusturur. master image icerisinde yalnizca tek partitionu olan
# ve uboot,kernel ve encrypt edilmis image guncellemesini bulunduran bir sdcard'tir.
# IMX6 SOM'u uzerinde bulunan jumperlarin degistirilmesi ile mainboard boot islemini
# sdcard uzerinden yapabiliyor. (bkz: workdir/meta/pictures/som-master-image-mode.png)
# iste master image bu sekilde boot edilen bir image olup
# initrd araciligiyla SOM'un diskini fabrika ayarlarina getirir yani tamamen
# sifirlayip formatlar. oysa sistem sdcard'tan boot edilmeyip normal sekilde boot
# edilince initrd /home partitionu olan /dev/mmcblk2p3'e asla dokunmayip usb veya 
# diger disklerle imaj guncellemesi yapar.
function do_create_master_img() {

	# master.img dosyasi sdcard.iso'dan olusturuluyor.

	[[ ! -f $sdcard_iso ]] && {
		println "error" "$sdcard_iso bulunamadi.";
		return $failed;
	}
	
	println "warning" "mnt/loop/tmp klasorler hazirlaniyor"; {
		sudo mkdir -p $workdir/mnt/iso/{p1,p2,p3,master};
		sudo umount $workdir/mnt/iso/{p1,p2,p3,master} $loop_dev{p1,p2,p3} &>/dev/null;

		# bu image'i loopback device olarak mount ediyoruz.
		sudo losetup -d $loop_dev &>/dev/null;
		sudo losetup $loop_dev $sdcard_iso -P || return $failed;

		sudo chown $USER:$USER $sdcard_iso $loop_dev{p1,p2,p3} 2>/dev/null;
		sudo mount -o loop ${loop_dev}p1 $workdir/mnt/iso/p1;
		sudo mount -o loop ${loop_dev}p2 $workdir/mnt/iso/p2;
		sudo mount -o loop ${loop_dev}p3 $workdir/mnt/iso/p3;
	}

	# img olustururken bunun 4096 byte'in katlari olmasi gerekiyor. o yuzden
	# ilk once rootfs'in boyutunu bulup bunu 4096'a tamamliyoruz ustune de 
	# diskte bos yer olmasi icin 40MB alan ekliyoruz.

	# -------------------------------------------------------------------------
	# boot partition
	# -------------------------------------------------------------------------
	println "warning" "bootfs: disk size hesaplaniyor."; {
		size_bootfs=$(sudo du -s $workdir/sysroots/boot/ | cut -f1);
		size_bootfs=$((size_bootfs / 4096));
		size_bootfs=$(((size_bootfs + 10) * 4096));
	}

	println "warning" "bootfs: mountdir olusturuluyor."; {
		sudo umount -f $mount_path 2>/dev/null;
		sudo rm -rf $mount_path 2>/dev/null;
		sudo mkdir -p $mount_path || return $failed;
	}

	println "warning" "bootfs: dd ile zero img olusturuluyor."; {
		sudo dd status=none if=/dev/zero of=$image_dir/boot.img bs=1KB count="${size_bootfs}" >/dev/null || return $failed;
	}

	println "warning" "bootfs: mkfs.vfat"; {
		sudo mkfs.vfat $image_dir/boot.img >/dev/null || return $failed;
	}

	println "warning" "bootfs: mount";
		sudo mount -o loop $image_dir/boot.img $mount_path >/dev/null && {
			println "warning+" "bootfs: kok dizin dosyalari kopyalaniyor.";
			sudo cp -r $workdir/sysroots/boot/* $mount_path || return $failed;
			sudo rm -f $mount_path/boot.cmd $mount_path/initrd.cpio;
		};
	
	println "warning" "bootfs: umount"; {
		sudo umount -f $image_dir/boot.img $mount_path &>/dev/null;
		println "warning+" "bootfs: finished.";
	}
	# -------------------------------------------------------------------------

	# -------------------------------------------------------------------------
	# root partition
	# -------------------------------------------------------------------------
	println "warning" "rootfs: disk size hesaplaniyor."; {
		size_rootfs=$(sudo du -s $workdir/mnt/iso/p2 | cut -f1);
		size_rootfs=$((size_rootfs / 4096));
		size_rootfs=$(((size_rootfs + 40) * 4096));
	}

	println "warning" "rootfs: mountdir olusturuluyor."; {
		sudo umount -f $mount_path 2>/dev/null && sudo rm -rf $mount_path && sudo mkdir $mount_path;
	}

	println "warning" "rootfs: dd ile zero img olusturuluyor."; {
		sudo dd status=none if=/dev/zero of=$image_dir/root.img bs=1KB count="$size_rootfs" >/dev/null || return $failed;
	}
	
	println "warning" "rootfs: mkfs.ext4"; {
		sudo mkfs.ext4 -b 4096 -F $image_dir/root.img >/dev/null || return $failed;
	}
	
	println "warning" "rootfs: mount"
	
	if sudo mount -t ext4 -o loop $image_dir/root.img $mount_path
	then
		println "warning+" "rootfs: kok dizin dosyalari kopyalaniyor."
		println "warning+" "rootfs: image icindeki cache klasorleri temizleniyor.."
		sudo rm -rf $workdir/mnt/iso/p2/tmp/* $workdir/mnt/iso/p2/var/cache/apt/archives/*
		sudo cp -r --preserve=all $workdir/mnt/iso/p2/* $mount_path
		sync; sudo umount -f $image_dir/root.img $mount_path &>/dev/null;
	else
		return $failed
	fi

	sync; println "warning+" "rootfs: tamamlandi.."
	# -------------------------------------------------------------------------

	# -------------------------------------------------------------------------
	# home partition
	# -------------------------------------------------------------------------
	println "warning" "homefs: disk size hesaplaniyor."; {
		size_homefs=$(sudo du -s $workdir/mnt/iso/p3 | cut -f1);
		size_homefs=$((size_homefs / 4096));
		size_homefs=$(((size_homefs + 20) * 4096));
	}

	println "warning" "homefs: mountdir olusturuluyor."; {
		sudo umount -f $mount_path 2>/dev/null && sudo rm -rf $mount_path && sudo mkdir $mount_path;
	}

	println "warning" "homefs: dd ile zero img olusturuluyor."; {
		sudo dd status=none if=/dev/zero of=$image_dir/home.img bs=1KB count="${size_homefs}" >/dev/null || return $failed;
	}
	
	println "warning" "homefs: mkfs.ext4"; {
		sudo mkfs.ext4 -b 4096 -F $image_dir/home.img >/dev/null || return $failed;
	}
	
	println "warning" "homefs: mount"
	
	if sudo mount -t ext4 -o loop $image_dir/home.img $mount_path
	then
		println "warning+" "homefs: kok dizin dosyalari kopyalaniyor."
		sudo cp -r --preserve=all $workdir/mnt/iso/p3/* $mount_path
		sync; sudo umount -f $image_dir/home.img $mount_path &>/dev/null;
	else
		return $failed
	fi

	sync; println "warning+" "homefs: tamamlandi."
	# -------------------------------------------------------------------------

	println "warning" "umount"; {
		sudo losetup -d $loop_dev &>/dev/null;
		sudo umount $workdir/mnt/iso/{p1,p2,p3} $loop_dev{p1,p2,p3} &>/dev/null;
	}

	# -------------------------------------------------------------------------
	# encryption
	# -------------------------------------------------------------------------
	println "warning" "img: sha256 hash hesaplaniyor."; {
		
		# distro versiyonu ve image'lari sh256 hash'lerini kopyaliyoruz.
		# image guncelleme islemi yaparken eger hash'ler tutmazsa guncelleme iptal edilir.
		
		root_hash=$(sha256sum $image_dir/root.img | awk '{ print $1 }');
		boot_hash=$(sha256sum $image_dir/boot.img | awk '{ print $1 }');
		home_hash=$(sha256sum $image_dir/home.img | awk '{ print $1 }');
		value=$(eval "jq '.distro_type = \""$distro_type"\" | .boot_img_hash = \""${boot_hash}"\" | .root_img_hash = \""${root_hash}"\" | .home_img_hash = \""${home_hash}"\" ' $workdir/distro/var/system/image.sys");
		
		util_check_is_empty $value || echo $value | sudo tee $image_dir/image.sys >/dev/null;
	}

	println "warning" "encryption: basladi."; {
		
		# openssl ile encryption islemini yaparken simdilik cok basit bir passphare
		# key kullandik (/space/earth/projects/debian/distro/root/.keys/key.bin)
		# ileride bu yapi degistirilip sertifika tarzi bir sey kullanilabilir
		# decryption > openssl enc -aes-256-ecb -pbkdf2 -iter 20000 -nosalt -e -kfile $workdir/distro/root/.keys/key.bin ) -in $image_dir/enc/boot.bin | tar -xz
		# https://www.tecmint.com/monitor-copy-backup-tar-progress-in-linux-using-pv-command/
		# https://robertheaton.com/2013/07/29/padding-oracle-attack/
		# https://www.czeskis.com/random/openssl-encrypt-file.html

		mkdir -p $image_dir/encrypted/ || return $failed;

		# not: kullandigimiz keyi burada her defasinda random olarak olusturup 
		# bunu RSA public ile encrypt ediyoruz ve gonderilecek image guncellemesi ile
		# birlikte yolluyoruz. dolayisiyla bu key olmadikca dosyalar extract edilemiyor.
		openssl rand -out $workdir/distro/root/.keys/key.bin 32
		openssl rsautl -encrypt -inkey $keys_dir/id_rsa.pub.pem -pubin -in $workdir/distro/root/.keys/key.bin -out $image_dir/encrypted/key.bin.enc || return $failed;
		
		tar -C $image_dir -czf - boot.img | (pv -p --timer --rate --bytes | openssl enc -aes-256-ecb -pbkdf2 -iter 20000 -nosalt -e -pass file:$workdir/distro/root/.keys/key.bin 2>/dev/null > $image_dir/encrypted/boot.bin) 2>&1;
		tar -C $image_dir -czf - root.img | (pv -p --timer --rate --bytes | openssl enc -aes-256-ecb -pbkdf2 -iter 20000 -nosalt -e -pass file:$workdir/distro/root/.keys/key.bin 2>/dev/null > $image_dir/encrypted/root.bin) 2>&1;
		tar -C $image_dir -czf - home.img | (pv -p --timer --rate --bytes | openssl enc -aes-256-ecb -pbkdf2 -iter 20000 -nosalt -e -pass file:$workdir/distro/root/.keys/key.bin 2>/dev/null > $image_dir/encrypted/home.bin) 2>&1;

		# not: imza dosyasini da tar ile compress etmemizin sebebi sayet key yanlis ise openssl bunun yanlis oldugunu
		# soylemiyor haliyle dosya bozuk mu degil mi anlamiyoruz. fakat tar ile compress ettigimizde dosya bozuk ise
		# tar extract yapamayacagi icin hata veriyor.
		tar -C $image_dir -czf - image.sys | (pv -p --timer --rate --bytes | openssl enc -aes-256-ecb -pbkdf2 -iter 20000 -nosalt -e -pass file:$workdir/distro/root/.keys/key.bin 2>/dev/null > $image_dir/encrypted/image.sign) 2>&1;
	}
	
	# bu keyle isimiz bittigi icin artik silebiliriz.
	rm -f $workdir/distro/root/.keys/key.bin;
	println "warning+" "encryption: tamamlandi.";
	# -------------------------------------------------------------------------

	# -------------------------------------------------------------------------
	# bu asamada ise cihazlara hard format atan master.img isimli
	# image-updater sdcardi hazirlaniyor.
	# -------------------------------------------------------------------------
	println "warning" "master-img: dd ile zero img olusturuluyor."; {
		# rootfs ve bootfs'in boyutuna 100MB ekliyoruz.
		size_of_master_img=$((size_rootfs+size_bootfs+size_homefs));
		size_of_master_img=$((size_of_master_img + (10 * 4096)));

		sudo dd status=none if=/dev/zero of=$image_dir/master.img bs=1 count=0 seek=3600M >/dev/null || return $failed;
	}

	println "warning" "master-img: sanal disk formatlaniyor."; {
		sudo parted --script $image_dir/master.img mklabel msdos mkpart primary fat32 10MiB 100%;
		
		# bu image'i loopback device olarak mount ediyoruz.
		sudo losetup -d $loop_dev &>/dev/null;
		sudo losetup $loop_dev $image_dir/master.img -P;
		sudo mkdosfs -F 32 ${loop_dev}p1 >/dev/null || return $failed;

		# burada u-boot.imx master.img dosyasina yaziliyor dikkat.
		sudo dd if=$workdir/sysroots/boot/u-boot.imx of=$loop_dev bs=512 seek=2 conv=fsync;
		sudo mount -o loop ${loop_dev}p1 $workdir/mnt/iso/master;
	}

	println "warning+" "master-img: dosyalar kopyalaniyor."; {
		distro_version=$(cat $workdir/distro/var/system/image.sys | jq '.distro_version' -r);
		util_check_is_empty "$distro_version" && println "error" "distro_version bilgisi null: $workdir/distro/var/system/image.sys" && return $failed;
		
		sudo cp -r $workdir/sysroots/boot/* $workdir/mnt/iso/master;
		sudo rm -f $workdir/mnt/iso/master/boot.cmd $workdir/mnt/iso/master/initrd.cpio;

		echo -e "\nmaster_image='yes'" | sudo tee -a $workdir/mnt/iso/master/env.cmd >/dev/null;
		sudo mkdir -p $workdir/mnt/iso/master/framework/update/image/$distro_version/;
		sudo cp $image_dir/encrypted/{key.bin.enc,image.sign,boot.bin,root.bin,home.bin} $workdir/mnt/iso/master/framework/update/image/$distro_version/;

		sync;
	}
	# -------------------------------------------------------------------------

	sudo losetup -d $loop_dev &>/dev/null
	sudo umount $workdir/mnt/iso/master ${loop_dev}p1 &>/dev/null
	
	sudo chown $USER:$USER $mount_path ${img_file} $image_dir/* 2>/dev/null

	println "success+" "master-img: tamamlandi."
}

# $software_update_dir klasorunde bulunan uygulamalarin guncelleme paketini
# olusturur. ornegin $software_update_dir/appname isimli klasor altinda
# package.sys package.sh package.tar.gz isminde 3 dosya mevcut. package.sys bu 
# paketin guncelleme, versiyon bilgilerini tutarken icindeki package.tar.gz dosyasi
# cihazda / root dizinine dogrudan extract edilir.
# `tar -czf package.tar.gz -C package/ .` komutuyla appname-v2 klasoru compress edilip
# `tar -xzf package.tar.gz -C /` komutu ile root dizinine extract edilebilir.
function do_create_software_update_package() {

	util_check_is_empty $package_name && {
		println "error" 'fonksiyonu cagirirken `package_name=appname ./framework.sh desktop do_create_software_update` biciminde package_name belirtiriniz.';
		return $failed;
	}

	[[ ! -f $software_update_dir/$package_name/package.sys || ! -f $software_update_dir/$package_name/package.tar.gz ]] && {
		println "error" "package klasorunde mutlaka package.sys ve package.tar.gz dosyalari olmak zorunda";
		return $failed;
	}

	package_hash=$(sha256sum $software_update_dir/$package_name/package.tar.gz | awk '{ print $1 }');
	new_hash_json=$(eval "jq '.hash = \""${package_hash}"\"' $software_update_dir/$package_name/package.sys")

	[[ ! -z ${new_hash_json} ]] || {
		println "error" "hash checksum hesaplanamadi."; return $failed;
	}

	echo $new_hash_json | sudo tee $software_update_dir/$package_name/package.sys >/dev/null

	println "info" "paket encrypt ediliyor..";
	# --------------------------------------------------------------------------
		openssl rand -hex 32 > $workdir/distro/root/.keys/key.bin

		openssl rsautl -encrypt -inkey $workdir/distro/root/.keys/id_rsa.pub.pem \
				-pubin -in $workdir/distro/root/.keys/key.bin \
				-out $software_update_dir/$package_name.key.bin.enc || return $failed;

		tar -C $software_update_dir/$package_name/ -czf - package.sys | ( \
			pv -p --timer --rate --bytes | \
				openssl enc -aes-256-ecb -pbkdf2 -iter 20000 -nosalt -e -pass file:$workdir/distro/root/.keys/key.bin 2>/dev/null > "$software_update_dir/$package_name.sign") 2>&1 || {
						println "error" "hata olustu.";
						return $failed;
			}

		tar -C $software_update_dir/$package_name -czf - package.{tar.gz,sh} | ( \
			pv -p --timer --rate --bytes | \
				openssl enc -aes-256-ecb -pbkdf2 -iter 20000 -nosalt -e -pass file:$workdir/distro/root/.keys/key.bin 2>/dev/null > "$software_update_dir/$package_name.appbin") 2>&1 || {
						println "error" "hata olustu.";
						return $failed;
			}

		# bu keyle isimiz bittigi icin artik silebiliriz.
		rm -f $workdir/distro/root/.keys/key.bin;
	# --------------------------------------------------------------------------

	println "success" "guncelleme paketi olusturuldu: $software_update_dir/$package_name.bin";
}

# https://blog.stefan-koch.name/2020/10/25/qemu-public-ip-vm-with-tap
# https://serverfault.com/questions/646709/linux-qemu-issue-with-bridge-network-interface
# host bilgisayarinda bridge kurarak qemu'nun dahil oldugumuz agdan ip almasini saglar.
# normal sartlarda qemu userspace network stacki ile ip alip internete baglanabiliyor,
# port yonlendirmesi ise qemuya ssh ile baglanabiliyoruz. bu fonksiyon ise
# root yetkisi ile host bilgisayara bridge kurarak qemunun dogrudan bulundugumuz aga
# girmesini sagliyor. bu sayede agdaki diger bilgisayarlar qemunun calistirdigi
# isletim sistemine erisebilir.
function do_create_virtual_network() {

	if ! $(ifconfig ${eth} &>/dev/null); then
		{ println "error" "virtual network icin ${eth} isimli interface bulunamadi"; return $failed; }
	fi

	sudo ifconfig ${eth} down
	sudo ifconfig ${eth} 0.0.0.0 promisc up

	sudo ip link add name $br type bridge
	sudo ip address add $eth_ip dev $br
	sudo ip link set dev $br up

	sudo ip link set dev ${eth} master $br
	sudo ip link set dev ${eth} up

	for t in $tap; do
		sudo openvpn --mktun --dev $t
		sudo ip link set dev $t master $br
		sudo ip link set dev $t up
	done

	return $success
}

function do_remove_virtual_network() {
	sudo ip link delete tap0 &>/dev/null
	sudo ip link delete br0 &>/dev/null
}

# qemu calistiktan sonra `ssh -p 2222 root@localhost` komutuyla baglanabilirsiniz
# veya vncviewer ile 'localhost' adresine baglanarak desktop'i kullanabilirsiniz.
# not: eger bilgisayarinizin ram'i 16gb'dan islemci ise 8 cekirdekten az ise
# qemu kullanmanin pek bir avantaji olmuyor. dolayisiyla dusuk donanimlarda
# dogrudan arac bilgisayari boardunu kullanmak daha performansli.
# -bios $workdir/qemu/u-boot.bin
function do_run_qemu() {

	println "success" "qemu hazirlaniyor.. (ctrl+a yapip biraktiktan sonra x'e basarak cikabilirsiniz)"
	println "warning+" "not: linux bootu tamamlanmadan qemu penceresini resize ediniz. desktop acilinca resolution degisemiyor."
	println "warning" "qemu ekrani disinda vncviewer (apt install remmina) ile localhost adresinden desktop'i kullanabilirsiniz."

	util_check_is_empty $path_initrd && path_initrd="$machine_dir/boot/initrd.cpio"
	util_check_is_empty $path_kernel && path_kernel="$machine_dir/boot/vmlinuz"

	[[ "${initrd}" != "no" ]] && {
		[[ ! -f $path_initrd ]] && println "error" "initrd bulunamadi: $path_initrd" && return $failed;
		qemu_conf="${qemu_conf} -initrd $path_initrd";
	}

	[[ ! -f $path_kernel ]] && {
		println "error" "kernel bulunamadi: $path_kernel"; return $failed;
	}

	[[ ! -f $sdcard_iso ]] && {
		println "error" "rootfs bulunamadi: $sdcard_iso"; return $failed;
	}

	qemu_network="-net nic -net user,hostfwd=tcp::${qemu_tcp_forw_port:-2222}-:22, "

	[[ "${bridge}" == "yes" ]] && {
		do_create_virtual_network;
		qemu_network="-net nic -net tap,ifname=tap0,script=no,downscript=no";
	}

	# qemu'yu nfs ile boot edebilmek icin.
	# root=/dev/nfs nfsroot=10.10.20.150:/opt/framework/mnt/nfs/p2,v3,tcp rw ip=dhcp
	# bu sistemle hem cihazlari nfs ile boot edip hem de hem de cross-toolchain ile kendi
	# host bilgisyarinizda live olarak host kaynaklarini kullanarak c++ 
	# uygulama gelistirme islemi yapabilirsiniz.

	if [[ "$nfs" == "yes" ]]
	then
		ifconfig ${eth} &>/dev/null || {
			println "error" "lutfen include/header.h dosyasindaki \$eth isimli parametreyi duzeltiniz.";
			return $failed;
		}

		# ctrl+a-x ile kapatinca nfs-server askida kaliyor.
		# restart ediyoruz ki hata vermesin.
		sudo systemctl restart nfs-server

		target="nfs" do_mount_sysroot && {
			cmdline_append="$cmdline_append root=/dev/nfs nfsroot=$host_ip:$workdir/mnt/nfs/p2,v3,tcp rw ip=dhcp";
			echo $cmdline_append
			println "success" "nfs baglantisi kuruluyor: nfsroot=$host_ip:$workdir/mnt/nfs/p2";
		}
	fi

	# isletim sisteminde yapilan her sey, yazilan her dosya ucucu moddadir restart 
	# edildiginde sistem eski haline geri doner. burada kullanm amacimiz, apt ile 
	# yeni bir package yuklerken sistemde kalmasini istemiyorsak veya gecici
	# testler yapacaksak imaji bozmamak.
	[[ "$snapshot" == "yes" ]] && {
		cmdline_append="$cmdline_append overlay_max_size=1g protected_rootfs=yes";
		println "warning" "system protected_rootfs modunda aciliyor.";
	}

	[[ "$distro_type" == "core" && "$initrd" != "no" ]] && {
		println "info-" "bug: core distrosu qemu ile calisirken initrd yuzunden klavye sorunu yaratiyor.";
		println "info-" "bug: lutfen 'initrd=no framework core do_run_qemu' biciminde calistiriniz.";
	}

	qemu_graph="-display gtk,zoom-to-fit=off"

	# desktop kullanilmayacaksa
	[[ "$nograph" == "1" ]] && {
		qemu_graph="$qemu_graph -nographic";
		cmdline_append="$cmdline_append systemd.unit=multi-user.target";
	}

	# desktop kullanilmayacaksa
	[[ "$vnc" == "yes" ]] && {
		qemu_graph="$qemu_graph -vnc :0 ";
	}

	local bin_qemu_system="qemu-system-aarch64"

	[[ "$arch" != "armhf" ]] && {
		bin_qemu_system="qemu-system-${arch}";
	}

	bin_qemu_system="$bin_qemu_system -accel tcg,thread=multi -cpu cortex-a57"

	# bu sekilde qemu dogrudan acilmayip gdb'nin baglanmasini bekler.
	# https://yulistic.gitlab.io/2018/12/debugging-linux-kernel-with-gdb-and-qemu/
	[[ "$debug_kernel" == "yes" ]] && {
		qemu_conf="$qemu_conf -s -S";
		cmdline_append="$cmdline_append nokaslr earlycon earlyprintk";
		path_kernel="$qemu_kernel_dir/vmlinux"
	}

	eval "$bin_qemu_system -machine virt,gic-version=max \
			-name 'qemu-framework' \
			-smp 4 \
			-m 2G \
			-vga std \
			-device virtio-gpu-pci \
			-serial mon:stdio \
			-device usb-ehci -device usb-tablet -device usb-kbd \
			-drive id=mydrive,file=${sdcard_iso},format=raw,id=mycard \
			-kernel ${path_kernel} \
			-append 'isolcpus=3 root=/dev/vda2 rw rootfstype=ext4 loglevel=1 no_wait=yes quiet splash=false systemd.show_status=yes ${cmdline_append}' \
			${qemu_conf} \
			${qemu_network} \
			${qemu_graph} \
			"

	[[ "$nfs" == "yes" ]] && {
		sudo systemctl restart nfs-server;
		target="nfs" do_umount_sysroot;
	}

	return $success
}

# kerneli armhf ile derleyip workdir altindaki sysroots/boot dizinine kopyalar.
# burada kernel'in derlendigi modulleri ise sysroots/boot altinda bulundurur.
function do_build_kernel() {
	if ! util_check_is_empty "$do"
	then
		cd $kernel_dir
		bash -c "export workdir=$workdir; source $workdir/include/header.h; cd $kernel_dir; source $toolchain_env; make $do;"
	else
		bash -c "
			export workdir=$workdir;
			source $workdir/include/header.h;
			cd $kernel_dir;
			source $toolchain_env;
			make Image Image.gz -j16 && println 'success' 'successed.' || println 'error' 'failed' " || { println "error" "failed."; return $failed;}

		kernel_arch="$arch"

		[[ "$arch" == "armhf" ]] && kernel_arch="arm"
		[[ "$arch" == "aarch64" ]] && kernel_arch="arm64"
		
		cp $kernel_dir/arch/$kernel_arch/boot/Image.gz $machine_dir/boot/vmlinuz
		sudo rm -rf $workdir/sysroots/lib/modules/$kernel_version/
		sudo bash -c "cd $kernel_dir; source $toolchain_env; make modules_install INSTALL_MOD_PATH=$workdir/sysroots/;" || {
			println "error" "failed.";
			return $failed;
		}

		if [[ "$firmwares" == "yes" ]]
		then
			sudo bash -c "cd $kernel_dir; source $toolchain_env; make firmware_install INSTALL_FW_PATH=$workdir/sysroots/lib/firmware;" || {
				println "error" "failed.";
				return $failed;
			}
		fi

		sudo rm -rf $workdir/sysroots/lib/modules/$kernel_version/{build,source}
		sudo chown -R $USER:$USER $workdir/sysroots/lib
	fi
}

# hem uboot hem de boot.scr dedigimiz boot esnasinda calisan shell script'i derler.
function do_build_uboot() {
	if ! util_check_is_empty "$do"
	then
		cd $uboot_dir
		bash -c "export workdir=$workdir; source $workdir/include/header.h; cd $uboot_dir; source $toolchain_env; make $do;"
	else
		bash -c "export workdir=$workdir; source $workdir/include/header.h; cd $uboot_dir; source $toolchain_env; make -j16 && println 'success' 'successed.' || println 'error' 'failed' " && {
			mkimage -A arm -T script -O linux -d $workdir/sysroots/boot/boot.cmd $install_dir/boot.scr;
			cp $uboot_dir/u-boot.imx $install_dir;
		}
	fi
}

function do_build_device_tree() {
	if [[ "${do}" == "extract" ]]
	then
		dtc -I dtb -O dts $workdir/sysroots/boot/imx6dl.dtb -o $workdir/sysroots/boot/imx6dl.dts
	else
		dtc -I dts -O dtb $workdir/sysroots/boot/imx6dl.dts -o $workdir/sysroots/boot/imx6dl.dtb
	fi
}

# parametre olarak sdcard.iso'nun nereye mount edilecegi verilir.
function do_mount_sysroot() {
	util_check_is_empty $target && { target="$distro_type"; }
	
	# daha once bind edilmisse umount yapiyoruz.
	do_umount_sysroot $target

	sudo mkdir -p $workdir/mnt/$target/{p1,p2,p3,master}

	sudo losetup $nfs_loop_dev $sdcard_iso -P --direct-io=on || {
		println "error" "loosetup failed.";
		return $failed;
	}

	options="${options} -o loop"
	sudo mount $options ${nfs_loop_dev}p1 $workdir/mnt/$target/p1;
	sudo mount $options ${nfs_loop_dev}p2 $workdir/mnt/$target/p2;
	sudo mount $options ${nfs_loop_dev}p3 $workdir/mnt/$target/p3;

	sudo chown $USER:$USER $sdcard_iso $workdir/mnt/$target/ $workdir/mnt/$target/{p2,p3,master}

	return $success
}

function do_umount_sysroot() {
	util_check_is_empty $target && { target="$distro_type"; }

	sudo umount -f $workdir/mnt/$target/{p1,p2,p3,master} $nfs_loop_dev{p1,p2,p3} &>/dev/null;
	sudo losetup -d $nfs_loop_dev &>/dev/null;
}

# not: initrd zaten kullandigimiz imajin icinde olusmakta. (bkz: distro/etc/initramfs-tools)
# bu fonksiyon ise yalnizca hizli degisiklikler icin eklendi. mevcut bir initrd.cpio'u extract
# edip degisiklik yaptiktan sonra tekrar compress etmeyi saglar.
function do_build_initrd() {
	if [[ "$do" == "extract" ]]
	then
		sudo rm -rf $workdir/sysroots/initrd/* && \
		sudo unmkinitramfs $workdir/sysroots/boot/initrd.cpio $workdir/sysroots/initrd/
		sudo chown -R $USER:$USER $workdir/sysroots/initrd/
	else
		sudo bash -c " \
			cd $workdir/sysroots/initrd/ && { \
				find . | cpio -H newc -o > ../initrd.tmp && \
				cat ../initrd.tmp | \
				gzip > $workdir/sysroots/boot/initrd.cpio && \
				rm -f ../initrd.tmp; }
			"
		sudo mkimage -A arm -O linux -T ramdisk -C gzip -n "Initrd file system" \
			-d $workdir/sysroots/boot/initrd.cpio $workdir/sysroots/boot/initrd.uboot;
		sudo chown $USER:$USER $workdir/sysroots/boot/initrd.uboot $workdir/sysroots/boot/initrd.cpio $workdir/sysroots/initrd
	fi
}

# gelistirmeler icin test yaparken her defasinda elle olusturmak zor oluyor
# https://www.ssh.com/academy/ssh/keygen
function do_create_new_rsa_keys() {

	# yanlislikla calistirilmasin diye
	if [[ "$do" == "new" ]]
	then
		# tedbir olarak yedekliyoruz.
		sudo cp -r $keys_dir /tmp/.old.keys/

		# private key
		openssl genrsa -out $keys_dir/id_rsa.pem 1024

		# public key
		openssl rsa -in $keys_dir/id_rsa.pem -pubout -out $keys_dir/id_rsa.pub.pem

		# certificate
		openssl req -new -x509 -key $keys_dir/id_rsa.pem -out $keys_dir/cert.pem -days 360 \
			-subj "/C=TR/ST=TR/L=Istanbul/O=framework/OU=IT/CN=linux.framework.com.tr"
	fi

	# test encrypt
	openssl rand -out $workdir/meta/tmp/key.bin 32

	println "info" "encrypt: key"
	openssl rsautl -encrypt -inkey $keys_dir/id_rsa.pub.pem -pubin -in $workdir/meta/tmp/key.bin -out $workdir/meta/tmp/key.bin.enc

	# test decrypt
	println "info" "decrypt: key"
	openssl rsautl -decrypt -inkey $keys_dir/id_rsa.pem -in $workdir/meta/tmp/key.bin.enc -out $workdir/meta/tmp/key.bin.out

	println "info" "encrypt: data"
	openssl enc -aes-256-ecb -pbkdf2 -iter 20000 -nosalt -e -pass file:$workdir/meta/tmp/key.bin.out -in $workdir/meta/tmp/data.bin -out $workdir/meta/tmp/data.bin.enc

	println "info" "decrypt: data"
	openssl enc -aes-256-ecb -pbkdf2 -iter 20000 -nosalt -d -pass file:$workdir/meta/tmp/key.bin.out -in $workdir/meta/tmp/data.bin.enc -out $workdir/meta/tmp/data.bin.out
}

# butun frameworku bir baska takim arkadasi ile paylasirken otomatik
# kurulum yapacak paketleri hazirlar.
function do_prepare_installer() {
	tmp_dir="/opt/installer/"

	sudo rm -rf $tmp_dir
	sudo mkdir $tmp_dir
	sudo chown -R $USER:$USER $tmp_dir

	# her ihtimale karsi kernel ve uboot derlenmis obje dosyalarini temizleyelim
	do=clean do_build_kernel
	do=clean do_build_uboot

	# orn: /opt/framework kelimesini /opt/'ye cevirir
	base_workdir=$(util_replace_str "$workdir" '/framework' '/')

	dirs="$dirs $workdir/framework.sh"
	dirs="$dirs $workdir/{repo/${distro}/,sysroots}"
	dirs="$dirs $workdir/{distro,host,include,mnt,machine,.vscode,.version,.gitignore}"
	dirs="$dirs $workdir/meta/"
	dirs="$dirs $image_dir_base/{core/sdcard.iso,desktop/sdcard.iso,dev/sdcard.iso}"
	dirs="$dirs $software_update_dir/testapp*"
	dirs="$dirs $workdir/sources/cross-debian"

	# compress islemi yaparken /opt/framework olarak degil /framework olarak
	# path veriyoruz ki extract esnasinda bu sekilde cikarilsin.
	dirs=$(util_replace_str "$dirs" "$base_workdir" '')

	println "warning" "dosyalar arsivleniyor."
	bash -c "cd $tmp_dir && tar -C ${base_workdir} -czf - $dirs | pv | split -a 1 -b 3G - 'framework-sdk.pack.'" || return $failed

	println "success" "islem tamamlandi."
}

# change root yaparak terminal icinde ilgili arch'i kullanmayi sagliyor.
function do_chroot() {
	do_mount_sysroot && sudo chroot $workdir/mnt/$target/p2 /bin/bash && do_umount_sysroot
}

main "$@"
