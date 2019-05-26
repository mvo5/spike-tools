#!/bin/bash

set -e

export PYTHONPATH=./ubuntu-image

./inject-initramfs.sh \
    -o pc-kernel_214.snap \
    -b mke2fs,grub-editenv \
    pc-kernel_214-orig.snap core-build/initramfs

ubuntu-image/ubuntu-image snap \
    --snap pc-amd64-gadget/pc_20-0.1_amd64.snap \
    --snap pc-kernel_214.snap \
    mvo-amd64.signed
