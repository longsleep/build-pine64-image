include common.mk

all: build

clean:
	rm -rf $(GADGET_DIR)/prebuilt/boot-assets
	rm -f $(GADGET_DIR)/prebuilt/uboot.conf
	rm -f $(GADGET_DIR)/prebuilt/uboot.env
	cd gadget; snapcraft clean

distclean: clean

u-boot:
	@if [ ! -d $(GADGET_DIR)/prebuilt/boot-assets ] ; then mkdir -p $(GADGET_DIR)/prebuilt/boot-assets; fi
	@if [ ! -f $(UBOOT_BIN) ]; then echo "Build u-boot first."; exit 1; fi
	cp -fa $(UBOOT_BIN) $(GADGET_DIR)/prebuilt/boot-assets/u-boot-with-dtb.bin

dtbs:
	@if [ ! -d $(GADGET_DIR)/prebuilt/boot-assets/dtbs ] ; then mkdir -p $(GADGET_DIR)/prebuilt/boot-assets/dtbs; fi
	dtc -Odtb -o $(GADGET_DIR)/prebuilt/boot-assets/dtbs/sun50i-a64-pine64-plus.dtb $(BLOBS_DIR)/pine64.dts
	dtc -Odtb -o $(GADGET_DIR)/prebuilt/boot-assets/dtbs/sun50i-a64-pine64.dtb $(BLOBS_DIR)/pine64noplus.dts
	dtc -Odtb -o $(GADGET_DIR)/prebuilt/boot-assets/dtbs/sun50i-a64-pine64so.dtb $(BLOBS_DIR)/pine64so.dts

preload: u-boot dtbs
	cp -fa $(BLOBS_DIR)/boot0.bin $(GADGET_DIR)/prebuilt/boot-assets/boot0.bin
	mkenvimage -r -s 131072  -o $(GADGET_DIR)/prebuilt/uboot.env $(GADGET_DIR)/prebuilt/uboot.env.in

snappy: preload
	cd gadget; snapcraft --target-arch amd64 snap

build: dtbs preload snappy

.PHONY: u-boot dtbs preload snappy build
