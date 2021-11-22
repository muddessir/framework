2021-06:
	- kernel sources/imx/patches/0009-random-initialize-pools-faster.patch patchlendi.
	  early boot esnasinda yeteri miktarda entropy olmadigi icin random number 
	  uretilemiyor ve openssl rsautl 2 dakika bekliyor. bu patch ilgili sorunu cozuyor.

2021-05:
	- kernel'e overlayfs modulu eklendi.
	- Kernel hacking->Compile-time checks.. debug-fs kaldirildi.
	- Drivers->Real Time Clock->RTC->Freescale MXC eklendi.