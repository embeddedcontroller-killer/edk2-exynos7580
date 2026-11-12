#include <Library/PcdLib.h>
#include <Library/ArmLib.h>
#include <Library/BaseMemoryLib.h>
#include <Library/DebugLib.h>
#include <Library/IoLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Library/HobLib.h>
#include <Library/SerialPortLib.h>
#include <Library/PrintLib.h>
#include <Library/BaseLib.h>
#include <Library/MemoryMapHelperLib.h>
#include <Library/PlatformPrePiLib.h>

#include "PlatformUtils.h"


VOID InitializeSharedUartBuffers(VOID)
{
  INTN* pFbConPosition = (INTN*)(FixedPcdGet32(PcdMipiFrameBufferAddress) + (FixedPcdGet32(PcdMipiFrameBufferWidth) * 
                                                                              FixedPcdGet32(PcdMipiFrameBufferHeight) * 
                                                                              FixedPcdGet32(PcdMipiFrameBufferPixelBpp) / 8));

  *(pFbConPosition + 0) = 0;
  *(pFbConPosition + 1) = 0;
}

VOID UartInit(VOID)
{
  SerialPortInitialize();

  InitializeSharedUartBuffers();

  DEBUG((EFI_D_INFO, "\nProjectEku edk2-exynos (AArch64)\n"));
  DEBUG(
      (EFI_D_INFO, "Firmware version %s built %a %a\n\n",
       (CHAR16 *)PcdGetPtr(PcdFirmwareVersionString), __TIME__, __DATE__));
}

#define J7_DECON_F_BASE             0x14830000
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
