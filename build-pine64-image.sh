#!/bin/sh
#
# This script takes a simpleimage and a kernel tarball, resizes the
# secondary partition and creates a rootfs inside it. Then extracts the
# Kernel tarball on top of it, resulting in a full Pine64 disk image.
#
# If a simpleimage is not available, the script will attempt to build one.

TYPE="$1"
LINUX="$2"
OUTPUT="$3"
DISTRO="$4"
SIMPLEIMAGE="$5"

SIZE="1440" # MiB
PWD=$(pwd)

set -e

if [ -z "$TYPE" -o -z "$LINUX" -o -z "$OUTPUT" ]; then
	echo "Usage: $0 <image-type> <linux-folder-or-tarball> <destination-directory> [distro] [simpleimage.img.xz]"
	echo ""
	echo "Image type:"
	echo ""
	echo "pine64      - Pine A64"
	echo "pine64lcd   - Pine A64 with LCD"
	echo "sopine      - SoPine A64"
	echo "pinebook    - Pinebook (PLACEHOLDER ONLY)"
	echo ""
	echo "Distros available:"
	echo ""
	echo "arch - Arch Linux"
	echo "xenial - Ubuntu Linux (Xenial Xerus)"
	echo "sid - Debian Linux (sid)"
	echo "jessie - Debian Linux (jessie)"
	echo "opensuse - OpenSUSE Tumbleweed"
	echo ""
	echo "If no distro is specified, this tool will default to xenial"
	echo "Also, if the location to the simpleimage is not provided, the tool will try"
	echo "to build one if the required dependecies are installed"
	exit 1
fi

DISTRO2=$DISTRO

if [ $TYPE = "pine64" ]; then
	echo -n
elif [ $TYPE = "pine64lcd" ]; then
	DISTRO=${DISTRO}-lcd
elif [ $TYPE = "sopine" ]; then
	echo -n
elif [ $TYPE = "pinebook" ]; then
	echo -n
else
	echo "Invalid image type specified"
	exit 2
fi

if [ ! -d "$PWD/$OUTPUT" ]; then
	echo "$OUTPUT is not a directory."
	exit 1
fi

if [ "$(id -u)" -ne "0" ]; then
	echo "This script requires root."
	exit 1
fi

echo -n "Checking for presence of zerofree... "

if [ -x /usr/sbin/zerofree ]; then
	echo "OK"
else
	echo "Not Installed"
	echo "ERROR: You need to install zerofree in order to generate a pine64 image."
	exit 1
fi

if [ -z "$DISTRO" ]; then
	DISTRO="xenial"
fi

# Find a free loop device
LOOP=$(losetup -f)

if [ -d /tmp/temp-pine64 ]; then
	rm -r /tmp/temp-pine64
fi

mkdir /tmp/temp-pine64
mkdir /tmp/temp-pine64/rootfs

cleanup() {
	set +e
	umount /tmp/temp-pine64/rootfs &> /dev/null
	losetup -d $LOOP &> /dev/null
	rm -r /tmp/temp-pine64/ &> /dev/null
}
trap cleanup EXIT

check_dependecies() {

	DEPENDECIES="0"

	echo -n "Checking for presence of arm-linux-gnueabihf toolchain... "

	if [ -x /usr/bin/arm-linux-gnueabihf-gcc ]; then
		echo "OK"
	else
		echo "Not Installed" && DEPENDECIES="1"
	fi

	echo -n "Checking for presence of aarch64-linux-gnu toolchain... "

	if [ -x /usr/bin/aarch64-linux-gnu-gcc ]; then
		echo "OK"
	else
		echo "Not Installed" && DEPENDECIES="1"
	fi
	
	echo -n "Checking for presence of git... "

	if [ -x /usr/bin/git ]; then
		echo "OK"
	else
		echo "Not Installed" && DEPENDECIES="1"
	fi

	echo -n "Checking for presence of device-tree-compiler... "

	if [ -x /usr/bin/dtc ]; then
		echo "OK"
	else
		echo "Not Installed" && DEPENDECIES="1"
	fi
	
	if [ $DEPENDECIES -eq 1 ]; then
		echo "ERROR: One or more depedecies required to generate the simpleimage are not installed. Please install the missing dependecies and try again or provide a simpleimage for the tool to use"
		exit 1
	fi

}

build_simpleimage() {
	if [ ! -d u-boot-pine64 ]; then
		git clone https://github.com/longsleep/u-boot-pine64.git
	fi
	
	if [ ! -d arm-trusted-firmware-pine64 ]; then
		git clone https://github.com/longsleep/arm-trusted-firmware.git arm-trusted-firmware-pine64
	fi

	if [ ! -d sunxi-pack-tools ]; then
		git clone https://github.com/longsleep/sunxi-pack-tools.git
		make -C sunxi-pack-tools
	fi

	cd u-boot-pine64

	make clean
	git pull origin
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- sun50iw1p1_config
	make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-

	cd ../arm-trusted-firmware-pine64

	make clean
	git pull origin
	make ARCH=arm CROSS_COMPILE=aarch64-linux-gnu- PLAT=sun50iw1p1 bl31

	cd ../u-boot-postprocess

	./u-boot-postprocess.sh
	
	cd ../simpleimage

	./make_simpleimage.sh $TYPE /tmp/temp-pine64/pine64-image.img $LINUX $SIZE
	
}

if [ -z "$SIMPLEIMAGE" ]; then
	echo "simpleimage is not provided. This tool will now attempt to generate a new simpleimage..."
	check_dependecies
	build_simpleimage
	losetup $LOOP /tmp/temp-pine64/pine64-image.img -o $((143360 * 512))
else
	echo "Using the simpleimage from $SIMPLEIMAGE..."
	# Unpack
	unxz -k --stdout "$SIMPLEIMAGE" > "/tmp/temp-pine64/pine64-image.img"
	# Enlarge
	dd if=/dev/zero bs=1M count=$(($SIZE - 50)) >> "/tmp/temp-pine64/pine64-image.img"
	# Resize
	echo ", +" | sfdisk -N 2 "/tmp/temp-pine64/pine64-image.img"
	losetup $LOOP /tmp/temp-pine64/pine64-image.img -o $((143360 * 512))
	resize2fs $LOOP
	cd simpleimage
fi

mount $LOOP /tmp/temp-pine64/rootfs
./make_rootfs.sh /tmp/temp-pine64/rootfs $LINUX $DISTRO
umount /tmp/temp-pine64/rootfs
zerofree -v $LOOP
losetup -d $LOOP

cd ..

mv /tmp/temp-pine64/pine64-image.img "$PWD/$OUTPUT/$DISTRO2-$TYPE-$(date +%Y%m%d).img"

trap "" EXIT

echo ""
echo "#"
echo "# The image has been built successfully"
echo "#"
echo ""
