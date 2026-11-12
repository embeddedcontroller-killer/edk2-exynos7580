#!/bin/bash
# Galaxy J7 (2015) EDK2 firmware'ini sifirdan, tek komutla derler.
#
#   ./build-all.sh                  # her sey: EDK2 agaci + GRUB + Linux + Binaries + firmware
#   ./build-all.sh --firmware-only  # Binaries/ hazirsa yalnizca UEFI firmware
#   ./build-all.sh --skip-grub      # GRUB'u yeniden derleme (prebuilt/ kullanilir)
#   ./build-all.sh --skip-linux     # Linux'u yeniden derleme (prebuilt/ kullanilir)
#   ./build-all.sh --clean          # build/ ve Build/ dizinlerini silerek basla
#   TARGET=RELEASE ./build-all.sh   # RELEASE derlemesi (varsayilan DEBUG)
#
# Cikti: <edk2-agaci>/Build/j7/${TARGET}_GCC5/FV/EXYNOS7580_UEFI.fd
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

TARGET="${TARGET:-DEBUG}"
FW_ONLY=0; SKIP_GRUB=0; SKIP_LINUX=0; CLEAN=0
for a in "$@"; do
  case "$a" in
    --firmware-only) FW_ONLY=1 ;;
    --skip-grub)     SKIP_GRUB=1 ;;
    --skip-linux)    SKIP_LINUX=1 ;;
    --clean)         CLEAN=1 ;;
    -h|--help)       sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "Bilinmeyen secenek: $a" >&2; exit 2 ;;
  esac
done

export EDK2_DIR="${EDK2_DIR:-$HERE/build/work/edk2-exynos}"
export WORK="${WORK:-$HERE/build/work}"

if [ "$CLEAN" = 1 ]; then
  echo ">> build/ ve EDK2 Build/ siliniyor"
  rm -rf "$HERE/build" "$EDK2_DIR/Build"
fi

step() { echo; echo "===== $* ====="; }

step "1/5 EDK2 agaci (edk2-exynos + J7 portu)"
bash scripts/setup-edk2.sh

if [ "$FW_ONLY" = 0 ]; then
  if [ "$SKIP_GRUB" = 0 ]; then
    step "2/5 GRUB 2.12 + J7 yamasi"
    bash grub/build-grub.sh "$HERE/build/grub"
  else
    step "2/5 GRUB atlandi"
  fi
  if [ "$SKIP_LINUX" = 0 ]; then
    step "3/5 Linux 6.12 + initramfs + DTB"
    bash build-linux.sh "$HERE/build/linux"
  else
    step "3/5 Linux atlandi"
  fi
else
  step "2-3/5 GRUB ve Linux atlandi (--firmware-only)"
fi

step "4/5 Binaries/ guncelleniyor"
bash scripts/install-binaries.sh "$EDK2_DIR"

step "5/5 EDK2 firmware derlemesi ($TARGET)"
( cd "$EDK2_DIR" && TARGET="$TARGET" ./build_j7.sh "$TARGET" )

FD="$EDK2_DIR/Build/j7/${TARGET}_GCC5/FV/EXYNOS7580_UEFI.fd"
echo
echo "===== BITTI ====="
echo "firmware : $FD"
echo "sha256   : $(sha256sum "$FD" | cut -d' ' -f1)"
echo "Odin'e vermek icin paketleme: python3 tools/package_boot.py <kernel> boot-j7"
