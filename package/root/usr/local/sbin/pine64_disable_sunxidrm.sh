#!/bin/bash

set -xe

dpkg-divert --remove --rename /etc/modules-load.d/pine64-disp.conf
dpkg-divert --remove --rename /etc/X11/xorg.conf.d/40-pine64-fbturbo.conf
dpkg-divert --remove --rename /etc/ld.so.conf.d/aarch64-linux-gnu_EGL.conf

dpkg-divert --remove --rename /etc/modules-load.d/pine64-sunxidrm.conf.disabled
dpkg-divert --remove --rename /etc/X11/xorg.conf.d/40-pine64-armsoc.conf.disabled
dpkg-divert --remove --rename /etc/ld.so.conf.d/mali.conf.disabled

ldconfig

echo "Done. Please reboot!"
