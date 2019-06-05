#!/bin/sh

sudo kvm \
  -bios /usr/share/ovmf/OVMF.fd \
  -smp 2 -m 2000 -netdev user,id=mynet0,hostfwd=tcp::8022-:22,hostfwd=tcp::8090-:80 \
  -device virtio-net-pci,netdev=mynet0 \
  -drive file=pc.img,format=raw
