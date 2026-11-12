## @file
#
#  Copyright (c) 2011-2015, ARM Limited. All rights reserved.
#  Copyright (c) 2014, Linaro Limited. All rights reserved.
#  Copyright (c) 2015 - 2016, Intel Corporation. All rights reserved.
#  Copyright (c) 2018 - 2019, Bingxing Wang. All rights reserved.
#  Copyright (c) 2022, Xilin Wu. All rights reserved.
#
#  SPDX-License-Identifier: BSD-2-Clause-Patent
#
##

################################################################################
#
# Defines Section - statements that will be processed to create a Makefile.
#
################################################################################

[Defines]
  SOC_PLATFORM            = exynos7580
  USE_PHYSICAL_TIMER      = FALSE

!include Silicon/Samsung/ExynosPkg/ExynosCommonDsc.j7.inc

[PcdsFixedAtBuild.common]
  gArmTokenSpaceGuid.PcdSystemMemoryBase|0x40000000
  gArmTokenSpaceGuid.PcdSystemMemorySize|0x50000000   # 0x40000000-0x90000000; 0x90000000+ is reserved/secure on J7

  gArmTokenSpaceGuid.PcdCpuVectorBaseAddress|0x40C40000     # CPU Vectors

  gArmTokenSpaceGuid.PcdArmArchTimerFreqInHz|26000000
  gArmTokenSpaceGuid.PcdArmArchTimerSecIntrNum|13
  gArmTokenSpaceGuid.PcdArmArchTimerIntrNum|14
  gArmTokenSpaceGuid.PcdArmArchTimerVirtIntrNum|11
  gArmTokenSpaceGuid.PcdArmArchTimerHypIntrNum|10

  gArmTokenSpaceGuid.PcdGicDistributorBase|0x10C01000
  gArmTokenSpaceGuid.PcdGicRedistributorsBase|0x10C02000   # unused on GICv2
  gArmTokenSpaceGuid.PcdGicInterruptInterfaceBase|0x10C02000   # GICC (J7 DTS reg #2); S6 DSC wrongly uses the GICH address

  gEfiMdeModulePkgTokenSpaceGuid.PcdAcpiDefaultOemRevision|0x00000850
  gEmbeddedTokenSpaceGuid.PcdPrePiStackBase|0x40C00000      # UEFI Stack
  gEmbeddedTokenSpaceGuid.PcdPrePiStackSize|0x00040000      # 256K stack
  #gEmbeddedTokenSpaceGuid.PcdPrePiCpuIoSize|44

  gSamsungTokenSpaceGuid.PcdUefiMemPoolBase|0x40D00000         # DXE Heap base address
  gSamsungTokenSpaceGuid.PcdUefiMemPoolSize|0x07000000         # UefiMemorySize, DXE heap size
  
  gSamsungTokenSpaceGuid.PcdMipiFrameBufferAddress|0x67000000   # from uniLoader board-a3xelte.c (Exynos 7580 sibling, ARGB8888); UNVERIFIED on J7 until the fb-probe image shows colours
  gSamsungTokenSpaceGuid.PcdMipiFrameBufferWidth|720
  gSamsungTokenSpaceGuid.PcdMipiFrameBufferHeight|1280
  gSamsungTokenSpaceGuid.PcdMipiFrameBufferVisibleWidth|720
  gSamsungTokenSpaceGuid.PcdMipiFrameBufferVisibleHeight|1280

  gArmPlatformTokenSpaceGuid.PcdCPUCoresStackBase|0x4FF00000   # J7: S6 value 0x9FF90000 lies inside J7 memreserve 0x9F700000+0x900000
  gArmPlatformTokenSpaceGuid.PcdCoreCount|8
  gArmPlatformTokenSpaceGuid.PcdClusterCount|2

  #
  # SimpleInit
  #
  gSimpleInitTokenSpaceGuid.PcdDeviceTreeStore|0x80000000
  gSimpleInitTokenSpaceGuid.PcdLoggerdUseConsole|FALSE

[LibraryClasses.common]
  KeypadDeviceImplLib|Silicon/Samsung/Exynos7580Pkg/Library/KeypadDeviceImplLib/KeypadDeviceImplLib.inf
  PlatformMemoryMapLib|Silicon/Samsung/Exynos7580Pkg/Library/PlatformMemoryMapLib/PlatformMemoryMapLib.inf
  PlatformPeiLib|Silicon/Samsung/Exynos7580Pkg/Library/PlatformPeiLib/PlatformPeiLib.inf
  PlatformPrePiLib|Silicon/Samsung/Exynos7580Pkg/Library/PlatformPrePiLib/PlatformPrePiLib.inf
  HwResetSystemLib|Silicon/Samsung/Exynos7580Pkg/Library/ResetSystemLib/ResetSystemLib.inf
  ResetSystemLib|Silicon/Samsung/Exynos7580Pkg/Library/ResetSystemLib/ResetSystemLib.inf
  MsPlatformDevicesLib|Silicon/Samsung/Exynos7580Pkg/Library/MsPlatformDevicesLib/MsPlatformDevicesLib.inf
  SOCSmbiosInfoLib|Silicon/Samsung/Exynos7580Pkg/Library/SOCSmbiosInfoLib/SOCSmbiosInfoLib.inf
