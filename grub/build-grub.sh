#!/bin/bash
# ProjectEku GRUB imaji: GRUB 2.12 (arm64-efi) + J7 zamanlayici yamasi + gomulu menu (memdisk).
#
# Kullanim:  ./build-grub.sh [cikti_dizini]      varsayilan cikti: build/grub
# Cikti:     build/grub/grubaa64.efi   (+ memdisk.tar)
#
# Gereken paketler: build-essential bison flex gawk curl xz-utils gcc-aarch64-linux-gnu
#   NOT: mawk YETMEZ (asorti yok) -> AWK=gawk veriyoruz.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
OUT="${1:-$REPO/build/grub}"
WORK="${WORK:-$REPO/build/work}"
VER="${GRUB_VER:-2.12}"
CROSS="${CROSS:-aarch64-linux-gnu-}"
JOBS="$(nproc)"

mkdir -p "$OUT" "$WORK"

need() { command -v "$1" >/dev/null 2>&1 || { echo "HATA: $1 bulunamadi ($2)" >&2; exit 1; }; }
need "${CROSS}gcc" "sudo apt install gcc-aarch64-linux-gnu"
need gawk          "sudo apt install gawk"
need bison         "sudo apt install bison"
need flex          "sudo apt install flex"
need curl          "sudo apt install curl"
need python3       "sudo apt install python3"

SRC="$WORK/grub-$VER"
if [ ! -d "$SRC" ]; then
  echo ">> GRUB $VER indiriliyor"
  curl -sSfL -o "$WORK/grub2_$VER.orig.tar.xz" \
    "https://ftp.gnu.org/gnu/grub/grub-$VER.tar.xz" ||
  curl -sSfL -o "$WORK/grub2_$VER.orig.tar.xz" \
    "https://archive.ubuntu.com/ubuntu/pool/main/g/grub2/grub2_$VER.orig.tar.xz"
  tar -C "$WORK" -xf "$WORK/grub2_$VER.orig.tar.xz"
fi

cd "$SRC"
if ! grep -q "ProjectEku" grub-core/kern/arm64/efi/init.c 2>/dev/null; then
  echo ">> J7 CNTFRQ yamasi uygulaniyor"
  patch -p1 --forward < "$HERE/grub-$VER-j7-cntfrq.patch"
fi

PREFIX="$WORK/grubinst"
if [ ! -x "$PREFIX/bin/grub-mkimage" ]; then
  echo ">> GRUB yapilandiriliyor ve derleniyor"
  ./configure --target=aarch64-linux-gnu --with-platform=efi --disable-werror --disable-nls \
    --disable-grub-mkfont --disable-grub-themes --disable-grub-emu-sdl --prefix="$PREFIX" \
    TARGET_CC="${CROSS}gcc" TARGET_OBJCOPY="${CROSS}objcopy" TARGET_STRIP="${CROSS}strip" \
    TARGET_NM="${CROSS}nm" TARGET_RANLIB="${CROSS}ranlib"
  # tarball'da bootstrap calismadigi icin eksik olan dosya:
  touch grub-core/extra_deps.lst
  make -j"$JOBS" AWK=gawk
  make install AWK=gawk
fi

echo ">> memdisk (gomulu menu)"
MEM="$WORK/memroot"
rm -rf "$MEM"; mkdir -p "$MEM/boot/grub"
cp "$HERE/grub.cfg" "$MEM/boot/grub/grub.cfg"
( cd "$MEM" && tar --format=ustar -cf "$OUT/memdisk.tar" boot )

echo ">> grubaa64.efi uretiliyor"
"$PREFIX/bin/grub-mkimage" -O arm64-efi -d "$PREFIX/lib/grub/arm64-efi" \
  -o "$OUT/grubaa64.efi" -p '(memdisk)/boot/grub' -m "$OUT/memdisk.tar" \
  normal minicmd configfile echo sleep memdisk tar chain boot linux part_gpt part_msdos \
  fat test read halt reboot terminal search cat ls help date time

echo "TAMAM: $OUT/grubaa64.efi ($(stat -c %s "$OUT/grubaa64.efi") bayt)"
