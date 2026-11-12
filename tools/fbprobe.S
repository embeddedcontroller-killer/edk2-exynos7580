/*
 * J7 framebuffer probe (Exynos 7580). No UEFI. If this runs and the values are right, the
 * screen shows 4 horizontal bands: RED, GREEN, BLUE, WHITE (top to bottom), then the CPU idles.
 *  - DECON trigger: 0x14830000 + 0x6b0 = 0x2058   (uniLoader board-a3xelte.c)
 *  - FB: 0x67000000, 720x1280, ARGB8888 (u32 = 0xAARRGGBB)  (uniLoader board-a3xelte.c)
 */
    .text
    .global _start
_start:
    ldr   x0, =0x148306b0
    mov   w1, #0x2058
    str   w1, [x0]
    dsb   sy

    ldr   x0, =0x67000000
    ldr   w1, =0xFFFF0000      /* red   */
    bl    band
    ldr   w1, =0xFF00FF00      /* green */
    bl    band
    ldr   w1, =0xFF0000FF      /* blue  */
    bl    band
    ldr   w1, =0xFFFFFFFF      /* white */
    bl    band
    dsb   sy
1:  wfi
    b     1b

/* fills 230400 pixels (320 rows x 720) with w1 starting at x0, advances x0 */
band:
    ldr   x4, =230400
2:  str   w1, [x0], #4
    subs  x4, x4, #1
    b.ne  2b
    ret
