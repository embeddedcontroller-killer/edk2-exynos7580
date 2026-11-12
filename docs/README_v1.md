# Galaxy J7 (2015) icin EDK2 (UEFI) portu - durum

Referans: sonic011gamer/edk2-exynos, cihaz **exynos7420 / Galaxy S6** (ayni GIC-400 yerlesimi, 8x A5x, 2 cluster).
Derleme: GCC 13.3 aarch64, edk2 `e7aac7f`, edk2-platforms `9822126`, 198 modul, hatasiz. **Cihazda HIC test edilmedi.**

## Ciktilar
| Dosya | Ne |
|---|---|
| `EXYNOS7580_UEFI.fd` | UEFI firmware, 0x700000 bayt (= FD_SIZE) |
| `uefi-j7-kernel` | BootShim + UEFI.fd (BootShim, payload'u 0x50000000'a kopyalayip atlar) |
| `boot-j7-uefi.img/.tar` | mkbootimg, upstream S6 tarifiyle birebir. **DT bolumu YOK** (mkbootimg header v0'da --dtb'yi yazmiyor) |
| `boot-j7-uefi-with-dt.img/.tar` | Ayni + `j7_dt.img` (Samsung DTBH) eklendi, `dt_size` header ofset 40'a yazildi |
| `j7_dt.img` | DTBH: 3 revizyon (hw_rev 0-3, 4-5, 6-255), chip 7580, platform 0x50a6, subtype 0x217584da |
| `src/` | port kaynaklari (`j7-edk2-port.tar.gz`), `port_edit.py` |

boot.img parametreleri: base 0x10000000 (J7 BoardConfig ile ayni), pagesize 2048, kernel_off 0x8000, ramdisk_off 0x1000000,
second_off 0xf0000000, tags_off 0x100 (S6 tarifi). **Cihazin kendi boot.img header'iyla karsilastirilmadi.**

## Kaynagi DOGRULANMIS degerler (J7 DTS + kernel kaynagi)
| | Deger | Kaynak |
|---|---|---|
| RAM | 0x40000000, UEFI'ye 0x50000000 (-> 0x90000000) | DTS memory + memreserve 0x90000000.. / 0x9F700000.. |
| GIC | dist 0x10C01000, GICC 0x10C02000 | DTS interrupt-controller reg |
| Timer | 26 MHz, PPI 13/14/11/10 | DTS timer |
| PMU / reset | 0x10480000, SWRESET 0x400, PS_HOLD 0x330C | exynos7580.dtsi, pmu_cal_sys_exynos7580.h |
| Tuslar | pinctrl 0x139B0000, bank gpa2 (ofs 0x40): vol-up 0, vol-down 1, power 7 | DTS gpio-keys, pinctrl-exynos.c |
| Ekran | 720x1280 | DTS decon |
| CPU | 8 core / 2 cluster | DTS |

## S6'dan DEVRALINIP DOGRULANMAYANLAR (risk)
- `BROKEN_CNTFRQ_EL0=1` + sanal timer (`USE_PHYSICAL_TIMER=FALSE`): S6 ile ayni aile, J7'de dogrulanmadi.
- PlatformPeiLib "Info Blk" 0x5FFFF000, UEFI heap 0x40D00000 (+112 MB), stack 0x40C00000, CPU vektorleri 0x40C40000.
- Tus polaritesi (aktif-dusuk varsayimi).

## BILEREK PORTLANMAYANLAR / DEGISTIRILENLER
- S6'nin `PlatformInitialize()` fonksiyonu **kor** bir yazmac yazimi (`0x139306b0 = 0x2058`) ve 0xEC000000'dan 20 MB silme yapiyordu. J7'de **kaldirildi**.
- S6 DSC'sinde `PcdGicInterruptInterfaceBase` = GICH adresiydi; J7'de DTS'e gore GICC (0x10C02000) kullanildi.
- `PcdCPUCoresStackBase` 0x9FF90000 J7'de memreserve'in icinde kalirdi; 0x4FF00000'a tasindi.
- Bellek haritasinda S6'daki "HLOS 0 Split 2" UEFI FD ile cakisiyordu; J7'de cakismasiz yazildi.
- SimpleInit GUI, KernelFdtDxe, LinuxSimpleMassStorage cikarildi (XNU icin gereksiz). FreeType gitlab yerine GitHub yansisindan alindi.

## EKSIK / ENGELLEYICI
1. **Framebuffer adresi: `PcdMipiFrameBufferAddress = 0x0` (placeholder).** Ne DTS'te ne kernel config'inde var (`CONFIG_DECON_USE_BOOTLOADER_FB` kapali).
   Bunsuz UEFI ekrana yazamaz. Cihazdan alinmali: DECON (0x14830000) window0 buffer start yazmaci ya da bootloader'in cmdline'i.
2. Cihazin stok boot.img header'i (base/offset/pagesize/dt) ile karsilastirma.
3. Samsung korumalari: bazi cihazlar boot.img sonunda `SEANDROIDENFORCE` ister (kilitli cihazlarda Odin "SECURE CHECK FAIL" verir).
4. UEFI'den XNU'ya gecis (HackiOS loader) ve J7 icin GICv2 XNU surucusu henuz yok.

## Flash oncesi
Stok boot.img yedegi ve stok firmware hazir olmadan hicbir sey yazma. Boot bolumu bootloader degildir; boot-loop olursa Download Mode + Odin ile stok boot geri yuklenebilir.
