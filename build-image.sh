#!/bin/bash

set -e

export PYTHONPATH=./ubuntu-image

./inject-initramfs.sh \
    -o pc-kernel_*.snap \
    -f bin:grub/grub-editenv \
    -f bin:/sbin/cryptsetup \
    -f bin:/sbin/dmsetup \
    -f lib:/lib/x86_64-linux-gnu/libcryptsetup.so.12 \
    -f lib:/usr/lib/x86_64-linux-gnu/libpopt.so.0 \
    -f lib:/lib/x86_64-linux-gnu/libgcrypt.so.20 \
    -f lib:/usr/lib/x86_64-linux-gnu/libargon2.so.0 \
    -f lib:/lib/x86_64-linux-gnu/libjson-c.so.3 \
    -f lib:/lib/x86_64-linux-gnu/libgpg-error.so.0 \
    -f lib/modules/4.15.0-54-generic/kernel/drivers:/lib/modules/4.15.0-54-generic/kernel/drivers/md/dm-crypt.ko \
    -f lib/modules/4.15.0-54-generic/kernel/drivers:/lib/modules/4.15.0-54-generic/kernel/arch/x86/crypto/aes-x86_64.ko \
    -f lib/modules/4.15.0-54-generic/kernel/drivers:/lib/modules/4.15.0-54-generic/kernel/crypto/cryptd.ko \
    -f lib/modules/4.15.0-54-generic/kernel/drivers:/lib/modules/4.15.0-54-generic/kernel/crypto/crypto_simd.ko \
    -f lib/modules/4.15.0-54-generic/kernel/drivers:/lib/modules/4.15.0-54-generic/kernel/arch/x86/crypto/glue_helper.ko \
    -f lib/modules/4.15.0-54-generic/kernel/drivers:/lib/modules/4.15.0-54-generic/kernel/crypto/af_alg.ko \
    -f lib/modules/4.15.0-54-generic/kernel/drivers:/lib/modules/4.15.0-54-generic/kernel/crypto/algif_skcipher.ko \
    -f lib:no-udev.so \
    pc-kernel_*.snap core-build/initramfs

sudo ./inject-snap.sh \
    -o core20_*.snap \
    -f usr/share/subiquity:console-conf-wrapper \
    -f bin:chooser/chooser \
    -f lib:no-udev.so \
    -d var/lib/snapd/seed \
    core20_*.snap

./inject-snap.sh \
    -o snapd_*.snap \
    -f usr/lib/snapd:go/snapd \
    -f usr/bin:go/snap \
    snapd_*.snap

ubuntu-image/ubuntu-image snap \
    --image-size 4G \
    --snap pc_*.snap \
    --snap pc-kernel_*.snap \
    --snap snapd_*.snap \
    --snap core20_*.snap \
    core20-mvo-amd64.model

echo "Run something like (note that the OVMF from 18.04+ does not work)"
echo "kvm -m 2000 -bios /usr/share/qemu/OVMF.fd pc.img"
