#!/bin/bash

set -xe

dpkg-divert --divert /etc/modules-load.d/pine64-disp.conf --rename /etc/modules-load.d/pine64-disp.conf.disabled
dpkg-divert --divert /etc/X11/xorg.conf.d/40-pine64-fbturbo.conf --rename /etc/modules-load.d/40-pine64-fbturbo.conf.disabled

dpkg-divert --divert /etc/modules-load.d/pine64-sunxidrm.conf.disabled --rename /etc/modules-load.d/pine64-sunxidrm.conf
dpkg-divert --divert /etc/X11/xorg.conf.d/40-pine64-armsoc.conf.disabled --rename /etc/modules-load.d/40-pine64-armsoc.conf

echo "Done. Please reboot!"
