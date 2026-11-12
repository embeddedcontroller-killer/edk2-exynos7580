# Exynos 7580 (Galaxy J7 2015) — UEFI portu, paket deposu

Bu depo, `edk2-exynos` ağacına **sonradan uygulanan** J7 portunu ve cihaz için hazır
imajları barındırır. Buradaki her şey `embeddedcontroller-killer/edk2-exynos7580`
altında yaşar; `edk2-exynos` ve `edk2` kendi depolarından, kendi commit'lerinden gelir.

| Yol | Ne |
|---|---|
| `edk2-exynos-j7/Platform/Samsung/exynos7580/` | Platform paketi: `exynos7580.dsc`, `j7.dsc`, `exynos7580.fdf`, `Apriori.fdf.inc`, `Binaries/` |
| `edk2-exynos-j7/Silicon/Samsung/Exynos7580Pkg/` | SoC paketi: `exynos7580.dec`, bellek haritası, PrePi/Pei kütüphaneleri, keypad |
| `edk2-exynos-j7/Silicon/Samsung/ExynosPkg/ExynosCommonDsc.j7.inc` | Ortak DSC'den J7 için süzülmüş kopya |
| `edk2-exynos-j7/j7-edk2-final.patch` | Aynı dosyaların `edk2-exynos` ağacına karşı birleşik yaması (arşiv) |
| `edk2-exynos-j7/build_j7.sh` | Firmware derleme betiği (edk2-exynos köküne kopyalanır) |
| `linux/` | Linux 6.12 yaması, yapılandırmalar, `init.c`, DTS/DTB, ekran konsolu |
| `grub/` | GRUB 2.12 imajı: zamanlayıcı yaması + gömülü menü (`build-grub.sh`) |
| `scripts/` | `setup-edk2.sh` (ağaç + port kopyalama), `install-binaries.sh` (çıktıları `Binaries/`'e koyma) |
| `recipe/` | Portu sıfırdan üreten adımlar (arşiv/başvuru; `apply_all.sh` elle, günlük iş `scripts/setup-edk2.sh`) |
| `tools/`, `bootimg-tools/` | Boot imajı paketleme, rootfs üretme, QEMU testi |
| `prebuilt/` | v9.3 hazır imajlar (`SHA256SUMS` ile) |
| `docs/` | Rootfs, işaret blokları, sürüm notları |

## Hangi imajı yazacağım? (`prebuilt/`)
| Dosya | Ne |
|---|---|
| **`boot-j7-v9.3-safe.tar`** | Önce bunu dene. GRUB menüsü + Linux 6.12 + ekran konsolu. eMMC'ye **dokunmaz**. |
| `boot-j7-v9.3-rootfs.tar` | Aynısı + `eku.root=auto`: eMMC modüllerini yükleyip `ROOTFS` etiketli ext4 rootfs arar. **Deneysel.** |
| **`rootfs-alpine-j7.img.gz`** | Hazır rootfs: Alpine 3.20.10, 64 MB ext4, etiket ROOTFS (`docs/ROOTFS.md`). |
| `*.img`, `*.fd` | Tar'sız imajlar ve ham firmware. |

## Derleme

Üç yol var; hepsi aynı çıktıyı verir: `Build/j7/DEBUG_GCC5/FV/EXYNOS7580_UEFI.fd`.

### 1) Her şeyi tek komutla (önerilen)
```bash
git clone https://github.com/embeddedcontroller-killer/edk2-exynos7580.git
cd edk2-exynos7580
./build-all.sh                  # firmware + GRUB + Linux (kernel/DTB) + FDF'ye gömme
./build-all.sh --firmware-only  # yalnızca UEFI firmware (Binaries/ hazırsa)
./build-all.sh --clean          # Build/ ve build/ dizinlerini silerek
```
`build-all.sh` sırasıyla:
1. `scripts/setup-edk2.sh` — `edk2-exynos` (pinned commit) + `edk2` (alt modül) klonlar,
   BaseTools'u derler, `Platform/Samsung/exynos7580`, `Silicon/Samsung/Exynos7580Pkg` ve
   `ExynosCommonDsc.j7.inc` dosyalarını bu repodan kopyalar, `build_j7.sh`'yi ağacın köküne koyar.
2. `build-grub.sh` — GRUB 2.12 + `grub-2.12-j7-cntfrq.patch` + gömülü `grub.cfg` → `grubaa64.efi`.
3. `build-linux.sh` — Linux 6.12 + `j7-kernel-v9.patch` + `frag.config` → `Image` + `j7elte.dtb`.
4. `scripts/install-binaries.sh` — çıktıları `edk2-exynos-j7/Platform/Samsung/exynos7580/Binaries/`'e koyar.
5. `build_j7.sh` — EDK2 derlemesi.

### 2) Elle, EDK2 tarafı
```bash
./build.sh setup j7     # ya da scripts/setup-edk2.sh
cd edk2-exynos && ./build_j7.sh DEBUG
```

### 3) Bu depoda yalnızca firmware
`edk2-exynos-j7/` içindeki paket dosyaları hazır; `Binaries/` doluysa `./build-all.sh --firmware-only`.

### Gereken paketler (Ubuntu/Debian)
```
build-essential uuid-dev iasl nasm python3 python-is-python3 git curl xz-utils
gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu bison flex gawk bc
libssl-dev libelf-dev device-tree-compiler
```
`gawk` şart: GRUB'ın `make` hattı `mawk` ile çalışmaz (`asorti` yok).

### Ortam uyarısı (dürüst not)
- **BaseTools:** `edk2` BaseTools'un C tarafı (VfrCompile → Pccts/dlg) GCC 14+ ile derlenmiyor.
  GCC 11–13 kullan (CI'da `ubuntu-22.04`) ya da `BUILD_CC=gcc-13 ./scripts/setup-edk2.sh`.
- **SimpleInit:** `edk2-exynos`'un `GPLDrivers/Library/SimpleInit` alt modülündeki
  `libs/compatible/include/stdbool.h` (`typedef BOOLEAN bool;`) yeni GCC'lerde hata veriyor
  ("two or more data types in declaration specifiers"). Portun kendi dosyaları bu başlığı
  kullanmıyor; sorun yalnızca bu alt modülde. Çözüm seçenekleri: SimpleInit'in daha yeni bir
  commit'ine geçmek, ya da LVGL/SimpleInit'in bu başlığı kullanmadığı bir derleme bayrağı —
  ikisi de **cihazda denenmeden** değiştirilmemeli. Bu depodaki `prebuilt/` imajları hattın
  sorunsuz çalıştığı ortamda derlenmiş sürümlerdir; `./build-all.sh` bu ortamı (GCC 11–13)
  hedefler.

## Dizinler
`edk2-exynos-j7/` `linux/` `grub/` `scripts/` `recipe/` `tools/` `bootimg-tools/` `docs/` `prebuilt/`

## Sürüm geçmişi
v1–v7 (S6'dan J7 değerleri, framebuffer/DECON, GRUB, startup.nsh, Linux gömme, işaret blokları, ProjectEku vendor) ·
v8 GRUB menüsü, J7 GRUB zamanlayıcı yaması ·
**v9 ekran kernel konsolu, açık komut satırı, rootfs devri, eMMC modülleri, simplefb** ·
v9.2 rootfs'i etiketle bulma + TANI ekranı · v9.3 eMMC `max-frequency` 400 kHz, tanı kayıtları

## Test durumu — dürüst özet
- **QEMU'da doğrulandı:** rootfs devri (modüller, GPT adı/etiketle arama, `chroot`, PID 1),
  GRUB menüsü geri sayımı. Betikler `tools/qemu-rootfs-test/` (örnek çıktı dahil).
- **Cihazda denenmedi:** ekran konsolu, eMMC (`dw_mmc`), 26 MHz sayaç varsayımı, dokunmatik.
- Flaştan önce stok `boot` yedeği al.

## Kaynak notu
`edk2-exynos` Renegade Project'in çalışmasına dayanır; lisans/telif başlıkları kaynakta duruyor,
dağıtırsan kaynak projeye kredi ver. `prebuilt/` altındaki imajlar GPLv3 (GRUB) ve GPLv2 (Linux)
bileşenleri içerir; ilgili kaynaklar bu depoda ve `grub/build-grub.sh` / `build-linux.sh`
içindeki adreslerde.
