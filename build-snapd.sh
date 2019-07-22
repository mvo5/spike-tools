#!/bin/bash

set -e

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
}

build_snapd
