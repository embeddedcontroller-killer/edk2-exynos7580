[Defines]
  PLATFORM_NAME                  = j7
  PLATFORM_GUID                  = 5b7c0f7e-2a6d-4f0e-9a63-7580a15c0007
  PLATFORM_VERSION               = 0.1
  DSC_SPECIFICATION              = 0x00010019
  OUTPUT_DIRECTORY               = Build/$(PLATFORM_NAME)
  SUPPORTED_ARCHITECTURES        = AARCH64
  BUILD_TARGETS                  = DEBUG|RELEASE
  SKUID_IDENTIFIER               = DEFAULT
  FLASH_DEFINITION               = Platform/Samsung/exynos7580/exynos7580.fdf
  DEVICE_DXE_FV_COMPONENTS       = Platform/Samsung/exynos7580/exynos7580.fdf.inc
  BROKEN_CNTFRQ_EL0              = 1
  IMPLEMENTS_CUSTOM_RESETLIB	 = 1

!include Platform/Samsung/exynos7580/exynos7580.dsc

[BuildOptions.common]
  GCC:*_*_AARCH64_CC_FLAGS = -DBROKEN_CNTFRQ_EL0=$(BROKEN_CNTFRQ_EL0)

[PcdsFixedAtBuild.common]
  gSamsungTokenSpaceGuid.PcdMipiFrameBufferWidth|720
  gSamsungTokenSpaceGuid.PcdMipiFrameBufferHeight|1280

  # Simple Init
  gSimpleInitTokenSpaceGuid.PcdGuiDefaultDPI|240

  gRenegadePkgTokenSpaceGuid.PcdDeviceVendor|"Samsung"
  gRenegadePkgTokenSpaceGuid.PcdDeviceProduct|"Galaxy J7 (2015)"
  gRenegadePkgTokenSpaceGuid.PcdDeviceCodeName|"SM-J700F"
