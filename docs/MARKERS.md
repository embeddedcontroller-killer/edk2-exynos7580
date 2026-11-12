# J7 Linux acilis isaretleri (sol ustte 40x80 px renkli bloklar, soldan saga)

Kernel ekrana yazamasa da, ulastigi asamayi sol ustteki bloklarla gosterir. EN SAGDAKI blok = son ulasilan asama.

| Blok | Renk | Asama |
|---|---|---|
| 0 | kirmizi | primary_entry (kernel ilk talimat, MMU kapali) |
| 1 | sari | page-table (idmap) hazir |
| 2 | yesil | EL ayari (init_kernel_el) bitti |
| 3 | camgobegi | MMU acilmadan hemen once |
| 4 | mavi | setup_arch: early_ioremap hazir |
| 5 | mor/pembe | device tree okundu |
| 6 | beyaz | komut satiri (parse_early_param) |
| 7 | turuncu | paging_init bitti |
| 8 | koyu kirmizi | setup_arch donmus |
| 9 | koyu yesil | timekeeping_init bitti |
| 10 | lacivert | time_init (timer) bitti |
| 11 | zeytin | kesmeler acildi (GIC calisti) |
| 12 | petrol | rest_init oncesi |
| 13 | mor | kernel_init basladi |
| 14 | acik gri | initramfs / init'e gecis oncesi |

Hic blok yoksa: kernel hic baslamiyor (EFI stub ile primary_entry arasi).
Ekran bir noktada donuyorsa: ilk eksik blokun onceki asamasi son calisan yerdir.
