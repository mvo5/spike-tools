#!/bin/bash

set -e

export PYTHONPATH=./ubuntu-image

./inject-initramfs.sh \
    -o pc-kernel_*.snap \
    -b ./e2fsprogs/misc/mke2fs,grub/grub-editenv \
    pc-kernel_*.snap core-build/initramfs

ubuntu-image/ubuntu-image snap \
    --image-size 4G \
    --snap pc_*.snap \
    --snap pc-kernel_*.snap \
    --snap snapd_*.snap \
    --snap core18_*.snap \
    mvo-amd64.signed

echo "Run something like (note that the OVMF from 18.04+ does not work)"
echo "kvm -m 2000 -bios /usr/share/qemu/OVMF.fd pc.img"
