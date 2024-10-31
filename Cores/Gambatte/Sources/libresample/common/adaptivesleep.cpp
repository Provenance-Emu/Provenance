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
#include "adaptivesleep.h"

static usec_t absdiff(usec_t a, usec_t b) { return a < b ? b - a : a - b; }

usec_t AdaptiveSleep::sleepUntil(usec_t base, usec_t inc) {
	usec_t now = getusecs();
	usec_t diff = now - base;
	if (diff >= inc)
		return diff - inc;

	diff = inc - diff;
	if (diff > oversleep_ + oversleepVar_) {
		diff -= oversleep_ + oversleepVar_;
		usecsleep(diff);
		usec_t const sleepTarget = now + diff;
		now = getusecs();

		usec_t curOversleep = now - sleepTarget;
		if (curOversleep > usec_t(-1) / 2)
			curOversleep = 0;

		oversleepVar_ = (oversleepVar_ * 15 + absdiff(curOversleep, oversleep_) + 8) >> 4;
		oversleep_ = (oversleep_ * 15 + curOversleep + 8) >> 4;
		noSleep_ = 60;
	} else if (--noSleep_ == 0) {
		noSleep_ = 60;
		oversleep_ = oversleepVar_ = 0;
	}

	while (now - base < inc)
		now = getusecs();

	return 0;
}
