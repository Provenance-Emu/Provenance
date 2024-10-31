/*
 * Texture Filtering
 * Version:  1.0
 *
 * Copyright (C) 2007  Hiroshi Morii   All Rights Reserved.
 * Email koolsmoky(at)users.sourceforge.net
 * Web   http://www.3dfxzone.it/koolsmoky
 *
 * this is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * this is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with GNU Make; see the file COPYING.  If not, write to
 * the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
 */

#ifdef __MSC__
#pragma warning(disable: 4786)
#endif

/* NOTE: The codes are not optimized. They can be made faster. */

#include <functional>
#include <thread>
#include <assert.h>

#include "TxQuantize.h"

static const unsigned char One2Eight[2] =
{
	0, // 0 = 00000000
	255, // 1 = 11111111
};

static const unsigned char Five2Eight[32] =
{
	0, // 00000 = 00000000
	8, // 00001 = 00001000
	16, // 00010 = 00010000
	25, // 00011 = 00011001
	33, // 00100 = 00100001
	41, // 00101 = 00101001
	49, // 00110 = 00110001
	58, // 00111 = 00111010
	66, // 01000 = 01000010
	74, // 01001 = 01001010
	82, // 01010 = 01010010
	90, // 01011 = 01011010
	99, // 01100 = 01100011
	107, // 01101 = 01101011
	115, // 01110 = 01110011
	123, // 01111 = 01111011
	132, // 10000 = 10000100
	140, // 10001 = 10001100
	148, // 10010 = 10010100
	156, // 10011 = 10011100
	165, // 10100 = 10100101
	173, // 10101 = 10101101
	181, // 10110 = 10110101
	189, // 10111 = 10111101
	197, // 11000 = 11000101
	206, // 11001 = 11001110
	214, // 11010 = 11010110
	222, // 11011 = 11011110
	230, // 11100 = 11100110
	239, // 11101 = 11101111
	247, // 11110 = 11110111
	255  // 11111 = 11111111
};

TxQuantize::TxQuantize()
{
	/* get number of CPU cores. */
	_numcore = TxUtil::getNumberofProcessors();
}


TxQuantize::~TxQuantize()
{
}

void
TxQuantize::ARGB1555_ARGB8888(uint32* src, uint32* dest, int width, int height)
{
	const int siz = (width * height) >> 1;
	uint8 r, g, b, a;
	uint32 color;
	for (int i = 0; i < siz; ++i) {
		color = (*src) & 0xffff;
		r = Five2Eight[color >> 11];
		g = Five2Eight[(color >> 6) & 0x001f];
		b = Five2Eight[(color >> 1) & 0x001f];
		a = One2Eight [(color     ) & 0x0001];
		*dest = (a << 24) | (b << 16) | (g << 8) | r;
		++dest;
		color = (*src) >> 16;
		r = Five2Eight[color >> 11];
		g = Five2Eight[(color >> 6) & 0x001f];
		b = Five2Eight[(color >> 1) & 0x001f];
		a = One2Eight [(color     ) & 0x0001];
		*dest = (a << 24) | (b << 16) | (g << 8) | r;
		++dest;
		++src;
	}
}

void
TxQuantize::ARGB4444_ARGB8888(uint32* src, uint32* dest, int width, int height)
{
	const int siz = (width * height) >> 1;
	for (int i = 0; i < siz; ++i) {
		*dest = ((*src & 0x0000f000) >> 8 ) |
				((*src & 0x00000f00) << 4 ) |
				((*src & 0x000000f0) << 16) |
				((*src & 0x0000000f) << 28);
		*dest |= (*dest >> 4);
		dest++;
		*dest =  ((*src & 0xf0000000) >> 24) |
				 ((*src & 0x0f000000) >> 12) |
				 ((*src & 0x00f00000) >> 0 ) |
				 ((*src & 0x000f0000) << 12);
		*dest |= (*dest >> 4);
		dest++;
		src++;
	}
}

