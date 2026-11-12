import os
R = os.environ.get('EDK2_DIR', os.getcwd()).rstrip('/') + '/'
def rw(p, fn):
    s=open(R+p).read(); n=fn(s); assert n!=s, p; open(R+p,'w').write(n)

# 1. DSC: framebuffer address from uniLoader board-a3xelte.c (Exynos 7580, 720x1280, ARGB8888)
rw('Platform/Samsung/exynos7580/exynos7580.dsc', lambda s: s.replace(
 "gSamsungTokenSpaceGuid.PcdMipiFrameBufferAddress|0x00000000   # TODO(J7): must be read from the device (DECON window0 buffer); see README",
 "gSamsungTokenSpaceGuid.PcdMipiFrameBufferAddress|0x67000000   # from uniLoader board-a3xelte.c (Exynos 7580 sibling, ARGB8888); UNVERIFIED on J7 until the fb-probe image shows colours"))

# 2. PlatformInitialize: DECON trigger (my earlier removal was wrong) + clear framebuffer
def util(s):
    a=s.index("VOID PlatformInitialize()")
    return s[:a]+'''#define J7_DECON_F_BASE             0x14830000
#define J7_DECON_HW_SW_TRIG_CONTROL 0x6b0

VOID PlatformInitialize()
{
  /*
   * S-Boot leaves the DECON trigger control unset, so the framebuffer would not refresh.
   * Same offset (0x6b0) and value (0x2058) as uniLoader's board-a3xelte.c (Exynos 7580,
   * DECON_F at 0x14830000, identical to the J7 DTS) and as the S6 port (0x13930000 + 0x6b0).
   * An earlier revision of this port removed it as a "blind write"; that was wrong.
   */
  MmioWrite32(J7_DECON_F_BASE + J7_DECON_HW_SW_TRIG_CONTROL, 0x2058);

  ZeroMem((VOID *)(UINTN)FixedPcdGet32(PcdMipiFrameBufferAddress),
          FixedPcdGet32(PcdMipiFrameBufferWidth) * FixedPcdGet32(PcdMipiFrameBufferHeight) *
          FixedPcdGet32(PcdMipiFrameBufferPixelBpp) / 8);

  UartInit();
}
'''
rw('Silicon/Samsung/Exynos7580Pkg/Library/PlatformPrePiLib/PlatformUtils.c', util)

# 3. memory map: reserve the display region (FB + shared console words right after it)
def mm(s):
    old='    {"HLOS 0 Split 2",    0x50700000, 0x3F900000, AddMem, SYS_MEM, SYS_MEM_CAP, Conv,   WRITE_BACK_XN},\n'
    assert old in s
    new=('    {"HLOS 0 Split 2",    0x50700000, 0x16900000, AddMem, SYS_MEM, SYS_MEM_CAP, Conv,   WRITE_BACK_XN},\n'
         '    {"Display Reserved",  0x67000000, 0x00400000, AddMem, MEM_RES, SYS_MEM_CAP, Reserv, WRITE_THROUGH_XN},\n'
         '    {"HLOS 0 Split 3",    0x67400000, 0x28C00000, AddMem, SYS_MEM, SYS_MEM_CAP, Conv,   WRITE_BACK_XN},\n')
    return s.replace(old,new)
rw('Silicon/Samsung/Exynos7580Pkg/Library/PlatformMemoryMapLib/PlatformMemoryMapLib.c', mm)
print("edits ok")
