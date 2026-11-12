#!/bin/bash
# Derlenen ikili dosyalari EDK2 agacinin FDF'nin bekledigi Binaries/ dizinine kopyalar.
#
# Kullanim:  ./scripts/install-binaries.sh [edk2-agaci]
#   varsayilan agac: $EDK2_DIR, yoksa build/work/edk2-exynos
#   kaynaklar:       build/grub, build/linux, recipe/nsh
#
# Bu adim atlanirsa FDF'deki SECTION PE32/RAW satirlari bulunamaz ve EDK2 derlemesi
# "file not found" ile durur; build_j7.sh bunu onceden kontrol eder.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"
EDK2_DIR="${1:-${EDK2_DIR:-$REPO/build/work/edk2-exynos}}"
BIN="$EDK2_DIR/Platform/Samsung/exynos7580/Binaries"

[ -d "$EDK2_DIR/Platform/Samsung/exynos7580" ] || {
  echo "HATA: $EDK2_DIR/Platform/Samsung/exynos7580 yok. Once ./scripts/setup-edk2.sh" >&2; exit 1; }
mkdir -p "$BIN"

# her ikili icin: hedef ad | olasi kaynaklar (ilk bulunan kazanir)
copy() {
  local dst="$1"; shift
  local src
  for src in "$@"; do
    if [ -s "$src" ]; then
      cp -f "$src" "$BIN/$dst"
      echo "  $dst  <-  ${src#$REPO/}"
      return 0
    fi
  done
  echo "  UYARI: $dst icin kaynak bulunamadi (denendi: $*)" >&2
  return 1
}

echo ">> Binaries/ guncelleniyor: $BIN"
MISS=0
copy grubaa64.efi  "$REPO/build/grub/grubaa64.efi" "$REPO/prebuilt/grubaa64-projecteku.efi" || MISS=1
copy linux-Image   "$REPO/build/linux/Image"       "$REPO/prebuilt/linux-6.12-j7-Image"       || MISS=1
copy j7elte.dtb    "$REPO/build/linux/j7elte.dtb"  "$REPO/linux/j7elte.dtb"                   || MISS=1
# startup.nsh: NSH_VARIANT=rootfs -> eku.root=auto ile eMMC rootfs arar; varsayilan "safe"
NSH="${NSH_VARIANT:-safe}"
copy startup.nsh   "$REPO/build/nsh/startup.nsh"   "$REPO/recipe/nsh/startup-$NSH.nsh" \
                   "$EDK2_DIR/Platform/Samsung/exynos7580/Binaries/startup.nsh"                || MISS=1

if [ "$MISS" = 1 ]; then
  echo "UYARI: bazi ikili dosyalar eksik; EDK2 derlemesi bu dosyalar olmadan tamamlanmaz." >&2
fi
echo "TAMAM"
