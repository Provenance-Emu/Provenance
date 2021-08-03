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

#ifndef SPRITE_MAPPER_H
#define SPRITE_MAPPER_H

#include "ly_counter.h"
#include "../savestate.h"

namespace gambatte {

class NextM0Time;

class SpriteMapper {
public:
	SpriteMapper(NextM0Time &nextM0Time,
	             LyCounter const &lyCounter,
	             unsigned char const *oamram);
	void reset(unsigned char const *oamram, bool cgb);
	unsigned long doEvent(unsigned long time);
	bool largeSprites(unsigned spNo) const { return oamReader_.largeSprites(spNo); }
	unsigned numSprites(unsigned ly) const { return num_[ly] & ~need_sorting_mask; }
	void oamChange(unsigned long cc) { oamReader_.change(cc); }
	void oamChange(unsigned char const *oamram, unsigned long cc) { oamReader_.change(oamram, cc); }
	unsigned char const * oamram() const { return oamReader_.oam(); }
	unsigned char const * posbuf() const { return oamReader_.spritePosBuf(); }
	void  preSpeedChange(unsigned long cc) { oamReader_.update(cc); }
	void postSpeedChange(unsigned long cc) { oamReader_.change(cc); }

	void resetCycleCounter(unsigned long oldCc, unsigned long newCc) {
		oamReader_.update(oldCc);
		oamReader_.resetCycleCounter(oldCc, newCc);
	}

	void setLargeSpritesSource(bool src) { oamReader_.setLargeSpritesSrc(src); }

	unsigned char const * sprites(unsigned ly) const {
		if (num_[ly] & need_sorting_mask)
			sortLine(ly);

		return spritemap_ + ly * 10;
	}

	void setStatePtrs(SaveState &state) { oamReader_.setStatePtrs(state); }
	void enableDisplay(unsigned long cc) { oamReader_.enableDisplay(cc); }
	void saveState(SaveState &state) const { oamReader_.saveState(state); }

	void loadState(SaveState const &state, unsigned char const *oamram) {
		oamReader_.loadState(state, oamram);
		mapSprites();
	}

	bool inactivePeriodAfterDisplayEnable(unsigned long cc) const {
		return oamReader_.inactivePeriodAfterDisplayEnable(cc);
	}

	static unsigned long schedule(LyCounter const &lyCounter, unsigned long cc) {
		return lyCounter.nextLineCycle(80, cc);
	}

private:
	class OamReader {
	public:
		OamReader(LyCounter const &lyCounter, unsigned char const *oamram);
		void reset(unsigned char const *oamram, bool cgb);
		void change(unsigned long cc);
		void change(unsigned char const *oamram, unsigned long cc) { change(cc); oamram_ = oamram; }
		bool changed() const { return lastChange_ != 0xFF; }
		bool largeSprites(unsigned spNo) const { return szbuf_[spNo]; }
		unsigned char const * oam() const { return oamram_; }
		void resetCycleCounter(unsigned long oldCc, unsigned long newCc) { lu_ -= oldCc - newCc; }
		void setLargeSpritesSrc(bool src) { largeSpritesSrc_ = src; }
		void update(unsigned long cc);
		unsigned char const * spritePosBuf() const { return buf_; }
		void setStatePtrs(SaveState &state);
		void enableDisplay(unsigned long cc);
		void saveState(SaveState &state) const { state.ppu.enableDisplayM0Time = lu_; }
		void loadState(SaveState const &ss, unsigned char const *oamram);
		bool inactivePeriodAfterDisplayEnable(unsigned long cc) const { return cc < lu_; }
		unsigned lineTime() const { return lyCounter_.lineTime(); }

	private:
		unsigned char buf_[80];
		bool szbuf_[40];
		LyCounter const &lyCounter_;
		unsigned char const *oamram_;
		unsigned long lu_;
		unsigned char lastChange_;
		bool largeSpritesSrc_;
		bool cgb_;
	};

	enum { need_sorting_mask = 0x80 };

	mutable unsigned char spritemap_[144 * 10];
	mutable unsigned char num_[144];
	NextM0Time &nextM0Time_;
	OamReader oamReader_;

	void clearMap();
	void mapSprites();
	void sortLine(unsigned ly) const;
};

}

#endif
