# dosyayi cache'e alip oyle calistirir.
# cunku ayni script framework klasorunu silmek zorunda kalabiliyor.

function m-sync() {
	bash -c "$(cat /etc/framework/sync.sh)"
}

function m-initrd() {
	bash -c "$(cat /etc/framework/create-initrd.sh)"
}

function m-cclean() {
	bash -c "$(cat /etc/framework/clean.sh)"
}

function m-dconf() {
	dconf dump / > /tmp/dconf.settings
	dconf load / < /etc/framework/conf/dconf.settings
}
