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

#ifndef SOUND_H
#define SOUND_H

#include "sound/channel1.h"
#include "sound/channel2.h"
#include "sound/channel3.h"
#include "sound/channel4.h"

namespace gambatte {

class PSG {
public:
	PSG();
	void init(bool cgb);
	void reset();
	void setStatePtrs(SaveState &state);
	void saveState(SaveState &state);
	void loadState(SaveState const &state);

	void generateSamples(unsigned long cycleCounter, bool doubleSpeed);
	void resetCounter(unsigned long newCc, unsigned long oldCc, bool doubleSpeed);
	std::size_t fillBuffer();
	void setBuffer(uint_least32_t *buf) { buffer_ = buf; bufferPos_ = 0; }

	bool isEnabled() const { return enabled_; }
	void setEnabled(bool value) { enabled_ = value; }

	void setNr10(unsigned data) { ch1_.setNr0(data); }
	void setNr11(unsigned data) { ch1_.setNr1(data); }
	void setNr12(unsigned data) { ch1_.setNr2(data); }
	void setNr13(unsigned data) { ch1_.setNr3(data); }
	void setNr14(unsigned data) { ch1_.setNr4(data); }

	void setNr21(unsigned data) { ch2_.setNr1(data); }
	void setNr22(unsigned data) { ch2_.setNr2(data); }
	void setNr23(unsigned data) { ch2_.setNr3(data); }
	void setNr24(unsigned data) { ch2_.setNr4(data); }

	void setNr30(unsigned data) { ch3_.setNr0(data); }
	void setNr31(unsigned data) { ch3_.setNr1(data); }
	void setNr32(unsigned data) { ch3_.setNr2(data); }
	void setNr33(unsigned data) { ch3_.setNr3(data); }
	void setNr34(unsigned data) { ch3_.setNr4(data); }
	unsigned waveRamRead(unsigned index) const { return ch3_.waveRamRead(index); }
	void waveRamWrite(unsigned index, unsigned data) { ch3_.waveRamWrite(index, data); }

	void setNr41(unsigned data) { ch4_.setNr1(data); }
	void setNr42(unsigned data) { ch4_.setNr2(data); }
	void setNr43(unsigned data) { ch4_.setNr3(data); }
	void setNr44(unsigned data) { ch4_.setNr4(data); }

	void setSoVolume(unsigned nr50);
	void mapSo(unsigned nr51);
	unsigned getStatus() const;

private:
	Channel1 ch1_;
	Channel2 ch2_;
	Channel3 ch3_;
	Channel4 ch4_;
	uint_least32_t *buffer_;
	std::size_t bufferPos_;
	unsigned long lastUpdate_;
	unsigned long soVol_;
	uint_least32_t rsum_;
	bool enabled_;

	void accumulateChannels(unsigned long cycles);
};

}

#endif
