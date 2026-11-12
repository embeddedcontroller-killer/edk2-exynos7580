#!/bin/bash
# UEFI Shell icin startup.nsh uretir (telefonda klavye yok).
# Kullanim: EDK2_DIR=/yol/edk2-exynos bash 08b_make_startup_nsh.sh
set -e
R="${EDK2_DIR:-$(pwd)}"
B="$R/Platform/Samsung/exynos7580/Binaries"
mkdir -p "$B"
printf '%s\r\n' '@echo -off' 'echo ===== J7: Linux 6.12 basliyor (8 sn) =====' 'stall 8000000' 'if exist FS0:\linux.efi then' '  FS0:\linux.efi' 'endif' 'if exist FS1:\linux.efi then' '  FS1:\linux.efi' 'endif' 'echo linux.efi calismadi, Shell durumda' > $B/startup.nsh
