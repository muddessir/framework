#!/usr/bin/env bash

# ----------
# Developer: Recai Almaz (muddessir@outlook.com)
#
# butun islemlerimiz bittikten sonra bu script araciligiyla isletim 
# sistemi uzerinde bulunan gereksiz dosyalari temizleyip nihai hale getiririz.
# ----------

source /etc/framework/conf/paths.h

# gereksiz dilleri temizler
rm -rf $(cat $dir_init/tmp/locale.purge)

# olusturdugumuz initrd backuplari
rm -rf /var/tmp/mkinitramfs*

# distro hazir hale gelince bu dosyalarin sahada olmasininin luzumu yok
sudo rm -rf $dir_init/{{first-boot*,create-initrd,sync,clean}.sh,{conf,files}}

apt-get autoremove -y
apt-get autoclean -y
apt-get clean -y

rm -rf /var/lib/apt/lists/*

echo '' > /root/.bash_history

exit 0