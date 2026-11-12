import os
R = os.environ.get('EDK2_DIR', os.getcwd()).rstrip('/')
p = R + '/Platform/Samsung/exynos7580/exynos7580.fdf'
s=open(p,newline='').read()
anchor='# Device specific fdf\r\n!include $(DEVICE_DXE_FV_COMPONENTS)\r\n'
assert s.count(anchor)==1 and 'linux-Image' not in s
add=('# Linux 6.12 (EFI stub, initramfs with the GUI built in). Shows up as FSx:\\linux.efi\r\n'
     'FILE APPLICATION = 0F2B5D8E-6C41-4E2A-9B7A-5D3E1C8A4B90 {\r\n'
     '    SECTION PE32 = Platform/Samsung/exynos7580/Binaries/linux-Image\r\n'
     '    SECTION UI = "linux"\r\n'
     '  }\r\n\r\n'
     '# Device tree for Linux, picked up by DtPlatformDxe (gDtPlatformDefaultDtbFileGuid)\r\n'
     'FILE FREEFORM = 25462CDA-221F-47DF-AC1D-259CFAA4E326 {\r\n'
     '    SECTION RAW = Platform/Samsung/exynos7580/Binaries/j7elte.dtb\r\n'
     '  }\r\n\r\n')
open(p,'w',newline='').write(s.replace(anchor,add+anchor))
print("fdf ok")
