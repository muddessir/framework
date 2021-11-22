#!/bin/bash -e

# ----------
# Developer: Recai Almaz (muddessir@outlook.com)
#
# sistem boot edildikten sonra calisan ilk servis.
# ----------

# initrd icinde home ve boot partitionlari farkli device'lara ataninca
# systemd-fstab-generator calistirilmadigi icin boot esnasinda hata aliniyor.
# systemctl daemon-reload

exit 0