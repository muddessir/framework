#!/usr/bin/env bash

# ----------
# Developer: Recai Almaz (muddessir@outlook.com)
#
# onemli not: bu bash shell scripti initrd tarafindan calistirildigi icin
# haliyle cok kisitli bir dosya sistemine sahip. yani normal bir linux 
# boot ettiginizde kullandiginiz uygulamalarin bir cogu initrd'de mevcut
# degil. haliyle ihtiyac duydugunuz baska bir binary varsa 
# /opt/framework/distro/etc/initramfs-tools/hooks/za-initrd-hook
# dosyasini inceleyerek bunu initrd scriptlerine ekleyip initrd'yi
# sizlere verdigimiz dokumanlari okuyarak yeniden derlemelisiniz.
# ----------

# return yapilirken mutlaka bunlar $success veya $failed kullanilmali.
# bu script cagrilmadan once varsayilan olarak asagidaki header include ediliyor.
# /opt/framework/distro/etc/initramfs-tools/files/etc/framework/lib.h

# software yukleme oncesi
do_preinstall()
{
	:
}

# software yukleme sonrasi
do_postinstall()
{
	:
}
