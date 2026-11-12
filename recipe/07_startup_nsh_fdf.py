import os
R = os.environ.get('EDK2_DIR', os.getcwd()).rstrip('/')
p = R + '/Platform/Samsung/exynos7580/exynos7580.fdf'
s=open(p,newline='').read()
anchor='# Device specific fdf\r\n!include $(DEVICE_DXE_FV_COMPONENTS)\r\n'
assert s.count(anchor)==1 and 'startup.nsh' not in s
add=('# Auto-run script for the UEFI Shell (the phone has no keyboard). Appears as FSx:\\startup.nsh\r\n'
     'FILE FREEFORM = 7C1D6F52-4E0B-4B8A-8E2A-3D9B5A1F0C44 {\r\n'
     '    SECTION RAW = Platform/Samsung/exynos7580/Binaries/startup.nsh\r\n'
     '    SECTION UI = "startup.nsh"\r\n'
     '  }\r\n\r\n')
open(p,'w',newline='').write(s.replace(anchor,add+anchor))
print("fdf ok")
