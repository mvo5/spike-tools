#!/bin/bash
#
# Use this script to inject stuff into an existing core snap.
#
# Example:
# $ ./inject-core -b mke2fs -o core18.snap ../core18_970.snap


source /usr/share/initramfs-tools/hook-functions

set -e

unsquash() {
    echo "Unsquashing $core..."
    unsquashfs -d "$rootdir" "$core"
}

add_binary() {
    if [ ! -z "$addlist" ]; then
        list=$(echo $addlist | tr , '\n')
        for bin in $list; do
            echo "Installing $bin..."
            cp $bin "$bindir"
        done
    fi
}

resquash() {
    if [ -z "$output" ]; then
        num=1
        while [ -f "$core.$num" ]; do
            num=$((num + 1))
        done
        output="$core.$num"
    fi
    mksquashfs "$rootdir" "$output" -noappend -comp gzip -no-xattrs -no-fragments
    echo "Created $output"
}

usage() {
    echo "Usage: $0 [-o output] [-a bins] <core snap>"
    exit
}

while getopts "ho:b:" opt; do
    case "${opt}" in
        o)
            output="$OPTARG"
            ;;
        b)
            addlist="$OPTARG"
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ $# -lt 1 ]; then
    usage
fi


core="$1"
tmpdir=$(mktemp -d -t inject-XXXXXXXXXX)
rootdir="$tmpdir/root"
bindir="$rootdir"/bin/

function finish {
    echo "Cleaning up"
    rm -Rf "$tmpdir"
}
trap finish EXIT

unsquash
add_binary
resquash

