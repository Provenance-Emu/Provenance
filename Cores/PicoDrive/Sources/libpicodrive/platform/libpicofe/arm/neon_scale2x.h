/**
 *
 *  Copyright (C) 2012 Roman Pauer
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy of
 *  this software and associated documentation files (the "Software"), to deal in
 *  the Software without restriction, including without limitation the rights to
 *  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
 *  of the Software, and to permit persons to whom the Software is furnished to do
 *  so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in all
 *  copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 *  SOFTWARE.
 *
 */

#if !defined(_NEON_SCALE2X_H_INCLUDED_)
#define _NEON_SCALE2X_H_INCLUDED_

#include <inttypes.h>

#ifdef __cplusplus
extern "C" {
#endif

extern void neon_scale2x_8_8(const uint8_t *src, uint8_t *dst, unsigned int width, unsigned int srcstride, unsigned int dststride, unsigned int height);
extern void neon_scale2x_16_16(const uint16_t *src, uint16_t *dst, unsigned int width, unsigned int srcstride, unsigned int dststride, unsigned int height);

extern void neon_scale2x_8_16(const uint8_t *src, uint16_t *dst, const uint32_t *palette, unsigned int width, unsigned int srcstride, unsigned int dststride, unsigned int height);

#ifdef __cplusplus
}
#endif


#endif /* _NEON_SCALE2X_H_INCLUDED_ */
