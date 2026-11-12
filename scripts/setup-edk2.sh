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
echo ">> alt modul: edk2"
git submodule update --init --recursive

echo ">> BaseTools/Source/C derleniyor"
make -C BaseTools/Source/C -j"$(nproc)" >/dev/null

echo ">> J7 portu kopyalaniyor"
mkdir -p Platform/Samsung Silicon/Samsung
rm -rf Platform/Samsung/exynos7580 Silicon/Samsung/Exynos7580Pkg
cp -a "$P/Platform/Samsung/exynos7580" Platform/Samsung/
cp -a "$P/Silicon/Samsung/Exynos7580Pkg" Silicon/Samsung/
cp -f "$P/Silicon/Samsung/ExynosPkg/ExynosCommonDsc.j7.inc" Silicon/Samsung/ExynosPkg/
cp -f "$P/build_j7.sh" ./build_j7.sh
chmod +x ./build_j7.sh
cp -a "$P/configs" ./

# exynos7580.dsc zaten ExynosCommonDsc.j7.inc'i include ediyor; yine de dogrulayalim.
grep -q 'ExynosCommonDsc.j7.inc' Platform/Samsung/exynos7580/exynos7580.dsc || {
  echo "HATA: exynos7580.dsc beklenen include'u icermiyor" >&2; exit 1; }

# Binaries/ icindeki ikili dosyalar repoda; yoksa kullanicinin uretmesi gerekir.
for f in grubaa64.efi linux-Image j7elte.dtb startup.nsh; do
  [ -s "Platform/Samsung/exynos7580/Binaries/$f" ] || echo "UYARI: Binaries/$f eksik (./build-all.sh uretir)" >&2
done

echo "TAMAM: $EDK2_DIR hazir. Derleme: cd \"$EDK2_DIR\" && ./build_j7.sh"
