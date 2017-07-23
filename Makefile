export RELEASE_NAME ?= 0.1~dev
export RELEASE ?= 1
export LINUX_BRANCH ?= my-hacks-1.2-with-drm
export BOOT_TOOLS_BRANCH ?= with-drm
LINUX_LOCALVERSION ?= -ayufan-$(RELEASE)

all: linux-pinebook linux-pine64 linux-sopine

linux/.git:
	git clone --depth=1 --branch=$(LINUX_BRANCH) --single-branch \
		https://github.com/ayufan-pine64/linux-pine64.git linux

linux/.config: linux/.git
	make -C linux ARCH=arm64 CROSS_COMPILE="ccache aarch64-linux-gnu-" clean CONFIG_ARCH_SUN50IW1P1=y
	make -C linux ARCH=arm64 CROSS_COMPILE="ccache aarch64-linux-gnu-" sun50iw1p1smp_linux_defconfig
	touch linux/.config

linux/arch/arm64/boot/Image: linux/.config
	make -C linux ARCH=arm64 CROSS_COMPILE="ccache aarch64-linux-gnu-" -j4 LOCALVERSION=$(LINUX_LOCALVERSION) Image
	make -C linux ARCH=arm64 CROSS_COMPILE="ccache aarch64-linux-gnu-" -j4 LOCALVERSION=$(LINUX_LOCALVERSION) modules
	make -C linux LOCALVERSION=$(LINUX_LOCALVERSION) M=modules/gpu/mali400/kernel_mode/driver/src/devicedrv/mali \
		ARCH=arm64 CROSS_COMPILE="ccache aarch64-linux-gnu-" \
		CONFIG_MALI400=m CONFIG_MALI450=y CONFIG_MALI400_PROFILING=y \
		CONFIG_MALI_DMA_BUF_MAP_ON_ATTACH=y CONFIG_MALI_DT=y \
		EXTRA_DEFINES="-DCONFIG_MALI400=1 -DCONFIG_MALI450=1 -DCONFIG_MALI400_PROFILING=1 -DCONFIG_MALI_DMA_BUF_MAP_ON_ATTACH -DCONFIG_MALI_DT"

busybox/.git:
	git clone --depth 1 --branch 1_24_stable --single-branch git://git.busybox.net/busybox busybox

busybox: busybox/.git
	cp -u kernel/pine64_config_busybox busybox/.config
	make -C busybox ARCH=arm64 CROSS_COMPILE="ccache aarch64-linux-gnu-" -j4 oldconfig

busybox/busybox: busybox
	make -C busybox ARCH=arm64 CROSS_COMPILE="ccache aarch64-linux-gnu-" -j4

kernel/initrd.gz: busybox/busybox
	cd kernel/ && ./make_initrd.sh

boot-tools/.git:
	git clone --single-branch --depth=1 --branch=$(BOOT_TOOLS_BRANCH) https://github.com/ayufan-pine64/boot-tools

boot-tools: boot-tools/.git

linux-pine64-$(RELEASE_NAME).tar: linux/arch/arm64/boot/Image boot-tools kernel/initrd.gz
	cd kernel && \
		bash ./make_kernel_tarball.sh $(shell readlink -f "$@")

package/rtk_bt/.git:
	git clone --single-branch --depth=1 https://github.com/NextThingCo/rtl8723ds_bt package/rtk_bt

package/rtk_bt/rtk_hciattach/rtk_hciattach: package/rtk_bt/.git
	make -C package/rtk_bt/rtk_hciattach CC="ccache aarch64-linux-gnu-gcc"