void
TxQuantize::RGB565_ARGB8888(uint32* src, uint32* dest, int width, int height)
{
	int siz = (width * height) >> 1;
	int i;
	for (i = 0; i < siz; i++) {
		*dest = (0xff000000 |
				 ((*src & 0x0000f800) << 8) | ((*src & 0x0000e000) << 3) |
				 ((*src & 0x000007e0) << 5) | ((*src & 0x00000600) >> 1) |
				 ((*src & 0x0000001f) << 3) | ((*src & 0x0000001c) >> 2));
		dest++;
		*dest = (0xff000000 |
				 ((*src & 0xf8000000) >>  8) | ((*src & 0xe0000000) >> 13) |
				 ((*src & 0x07e00000) >> 11) | ((*src & 0x06000000) >> 17) |
				 ((*src & 0x001f0000) >> 13) | ((*src & 0x001c0000) >> 18));
		dest++;
		src++;
	}
}

void
TxQuantize::A8_ARGB8888(uint32* src, uint32* dest, int width, int height)
{
	int siz = (width * height) >> 2;
	int i;
	for (i = 0; i < siz; i++) {
		*dest = (*src & 0x000000ff);
		*dest |= (*dest << 8);
		*dest |= (*dest << 16);
		dest++;
		*dest = (*src & 0x0000ff00);
		*dest |= (*dest >> 8);
		*dest |= (*dest << 16);
		dest++;
		*dest = (*src & 0x00ff0000);
		*dest |= (*dest << 8);
		*dest |= (*dest >> 16);
		dest++;
		*dest = (*src & 0xff000000);
		*dest |= (*dest >> 8);
		*dest |= (*dest >> 16);
		dest++;
		src++;
	}
}

void
TxQuantize::AI44_ARGB8888(uint32* src, uint32* dest, int width, int height)
{
	int siz = (width * height) >> 2;
	int i;
	for (i = 0; i < siz; i++) {
		*dest = (*src & 0x0000000f);
		*dest |= ((*dest << 8) | (*dest << 16));
		*dest |= ((*src & 0x000000f0) << 20);
		*dest |= (*dest << 4);
		dest++;
		*dest = (*src & 0x00000f00);
		*dest |= ((*dest << 8) | (*dest >> 8));
		*dest |= ((*src & 0x0000f000) << 12);
		*dest |= (*dest << 4);
		dest++;
		*dest = (*src & 0x000f0000);
		*dest |= ((*dest >> 8) | (*dest >> 16));
		*dest |= ((*src & 0x00f00000) << 4);
		*dest |= (*dest << 4);
		dest++;
		*dest = ((*src & 0x0f000000) >> 4);
		*dest |= ((*dest >> 8) | (*dest >> 16));
		*dest |= (*src & 0xf0000000);
		*dest |= (*dest >> 4);
		dest++;
		src++;
	}
}

void
TxQuantize::AI88_ARGB8888(uint32* src, uint32* dest, int width, int height)
{
	int siz = (width * height) >> 1;
	int i;
	for (i = 0; i < siz; i++) {
		*dest = (*src & 0x000000ff);
		*dest |= ((*dest << 8) | (*dest << 16));
		*dest |= ((*src & 0x0000ff00) << 16);
		dest++;
		*dest = (*src & 0x00ff0000);
		*dest |= ((*dest >> 8) | (*dest >> 16));
		*dest |= (*src & 0xff000000);
		dest++;
		src++;
	}
}

void
TxQuantize::ARGB8888_ARGB1555(uint32* src, uint32* dest, int width, int height)
{
	const int siz = (width * height) >> 1;
	uint32 color;
	uint32 r, g, b;
	for (int i = 0; i < siz; i++) {
		color = *src;
		*dest = ((color & 0xff000000) ? 0x0001 : 0x0000);
		r = (color & 0x000000FF) >> 3;
		g = (color & 0x0000FF00) >> 11;
		b = (color & 0x00FF0000) >> 19;
		*dest |= (r<<11)|(g<<6)|(b<<1);
		src++;
		color = *src;
		*dest |= ((color & 0xff000000) ? 0x00010000 : 0x0000);
		r = (color & 0x000000FF) >> 3;
		g = (color & 0x0000FF00) >> 11;
		b = (color & 0x00FF0000) >> 19;
		*dest |= (r<<27)|(g<<22)|(b<<17);
		src++;
		dest++;
	}
}

