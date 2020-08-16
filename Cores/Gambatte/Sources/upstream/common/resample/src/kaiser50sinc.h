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
#ifndef KAISER50SINC_H
#define KAISER50SINC_H

#include "array.h"
#include "cic3.h"
#include "makesinckernel.h"
#include "polyphasefir.h"
#include "subresampler.h"
#include <algorithm>
#include <cmath>
#include <cstddef>

double kaiser50SincWin(long n, long M);

template<unsigned channels, unsigned phases>
class Kaiser50Sinc : public SubResampler {
public:
	enum { MUL = phases };
	typedef Cic3<channels> Cic;
	static float cicLimit() { return 4.2f; }

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
			float widthTimesTaps = 2.715f;
			return std::max(unsigned(std::ceil(widthTimesTaps / rollOffWidth)), 4u);
		}

		static float toFc(float rollOffStart, int taps) {
			float startToFcDeltaTimesTaps = 1.2f;
			return startToFcDeltaTimesTaps / taps + rollOffStart;
		}
	};

	Kaiser50Sinc(unsigned div, unsigned phaseLen, double fc)
	: kernel_(phaseLen * phases)
	, polyfir_(kernel_, phaseLen, div)
	{
		makeSincKernel(kernel_, phases, phaseLen, fc, kaiser50SincWin, 1.0);
	}

	Kaiser50Sinc(unsigned div, RollOff ro, double gain)
	: kernel_(ro.taps * phases)
	, polyfir_(kernel_, ro.taps, div)
	{
		makeSincKernel(kernel_, phases, ro.taps, ro.fc, kaiser50SincWin, gain);
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
