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
#ifndef CIC4_H
#define CIC4_H

#include "rshift16_round.h"
#include "subresampler.h"

template<unsigned channels>
class Cic4Core {
public:
	explicit Cic4Core(unsigned div = 1) { reset(div); }
	unsigned div() const { return div_; }
	std::size_t filter(short *out, short const *in, std::size_t inlen);
	void reset(unsigned div);

	static double gain(unsigned div) {
		return rshift16_round(-32768l * (div * div * div * div) * mulForDiv(div)) / -32768.0;
	}

private:
	enum { buf_len = 64 };
	unsigned long buf_[buf_len];
	unsigned long sum1_;
	unsigned long sum2_;
	unsigned long sum3_;
	unsigned long sum4_;
	unsigned long prev1_;
	unsigned long prev2_;
	unsigned long prev3_;
	unsigned long prev4_;
	unsigned div_;
	unsigned bufpos_;

	// trouble if div is too large, may be better to only support power of 2 div
	static long mulForDiv(unsigned div) { return 0x10000 / (div * div * div * div); }
};

template<unsigned channels>
void Cic4Core<channels>::reset(unsigned div) {
	sum4_ = sum3_ = sum2_ = sum1_ = 0;
	prev4_ = prev3_ = prev2_ = prev1_ = 0;
	div_ = div;
	bufpos_ = div - 1;
}

template<unsigned channels>
std::size_t Cic4Core<channels>::filter(short *out, short const *const in, std::size_t inlen) {
	std::size_t const produced = (inlen + div_ - (bufpos_ + 1)) / div_;
	long const mul = mulForDiv(div_);
	short const *s = in;

	unsigned long sm1 = sum1_;
	unsigned long sm2 = sum2_;
	unsigned long sm3 = sum3_;
	unsigned long sm4 = sum4_;
	unsigned long prv1 = prev1_;
	unsigned long prv2 = prev2_;
	unsigned long prv3 = prev3_;
	unsigned long prv4 = prev4_;

	while (inlen >> 2) {
		unsigned const end = inlen < buf_len ? inlen & ~3 : buf_len & ~3;
		unsigned long *b = buf_;
		unsigned n = end;

		do {
			unsigned long s1 = sm1 += static_cast<long>(s[0 * channels]);
			sm1 += static_cast<long>(s[1 * channels]);
			unsigned long s2 = sm2 += s1;
			sm2 += sm1;
			unsigned long s3 = sm3 += s2;
			sm3 += sm2;
			b[0] = sm4 += s3;
			b[1] = sm4 += sm3;
			s1 = sm1 += static_cast<long>(s[2 * channels]);
			sm1 += static_cast<long>(s[3 * channels]);
			s2 = sm2 += s1;
			sm2 += sm1;
			s3 = sm3 += s2;
			sm3 += sm2;
			b[2] = sm4 += s3;
			b[3] = sm4 += sm3;
			s += 4 * channels;
			b += 4;
		} while (n -= 4);

		while (bufpos_ < end) {
			unsigned long const out4 = buf_[bufpos_] - prv4;
			prv4 = buf_[bufpos_];
			bufpos_ += div_;

			unsigned long const out3 = out4 - prv3;
			prv3 = out4;
			unsigned long const out2 = out3 - prv2;
			prv2 = out3;

			*out = rshift16_round(static_cast<long>(out2 - prv1) * mul);
			prv1 = out2;
			out += channels;
		}

		bufpos_ -= end;
		inlen -= end;
	}

	if (inlen) {
		unsigned n = inlen;
		unsigned i = 0;

		do {
			sm1 += static_cast<long>(*s);
			s += channels;
			sm2 += sm1;
			sm3 += sm2;
			buf_[i++] = sm4 += sm3;
		} while (--n);

		while (bufpos_ < inlen) {
			unsigned long const out4 = buf_[bufpos_] - prv4;
			prv4 = buf_[bufpos_];
			bufpos_ += div_;

			unsigned long const out3 = out4 - prv3;
			prv3 = out4;
			unsigned long const out2 = out3 - prv2;
			prv2 = out3;

			*out = rshift16_round(static_cast<long>(out2 - prv1) * mul);
			prv1 = out2;
			out += channels;
		}

		bufpos_ -= inlen;
	}

	sum1_ = sm1;
	sum2_ = sm2;
	sum3_ = sm3;
	sum4_ = sm4;
	prev1_ = prv1;
	prev2_ = prv2;
	prev3_ = prv3;
	prev4_ = prv4;

	return produced;
}

template<unsigned channels>
class Cic4 : public SubResampler {
public:
	enum { MAX_DIV = 13 };
	explicit Cic4(unsigned div);
	virtual std::size_t resample(short *out, short const *in, std::size_t inlen);
	virtual unsigned mul() const { return 1; }
	virtual unsigned div() const { return cics_[0].div(); }
	static double gain(unsigned div) { return Cic4Core<channels>::gain(div); }

private:
	Cic4Core<channels> cics_[channels];
};

template<unsigned channels>
Cic4<channels>::Cic4(unsigned div) {
	for (unsigned i = 0; i < channels; ++i)
		cics_[i].reset(div);
}

template<unsigned channels>
std::size_t Cic4<channels>::resample(short *out, short const *in, std::size_t inlen) {
	std::size_t samplesOut;
	for (unsigned i = 0; i < channels; ++i)
		samplesOut = cics_[i].filter(out + i, in + i, inlen);

	return samplesOut;
}

#endif
