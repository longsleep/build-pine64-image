#!/bin/bash

if ! dpkg -l xserver-xorg-video-armsoc-sunxi &>/dev/null || ! dpkg -l libmali-sunxi &>/dev/null; then
    echo "The armsoc-sunxi and libmali is not installed!"
    echo "Please run this before trying again:"
    echo ""
    echo "  apt-add-repository -y ppa:ayufan/pine64-ppa"
    echo "  apt-get update"
    echo "  apt-get install -y xserver-xorg-video-armsoc-sunxi libmali-sunxi-utgard0-r6p0"
    exit 1
fi

set -xe

dpkg-divert --divert /etc/modules-load.d/pine64-disp.conf.disabled --rename /etc/modules-load.d/pine64-disp.conf
dpkg-divert --divert /etc/X11/xorg.conf.d/40-pine64-fbturbo.conf.disabled --rename /etc/X11/xorg.conf.d/40-pine64-fbturbo.conf
dpkg-divert --divert /etc/ld.so.conf.d/aarch64-linux-gnu_EGL.conf.disabled --rename /etc/ld.so.conf.d/aarch64-linux-gnu_EGL.conf

dpkg-divert --divert /etc/modules-load.d/pine64-sunxidrm.conf --rename /etc/modules-load.d/pine64-sunxidrm.conf.disabled
dpkg-divert --divert /etc/X11/xorg.conf.d/40-pine64-armsoc.conf --rename /etc/X11/xorg.conf.d/40-pine64-armsoc.conf.disabled
dpkg-divert --divert /etc/ld.so.conf.d/mali.conf --rename /etc/ld.so.conf.d/mali.conf.disabled

ldconfig

echo "Done. Please reboot!"
