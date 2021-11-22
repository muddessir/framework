#!/usr/bin/env bash

# ----------
# Developer: Recai Almaz (muddessir@outlook.com)
# ----------

source /etc/framework/conf/paths.h

apt-get update -y
apt-get --fix-broken install

# bu dosya yalnizca root tarafindan goruntulenebilmeli.
chown -R root:root /var/system
chmod -R 700 /var/system &>/dev/null

# yapilan mount islemleri bu klasorlerde olunca isletim sistemi kapanirken
# otomatik olarak umount islemi guvenli bir sekilde yapiliyor.
mkdir -p /mnt/{usb,sdcard,mmc,tmp,iso}
chmod 777 /mnt/{usb,sdcard,mmc,tmp,iso}

systemctl enable daemon-init
systemctl enable daemon-firstboot
systemctl enable acpid

exit 0