linux-pine64-package-$(RELEASE_NAME).deb: package package/rtk_bt/rtk_hciattach/rtk_hciattach
	fpm -s dir -t deb -n linux-pine64-package -v $(RELEASE_NAME) \
		-p $@ \
		--deb-priority optional --category admin \
		--force \
		--deb-compression bzip2 \
		--after-install package/scripts/postinst.deb \
		--before-remove package/scripts/prerm.deb \
		--url https://gitlab.com/ayufan-pine64/linux-build \
		--description "Pine A64 Linux support package" \
		-m "Kamil Trzciński <ayufan@ayufan.eu>" \
		--license "MIT" \
		--vendor "Kamil Trzciński" \
		-a arm64 \
		--config-files /var/lib/alsa/asound.state \
		package/root/=/ \
		package/rtk_bt/rtk_hciattach/rtk_hciattach=/usr/local/sbin/rtk_hciattach

%.tar.xz: %.tar
	pxz -f -3 $<

%.img.xz: %.img
	pxz -f -3 $<

simple-image-pine64-$(RELEASE_NAME).img: linux-pine64-$(RELEASE_NAME).tar.xz boot-tools
	cd simpleimage && \
		export boot0=../boot-tools/boot/pine64/boot0-pine64-plus.bin && \
		export uboot=../boot-tools/boot/pine64/u-boot-pine64-plus.bin && \
		bash ./make_simpleimage.sh $(shell readlink -f "$@") 150 $(shell readlink -f linux-pine64-$(RELEASE_NAME).tar.xz)

simple-image-sopine-$(RELEASE_NAME).img: linux-pine64-$(RELEASE_NAME).tar.xz boot-tools
	cd simpleimage && \
		export boot0=../boot-tools/boot/pine64/boot0-pine64-sopine.bin && \
		export uboot=../boot-tools/boot/pine64/u-boot-pine64-sopine.bin && \
		bash ./make_simpleimage.sh $(shell readlink -f "$@") 150 $(shell readlink -f linux-pine64-$(RELEASE_NAME).tar.xz)

simple-image-pinebook-$(RELEASE_NAME).img: linux-pine64-$(RELEASE_NAME).tar.xz boot-tools
	cd simpleimage && \
		export boot0=../boot-tools/boot/pine64/boot0-pine64-pinebook.bin && \
		export uboot=../boot-tools/boot/pine64/u-boot-pine64-pinebook.bin && \
		bash ./make_simpleimage.sh $(shell readlink -f "$@") 150 $(shell readlink -f linux-pine64-$(RELEASE_NAME).tar.xz)

BUILD_SYSTEMS := xenial zesty jessie stretch
BUILD_VARIANTS := minimal mate i3 openmediavault
BUILD_ARCHS := arm64
BUILD_MODELS := pine64 pinebook sopine

%-$(RELEASE_NAME)-$(RELEASE).img.xz: %-$(RELEASE_NAME)-$(RELEASE).img
	pxz -f -3 $<

%-$(RELEASE_NAME)-$(RELEASE).img: simple-image-pine64-$(RELEASE_NAME).img.xz linux-pine64-$(RELEASE_NAME).tar.xz linux-pine64-package-$(RELEASE_NAME).deb boot-tools
	sudo bash ./build-pine64-image.sh \
		"$(shell readlink -f $@)" \
		"$(shell readlink -f $<)" \
		"$(shell readlink -f linux-pine64-$(RELEASE_NAME).tar.xz)" \
		"$(shell readlink -f linux-pine64-package-$(RELEASE_NAME).deb)" \
		"$(filter $(BUILD_SYSTEMS), $(subst -, ,$@))" \
		"$(filter $(BUILD_MODELS), $(subst -, ,$@))" \
		"$(filter $(BUILD_VARIANTS), $(subst -, ,$@))"

.PHONY: kernel-tarball
kernel-tarball: linux-pine64-$(RELEASE_NAME).tar.xz

.PHONY: linux-package
linux-package: linux-pine64-package-$(RELEASE_NAME).deb

.PHONY: simple-image-pinebook-$(RELEASE_NAME).img
simple-image-pinebook: simple-image-pinebook-$(RELEASE_NAME).img

.PHONY: zesty-minimal-pinebook
zesty-minimal-pinebook: zesty-minimal-pinebook-bspkernel-$(RELEASE_NAME)-$(RELEASE).img.xz

