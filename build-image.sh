#!/bin/bash

set -e

export PYTHONPATH=./ubuntu-image

./inject-initramfs.sh \
    -o pc-kernel_*.snap \
    -f bin:/usr/bin/grub-editenv \
    -f bin:/sbin/cryptsetup \
    -f bin:/sbin/dmsetup \
    -f lib/udev/rules.d:/lib/udev/rules.d/55-dm.rules \
    -f lib/udev/rules.d:/lib/udev/rules.d/60-persistent-storage-dm.rules \
    -f lib/udev/rules.d:/lib/udev/rules.d/95-dm-notify.rules \
    -f lib:/lib/x86_64-linux-gnu/libcryptsetup.so.12 \
    -f lib:/usr/lib/x86_64-linux-gnu/libpopt.so.0 \
    -f lib:/lib/x86_64-linux-gnu/libgcrypt.so.20 \
    -f lib:/usr/lib/x86_64-linux-gnu/libargon2.so.0 \
    -f lib:/lib/x86_64-linux-gnu/libjson-c.so.3 \
    -f lib:/lib/x86_64-linux-gnu/libgpg-error.so.0 \
    -m dm-crypt.ko \
    -m aes-x86_64.ko \
    -m cryptd.ko \
    -m crypto_simd.ko \
    -m glue_helper.ko \
    -m af_alg.ko \
    -m algif_skcipher.ko \
    -f bin:go/unlock \
    -f lib:no-udev.so \
    -f bin:chooser/chooser \
    -f lib:/usr/lib/x86_64-linux-gnu/libform.so.5 \
    -f lib:/usr/lib/x86_64-linux-gnu/libmenu.so.5 \
    -f lib:/lib/x86_64-linux-gnu/libncurses.so.5 \
    -f lib:/lib/x86_64-linux-gnu/libtinfo.so.5 \
    -f lib:/usr/lib/x86_64-linux-gnu/libpanel.so.5 \
    -f lib/terminfo/l:/lib/terminfo/l/linux \
    pc-kernel_*.snap core-build/initramfs


sudo ./inject-snap.sh \
    -o core20_*.snap \
    -f usr/share/subiquity:console-conf-wrapper \
    -f bin:chooser/chooser \
    -d var/lib/snapd/seed \
    core20_*.snap

./inject-snap.sh \
    -o snapd_*.snap \
    -f usr/lib/snapd:go/snapd \
    -f usr/bin:go/snap \
    snapd_*.snap

#skip mtools warning
export MTOOLS_SKIP_CHECK=1

UBUNTU_IMAGE_SNAP_CMD=$(pwd)/go/snap \
    ubuntu-image/ubuntu-image snap \
    --image-size 4G \
    --snap pc_*.snap \
    --snap pc-kernel_*.snap \
    --snap snapd_*.snap \
    --snap core20_*.snap \
    core20-mvo-amd64.model

echo "Run something like (note that the OVMF from 18.04+ does not work)"
echo "kvm -m 2000 -bios /usr/share/qemu/OVMF.fd pc.img"