void
TxQuantize::ARGB8888_ARGB4444(uint32* src, uint32* dest, int width, int height)
{
	const int siz = (width * height) >> 1;
	for (int i = 0; i < siz; ++i) {
		*dest = (((*src & 0xf0000000) >> 28) |
				 ((*src & 0x00f00000) >> 16) |
				 ((*src & 0x0000f000) >> 4)  |
				 ((*src & 0x000000f0) << 8));
		src++;
		*dest |= (((*src & 0xf0000000) >> 12) |
				  ((*src & 0x00f00000) << 0)  |
				  ((*src & 0x0000f000) << 12) |
				  ((*src & 0x000000f0) << 24));
		src++;
		dest++;
	}
}

void
TxQuantize::ARGB8888_RGB565(uint32* src, uint32* dest, int width, int height)
{
	int siz = (width * height) >> 1;
	int i;
	for (i = 0; i < siz; i++) {
		*dest = (((*src & 0x000000f8) >> 3) |
				 ((*src & 0x0000fc00) >> 5) |
				 ((*src & 0x00f80000) >> 8));
		src++;
		*dest |= (((*src & 0x000000f8) << 13) |
				  ((*src & 0x0000fc00) << 11) |
				  ((*src & 0x00f80000) << 8));
		src++;
		dest++;
	}
}

void
TxQuantize::ARGB8888_A8(uint32* src, uint32* dest, int width, int height)
{
	int siz = (width * height) >> 2;
	int i;
	for (i = 0; i < siz; i++) {
		*dest = (*src & 0x0000ff00) >> 8;
		src++;
		*dest |= (*src & 0x0000ff00);
		src++;
		*dest |= ((*src & 0x0000ff00) << 8);
		src++;
		*dest |= ((*src & 0x0000ff00) << 16);
		src++;
		dest++;
	}
}

void
TxQuantize::ARGB8888_AI44(uint32* src, uint32* dest, int width, int height)
{
	int siz = (width * height) >> 2;
	int i;
	for (i = 0; i < siz; i++) {
		*dest = (((*src & 0xf0000000) >> 24) | ((*src & 0x0000f000) >> 12));
		src++;
		*dest |= (((*src & 0xf0000000) >> 16) | ((*src & 0x0000f000) >> 4));
		src++;
		*dest |= (((*src & 0xf0000000) >> 8) | ((*src & 0x0000f000) << 4));
		src++;
		*dest |= ((*src & 0xf0000000) | ((*src & 0x0000f000) << 12));
		src++;
		dest++;
	}
}

void
TxQuantize::ARGB8888_AI88(uint32* src, uint32* dest, int width, int height)
{
	int siz = (width * height) >> 1;
	int i;
	for (i = 0; i < siz; i++) {
		*dest = (((*src & 0xff000000) >> 16) | ((*src & 0x0000ff00) >> 8));
		src++;
		*dest |= ((*src & 0xff000000) | ((*src & 0x0000ff00) << 8));
		src++;
		dest++;
	}
}

/* R.W. Floyd and L. Steinberg, An adaptive algorithm
 * for spatial grey scale, Proceedings of the Society
 * of Information Display 17, pp75-77, 1976
 */
