#!/bin/bash
#
# Use this script to inject stuff into an existing snap.
#
# Example:
# $ ./inject-snap -o core18.snap -d bin mke2fs ../core18_970.snap


source /usr/share/initramfs-tools/hook-functions

set -e

unsquash() {
    echo "Unsquashing $snap..."
    unsquashfs -d "$rootdir" "$snap"
}

add_file() {
    if [ ! -z "$addlist" ]; then
        list=$(echo $addlist | tr , '\n')
        for f in $list; do
            echo "Installing $f..."
            cp $f "$destdir"
        done
    fi
}

resquash() {
    if [ -z "$output" ]; then
        num=1
        while [ -f "$snap.$num" ]; do
            num=$((num + 1))
        done
        output="$snap.$num"
    fi
    mksquashfs "$rootdir" "$output" -noappend -comp gzip -no-xattrs -no-fragments
    echo "Created $output"
}

usage() {
    echo "Usage: $0 [-o output] [-d destdir] <file list> <snap>"
    exit
}


tmpdir=$(mktemp -d -t inject-XXXXXXXXXX)
rootdir="$tmpdir/root"
destdir="$rootdir"

while getopts "ho:d:" opt; do
    case "${opt}" in
        o)
            output="$OPTARG"
            ;;
        d)
            destdir="$rootdir/$OPTARG"
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ $# -lt 2 ]; then
    usage
fi

addlist="$1"
snap="$2"

function finish {
    echo "Cleaning up"
    rm -Rf "$tmpdir"
}
trap finish EXIT

unsquash
add_file
resquash

