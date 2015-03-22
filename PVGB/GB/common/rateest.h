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
#ifndef RATEEST_H
#define RATEEST_H

#include "usec.h"
#include <cstddef>
#include <deque>
#include <utility>

class RateEst {
public:
	RateEst() { *this = RateEst(0, 0); }
	RateEst(long nominalSampleRate, std::size_t maxValidFeedPeriodSamples);
	void resetLastFeedTimeStamp() { last_ = 0; }
	void feed(std::ptrdiff_t samples, usec_t usecsNow = getusecs());
	long result() const { return (srate_ + est_scale / 2) >> est_lshift; }

private:
	class SumQueue {
	public:
		SumQueue() : samples_(0), usecs_(0) {}
		std::ptrdiff_t samples() const { return samples_; }
		usec_t usecs() const { return usecs_; }
		void push(std::ptrdiff_t samples, usec_t usecs);
		void pop();

	private:
		std::deque< std::pair<std::ptrdiff_t, usec_t> > q_;
		std::ptrdiff_t samples_;
		usec_t usecs_;
	};

	enum { est_lshift = 5 };
	enum { est_scale = 1 << est_lshift };

	SumQueue sumq_;
	long srate_;
	long reference_;
	usec_t maxPeriod_;
	usec_t last_;
	double t_, s_, st_, t2_;
};

#endif
