#!/bin/bash

set -e

export PYTHONPATH=./ubuntu-image

./inject-initramfs.sh \
    -o pc-kernel_214.snap \
    -b ./e2fsprogs/misc/mke2fs,grub-editenv \
    pc-kernel_*.snap core-build/initramfs

ubuntu-image/ubuntu-image snap \
    --snap pc_*.snap \
    --snap pc-kernel_*.snap \
    --snap snapd_*.snap \
    --snap core18_*.snap
    mvo-amd64.signed
