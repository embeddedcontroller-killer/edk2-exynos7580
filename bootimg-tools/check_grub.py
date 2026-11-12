#!/usr/bin/env python3
"""Acilmis 'kernel' dosyasinda GRUB'in gomulu olup olmadigini boyut/doluluk ile kontrol eder.
Kullanim: python3 check_grub.py acik/kernel"""
import hashlib, sys
k = open(sys.argv[1], 'rb').read()
i = len(k) - 1
while i >= 0 and k[i] == 0xFF:
    i -= 1
used = i + 1
print("boyut: %d | son dolu ofset: 0x%x | sha256: %s" % (len(k), used, hashlib.sha256(k).hexdigest()[:16]))
print("-> GRUB VAR" if used > 0x100000 else "-> GRUB YOK gibi (eski imaj)")
