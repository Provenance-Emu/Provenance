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
#include "u48div.h"
#include <algorithm>

unsigned long u48div(unsigned long num1, unsigned num2, unsigned long const den) {
	unsigned long res = 0;
	unsigned s = 16;

	do {
		if (num1 < 0x10000) {
			num1 <<= s;
			num1 |= num2 & ((1 << s) - 1);
			s = 0;
		} else {
			if (num1 < 0x1000000) {
				unsigned const maxs = std::min(s, 8u);
				num1 <<= maxs;
				num1 |= (num2 >> (s - maxs)) & ((1 << maxs) - 1);
				s -= maxs;
			}
			if (num1 < 0x10000000) {
				unsigned const maxs = std::min(s, 4u);
				num1 <<= maxs;
				num1 |= (num2 >> (s - maxs)) & ((1 << maxs) - 1);
				s -= maxs;
			}

			while (num1 < den && s) {
				num1 <<= 1; // if this overflows we're screwed
				num1 |= num2 >> (s - 1) & 1;
				s -= 1;
			}
		}

		res += (num1 / den) << s;
		num1 = (num1 % den);
	} while (s);

	return res;
}
