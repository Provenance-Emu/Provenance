/***************************************************************************
 *   Copyright (C) 2008 by Sindre Aamås                                    *
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
#ifndef UPSAMPLER_H
#define UPSAMPLER_H

#include "subresampler.h"
#include <cstring>

template<unsigned channels>
class Upsampler : public SubResampler {
public:
	explicit Upsampler(unsigned mul) : mul_(mul) {}
	virtual std::size_t resample(short *out, short const *in, std::size_t inlen);
	virtual unsigned mul() const { return mul_; }
	virtual unsigned div() const { return 1; }

private:
	unsigned mul_;
};

template<unsigned channels>
std::size_t Upsampler<channels>::resample(short *out, short const *in, std::size_t const inlen) {
	unsigned const mul = mul_;
	if (std::size_t n = inlen) {
		std::memset(out, 0, inlen * mul * channels * sizeof *out);

		do {
			std::memcpy(out, in, channels * sizeof *out);
			in += channels;
			out += mul * channels;
		} while (--n);
	}

	return inlen * mul;
}

#endif
