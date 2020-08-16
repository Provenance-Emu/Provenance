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
#ifndef CIC3_H
#define CIC3_H

#include "rshift16_round.h"
#include "subresampler.h"

template<unsigned channels>
class Cic3Core {
public:
	explicit Cic3Core(unsigned div = 1) { reset(div); }
	unsigned div() const { return div_; }
	std::size_t filter(short *out, short const *in, std::size_t inlen);
	void reset(unsigned div);

	static double gain(unsigned div) {
		return rshift16_round(-32768l * (div * div * div) * mulForDiv(div)) / -32768.0;
	}

private:
	unsigned long sum1_;
	unsigned long sum2_;
	unsigned long sum3_;
	unsigned long prev1_;
	unsigned long prev2_;
	unsigned div_;
	unsigned nextdivn_;

	// trouble if div is too large, may be better to only support power of 2 div
	static long mulForDiv(unsigned div) { return 0x10000 / (div * div * div); }
};

template<unsigned channels>
void Cic3Core<channels>::reset(unsigned div) {
	sum3_ = sum2_ = sum1_ = 0;
	prev2_ = prev1_ = 0;
	div_ = div;
	nextdivn_ = div;
}

template<unsigned channels>
std::size_t Cic3Core<channels>::filter(short *out, short const *const in, std::size_t inlen) {
	std::size_t const produced = (inlen + div_ - nextdivn_) / div_;
	short const *s = in;
	unsigned long sm1 = sum1_;
	unsigned long sm2 = sum2_;
	unsigned long sm3 = sum3_;

	if (inlen >= nextdivn_) {
		long const mul = mulForDiv(div_);
		unsigned divn = nextdivn_;
		std::size_t n = produced;

		do {
			do {
				sm1 += static_cast<long>(*s);
				sm2 += sm1;
				sm3 += sm2;
				s += channels;
			} while (--divn);

			unsigned long const out2 = sm3 - prev2_;
			prev2_ = sm3;
			*out = rshift16_round(static_cast<long>(out2 - prev1_) * mul);
			prev1_ = out2;
			out += channels;
			divn = div_;
			sm3 = 0;
		} while (--n);

		nextdivn_ = div_;
	}

	{
		unsigned divn = (in + inlen * channels - s) / channels;
		nextdivn_ -= divn;

		while (divn--) {
			sm1 += static_cast<long>(*s);
			sm2 += sm1;
			sm3 += sm2;
			s += channels;
		}
	}

	sum1_ = sm1;
	sum2_ = sm2;
	sum3_ = sm3;

	return produced;
}

template<unsigned channels>
class Cic3 : public SubResampler {
public:
	enum { MAX_DIV = 23 };
	explicit Cic3(unsigned div);
	virtual std::size_t resample(short *out, short const *in, std::size_t inlen);
	virtual unsigned mul() const { return 1; }
	virtual unsigned div() const { return cics_[0].div(); }
	static double gain(unsigned div) { return Cic3Core<channels>::gain(div); }

private:
	Cic3Core<channels> cics_[channels];
};

template<unsigned channels>
Cic3<channels>::Cic3(unsigned div) {
	for (unsigned i = 0; i < channels; ++i)
		cics_[i].reset(div);
}

template<unsigned channels>
std::size_t Cic3<channels>::resample(short *out, short const *in, std::size_t inlen) {
	std::size_t samplesOut;
	for (unsigned i = 0; i < channels; ++i)
		samplesOut = cics_[i].filter(out + i, in + i, inlen);

	return samplesOut;
}

#endif
