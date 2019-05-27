#!/bin/bash

set -e

add_cleanup() {
    if [ ! -x cleanup.sh ]; then
        echo '#!/bin/sh' > cleanup.sh
        echo '# (no set -e on purpose)'  >> cleanup.sh
        chmod +x cleanup.sh
    fi
    echo "$@" >> cleanup.sh
}

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

get_ubuntu_image() {
    REPO="https://github.com/mvo5/ubuntu-image.git"
    BRANCH="uc20-recovery"
    
    git clone -b "$BRANCH" "$REPO"
}

add_bind_mount() {
    SRC="$1"
    DST="$2"
    if [ -e "$2" ]; then
        sudo mount -o bind "$1" "$2"
        add_cleanup "sudo umount $2"
    fi
}

get_snapd_uc20() {
    REPO="https://github.com/mvo5/snappy.git"
    BRANCH="prepare-image-with-recovery"
    
    GOPATH="$(pwd)/go"
    DST="$GOPATH/src/github.com/snapcore/snapd"
    
    # fake GOPATH
    export GOPATH
    mkdir -p "$DST"
    if [ ! -d "$DST/cmd/snap" ]; then
        git clone -b "$BRANCH" "$REPO" "$DST"
    fi
    (cd "$DST" && ./get-deps.sh)

    go build -o go/snap github.com/snapcore/snapd/cmd/snap

    # this alters the system state :/
    # use "./cleanup.sh" to restore things
    for m in /snap/core/current/usr/bin/snap /snap/snapd/current/usr/bin/snap /usr/bin/snap; do
        add_bind_mount "./go/snap" "$m"
    done
}

if [ ! -d ./ubuntu-image ]; then
    get_ubuntu_image
fi

if [ ! -d ./core-build ]; then
    REPO="https://github.com/cmatsuoka/core-build.git"
    BRANCH="install-script"
    
    git clone -b "$BRANCH" "$REPO"
fi

# FIXME: once we put snapd in channel=20 this is no longer needed
#        we can just use the "snapd" snap from channel=20
if [ ! -x ./go/src/github.com/snapcore/snapd/cmd/snap/snap ]; then
    get_snapd_uc20
fi

if [ ! -e mvo-amd64.signed ]; then
    wget https://people.canonical.com/~mvo/tmp/mvo-amd64.signed
fi

# get the snaps
snap download --channel=18 pc-kernel
snap download snapd    # --channel=20 (once available)
snap download core18   # core20 (once available)
snap download --channel=20/edge pc

if [ ! -d e2fsprogs ]; then
    build_mke2fs
fi
if [ ! -d grub ]; then
    build_grub_editenv
fi
#get_ubuntu_core 171