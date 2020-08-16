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
#ifndef LININT_H
#define LININT_H

#include "../resampler.h"
#include "rshift16_round.h"
#include "u48div.h"
#include <cstddef>

template<int channels>
class LinintCore {
public:
	LinintCore() { *this = LinintCore(1, 1); }
	LinintCore(long inRate, long outRate);
	void adjustRate(long inRate, long outRate) { ratio_ = calcRatio(inRate, outRate); }
	void exactRatio(unsigned long &mul, unsigned long &div) const { mul = 0x10000; div = ratio_; }

	std::size_t maxOut(std::size_t inlen) const {
		return inlen ? u48div(inlen - 1, 0xffff, ratio_) + 1 : 0;
	}

	std::size_t resample(short *out, short const *in, std::size_t inlen);

private:
	unsigned long ratio_;
	std::size_t pos_;
	unsigned fracPos_;
	int prevSample_;

	static unsigned long calcRatio(long inRate, long outRate) {
		return static_cast<unsigned long>((double(inRate) / outRate) * 0x10000 + 0.5);
	}
};

template<int channels>
LinintCore<channels>::LinintCore(long inRate, long outRate)
: ratio_(calcRatio(inRate, outRate))
, pos_((ratio_ >> 16) + 1)
, fracPos_(ratio_ & 0xffff)
, prevSample_(0)
{
}

template<int channels>
std::size_t LinintCore<channels>::resample(
		short *const out, short const *const in, std::size_t const inlen) {
	if (pos_ < inlen) {
		unsigned long const ratio = ratio_;
		unsigned fracPos = fracPos_;
		short *o = out;
		std::ptrdiff_t pos = pos_;
		while (pos == 0) {
			long const lhs = prevSample_;
			long const rhs = in[0];
			*o = lhs + rshift16_round((rhs - lhs) * static_cast<long>(fracPos));
			o += channels;

			unsigned long const nfrac = fracPos + ratio;
			fracPos = nfrac & 0xffff;
			pos    += nfrac >> 16;
		}

		short const *const inend = in + inlen * channels;
		pos -= static_cast<std::ptrdiff_t>(inlen);
		while (pos < 0) {
			long const lhs = inend[(pos-1) * channels];
			long const rhs = inend[ pos    * channels];
			*o = lhs + rshift16_round((rhs - lhs) * static_cast<long>(fracPos));
			o += channels;

			unsigned long const nfrac = fracPos + ratio;
			fracPos = nfrac & 0xffff;
			pos    += nfrac >> 16;
		}

		prevSample_ = inend[-channels];
		pos_ = pos;
		fracPos_ = fracPos;

		return (o - out) / channels;
	}

	return 0;
}

template<int channels>
class Linint : public Resampler {
public:
	Linint(long inRate, long outRate);
	virtual void adjustRate(long inRate, long outRate);

	virtual void exactRatio(unsigned long &mul, unsigned long &div) const {
		cores_[0].exactRatio(mul, div);
	}

	virtual std::size_t maxOut(std::size_t inlen) const { return cores_[0].maxOut(inlen); }
	virtual std::size_t resample(short *out, short const *in, std::size_t inlen);

private:
	LinintCore<channels> cores_[channels];
};

template<int channels>
Linint<channels>::Linint(long inRate, long outRate)
: Resampler(inRate, outRate)
{
	for (int i = 0; i < channels; ++i)
		cores_[i] = LinintCore<channels>(inRate, outRate);
}

template<int channels>
void Linint<channels>::adjustRate(long inRate, long outRate) {
	setRate(inRate, outRate);
	for (int i = 0; i < channels; ++i)
		cores_[i].adjustRate(inRate, outRate);
}

template<int channels>
std::size_t Linint<channels>::resample(short *out, short const *in, std::size_t inlen) {
	std::size_t outlen = 0;
	for (int i = 0; i < channels; ++i)
		outlen = cores_[i].resample(out + i, in + i, inlen);

	return outlen;
}

#endif
