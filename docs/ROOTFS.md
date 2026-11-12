# Rootfs — hangisi, nereye, nasıl (v9.3)

## Kısa cevap
**Alpine Linux (arm64 minirootfs).** Hazır imaj `prebuilt/rootfs-alpine-j7.img.gz` (64 MB ext4, etiket `ROOTFS`, Alpine 3.20.10, BusyBox init).
**Debian şimdilik olmaz.** Kernel bilerek minimal derlendi; Debian'ın systemd'si ve glibc'si için gereken şu özellikler kapalı:
`NET, CGROUPS, EPOLL, SIGNALFD, TIMERFD, INOTIFY, FHANDLE, SECCOMP, SHMEM (tmpfs), FUTEX`.
Alpine'in BusyBox init'i ve musl libc'si bunlar olmadan çalışıyor (QEMU'da aynı yapılandırmayla doğrulandı). Debian istersen önce "dağıtım çekirdeği" yapılandırması ile kernel'i yeniden derlemek gerekir (imaj büyür).

## Doğrulananlar (QEMU, aynı kernel yapılandırması + sanal disk)
Hazır Alpine imajı GPT'de `CACHE` adlı bölüme konup `init` ile açıldı: eMMC modülleri yüklendi, `USERDATA` (init yok) atlandı, `CACHE` bulundu, ro→rw, `chroot`, BusyBox init, ekrana `=== ProjectEku Alpine rootfs OK ===`, `uname`, `df` ve shell istemi (`tools/qemu-rootfs-test/`).
**Cihazda denenmedi:** eMMC sürücüsü (mainline `dw_mmc` + sabit saatler) J7'de hiç çalışmadı. O yüzden sonuç ekranda görünecek, hata varsa `modul HATA ...` / `ext4 mount HATA ...` satırları olarak.

## Hangi bölüme yazmalı
`init` rootfs'i **ext4 etiketine** göre bulur: etiketi **`ROOTFS`** olan ext4 bölüm, bölümün adı ne olursa olsun (hazır imajın etiketi zaten ROOTFS). Etiketle bulunamazsa GPT bölüm adlarına bakar: **ROOTFS, LINUX, USERDATA, SYSTEM, CACHE, HIDDEN**. Yalnızca içinde init olan ext4 bölüm kabul edilir (Android'in `/system`, `/data`, `/cache` bölümleri rootfs sanılmaz). En çok 40 sn aday arar.
En az yıkıcı seçenek: **CACHE** (Android'e dönmek için cache'i silmek yeter). Bölüm boyutu imajdan büyük olmalı (küçükse `tools/make_alpine_rootfs.sh 32` ile 32 MB'lık imaj üret; Alpine ~9 MB kullanır).

## "aday bolum bulunamadi" ya da başka bir hata görürsen
İmaj ext4'tür (`mke2fs -t ext4`, `e2fsck` temiz). Bu mesaj dosya sisteminden değil, **bölüm bulunamamasından** gelir: kernel bir blok aygıtı görmüş ama etiketi ROOTFS olan ya da adı listedeki bir bölüm yok. Olası nedenler: imaj yazılmadı/yanlış yere yazıldı, bölüm tablosu kernel'de okunamadı ya da eMMC okuma hatası.
v9.2'de bu durumda ekrana **TANI ekranı** basılır (45 sn kalır): tüm blok aygıtları (ad, MB, GPT adı, ext4 etiketi) ve kernel'in eMMC/blok mesajlarının son satırları. **O ekranın fotoğrafını at**; asıl nedeni oradan okuruz.

## eMMC durumu (cihaz fotoğrafından)
`mmcblk0` 15028 MB olarak göründü ama sektör 0..9 okumaları `I/O error`. Kart ilk tanımada (400 kHz, 1 bit) cevap verip EXT_CSD'yi okudu, sonra hız/veri yolu artınca okumalar bozuldu. Downstream DTS'e göre CIU saati moda göre CMU'dan ayarlanıyor (`ciu_clkin = <25 50 50 100 200 100 200 400 400 200>` MHz) ve bu kartın gerçek hızı sabit 100 MHz varsayımıma uymuyor. v9.3 hızı 400 kHz'e kilitler; TANI ekranındaki `MMC`, `TOP`, `MIF` kayıt satırları gerçek saati hesaplamaya yarar.

## Yazma yöntemleri (cihazda doğrulanmadı)
**TWRP / özel recovery (önerilen, ham imajı olduğu gibi yazar):**
```
gunzip -k rootfs-alpine-j7.img.gz
adb push rootfs-alpine-j7.img /sdcard/
adb shell blockdev --getsize64 /dev/block/platform/13540000.dwmmc0/by-name/CACHE     # >= 67108864 olmalı
adb shell dd if=/sdcard/rootfs-alpine-j7.img of=/dev/block/platform/13540000.dwmmc0/by-name/CACHE bs=4M
adb shell sync
```
(`by-name` yolu downstream DTS'ten: `13540000.dwmmc0`.) Önce `boot` yedeği ve EFS yedeği al.
**Odin:** `cache.img` adıyla tar'layıp AP'ye vermek mümkün olabilir ama Odin'in ham ext4'ü kabul edip etmediği doğrulanmadı; dd yolunu tercih et.

## Sırayla ne yapmalı
1. `boot-j7-v9.3-rootfs.tar`'ı Odin AP'ye ver. (Rootfs yoksa TANI ekranı çıkar, 45 sn sonra GUI açılır; zararsız.)
2. Recovery'den imajı `CACHE`'e yaz.
3. Cihazı yeniden başlat: GRUB menüsü → 5 sn → Linux. Ekranda durum satırları, sonra Alpine'in "rootfs OK" çıktısı ve shell istemi.
4. Takılırsa son ekranın fotoğrafını at (hangi satırda durduğu önemli).
Klavye ve dokunmatik olmadığı için shell'e komut yazamazsın, bu adım yalnızca rootfs'in açıldığını doğrular.

## init mantığı (eku.root=)
`eku.root=auto` | `LABEL=ETIKET` | `PARTNAME=ADI` | `/dev/mmcblk0pN`; `eku.init=/yol`. Init, rootfs'teki `/sbin/init` gibi **mutlak symlink**'leri de tanır (v9'da bu hata vardı, Alpine/Debian rootfs'ini atlıyordu; v9.1'de düzeltildi).

## Dokunmatik — durum (yapılmadı)
Mainline Linux'ta bu SoC'nin dokunmatik zinciri yok: (1) Exynos 7580 saat/pinctrl sürücüsü, dokunmatiğin I2C'si `i2c@13860000` için saat kapısı; (2) PMIC S2MPU03'ten `tsp_avdd` (LDO33, 3.0 V), PMIC `hsi2c@104c0000` üzerinde; (3) Melfas MMS438 (I2C 0x48) için giriş sürücüsü. Cihazda adım adım denemeden yazılamaz.
