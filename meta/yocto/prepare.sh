#!/usr/bin/env bash

# ----------
# Developer: Recai Almaz (muddessir@outlook.com)
#
# ptsui (qt5 qml) ve pts projelerini native derlemek icin ihtiyac duydugumuz
# toolchain'i olusturur..
# 
# cd poky
# source oe-init-build-env ../build
# bitbake core-image-minimal
# bitbake core-image-minimal-dev
# bitbake -c populate_sdk core-image-minimal
# bitbake -c populate_sdk meta-toolchain-qt5
# ----------

export yocto_workdir="/opt/yocto/"
export poky_version="3.1"
export poky_branch="dunfell"

here=$(pwd)

# yocto'nun calismasi icin gerekli olan programlari indirir.
sudo apt-get -y -m install gawk wget git-core diffstat unzip texinfo gcc-multilib \
     build-essential chrpath socat cpio python3 python3-pip python3-pexpect \
     xz-utils debianutils iputils-ping python3-git python3-jinja2 libegl1-mesa \
     libsdl1.2-dev pylint3 xterm

mkdir -p $yocto_workdir && cd $yocto_workdir || {
	echo "error.";
	exit 1;
}

# dosya sistemi yapimiz yocto klasoru altinda builds, downloads ve poky olacak
mkdir -p $yocto_workdir/build/{sstate-cache,tmp,conf}
mkdir -p $yocto_workdir/downloads

# poky'nin butun branchlerini indirip bizim kullandigimiz surume gececegiz
git clone git://git.yoctoproject.org/poky \
	&& cd $yocto_workdir/poky \
	&& git checkout ${poky_branch}

# network, gnome, python gibi layerlerin bulundugu meta
git clone git://git.openembedded.org/meta-openembedded \
	&& cd $yocto_workdir/meta-openembedded \
	&& git checkout ${poky_branch} \
	&& cd ..

# kullanmis oldugumuz imx somlarina ait BSP'leri icerir.
git clone https://git.yoctoproject.org/git/meta-freescale \
	&& cd $yocto_workdir/meta-freescale \
	&& git checkout ${poky_branch} \
	&& cd ..
	
# kullanmis oldugumuz imx somlarina ait BSP'leri icerir.
git clone git://github.com/Freescale/meta-freescale-3rdparty.git \
	&& cd $yocto_workdir/meta-freescale-3rdparty \
	&& git checkout ${poky_branch} \
	&& cd ..

# qt5 ve qt temelli desktop'lar
# patch: https://github.com/meta-qt5/meta-qt5/issues/128
patch_qmlcachegen=$here/patches/001-qmlcachegen-not-found.patch

[[ ! -f $patch_qmlcachegen ]] && {
	echo "error: patch bulunamadi lutfen kontrol ediniz: $patch_qmlcachegen";
}

git clone git://github.com/meta-qt5/meta-qt5.git \
	&& cd $yocto_workdir/meta-qt5 \
	&& git checkout ${poky_branch} \
	&& patch -p1 < $patch_qmlcachegen
	&& cd ..

# qt5 ve qt temelli desktop'lar
git clone git://github.com/schnitzeltony/meta-qt5-extra.git \
	&& cd $yocto_workdir/meta-qt5-extra \
	&& git checkout ${poky_branch} \
	&& cd ..

# disk encrypt etme, acl ve vb. sistemler icin gerekli
git clone git://git.yoctoproject.org/meta-security \
	&& cd $yocto_workdir/meta-security \
	&& git checkout ${poky_branch} \
	&& cd ..
	
# disk encrypt etme, acl ve vb. sistemler icin gerekli
git clone git://git.yoctoproject.org/meta-selinux \
	&& cd $yocto_workdir/meta-selinux \
	&& git checkout ${poky_branch} \
	&& cd ..

# ota (over the air) uzaktan isletim sistemi kernel, rootfs guncellemeleri icin
git clone https://github.com/sbabic/meta-swupdate \
	&& cd $yocto_workdir/meta-swupdate \
	&& git checkout ${poky_branch} \
	&& cd ..
	
cp $here/conf/* $yocto_workdir/build/conf/

# derleme islemi yapabilmek icin poky klasorunde source oe-init-build-env
# diyerek build klasorunu belirtmek ve sonra `bitbake core-image-minimal` demek
# yeterlidir. toolchain derlemek icin `bitbake -c populate_sdk meta-toolchain-qt5`
cd $yocto_workdir/poky && source oe-init-build-env $yocto_workdir/build/

exit 0
