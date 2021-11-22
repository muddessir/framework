#!/usr/bin/env bash

# ----------
# Developer: Recai Almaz (muddessir@outlook.com)
# ----------

success=0
failed=1
bold=$(tput bold)
normal=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)

here=$(pwd)
check_apps="pv tar"
pack_a="$here/framework-sdk.pack.a"
pack_b="$here/framework-sdk.pack.b"
pack_c="$here/framework-sdk.pack.c"

install_dir="/opt"

add_fail_reason(){
	is_failed="$is_failed\n\t$1"
}

for i in ${check_apps[@]}; do
	command -v ${i} &>/dev/null || notfound="$i $notfound"
done

if [[ ! -z "$notfound" ]]; then
	add_fail_reason "kurulum yapabilmek icin '$notfound' uygulamalarin kurulu olmasi gerekli: sudo apt install $notfound"
fi

[[ ! -f $pack_a || ! -f $pack_b || ! -f $pack_c ]] && {
	add_fail_reason "kurulum paketleri eksik.";
}

echo -n "lutfen kurulum yapilacak dizini giriniz [default: $install_dir]: "; {
	read answer && [[ ! -z "$answer" ]] && install_dir=$answer;
}

[[ ! -d "$install_dir" ]] && {
	add_fail_reason "kurulum klasoru ($install_dir) bulunamadi.";
}

touch $install_dir/.test 2>/dev/null && rm $install_dir/.test || {
	add_fail_reason "klasore ($install_dir) yazma yetkiniz yok: 'sudo chown $USER:$USER $install_dir'";
}

if [[ -d $install_dir ]]
then
	free_disk=$(df --output=avail -h $install_dir | sed '1d;')
	free_disk_in_size=$(echo $free_disk | sed 's/[^0-9]//g')

	if (( $free_disk_in_size < 30 )); then
		add_fail_reason "kurulum yapabilmek icin diskinizde (free:$free_disk) en az 30 gb alan olmak zorunda.";
	fi
fi

if [[ ! -z "$is_failed" ]]
then
	echo -e "\n${bold}${red}error: kuruluma asagidaki sebeplerden dolayi devam edilemiyor ..${normal}"
	echo -e "$is_failed\n"
	exit $failed
fi

echo "dosyalar birlestiriliyor.."
pack=$install_dir/framework-sdk.tar.gz
pv $here/framework-sdk.pack.* > $pack

# tar extract
echo "kurulum yapiliyor.."
pv $pack | tar -xzpf - -C $install_dir/ || {
	echo "kurulum yapilamadi.";
	exit $failed;
}

dir_framework="$install_dir/framework"

chmod +x $dir_framework/framework.sh

# framework icindeki dosyalarda hardcoded olarak kayitli
# olan workdiri set ediyoruz.
hardcoded="/opt/framework"

sed -i "s/${hardcoded//\//\\/}/${dir_framework//\//\\/}/g" \
	$dir_framework/framework.sh \
	$dir_framework/distro/etc/framework/conf/paths.h \
	$dir_framework/distro/etc/framework/create-initrd.sh \
	$dir_framework/distro/etc/framework/sync.sh \
	$dir_framework/sources/cross-debian/environment-setup-cross-debian-gnueabihf \
	$dir_framework/host/etc/exports \
	$dir_framework/host/etc/xinetd.d/tftp \
	$dir_framework/sysroots/boot/env.cmd || {
		echo "framework icindeki path'ler set edilemedi.";
		exit $failed;
	}

rm -f $pack

echo "${bold}${green}kurulum tamamlandi: $dir_framework ${normal}"
echo "orn: ./framework --prepare"
cd $dir_framework/

exit $success
