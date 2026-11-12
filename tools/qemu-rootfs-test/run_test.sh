#!/bin/bash
# init'in rootfs devrini QEMU'da dener (J7 gerekmez). Gerekenler: qemu-system-arm gdisk e2fsprogs gcc-aarch64-linux-gnu
# 1) Kernel: J7 yapilandirmasi + virtio/pl011/psci (linux/kernel.config ustune):
#      scripts/config -e SERIAL_AMBA_PL011 -e SERIAL_AMBA_PL011_CONSOLE -e VIRTIO_MENU -e VIRTIO -e VIRTIO_MMIO -e VIRTIO_BLK -e BLK_DEV -e ARM_PSCI_FW
#      make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig Image      -> qemu-Image
# 2) Disk: GPT, p1 "USERDATA" (init YOK, atlanmali), p2 "SYSTEM" (/sbin/init VAR)
set -e
aarch64-linux-gnu-gcc -static -O2 -o eku_test_init eku_test_init.c
mkdir -p rootA/etc rootB/sbin && echo "android-benzeri, init yok" > rootA/etc/note
cp eku_test_init rootB/sbin/init && touch rootB/EKU_MARKER_SYSTEM
truncate -s 24M fsA.img && mke2fs -q -t ext4 -d rootA fsA.img
truncate -s 24M fsB.img && mke2fs -q -t ext4 -d rootB fsB.img
truncate -s 64M disk.img && sgdisk -o disk.img >/dev/null
sgdisk -n 1:2048:+24M -c 1:USERDATA -n 2:0:+24M -c 2:SYSTEM disk.img >/dev/null
dd if=fsA.img of=disk.img bs=512 seek=2048  conv=notrunc status=none
dd if=fsB.img of=disk.img bs=512 seek=51200 conv=notrunc status=none
timeout 170 qemu-system-aarch64 -M virt,gic-version=2 -cpu cortex-a53 -smp 1 -m 1024 -nographic -monitor none -no-reboot -nic none \
  -kernel qemu-Image -append "console=ttyAMA0 ignore_loglevel rdinit=/init maxcpus=1 eku.root=auto" \
  -drive file=disk.img,format=raw,if=none,id=d0 -device virtio-blk-device,drive=d0 | tee q.log | grep -E 'j7init|EKU-TEST'
