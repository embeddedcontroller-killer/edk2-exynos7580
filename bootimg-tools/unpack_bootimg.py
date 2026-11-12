#!/usr/bin/env python3
"""
unpack_bootimg.py - Android/Samsung boot.img (baslik surumu 0) acici.

Desteklenen: 'ANDROID!' sihirli degerli, 1632 baytlik klasik baslik.
  * Samsung/QC tarzi dt_size (baslik ofseti 40) -> dt.img (orn. Samsung DTBH)
  * Sonda 'SEANDROIDENFORCE' ayagi
AOSP baslik surum 1-4 (header_version) DESTEKLENMEZ, aracin kendi mkbootimg'ini kullan.

Kullanim:
  python3 unpack_bootimg.py boot.img [-o cikti_dizini]

Cikti dizini: kernel, ramdisk.img, second (varsa), dt.img (varsa), tail.bin (varsa), header.json
header.json, pack_bootimg.py tarafindan okunur.
"""
import argparse
import hashlib
import json
import os
import struct
import sys

MAGIC = b"ANDROID!"
FOOTER = b"SEANDROIDENFORCE"
# magic, kernel_size, kernel_addr, ramdisk_size, ramdisk_addr, second_size, second_addr,
# tags_addr, page_size, dt_size (AOSP'ta header_version), os_version, name, cmdline, id, extra_cmdline
HDR = struct.Struct("<8s10I16s512s32s1024s")


def pages(n, ps):
    return (n + ps - 1) // ps * ps


def cstr(b):
    return b.split(b"\0", 1)[0].decode("utf-8", "replace")


def decode_os_version(v):
    if v == 0:
        return None, None
    ver = v >> 11
    patch = v & 0x7FF
    a, b, c = (ver >> 14) & 0x7F, (ver >> 7) & 0x7F, ver & 0x7F
    y, m = (patch >> 4) + 2000, patch & 0xF
    return "%d.%d.%d" % (a, b, c), "%04d-%02d" % (y, m)


def die(msg):
    print("HATA: " + msg, file=sys.stderr)
    sys.exit(1)


def main():
    ap = argparse.ArgumentParser(description="boot.img acici (baslik surumu 0, Samsung uyumlu)")
    ap.add_argument("image", help="boot.img yolu")
    ap.add_argument("-o", "--out", default="unpacked", help="cikti dizini (varsayilan: unpacked)")
    a = ap.parse_args()

    data = open(a.image, "rb").read()
    if len(data) < HDR.size or data[:8] != MAGIC:
        die("'ANDROID!' sihirli degeri bulunamadi, bu bir boot.img degil")

    (_, ksz, kaddr, rsz, raddr, ssz, saddr, taddr, ps, dtsz, osv,
     name, cmdline, bid, extra) = HDR.unpack_from(data, 0)

    if dtsz in (1, 2, 3, 4):
        die("AOSP baslik surumu %d (v1-v4) bu betikle desteklenmiyor" % dtsz)
    if ps < 512 or ps & (ps - 1):
        die("gecersiz page_size: %d" % ps)

    has_footer = data.endswith(FOOTER)
    limit = len(data) - (len(FOOTER) if has_footer else 0)

    os.makedirs(a.out, exist_ok=True)
    off = ps
    parts = []
    for fname, size in (("kernel", ksz), ("ramdisk.img", rsz), ("second", ssz), ("dt.img", dtsz)):
        if size:
            if off + size > limit:
                die("%s dosyanin disina tasiyor (offset 0x%x, boyut %d)" % (fname, off, size))
            blob = data[off:off + size]
            with open(os.path.join(a.out, fname), "wb") as f:
                f.write(blob)
            parts.append((fname, off, size))
        off += pages(size, ps)

    # hesaplanan sonun ardindaki ekstra veri (sifirlar degilse tail.bin olarak sakla)
    tail = data[min(off, limit):limit]
    tail_saved = False
    if tail.strip(b"\0"):
        with open(os.path.join(a.out, "tail.bin"), "wb") as f:
            f.write(tail)
        tail_saved = True

    os_version, os_patch = decode_os_version(osv)
    cmd = cstr(cmdline) + cstr(extra)
    info = {
        "page_size": ps,
        "kernel_addr": kaddr,
        "ramdisk_addr": raddr,
        "second_addr": saddr,
        "tags_addr": taddr,
        "os_version": os_version,
        "os_patch_level": os_patch,
        "name": cstr(name),
        "cmdline": cmd,
        "id": bid.hex(),
        "seandroid_footer": has_footer,
        "sizes": {"kernel": ksz, "ramdisk": rsz, "second": ssz, "dt": dtsz},
        "tail_bin": tail_saved,
    }
    with open(os.path.join(a.out, "header.json"), "w") as f:
        json.dump(info, f, indent=2)
        f.write("\n")

    print("Dosya        : %s (%d bayt)" % (a.image, len(data)))
    print("page_size    : %d" % ps)
    print("kernel       : %d bayt, adres 0x%08x" % (ksz, kaddr))
    print("ramdisk      : %d bayt, adres 0x%08x" % (rsz, raddr))
    print("second       : %d bayt, adres 0x%08x" % (ssz, saddr))
    print("dt           : %d bayt (baslik ofseti 40)" % dtsz)
    print("tags adresi  : 0x%08x" % taddr)
    print("os_version   : %s   patch: %s" % (os_version, os_patch))
    print("name/cmdline : %r / %r" % (cstr(name), cmd))
    print("SEANDROIDENFORCE ayagi: %s" % ("VAR" if has_footer else "yok"))
    if tail_saved:
        print("UYARI: sayfa sonundan sonra sifir olmayan %d bayt var -> tail.bin" % len(tail))
    calc = hashlib.sha1()
    for fname, _, size in parts:
        calc.update(open(os.path.join(a.out, fname), "rb").read())
        calc.update(struct.pack("<I", size))
    print("Cikti dizini : %s" % a.out)


if __name__ == "__main__":
    main()
