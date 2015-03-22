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

#include "channel3.h"
#include "../savestate.h"
#include <algorithm>
#include <cstring>

static inline unsigned toPeriod(unsigned nr3, unsigned nr4) {
	return 0x800 - ((nr4 << 8 & 0x700) | nr3);
}

namespace gambatte {

Channel3::Channel3()
: disableMaster_(master_, waveCounter_)
, lengthCounter_(disableMaster_, 0xFF)
, cycleCounter_(0)
, soMask_(0)
, prevOut_(0)
, waveCounter_(SoundUnit::counter_disabled)
, lastReadTime_(0)
, nr0_(0)
, nr3_(0)
, nr4_(0)
, wavePos_(0)
, rshift_(4)
, sampleBuf_(0)
, master_(false)
, cgb_(false)
{
}

void Channel3::setNr0(unsigned data) {
	nr0_ = data & 0x80;

	if (!(data & 0x80))
		disableMaster_();
}

void Channel3::setNr2(unsigned data) {
	rshift_ = (data >> 5 & 3U) - 1;
	if (rshift_ > 3)
		rshift_ = 4;
}

void Channel3::setNr4(unsigned const data) {
	lengthCounter_.nr4Change(nr4_, data, cycleCounter_);
	nr4_ = data & 0x7F;

	if (data & nr0_/* & 0x80*/) {
		if (!cgb_ && waveCounter_ == cycleCounter_ + 1) {
			unsigned const pos = ((wavePos_ + 1) & 0x1F) >> 1;

			if (pos < 4)
				waveRam_[0] = waveRam_[pos];
			else
				std::memcpy(waveRam_, waveRam_ + (pos & ~3), 4);
		}

		master_ = true;
		wavePos_ = 0;
		lastReadTime_ = waveCounter_ = cycleCounter_ + toPeriod(nr3_, data) + 3;
	}
}

void Channel3::setSo(unsigned long soMask) {
	soMask_ = soMask;
}

void Channel3::reset() {
	// cycleCounter >> 12 & 7 represents the frame sequencer position.
	cycleCounter_ &= 0xFFF;
	cycleCounter_ += ~(cycleCounter_ + 2) << 1 & 0x1000;

	sampleBuf_ = 0;
}

void Channel3::init(bool cgb) {
	cgb_ = cgb;
}

void Channel3::setStatePtrs(SaveState &state) {
	state.spu.ch3.waveRam.set(waveRam_, sizeof waveRam_);
}

void Channel3::saveState(SaveState &state) const {
	lengthCounter_.saveState(state.spu.ch3.lcounter);

	state.spu.ch3.waveCounter = waveCounter_;
	state.spu.ch3.lastReadTime = lastReadTime_;
	state.spu.ch3.nr3 = nr3_;
	state.spu.ch3.nr4 = nr4_;
	state.spu.ch3.wavePos = wavePos_;
	state.spu.ch3.sampleBuf = sampleBuf_;
	state.spu.ch3.master = master_;
}

void Channel3::loadState(SaveState const &state) {
	lengthCounter_.loadState(state.spu.ch3.lcounter, state.spu.cycleCounter);

	cycleCounter_ = state.spu.cycleCounter;
	waveCounter_ = std::max(state.spu.ch3.waveCounter, state.spu.cycleCounter);
	lastReadTime_ = state.spu.ch3.lastReadTime;
	nr3_ = state.spu.ch3.nr3;
	nr4_ = state.spu.ch3.nr4;
	wavePos_ = state.spu.ch3.wavePos & 0x1F;
	sampleBuf_ = state.spu.ch3.sampleBuf;
	master_ = state.spu.ch3.master;

	nr0_ = state.mem.ioamhram.get()[0x11A] & 0x80;
	setNr2(state.mem.ioamhram.get()[0x11C]);
}

void Channel3::updateWaveCounter(unsigned long const cc) {
	if (cc >= waveCounter_) {
		unsigned const period = toPeriod(nr3_, nr4_);
		unsigned long const periods = (cc - waveCounter_) / period;

		lastReadTime_ = waveCounter_ + periods * period;
		waveCounter_ = lastReadTime_ + period;

		wavePos_ += periods + 1;
		wavePos_ &= 0x1F;

		sampleBuf_ = waveRam_[wavePos_ >> 1];
	}
}

void Channel3::update(uint_least32_t *buf, unsigned long const soBaseVol, unsigned long cycles) {
	unsigned long const outBase = nr0_/* & 0x80*/ ? soBaseVol & soMask_ : 0;

	if (outBase && rshift_ != 4) {
		unsigned long const endCycles = cycleCounter_ + cycles;

		for (;;) {
			unsigned long const nextMajorEvent =
				std::min(lengthCounter_.counter(), endCycles);
			unsigned long out = master_
				? ((sampleBuf_ >> (~wavePos_ << 2 & 4) & 0xF) >> rshift_) * 2 - 15ul
				: 0 - 15ul;
			out *= outBase;

			while (waveCounter_ <= nextMajorEvent) {
				*buf += out - prevOut_;
				prevOut_ = out;
				buf += waveCounter_ - cycleCounter_;
				cycleCounter_ = waveCounter_;

				lastReadTime_ = waveCounter_;
				waveCounter_ += toPeriod(nr3_, nr4_);
				++wavePos_;
				wavePos_ &= 0x1F;
				sampleBuf_ = waveRam_[wavePos_ >> 1];
				out = ((sampleBuf_ >> (~wavePos_ << 2 & 4) & 0xF) >> rshift_) * 2 - 15ul;
				out *= outBase;
			}

			if (cycleCounter_ < nextMajorEvent) {
				*buf += out - prevOut_;
				prevOut_ = out;
				buf += nextMajorEvent - cycleCounter_;
				cycleCounter_ = nextMajorEvent;
			}

			if (lengthCounter_.counter() == nextMajorEvent) {
				lengthCounter_.event();
			} else
				break;
		}
	} else {
		unsigned long const out = outBase * (0 - 15ul);
		*buf += out - prevOut_;
		prevOut_ = out;
		cycleCounter_ += cycles;

		while (lengthCounter_.counter() <= cycleCounter_) {
			updateWaveCounter(lengthCounter_.counter());
			lengthCounter_.event();
		}

		updateWaveCounter(cycleCounter_);
	}

	if (cycleCounter_ >= SoundUnit::counter_max) {
		lengthCounter_.resetCounters(cycleCounter_);

		if (waveCounter_ != SoundUnit::counter_disabled)
			waveCounter_ -= SoundUnit::counter_max;

		lastReadTime_ -= SoundUnit::counter_max;
		cycleCounter_ -= SoundUnit::counter_max;
	}
}

}