void
TxQuantize::ARGB8888_RGB565_ErrD(uint32* src, uint32* dst, int width, int height)
{
	/* Floyd-Steinberg error-diffusion halftoning */

	int i, x, y;
	int qr, qg, qb; /* quantized incoming values */
	int ir, ig, ib; /* incoming values */
	int t;
	int *errR = new int[width];
	int *errG = new int[width];
	int *errB = new int[width];

	uint16 *dest = (uint16 *)dst;

	for (i = 0; i < width; i++) errR[i] = errG[i] = errB[i] = 0;

	for (y = 0; y < height; y++) {
		for (x = 0; x < width; x++) {
			/* incoming pixel values */
			ir = ((*src >> 16) & 0xFF) * 10000;
			ig = ((*src >>  8) & 0xFF) * 10000;
			ib = ((*src      ) & 0xFF) * 10000;

			if (x == 0) qr = qg = qb = 0;

			/* quantize pixel values.
	   * qr * 0.4375 is the error from the pixel to the left,
	   * errR is the error from the pixel to the top, top left, and top right */
			/* qr * 0.4375 is the error distribution to the EAST in
	   * the previous loop */
			ir += errR[x] + qr * 4375 / 10000;
			ig += errG[x] + qg * 4375 / 10000;
			ib += errB[x] + qb * 4375 / 10000;

			/* error distribution to the SOUTH-EAST in the previous loop
	   * can't calculate in the previous loop because it steps on
	   * the above quantization */
			errR[x] = qr * 625 / 10000;
			errG[x] = qg * 625 / 10000;
			errB[x] = qb * 625 / 10000;

			qr = ir;
			qg = ig;
			qb = ib;

			/* clamp */
			if (qr < 0) qr = 0; else if (qr > 2550000) qr = 2550000;
			if (qg < 0) qg = 0; else if (qg > 2550000) qg = 2550000;
			if (qb < 0) qb = 0; else if (qb > 2550000) qb = 2550000;

			/* convert to RGB565 */
			qr = qr * 0x1F / 2550000;
			qg = qg * 0x3F / 2550000;
			qb = qb * 0x1F / 2550000;

			/* this is the dithered pixel */
			t  = (qr << 11) | (qg << 5) | qb;

			/* compute the errors */
			qr = ((qr << 3) | (qr >> 2)) * 10000;
			qg = ((qg << 2) | (qg >> 4)) * 10000;
			qb = ((qb << 3) | (qb >> 2)) * 10000;
			qr = ir - qr;
			qg = ig - qg;
			qb = ib - qb;

			/* compute the error distributions */
			/* Floyd-Steinberg filter
	   * 7/16 (=0.4375) to the EAST
	   * 5/16 (=0.3125) to the SOUTH
	   * 1/16 (=0.0625) to the SOUTH-EAST
	   * 3/16 (=0.1875) to the SOUTH-WEST
	   *
	   *         x    7/16
	   *  3/16  5/16  1/16
	   */
			/* SOUTH-WEST */
			if (x > 1) {
				errR[x - 1] += qr * 1875 / 10000;
				errG[x - 1] += qg * 1875 / 10000;
				errB[x - 1] += qb * 1875 / 10000;
			}

			/* SOUTH */
			errR[x] += qr * 3125 / 10000;
			errG[x] += qg * 3125 / 10000;
			errB[x] += qb * 3125 / 10000;

			*dest = (t & 0xFFFF);

			dest++;
			src++;
		}
	}

	delete [] errR;
	delete [] errG;
	delete [] errB;
}


