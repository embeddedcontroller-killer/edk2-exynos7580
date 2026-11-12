#!/bin/bash
# Temiz bir edk2-exynos clone'u uzerinde portu bastan uretir (arşiv/başvuru).
#
# DIKKAT: Günlük kullanımda bunu değil, depo kökündeki ./build-all.sh kullanın:
# portun hazır hali edk2-exynos-j7/ altında duruyor ve setup-edk2.sh onu kopyalıyor.
# Bu betik yalnızca portu sıfırdan yeniden üretmek isteyenler için.
#
#   EDK2_DIR=~/edk2-exynos ./recipe/apply_all.sh
set -euo pipefail
H="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$H/.." && pwd)"
export EDK2_DIR="${EDK2_DIR:-$REPO/build/work/edk2-exynos}"
[ -d "$EDK2_DIR/.git" ] || { echo "HATA: $EDK2_DIR bir edk2-exynos clone'u değil (EDK2_DIR ayarla)" >&2; exit 1; }
export GRUB_EFI="${GRUB_EFI:-$REPO/prebuilt/grubaa64-projecteku.efi}"

bash "$H/01_mkport.sh"
python3 "$H/02_port_edit.py"
python3 "$H/03_fdf_strip.py"
( cd "$EDK2_DIR/Silicon/Samsung/ExynosPkg" && python3 "$H/04_common_dsc.py" )
( cd "$EDK2_DIR" && sed -i 's#!include Silicon/Samsung/ExynosPkg/ExynosCommonDsc.inc#!include Silicon/Samsung/ExynosPkg/ExynosCommonDsc.j7.inc#' Platform/Samsung/exynos7580/exynos7580.dsc )
cp -f "$REPO/edk2-exynos-j7/build_j7.sh" "$EDK2_DIR/build_j7.sh" && chmod +x "$EDK2_DIR/build_j7.sh"
python3 "$H/05_port_edit2_fb_decon.py"
mkdir -p "$EDK2_DIR/Platform/Samsung/exynos7580/Binaries"
python3 "$H/06_grub_fdf.py"
python3 "$H/07_startup_nsh_fdf.py"
bash "$H/08b_make_startup_nsh.sh"
python3 "$H/08_linux_dtb_fdf.py"
( cd "$EDK2_DIR" && sed -i 's|PcdFirmwareVendor|L"Renegade Project"|PcdFirmwareVendor|L"ProjectEku"|' Silicon/Samsung/ExynosPkg/ExynosCommonDsc.j7.inc \
  && sed -i 's|Renegade Project edk2-exynos (AArch64)|ProjectEku edk2-exynos (AArch64)|' Silicon/Samsung/Exynos7580Pkg/Library/PlatformPrePiLib/PlatformUtils.c )
bash "$REPO/scripts/install-binaries.sh" "$EDK2_DIR"
echo "tamam: $EDK2_DIR"
