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

#ifndef SOUND_CHANNEL3_H
#define SOUND_CHANNEL3_H

#include "gbint.h"
#include "length_counter.h"
#include "master_disabler.h"

namespace gambatte {

struct SaveState;

class Channel3 {
public:
	Channel3();
	bool isActive() const { return master_; }
	void reset();
	void init(bool cgb);
	void setStatePtrs(SaveState &state);
	void saveState(SaveState &state) const;
	void loadState(const SaveState &state);
	void setNr0(unsigned data);
	void setNr1(unsigned data) { lengthCounter_.nr1Change(data, nr4_, cycleCounter_); }
	void setNr2(unsigned data);
	void setNr3(unsigned data) { nr3_ = data; }
	void setNr4(unsigned data);
	void setSo(unsigned long soMask);
	void update(uint_least32_t *buf, unsigned long soBaseVol, unsigned long cycles);

	unsigned waveRamRead(unsigned index) const {
		if (master_) {
			if (!cgb_ && cycleCounter_ != lastReadTime_)
				return 0xFF;

			index = wavePos_ >> 1;
		}

		return waveRam_[index];
	}

	void waveRamWrite(unsigned index, unsigned data) {
		if (master_) {
			if (!cgb_ && cycleCounter_ != lastReadTime_)
				return;

			index = wavePos_ >> 1;
		}

		waveRam_[index] = data;
	}

private:
	class Ch3MasterDisabler : public MasterDisabler {
	public:
		Ch3MasterDisabler(bool &m, unsigned long &wC) : MasterDisabler(m), waveCounter_(wC) {}

		virtual void operator()() {
			MasterDisabler::operator()();
			waveCounter_ = SoundUnit::counter_disabled;
		}

	private:
		unsigned long &waveCounter_;
	};

	unsigned char waveRam_[0x10];
	Ch3MasterDisabler disableMaster_;
	LengthCounter lengthCounter_;
	unsigned long cycleCounter_;
	unsigned long soMask_;
	unsigned long prevOut_;
	unsigned long waveCounter_;
	unsigned long lastReadTime_;
	unsigned char nr0_;
	unsigned char nr3_;
	unsigned char nr4_;
	unsigned char wavePos_;
	unsigned char rshift_;
	unsigned char sampleBuf_;
	bool master_;
	bool cgb_;

	void updateWaveCounter(unsigned long cc);
};

}

#endif
