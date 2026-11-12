# Galaxy J7 (2015) EDK2 portu - v2

v1'e gore degisenler (kanit: github.com/ivoszbg/uniLoader `board/samsung/board-a3xelte.c`, Exynos 7580 = J7 ile ayni SoC):
- **Framebuffer 0x67000000**, 720x1280, ARGB8888 (u32 0xAARRGGBB = bellekte B,G,R,A = EFI BGRX). DECON_F 0x14830000 (J7 DTS ile ayni).
- **DECON tetik yazmaci geri eklendi:** `0x14830000 + 0x6b0 = 0x2058`. v1'de bunu "kor yazma" diye kaldirmistim, YANLISTI:
  S6 portundaki ayni yazma (`0x13930000 + 0x6b0`) ve uniLoader ayni degeri kullaniyor. S-Boot tetigi ayarsiz birakiyor, bu yuzden FB yenilenmiyor.
- Bellek haritasinda 0x67000000 +4 MB "Display Reserved" (Reserved, WT). FB'nin hemen arkasina (0x67384000) paylasimli konsol kelimeleri yazildigi icin 4 MB.
- ZeroMem ile FB temizleniyor.

## Dosyalar (hepsinin sonunda SEANDROIDENFORCE var; Odin icin .tar, AP slotu)
| Dosya | Amac |
|---|---|
| `boot-j7-fb-probe` | **Once bunu dene.** UEFI yok. DECON tetigini yazar, 0x67000000'a 4 yatay bant boyar: KIRMIZI, YESIL, MAVI, BEYAZ (ustten alta), sonra bosta bekler |
| `boot-j7-uefi` | BootShim + UEFI (S6 tarifi) |
| `boot-j7-uefi-padded` | Ayni, ama payload 2 MB ileride. Neden: U-Boot belgelerine gore Exynos 78xx S-Boot'u payload'in 0x1f7550-0x1f8280 araligini yamiyor; 7580'de dogrulanmadi, ama uniLoader'in TEXT_BASE'i (0x40205000) bunu destekliyor |

Onceki `reset-probe` (j7-edk2/with-footer) de gecerli: kendi kendine resetlerse kodumuz calisiyor demektir.

## fb-probe sonucu nasil okunur
- 4 renk bandi, dogru sirada -> FB adresi, DECON tetigi ve piksel formati DOGRU. UEFI imajlarini dene.
- Bantlar var ama renkler yer degismis -> kanal sirasi; UEFI'de format degisir.
- Hicbir sey degismiyor (splash kaliyor) -> adres ya da tetik yanlis, ya da kod calismiyor (reset-probe ile ayir).
- Cihaz kendi kendine resetliyor/donuyor -> haber ver, DECON saati kapali olabilir.

## Dogrulanmamis (J7'de)
0x67000000 (A3 2016'dan), 2 MB yama hipotezi, DT'siz image'in S-Boot tarafindan kabulu, UEFI icinde GOP/Seri.
Flash oncesi stok boot.img yedegi sart; geri donus: Download Mode + Odin ile stok boot.
