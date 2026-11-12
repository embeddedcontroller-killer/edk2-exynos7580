# Lisans notları

Bu depo bir **port çalışmasıdır**; içindeki dosyalar farklı lisanslara tabidir.

| Bileşen | Lisans | Not |
|---|---|---|
| `edk2-exynos-j7/`, `recipe/` | BSD-2-Clause-Patent (EDK2 geleneği) | Dosya başlıklarındaki telif satırları korunmuştur; `edk2-exynos` Renegade Project çalışmasına dayanır. |
| `grub/` (yama, `grub.cfg`, `build-grub.sh`) | GPL-3.0-or-later | GRUB 2.12 kaynağına uygulanır. |
| `linux/` (yama, `init.c`, DTS, yapılandırmalar) | GPL-2.0-only | Linux 6.12 kaynağına uygulanır; `init.c` GPL-2.0. |
| `tools/`, `bootimg-tools/` | GPL-3.0-or-later | mkbootimg türevi betikler. |
| `prebuilt/` | karışık | GRUB (GPLv3) ve Linux (GPLv2) ikilileri içerir; karşılık gelen kaynaklar bu depoda ve `grub/build-grub.sh`, `build-linux.sh` içindeki adreslerde. |

Dağıtırsan kaynak projelere kredi ver: `edk2-exynos` (Renegade Project), `edk2` (TianoCore),
GRUB, Linux.
