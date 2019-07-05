#!/bin/bash

set -e

add_bind_mount() {
    SRC="$1"
    DST="$2"
    if [ -e "$DST" ]; then
        sudo mount -o bind "$SRC" "$DST"
        #add_cleanup "sudo umount $DST"
    fi
}

build_snapd() {
    REPO="https://github.com/snapcore/snapd.git"
    BRANCH="uc20"

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
    go build -o go/snapd github.com/snapcore/snapd/cmd/snapd

    # this alters the system state :/
    # use "./cleanup.sh" to restore things
    for m in /snap/core/current/usr/bin/snap /snap/snapd/current/usr/bin/snap /usr/bin/snap; do
        add_bind_mount "./go/snap" "$m"
    done
}

./cleanup.sh || true
build_snapd
