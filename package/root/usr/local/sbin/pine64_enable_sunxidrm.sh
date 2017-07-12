#!/bin/bash

set -xe

dpkg-divert --divert /etc/modules-load.d/pine64-disp.conf.disabled --rename /etc/modules-load.d/pine64-disp.conf
dpkg-divert --divert /etc/X11/xorg.conf.d/40-pine64-fbturbo.conf.disabled --rename /etc/X11/xorg.conf.d/40-pine64-fbturbo.conf

dpkg-divert --divert /etc/modules-load.d/pine64-sunxidrm.conf --rename /etc/modules-load.d/pine64-sunxidrm.conf.disabled
dpkg-divert --divert /etc/X11/xorg.conf.d/40-pine64-armsoc.conf --rename /etc/X11/xorg.conf.d/40-pine64-armsoc.conf.disabled

echo "Done. Please reboot!"
