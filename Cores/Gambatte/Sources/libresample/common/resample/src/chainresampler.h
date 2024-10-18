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
#ifndef CHAINRESAMPLER_H
#define CHAINRESAMPLER_H

#include "../resampler.h"
#include "../resamplerinfo.h"
#include "array.h"
#include "transfer_ptr.h"
#include "upsampler.h"
#include <algorithm>
#include <list>

class SubResampler;

class ChainResampler : public Resampler {
public:
	enum { channels = ResamplerInfo::channels };

	template<template<unsigned, unsigned> class Sinc>
	static Resampler * create(long inRate, long outRate, std::size_t periodSize);

	virtual ~ChainResampler();
	virtual void adjustRate(long inRate, long outRate);
	virtual void exactRatio(unsigned long &mul, unsigned long &div) const;
	virtual std::size_t maxOut(std::size_t /*inlen*/) const { return maxOut_; }
	virtual std::size_t resample(short *out, short const *in, std::size_t inlen);

private:
	typedef std::list<SubResampler *> List;
	typedef SubResampler * (*CreateSinc)(unsigned div, float rollOffStart,
	                                     float rollOffWidth, double gain);
	enum { big_sinc_mul   = 2048 };
	enum { small_sinc_mul =   32 };

	List list_;
	SubResampler *bigSinc_;
	Array<short> buffer_;
	short *buffer2_;
	std::size_t const periodSize_;
	std::size_t maxOut_;

	ChainResampler(long inRate, long outRate, std::size_t periodSize);
	void downinitAddSincResamplers(double ratio, float outRate,
	                               CreateSinc createBigSinc,
	                               CreateSinc createSmallSinc,
	                               double gain);
	void upinit(long inRate, long outRate, CreateSinc);
	void reallocateBuffer();

	template<class Sinc>
	static SubResampler * createSinc(unsigned div,
			float rollOffStart, float rollOffWidth, double gain) {
		return new Sinc(div, typename Sinc::RollOff(rollOffStart, rollOffWidth), gain);
	}

	template<template<unsigned, unsigned> class Sinc>
	void downinit(long inRate, long outRate);
};

template<template<unsigned, unsigned> class Sinc>
Resampler * ChainResampler::create(long inRate, long outRate, std::size_t periodSize) {
	transfer_ptr<ChainResampler> r(new ChainResampler(inRate, outRate, periodSize));
	if (outRate > inRate) {
		r->upinit(inRate, outRate,
		          createSinc< Sinc<channels, big_sinc_mul> >);
	} else
		r->downinit<Sinc>(inRate, outRate);

	return r.release();
}

template<template<unsigned, unsigned> class Sinc>
void ChainResampler::downinit(long const inRate,
                              long const outRate) {
	typedef Sinc<channels,   big_sinc_mul> BigSinc;
	typedef Sinc<channels, small_sinc_mul> SmallSinc;

	double ratio = static_cast<double>(inRate) / outRate;
	double gain = 1.0;
	while (ratio >= BigSinc::cicLimit() * 2) {
		int const div = std::min<int>(int(ratio / BigSinc::cicLimit()),
		                              BigSinc::Cic::MAX_DIV);
		list_.push_back(new typename BigSinc::Cic(div));
		ratio /= div;
		gain *= 1.0 / BigSinc::Cic::gain(div);
	}

	downinitAddSincResamplers(ratio, outRate,
	                          createSinc<BigSinc>, createSinc<SmallSinc>,
	                          gain);
	reallocateBuffer();
}

#endif
