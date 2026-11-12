#!/bin/bash
# ProjectEku J7 icin Alpine rootfs imaji uretir (PC'de, root gerekmez; e2fsprogs >= 1.43 'mke2fs -d' yeterli).
#   ./make_alpine_rootfs.sh [boyut_MB]      varsayilan 64  -> rootfs-alpine-j7.img (ext4, etiket ROOTFS)
# Alpine arm64 minirootfs'i sabit surumden (3.20.10) GitHub'dan alir ve sha512 ile dogrular.
set -e
SIZE=${1:-64}
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
git clone -q --depth 1 --branch v3.20 https://github.com/alpinelinux/docker-alpine.git "$W/d"
( cd "$W/d" && grep 'aarch64/alpine-minirootfs-3.20.10' checksums.sha512 | sed 's#aarch64/##' | (cd aarch64 && sha512sum -c -) )
mkdir "$W/root" && sudo tar -xzpf "$W/d/aarch64/alpine-minirootfs-3.20.10-aarch64.tar.gz" --numeric-owner -C "$W/root" 2>/dev/null || tar -xzpf "$W/d/aarch64/alpine-minirootfs-3.20.10-aarch64.tar.gz" --numeric-owner -C "$W/root"
cat > "$W/root/etc/inittab" <<'EOT'
# ProjectEku Alpine - BusyBox init (Galaxy J7, Linux 6.12, ekran konsolu)
::sysinit:/bin/hostname -F /etc/hostname
::sysinit:/bin/sh -c 'echo; echo "=== ProjectEku Alpine rootfs OK ==="; uname -a; cat /etc/alpine-release; df -h / | tail -1; echo "giris aygitlari:"; grep "Name=" /proc/bus/input/devices 2>/dev/null || echo "  (yok)"; echo'
::respawn:-/bin/sh
::ctrlaltdel:/sbin/reboot
::shutdown:/bin/sync
EOT
echo projecteku > "$W/root/etc/hostname"; printf 'ProjectEku Alpine\n' > "$W/root/etc/motd"
rm -f rootfs-alpine-j7.img; truncate -s ${SIZE}M rootfs-alpine-j7.img
mke2fs -q -t ext4 -L ROOTFS -d "$W/root" rootfs-alpine-j7.img
e2fsck -fn rootfs-alpine-j7.img | tail -1
echo "tamam: rootfs-alpine-j7.img"
