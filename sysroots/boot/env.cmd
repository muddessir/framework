# default,nfs,tftp,usb veya loopiso secilebilir.
boot_mode=default
console=tty1
console_append='console=ttymxc0,115200'
random_ethaddr=ba:d0:4a:9c:4e:ce
serverip=10.10.20.150
ipaddr=10.10.20.224
nfsroot=/opt/framework/mnt/nfs/p2
initrd_file=initrd.uboot
devtree_file=imx6dl-validator.dtb
silent='quiet loglevel=3 rd.systemd.show_status=yes rd.udev.log_level=3 vt.global_cursor_default=0'
cmdline_append='rootwait rw rootfstype=ext4 consoleblank=0'
rotate='1'
protected_rootfs='no'
load_tftp=setenv ethaddr ${random_ethaddr}; setenv boot_mode tftp; boot;
load_nfs=setenv ethaddr ${random_ethaddr}; setenv boot_mode nfs; boot;
