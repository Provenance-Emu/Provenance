/***************************************************************************
 *   Copyright (C) 2008-2009 by Sindre Aamås                               *
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
#ifndef KAISER70SINC_H
#define KAISER70SINC_H

#include "array.h"
#include "cic4.h"
#include "makesinckernel.h"
#include "polyphasefir.h"
#include "subresampler.h"
#include <algorithm>
#include <cmath>
#include <cstddef>

double kaiser70SincWin(long n, long M);

template<unsigned channels, unsigned phases>
class Kaiser70Sinc : public SubResampler {
public:
	enum { MUL = phases };
	typedef Cic4<channels> Cic;
	static float cicLimit() { return 4.7f; }

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
			float widthTimesTaps = 3.75f;
			return std::max(unsigned(std::ceil(widthTimesTaps / rollOffWidth)), 4u);
		}

		static float toFc(float rollOffStart, int taps) {
			float startToFcDeltaTimesTaps = 1.5f;
			return startToFcDeltaTimesTaps / taps + rollOffStart;
		}
	};

	Kaiser70Sinc(unsigned div, unsigned phaseLen, double fc)
	: kernel_(phaseLen * phases)
	, polyfir_(kernel_, phaseLen, div)
	{
		makeSincKernel(kernel_, phases, phaseLen, fc, kaiser70SincWin, 1.0);
	}

	Kaiser70Sinc(unsigned div, RollOff ro, double gain)
	: kernel_(ro.taps * phases)
	, polyfir_(kernel_, ro.taps, div)
	{
		makeSincKernel(kernel_, phases, ro.taps, ro.fc, kaiser70SincWin, gain);
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
};

#endif
