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

#include "channel1.h"
#include "../savestate.h"
#include <algorithm>

namespace gambatte {

Channel1::SweepUnit::SweepUnit(MasterDisabler &disabler, DutyUnit &dutyUnit)
: disableMaster_(disabler)
, dutyUnit_(dutyUnit)
, shadow_(0)
, nr0_(0)
, negging_(false)
, cgb_(false)
{
}

unsigned Channel1::SweepUnit::calcFreq() {
	unsigned freq = shadow_ >> (nr0_ & 0x07);

	if (nr0_ & 0x08) {
		freq = shadow_ - freq;
		negging_ = true;
	} else
		freq = shadow_ + freq;

	if (freq & 2048)
		disableMaster_();

	return freq;
}

void Channel1::SweepUnit::event() {
	unsigned long const period = nr0_ >> 4 & 0x07;

	if (period) {
		unsigned const freq = calcFreq();

		if (!(freq & 2048) && (nr0_ & 0x07)) {
			shadow_ = freq;
			dutyUnit_.setFreq(freq, counter_);
			calcFreq();
		}

		counter_ += period << 14;
	} else
		counter_ += 8ul << 14;
}

void Channel1::SweepUnit::nr0Change(unsigned newNr0) {
	if (negging_ && !(newNr0 & 0x08))
		disableMaster_();

	nr0_ = newNr0;
}

void Channel1::SweepUnit::nr4Init(unsigned long const cc) {
	negging_ = false;
	shadow_ = dutyUnit_.freq();

	unsigned const period = nr0_ >> 4 & 0x07;
	unsigned const shift = nr0_ & 0x07;

	if (period | shift)
		counter_ = ((((cc + 2 + cgb_ * 2) >> 14) + (period ? period : 8)) << 14) + 2;
	else
		counter_ = counter_disabled;

	if (shift)
		calcFreq();
}

void Channel1::SweepUnit::reset() {
	counter_ = counter_disabled;
}

void Channel1::SweepUnit::saveState(SaveState &state) const {
	state.spu.ch1.sweep.counter = counter_;
	state.spu.ch1.sweep.shadow = shadow_;
	state.spu.ch1.sweep.nr0 = nr0_;
	state.spu.ch1.sweep.negging = negging_;
}

void Channel1::SweepUnit::loadState(SaveState const &state) {
	counter_ = std::max(state.spu.ch1.sweep.counter, state.spu.cycleCounter);
	shadow_ = state.spu.ch1.sweep.shadow;
	nr0_ = state.spu.ch1.sweep.nr0;
	negging_ = state.spu.ch1.sweep.negging;
}

Channel1::Channel1()
: staticOutputTest_(*this, dutyUnit_)
, disableMaster_(master_, dutyUnit_)
, lengthCounter_(disableMaster_, 0x3F)
, envelopeUnit_(staticOutputTest_)
, sweepUnit_(disableMaster_, dutyUnit_)
, nextEventUnit_(0)
, cycleCounter_(0)
, soMask_(0)
, prevOut_(0)
, nr4_(0)
, master_(false)
{
	setEvent();
}

void Channel1::setEvent() {
	nextEventUnit_ = &sweepUnit_;
	if (envelopeUnit_.counter() < nextEventUnit_->counter())
		nextEventUnit_ = &envelopeUnit_;
	if (lengthCounter_.counter() < nextEventUnit_->counter())
		nextEventUnit_ = &lengthCounter_;
}

void Channel1::setNr0(unsigned data) {
	sweepUnit_.nr0Change(data);
	setEvent();
}

void Channel1::setNr1(unsigned data) {
	lengthCounter_.nr1Change(data, nr4_, cycleCounter_);
	dutyUnit_.nr1Change(data, cycleCounter_);
	setEvent();
}

void Channel1::setNr2(unsigned data) {
	if (envelopeUnit_.nr2Change(data))
		disableMaster_();
	else
		staticOutputTest_(cycleCounter_);

	setEvent();
}

void Channel1::setNr3(unsigned data) {
	dutyUnit_.nr3Change(data, cycleCounter_);
	setEvent();
}

void Channel1::setNr4(unsigned const data) {
	lengthCounter_.nr4Change(nr4_, data, cycleCounter_);
	nr4_ = data;
	dutyUnit_.nr4Change(data, cycleCounter_);

	if (data & 0x80) { // init-bit
		nr4_ &= 0x7F;
		master_ = !envelopeUnit_.nr4Init(cycleCounter_);
		sweepUnit_.nr4Init(cycleCounter_);
		staticOutputTest_(cycleCounter_);
	}

	setEvent();
}

void Channel1::setSo(unsigned long soMask) {
	soMask_ = soMask;
	staticOutputTest_(cycleCounter_);
	setEvent();
}

void Channel1::reset() {
	// cycleCounter >> 12 & 7 represents the frame sequencer position.
	cycleCounter_ &= 0xFFF;
	cycleCounter_ += ~(cycleCounter_ + 2) << 1 & 0x1000;

	dutyUnit_.reset();
	envelopeUnit_.reset();
	sweepUnit_.reset();
	setEvent();
}

void Channel1::init(bool cgb) {
	sweepUnit_.init(cgb);
}

void Channel1::saveState(SaveState &state) {
	sweepUnit_.saveState(state);
	dutyUnit_.saveState(state.spu.ch1.duty, cycleCounter_);
	envelopeUnit_.saveState(state.spu.ch1.env);
	lengthCounter_.saveState(state.spu.ch1.lcounter);

	state.spu.cycleCounter = cycleCounter_;
	state.spu.ch1.nr4 = nr4_;
	state.spu.ch1.master = master_;
}

void Channel1::loadState(SaveState const &state) {
	sweepUnit_.loadState(state);
	dutyUnit_.loadState(state.spu.ch1.duty, state.mem.ioamhram.get()[0x111],
	                    state.spu.ch1.nr4, state.spu.cycleCounter);
	envelopeUnit_.loadState(state.spu.ch1.env, state.mem.ioamhram.get()[0x112],
	                        state.spu.cycleCounter);
	lengthCounter_.loadState(state.spu.ch1.lcounter, state.spu.cycleCounter);

	cycleCounter_ = state.spu.cycleCounter;
	nr4_ = state.spu.ch1.nr4;
	master_ = state.spu.ch1.master;
}

void Channel1::update(uint_least32_t *buf, unsigned long const soBaseVol, unsigned long cycles) {
	unsigned long const outBase = envelopeUnit_.dacIsOn() ? soBaseVol & soMask_ : 0;
	unsigned long const outLow = outBase * (0 - 15ul);
	unsigned long const endCycles = cycleCounter_ + cycles;

	for (;;) {
		unsigned long const outHigh = master_
		                            ? outBase * (envelopeUnit_.getVolume() * 2 - 15ul)
		                            : outLow;
		unsigned long const nextMajorEvent = std::min(nextEventUnit_->counter(), endCycles);
		unsigned long out = dutyUnit_.isHighState() ? outHigh : outLow;

		while (dutyUnit_.counter() <= nextMajorEvent) {
			*buf = out - prevOut_;
			prevOut_ = out;
			buf += dutyUnit_.counter() - cycleCounter_;
			cycleCounter_ = dutyUnit_.counter();

			dutyUnit_.event();
			out = dutyUnit_.isHighState() ? outHigh : outLow;
		}

		if (cycleCounter_ < nextMajorEvent) {
			*buf = out - prevOut_;
			prevOut_ = out;
			buf += nextMajorEvent - cycleCounter_;
			cycleCounter_ = nextMajorEvent;
		}

		if (nextEventUnit_->counter() == nextMajorEvent) {
			nextEventUnit_->event();
			setEvent();
		} else
			break;
	}

	if (cycleCounter_ >= SoundUnit::counter_max) {
		dutyUnit_.resetCounters(cycleCounter_);
		lengthCounter_.resetCounters(cycleCounter_);
		envelopeUnit_.resetCounters(cycleCounter_);
		sweepUnit_.resetCounters(cycleCounter_);
		cycleCounter_ -= SoundUnit::counter_max;
	}
}

}
