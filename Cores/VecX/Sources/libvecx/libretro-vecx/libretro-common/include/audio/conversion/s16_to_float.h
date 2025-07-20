/* Copyright  (C) 2010-2021 The RetroArch team
 *
 * ---------------------------------------------------------------------------------------
 * The following license statement only applies to this file (s16_to_float.h).
 * ---------------------------------------------------------------------------------------
 *
 * Permission is hereby granted, free of charge,
 * to any person obtaining a copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
 * and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */
#ifndef __LIBRETRO_SDK_CONVERSION_S16_TO_FLOAT_H__
#define __LIBRETRO_SDK_CONVERSION_S16_TO_FLOAT_H__

#include <stdint.h>
#include <stddef.h>

#include <retro_common_api.h>

RETRO_BEGIN_DECLS

/**
 * convert_s16_to_float:
 * @out               : output buffer
 * @in                : input buffer
 * @samples           : size of samples to be converted
 * @gain              : gain applied (.e.g. audio volume)
 *
 * Converts from signed integer 16-bit
 * to floating point.
 **/
void convert_s16_to_float(float *out,
      const int16_t *in, size_t samples, float gain);

/**
 * convert_s16_to_float_init_simd:
 *
 * Sets up function pointers for conversion
 * functions based on CPU features.
 **/
void convert_s16_to_float_init_simd(void);

RETRO_END_DECLS

#endif
