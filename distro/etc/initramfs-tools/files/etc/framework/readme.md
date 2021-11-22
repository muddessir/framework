initrd klasorleri asagidaki sira ile calisirken icerisindeki moduller ise 
kendi isimlerinin ilk iki harfinin sirasi ile za,zb,zc calisir.

http://manpages.ubuntu.com/manpages/bionic/man8/initramfs-tools.8.html

	1: init-top
	2: init-premount
	3: local-top / nfs-top
	4: local-block
	5: local-premount / nfs-premount
	6: local-bottom / nfs-bottom
	7: init-bottom

break=(top, modules, premount, mount, mountroot, bottom, init)

```c++
#define date "2021-05-14"
#define author "Recai Almaz"
```