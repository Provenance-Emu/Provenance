//
//   Copyright (C) 2010 by sinamas <sinamas at users.sourceforge.net>
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

#ifndef PPU_H
#define PPU_H

#include "lcddef.h"
#include "ly_counter.h"
#include "sprite_mapper.h"
#include "gbint.h"
#include <cstddef>

namespace gambatte {

class PPUFrameBuf {
public:
	PPUFrameBuf() : buf_(0), fbline_(nullfbline()), pitch_(0) {}
	uint_least32_t * fb() const { return buf_; }
	uint_least32_t * fbline() const { return fbline_; }
	std::ptrdiff_t pitch() const { return pitch_; }
	void setBuf(uint_least32_t *buf, std::ptrdiff_t pitch) { buf_ = buf; pitch_ = pitch; fbline_ = nullfbline(); }
	void setFbline(unsigned ly) { fbline_ = buf_ ? buf_ + std::ptrdiff_t(ly) * pitch_ : nullfbline(); }

private:
	uint_least32_t *buf_;
	uint_least32_t *fbline_;
	std::ptrdiff_t pitch_;

	static uint_least32_t * nullfbline() { static uint_least32_t nullfbline_[160]; return nullfbline_; }
};

struct PPUPriv;

struct PPUState {
	void (*f)(PPUPriv &v);
	unsigned (*predictCyclesUntilXpos_f)(PPUPriv const &v, int targetxpos, unsigned cycles);
	unsigned char id;
};

struct PPUPriv {
	unsigned long bgPalette[8 * 4];
	unsigned long spPalette[8 * 4];
	struct Sprite { unsigned char spx, oampos, line, attrib; } spriteList[11];
	unsigned short spwordList[11];
	unsigned char nextSprite;
	unsigned char currentSprite;

	unsigned char const *vram;
	PPUState const *nextCallPtr;

	unsigned long now;
	unsigned long lastM0Time;
	long cycles;

	unsigned tileword;
	unsigned ntileword;

	SpriteMapper spriteMapper;
	LyCounter lyCounter;
	PPUFrameBuf framebuf;

	unsigned char lcdc;
	unsigned char scy;
	unsigned char scx;
	unsigned char wy;
	unsigned char wy2;
	unsigned char wx;
	unsigned char winDrawState;
	unsigned char wscx;
	unsigned char winYPos;
	unsigned char reg0;
	unsigned char reg1;
	unsigned char attrib;
	unsigned char nattrib;
	unsigned char xpos;
	unsigned char endx;

	bool cgb;
	bool weMaster;

	PPUPriv(NextM0Time &nextM0Time, unsigned char const *oamram, unsigned char const *vram);
};

class PPU {
public:
	PPU(NextM0Time &nextM0Time, unsigned char const *oamram, unsigned char const *vram)
	: p_(nextM0Time, oamram, vram)
	{
	}

	unsigned long * bgPalette() { return p_.bgPalette; }
	bool cgb() const { return p_.cgb; }
	void doLyCountEvent() { p_.lyCounter.doEvent(); }
	unsigned long doSpriteMapEvent(unsigned long time) { return p_.spriteMapper.doEvent(time); }
	PPUFrameBuf const & frameBuf() const { return p_.framebuf; }

	bool inactivePeriodAfterDisplayEnable(unsigned long cc) const {
		return p_.spriteMapper.inactivePeriodAfterDisplayEnable(cc);
	}

	unsigned long lastM0Time() const { return p_.lastM0Time; }
	unsigned lcdc() const { return p_.lcdc; }
	void loadState(SaveState const &state, unsigned char const *oamram);
	LyCounter const & lyCounter() const { return p_.lyCounter; }
	unsigned long now() const { return p_.now; }
	void oamChange(unsigned long cc) { p_.spriteMapper.oamChange(cc); }
	void oamChange(unsigned char const *oamram, unsigned long cc) { p_.spriteMapper.oamChange(oamram, cc); }
	unsigned long predictedNextXposTime(unsigned xpos) const;
	void reset(unsigned char const *oamram, unsigned char const *vram, bool cgb);
	void resetCc(unsigned long oldCc, unsigned long newCc);
	void saveState(SaveState &ss) const;
	void setFrameBuf(uint_least32_t *buf, std::ptrdiff_t pitch) { p_.framebuf.setBuf(buf, pitch); }
	void setLcdc(unsigned lcdc, unsigned long cc);
	void setScx(unsigned scx) { p_.scx = scx; }
	void setScy(unsigned scy) { p_.scy = scy; }
	void setStatePtrs(SaveState &ss) { p_.spriteMapper.setStatePtrs(ss); }
	void setWx(unsigned wx) { p_.wx = wx; }
	void setWy(unsigned wy) { p_.wy = wy; }
	void updateWy2() { p_.wy2 = p_.wy; }
	void speedChange(unsigned long cycleCounter);
	unsigned long * spPalette() { return p_.spPalette; }
	void update(unsigned long cc);

private:
	PPUPriv p_;
};

}

#endif
