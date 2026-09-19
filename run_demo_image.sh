#!/bin/sh

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

BASE_DIR="${SCRIPT_DIR}/base_image/output/images"
DEMO_RELEASE_DIR="${SCRIPT_DIR}/demo/_build/dev/rel"

KERNEL="${BASE_DIR}/Image"
FIRMWARE="${BASE_DIR}/fw_jump.bin"
ROOTFS="${DEMO_RELEASE_DIR}/demo.squashfs"

qemu-system-riscv64 -M virt -bios "${FIRMWARE}" -nographic -m 256 \
    -kernel "${KERNEL}" -append "rootwait root=/dev/vda" \
    -netdev user,id=eth0,hostfwd=tcp::2222-:22 \
    -device virtio-net-device,netdev=eth0 \
    -drive file="${ROOTFS}",if=none,format=raw,id=hd0 -device virtio-blk-device,drive=hd0

