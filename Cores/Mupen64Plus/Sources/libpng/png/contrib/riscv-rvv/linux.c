/* contrib/riscv-rvv/linux.c
 *
 * Copyright (c) 2023 Google LLC
 * Written by Dragoș Tiselice <dtiselice@google.com>, May 2023.
 *
 * This code is released under the libpng license.
 * For conditions of distribution and use, see the disclaimer
 * and license in png.h
 *
 * SEE contrib/riscv-rvv/README before reporting bugs
 *
 * STATUS: SUPPORTED
 * BUG REPORTS: png-mng-implement@sourceforge.net
 *
 * png_have_rvv implemented for Linux by reading the widely available
 * pseudo-file /proc/cpuinfo.
 *
 * This code is strict ANSI-C and is probably moderately portable; it does
 * however use <stdio.h> and it assumes that /proc/cpuinfo is never localized.
 */

#if defined(__linux__)
#include <asm/hwcap.h>
#include <sys/auxv.h>
#endif

static int
png_have_rvv(png_structp png_ptr) {
#if defined(__linux__)
   return getauxval (AT_HWCAP) & COMPAT_HWCAP_ISA_V ? 1 : 0;
#else
#pragma message(                                                               \
   "warning: RISC-V Vector not supported for this platform")
   return 0;
#endif
}
