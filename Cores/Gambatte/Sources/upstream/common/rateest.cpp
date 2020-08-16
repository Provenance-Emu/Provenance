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
#include "rateest.h"
#include <cstdlib>

void RateEst::SumQueue::push(std::ptrdiff_t const samples, usec_t const usecs) {
	q_.push_back(std::make_pair(samples, usecs));
	samples_ += samples;
	usecs_ += usecs;
}

void RateEst::SumQueue::pop() {
	std::pair<std::ptrdiff_t, usec_t> const &f = q_.front();
	samples_ -= f.first;
	usecs_ -= f.second;
	q_.pop_front();
}

static usec_t sampleUsecs(std::ptrdiff_t samples, long rate) {
	return usec_t((samples * 1000000.0f) / (rate ? rate : 1) + 0.5f);
}

static long limit(long est, long const reference) {
	if (est > reference + (reference >> 6))
		est = reference + (reference >> 6);
	else if (est < reference - (reference >> 6))
		est = reference - (reference >> 6);

	return est;
}

RateEst::RateEst(long const nominalSampleRate, std::size_t const maxValidFeedPeriodSamples)
: srate_(nominalSampleRate * est_scale)
, reference_(srate_)
, maxPeriod_(sampleUsecs(maxValidFeedPeriodSamples, nominalSampleRate))
, last_(0)
, t_(6000)
, s_(nominalSampleRate * 6)
, st_(s_ * t_)
, t2_(t_ * t_)
{
}

void RateEst::feed(std::ptrdiff_t samplesIn, usec_t const now) {
	usec_t usecsIn = now - last_;

	if (last_ && usecsIn < maxPeriod_) {
		sumq_.push(samplesIn, usecsIn);

		while ((usecsIn = sumq_.usecs()) > 100000) {
			samplesIn = sumq_.samples();
			sumq_.pop();

			long const srateIn = long(samplesIn * (1000000.0f * est_scale) / usecsIn);
			if (std::abs(srateIn - reference_) < reference_ >> 1) {
				s_ +=  samplesIn - sumq_.samples()         ;
				t_ += (  usecsIn - sumq_.usecs()  ) * 0.001;
				st_ += s_ * t_;
				t2_ += t_ * t_;

				long est = long(st_ * (1000.0 * est_scale) / t2_ + 0.5);
				srate_ = limit((srate_ * 31 + est + 16) >> 5, reference_);

				if (t_ > 8000) {
					s_ *= 3.0 / 4;
					t_ *= 3.0 / 4;
					st_ *= 9.0 / 16;
					t2_ *= 9.0 / 16;
				}
			}
		}
	}

	last_ = now;
}