void
TxQuantize::ARGB8888_ARGB1555_ErrD(uint32* src, uint32* dst, int width, int height)
{
	/* Floyd-Steinberg error-diffusion halftoning */

	int i, x, y;
	int qr, qg, qb; /* quantized incoming values */
	int ir, ig, ib; /* incoming values */
	int t;
	int *errR = new int[width];
	int *errG = new int[width];
	int *errB = new int[width];

	uint16 *dest = (uint16 *)dst;

	for (i = 0; i < width; i++) errR[i] = errG[i] = errB[i] = 0;

	for (y = 0; y < height; y++) {
		for (x = 0; x < width; x++) {
			/* incoming pixel values */
			ir = ((*src >> 16) & 0xFF) * 10000;
			ig = ((*src >>  8) & 0xFF) * 10000;
			ib = ((*src      ) & 0xFF) * 10000;

			if (x == 0) qr = qg = qb = 0;

			/* quantize pixel values.
	   * qr * 0.4375 is the error from the pixel to the left,
	   * errR is the error from the pixel to the top, top left, and top right */
			/* qr * 0.4375 is the error distribution to the EAST in
	   * the previous loop */
			ir += errR[x] + qr * 4375 / 10000;
			ig += errG[x] + qg * 4375 / 10000;
			ib += errB[x] + qb * 4375 / 10000;

			/* error distribution to the SOUTH-EAST of the previous loop.
	   * cannot calculate in the previous loop because it steps on
	   * the above quantization */
			errR[x] = qr * 625 / 10000;
			errG[x] = qg * 625 / 10000;
			errB[x] = qb * 625 / 10000;

			qr = ir;
			qg = ig;
			qb = ib;

			/* clamp */
			if (qr < 0) qr = 0; else if (qr > 2550000) qr = 2550000;
			if (qg < 0) qg = 0; else if (qg > 2550000) qg = 2550000;
			if (qb < 0) qb = 0; else if (qb > 2550000) qb = 2550000;

			/* convert to RGB555 */
			qr = qr * 0x1F / 2550000;
			qg = qg * 0x1F / 2550000;
			qb = qb * 0x1F / 2550000;

			/* this is the dithered pixel */
			t  = (qr << 10) | (qg << 5) | qb;
			t |= ((*src >> 24) ? 0x8000 : 0);

			/* compute the errors */
			qr = ((qr << 3) | (qr >> 2)) * 10000;
			qg = ((qg << 3) | (qg >> 2)) * 10000;
			qb = ((qb << 3) | (qb >> 2)) * 10000;
			qr = ir - qr;
			qg = ig - qg;
			qb = ib - qb;

			/* compute the error distributions */
			/* Floyd-Steinberg filter
	   * 7/16 (=0.4375) to the EAST
	   * 5/16 (=0.3125) to the SOUTH
	   * 1/16 (=0.0625) to the SOUTH-EAST
	   * 3/16 (=0.1875) to the SOUTH-WEST
	   *
	   *         x    7/16
	   *  3/16  5/16  1/16
	   */
			/* SOUTH-WEST */
			if (x > 1) {
				errR[x - 1] += qr * 1875 / 10000;
				errG[x - 1] += qg * 1875 / 10000;
				errB[x - 1] += qb * 1875 / 10000;
			}

			/* SOUTH */
			errR[x] += qr * 3125 / 10000;
			errG[x] += qg * 3125 / 10000;
			errB[x] += qb * 3125 / 10000;

			*dest = (t & 0xFFFF);

			dest++;
			src++;
		}
	}

	delete [] errR;
	delete [] errG;
	delete [] errB;
}

void
TxQuantize::ARGB8888_ARGB4444_ErrD(uint32* src, uint32* dst, int width, int height)
{
	/* Floyd-Steinberg error-diffusion halftoning */

	int i, x, y;
	int qr, qg, qb, qa; /* quantized incoming values */
	int ir, ig, ib, ia; /* incoming values */
	int t;
	int *errR = new int[width];
	int *errG = new int[width];
	int *errB = new int[width];
	int *errA = new int[width];

	uint16 *dest = (uint16 *)dst;

	for (i = 0; i < width; i++) errR[i] = errG[i] = errB[i] = errA[i] = 0;

	for (y = 0; y < height; y++) {
		for (x = 0; x < width; x++) {
			/* incoming pixel values */
			ir = ((*src >> 16) & 0xFF) * 10000;
			ig = ((*src >>  8) & 0xFF) * 10000;
			ib = ((*src      ) & 0xFF) * 10000;
			ia = ((*src >> 24) & 0xFF) * 10000;

			if (x == 0) qr = qg = qb = qa = 0;

			/* quantize pixel values.
	   * qr * 0.4375 is the error from the pixel to the left,
	   * errR is the error from the pixel to the top, top left, and top right */
			/* qr * 0.4375 is the error distribution to the EAST in
	   * the previous loop */
			ir += errR[x] + qr * 4375 / 10000;
			ig += errG[x] + qg * 4375 / 10000;
			ib += errB[x] + qb * 4375 / 10000;
			ia += errA[x] + qa * 4375 / 10000;

			/* error distribution to the SOUTH-EAST of the previous loop.
	   * cannot calculate in the previous loop because it steps on
	   * the above quantization */
			errR[x] = qr * 625 / 10000;
			errG[x] = qg * 625 / 10000;
			errB[x] = qb * 625 / 10000;
			errA[x] = qa * 625 / 10000;

			qr = ir;
			qg = ig;
			qb = ib;
			qa = ia;

			/* clamp */
			if (qr < 0) qr = 0; else if (qr > 2550000) qr = 2550000;
			if (qg < 0) qg = 0; else if (qg > 2550000) qg = 2550000;
			if (qb < 0) qb = 0; else if (qb > 2550000) qb = 2550000;
			if (qa < 0) qa = 0; else if (qa > 2550000) qa = 2550000;

			/* convert to RGB444 */
			qr = qr * 0xF / 2550000;
			qg = qg * 0xF / 2550000;
			qb = qb * 0xF / 2550000;
			qa = qa * 0xF / 2550000;

			t = (qr <<  8) | (qg << 4) | qb;
			t |= (*src >> 16) & 0xF000;

			/* compute the errors */
			qr = ((qr << 4) | qr) * 10000;
			qg = ((qg << 4) | qg) * 10000;
			qb = ((qb << 4) | qb) * 10000;
			qa = ((qa << 4) | qa) * 10000;
			qr = ir - qr;
			qg = ig - qg;
			qb = ib - qb;
			qa = ia - qa;

			/* compute the error distributions */
			/* Floyd-Steinberg filter
	   * 7/16 (=0.4375) to the EAST
	   * 5/16 (=0.3125) to the SOUTH
	   * 1/16 (=0.0625) to the SOUTH-EAST
	   * 3/16 (=0.1875) to the SOUTH-WEST
	   *
	   *         x    7/16
	   *  3/16  5/16  1/16
	   */
			/* SOUTH-WEST */
			if (x > 1) {
				errR[x - 1] += qr * 1875 / 10000;
				errG[x - 1] += qg * 1875 / 10000;
				errB[x - 1] += qb * 1875 / 10000;
				errA[x - 1] += qa * 1875 / 10000;
			}

			/* SOUTH */
			errR[x] += qr * 3125 / 10000;
			errG[x] += qg * 3125 / 10000;
			errB[x] += qb * 3125 / 10000;
			errA[x] += qa * 3125 / 10000;

			*dest = (t & 0xFFFF);

			dest++;
			src++;
		}
	}

	delete [] errR;
	delete [] errG;
	delete [] errB;
	delete [] errA;
}

