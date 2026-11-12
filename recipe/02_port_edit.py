import os, re, io
# EDK2 agacinin koku: EDK2_DIR ortam degiskeni ya da bulundugun dizin
R = os.environ.get('EDK2_DIR', os.getcwd()).rstrip('/') + '/'
if not os.path.isdir(R + 'Platform/Samsung/exynos7580'):
    raise SystemExit('HATA: %s/Platform/Samsung/exynos7580 yok (EDK2_DIR?)' % R.rstrip('/'))
def rw(p, fn):
    s=open(R+p).read(); n=fn(s); open(R+p,'w').write(n); return n!=s

# --- SoC DSC
def dsc(s):
    s=s.replace("gArmTokenSpaceGuid.PcdSystemMemorySize|0xBE800000","gArmTokenSpaceGuid.PcdSystemMemorySize|0x50000000   # 0x40000000-0x90000000; 0x90000000+ is reserved/secure on J7")
    s=s.replace("PcdArmArchTimerFreqInHz|24000000","PcdArmArchTimerFreqInHz|26000000")
    s=s.replace("PcdGicDistributorBase|0x11001000","PcdGicDistributorBase|0x10C01000")
    s=s.replace("PcdGicRedistributorsBase|0x11002000","PcdGicRedistributorsBase|0x10C02000   # unused on GICv2")
    s=s.replace("PcdGicInterruptInterfaceBase|0x11004000","PcdGicInterruptInterfaceBase|0x10C02000   # GICC (J7 DTS reg #2); S6 DSC wrongly uses the GICH address")
    s=s.replace("PcdMipiFrameBufferAddress|0xe2a00000","PcdMipiFrameBufferAddress|0x00000000   # TODO(J7): must be read from the device (DECON window0 buffer); see README")
    s=s.replace("PcdMipiFrameBufferWidth|1440","PcdMipiFrameBufferWidth|720").replace("PcdMipiFrameBufferHeight|2560","PcdMipiFrameBufferHeight|1280")
    s=s.replace("PcdMipiFrameBufferVisibleWidth|1440","PcdMipiFrameBufferVisibleWidth|720").replace("PcdMipiFrameBufferVisibleHeight|2560","PcdMipiFrameBufferVisibleHeight|1280")
    if "PcdCPUCoresStackBase" not in s:
        s=s.replace("  gArmPlatformTokenSpaceGuid.PcdCoreCount|8","  gArmPlatformTokenSpaceGuid.PcdCPUCoresStackBase|0x4FF00000   # J7: S6 value 0x9FF90000 lies inside J7 memreserve 0x9F700000+0x900000\n  gArmPlatformTokenSpaceGuid.PcdCoreCount|8",1)
    return s
print("soc dsc", rw('Platform/Samsung/exynos7580/exynos7580.dsc', dsc))

# --- Device DSC
def jdsc(s):
    s=s.replace("PLATFORM_NAME                  = s6","PLATFORM_NAME                  = j7")
    s=s.replace("e940fcdd-48c9-4c1f-af7c-523b972808b8","5b7c0f7e-2a6d-4f0e-9a63-7580a15c0007")
    s=s.replace("PcdMipiFrameBufferWidth|1440","PcdMipiFrameBufferWidth|720").replace("PcdMipiFrameBufferHeight|2560","PcdMipiFrameBufferHeight|1280")
    s=s.replace("PcdGuiDefaultDPI|350","PcdGuiDefaultDPI|240")
    s=s.replace('"Galaxy S6/S6 edge"','"Galaxy J7 (2015)"').replace('"G920F"','"SM-J700F"')
    return s
print("j7 dsc", rw('Platform/Samsung/exynos7580/j7.dsc', jdsc))

