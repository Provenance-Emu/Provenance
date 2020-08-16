/***************************************************************************
 *   Copyright (C) 2007 by Sindre Aamås                                    *
 *   sinamas@users.sourceforge.net                                         *
 *                                                                         *
 *   Copyright (C) 1999 Derek Liauw Kie Fa (Kreed)                         *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License version 2 as     *
 *   published by the Free Software Foundation.                            *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License version 2 for more details.                *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   version 2 along with this program; if not, write to the               *
 *   Free Software Foundation, Inc.,                                       *
 *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
 ***************************************************************************/
#include "kreed2xsai.h"
#include <algorithm>

namespace {

static int getResult1(unsigned long const a,
                      unsigned long const b,
                      unsigned long const c,
                      unsigned long const d)
{
	int x = 0;
	int y = 0;
	int r = 0;

	if (a == c) ++x;
	else if (b == c) ++y;

	if (a == d) ++x;
	else if (b == d) ++y;

	if (x <= 1) ++r;
	if (y <= 1) --r;

	return r;
}

static int getResult2(unsigned long const a,
                      unsigned long const b,
                      unsigned long const c,
                      unsigned long const d)
{
	int x = 0;
	int y = 0;
	int r = 0;

	if (a == c) ++x;
	else if (b == c) ++y;

	if (a == d) ++x;
	else if (b == d) ++y;

	if (x <= 1) --r;
	if (y <= 1) ++r;

	return r;
}

static unsigned long interpolate(unsigned long a, unsigned long b) {
	return (a + b - ((a ^ b) & 0x010101)) >> 1;
}

static unsigned long qInterpolate(unsigned long const a,
                                  unsigned long const b,
                                  unsigned long const c,
                                  unsigned long const d)
{
	unsigned long lowBits = ((a & 0x030303)
	                         + (b & 0x030303)
	                         + (c & 0x030303)
	                         + (d & 0x030303)) & 0x030303;
	return (a + b + c + d - lowBits) >> 2;
}

template<std::ptrdiff_t srcPitch, unsigned width, unsigned height>
static void filter(gambatte::uint_least32_t *dstPtr,
                   std::ptrdiff_t const dstPitch,
                   gambatte::uint_least32_t const *srcPtr)
{
	for (unsigned h = height; h--;) {
		gambatte::uint_least32_t const *bP = srcPtr;
		gambatte::uint_least32_t *dP = dstPtr;
		for (unsigned w = width; w--;) {
			unsigned long colorA, colorB, colorC, colorD,
			              colorE, colorF, colorG, colorH,
			              colorI, colorJ, colorK, colorL,
			              colorM, colorN, colorO/*, colorP*/;

			//---------------------------------------
			// Map of the pixels:                    I|E F|J
			//                                       G|A B|K
			//                                       H|C D|L
			//                                       M|N O|P

			colorI = *(bP - srcPitch - 1);
			colorE = *(bP - srcPitch    );
			colorF = *(bP - srcPitch + 1);
			colorJ = *(bP - srcPitch + 2);

			colorG = *(bP - 1);
			colorA = *(bP    );
			colorB = *(bP + 1);
			colorK = *(bP + 2);

			colorH = *(bP + srcPitch - 1);
			colorC = *(bP + srcPitch    );
			colorD = *(bP + srcPitch + 1);
			colorL = *(bP + srcPitch + 2);

			colorM = *(bP + srcPitch * 2 - 1);
			colorN = *(bP + srcPitch * 2    );
			colorO = *(bP + srcPitch * 2 + 1);
			// colorP = *(bP + srcPitch * 2 + 2);

			unsigned long product0, product1, product2;
			if (colorA == colorD && colorB != colorC) {
				product0 =    (colorA == colorE && colorB == colorL)
				           || (colorA == colorC && colorA == colorF
				               && colorB != colorE && colorB == colorJ)
				         ? colorA
				         : interpolate(colorA, colorB);
				product1 =    (colorA == colorG && colorC == colorO)
				           || (colorA == colorB && colorA == colorH
				               && colorG != colorC && colorC == colorM)
				         ? colorA
				         : interpolate(colorA, colorC);
				product2 = colorA;
			} else if (colorB == colorC && colorA != colorD) {
				product0 =    (colorB == colorF && colorA == colorH)
				           || (colorB == colorE && colorB == colorD
				               && colorA != colorF && colorA == colorI)
				         ? colorB
				         : interpolate(colorA, colorB);
				product1 =    (colorC == colorH && colorA == colorF)
				           || (colorC == colorG && colorC == colorD
				               && colorA != colorH && colorA == colorI)
				         ? colorC
				         : interpolate(colorA, colorC);
				product2 = colorB;
			} else if (colorA == colorD && colorB == colorC) {
				if (colorA == colorB) {
					product0 = colorA;
					product1 = colorA;
					product2 = colorA;
				} else {
					product0 = interpolate(colorA, colorB);
					product1 = interpolate(colorA, colorC);

					int r = 0;
					r += getResult1(colorA, colorB, colorG, colorE);
					r += getResult2(colorB, colorA, colorK, colorF);
					r += getResult2(colorB, colorA, colorH, colorN);
					r += getResult1(colorA, colorB, colorL, colorO);
					if (r > 0) {
						product2 = colorA;
					} else if (r < 0) {
						product2 = colorB;
					} else {
						product2 = qInterpolate(colorA, colorB, colorC, colorD);
					}
				}
			} else {
				product2 = qInterpolate(colorA, colorB, colorC, colorD);

				if (colorA == colorC && colorA == colorF
						&& colorB != colorE && colorB == colorJ) {
					product0 = colorA;
				} else if (colorB == colorE && colorB == colorD
						&& colorA != colorF && colorA == colorI) {
					product0 = colorB;
				} else {
					product0 = interpolate(colorA, colorB);
				}

				if (colorA == colorB && colorA == colorH
						&& colorG != colorC && colorC == colorM) {
					product1 = colorA;
				} else if (colorC == colorG && colorC == colorD
						&& colorA != colorH && colorA == colorI) {
					product1 = colorC;
				} else {
					product1 = interpolate(colorA, colorC);
				}
			}

			*(dP               ) = colorA;
			*(dP            + 1) = product0;
			*(dP + dstPitch    ) = product1;
			*(dP + dstPitch + 1) = product2;
			dP += 2;
			++bP;
		}

		srcPtr += srcPitch;
		dstPtr += dstPitch * 2;
	}
}

enum { in_width  = VfilterInfo::in_width };
enum { in_height = VfilterInfo::in_height };
enum { in_pitch  = in_width + 3 };
enum { buf_size = (in_height + 3ul) * in_pitch };
enum { buf_offset = in_pitch + 1 };

} // anon namespace

Kreed2xSaI::Kreed2xSaI()
: buffer_(buf_size)
{
	std::fill_n(buffer_.get(), buffer_.size(), 0);
}

void * Kreed2xSaI::inBuf() const {
	return buffer_ + buf_offset;
}

std::ptrdiff_t Kreed2xSaI::inPitch() const {
	return in_pitch;
}

void Kreed2xSaI::draw(void *dbuffer, std::ptrdiff_t dpitch) {
	::filter<in_pitch, in_width, in_height>(static_cast<gambatte::uint_least32_t *>(dbuffer),
	                                        dpitch, buffer_ + buf_offset);
}
