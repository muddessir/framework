#!/bin/bash

# ----------
# Developer: Recai Almaz (muddessir@outlook.com)
# 
# initrd image update system icin kullanilan library
# ----------

mkdir -p /run/framework

logfile="/run/framework/initrd.log" && touch ${logfile}

# console ayarlari
success=0
failed=1
bold="\e[1m"
normal="\e[0m"
red="\e[31m"
green="\e[32m"
blue="\e[34m"

# cihazin uzerinde gomulu olan
emmc="/dev/mmcblk2"

# cihaza disaridan takilan sd card
sdcard="/dev/mmcblk1"

# img dosyalarini dogrudan kullanamiyoruz loop olusturup 
# mount etmek gerekiyor. bu degisken nereye loop edilecegini belirtir.
loopdir="/dev/loop6"

# println "success" "message"
println()
{
	local type=$1
	local message=$2
	local indicator="[      ] "

	# fonksiyon parametresiz calistirilmasin.
	[[ -z "$message" ]] && return $failed

	[[ $type == 'success' ]] && indicator="[${green}  OK  ${normal}] "
	[[ $type == 'error' ]] && indicator="[${bold}${red} ERR. ${normal}] "
	[[ $type == 'wait' ]] && indicator="[ wait ] "
	[[ $type == 'warning' ]] && indicator="[ ${bold}warn${normal} ] "

	echo -e "${indicator}${normal}${message}${normal}"
	echo "$message" >> $logfile
}

do_log_debug()
{
	echo "debug: $1 $2" >> $logfile
}

# parametre basindaki ve sonundaki bosluklari siler.
util_trim()
{
	echo $1 | sed -e 's/^[[:space:]]*//'
}

# verilen parametre null, empty, bosluk ise 0=true degilse 1=false doner.
util_check_is_empty()
{
	local value="$(util_trim $1)"
	[[ "$value" != "" && "$value" != "null" && "$value" != "NULL" ]] && return $failed || return $success
}

# verilen parametre null veya empty ise 0 doner.
# sayet ikinci parametre verilirse 0 yerine, girilen deger doner.
util_nvl()
{
	util_check_is_empty "${2}" && ret=0 || ret=${2}
	util_check_is_empty "${1}" && echo $ret || echo ${1}
}

# `util_is_number "22a"` geriye -1 dondurur `util_is_number "22a" 0` fonksiyon
# sonuna baska bir integer verilirse de 22a number degilse 0 yani o verilen par. doner
util_is_number()
{
	util_check_is_empty "$2" && ret=-1 || ret=$2
	[[ ! -z "${1##*[!0-9]*}" ]] && echo $1 || echo $ret
}

# parametresiz cagrilinca datetime. bunlar disinda time, date gibi yanliz
# ilgili sonuc alinabilmekte. format girilecekse mutlaka her iki parametre yazilmali.
# orn: `util_getdate "datetime" "%m%d%Y%H%M"` gibi
util_get_date()
{

	# birinci parametre bos veya "datetime" girilince
	format="%Y-%m-%d %H:%M"

	[[ "$1" == "time" ]] && format="%H:%M"
	[[ "$1" == "date" ]] && format="%Y-%m-%d"

	# format ikinci parametre olarak belirlenebilir.
	util_check_is_empty $2 || format=$2

	echo "$(date "+${format}")"
}

util_replace_str() {
	util_check_is_empty $1 || util_check_is_empty $2 || {
		echo $1 | sed "s/${2//\//\\/}/${3//\//\\/}/g";
	}
}

do_mount_disk()
{
	if util_check_is_empty ${1} || util_check_is_empty ${2}
	then
		println "error" "do_mount_disk \$1: $1 \$2: $2 parametreler null olamaz"
		return $failed
	fi
	
	if ! util_check_is_empty ${3}
	then
		fs_type=${3}
	else
		fs_type=$(blkid ${1} -s TYPE -o value 2>>$logfile)
	fi

	util_check_is_empty $fs_type && {
		println "error" "do_mount_disk fs_type tespit edilemedi.";
		return $failed;
	}

	mount -o rw -t $fs_type ${1} ${2} &>>$logfile || { println "error" "${1} (${2}) mount edilemedi."; return $failed; }

	return $success
}

do_umount()
{
	for i in $@; do (mount | grep -q $i && umount -f "$i"); done
}

do_loop_mount_disk()
{
	# eger mevcut bir loop kaldirilmayi unutulmussa ilk once unloop yapiyoruz
	losetup -d $loopdir &>/dev/null

	# akabinde loop diski mount ediyoruz.
	losetup $loopdir ${1} &>>$logfile || return $failed
	do_mount_disk $loopdir ${2} ${3} || return $failed

	return $success
}

do_loop_unmount_disk()
{
	losetup -d $loopdir &>>$logfile
	do_umount "$1" || return $failed

	return $success
}

do_safe_return()
{
	util_check_is_empty ${1} || rm -rf /run/framework/key.bin ${1}/{extracted,image.sys,{boot,root,home}.img}
}

# IMX SOM uzerinde 2 tane led bulunmakta.
# bunlardan bir tanesini on/off yaparak LCD ekranin olmadigi durumlarda
# image update isleminin bitip bitmedigini haber verecegiz.
do_led_blink()
{
	util_check_is_empty $1 || { echo $1 | tee /sys/class/leds/sys_led/brightness &>$logfile; }
}

# ledi hizli bir sekilde on/off yapip
# start aldigimizi belirtmek icin eklendi.
do_led_blink_effect()
{
	for ((i=1; i<=20; i++)); do do_led_blink $((i % 2)); sleep 0.1; done
}