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

#include "channel4.h"
#include "../savestate.h"
#include <algorithm>

static unsigned long toPeriod(unsigned const nr3) {
	unsigned s = (nr3 >> 4) + 3;
	unsigned r = nr3 & 7;

	if (!r) {
		r = 1;
		--s;
	}

	return r << s;
}

namespace gambatte {

Channel4::Lfsr::Lfsr()
: backupCounter_(counter_disabled)
, reg_(0x7FFF)
, nr3_(0)
, master_(false)
{
}

void Channel4::Lfsr::updateBackupCounter(unsigned long const cc) {
	if (backupCounter_ <= cc) {
		unsigned long const period = toPeriod(nr3_);
		unsigned long periods = (cc - backupCounter_) / period + 1;
		backupCounter_ += periods * period;

		if (master_ && nr3_ < 0xE0) {
			if (nr3_ & 8) {
				while (periods > 6) {
					unsigned const xored = (reg_ << 1 ^ reg_) & 0x7E;
					reg_ = (reg_ >> 6 & ~0x7E) | xored | xored << 8;
					periods -= 6;
				}

				unsigned const xored = ((reg_ ^ reg_ >> 1) << (7 - periods)) & 0x7F;
				reg_ = (reg_ >> periods & ~(0x80 - (0x80 >> periods))) | xored | xored << 8;
			} else {
				while (periods > 15) {
					reg_ = reg_ ^ reg_ >> 1;
					periods -= 15;
				}

				reg_ = reg_ >> periods | (((reg_ ^ reg_ >> 1) << (15 - periods)) & 0x7FFF);
			}
		}
	}
}

void Channel4::Lfsr::reviveCounter(unsigned long cc) {
	updateBackupCounter(cc);
	counter_ = backupCounter_;
}

inline void Channel4::Lfsr::event() {
	if (nr3_ < 0xE0) {
		unsigned const shifted = reg_ >> 1;
		unsigned const xored = (reg_ ^ shifted) & 1;
		reg_ = shifted | xored << 14;

		if (nr3_ & 8)
			reg_ = (reg_ & ~0x40) | xored << 6;
	}

	counter_ += toPeriod(nr3_);
	backupCounter_ = counter_;
}

void Channel4::Lfsr::nr3Change(unsigned newNr3, unsigned long cc) {
	updateBackupCounter(cc);
	nr3_ = newNr3;
}

void Channel4::Lfsr::nr4Init(unsigned long cc) {
	disableMaster();
	updateBackupCounter(cc);
	master_ = true;
	backupCounter_ += 4;
	counter_ = backupCounter_;
}

void Channel4::Lfsr::reset(unsigned long cc) {
	nr3_ = 0;
	disableMaster();
	backupCounter_ = cc + toPeriod(nr3_);
}

void Channel4::Lfsr::resetCounters(unsigned long oldCc) {
	updateBackupCounter(oldCc);
	backupCounter_ -= counter_max;
	SoundUnit::resetCounters(oldCc);
}

void Channel4::Lfsr::saveState(SaveState &state, unsigned long cc) {
	updateBackupCounter(cc);
	state.spu.ch4.lfsr.counter = backupCounter_;
	state.spu.ch4.lfsr.reg = reg_;
}

void Channel4::Lfsr::loadState(SaveState const &state) {
	counter_ = backupCounter_ = std::max(state.spu.ch4.lfsr.counter, state.spu.cycleCounter);
	reg_ = state.spu.ch4.lfsr.reg;
	master_ = state.spu.ch4.master;
	nr3_ = state.mem.ioamhram.get()[0x122];
}

Channel4::Channel4()
: staticOutputTest_(*this, lfsr_)
, disableMaster_(master_, lfsr_)
, lengthCounter_(disableMaster_, 0x3F)
, envelopeUnit_(staticOutputTest_)
, nextEventUnit_(0)
, cycleCounter_(0)
, soMask_(0)
, prevOut_(0)
, nr4_(0)
, master_(false)
{
	setEvent();
}

void Channel4::setEvent() {
	nextEventUnit_ = &envelopeUnit_;
	if (lengthCounter_.counter() < nextEventUnit_->counter())
		nextEventUnit_ = &lengthCounter_;
}

void Channel4::setNr1(unsigned data) {
	lengthCounter_.nr1Change(data, nr4_, cycleCounter_);
	setEvent();
}

void Channel4::setNr2(unsigned data) {
	if (envelopeUnit_.nr2Change(data))
		disableMaster_();
	else
		staticOutputTest_(cycleCounter_);

	setEvent();
}

void Channel4::setNr4(unsigned const data) {
	lengthCounter_.nr4Change(nr4_, data, cycleCounter_);
	nr4_ = data;

	if (data & 0x80) { // init-bit
		nr4_ &= 0x7F;
		master_ = !envelopeUnit_.nr4Init(cycleCounter_);

		if (master_)
			lfsr_.nr4Init(cycleCounter_);

		staticOutputTest_(cycleCounter_);
	}

	setEvent();
}

void Channel4::setSo(unsigned long soMask) {
	soMask_ = soMask;
	staticOutputTest_(cycleCounter_);
	setEvent();
}

void Channel4::reset() {
	// cycleCounter >> 12 & 7 represents the frame sequencer position.
	cycleCounter_ &= 0xFFF;
	cycleCounter_ += ~(cycleCounter_ + 2) << 1 & 0x1000;

	lfsr_.reset(cycleCounter_);
	envelopeUnit_.reset();
	setEvent();
}

void Channel4::saveState(SaveState &state) {
	lfsr_.saveState(state, cycleCounter_);
	envelopeUnit_.saveState(state.spu.ch4.env);
	lengthCounter_.saveState(state.spu.ch4.lcounter);

	state.spu.ch4.nr4 = nr4_;
	state.spu.ch4.master = master_;
}

void Channel4::loadState(SaveState const &state) {
	lfsr_.loadState(state);
	envelopeUnit_.loadState(state.spu.ch4.env, state.mem.ioamhram.get()[0x121],
	                        state.spu.cycleCounter);
	lengthCounter_.loadState(state.spu.ch4.lcounter, state.spu.cycleCounter);

	cycleCounter_ = state.spu.cycleCounter;
	nr4_ = state.spu.ch4.nr4;
	master_ = state.spu.ch4.master;
}

void Channel4::update(uint_least32_t *buf, unsigned long const soBaseVol, unsigned long cycles) {
	unsigned long const outBase = envelopeUnit_.dacIsOn() ? soBaseVol & soMask_ : 0;
	unsigned long const outLow = outBase * (0 - 15ul);
	unsigned long const endCycles = cycleCounter_ + cycles;

	for (;;) {
		unsigned long const outHigh = outBase * (envelopeUnit_.getVolume() * 2 - 15ul);
		unsigned long const nextMajorEvent = std::min(nextEventUnit_->counter(), endCycles);
		unsigned long out = lfsr_.isHighState() ? outHigh : outLow;

		while (lfsr_.counter() <= nextMajorEvent) {
			*buf += out - prevOut_;
			prevOut_ = out;
			buf += lfsr_.counter() - cycleCounter_;
			cycleCounter_ = lfsr_.counter();

			lfsr_.event();
			out = lfsr_.isHighState() ? outHigh : outLow;
		}

		if (cycleCounter_ < nextMajorEvent) {
			*buf += out - prevOut_;
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
		lengthCounter_.resetCounters(cycleCounter_);
		lfsr_.resetCounters(cycleCounter_);
		envelopeUnit_.resetCounters(cycleCounter_);
		cycleCounter_ -= SoundUnit::counter_max;
	}
}

}
