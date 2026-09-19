#!/bin/sh
set -eu

make -C buildroot \
  O=/work/output \
  BR2_EXTERNAL=/work/buildroot-external \
  qemu_riscv64_virt_nerves_defconfig

make -C /work/output

rm -rf /export/images
cp -a /work/output/images /export/images
cp /work/output/.config /export/.config
