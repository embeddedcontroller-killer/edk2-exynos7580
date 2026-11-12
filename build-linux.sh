#!/bin/bash
# Galaxy J7 (2015) / Exynos 7580 icin Linux 6.12 kernel + initramfs + DTB uretir.
#
# Kullanim:  ./build-linux.sh [cikti_dizini]        varsayilan cikti: build/linux
# Cikti:     build/linux/Image, build/linux/j7elte.dtb, build/linux/j7elte-rootfs.dtb,
#            build/linux/modules/*.ko, build/linux/initramfs.cpio.gz
#
# Not: kaynak agaci build/work/linux-<surum> altinda kalir; ikinci kosu hizli gecer.
# Gereken paketler: gcc-aarch64-linux-gnu bison flex bc libssl-dev libelf-dev
#                   device-tree-compiler xz-utils cpio python3 make
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
OUT="${1:-$REPO/build/linux}"
WORK="${WORK:-$REPO/build/work}"
VER="${KERNEL_VER:-6.12}"
CROSS="${CROSS:-aarch64-linux-gnu-}"
JOBS="$(nproc)"
L="$HERE"

mkdir -p "$OUT/modules" "$WORK"
export ARCH=arm64 CROSS_COMPILE="$CROSS"

need() { command -v "$1" >/dev/null 2>&1 || { echo "HATA: $1 bulunamadi ($2)" >&2; exit 1; }; }
need "${CROSS}gcc" "sudo apt install gcc-aarch64-linux-gnu"
need bc      "sudo apt install bc"
need flex    "sudo apt install flex"
need bison   "sudo apt install bison"
need dtc     "sudo apt install device-tree-compiler"

SRC="$WORK/linux-$VER"
if [ ! -d "$SRC" ]; then
  echo ">> Linux $VER indiriliyor"
  TARBALL="$WORK/linux-$VER.tar.xz"
  [ -s "$TARBALL" ] || curl -sSfL -o "$TARBALL" "https://cdn.kernel.org/pub/linux/kernel/v${VER%%.*}.x/linux-$VER.tar.xz"
  tar -C "$WORK" -xf "$TARBALL"
fi

cd "$SRC"
if [ ! -f .j7_patched ]; then
  echo ">> j7-kernel-v9.patch uygulaniyor"
  patch -p1 --forward < "$L/j7-kernel-v9.patch"
  touch .j7_patched
fi

echo ">> Yapilandirma: kernel.config + frag.config"
cp "$L/kernel.config" .config
"$SRC/scripts/kconfig/merge_config.sh" -m -O . "$L/frag.config" >/dev/null 2>&1 || {
  echo "UYARI: merge_config.sh calismadi, frag.config elle ekleniyor" >&2
  cat "$L/frag.config" >> .config
}
make ARCH=arm64 CROSS_COMPILE="$CROSS" olddefconfig

echo ">> 1. gecis: Image + modules"
make -j"$JOBS" Image modules

echo ">> moduller toplaniyor"
grep -v '^CONFIG_INITRAMFS_SOURCE' .config > "$OUT/kernel.config.used"
find . -name '*.ko' -newer .j7_patched -exec cp -f {} "$OUT/modules/" \; 2>/dev/null || true
# ekran/konsol icin gereken modul listesi depoda; eksik olani uyaralim
while read -r m; do
  [ -z "$m" ] && continue
  [ -f "$OUT/modules/$m.ko" ] || echo "UYARI: $m.ko uretilmedi (initramfs'te eksik olacak)" >&2
done < "$L/eku-modules.txt"

echo ">> initramfs"
# ekran konsolu fontu (j7fbcon.h icinde hazir; yalnizca kernel kaynagindan yeniden uretmek istersen)
python3 "$L/gen_font8x16.py" "$SRC/lib/fonts/font_8x16.c" > "$OUT/font8x16.h" 2>/dev/null \
  && echo ">> font8x16.h uretildi ($OUT/font8x16.h)"
IR="$WORK/initramfs-root"
rm -rf "$IR"; mkdir -p "$IR"/{dev,proc,sys,mnt,lib/modules}
cp -f "$L/init.c" "$IR/init"
cp -f "$OUT/modules/"*.ko "$IR/lib/modules/" 2>/dev/null || true
cp -f "$L/eku-modules.txt" "$IR/lib/modules/" 2>/dev/null || true
chmod 0755 "$IR/init"
( cd "$IR" && find . -print0 | cpio --null -o -H newc --owner=0:0 2>/dev/null | gzip -9 ) > "$OUT/initramfs.cpio.gz"

echo ">> 2. gecis: Image (gomulu initramfs ile)"
# kernel.config'teki mutlak initramfs yolunu (eski makineye ait) kendi kokumuze cevir
scripts/config --file .config -s INITRAMFS_SOURCE "$IR"
make -j"$JOBS" olddefconfig
make -j"$JOBS" Image
cp -f arch/arm64/boot/Image "$OUT/Image"

echo ">> DTB"
dtc -I dts -O dtb -o "$OUT/j7elte.dtb" "$L/j7elte.dts" 2>/dev/null || cp -f "$L/j7elte.dtb" "$OUT/j7elte.dtb"
dtc -I dts -O dtb -o "$OUT/j7elte-rootfs.dtb" "$L/j7elte-rootfs.dts" 2>/dev/null || cp -f "$L/j7elte-rootfs.dtb" "$OUT/j7elte-rootfs.dtb"

echo "TAMAM: $OUT/Image ($(stat -c %s "$OUT/Image") bayt), $OUT/j7elte.dtb, $OUT/modules/ ($(ls -1 "$OUT/modules" 2>/dev/null | wc -l) dosya)"
