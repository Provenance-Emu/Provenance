//
//   Copyright (C) 2007 by sinamas <sinamas at users.sourceforge.net>
//
//   This program is free software; you can redistribute it and/or modify
//   it under the terms of the GNU General Public License version 2 as
//   published by the Free Software Foundation.
//
//   This program is distributed in the hope that it will be useful,
//   but WITHOUT ANY WARRANTY; without even the implied warranty of
//   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//   GNU General Public License version 2 for more details.
//
//   You should have received a copy of the GNU General Public License
//   version 2 along with this program; if not, write to the
//   Free Software Foundation, Inc.,
//   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
//

#include "tima.h"
#include "savestate.h"

static unsigned char const timaClock[4] = { 10, 4, 6, 8 };

namespace gambatte {

Tima::Tima()
: lastUpdate_(0)
, tmatime_(disabled_time)
, tima_(0)
, tma_(0)
, tac_(0)
{
}

void Tima::saveState(SaveState &state) const {
	state.mem.timaLastUpdate = lastUpdate_;
	state.mem.tmatime = tmatime_;
}

void Tima::loadState(SaveState const &state, TimaInterruptRequester timaIrq) {
	lastUpdate_ = state.mem.timaLastUpdate;
	tmatime_ = state.mem.tmatime;
	tima_ = state.mem.ioamhram.get()[0x105];
	tma_  = state.mem.ioamhram.get()[0x106];
	tac_  = state.mem.ioamhram.get()[0x107];

	unsigned long nextIrqEventTime = disabled_time;
	if (tac_ & 4) {
		nextIrqEventTime = tmatime_ != disabled_time && tmatime_ > state.cpu.cycleCounter
		                 ? tmatime_
		                 : lastUpdate_ + ((256u - tima_) << timaClock[tac_ & 3]) + 3;
	}

	timaIrq.setNextIrqEventTime(nextIrqEventTime);
}

void Tima::resetCc(unsigned long const oldCc, unsigned long const newCc, TimaInterruptRequester timaIrq) {
	if (tac_ & 0x04) {
		updateIrq(oldCc, timaIrq);
		updateTima(oldCc);

		unsigned long const dec = oldCc - newCc;
		lastUpdate_ -= dec;
		timaIrq.setNextIrqEventTime(timaIrq.nextIrqEventTime() - dec);

		if (tmatime_ != disabled_time)
			tmatime_ -= dec;
	}
}

void Tima::updateTima(unsigned long const cc) {
	unsigned long const ticks = (cc - lastUpdate_) >> timaClock[tac_ & 3];
	lastUpdate_ += ticks << timaClock[tac_ & 3];

	if (cc >= tmatime_) {
		if (cc >= tmatime_ + 4)
			tmatime_ = disabled_time;

		tima_ = tma_;
	}

	unsigned long tmp = tima_ + ticks;
	while (tmp > 0x100)
		tmp -= 0x100 - tma_;

	if (tmp == 0x100) {
		tmp = 0;
		tmatime_ = lastUpdate_ + 3;

		if (cc >= tmatime_) {
			if (cc >= tmatime_ + 4)
				tmatime_ = disabled_time;

			tmp = tma_;
		}
	}

	tima_ = tmp;
}

void Tima::setTima(unsigned const data, unsigned long const cc, TimaInterruptRequester timaIrq) {
	if (tac_ & 0x04) {
		updateIrq(cc, timaIrq);
		updateTima(cc);

		if (tmatime_ - cc < 4)
			tmatime_ = disabled_time;

		timaIrq.setNextIrqEventTime(lastUpdate_ + ((256u - data) << timaClock[tac_ & 3]) + 3);
	}

	tima_ = data;
}

void Tima::setTma(unsigned const data, unsigned long const cc, TimaInterruptRequester timaIrq) {
	if (tac_ & 0x04) {
		updateIrq(cc, timaIrq);
		updateTima(cc);
	}

	tma_ = data;
}

void Tima::setTac(unsigned const data, unsigned long const cc, TimaInterruptRequester timaIrq) {
	if (tac_ ^ data) {
		unsigned long nextIrqEventTime = timaIrq.nextIrqEventTime();

		if (tac_ & 0x04) {
			updateIrq(cc, timaIrq);
			updateTima(cc);

			lastUpdate_ -= (1u << (timaClock[tac_ & 3] - 1)) + 3;
			tmatime_ -= (1u << (timaClock[tac_ & 3] - 1)) + 3;
			nextIrqEventTime -= (1u << (timaClock[tac_ & 3] - 1)) + 3;

			if (cc >= nextIrqEventTime)
				timaIrq.flagIrq();

			updateTima(cc);

			tmatime_ = disabled_time;
			nextIrqEventTime = disabled_time;
		}

		if (data & 4) {
			lastUpdate_ = (cc >> timaClock[data & 3]) << timaClock[data & 3];
			nextIrqEventTime = lastUpdate_ + ((256u - tima_) << timaClock[data & 3]) + 3;
		}

		timaIrq.setNextIrqEventTime(nextIrqEventTime);
	}

	tac_ = data;
}

unsigned Tima::tima(unsigned long cc) {
	if (tac_ & 0x04)
		updateTima(cc);

	return tima_;
}

void Tima::doIrqEvent(TimaInterruptRequester timaIrq) {
	timaIrq.flagIrq();
	timaIrq.setNextIrqEventTime(timaIrq.nextIrqEventTime()
	                          + ((256u - tma_) << timaClock[tac_ & 3]));
}

}
