#!/bin/bash

# ----------
# Developer: Recai Almaz (muddessir@outlook.com)
# ----------

# consola veri girisi icin her defasinda renk belirtmemek icin yapildi.
bold=$(tput bold)
normal=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)

# uygulamalar 0=true 1=false olarak sonuc dondurdugu 
# icin karisiklik olmamasi adina eklendi. oysa parametrik yapi kullandigimiz
# yerlerde 1 (true/acik) iken 0 (false/kapali) anlami tasiyor bizim
# bizim. asagidaki success/failed yalnizca bash return degerleri icindir.
success=0
failed=1

# parametre basindaki ve sonundaki bosluklari siler.
function util_trim() {
	echo $1 | sed -e 's/^[[:space:]]*//'
}

# verilen parametre null, empty, bosluk ise 0=true degilse 1=false doner.
function util_check_is_empty() {
	local value="$(util_trim $1)"
	[[ "$value" != "" && "$value" != "null" && "$value" != "NULL" ]] && return $failed || return $success
}

# verilen parametre null veya empty ise 0 doner.
# sayet ikinci parametre verilirse 0 yerine, girilen deger doner.
function util_nvl() {
	util_check_is_empty "${2}" && ret=0 || ret=${2}
	util_check_is_empty "${1}" && echo $ret || echo ${1}
}

# `util_is_number "22a"` geriye -1 dondurur `util_is_number "22a" 0` fonksiyon
# sonuna baska bir integer verilirse de 22a number degilse 0 yani o verilen par. doner
function util_is_number() {
	util_check_is_empty "$2" && ret=-1 || ret=$2
	[[ ! -z "${1##*[!0-9]*}" ]] && echo $1 || echo $ret
}

# parametresiz cagrilinca datetime. bunlar disinda time, date gibi yanliz
# ilgili sonuc alinabilmekte. format girilecekse mutlaka her iki parametre yazilmali.
# orn: `util_getdate "datetime" "%m%d%Y%H%M"` gibi
function util_get_date() {

	# birinci parametre bos veya "datetime" girilince
	format="%Y-%m-%d %H:%M"

	[[ "$1" == "time" ]] && format="%H:%M"
	[[ "$1" == "date" ]] && format="%Y-%m-%d"

	# format ikinci parametre olarak belirlenebilir.
	util_check_is_empty $2 || format=$2

	echo "$(date "+${format}")"
}

# usage: `println "success" "message"`
function println() {

	local type=$1
	local message=$2

	# fonksiyon parametresiz calistirilmasin.
	[[ -z "$type" || -z "$message" ]] && return $failed
	
	local info_color="${normal}"
	local indicator="[>]"

	[[ ${type: -1} == '+' ]] && type=${type%?} && indicator="${bold}${green}[+]"
	[[ ${type: -1} == '-' ]] && type=${type%?} && indicator="${bold}${red}[-]"

	[[ ${type} == "success" ]] && info_color="${bold}${green}"
	[[ ${type} == "error" ]] && info_color="${bold}${red}"
	[[ ${type} == "warning" ]] && info_color="${bold}"

	echo -e "${indicator}${normal} ${info_color}${message}${normal}"
}

function util_replace_str() {
	util_check_is_empty $1 || util_check_is_empty $2 || {
		echo $1 | sed "s/${2//\//\\/}/${3//\//\\/}/g";
	}
}
