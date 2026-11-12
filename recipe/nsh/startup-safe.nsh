@echo -off
cls
echo ===== ProjectEku - Galaxy J7 =====
stall 1000000
if exist FS0:\grubaa64.efi then
  cls
  FS0:\grubaa64.efi
endif
if exist FS1:\grubaa64.efi then
  cls
  FS1:\grubaa64.efi
endif
cls
echo ProjectEku Linux 6.12 basliyor...
stall 3000000
if exist FS0:\linux.efi then
  FS0:\linux.efi console=tty0 ignore_loglevel initcall_debug clk_ignore_unused pd_ignore_unused maxcpus=1 rdinit=/init
endif
if exist FS1:\linux.efi then
  FS1:\linux.efi console=tty0 ignore_loglevel initcall_debug clk_ignore_unused pd_ignore_unused maxcpus=1 rdinit=/init
endif
echo linux.efi calismadi, Shell durumda
