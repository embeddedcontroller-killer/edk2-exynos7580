#!/usr/bin/env python3
"""
pack_bootimg.py - Android/Samsung boot.img (baslik surumu 0) olusturucu.

unpack_bootimg.py'nin urettigi dizini (header.json + dosyalar) boot.img'ye cevirir.
Hicbir sey vermezsen header.json'daki degerler kullanilir; komut satiri secenekleri
bunlari ezer. Dizin olmadan, sadece dosyalarla da kullanilabilir.

Ornekler:
  python3 pack_bootimg.py -i unpacked -o yeni_boot.img
  python3 pack_bootimg.py -i unpacked --kernel benim_kernel.bin --footer -o boot.img
  python3 pack_bootimg.py --kernel k.bin --ramdisk r.img --dt dt.img \
      --pagesize 2048 --kernel-addr 0x10008000 --ramdisk-addr 0x11000000 \
      --tags-addr 0x10000100 --footer -o boot.img
"""
import argparse
import hashlib
import json
import os
import struct
import sys

MAGIC = b"ANDROID!"
FOOTER = b"SEANDROIDENFORCE"
HDR = struct.Struct("<8s10I16s512s32s1024s")


def pages_pad(n, ps):
    return b"\0" * (-n % ps)


def die(msg):
    print("HATA: " + msg, file=sys.stderr)
    sys.exit(1)


def num(s):
    return int(s, 0)


def encode_os_version(ver, patch):
    v = 0
    if ver:
        try:
            a, b, c = (int(x) for x in ver.split("."))
        except ValueError:
            die("os_version A.B.C biciminde olmali: %r" % ver)
        if not (a < 128 and b < 128 and c < 128):
            die("os_version bilesenleri 0-127 olmali")
        v = ((a << 14) | (b << 7) | c) << 11
    if patch:
        try:
            y, m = (int(x) for x in patch.split("-"))
        except ValueError:
            die("os_patch_level YYYY-MM biciminde olmali: %r" % patch)
        if not (2000 <= y < 2128 and 1 <= m <= 12):
            die("os_patch_level araligi gecersiz")
        v |= ((y - 2000) << 4) | m
    return v


def read_opt(path):
    if not path:
        return b""
    if not os.path.isfile(path):
        die("dosya yok: %s" % path)
    return open(path, "rb").read()


def main():
    ap = argparse.ArgumentParser(description="boot.img olusturucu (baslik surumu 0, Samsung uyumlu)")
    ap.add_argument("-i", "--indir", help="unpack_bootimg.py cikti dizini (header.json burada)")
    ap.add_argument("-o", "--output", default="boot.img", help="cikti imaj (varsayilan: boot.img)")
    ap.add_argument("--kernel"); ap.add_argument("--ramdisk"); ap.add_argument("--second"); ap.add_argument("--dt")
    ap.add_argument("--pagesize", type=num)
    ap.add_argument("--kernel-addr", type=num); ap.add_argument("--ramdisk-addr", type=num)
    ap.add_argument("--second-addr", type=num); ap.add_argument("--tags-addr", type=num)
    ap.add_argument("--os-version"); ap.add_argument("--os-patch-level")
    ap.add_argument("--name"); ap.add_argument("--cmdline")
    ap.add_argument("--footer", dest="footer", action="store_true", default=None,
                    help="sona SEANDROIDENFORCE ekle")
    ap.add_argument("--no-footer", dest="footer", action="store_false", help="ayagi ekleme")
    ap.add_argument("--keep-id", action="store_true",
                    help="header.json'daki id'yi aynen yaz (varsayilan: yeniden hesapla)")
    a = ap.parse_args()

    h = {}
    if a.indir:
        hp = os.path.join(a.indir, "header.json")
        if not os.path.isfile(hp):
            die("%s bulunamadi" % hp)
        h = json.load(open(hp))

    def pick(cli, key, default):
        return cli if cli is not None else h.get(key, default)

    ps = pick(a.pagesize, "page_size", 2048)
    if ps < 512 or ps & (ps - 1):
        die("page_size 2'nin kuvveti ve >=512 olmali")
    kaddr = pick(a.kernel_addr, "kernel_addr", 0x10008000)
    raddr = pick(a.ramdisk_addr, "ramdisk_addr", 0x11000000)
    saddr = pick(a.second_addr, "second_addr", 0x10F00000)
    taddr = pick(a.tags_addr, "tags_addr", 0x10000100)
    osver = pick(a.os_version, "os_version", None)
    ospl = pick(a.os_patch_level, "os_patch_level", None)
    name = pick(a.name, "name", "")
    cmd = pick(a.cmdline, "cmdline", "")
    footer = a.footer if a.footer is not None else bool(h.get("seandroid_footer", False))

    def src(cli, default_name):
        if cli:
            return cli
        if a.indir:
            p = os.path.join(a.indir, default_name)
            return p if os.path.isfile(p) else None
        return None

    kernel = read_opt(src(a.kernel, "kernel"))
    ramdisk = read_opt(src(a.ramdisk, "ramdisk.img"))
    second = read_opt(src(a.second, "second"))
    dt = read_opt(src(a.dt, "dt.img"))
    if not kernel:
        die("kernel gerekli (--kernel ya da -i dizininde 'kernel')")
    if 0 < len(dt) <= 4:
        die("dt bolumu cok kucuk; 1-4 AOSP header_version olarak yorumlanir")

    cmdb = cmd.encode()
    if len(cmdb) > 1536:
        die("cmdline 1536 bayttan uzun")
    namb = name.encode()
    if len(namb) > 16:
        die("name 16 bayttan uzun")

    sha = hashlib.sha1()
    for blob in (kernel, ramdisk, second):
        sha.update(blob)
        sha.update(struct.pack("<I", len(blob)))
    if dt:
        sha.update(dt)
        sha.update(struct.pack("<I", len(dt)))
    bid = bytes.fromhex(h["id"]) if (a.keep_id and h.get("id")) else sha.digest()
    bid = bid.ljust(32, b"\0")[:32]

    header = HDR.pack(MAGIC, len(kernel), kaddr, len(ramdisk), raddr, len(second), saddr,
                      taddr, ps, len(dt), encode_os_version(osver, ospl),
                      namb, cmdb[:512], bid, cmdb[512:])

    out = bytearray(header)
    out += pages_pad(len(out), ps)
    for blob in (kernel, ramdisk, second, dt):
        out += blob + pages_pad(len(blob), ps)

    if a.indir and os.path.isfile(os.path.join(a.indir, "tail.bin")) and h.get("tail_bin"):
        out += open(os.path.join(a.indir, "tail.bin"), "rb").read()
    if footer:
        out += FOOTER

    with open(a.output, "wb") as f:
        f.write(out)

    print("Yazildi: %s (%d bayt)" % (a.output, len(out)))
    print("  kernel %d | ramdisk %d | second %d | dt %d | page %d | footer %s"
          % (len(kernel), len(ramdisk), len(second), len(dt), ps, "VAR" if footer else "yok"))


if __name__ == "__main__":
    main()
