import os, sys
# ExynosPkg dizininde calisir:  ( cd "$EDK2_DIR/Silicon/Samsung/ExynosPkg" && python3 04_common_dsc.py )
p = os.environ.get('EXYNOS_COMMON_DSC', 'ExynosCommonDsc.inc')
if not os.path.isfile(p):
    sys.exit('HATA: %s bulunamadi; ExynosPkg dizininde calistir' % p)
s=open(p,newline='').read()
out=[]
for line in s.splitlines(keepends=True):
    if any(k in line for k in ('SimpleInitMain.inf','KernelFdtDxe.inf','LinuxSimpleMassStorage.inf')):
        continue
    out.append(line)
open('ExynosCommonDsc.j7.inc','w',newline='').write(''.join(out))
print("written", len(out))
