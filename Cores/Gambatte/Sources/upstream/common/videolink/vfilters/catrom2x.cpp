/***************************************************************************
 *   Copyright (C) 2007 by Sindre Aamås                                    *
 *   sinamas@users.sourceforge.net                                         *
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
#include "catrom2x.h"
#include <algorithm>

namespace {

enum { in_width  = VfilterInfo::in_width };
enum { in_height = VfilterInfo::in_height };
enum { in_pitch  = in_width + 3 };

struct Colorsum {
	gambatte::uint_least32_t r, g, b;
};

static void mergeColumns(gambatte::uint_least32_t *dest, Colorsum const *sums) {
	for (unsigned w = in_width; w--;) {
		{
			gambatte::uint_least32_t rsum = sums[1].r;
			gambatte::uint_least32_t gsum = sums[1].g;
			gambatte::uint_least32_t bsum = sums[1].b;

			if (rsum >= 0x80000000) rsum = 0;
			if (gsum >= 0x80000000) gsum = 0;
			if (bsum >= 0x80000000) bsum = 0;

			rsum <<= 12;
			rsum += 0x008000;
			gsum >>= 4;
			gsum += 0x0080;
			bsum += 0x0008;
			bsum >>= 4;

			if (rsum > 0xFF0000) rsum = 0xFF0000;
			if (gsum > 0x00FF00) gsum = 0x00FF00;
			if (bsum > 0x0000FF) bsum = 0x0000FF;

			*dest++ = (rsum & 0xFF0000) | (gsum & 0x00FF00) | bsum;
		}

		{
			gambatte::uint_least32_t rsum = sums[1].r * 9;
			gambatte::uint_least32_t gsum = sums[1].g * 9;
			gambatte::uint_least32_t bsum = sums[1].b * 9;

			rsum -= sums[0].r;
			gsum -= sums[0].g;
			bsum -= sums[0].b;

			rsum += sums[2].r * 9;
			gsum += sums[2].g * 9;
			bsum += sums[2].b * 9;

			rsum -= sums[3].r;
			gsum -= sums[3].g;
			bsum -= sums[3].b;

			if (rsum >= 0x80000000) rsum = 0;
			if (gsum >= 0x80000000) gsum = 0;
			if (bsum >= 0x80000000) bsum = 0;

			rsum <<= 8;
			rsum += 0x008000;
			gsum >>= 8;
			gsum += 0x000080;
			bsum += 0x000080;
			bsum >>= 8;

			if (rsum > 0xFF0000) rsum = 0xFF0000;
			if (gsum > 0x00FF00) gsum = 0x00FF00;
			if (bsum > 0x0000FF) bsum = 0x0000FF;

			*dest++ = (rsum & 0xFF0000) | (gsum & 0x00FF00) | bsum;
		}

		++sums;
	}
}

static void filter(gambatte::uint_least32_t *dline,
                   std::ptrdiff_t const pitch,
                   gambatte::uint_least32_t const *sline)
{
	Colorsum sums[in_pitch];
	for (unsigned h = in_height; h--;) {
		{
			gambatte::uint_least32_t const *s = sline;
			Colorsum *sum = sums;
			unsigned n = in_pitch;
			while (n--) {
				unsigned long pixel = *s;
				sum->r = pixel >> 12 & 0x000FF0 ;
				pixel <<= 4;
				sum->g = pixel & 0x0FF000;
				sum->b = pixel & 0x000FF0;

				++s;
				++sum;
			}
		}

		mergeColumns(dline, sums);
		dline += pitch;

		{
			gambatte::uint_least32_t const *s = sline;
			Colorsum *sum = sums;
			unsigned n = in_pitch;
			while (n--) {
				unsigned long pixel = *s;
				unsigned long rsum = (pixel >> 16) * 9;
				unsigned long gsum = (pixel & 0x00FF00) * 9;
				unsigned long bsum = (pixel & 0x0000FF) * 9;

				pixel = s[-1 * in_pitch];
				rsum -= pixel >> 16;
				gsum -= pixel & 0x00FF00;
				bsum -= pixel & 0x0000FF;

				pixel = s[1 * in_pitch];
				rsum += (pixel >> 16) * 9;
				gsum += (pixel & 0x00FF00) * 9;
				bsum += (pixel & 0x0000FF) * 9;

				pixel = s[2 * in_pitch];
				rsum -= pixel >> 16;
				gsum -= pixel & 0x00FF00;
				bsum -= pixel & 0x0000FF;

				sum->r = rsum;
				sum->g = gsum;
				sum->b = bsum;

				++s;
				++sum;
			}
		}

		mergeColumns(dline, sums);
		dline += pitch;
		sline += in_pitch;
	}
}

} // anon namespace

Catrom2x::Catrom2x()
: buffer_((in_height + 3UL) * in_pitch)
{
	std::fill_n(buffer_.get(), buffer_.size(), 0);
}

void * Catrom2x::inBuf() const {
	return buffer_ + in_pitch + 1;
}

std::ptrdiff_t Catrom2x::inPitch() const {
	return in_pitch;
}

void Catrom2x::draw(void *dbuffer, std::ptrdiff_t pitch) {
	::filter(static_cast<gambatte::uint_least32_t *>(dbuffer), pitch, buffer_ + in_pitch);
}