void
TxQuantize::ARGB8888_AI44_ErrD(uint32* src, uint32* dst, int width, int height)
{
	/* Floyd-Steinberg error-diffusion halftoning */

	int i, x, y;
	int qi, qa; /* quantized incoming values */
	int ii, ia; /* incoming values */
	int t;
	int *errI = new int[width];
	int *errA = new int[width];

	uint8 *dest = (uint8 *)dst;

	for (i = 0; i < width; i++) errI[i] = errA[i] = 0;

	for (y = 0; y < height; y++) {
		for (x = 0; x < width; x++) {
			/* 3dfx style Intensity = R * 0.299 + G * 0.587 + B * 0.114 */
			ii = ((*src >> 16) & 0xFF) * 2990 +
					((*src >>  8) & 0xFF) * 5870 +
					((*src      ) & 0xFF) * 1140;
			ia = ((*src >> 24) & 0xFF) * 10000;

			if (x == 0) qi = qa = 0;

			/* quantize pixel values.
	   * qi * 0.4375 is the error from the pixel to the left,
	   * errI is the error from the pixel to the top, top left, and top right */
			/* qi * 0.4375 is the error distrtibution to the EAST in
	   * the previous loop */
			ii += errI[x] + qi * 4375 / 10000;
			ia += errA[x] + qa * 4375 / 10000;

			/* error distribution to the SOUTH-EAST in the previous loop.
	   * cannot calculate in the previous loop because it steps on
	   * the above quantization */
			errI[x] = qi * 625 / 10000;
			errA[x] = qa * 625 / 10000;

			qi = ii;
			qa = ia;

			/* clamp */
			if (qi < 0) qi = 0; else if (qi > 2550000) qi = 2550000;
			if (qa < 0) qa = 0; else if (qa > 2550000) qa = 2550000;

			/* convert to I4 */
			qi = qi * 0xF / 2550000;
			qa = qa * 0xF / 2550000;

			t = qi;
			t |= ((*src >> 24) & 0xF0);

			/* compute the errors */
			qi = ((qi << 4) | qi) * 10000;
			qa = ((qa << 4) | qa) * 10000;
			qi = ii - qi;
			qa = ia - qa;

			/* compute the error distributions */
			/* Floyd-Steinberg filter
	   * 7/16 (=0.4375) to the EAST
	   * 5/16 (=0.3125) to the SOUTH
	   * 1/16 (=0.0625) to the SOUTH-EAST
	   * 3/16 (=0.1875) to the SOUTH-WEST
	   *
	   *         x    7/16
	   *  3/16  5/16  1/16
	   */
			/* SOUTH-WEST */
			if (x > 1) {
				errI[x - 1] += qi * 1875 / 10000;
				errA[x - 1] += qa * 1875 / 10000;
			}

			/* SOUTH */
			errI[x] += qi * 3125 / 10000;
			errA[x] += qa * 3125 / 10000;

			*dest = t & 0xFF;

			dest++;
			src++;
		}
	}

	delete [] errI;
	delete [] errA;
}

