#!/bin/bash
# ESKI BETIK (arsiv). Yerine depo kokundeki ../grub/build-grub.sh kullaniliyor:
#   ./build-grub.sh             (depo kokunde) -> build/grub/grubaa64.efi
# Bu dosya yalnizca eski sabit yollu (/home/claude) surumun kaydi olarak duruyor.
#
# GRUB 2.12 (arm64-efi) + J7 CNTFRQ yamasi + gomulu menu (memdisk).
# Gereken paketler: gcc-aarch64-linux-gnu build-essential bison flex gawk (mawk YETMEZ: asorti)
echo "Bu betik arsivlendi. Kullan: $(cd "$(dirname "$0")/.." && pwd)/build-grub.sh" >&2
exit 1
