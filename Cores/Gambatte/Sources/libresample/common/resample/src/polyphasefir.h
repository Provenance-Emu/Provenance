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
#ifndef POLYPHASEFIR_H
#define POLYPHASEFIR_H

#include "array.h"
#include "rshift16_round.h"
#include <algorithm>
#include <cstring>

template<int channels, unsigned phases>
class PolyphaseFir {
public:
	PolyphaseFir(short const *kernel, std::size_t phaseLen, unsigned div);
	std::size_t filter(short *out, short const *in, std::size_t inlen);
	void adjustDiv(unsigned div) { div_ = div; }
	unsigned div() const { return div_; }

private:
	short const *const kernel_;
	Array<short> const prevbuf_;
	unsigned div_;
	std::size_t x_;
};

template<int channels, unsigned phases>
PolyphaseFir<channels, phases>::PolyphaseFir(short const *kernel,
                                             std::size_t phaseLen,
                                             unsigned div)
: kernel_(kernel)
, prevbuf_(phaseLen * channels)
, div_(div)
, x_(0)
{
	std::fill(prevbuf_.get(), prevbuf_.get() + prevbuf_.size(), 0);
}

template<int channels, unsigned phases>
std::size_t PolyphaseFir<channels, phases>::filter(short *out,
                                                   short const *const in,
                                                   std::size_t inlen)
{
	if (!kernel_ || !inlen)
		return 0;

	// The gist of what happens here is given by the commented pseudo-code below.
	// Note that the order of the kernel elements has been changed for efficiency in
	// the real implementation.
	/*for (std::size_t x = 0; x < inlen + M; ++x) {
		int const end = x < inlen ? M + 1 : inlen + M - x;
		int j = x < M ? M - x : 0;
		// adjust j so we do not start on a virtual 0 sample
		j += (phases - (x - M + j) % phases) % phases;

		for (; j < end; j += phases) {
			buffer[x] += kernel_[j] * start[(x - M + j) / phases];
		}
	}*/

	// Slightly more optimized version.
	/*for (std::size_t x = 0; x < inlen + M; ++x) {
		int const end = x < inlen ? M + 1 : inlen + M - x;
		int j = x < M ? M - x : 0;
		// adjust j so we do not start on a virtual 0 sample
		j += (phases - (x - M + j) % phases) % phases;
		short const *k = kernel_ + (j % phases) * phaseLen + j / phases;
		short const *s = start + (x - M + j) / phases;
		int n = ((end - j) + phases - 1) / phases;

		do {
			buffer[x] += *k++ * *s++;
		} while (--n);
	}*/

	std::size_t const phaseLen = prevbuf_.size() / channels;
	std::size_t const M = phaseLen * phases - 1;
	inlen *= phases;
	std::size_t x = x_;

	for (; x < (M < inlen ? M : inlen); x += div_) {
		for (int c = 0; c < channels; ++c) {
			// adjust phase so we do not start on a virtual 0 sample
			short const *k = kernel_ + ((x + 1) % phases) * phaseLen;
			short const *s = prevbuf_ + phaseLen * channels + c;
			long acc = 0;
			std::size_t n = phaseLen * channels - (x / phases + 1) * channels;

			for (; n; n -= channels)
				acc += *k++ * *(s-n);

			n = (x / phases + 1) * channels;
			s = in + n + c;

			do {
				acc += *k++ * *(s-n);
			} while (n -= channels);

			*out++ = rshift16_round(acc);
		}
	}

	// We could easily get rid of the division and modulus here by updating the
	// k and s pointers incrementally. However, we currently only use powers of 2
	// and we would end up referencing more variables which often compiles to bad
	// code on x86, which is why I'm also hesitant to get rid of the template arguments.
	for (; x < inlen; x += div_) {
		for (int c = 0; c < channels-1; c += 2) {
			// adjust phase so we do not start on a virtual 0 sample
			short const *k = kernel_ + ((x + 1) % phases) * phaseLen;
			short const *const s = in + (x / phases + 1) * channels + c;
			long accl = 0, accr = 0;
			std::ptrdiff_t i = -static_cast<std::ptrdiff_t>(phaseLen * channels);
			do {
				accl += *k * s[i  ];
				accr += *k * s[i+1];
				++k;
			} while (i += channels);

			out[0] = rshift16_round(accl);
			out[1] = rshift16_round(accr);
			out += 2;
		}

		if (channels & 1) {
			// adjust phase so we do not start on a virtual 0 sample
			short const *k = kernel_ + ((x + 1) % phases) * phaseLen;
			short const *const s = in + (x / phases + 1) * channels + channels-1;
			long acc = 0;
			std::ptrdiff_t i = -static_cast<std::ptrdiff_t>(phaseLen * channels);
			do {
				acc += *k++ * s[i];
			} while (i += channels);

			*out++ = rshift16_round(acc);
		}
	}

	std::size_t const produced = (x - x_) / div_;
	x_ = x - inlen;
	inlen /= phases;

	{
		short *p = prevbuf_;
		short const *s = in + (inlen - phaseLen) * channels;
		std::size_t n = phaseLen;
		if (inlen < phaseLen) {
			std::size_t const i = phaseLen - inlen;
			std::memmove(p, p + inlen * channels, i * channels * sizeof *p);
			p += i * channels;
			n -= i;
			s = in;
		}

		std::memcpy(p, s, n * channels * sizeof *p);
	}

	return produced;
}

#endif
