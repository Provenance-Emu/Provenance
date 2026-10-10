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
#include "chainresampler.h"
#include <cassert>
#include <cmath>

static float get1ChainCost(float ratio, float finalRollOffLen) {
	return ratio / finalRollOffLen;
}

static float get2ChainMidRatio(float ratio, float finalRollOffLen, float midRollOffStartPlusEnd) {
	return 0.5f * (   std::sqrt(ratio * midRollOffStartPlusEnd * finalRollOffLen)
	                + midRollOffStartPlusEnd);
}

static float get2ChainCost(float ratio, float finalRollOffLen, float midRatio,
                           float midRollOffStartPlusEnd)
{
	float midRollOffLen = midRatio * 2 - midRollOffStartPlusEnd;
	return midRatio * ratio / midRollOffLen
	     + get1ChainCost(midRatio, finalRollOffLen);
}

static float get3ChainRatio2(float ratio1,
                             float finalRollOffLen,
                             float midRollOffStartPlusEnd) {
	return get2ChainMidRatio(ratio1, finalRollOffLen, midRollOffStartPlusEnd);
}

static float get3ChainRatio1(float ratio1, float const finalRollOffLen, float const ratio,
                             float const midRollOffStartPlusEnd)
{
	for (int n = 8; n--;) {
		float ratio2 = get3ChainRatio2(ratio1, finalRollOffLen, midRollOffStartPlusEnd);
		ratio1 = (   std::sqrt(ratio * midRollOffStartPlusEnd * (2 - midRollOffStartPlusEnd / ratio2))
		           + midRollOffStartPlusEnd) * 0.5f;
	}

	return ratio1;
}

static float get3ChainCost(float ratio, float finalRollOffLen,
                           float ratio1, float ratio2, float midRollOffStartPlusEnd)
{
	float firstRollOffLen = ratio1 * 2 - midRollOffStartPlusEnd;
	return ratio1 * ratio / firstRollOffLen
	     + get2ChainCost(ratio1, finalRollOffLen, ratio2, midRollOffStartPlusEnd);
}

ChainResampler::ChainResampler(long inRate, long outRate, std::size_t periodSize)
: Resampler(inRate, outRate)
, bigSinc_(0)
, buffer2_(0)
, periodSize_(periodSize)
, maxOut_(0)
{
}

void ChainResampler::downinitAddSincResamplers(double ratio,
                                               float const outRate,
                                               CreateSinc const createBigSinc,
                                               CreateSinc const createSmallSinc,
                                               double gain)
{
	// For high outRate: Start roll-off at 36 kHz continue until outRate Hz,
	// then wrap around back down to 40 kHz.
	float const outPeriod = 1.0f / outRate;
	float const finalRollOffLen =
		std::max((outRate - 36000.0f + outRate - 40000.0f) * outPeriod,
		         0.2f);
	{
		float const midRollOffStart = std::min(36000.0f * outPeriod, 1.0f);
		float const midRollOffEnd   = std::min(40000.0f * outPeriod, 1.0f); // after wrap at folding freq.
		float const midRollOffStartPlusEnd = midRollOffStart + midRollOffEnd;
		float const ideal2ChainMidRatio = get2ChainMidRatio(ratio, finalRollOffLen,
		                                                    midRollOffStartPlusEnd);
		int div_2c = int(ratio * small_sinc_mul / ideal2ChainMidRatio + 0.5f);
		double ratio_2c = ratio * small_sinc_mul / div_2c;
		float cost_2c = get2ChainCost(ratio, finalRollOffLen, ratio_2c, midRollOffStartPlusEnd);
		if (cost_2c < get1ChainCost(ratio, finalRollOffLen)) {
			float const ideal3ChainRatio1 = get3ChainRatio1(ratio_2c, finalRollOffLen,
			                                                ratio, midRollOffStartPlusEnd);
			int const div1_3c = int(ratio * small_sinc_mul / ideal3ChainRatio1 + 0.5f);
			double const ratio1_3c = ratio * small_sinc_mul / div1_3c;
			float const ideal3ChainRatio2 = get3ChainRatio2(ratio1_3c, finalRollOffLen,
			                                                midRollOffStartPlusEnd);
			int const div2_3c = int(ratio1_3c * small_sinc_mul / ideal3ChainRatio2 + 0.5f);
			double const ratio2_3c = ratio1_3c * small_sinc_mul / div2_3c;
			if (get3ChainCost(ratio, finalRollOffLen, ratio1_3c,
			                  ratio2_3c, midRollOffStartPlusEnd) < cost_2c) {
				list_.push_back(createSmallSinc(div1_3c,
				                                0.5f * midRollOffStart / ratio,
				                                (ratio1_3c - 0.5f * midRollOffStartPlusEnd) / ratio,
				                                gain));
				ratio = ratio1_3c;
				div_2c = div2_3c;
				ratio_2c = ratio2_3c;
				gain = 1.0;
			}

			list_.push_back(createSmallSinc(div_2c,
			                                0.5f * midRollOffStart / ratio,
			                                (ratio_2c - 0.5f * midRollOffStartPlusEnd) / ratio,
			                                gain));
			ratio = ratio_2c;
			gain = 1.0;
		}
	}

	float rollOffStart = 0.5f * (1.0f
	                             + std::max((outRate - 40000.0f) * outPeriod, 0.0f)
	                             - finalRollOffLen) / ratio;
	bigSinc_ = createBigSinc(static_cast<int>(big_sinc_mul * ratio + 0.5),
	                         rollOffStart,
	                         0.5f * finalRollOffLen / ratio,
	                         gain);
	list_.push_back(bigSinc_);
}

