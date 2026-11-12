#!/usr/bin/env python3
"""Linux'un 8x16 VGA fontunu (lib/fonts/font_8x16.c) j7fbcon icin C dizisine cevirir.

Kullanim:
  # font kaynagi verilmezse once $LINUX_SRC, sonra build/work/linux-*/ aranir
  python3 linux/gen_font8x16.py [lib/fonts/font_8x16.c] > font8x16.h
"""
import glob, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)


def find_font():
    if len(sys.argv) > 1:
        return sys.argv[1]
    if os.environ.get('LINUX_SRC'):
        return os.path.join(os.environ['LINUX_SRC'], 'lib/fonts/font_8x16.c')
    hits = sorted(glob.glob(os.path.join(REPO, 'build/work/linux-*/lib/fonts/font_8x16.c')))
    return hits[0] if hits else None


path = find_font()
if not path or not os.path.isfile(path):
    sys.exit('HATA: font_8x16.c bulunamadi. Kernel kaynagini ver: python3 gen_font8x16.py <yol>/lib/fonts/font_8x16.c')

s = open(path).read()
i = s.index('fontdata_8x16')
body = s[i:]
body = re.sub(r'/\*.*?\*/', '', body, flags=re.S)
body = body[body.index('{'):]
# baslik struct'ini atla: "{ 0, 0, FONTDATAMAX, 0 }"
j = body.index('FONTDATAMAX')
body = body[body.index('}', j) + 1:]
vals = [int(x, 16) for x in re.findall(r'0x[0-9a-fA-F]{1,2}', body)]
assert len(vals) >= 4096, 'beklenen font verisi yok (%d deger)' % len(vals)
vals = vals[:4096]
out = '/* 8x16 VGA font, data from Linux lib/fonts/font_8x16.c (GPL-2.0) */\nstatic const unsigned char font8x16[4096] = {\n'
for k in range(0, 4096, 16):
    out += '  ' + ','.join('0x%02x' % v for v in vals[k:k+16]) + ',\n'
out += '};\n'
sys.stdout.write(out)
