/* J7 reset probe: if this code runs, the phone reboots by itself. */
    .text
    .global _start
_start:
    ldr   x0, =0x10480400      /* Exynos7580 PMU SWRESET (same write Linux exynos_restart does) */
    mov   w1, #1
    str   w1, [x0]
    dsb   sy
1:  wfi
    b     1b