.PHONY: xenial-mate-pinebook
zesty-mate-pinebook: zesty-mate-pinebook-bspkernel-$(RELEASE_NAME)-$(RELEASE).img.xz

.PHONY: xenial-i3-pinebook
zesty-i3-pinebook: zesty-i3-pinebook-bspkernel-$(RELEASE_NAME)-$(RELEASE).img.xz

.PHONY: xenial-minimal-pinebook
xenial-minimal-pinebook: xenial-minimal-pinebook-bspkernel-$(RELEASE_NAME)-$(RELEASE).img.xz

.PHONY: xenial-mate-pinebook
xenial-mate-pinebook: xenial-mate-pinebook-bspkernel-$(RELEASE_NAME)-$(RELEASE).img.xz

.PHONY: xenial-i3-pinebook
xenial-i3-pinebook: xenial-i3-pinebook-bspkernel-$(RELEASE_NAME)-$(RELEASE).img.xz

.PHONY: stretch-minimal-pine64
stretch-minimal-pine64: stretch-minimal-pine64-bspkernel-$(RELEASE_NAME)-$(RELEASE).img.xz

.PHONY: stretch-minimal-sopine
stretch-minimal-sopine: stretch-minimal-sopine-bspkernel-$(RELEASE_NAME)-$(RELEASE).img.xz

.PHONY: stretch-minimal-pinebook
stretch-minimal-pinebook: stretch-minimal-pinebook-bspkernel-$(RELEASE_NAME)-$(RELEASE).img.xz

.PHONY: jessie-minimal-pinebook
jessie-minimal-pinebook: jessie-minimal-pinebook-$(RELEASE_NAME)-$(RELEASE).img.xz

.PHONY: jessie-minimal-sopine
jessie-minimal-sopine: jessie-minimal-sopine-$(RELEASE_NAME)-$(RELEASE).img.xz

.PHONY: jessie-minimal-pine64
jessie-minimal-pine64: jessie-minimal-pine64-$(RELEASE_NAME)-$(RELEASE).img.xz

.PHONY: jessie-openmediavault-pine64
jessie-openmediavault-pine64: jessie-openmediavault-pine64-$(RELEASE_NAME)-$(RELEASE).img.xz

.PHONY: zesty-pinebook
zesty-pinebook: zesty-minimal-pinebook zesty-mate-pinebook zesty-i3-pinebook

.PHONY: xenial-pinebook
xenial-pinebook: xenial-minimal-pinebook xenial-mate-pinebook xenial-i3-pinebook

.PHONY: stretch-pinebook
stretch-pinebook: stretch-minimal-pinebook

.PHONY: linux-pinebook
linux-pinebook: xenial-pinebook stretch-pinebook jessie-minimal-pinebook

.PHONY: zesty-minimal-pine64
zesty-minimal-pine64: zesty-minimal-pine64-bspkernel-$(RELEASE_NAME)-$(RELEASE).img.xz

.PHONY: xenial-minimal-pine64
xenial-minimal-pine64: xenial-minimal-pine64-bspkernel-$(RELEASE_NAME)-$(RELEASE).img.xz

.PHONY: linux-pine64
linux-pine64: zesty-minimal-pine64 xenial-minimal-pine64 stretch-minimal-pine64 jessie-minimal-pine64 jessie-openmediavault-pine64

.PHONY: zesty-minimal-sopine
zesty-minimal-sopine: zesty-minimal-sopine-bspkernel-$(RELEASE_NAME)-$(RELEASE).img.xz

.PHONY: xenial-minimal-sopine
 xenial-minimal-sopine: xenial-minimal-sopine-bspkernel-$(RELEASE_NAME)-$(RELEASE).img.xz

.PHONY: linux-sopine
linux-sopine: zesty-minimal-sopine xenial-minimal-sopine stretch-minimal-sopine jessie-minimal-sopine
