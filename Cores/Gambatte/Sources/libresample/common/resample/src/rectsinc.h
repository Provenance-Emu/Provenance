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
#ifndef RECTSINC_H
#define RECTSINC_H

#include "array.h"
#include "cic2.h"
#include "makesinckernel.h"
#include "polyphasefir.h"
#include "subresampler.h"
#include <algorithm>
#include <cmath>
#include <cstddef>

template<unsigned channels, unsigned phases>
class RectSinc : public SubResampler {
public:
	enum { MUL = phases };
	typedef Cic2<channels> Cic;
	static float cicLimit() { return 2.0f; }

	class RollOff {
	public:
		unsigned const taps;
		float const fc;

		RollOff(float rollOffStart, float rollOffWidth)
		: taps(toTaps(rollOffWidth)), fc(toFc(rollOffStart, taps)) 
		{
		}

	private:
		static unsigned toTaps(float rollOffWidth) {
			float widthTimesTaps = 0.9f;
			return std::max(unsigned(std::ceil(widthTimesTaps / rollOffWidth)), 4u);
		}

		static float toFc(float rollOffStart, int taps) {
			float startToFcDeltaTimesTaps = 0.43f;
			return startToFcDeltaTimesTaps / taps + rollOffStart;
		}
	};

	RectSinc(unsigned div, unsigned phaseLen, double fc)
	: kernel_(phaseLen * phases)
	, polyfir_(kernel_, phaseLen, div)
	{
		makeSincKernel(kernel_, phases, phaseLen, fc, rectWin, 1.0);
	}

	RectSinc(unsigned div, RollOff ro, double gain)
	: kernel_(ro.taps * phases)
	, polyfir_(kernel_, ro.taps, div)
	{
		makeSincKernel(kernel_, phases, ro.taps, ro.fc, rectWin, gain);
	}

	virtual std::size_t resample(short *out, short const *in, std::size_t inlen) {
		return polyfir_.filter(out, in, inlen);
	}

	virtual void adjustDiv(unsigned div) { polyfir_.adjustDiv(div); }
	virtual unsigned mul() const { return MUL; }
	virtual unsigned div() const { return polyfir_.div(); }

private:
	Array<short> const kernel_;
	PolyphaseFir<channels, phases> polyfir_;

	static double rectWin(long /*i*/, long /*M*/) { return 1; }
};

#endif
