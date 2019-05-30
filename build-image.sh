#!/bin/bash

set -e

export PYTHONPATH=./ubuntu-image

./inject-initramfs.sh \
    -o pc-kernel_*.snap \
    pc-kernel_*.snap core-build/initramfs

sudo ./inject-core.sh \
    -o core18_*.snap \
    -b grub/grub-editenv \
    core18_*.snap

ubuntu-image/ubuntu-image snap \
    --image-size 4G \
    --snap pc_*.snap \
    --snap pc-kernel_*.snap \
    --snap snapd_*.snap \
    --snap core18_*.snap \
    mvo-amd64.signed

echo "Run something like (note that the OVMF from 18.04+ does not work)"
echo "kvm -m 2000 -bios /usr/share/qemu/OVMF.fd pc.img"
