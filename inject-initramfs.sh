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
    start=$(binwalk "$rootdir/initrd.img"|grep LZMA|cut -f1 -d' ')
    dd if="$rootdir/initrd.img" bs=16M | (dd of=/dev/null bs=$start count=1; dd bs=16M) | \
       unlzma | cpio -D "$fsdir" -id
}

inject() {
    echo "Injecting $initramfs..."
    cp -rap "$initramfs"/conf/* "$confdir"
    cp -rap "$initramfs"/scripts/* "$scriptdir"
}

repack() {
    echo "Repacking initramfs..."
    mv "$rootdir/initrd.img" "$tmpdir/initrd.img"
    dd if="$tmpdir/initrd.img" of="$rootdir/initrd.img" bs=$start count=1
    (cd "$fsdir"; find . | cpio -ov | lzma -c) >> "$rootdir/initrd.img"
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
confdir="$fsdir"/conf/conf.d
scriptdir="$fsdir"/scripts

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

