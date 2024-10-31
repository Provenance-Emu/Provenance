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

#include "channel2.h"
#include "../savestate.h"
#include <algorithm>

namespace gambatte {

Channel2::Channel2()
: staticOutputTest_(*this, dutyUnit_)
, disableMaster_(master_, dutyUnit_)
, lengthCounter_(disableMaster_, 0x3F)
, envelopeUnit_(staticOutputTest_)
, cycleCounter_(0)
, soMask_(0)
, prevOut_(0)
, nr4_(0)
, master_(false)
{
	setEvent();
}

void Channel2::setEvent() {
	nextEventUnit = &envelopeUnit_;
	if (lengthCounter_.counter() < nextEventUnit->counter())
		nextEventUnit = &lengthCounter_;
}

void Channel2::setNr1(unsigned data) {
	lengthCounter_.nr1Change(data, nr4_, cycleCounter_);
	dutyUnit_.nr1Change(data, cycleCounter_);
	setEvent();
}

void Channel2::setNr2(unsigned data) {
	if (envelopeUnit_.nr2Change(data))
		disableMaster_();
	else
		staticOutputTest_(cycleCounter_);

	setEvent();
}

void Channel2::setNr3(unsigned data) {
	dutyUnit_.nr3Change(data, cycleCounter_);
	setEvent();
}

void Channel2::setNr4(unsigned const data) {
	lengthCounter_.nr4Change(nr4_, data, cycleCounter_);
	nr4_ = data;

	if (data & 0x80) { // init-bit
		nr4_ &= 0x7F;
		master_ = !envelopeUnit_.nr4Init(cycleCounter_);
		staticOutputTest_(cycleCounter_);
	}

	dutyUnit_.nr4Change(data, cycleCounter_);
	setEvent();
}

void Channel2::setSo(unsigned long soMask) {
	soMask_ = soMask;
	staticOutputTest_(cycleCounter_);
	setEvent();
}

void Channel2::reset() {
	// cycleCounter >> 12 & 7 represents the frame sequencer position.
	cycleCounter_ &= 0xFFF;
	cycleCounter_ += ~(cycleCounter_ + 2) << 1 & 0x1000;

	dutyUnit_.reset();
	envelopeUnit_.reset();
	setEvent();
}

void Channel2::saveState(SaveState &state) {
	dutyUnit_.saveState(state.spu.ch2.duty, cycleCounter_);
	envelopeUnit_.saveState(state.spu.ch2.env);
	lengthCounter_.saveState(state.spu.ch2.lcounter);

	state.spu.ch2.nr4 = nr4_;
	state.spu.ch2.master = master_;
}

void Channel2::loadState(SaveState const &state) {
	dutyUnit_.loadState(state.spu.ch2.duty, state.mem.ioamhram.get()[0x116],
	                    state.spu.ch2.nr4, state.spu.cycleCounter);
	envelopeUnit_.loadState(state.spu.ch2.env, state.mem.ioamhram.get()[0x117],
	                        state.spu.cycleCounter);
	lengthCounter_.loadState(state.spu.ch2.lcounter, state.spu.cycleCounter);

	cycleCounter_ = state.spu.cycleCounter;
	nr4_ = state.spu.ch2.nr4;
	master_ = state.spu.ch2.master;
}

void Channel2::update(uint_least32_t *buf, unsigned long const soBaseVol, unsigned long cycles) {
	unsigned long const outBase = envelopeUnit_.dacIsOn() ? soBaseVol & soMask_ : 0;
	unsigned long const outLow = outBase * (0 - 15ul);
	unsigned long const endCycles = cycleCounter_ + cycles;

	for (;;) {
		unsigned long const outHigh = master_
		                            ? outBase * (envelopeUnit_.getVolume() * 2 - 15ul)
		                            : outLow;
		unsigned long const nextMajorEvent = std::min(nextEventUnit->counter(), endCycles);
		unsigned long out = dutyUnit_.isHighState() ? outHigh : outLow;

		while (dutyUnit_.counter() <= nextMajorEvent) {
			*buf += out - prevOut_;
			prevOut_ = out;
			buf += dutyUnit_.counter() - cycleCounter_;
			cycleCounter_ = dutyUnit_.counter();

			dutyUnit_.event();
			out = dutyUnit_.isHighState() ? outHigh : outLow;
		}

		if (cycleCounter_ < nextMajorEvent) {
			*buf += out - prevOut_;
			prevOut_ = out;
			buf += nextMajorEvent - cycleCounter_;
			cycleCounter_ = nextMajorEvent;
		}

		if (nextEventUnit->counter() == nextMajorEvent) {
			nextEventUnit->event();
			setEvent();
		} else
			break;
	}

	if (cycleCounter_ >= SoundUnit::counter_max) {
		dutyUnit_.resetCounters(cycleCounter_);
		lengthCounter_.resetCounters(cycleCounter_);
		envelopeUnit_.resetCounters(cycleCounter_);
		cycleCounter_ -= SoundUnit::counter_max;
	}
}

}
