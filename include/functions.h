#!/bin/bash

# ----------
# Developer: Recai Almaz (muddessir@outlook.com)
# ----------

# header guard: iki kez ust uste lib.h dosyasini include etmemek icin
# burada su kontrolu yapiyoruz: eger fonksiyon tanimli degilse source yap.
type "util_check_is_empty " &>/dev/null || {
	source $workdir/include/lib.h;
}

fw_version=$(head -n1 $workdir/.version | tr -d '\n')
fw_build=$(tail -n1 $workdir/.version | tr -d '\n')

function usage() {
	# framework logo
	[[ -f $workdir/distro/etc/motd ]] && cat $workdir/distro/etc/motd;

	echo -e "${bold}Distro Build Framework $fw_version-$fw_build ${normal}\n";
	echo -e "  Bu framework debian tabanli distro ureterek embedded "
	echo -e "  bilgisayarlara yukleyen, isletim sistemi imajlarini olusturup"
	echo -e "  kernel ve uboot derlemelerini yapan yardimci bash uygulamasidir."
	echo -e "  Detayli kullanim icin lutfen framework.sh dosyasini inceleyiniz."
	echo -e ""
	echo -e "Kulllanim:"
	echo -e "  ${bold}./framework.sh${normal} [distro_type=core|desktop|dev] [function=do_prepare_host|do_debootstrap|do_build_kernel|..]"
	echo -e ""
	echo -e "Ornekler:";
	echo -e "  $> ${bold}./framework.sh${normal} desktop do_prepare_host do_debootstrap do_second_stage do_create_sdcard do_run_qemu"
	echo -e "  $> sdcard_bootpart_size='100MiB' sdcard_total_size=3600MiB ${bold}./framework.sh${normal} desktop do_create_sdcard"
	echo -e "  $> package_name=\$appname ${bold}./framework.sh${normal} desktop do_create_software_update_package"
	echo -e "  $> initrd=yes ${bold}./framework.sh${normal} desktop do_run_qemu"
	echo -e "  $> initrd=yes cmdline_append=\"update_system=no no_wait=yes protected_rootfs=no\" ${bold}./framework${normal} core do_run_qemu"
	echo -e "  $> cmdline_append=\"update_system=no automount=no no_wait=yes protected_rootfs=no break=init\" ${bold}./framework.sh${normal} core do_run_qemu"
	echo -e "  $> cmdline_append=\"protected_rootfs=yes\" nfs=yes ${bold}framework${normal} desktop do_run_qemu"
	echo -e "  $> cmdline_append='overlay_max_size=1g protected_rootfs=yes' ${bold}framework${normal} dev do_run_qemu"
	echo -e '  $> `framework --source` # framework.sh dosyasini aktif bash terminaline include eder. degiskenleri kullanabilirsiniz. '
	echo -e ""
	echo -e "Fonksiyonlar:"
	echo -e "  do_prepare_host(\$extra_packages)"
	echo -e "  do_bootstrap(\$variant=ubuntu|${bold}debian${normal})"
	echo -e "  do_second_stage"
	echo -e "  do_create_sdcard(\$sdcard_bootpart_size,\$sdcard_total_size)"
	echo -e "  do_update_sdcard"
	echo -e "  do_create_master_img"
	echo -e "  do_create_software_update_package(\$package_name)"
	echo -e "  do_create_virtual_network"
	echo -e "  do_remove_virtual_network"
	echo -e "  do_run_qemu(\$qemu_conf,\$cmdline_append,\$initrd=no,\$bridge=yes)"
	echo -e "  do_build_kernel(\$do=nconfig,clean,modules,all)"
	echo -e "  do_build_uboot(\$do=clean,all)"
	echo -e "  do_build_device_tree(\$devtree=compile)"
	echo -e "  do_mount_sysroot(\$options)"
	echo -e "  do_umount_sysroot"
	echo -e "  do_build_initrd(\$do=extract)"

	echo -e "";

	return $success
}

# frameworkun calisabilmesi icin gerekli programlarin yuklu olup
# olmadigini kontrol eder.
function do_sanity_check() {

	local apps="pv dialog tar openssl dd mkimage qemu-system-arm mkinitramfs"

	for i in ${apps[@]}; do
		sudo bash -c "command -v ${i} &>/dev/null" || local notfound="$i $notfound"
	done

	util_check_is_empty "$notfound" || {
		println "error" "$notfound isimli uygulama(lar)in yuklu olmasi gerek. lutfen do_prepare_host isimli fonksiyonu calistiriniz.";
		return $failed;
	}

	return $success
}
