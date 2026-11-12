import os, shutil, sys
# Kullanim:  GRUB_EFI=/yol/grubaa64.efi EDK2_DIR=/yol/edk2-exynos python3 06_grub_fdf.py
# GRUB_EFI verilmezse build/grub/grubaa64.efi, o da yoksa prebuilt/grubaa64-projecteku.efi kullanilir.
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
R = os.environ.get('EDK2_DIR', os.getcwd()).rstrip('/')
cands = [os.environ.get('GRUB_EFI'),
         os.path.join(REPO, 'build/grub/grubaa64.efi'),
         os.path.join(REPO, 'prebuilt/grubaa64-projecteku.efi')]
src = next((c for c in cands if c and os.path.isfile(c)), None)
if not src:
    sys.exit('HATA: GRUB imaji yok (build/grub/grubaa64.efi). Once ./build-grub.sh')
dst = R + '/Platform/Samsung/exynos7580/Binaries'
os.makedirs(dst, exist_ok=True)
shutil.copy(src, dst + '/grubaa64.efi')
print('grub <-', src)
p = R + '/Platform/Samsung/exynos7580/exynos7580.fdf'
s=open(p,newline='').read()
anchor='# Device specific fdf\r\n!include $(DEVICE_DXE_FV_COMPONENTS)\r\n'
assert s.count(anchor)==1
add=('# GRUB (Debian arm64 signed, monolithic, GPLv3). Shows up in the UEFI Shell as FSx:\\grubaa64.efi (FvSimpleFileSystem)\r\n'
     'FILE APPLICATION = 5E8F7C2A-3B1D-4A6E-9C54-7D2A1B8E6F03 {\r\n'
     '    SECTION PE32 = Platform/Samsung/exynos7580/Binaries/grubaa64.efi\r\n'
     '    SECTION UI = "grubaa64"\r\n'
     '  }\r\n\r\n')
s=s.replace(anchor,add+anchor)
open(p,'w',newline='').write(s)
print("fdf updated")
