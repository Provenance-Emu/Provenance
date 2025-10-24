/* arm_init.c - RISC-V Vector optimized filter functions
 *
 * Copyright (c) 2023 Google LLC
 * Written by Dragoș Tiselice <dtiselice@google.com>, May 2023.
 *            Filip Wasil     <f.wasil@samsung.com>, March 2025.
 * This code is released under the libpng license.
 * For conditions of distribution and use, see the disclaimer
 * and license in png.h
 */

#include "../pngpriv.h"

#ifdef PNG_READ_SUPPORTED

#if PNG_RISCV_RVV_OPT > 0

#include <riscv_vector.h>

#ifdef PNG_RISCV_RVV_CHECK_SUPPORTED /* Do run-time checks */
/* WARNING: it is strongly recommended that you do not build libpng with
 * run-time checks for CPU features if at all possible.  In the case of the
 * RISC-V Vector instructions there is no processor-specific way of detecting
 * the presence of the required support, therefore run-time detection is
 * extremely OS specific.
 *
 * You may set the macro PNG_RISCV_RVV_FILE to the file name of file containing
 * a fragment of C source code which defines the png_have_neon function.  There
 * are a number of implementations in contrib/riscv-vector, but the only one that
 * has partial support is contrib/riscv-vector/linux.c - a generic Linux
 * implementation which reads /proc/cpuinfo.
 */

#ifndef PNG_RISCV_RVV_FILE
#  if defined(__linux__)
#    define PNG_RISCV_RVV_FILE "contrib/riscv-vector/linux.c"
#  else
#    error "No support for run-time RISC-V Vector checking; use compile-time options"
#  endif
#endif

static int png_have_rvv(png_structp png_ptr);
#ifdef PNG_RISCV_RVV_FILE
#  include PNG_RISCV_RVV_FILE
#endif
#endif /* PNG_RISCV_RVV_CHECK_SUPPORTED */

#ifndef PNG_ALIGNED_MEMORY_SUPPORTED
#  error "ALIGNED_MEMORY is required; set: -DPNG_ALIGNED_MEMORY_SUPPORTED"
#endif

void
png_init_filter_functions_rvv(png_structp pp, unsigned int bpp)
{
   /* The switch statement is compiled in for RISCV_rvv_API, the call to
    * png_have_rvv is compiled in for RISCV_rvv_CHECK.  If both are
    * defined the check is only performed if the API has not set the VECTOR
    * option on or off explicitly.  In this case the check controls what
    * happens.
    *
    * If the CHECK is not compiled in and the option is UNSET the behavior prior
    * to 1.6.7 was to use the NEON code - this was a bug caused by having the
    * wrong order of the 'ON' and 'default' cases.  UNSET now defaults to OFF,
    * as documented in png.h
    */
   png_debug(1, "in png_init_filter_functions_rvv");
#ifdef PNG_RISCV_RVV_API_SUPPORTED
   switch ((pp->options >> PNG_RISCV_RVV) & 3)
   {
      case PNG_OPTION_UNSET:
         /* Allow the run-time check to execute if it has been enabled -
          * thus both API and CHECK can be turned on.  If it isn't supported
          * this case will fall through to the 'default' below, which just
          * returns.
          */
#endif /* PNG_RISCV_RVV_API_SUPPORTED */
#ifdef PNG_RISCV_RVV_CHECK_SUPPORTED
         {
            static volatile sig_atomic_t no_rvv = -1; /* not checked */

            if (no_rvv < 0)
               no_rvv = !png_have_rvv(pp);

            if (no_rvv)
               return;
         }
#ifdef PNG_RISCV_RVV_API_SUPPORTED
         break;
#endif
#endif /* PNG_RISCV_RVV_CHECK_SUPPORTED */

#ifdef PNG_RISCV_RVV_API_SUPPORTED
      default: /* OFF or INVALID */
         return;

      case PNG_OPTION_ON:
         /* Option turned on */
         break;
   }
#endif

   /* IMPORTANT: any new external functions used here must be declared using
    * PNG_INTERNAL_FUNCTION in ../pngpriv.h.  This is required so that the
    * 'prefix' option to configure works:
    *
    *    ./configure --with-libpng-prefix=foobar_
    *
    * Verify you have got this right by running the above command, doing a build
    * and examining pngprefix.h; it must contain a #define for every external
    * function you add.  (Notice that this happens automatically for the
    * initialization function.)
    */
   pp->read_filter[PNG_FILTER_VALUE_UP-1] = png_read_filter_row_up_rvv;

   if (bpp == 3)
   {
      pp->read_filter[PNG_FILTER_VALUE_AVG-1] = png_read_filter_row_avg3_rvv;
      pp->read_filter[PNG_FILTER_VALUE_PAETH-1] = png_read_filter_row_paeth3_rvv;
      pp->read_filter[PNG_FILTER_VALUE_SUB-1] = png_read_filter_row_sub3_rvv;
   }
   else if (bpp == 4)
   {
      pp->read_filter[PNG_FILTER_VALUE_AVG-1] = png_read_filter_row_avg4_rvv;
      pp->read_filter[PNG_FILTER_VALUE_PAETH-1] = png_read_filter_row_paeth4_rvv;
      pp->read_filter[PNG_FILTER_VALUE_SUB-1] = png_read_filter_row_sub4_rvv;
   }
}

#endif /* PNG_RISCV_RVV_OPT > 0 */
#endif /* PNG_READ_SUPPORTED */