void
TxQuantize::ARGB8888_AI88_Slow(uint32* src, uint32* dst, int width, int height)
{
	int x, y;
	uint16 *dest = (uint16 *)dst;
	for (y = 0; y < height; y++) {
		for (x = 0; x < width; x++) {
#if 1
			/* libpng style grayscale conversion.
	   * Reduce RGB files to grayscale with or without alpha
	   * using the equation given in Poynton's ColorFAQ at
	   * <http://www.inforamp.net/~poynton/>
	   * Copyright (c) 1998-01-04 Charles Poynton poynton at inforamp.net
	   *
	   *     Y = 0.212671 * R + 0.715160 * G + 0.072169 * B
	   *
	   *  We approximate this with
	   *
	   *     Y = 0.21268 * R    + 0.7151 * G    + 0.07217 * B
	   *
	   *  which can be expressed with integers as
	   *
	   *     Y = (6969 * R + 23434 * G + 2365 * B)/32768
	   *
	   *  The calculation is to be done in a linear colorspace.
	   */
			*dest = (((int)((((*src >> 16) & 0xFF) * 6969 +
							 ((*src >>  8) & 0xFF) * 23434 +
							 ((*src      ) & 0xFF) * 2365) / 32768) & 0xFF) |
					 (uint16)((*src >> 16) & 0xFF00));
#else
			/* 3dfx style Intensity = R * 0.299 + G * 0.587 + B * 0.114
	   * this is same as the standard NTSC gray scale conversion. */
			*dest = (((int)((((*src >> 16) & 0xFF) * 299 +
							 ((*src >>  8) & 0xFF) * 587 +
							 ((*src      ) & 0xFF) * 114) / 1000) & 0xFF) |
					 (uint16)((*src >> 16) & 0xFF00));
#endif
			dest++;
			src++;
		}
	}
}

void
TxQuantize::ARGB8888_I8_Slow(uint32* src, uint32* dst, int width, int height)
{
	int x, y;
	uint8 *dest = (uint8 *)dst;
	for (y = 0; y < height; y++) {
		for (x = 0; x < width; x++) {
#if 1
			/* libpng style Intensity = (6969 * R + 23434 * G + 2365 * B)/32768 */
			*dest = (int)((((*src >> 16) & 0xFF) * 6969 +
						   ((*src >>  8) & 0xFF) * 23434 +
						   ((*src      ) & 0xFF) * 2365) / 32768) & 0xFF;
#else
			/* 3dfx style Intensity = R * 0.299 + G * 0.587 + B * 0.114
	   * this is same as the standard NTSC gray scale conversion. */
			*dest = (int)((((*src >>16) & 0xFF) * 299 +
						   ((*src >> 8) & 0xFF) * 587 +
						   ((*src     ) & 0xFF) * 114) / 1000) & 0xFF;
#endif
			dest++;
			src++;
		}
	}
}

void
TxQuantize::P8_16BPP(uint32* src, uint32* dest, int width, int height, uint32* palette)
{
	/* passed in palette is RGBA5551 format */
	int i;
	int size = width * height;
	for (i = 0; i < size; i++) {
		((uint16*)dest)[i] = ((uint16*)palette)[(int)(((uint8*)src)[i])];
		((uint16*)dest)[i] = ((((uint16*)dest)[i] << 15) | (((uint16*)dest)[i] >> 1));
	}
}

