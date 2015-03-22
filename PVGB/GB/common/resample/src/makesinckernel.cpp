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
#include "makesinckernel.h"
#include "array.h"
#include <cmath>

void makeSincKernel(short *const kernel, int const phases, int const phaseLen, double fc,
                    double (*const win)(long m, long M), double const maxAllowedGain)
{
	double const PI = 3.14159265358979323846;
	fc /= phases;

	/*{
		Array<double> const dkernel(phaseLen * phases);
		long const M = long(phaseLen) * phases - 1;
		for (long i = 0; i < M + 1; ++i) {
			double sinc = i * 2 == M
			            ? PI * fc
			            : std::sin(PI * fc * (i * 2 - M)) / (i * 2 - M);
			std::size_t pos = std::size_t((phases - (i % phases)) % phases) * phaseLen
			                  + i / phases;
			dkernel[pos] = win(i, M) * sinc;
		}

		double maxabsgain = 0;
		for (int ph = 0; ph < phases; ++ph) {
			double gain = 0;
			double absgain = 0;
			for (int i = 0; i < phaseLen; ++i) {
				gain += dkernel[std::size_t(ph) * phaseLen + i];
				absgain += std::abs(dkernel[std::size_t(ph) * phaseLen + i]);
			}

			gain = 1.0 / gain;
			// Per phase normalization to avoid DC fluctuations.
			for (int i = 0; i < phaseLen; ++i)
				dkernel[std::size_t(ph) * phaseLen + i] *= gain;

			absgain *= gain;
			if (absgain > maxabsgain)
				maxabsgain = absgain;
		}

		double gain = (0x10000 - 0.5 * phaseLen) * maxAllowedGain / maxabsgain;
		for (long i = 0; i < M + 1; ++i)
			kernel[i] = std::floor(dkernel[i] * gain + 0.5);
	}*/

	// The following should be equivalent to the more concise version above
	// Some polyphase FIRs used are huge enough that this seemed worthwile.
	long const M = long(phaseLen) * phases - 1;
	Array<double> const dkernel(M / 2 + 1);

	{
		double *dk = dkernel;
		for (int ph = 0; ph < phases; ++ph) {
			for (long i = ph; i < M / 2 + 1; i += phases) {
				double sinc = i * 2 == M
				            ? PI * fc
				            : std::sin(PI * fc * (i * 2 - M)) / (i * 2 - M);
				*dk++ = win(i, M) * sinc;
			}
		}
	}

	double maxabsgain = 0.0;

	{
		double *dkp1 = dkernel;
		double *dkp2 = dkernel + M / 2;
		for (int ph = 0; ph < (phases + 1) / 2; ++ph) {
			double gain = 0.0;
			double absgain = 0.0;

			{
				double const *kp1 = dkp1;
				double const *kp2 = dkp2;
				long i = ph;
				for (; i < M / 2 + 1; i += phases) {
					gain += *kp1;
					absgain += std::abs(*kp1++);
				}
				for (; i < M + 1; i += phases) {
					gain += *kp2;
					absgain += std::abs(*kp2--);
				}
			}

			gain = 1.0 / gain;

			long i = ph;
			for (; i < M / 2 + 1; i += phases)
				*dkp1++ *= gain;

			if (dkp1 < dkp2) {
				for (; i < M + 1; i += phases)
					*dkp2-- *= gain;
			}

			absgain *= gain;
			if (absgain > maxabsgain)
				maxabsgain = absgain;
		}
	}

	double const gain = (0x10000 - 0.5 * phaseLen) * maxAllowedGain / maxabsgain;
	double const *dk = dkernel;
	for (int ph = 0; ph < phases; ++ph) {
		short *k = kernel + std::size_t((phases - ph) % phases) * phaseLen;
		short *km = kernel + phaseLen - 1 + std::size_t((ph + 1) % phases) * phaseLen;
		for (long i = ph; i < M / 2 + 1; i += phases)
			*km-- = *k++ = static_cast<short>(std::floor(*dk++ * gain + 0.5));
	}
}
