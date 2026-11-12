import os
R = os.environ.get('EDK2_DIR', os.getcwd()).rstrip('/') + '/'
p = R + 'Platform/Samsung/exynos7580/exynos7580.fdf'
s=open(p,newline='').read()
for pat in ["  INF src/main/SimpleInitMain.inf\r\n","  INF src/kernelfdt/KernelFdtDxe.inf\r\n","  INF Platform/EFI_Binaries/Applications/LinuxSimpleMassStorage/LinuxSimpleMassStorage.inf\r\n"]:
    print(pat.strip(), pat in s); s=s.replace(pat,"")
open(p,'w',newline='').write(s)
p = R + 'Platform/Samsung/exynos7580/j7.dsc'
s=open(p).read().replace("-DENABLE_SIMPLE_INIT ","")
open(p,'w').write(s)