void ChainResampler::upinit(long const inRate,
                            long const outRate,
                            CreateSinc const createSinc) {
	double ratio = static_cast<double>(outRate) / inRate;
	// Spectral images above 20 kHz assumed inaudible
	// this post-polyphase zero stuffing causes some power loss though.
	{
		int const div = outRate / std::max(inRate, 40000l);
		if (div >= 2) {
			list_.push_front(new Upsampler<channels>(div));
			ratio /= div;
		}
	}

	float const rollOffLen = std::max((inRate - 36000.0f) / inRate, 0.2f);
	bigSinc_ = createSinc(static_cast<int>(big_sinc_mul / ratio + 0.5),
	                      0.5f * (1 - rollOffLen),
	                      0.5f * rollOffLen,
	                      1.0);
	list_.push_front(bigSinc_); // note: inserted at the front
	reallocateBuffer();
}

void ChainResampler::reallocateBuffer() {
	std::size_t bufSize[2] = { 0, 0 };
	std::size_t inSize = periodSize_;
	int i = -1;
	for (List::iterator it = list_.begin(); it != list_.end(); ++it) {
		inSize = (inSize * (*it)->mul() - 1) / (*it)->div() + 1;
		++i;
		if (inSize > bufSize[i & 1])
			bufSize[i & 1] = inSize;
	}

	if (inSize >= bufSize[i & 1])
		bufSize[i & 1] = 0;

	if (buffer_.size() < (bufSize[0] + bufSize[1]) * channels)
		buffer_.reset((bufSize[0] + bufSize[1]) * channels);

	buffer2_ = bufSize[1] ? buffer_ + bufSize[0] * channels : 0;
	maxOut_ = inSize;
}

void ChainResampler::adjustRate(long const inRate, long const outRate) {
	unsigned long mul, div;
	exactRatio(mul, div);

	double newDiv =  double( inRate) *  mul
	              / (double(outRate) * (div / bigSinc_->div()));
	bigSinc_->adjustDiv(int(newDiv + 0.5));
	reallocateBuffer();
	setRate(inRate, outRate);
}

void ChainResampler::exactRatio(unsigned long &mul, unsigned long &div) const {
	mul = 1;
	div = 1;
	for (List::const_iterator it = list_.begin(); it != list_.end(); ++it) {
		mul *= (*it)->mul();
		div *= (*it)->div();
	}
}

std::size_t ChainResampler::resample(short *const out, short const *const in, std::size_t inlen) {
	assert(inlen <= periodSize_);
	short *const buf = buffer_ != buffer2_ ? buffer_ : out;
	short *const buf2 = buffer2_ ? buffer2_ : out;
	short const *inbuf = in;
	short *outbuf = 0;
	for (List::iterator it = list_.begin(); it != list_.end(); ++it) {
		outbuf = ++List::iterator(it) == list_.end()
		       ? out
		       : (inbuf == buf ? buf2 : buf);
		inlen = (*it)->resample(outbuf, inbuf, inlen);
		inbuf = outbuf;
	}

	return inlen;
}

ChainResampler::~ChainResampler() {
	std::for_each(list_.begin(), list_.end(), defined_delete<SubResampler>);
}