boolean
TxQuantize::quantize(uint8* src, uint8* dest, int width, int height, ColorFormat srcformat, ColorFormat destformat, boolean fastQuantizer)
{
	typedef void (TxQuantize::*quantizerFunc)(uint32* src, uint32* dest, int width, int height);
	assert(srcformat != graphics::colorFormat::RGBA);
	assert(destformat != graphics::colorFormat::RGBA);
	quantizerFunc quantizer;
	int bpp_shift = 0;

	if (destformat == graphics::internalcolorFormat::RGBA8) {
		if (srcformat == graphics::internalcolorFormat::RGB5_A1) {
			quantizer = &TxQuantize::ARGB1555_ARGB8888;
			bpp_shift = 1;
		} else if (srcformat == graphics::internalcolorFormat::RGBA4) {
			quantizer = &TxQuantize::ARGB4444_ARGB8888;
			bpp_shift = 1;
		} else if (srcformat == graphics::internalcolorFormat::RGB8) {
			quantizer = &TxQuantize::RGB565_ARGB8888;
			bpp_shift = 1;
		} else
			return 0;

		unsigned int numcore = _numcore;
		unsigned int blkrow = 0;
		while (numcore > 1 && blkrow == 0) {
			blkrow = (height >> 2) / numcore;
			numcore--;
		}
		if (blkrow > 0 && numcore > 1) {
			std::thread *thrd[MAX_NUMCORE];
			unsigned int i;
			int blkheight = blkrow << 2;
			unsigned int srcStride = (width * blkheight) << (2 - bpp_shift);
			unsigned int destStride = srcStride << bpp_shift;
			for (i = 0; i < numcore - 1; i++) {
				thrd[i] = new std::thread(std::bind(quantizer,
														this,
														(uint32*)src,
														(uint32*)dest,
														width,
														blkheight));
				src  += srcStride;
				dest += destStride;
			}
			thrd[i] = new std::thread(std::bind(quantizer,
													this,
													(uint32*)src,
													(uint32*)dest,
													width,
													height - blkheight * i));
			for (i = 0; i < numcore; i++) {
				thrd[i]->join();
				delete thrd[i];
			}
		} else {
			(*this.*quantizer)((uint32*)src, (uint32*)dest, width, height);
		}

	} else if (srcformat == graphics::internalcolorFormat::RGBA8) {
		if (destformat == graphics::internalcolorFormat::RGB5_A1) {
			quantizer = fastQuantizer ? &TxQuantize::ARGB8888_ARGB1555 : &TxQuantize::ARGB8888_ARGB1555_ErrD;
			bpp_shift = 1;
		} else if (destformat == graphics::internalcolorFormat::RGBA4) {
			quantizer = fastQuantizer ? &TxQuantize::ARGB8888_ARGB4444 : &TxQuantize::ARGB8888_ARGB4444_ErrD;
			bpp_shift = 1;
		} else if (destformat == graphics::internalcolorFormat::RGB8) {
			quantizer = fastQuantizer ? &TxQuantize::ARGB8888_RGB565 : &TxQuantize::ARGB8888_RGB565_ErrD;
			bpp_shift = 1;
		} else
			return 0;

		unsigned int numcore = _numcore;
		unsigned int blkrow = 0;
		while (numcore > 1 && blkrow == 0) {
			blkrow = (height >> 2) / numcore;
			numcore--;
		}
		if (blkrow > 0 && numcore > 1) {
			std::thread *thrd[MAX_NUMCORE];
			unsigned int i;
			int blkheight = blkrow << 2;
			unsigned int srcStride = (width * blkheight) << 2;
			unsigned int destStride = srcStride >> bpp_shift;
			for (i = 0; i < numcore - 1; i++) {
				thrd[i] = new std::thread(std::bind(quantizer,
														this,
														(uint32*)src,
														(uint32*)dest,
														width,
														blkheight));
				src  += srcStride;
				dest += destStride;
			}
			thrd[i] = new std::thread(std::bind(quantizer,
													this,
													(uint32*)src,
													(uint32*)dest,
													width,
													height - blkheight * i));
			for (i = 0; i < numcore; i++) {
				thrd[i]->join();
				delete thrd[i];
			}
		} else {
			(*this.*quantizer)((uint32*)src, (uint32*)dest, width, height);
		}

	} else {
		return 0;
	}

	return 1;
}
