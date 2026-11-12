#!/usr/bin/env python3
"""BootShim+UEFI 'kernel' dosyasindan Odin'e hazir boot imaji uretir.
Sohbetteki her imajla ayni parametreler: header v0, pagesize 2048, base 0x10000000,
SEANDROIDENFORCE altbilgisi, tar icinde 'boot.img' (Odin AP slotu).

Kullanim:
  python3 tools/package_boot.py <mkbootimg.py> <uefi-kernel> [cikti-adi]
  # mkbootimg.py yoksa depodaki bootimg-tools/pack_bootimg.py ile ayni is yapilir:
  python3 bootimg-tools/pack_bootimg.py --kernel <uefi-kernel> --ramdisk /dev/null \
          --pagesize 2048 --kernel-addr 0x10008000 --ramdisk-addr 0x11000000 \
          --tags-addr 0x10000100 --footer -o boot-j7-uefi.img
Cikti: <cikti-adi>.img ve <cikti-adi>.tar (varsayilan boot-j7-uefi)
"""
import sys, subprocess, tarfile, tempfile, os, hashlib
mkboot, kernel, out = sys.argv[1:4]
ram = tempfile.NamedTemporaryFile(delete=False); ram.write(b'\n'); ram.close()
tmp = out + '.tmp'
subprocess.check_call([sys.executable, mkboot, '--kernel', kernel, '--ramdisk', ram.name,
    '--kernel_offset', '0x00008000', '--ramdisk_offset', '0x01000000',
    '--second_offset', '0xf0000000', '--tags_offset', '0x00000100',
    '--os_version', '11.0.0', '--os_patch_level', '2023-02', '--header_version', '0', '-o', tmp])
d = open(tmp, 'rb').read(); os.remove(tmp); os.remove(ram.name)
F = b'SEANDROIDENFORCE'
if not d.endswith(F): d += F
open(out + '.img', 'wb').write(d)
with tempfile.TemporaryDirectory() as t:
    open(t + '/boot.img', 'wb').write(d)
    with tarfile.open(out + '.tar', 'w') as tf: tf.add(t + '/boot.img', arcname='boot.img')
print(out, len(d), hashlib.sha256(d).hexdigest()[:12])
