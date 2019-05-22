#!/bin/bash

unsquash() {
    echo "Unsquashing $kernel..."
    unsquashfs -d "$rootdir" "$kernel"
}

append() {
    echo "Appending to initramfs..."
    cp -rap "$initramfs"/conf/* "$confdir"
    cp -rap "$initramfs"/scripts/* "$scriptdir"
    (cd "$fsdir"; find . | cpio -o --no-absolute-filenames >> "$rootdir/initrd.img")
}

extract() {
    echo "Extracting initramfs..."
    unmkinitramfs "$rootdir/initrd.img" "$fsdir"
}

inject() {
    echo "Injecting $initramfs..."
    cp -rap "$initramfs"/conf/* "$confdir"
    cp -rap "$initramfs"/scripts/* "$scriptdir"
}

repack() {
    echo "Repacking initramfs..."
    (cd "$fsdir/early"; find . | cpio -H newc -o) > "$rootdir/initrd.img"
    (cd "$fsdir/main"; find . | cpio -H newc -o | gzip -c) >> "$rootdir/initrd.img"
}

resquash() {
    num=1
    while [ -f "$kernel.$num" ]; do
        num=$((num + 1))
    done
    mksquashfs "$rootdir" "$kernel.$num" -noappend -comp xz -no-xattrs -no-fragments
    echo "Created $kernel.$num"
}

usage() {
    echo "Usage: $0 <kernel snap> <initramfs>"
    exit
}

while getopts "h" opt; do
    case "${opt}" in
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
confdir="$fsdir"/main/conf/conf.d
scriptdir="$fsdir"/main/scripts

mkdir -p "$confdir" "$scriptdir"

function finish {
    echo "Cleaning up"
    rm -Rf "$tmpdir"
}
trap finish EXIT

unsquash
extract
inject
repack
resquash

