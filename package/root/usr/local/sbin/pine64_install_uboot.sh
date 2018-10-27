#!/bin/sh

set -e

if [ "$(id -u)" -ne "0" ]; then
	echo "This script requires root."
	exit 1
fi

DEVICE="${1:-/dev/mmcblk0}"

if [ ! -b "$DEVICE" ]; then
  echo "Block device ${DEVICE} not found."
  exit 2
fi

local boot0_position=8     # KiB
local boot0_size=64        # KiB
local uboot_position=19096 # KiB
local uboot_size=1384      # KiB

echo "Flashing boot0 ..."
dd if="/boot/pine64/boot0-pine64-$(cat /etc/pine64_model).bin" conv=notrunc bs=1k seek=$boot0_position oflag=sync of="${DEVICE}"

echo "Flashing U-Boot ..."
dd if="/boot/pine64/u-boot-pine64-$(cat /etc/pine64_model).bin" conv=notrunc bs=1k seek=$uboot_position oflag=sync of="${DEVICE}"

sync
echo "Done - you should reboot now."
