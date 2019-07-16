#!/bin/bash
#
# Use this script to inject content from core-build/initramfs into an existing
# kernel snap.
#
# Example:
# $ ./inject-initramfs -o kernel.snap ../kernel_214.snap core-build/initramfs


source /usr/share/initramfs-tools/hook-functions

set -e

unsquash() {
    echo "Unsquashing $kernel..."
    unsquashfs -d "$rootdir" "$kernel"
}

extract() {
    echo "Extracting initramfs..."
    unmkinitramfs "$rootdir/initrd.img" "$fsdir"
}

inject() {
    echo "Injecting $initramfs..."
    cp -rap "$initramfs"/conf/* "$confdir"
    cp -rap "$initramfs"/scripts/* "$scriptdir"

    # rebuild script order cache
    CONFDIR="$fsdir/main"
    for b in $(cd "$scriptdir" && find . -mindepth 1 -type d); do
        cache_run_scripts "$fsdir/main" "/scripts/${b#./}"
    done
}

add_files() {
    if [ "${#files[@]}" -gt 0 ]; then
        for item in ${files[@]}; do
            IFS=":" read -ra A <<< "$item"
            destdir=${A[0]}
            list=$(echo ${A[1]} | tr , '\n')
            for f in $list; do
                echo "Installing $f..."
                mkdir -p "$fsdir/main/$destdir"
                cp $f "$fsdir/main/$destdir"
            done
        done
    fi
}

run_depmod() {
    depmod -b "$fsdir/main" 4.15.0-54-generic
}

repack() {
    echo "Repacking initramfs..."
    (cd "$fsdir/early"; find . | cpio -H newc -o) > "$rootdir/initrd.img"
    (cd "$fsdir/main"; find . | cpio -H newc -o | gzip -c) >> "$rootdir/initrd.img"
}

resquash() {
    if [ -z "$output" ]; then
        num=1
        while [ -f "$kernel.$num" ]; do
            num=$((num + 1))
        done
        output="$kernel.$num"
    fi
    mksquashfs "$rootdir" "$output" -noappend -comp gzip -no-xattrs -no-fragments
    echo "Created $output"
}

usage() {
    echo "Usage: $0 [-o output] [-a bins] <kernel snap> <initramfs>"
    exit
}

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

if [ $# -lt 2 ]; then
    usage
fi


kernel="$1"
initramfs="$2"
tmpdir=$(mktemp -d -t inject-XXXXXXXXXX)
rootdir="$tmpdir/root"
fsdir="$tmpdir/fs"
confdir="$fsdir"/main/conf/conf.d/
scriptdir="$fsdir"/main/scripts/

mkdir -p "$confdir" "$scriptdir"

function finish {
    echo "Cleaning up"
    rm -Rf "$tmpdir"
}
trap finish EXIT

unsquash
extract
inject
add_files
run_depmod
repack
resquash