# --- Memory map
mm='''#include <Library/BaseLib.h>
#include <Library/PlatformMemoryMapLib.h>

/*
 * Galaxy J7 (2015), Exynos 7580. DRAM 0x40000000-0xA0000000 (1.5 GB).
 * 0x90000000-0xA0000000 is memreserve/reserved-memory in the stock DTS, so only
 * 0x40000000-0x90000000 is described here. No regions may overlap.
 * Source: exynos7580-j7elte_rev06.dts (see DEVICE_MAP.md).
 */
static ARM_MEMORY_REGION_DESCRIPTOR_EX gDeviceMemoryDescriptorEx[] = {
/*                                                    EFI_RESOURCE_ EFI_RESOURCE_ATTRIBUTE_ EFI_MEMORY_TYPE ARM_REGION_ATTRIBUTE_
     MemLabel(32 Char.),  MemBase,    MemSize, BuildHob, ResourceType, ResourceAttribute, MemoryType, CacheAttributes
*/

//--------------------- Register ---------------------
    {"Periphs",           0x00000000, 0x20000000,  AddMem, MEM_RES, UNCACHEABLE,  RtCode,   NS_DEVICE},

//--------------------- DDR --------------------- */

    {"HLOS 0",            0x40000000, 0x00C00000, AddMem, SYS_MEM, SYS_MEM_CAP, Conv,   WRITE_BACK_XN},
    {"UEFI Stack",        0x40C00000, 0x00040000, AddMem, SYS_MEM, SYS_MEM_CAP, BsData, WRITE_BACK},
    {"CPU Vectors",       0x40C40000, 0x00010000, AddMem, SYS_MEM, SYS_MEM_CAP, BsCode, WRITE_BACK},
    {"HLOS 0 Split",      0x40C50000, 0x0F3B0000, AddMem, SYS_MEM, SYS_MEM_CAP, Conv,   WRITE_BACK_XN},
    {"UEFI FD",           0x50000000, 0x00700000, AddMem, SYS_MEM, SYS_MEM_CAP, BsCode, WRITE_BACK},
    {"HLOS 0 Split 2",    0x50700000, 0x3F900000, AddMem, SYS_MEM, SYS_MEM_CAP, Conv,   WRITE_BACK_XN},

    /* Terminator for MMU */
    { "Terminator", 0, 0, 0, 0, 0, 0, 0}};

ARM_MEMORY_REGION_DESCRIPTOR_EX *GetPlatformMemoryMap()
{
  return gDeviceMemoryDescriptorEx;
}
'''
open(R+'Silicon/Samsung/Exynos7580Pkg/Library/PlatformMemoryMapLib/PlatformMemoryMapLib.c','w').write(mm)

# --- PrePi: remove S6-specific blind register write + 20MB screen clear
def pre(s):
    a=s.index("VOID PlatformInitialize()")
    return s[:a]+'''VOID PlatformInitialize()
{
  /*
   * S6 port wrote 0x2058 to 0x139306b0 ("enable fb") and zeroed 20 MB at
   * 0xEC000000. Both are Exynos 7420/S6 specific and would be blind writes on
   * the J7, so they are intentionally NOT ported. The J7 framebuffer address
   * has to be taken from the device first (see README).
   */
  UartInit();
}
'''
print("prepi", rw('Silicon/Samsung/Exynos7580Pkg/Library/PlatformPrePiLib/PlatformUtils.c', pre))

# --- Reset: PMU base from kernel dtsi (reg = 0x10480000), offsets from pmu_cal_sys_exynos7580.h
print("reset", rw('Silicon/Samsung/Exynos7580Pkg/Library/ResetSystemLib/ResetSystemLib.c', lambda s: s.replace("#define PMU_BASE (0x105C0000)","#define PMU_BASE (0x10480000)   /* Exynos 7580 PMU, exynos7580.dtsi */")))

# --- Keypad: gpio-keys from J7 DTS (all on gpa2): vol-up gpa2-0, vol-down gpa2-1, power gpa2-7
def key(s):
    a=s.index("  // vol down (gpa0-3)"); b=s.index("  return RETURN_SUCCESS;",a)
    new='''  // J7 DTS gpio-keys, bank gpa2 in pinctrl@139B0000 (bank offset 0x040)
  // vol down (gpa2-1)
  StaticContext             = KeypadKeyCodeToKeyContext(114);
  StaticContext->PioBase    = 0x139B0000;
  StaticContext->BankOffset = 0x040;
  StaticContext->PinNum     = 1;

  // vol up (gpa2-0)
  StaticContext             = KeypadKeyCodeToKeyContext(115);
  StaticContext->PioBase    = 0x139B0000;
  StaticContext->BankOffset = 0x040;
  StaticContext->PinNum     = 0;

  // power (gpa2-7)
  StaticContext             = KeypadKeyCodeToKeyContext(116);
  StaticContext->PioBase    = 0x139B0000;
  StaticContext->BankOffset = 0x040;
  StaticContext->PinNum     = 7;

'''
    return s[:a]+new+s[b:]
print("keypad", rw('Silicon/Samsung/Exynos7580Pkg/Library/KeypadDeviceImplLib/KeypadDeviceImplLib.c', key))

# --- configs
open(R+'configs/exynos7580.conf','w').write("FD_BASE=0x50000000\nFD_SIZE=0x00700000\n")
open(R+'configs/devices/j7.conf','w').write('''SOC_PLATFORM="EXYNOS7580"
VENDOR_NAME="Samsung"
PLATFORM_NAME="j7"

# mkbootimg config (verify against the device's stock boot.img header)
BOOTIMG_OS_PATCH_LEVEL="2023-02"
BOOTIMG_OS_VERSION=11.0.0
BOOTIMG_HEADER_VERSION=0
''')
open(R+'build_j7.sh','w').write("#!/bin/bash\n\nGCC5_AARCH64_PREFIX=aarch64-linux-gnu- ./build.sh -d j7 -t GCC5 -r DEBUG --skip-rootfs-gen\n")
print("done")
