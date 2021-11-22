#!/bin/bash

# ----------
# Developer: Recai Almaz (muddessir@outlook.com)
# ----------

# workdir degiskeninin mutlaka framework.sh icinde tanimli olmasi gerek
[[ -z "$workdir" ]] && {
	errmsg="\$workdir isimli degisken null olamaz. lutfen framework.sh icinde tanimlayiniz.";
	command -v dialog &>/dev/null && dialog --msgbox "$errmsg" 10 70 || echo $errmsg; sleep 100;
}

# header guard
type "util_check_is_empty " &>/dev/null || {
	source $workdir/include/lib.h;
}

# frameworkun calistigi bilgisayarin dagitimi
export host_lbs_release=$((lsb_release -ds || cat /etc/*release || uname -om ) 2>/dev/null | head -n1)

# core, desktop, dev olmak uzere ozellestirdigimiz 3 cesit dagitimimiz mevcut.
export distro_type="${distro_type:-dev}"

# 3 tipte imaj olusturma mevcut. bir tanesi ustunde grafiksel arayuzu olmayan core
# ikincisi cihazlarda calisacak olan desktop sonuncusu ise development
# icin host bilgisayarimizda kullanacagimiz dev distrosu.
[[ ! -z "$1" ]] && {
	export distro_type="$1";
}

export machine="${machine:-qemu}"

export machine_dir="$workdir/machine/$machine"

export arch="${arch:-aarch64}"

# buster veya stable secilebilir. fakat jessie gibi eski
# dagitimlar test edilmek istenirse diye eklendi.
export release_name="${release_name:-buster}"

# sdcard.iso'i mount ederken kullandigimiz loop pathi.
export loop_dev="/dev/loop99"

export nfs_loop_dev="/dev/loop90"

# debian tabanli distronun / root dizini
export rootfs_dir="$workdir/sysroots/$distro_type"

# .img dosyasini mount edecegimiz dizin
export mount_path="$workdir/mnt/$distro_type"

# debian / root dizisinin ext4 turundeki .img diski
export image_dir_base="$workdir/build/images/$machine/$release_name"

export image_dir="$image_dir_base/$distro_type"

export software_update_dir="$workdir/build/packages"

# olusan image'in hem qemu hem de sdcard'a yazarken kullandigimiz dosyasi
export sdcard_iso=$image_dir/sdcard.iso

export kernel_version="${kernel_version:-5.10.78-rt55}"

# linux kernel kaynak kodlari
export kernel_dir=$machine_dir/sources/linux

export uboot_version="${uboot_version:-2016.03-r0}"

# imx uboot kaynak kodlari
export uboot_dir=$machine_dir/sources/u-boot

# derlenen kernel, uboot dosyalarinin kopyalandigi dizin
export install_dir=$workdir/sysroots/boot

export toolchain_env=${toolchain_env:-"$machine_dir/sources/environment-setup"}

# diger toolchainlerden farkli olarak x86_64 host debian/ubuntu'ya arm-linux-gcc-8
# kurarak dogrudan guest/target olan cihazin icindeki debianin sysrootunu kullanarak
# oradaki kutuphaneler araciligiyla derleme imkani saglar.
export cross_debian_toolchain_env=$workdir/sources/cross-debian/environment-setup-cross-debian-gnueabihf

# initrd ve cihaza yuklenen rsa keylerin hepsi tek noktada bulunur ki ulasmak ve degistirmek kolay olsun.
export keys_dir=$workdir/distro/root/.keys/

# asagidaki ayarlar qemuyu kullanirken guest'in bizim network'umuza dogrudan
# baglanip bridge ile ip almasi icin eklendi. default olarak kullanilmiyor
# cunku qemu virtual ip alabiliyor. ssh ile qemuya ulasiyoruz. (true komutu bir ise
# yaramiyor sadece degiskenleri gruplamak icin eklendi.)

true && {
	# ethernete yapilacak bridge adi
	export br="br0";

	# qemunun bridge uzerinden kullanacagi link. birden fazla tanimlanabilir; tap0 tap1 vs.
	export tap="tap0";

	# host yani bizim bilgisayarimizdaki ethernet interface'i karti
	export eth="enp59s0";

	# bridge aktiflestirilirse qemu guest'in alacagi ip
	export eth_ip="10.10.20.79/24";

	# qemuyu nfs ile kullanirken ihtiyac olabiliyor.
	export host_ip="$(ip addr show $eth 2>> /dev/null | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}' | head -n1)"
}

# calisma yaptigimiz klasorler eger chown ile degistirilmezse qemu mount hatasi verebiliyor.
sudo mkdir -p $workdir/{repo/$release_name/$arch,{mnt,sysroots}/{core,dev,desktop},mnt/nfs,sysroots/boot} \
	$workdir/mnt/{core,desktop,dev,iso,nfs}/{p1,p2,p3} \
	$machine_dir/boot/ \
	$image_dir \
	$software_update_dir

sudo chown $USER:$USER $workdir \
	$workdir/{repo,repo/$release_name,repo/$release_name/*} \
	$workdir/{mnt,sysroots,build/images,{build/images/,mnt,sysroots}/*} \
	$workdir/mnt/{core,desktop,dev,iso,nfs}/{p2,p3} \
	$machine_dir \
	$image_dir \
	$software_update_dir

sudo chown -R $USER:$USER $workdir/build
