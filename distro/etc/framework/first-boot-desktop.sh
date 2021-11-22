#!/usr/bin/env bash

# ----------
# Developer: Recai Almaz (muddessir@outlook.com)
#
# https://wiki.archlinux.org/title/LightDM
# ----------

source /etc/framework/conf/paths.h

apt-get install -y -m -f --no-install-recommends --no-install-suggests \
	xserver-xorg xinit x11-utils x11-xserver-utils xauth xbitmaps \
	xserver-xorg-video-fbdev xserver-xorg-input-libinput xserver-xorg-input-multitouch \
	xserver-xorg-video-vesa xserver-common xserver-xorg-core fonts-dejavu \
	xfonts-base xfonts-cyrillic xfonts-100dpi xfonts-75dpi \
	xfonts-scalable || exit 1

apt-get install -y -m -f openbox lightdm lightdm-gtk-greeter onboard \
	lightdm-gtk-greeter-settings obconf menu obmenu dbus-user-session \
	plymouth plymouth-themes accountsservice qt5-default default-jre \
	mousetweaks lm-sensors mesa-utils xterm || exit 1

# https://askubuntu.com/questions/692577/ubuntu-15-10-boot-hangs-when-starting-lightdm
# klasorler olusmayinca journalctl'te hata aliniyor.

mkdir -p /var/lib/lightdm
chown -R lightdm:lightdm /var/lib/lightdm
chmod 0750 /var/lib/lightdm

# multitouch destegi
# https://github.com/JoseExposito/touchegg

[[ -f /var/cache/apt/archives/libpugixml1v5_1.9-3_armhf.deb ]] && {
	dpkg -i /var/cache/apt/archives/libpugixml1v5_1.9-3_armhf.deb;
	dpkg -i /var/cache/apt/archives/touchegg_2.0.9_armhf.deb;
	systemctl enable touchegg.service;
}

cp -r $dir_init/files/desktop/* /

systemctl set-default graphical.target
systemctl enable daemon-desktop.service

exit 0