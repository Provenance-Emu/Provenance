@@
@@  Copyright (C) 2012 Roman Pauer
@@
@@  Permission is hereby granted, free of charge, to any person obtaining a copy of
@@  this software and associated documentation files (the "Software"), to deal in
@@  the Software without restriction, including without limitation the rights to
@@  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
@@  of the Software, and to permit persons to whom the Software is furnished to do
@@  so, subject to the following conditions:
@@
@@  The above copyright notice and this permission notice shall be included in all
@@  copies or substantial portions of the Software.
@@
@@  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
@@  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
@@  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
@@  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
@@  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
@@  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
@@  SOFTWARE.
@@

.arm

#include "neon_normalxx.Sinc"
#include "neon_scale2x.Sinc"

.global neon_scale2x_8_8
.global neon_scale2x_16_16
.global neon_scale2x_8_16

.align 4
neon_scale2x_8_8:

@ r0     = const uint8_t *src
@ r1     = uint8_t *dst
@ r2     = unsigned int width (pixels)
@ r3     = unsigned int srcstride (bytes)
@ [sp]   = unsigned int dststride (bytes)
@ [sp+4] = unsigned int height
@ lr     = return address

        ldr	ip, [sp]                    @ ip = dststride
        push {r4-r9}
        ldr	r9, [sp, #(7*4)]            @ r9 = height
        sub r4, r0, r3                  @ r4 = src - srcstride
        add r5, r0, r3                  @ r5 = src + srcstride
        add r6, r1, ip                  @ r6 = dst + dststride
        sub r3, r3, r2                  @ r3 = srcstride - width
        sub ip, ip, r2                  @ ip = dststride - width
        lsl ip, #1                      @ ip = 2 * dststride - 2 * width
        mov r7, r2                      @ r7 = width
        sub r9, r9, #2                  @ r9 = height - 2

@ r0 = src
@ r1 = dst
@ r2 = width
@ r3 = srcdiff (srcstride - width)
@ r4 = src - srcstride
@ r5 = src + srcstride
@ r6 = dst + dststride
@ r7 = counter
@ r8 = tmpreg
@ r9 = height
@ ip = dstdiff (2 * dststride - 2 * width)

    @ first line
        neon_scale2x_8_8_line first, r4, r0, r5, r7, r1, r6, r8, 0, 0

        add r0, r0, r3
        add r4, r4, r3
        add r5, r5, r3
        add r1, r1, ip
        add r6, r6, ip

    @ middle lines
    101:
        mov r7, r2

        neon_scale2x_8_8_line middle, r4, r0, r5, r7, r1, r6, r8, 0, 0

        subS r9, r9, #1
        add r0, r0, r3
        add r4, r4, r3
        add r5, r5, r3
        add r1, r1, ip
        add r6, r6, ip
        bne 101b

    @ last line
        mov r7, r2

        neon_scale2x_8_8_line last, r4, r0, r5, r7, r1, r6, r8, 0, 0

        pop {r4-r9}
        bx lr

@ end procedure neon_scale2x_8_8


neon_scale2x_16_16:

@ r0     = const uint16_t *src
@ r1     = uint16_t *dst
@ r2     = unsigned int width (pixels)
@ r3     = unsigned int srcstride (bytes)
@ [sp]   = unsigned int dststride (bytes)
@ [sp+4] = unsigned int height
@ lr     = return address

        ldr	ip, [sp]                    @ ip = dststride
        push {r4-r9}
        ldr	r9, [sp, #(7*4)]            @ r9 = height
        sub r4, r0, r3                  @ r4 = src - srcstride
        add r5, r0, r3                  @ r5 = src + srcstride
        add r6, r1, ip                  @ r6 = dst + dststride
        sub r3, r3, r2, lsl #1          @ r3 = srcstride - 2 * width
        sub ip, ip, r2, lsl #1          @ ip = dststride - 2 * width
        lsl ip, #1                      @ ip = 2 * dststride - 4 * width
        mov r7, r2                      @ r7 = width
        sub r9, r9, #2                  @ r9 = height - 2

@ r0 = src
@ r1 = dst
@ r2 = width
@ r3 = srcdiff (srcstride - 2 * width)
@ r4 = src - srcstride
@ r5 = src + srcstride
@ r6 = dst + dststride
@ r7 = counter
@ r8 = tmpreg
@ r9 = height
@ ip = dstdiff (2 * dststride - 4 * width)

    @ first line
        neon_scale2x_16_16_line first, r4, r0, r5, r7, r1, r6, r8, 0, 0

        add r0, r0, r3
        add r4, r4, r3
        add r5, r5, r3
        add r1, r1, ip
        add r6, r6, ip

    @ middle lines
    101:
        mov r7, r2

        neon_scale2x_16_16_line middle, r4, r0, r5, r7, r1, r6, r8, 0, 0

        subS r9, r9, #1
        add r0, r0, r3
        add r4, r4, r3
        add r5, r5, r3
        add r1, r1, ip
        add r6, r6, ip
        bne 101b

    @ last line
        mov r7, r2

        neon_scale2x_16_16_line last, r4, r0, r5, r7, r1, r6, r8, 0, 0

        pop {r4-r9}
        bx lr

@ end procedure neon_scale2x_16_16


neon_scale2x_8_16:

@ r0     = const uint8_t *src
@ r1     = uint8_t *dst
@ r2     = const uint32_t *palette
@ r3     = unsigned int width (pixels)
@ [sp]   = unsigned int srcstride (bytes)
@ [sp+4] = unsigned int dststride (bytes)
@ [sp+8] = unsigned int height
@ lr     = return address

@ three temporary lines

        ldr	ip, [sp]                @ ip = srcstride
        push {r4-r11,lr}
        ldr r4, [sp, #(4*10)]       @ r4 = dststride
        ldr r5, [sp, #(4*11)]       @ r5 = height
        mov r6, sp                  @ r6 = sp
        sub ip, ip, r3              @ ip = srcstride - width
        bic sp, sp, #31             @ align sp to 32 bytes
        sub r7, r4, r3, lsl #1      @ r7 = dststride - 2 * width
        sub sp, sp, r3, lsl #1      @ sp -= 2 * width
        sub r5, r5, #2              @ height -= 2
        mov r10, sp                 @ tmpline3 = sp
        lsl r7, #1                  @ r7 = 2 * dststride - 4 * width
        bic sp, sp, #31             @ align sp to 32 bytes
        sub sp, sp, r3, lsl #1      @ sp -= 2 * width
        mov r11, sp                 @ tmpline2 = sp
        bic sp, sp, #31             @ align sp to 32 bytes
        sub sp, sp, r3, lsl #1      @ sp -= 2 * width
        mov lr, sp                  @ tmpline1 = sp
        bic sp, sp, #31             @ align sp to 32 bytes
        sub sp, sp, #36
        str r6, [sp]                @ oldsp = r6
        str r5, [sp, #4]            @ height = r5
        str ip, [sp, #8]            @ srcdiff = ip
        str r7, [sp, #12]           @ dstdiff = r7
        str r4, [sp, #16]           @ dststride = r4
        str lr, [sp, #20]           @ tmpline1 = lr
        str r11, [sp, #24]          @ tmpline2 = r11
        str r10, [sp, #28]          @ tmpline3 = r10
        str r3, [sp, #32]           @ width = r3

@ r0  = src
@ r1  = dst
@ r2  = palette
@ r3  = counter
@ r4  = dst2

@ r11 = bufptr1
@ ip  = bufptr2
@ lr  = bufptr3

@ [sp]      = oldsp
@ [sp, #4]  = height
@ [sp, #8]  = srcdiff (srcstride - width)
@ [sp, #12] = dstdiff (2 * dststride - 4 * width)
@ [sp, #16] = dststride
@ [sp, #20] = tmpline1
@ [sp, #24] = tmpline2
@ [sp, #28] = tmpline3
@ [sp, #32] = width

    @ lr = tmpline1
    @ r3 = counter

    @ first line
        neon_normal1x_8_16_line r0, lr, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, ip

        ldr r7, [sp, #8]            @ r7 = srcdiff
        ldr r3, [sp, #32]           @ counter = width
        ldr lr, [sp, #24]           @ bufptr3 = tmpline2
        add r0, r0, r7              @ src += srcdiff

    @ second line
        neon_normal1x_8_16_line r0, lr, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, ip

        ldr r9, [sp, #16]           @ r9 = dststride
        ldr r3, [sp, #32]           @ counter = width
        ldr ip, [sp, #20]           @ bufptr2 = tmpline1
        ldr lr, [sp, #24]           @ bufptr3 = tmpline2
        add r4, r1, r9              @ dst2 = dst + dststride

    @ first temporary line
        neon_scale2x_16_16_line first, r11, ip, lr, r3, r1, r4, r5, 1, 0

        ldr r7, [sp, #8]            @ r7 = srcdiff
        ldr r8, [sp, #12]           @ r8 = dstdiff
        ldr r3, [sp, #32]           @ counter = width
        ldr lr, [sp, #28]           @ bufptr3 = tmpline3
        add r0, r0, r7              @ src += srcdiff
        add r1, r1, r8              @ dst += dstdiff

    100:

    @ line n+1
        neon_normal1x_8_16_line r0, lr, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, ip

        ldr r9, [sp, #16]           @ r9 = dststride
        ldr r11, [sp, #20]          @ bufptr1 = tmpline1
        ldr ip, [sp, #24]           @ bufptr2 = tmpline2
        ldr lr, [sp, #28]           @ bufptr3 = tmpline3
        add r4, r1, r9              @ dst2 = dst + dststride
        ldr r3, [sp, #32]           @ counter = width
        str r11, [sp, #28]          @ tmpline3 = bufptr1
        str ip, [sp, #20]           @ tmpline1 = bufptr2
        str lr, [sp, #24]           @ tmpline2 = bufptr3

    @ temporary line n
        neon_scale2x_16_16_line middle, r11, ip, lr, r3, r1, r4, r5, 1, 0

        ldr r6, [sp, #4]            @ r6 = height
        ldr r7, [sp, #8]            @ r7 = srcdiff
        ldr r8, [sp, #12]           @ r8 = dstdiff
        ldr r3, [sp, #32]           @ counter = width
        subS r6, r6, #1             @ height--
        ldr lr, [sp, #28]           @ bufptr3 = tmpline3
        add r0, r0, r7              @ src += srcdiff
        add r1, r1, r8              @ dst += dstdiff
        str r6, [sp, #4]            @ height = r6
        bne 100b


        ldr r9, [sp, #16]           @ r9 = dststride
        ldr r11, [sp, #20]          @ bufptr1 = tmpline1
        ldr ip, [sp, #24]           @ bufptr2 = tmpline2
        add r4, r1, r9              @ dst2 = dst + dststride

    @ last temporary line
        neon_scale2x_16_16_line last, r11, ip, lr, r3, r1, r4, r5, 1, 0


        ldr sp, [sp]                @ sp = oldsp
        pop {r4-r11,lr}
        bx lr

@ end procedure neon_scale2x_8_16

