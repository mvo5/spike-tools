#!/bin/bash

set -e

build_mke2fs() {
    git clone https://git.kernel.org/pub/scm/fs/ext2/e2fsprogs.git
    (cd e2fsprogs
     git checkout v1.45.1
     ./configure --disable-elf-shlibs
     make LDFLAGS=-static)
    cp e2fsprogs/misc/mke2fs .
}

build_grub_editenv() {
    git clone git://git.savannah.gnu.org/grub.git
    (cd grub; \
     ./bootstrap; \
     ./configure --disable-device-mapper; \
     make; \
     rm grub-editenv; \
     make grub-editenv LDFLAGS=-static)
    cp grub/grub-editenv .
}

get_ubuntu_core() {
    prnum=$1
    git clone https://github.com/CanonicalLtd/ubuntu-image
    (cd ubuntu-image;
     git fetch origin pull/$prnum/head:pr-$prnum
     git checkout pr-$prnum
    )
}


# Also needed:
# https://github.com/CanonicalLtd/ubuntu-image/pull/171
# https://github.com/snapcore/snapd/pull/6899


build_mke2fs
build_grub_editenv
#get_ubuntu_core 171
