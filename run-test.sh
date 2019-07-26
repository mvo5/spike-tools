#!/bin/sh

TPM=tpm

usage() {
    echo "Usage: $0 [-c]"
    exit
}

while getopts "hc" opt; do
    case "${opt}" in
        c)
            rm -f "$TPM"/*
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))


TPM="/var/snap/swtpm-mvo/current/"

sudo kvm \
  -smp 2 -m 256 -netdev user,id=mynet0,hostfwd=tcp::8022-:22,hostfwd=tcp::8090-:80 \
  -device virtio-net-pci,netdev=mynet0 \
  -pflash /usr/share/OVMF/OVMF_CODE.fd \
  -drive file=OVMF_VARS.fd,if=pflash,format=raw \
  -chardev socket,id=chrtpm,path="$TPM"/swtpm-sock -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis,tpmdev=tpm0 \
  -drive file=pc.img,format=raw \
  -drive file=sbtestdb/drive.img
