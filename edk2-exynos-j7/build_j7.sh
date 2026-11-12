#!/bin/bash
# Exynos 7580 (Galaxy J7 2015) icin EDK2 UEFI firmware derler.
#
# Bu dosya edk2-exynos agacinin KOKUNDE durur. Tek basina calismaz: once
#   ./build.sh setup j7        (veya  bash scripts/setup-edk2.sh)
# ile edk2-exynos + edk2 klonlanip Platform/Samsung/exynos7580 ve
# Silicon/Samsung/Exynos7580Pkg bu repodan kopyalanmis olmalidir.
#
# Kullanim:
#   ./build_j7.sh                 # DEBUG  (varsayilan)
#   ./build_j7.sh RELEASE
#   ./build_j7.sh DEBUG --clean   # Build/ dizinini silip bastan derle
#   TARGET=RELEASE ./build_j7.sh
#
# Gereken paketler (Ubuntu/Debian):
#   build-essential uuid-dev iasl nasm python3 python-is-python3 git
#   gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu
# Gereken EDK2 alt modulleri: BaseTools/Source/C altindaki her sey (setup betigi
# bunlari zaten derler; elle: make -C BaseTools/Source/C).
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

TARGET="${1:-${TARGET:-DEBUG}}"
CLEAN="${2:-}"
PREFIX="${GCC5_AARCH64_PREFIX:-aarch64-linux-gnu-}"
DEVICE="${DEVICE:-j7}"

die() { echo "HATA: $*" >&2; exit 1; }

[ -f build.sh ] || die "build.sh yok. Bu betik edk2-exynos agacinin kokunde calismali (bkz. scripts/setup-edk2.sh)."
[ -d BaseTools ] || die "BaseTools yok. edk2 alt modulu eksik: git submodule update --init --recursive"
[ -d Platform/Samsung/exynos7580 ] || die "Platform/Samsung/exynos7580 yok. ./build.sh setup $DEVICE calistir (veya scripts/setup-edk2.sh)."
[ -d Silicon/Samsung/Exynos7580Pkg ] || die "Silicon/Samsung/Exynos7580Pkg yok. ./build.sh setup $DEVICE calistir."

command -v "${PREFIX}gcc" >/dev/null 2>&1 || die "${PREFIX}gcc bulunamadi. Kur: sudo apt install gcc-aarch64-linux-gnu"
command -v python3 >/dev/null 2>&1 || die "python3 bulunamadi."
command -v iasl >/dev/null 2>&1 || echo "UYARI: iasl yok; ACPI tablolari derlenemezse 'sudo apt install iasl' gerekir." >&2

# BaseTools'un C parcalari (GenFw, GenFfs, VfrCompile...) derlenmis mi?
if [ ! -x BaseTools/Source/C/bin/GenFw ] || [ ! -x BaseTools/Source/C/bin/VfrCompile ]; then
  echo ">> BaseTools/Source/C derleniyor"
  make -C BaseTools/Source/C -j"$(nproc)"
fi

if [ "$CLEAN" = "--clean" ] || [ "$CLEAN" = "clean" ]; then
  echo ">> Build/$DEVICE siliniyor"
  rm -rf "Build/$DEVICE"
fi

# FDF'ye gomulen ikili dosyalar olmadan derleme yarida kalir; erken ve net hata verelim.
BIN="Platform/Samsung/exynos7580/Binaries"
for f in grubaa64.efi linux-Image j7elte.dtb startup.nsh; do
  [ -s "$BIN/$f" ] || die "$BIN/$f yok/bos. Once: ./build-grub.sh ve ./build-linux.sh (veya ./build-all.sh)"
done

echo ">> EDK2 derleniyor: device=$DEVICE target=$TARGET prefix=$PREFIX"
GCC5_AARCH64_PREFIX="$PREFIX" ./build.sh -d "$DEVICE" -t GCC5 -r "$TARGET"

FD="Build/$DEVICE/${TARGET}_GCC5/FV/EXYNOS7580_UEFI.fd"
[ -f "$FD" ] || FD="Build/$DEVICE/${TARGET}_GCC5/FV/EXYNOS7580Pkg.fd"
if [ -f "$FD" ]; then
  echo
  echo "TAMAM: $FD  ($(stat -c %s "$FD") bayt, sha256 $(sha256sum "$FD" | cut -c1-16)...)"
  echo "Yazmak icin: python3 tools/package_boot.py $FD <cikti-adi>  (veya tools/ altindaki yardimcilar)"
else
  echo "Derleme bitti ama $FD bulunamadi; Build/$DEVICE/${TARGET}_GCC5/FV/ icerigine bak." >&2
  exit 1
fi
