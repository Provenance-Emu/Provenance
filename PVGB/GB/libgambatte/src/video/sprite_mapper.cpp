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

#include "sprite_mapper.h"
#include "counterdef.h"
#include "next_m0_time.h"
#include "../insertion_sort.h"
#include <algorithm>
#include <cstring>

namespace {

class SpxLess {
public:
	explicit SpxLess(unsigned char const *spxlut) : spxlut_(spxlut) {}

	bool operator()(unsigned char lhs, unsigned char rhs) const {
		return spxlut_[lhs] < spxlut_[rhs];
	}

private:
	unsigned char const *const spxlut_;
};

}

namespace gambatte {

SpriteMapper::OamReader::OamReader(LyCounter const &lyCounter, unsigned char const *oamram)
: lyCounter_(lyCounter)
, oamram_(oamram)
, cgb_(false)
{
	reset(oamram, false);
}

void SpriteMapper::OamReader::reset(unsigned char const *const oamram, bool const cgb) {
	oamram_ = oamram;
	cgb_ = cgb;
	setLargeSpritesSrc(false);
	lu_ = 0;
	lastChange_ = 0xFF;
	std::fill(szbuf_, szbuf_ + 40, largeSpritesSrc_);

	unsigned pos = 0;
	unsigned distance = 80;
	while (distance--) {
		buf_[pos] = oamram[((pos * 2) & ~3) | (pos & 1)];
		++pos;
	}
}

static unsigned toPosCycles(unsigned long const cc, LyCounter const &lyCounter) {
	unsigned lc = lyCounter.lineCycles(cc) + 3 - lyCounter.isDoubleSpeed() * 3u;
	if (lc >= 456)
		lc -= 456;

	return lc;
}

void SpriteMapper::OamReader::update(unsigned long const cc) {
	if (cc > lu_) {
		if (changed()) {
			unsigned const lulc = toPosCycles(lu_, lyCounter_);
			unsigned pos = std::min(lulc, 80u);
			unsigned distance = 80;

			if ((cc - lu_) >> lyCounter_.isDoubleSpeed() < 456) {
				unsigned cclc = toPosCycles(cc, lyCounter_);
				distance = std::min(cclc, 80u) - pos + (cclc < lulc ? 80 : 0);
			}

			{
				unsigned targetDistance =
					lastChange_ - pos + (lastChange_ <= pos ? 80 : 0);
				if (targetDistance <= distance) {
					distance = targetDistance;
					lastChange_ = 0xFF;
				}
			}

			while (distance--) {
				if (!(pos & 1)) {
					if (pos == 80)
						pos = 0;

					if (cgb_)
						szbuf_[pos >> 1] = largeSpritesSrc_;

					buf_[pos    ] = oamram_[pos * 2    ];
					buf_[pos + 1] = oamram_[pos * 2 + 1];
				} else
					szbuf_[pos >> 1] = (szbuf_[pos >> 1] & cgb_) | largeSpritesSrc_;

				++pos;
			}
		}

		lu_ = cc;
	}
}

void SpriteMapper::OamReader::change(unsigned long cc) {
	update(cc);
	lastChange_ = std::min(toPosCycles(lu_, lyCounter_), 80u);
}

void SpriteMapper::OamReader::setStatePtrs(SaveState &state) {
	state.ppu.oamReaderBuf.set(buf_, sizeof buf_);
	state.ppu.oamReaderSzbuf.set(szbuf_, sizeof szbuf_ / sizeof *szbuf_);
}

void SpriteMapper::OamReader::loadState(SaveState const &ss, unsigned char const *const oamram) {
	oamram_ = oamram;
	largeSpritesSrc_ = ss.mem.ioamhram.get()[0x140] >> 2 & 1;
	lu_ = ss.ppu.enableDisplayM0Time;
	change(lu_);
}

void SpriteMapper::OamReader::enableDisplay(unsigned long cc) {
	std::memset(buf_, 0x00, sizeof buf_);
	std::fill(szbuf_, szbuf_ + 40, false);
	lu_ = cc + (80 << lyCounter_.isDoubleSpeed());
	lastChange_ = 80;
}

SpriteMapper::SpriteMapper(NextM0Time &nextM0Time,
                           LyCounter const &lyCounter,
                           unsigned char const *oamram)
: nextM0Time_(nextM0Time)
, oamReader_(lyCounter, oamram)
{
	clearMap();
}

void SpriteMapper::reset(unsigned char const *oamram, bool cgb) {
	oamReader_.reset(oamram, cgb);
	clearMap();
}

void SpriteMapper::clearMap() {
	std::memset(num_, need_sorting_mask, sizeof num_);
}

void SpriteMapper::mapSprites() {
	clearMap();

	for (unsigned i = 0x00; i < 0x50; i += 2) {
		int const spriteHeight = 8 << largeSprites(i >> 1);
		unsigned const bottomPos = posbuf()[i] - (17u - spriteHeight);

		if (bottomPos < 143u + spriteHeight) {
			unsigned const startly = std::max(int(bottomPos) + 1 - spriteHeight, 0);
			unsigned char *map = spritemap_ + startly * 10;
			unsigned char *n   = num_       + startly;
			unsigned char *const nend = num_ + std::min(bottomPos, 143u) + 1;

			do {
				if (*n < need_sorting_mask + 10)
					map[(*n)++ - need_sorting_mask] = i;

				map += 10;
			} while (++n != nend);
		}
	}

	nextM0Time_.invalidatePredictedNextM0Time();
}

void SpriteMapper::sortLine(unsigned const ly) const {
	num_[ly] &= ~need_sorting_mask;
	insertionSort(spritemap_ + ly * 10, spritemap_ + ly * 10 + num_[ly],
	              SpxLess(posbuf() + 1));
}

unsigned long SpriteMapper::doEvent(unsigned long const time) {
	oamReader_.update(time);
	mapSprites();
	return oamReader_.changed()
	     ? time + oamReader_.lineTime()
	     : static_cast<unsigned long>(disabled_time);
}

}
