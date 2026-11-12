#!/bin/bash
# edk2-exynos + edk2 agacini hazirlar ve bu repodaki J7 portunu icine kopyalar.
#
# Kullanim:
#   ./scripts/setup-edk2.sh                 # build/work/edk2-exynos icine kurar
#   EDK2_DIR=~/edk2-exynos ./scripts/setup-edk2.sh
#   ./scripts/setup-edk2.sh --force         # var olan agaci sil bastan klonla
#
# Sonuc: EDK2_DIR icinde Platform/Samsung/exynos7580, Silicon/Samsung/Exynos7580Pkg,
#        Silicon/Samsung/ExynosPkg/ExynosCommonDsc.j7.inc ve kokte build_j7.sh hazir olur.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
P="$REPO/edk2-exynos-j7"

# edk2-exynos: portun uretildigi taban commit. Fork/guncel dal kullanmak icin EDK2_REF gec.
EDK2_URL="${EDK2_URL:-https://github.com/sonic011gamer/edk2-exynos.git}"
EDK2_REF="${EDK2_REF:-c000354}"
EDK2_DIR="${EDK2_DIR:-$REPO/build/work/edk2-exynos}"

FORCE=0
[ "${1:-}" = "--force" ] && FORCE=1

need() { command -v "$1" >/dev/null 2>&1 || { echo "HATA: $1 bulunamadi ($2)" >&2; exit 1; }; }
need git "sudo apt install git"

if [ "$FORCE" = 1 ] && [ -d "$EDK2_DIR" ]; then
  echo ">> $EDK2_DIR siliniyor (--force)"
  rm -rf "$EDK2_DIR"
fi

if [ ! -d "$EDK2_DIR/.git" ]; then
  echo ">> edk2-exynos klonlaniyor -> $EDK2_DIR"
  git clone "$EDK2_URL" "$EDK2_DIR"
  ( cd "$EDK2_DIR" && git checkout "$EDK2_REF" )
fi

cd "$EDK2_DIR"
echo ">> alt moduller (edk2, edk2-platforms, SimpleInit, EFI_Binaries)"
git submodule update --init --recursive

# BaseTools edk2 agacinin icinde: edk2-exynos'da Common/edk2/BaseTools
EDK2_BASE=""
for c in Common/edk2 BaseTools edk2; do
  [ -d "$c/BaseTools" ] && { EDK2_BASE="$c"; break; }
done
[ -n "$EDK2_BASE" ] || { echo "HATA: BaseTools bulunamadi (edk2 alt modulu eksik)" >&2; exit 1; }
# BaseTools'un eski C kodu (VfrCompile -> Pccts/dlg) GCC 14+ ile derlenmiyor. Iki care:
#   1) GCC 13/12 kuruluysa onu kullan (CC/CXX ile),
#   2) ya da distro'nun iasl/nasm + hazir BaseTools'u olan bir ortam kullan.
# CI'da ubuntu-22.04 (GCC 11) sorunsuz derler.
BUILD_CC="${BUILD_CC:-$(command -v gcc-13 || command -v gcc-12 || command -v gcc)}"
BUILD_CXX="${BUILD_CXX:-$(command -v g++-13 || command -v g++-12 || command -v g++)}"
echo ">> BaseTools derleyicisi: $BUILD_CC"

echo ">> BaseTools/Source/C derleniyor ($EDK2_BASE/BaseTools)"
# Not: yeni GCC (>=14) BaseTools'un eski kodunda -Werror'a takilir; uyarilari hata saymiyoruz.
if ! make -C "$EDK2_BASE/BaseTools/Source/C" -j"$(nproc)" CC="$BUILD_CC" CXX="$BUILD_CXX" \
      BUILD_CFLAGS="-Wno-error -Wno-unused-but-set-variable -Wno-error=unused-but-set-variable" \
      BUILD_CXXFLAGS="-Wno-error"; then
  echo "UYARI: BaseTools derlenemedi (GCC cok yeni olabilir: VfrCompile/Pccts)." >&2
  echo "        GCC 12/13 kurup BUILD_CC=gcc-13 ile tekrar dene." >&2
  exit 1
fi

echo ">> J7 portu kopyalaniyor"
mkdir -p Platform/Samsung Silicon/Samsung
rm -rf Platform/Samsung/exynos7580 Silicon/Samsung/Exynos7580Pkg
cp -a "$P/Platform/Samsung/exynos7580" Platform/Samsung/
cp -a "$P/Silicon/Samsung/Exynos7580Pkg" Silicon/Samsung/
cp -f "$P/Silicon/Samsung/ExynosPkg/ExynosCommonDsc.j7.inc" Silicon/Samsung/ExynosPkg/
cp -f "$P/build_j7.sh" ./build_j7.sh
chmod +x ./build_j7.sh
# cihaz/SoC yapilandirmalari build.sh tarafindan configs/ altinda aranir
mkdir -p configs/devices
cp -f "$P/configs/devices/j7.conf" configs/devices/
cp -f "$P/configs/exynos7580.conf" configs/

# exynos7580.dsc zaten ExynosCommonDsc.j7.inc'i include ediyor; yine de dogrulayalim.
grep -q 'ExynosCommonDsc.j7.inc' Platform/Samsung/exynos7580/exynos7580.dsc || {
  echo "HATA: exynos7580.dsc beklenen include'u icermiyor" >&2; exit 1; }

# Binaries/ icindeki ikili dosyalar repoda; yoksa kullanicinin uretmesi gerekir.
for f in grubaa64.efi linux-Image j7elte.dtb startup.nsh; do
  [ -s "Platform/Samsung/exynos7580/Binaries/$f" ] || echo "UYARI: Binaries/$f eksik (./build-all.sh uretir)" >&2
done

echo "TAMAM: $EDK2_DIR hazir. Derleme: cd \"$EDK2_DIR\" && ./build_j7.sh"
