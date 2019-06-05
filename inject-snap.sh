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

add_files() {
    if [ "${#files[@]}" -gt 0 ]; then
        for item in ${files[@]}; do
            IFS=":" read -ra A <<< "$item"
            destdir=${A[0]}
            list=$(echo ${A[1]} | tr , '\n')
            for f in $list; do
                echo "Installing $f..."
                cp $f "$rootdir/$destdir"
            done
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
    echo "Usage: $0 [-o output] [-f destdir:filelist] <file list> <snap>"
    exit
}


tmpdir=$(mktemp -d -t inject-XXXXXXXXXX)
rootdir="$tmpdir/root"
files=()

while getopts "ho:f:" opt; do
    case "${opt}" in
        o)
            output="$OPTARG"
            ;;
        f)
            files+=("$OPTARG")
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

snap="$1"

function finish {
    echo "Cleaning up"
    rm -Rf "$tmpdir"
}
trap finish EXIT

unsquash
add_files
resquash

