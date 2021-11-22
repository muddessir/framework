#!/usr/bin/env bash

# ----------
# Developer: Recai Almaz (muddessir@outlook.com)
# ----------

source /etc/framework/conf/paths.h

apt-get install -y -m -f u-boot-tools mtd-utils build-essential man \
	htop git cmake meson pkg-config initramfs-tools libsqlite3-0 libsqlite3-dev || exit 1;

# desktop yuklu ise bu uygulamalarin kurulmasi gerekli.
[[ -d /usr/share/lightdm ]] && {
	apt-get install -y -m tightvncserver dconf-cli dconf-editor gedit nautilus;
}

# dev image'ina ait ayarlar.
cp -r $dir_init/files/dev/* /

# sabit ip
cp /etc/framework/tmp/wired-local.nmconnection /etc/NetworkManager/system-connections/

exit 0
