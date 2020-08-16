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

#include "ppu.h"
#include "savestate.h"
#include <algorithm>
#include <cstring>
#include <cstddef>

namespace {

using namespace gambatte;

#define PREP(u8) (((u8) << 7 & 0x80) | ((u8) << 5 & 0x40) | ((u8) << 3 & 0x20) | ((u8) << 1 & 0x10) \
                | ((u8) >> 1 & 0x08) | ((u8) >> 3 & 0x04) | ((u8) >> 5 & 0x02) | ((u8) >> 7 & 0x01))

#define EXPAND(u8) ((PREP(u8) << 7 & 0x4000) | (PREP(u8) << 6 & 0x1000) \
                  | (PREP(u8) << 5 & 0x0400) | (PREP(u8) << 4 & 0x0100) \
                  | (PREP(u8) << 3 & 0x0040) | (PREP(u8) << 2 & 0x0010) \
                  | (PREP(u8) << 1 & 0x0004) | (PREP(u8)      & 0x0001))

#define EXPAND_ROW(n) EXPAND((n)|0x0), EXPAND((n)|0x1), EXPAND((n)|0x2), EXPAND((n)|0x3), \
                      EXPAND((n)|0x4), EXPAND((n)|0x5), EXPAND((n)|0x6), EXPAND((n)|0x7), \
                      EXPAND((n)|0x8), EXPAND((n)|0x9), EXPAND((n)|0xA), EXPAND((n)|0xB), \
                      EXPAND((n)|0xC), EXPAND((n)|0xD), EXPAND((n)|0xE), EXPAND((n)|0xF)

#define EXPAND_TABLE EXPAND_ROW(0x00), EXPAND_ROW(0x10), EXPAND_ROW(0x20), EXPAND_ROW(0x30), \
                     EXPAND_ROW(0x40), EXPAND_ROW(0x50), EXPAND_ROW(0x60), EXPAND_ROW(0x70), \
                     EXPAND_ROW(0x80), EXPAND_ROW(0x90), EXPAND_ROW(0xA0), EXPAND_ROW(0xB0), \
                     EXPAND_ROW(0xC0), EXPAND_ROW(0xD0), EXPAND_ROW(0xE0), EXPAND_ROW(0xF0)

static unsigned short const expand_lut[0x200] = {
	EXPAND_TABLE,

#undef PREP
#define PREP(u8) (u8)

	EXPAND_TABLE
};

#undef EXPAND_TABLE
#undef EXPAND_ROW
#undef EXPAND
#undef PREP

#define DECLARE_FUNC(n, id) \
	enum { ID##n = id }; \
	static void f##n (PPUPriv &); \
	static unsigned predictCyclesUntilXpos_f##n (PPUPriv const &, int targetxpos, unsigned cycles); \
	static PPUState const f##n##_ = { f##n, predictCyclesUntilXpos_f##n, ID##n }

namespace M2_Ly0    { DECLARE_FUNC(0, 0); }
namespace M2_LyNon0 { DECLARE_FUNC(0, 0); DECLARE_FUNC(1, 0); }
namespace M3Start { DECLARE_FUNC(0, 0); DECLARE_FUNC(1, 0); }
namespace M3Loop {
namespace Tile {
	DECLARE_FUNC(0, 0x80);
	DECLARE_FUNC(1, 0x81);
	DECLARE_FUNC(2, 0x82);
	DECLARE_FUNC(3, 0x83);
	DECLARE_FUNC(4, 0x84);
	DECLARE_FUNC(5, 0x85);
}
namespace LoadSprites {
	DECLARE_FUNC(0, 0x88);
	DECLARE_FUNC(1, 0x89);
	DECLARE_FUNC(2, 0x8A);
	DECLARE_FUNC(3, 0x8B);
	DECLARE_FUNC(4, 0x8C);
	DECLARE_FUNC(5, 0x8D);
}
namespace StartWindowDraw {
	DECLARE_FUNC(0, 0x90);
	DECLARE_FUNC(1, 0x91);
	DECLARE_FUNC(2, 0x92);
	DECLARE_FUNC(3, 0x93);
	DECLARE_FUNC(4, 0x94);
	DECLARE_FUNC(5, 0x95);
}
} // namespace M3Loop

#undef DECLARE_FUNC

enum { win_draw_start = 1, win_draw_started = 2 };
enum { m2_ds_offset = 3 };
enum { max_m3start_cycles = 80 };
enum { attr_yflip = 0x40, attr_bgpriority = 0x80 };

static inline int lcdcEn(   PPUPriv const &p) { return p.lcdc & lcdc_en;    }
static inline int lcdcWinEn(PPUPriv const &p) { return p.lcdc & lcdc_we;    }
static inline int lcdcObj2x(PPUPriv const &p) { return p.lcdc & lcdc_obj2x; }
static inline int lcdcObjEn(PPUPriv const &p) { return p.lcdc & lcdc_objen; }
static inline int lcdcBgEn( PPUPriv const &p) { return p.lcdc & lcdc_bgen;  }

static inline int weMasterCheckPriorToLyIncLineCycle(bool cgb) { return 450 - cgb; }
static inline int weMasterCheckAfterLyIncLineCycle(bool cgb) { return 454 - cgb; }
static inline int m3StartLineCycle(bool /*cgb*/) { return 83; }

static inline void nextCall(int const cycles, PPUState const &state, PPUPriv &p) {
	int const c = p.cycles - cycles;
	if (c >= 0) {
		p.cycles = c;
		return state.f(p);
	}

	p.cycles = c;
	p.nextCallPtr = &state;
}

namespace M2_Ly0 {
	static void f0(PPUPriv &p) {
		p.weMaster = lcdcWinEn(p) && 0 == p.wy;
		p.winYPos = 0xFF;
		nextCall(m3StartLineCycle(p.cgb), M3Start::f0_, p);
	}
}

namespace M2_LyNon0 {
	static void f0(PPUPriv &p) {
		p.weMaster |= lcdcWinEn(p) && p.lyCounter.ly() == p.wy;
		nextCall(   weMasterCheckAfterLyIncLineCycle(p.cgb)
		          - weMasterCheckPriorToLyIncLineCycle(p.cgb), f1_, p);
	}

	static void f1(PPUPriv &p) {
		p.weMaster |= lcdcWinEn(p) && p.lyCounter.ly() + 1 == p.wy;
		nextCall(456 - weMasterCheckAfterLyIncLineCycle(p.cgb) + m3StartLineCycle(p.cgb),
		         M3Start::f0_, p);
	}
}

/*
namespace M2 {
	struct SpriteLess {
		bool operator()(Sprite lhs, Sprite rhs) const {
			return lhs.spx < rhs.spx;
		}
	};

	static void f0(PPUPriv &p) {
		std::memset(&p.spLut, 0, sizeof p.spLut);
		p.reg0 = 0;
		p.nextSprite = 0;
		p.nextCallPtr = &f1_;
		f1(p);
	}

	static void f1(PPUPriv &p) {
		int cycles = p.cycles;
		unsigned oampos = p.reg0;
		unsigned nextSprite = p.nextSprite;
		unsigned const nly = (p.lyCounter.ly() + 1 == 154 ? 0 : p.lyCounter.ly() + 1)
		                   + ((p.lyCounter.time()-(p.now-p.cycles)) <= 4);
		bool const ls = p.spriteMapper.largeSpritesSource();

		do {
			unsigned const spy = p.spriteMapper.oamram()[oampos  ];
			unsigned const spx = p.spriteMapper.oamram()[oampos+1];
			unsigned const ydiff = spy - nly;

			if (ls ? ydiff < 16u : ydiff - 8u < 8u) {
				p.spriteList[nextSprite].spx = spx;
				p.spriteList[nextSprite].line = 15u - ydiff;
				p.spriteList[nextSprite].oampos = oampos;

				if (++nextSprite == 10) {
					cycles -= (0xA0 - 4 - oampos) >> 1;
					oampos = 0xA0 - 4;
				}
			}

			oampos += 4;
		} while ((cycles-=2) >= 0 && oampos != 0xA0);

		p.reg0 = oampos;
		p.nextSprite = nextSprite;
		p.cycles = cycles;

		if (oampos == 0xA0) {
			insertionSort(p.spriteList, p.spriteList + nextSprite, SpriteLess());
			p.spriteList[nextSprite].spx = 0xFF;
			p.nextSprite = 0;
			nextCall(0, M3Start::f0_, p);
		}
	}
}
*/

static int loadTileDataByte0(PPUPriv const &p) {
	unsigned const yoffset = p.winDrawState & win_draw_started
	                       ? p.winYPos
	                       : p.scy + p.lyCounter.ly();

	return p.vram[0x1000 + (p.nattrib << 10             & 0x2000)
	                     - ((p.reg1 * 32 | p.lcdc << 8) & 0x1000)
	                     + p.reg1 * 16
	                     + ((-(p.nattrib >> 6 & 1) ^ yoffset) & 7) * 2];
}

static int loadTileDataByte1(PPUPriv const &p) {
	unsigned const yoffset = p.winDrawState & win_draw_started
	                       ? p.winYPos
	                       : p.scy + p.lyCounter.ly();

	return p.vram[0x1000 + (p.nattrib << 10             & 0x2000)
	                     - ((p.reg1 * 32 | p.lcdc << 8) & 0x1000)
	                     + p.reg1 * 16
	                     + ((-(p.nattrib >> 6 & 1) ^ yoffset) & 7) * 2 + 1];
}

namespace M3Start {
	static void f0(PPUPriv &p) {
		p.xpos = 0;

		if ((p.winDrawState & win_draw_start) && lcdcWinEn(p)) {
			p.winDrawState = win_draw_started;
			p.wscx = 8 + (p.scx & 7);
			++p.winYPos;
		} else
			p.winDrawState = 0;

		p.nextCallPtr = &f1_;
		f1(p);
	}

	static void f1(PPUPriv &p) {
		while (p.xpos < max_m3start_cycles) {
			if ((p.xpos & 7) == (p.scx & 7))
				break;

			switch (p.xpos & 7) {
			case 0:
				if (p.winDrawState & win_draw_started) {
					p.reg1    = p.vram[(p.lcdc << 4 & 0x400) + (p.winYPos & 0xF8) * 4
					                 + (p.wscx >> 3 & 0x1F) + 0x1800];
					p.nattrib = p.vram[(p.lcdc << 4 & 0x400) + (p.winYPos & 0xF8) * 4
					                 + (p.wscx >> 3 & 0x1F) + 0x3800];
				} else {
					p.reg1    = p.vram[((p.lcdc << 7 | p.scx >> 3) & 0x41F)
					                 + ((p.scy + p.lyCounter.ly()) & 0xF8) * 4 + 0x1800];
					p.nattrib = p.vram[((p.lcdc << 7 | p.scx >> 3) & 0x41F)
					                 + ((p.scy + p.lyCounter.ly()) & 0xF8) * 4 + 0x3800];
				}

				break;
			case 2:
				p.reg0 = loadTileDataByte0(p);
				break;
			case 4:
				{
					int const r1 = loadTileDataByte1(p);
					p.ntileword = (expand_lut + (p.nattrib << 3 & 0x100))[p.reg0]
					            + (expand_lut + (p.nattrib << 3 & 0x100))[r1    ] * 2;
				}

				break;
			}

			++p.xpos;

			if (--p.cycles < 0)
				return;
		}

		{
			unsigned const ly = p.lyCounter.ly();
			unsigned const numSprites = p.spriteMapper.numSprites(ly);
			unsigned char const *const sprites = p.spriteMapper.sprites(ly);

			for (unsigned i = 0; i < numSprites; ++i) {
				unsigned pos = sprites[i];
				unsigned spy = p.spriteMapper.posbuf()[pos  ];
				unsigned spx = p.spriteMapper.posbuf()[pos+1];

				p.spriteList[i].spx    = spx;
				p.spriteList[i].line   = ly + 16u - spy;
				p.spriteList[i].oampos = pos * 2;
				p.spwordList[i] = 0;
			}

			p.spriteList[numSprites].spx = 0xFF;
			p.nextSprite = 0;
		}

		p.xpos = 0;
		p.endx = 8 - (p.scx & 7);

		static PPUState const *const flut[8] = {
			&M3Loop::Tile::f0_,
			&M3Loop::Tile::f1_,
			&M3Loop::Tile::f2_,
			&M3Loop::Tile::f3_,
			&M3Loop::Tile::f4_,
			&M3Loop::Tile::f5_,
			&M3Loop::Tile::f5_,
			&M3Loop::Tile::f5_
		};

		nextCall(1-p.cgb, *flut[p.scx & 7], p);
	}
}

namespace M3Loop {

static void doFullTilesUnrolledDmg(PPUPriv &p, int const xend, uint_least32_t *const dbufline,
		unsigned char const *const tileMapLine, unsigned const tileline, unsigned tileMapXpos) {
	unsigned const tileIndexSign = ~p.lcdc << 3 & 0x80;
	unsigned char const *const tileDataLine = p.vram + tileIndexSign * 32 + tileline * 2;
	int xpos = p.xpos;

	do {
		int nextSprite = p.nextSprite;

		if (int(p.spriteList[nextSprite].spx) < xpos + 8) {
			int cycles = p.cycles - 8;

			if (lcdcObjEn(p)) {
				cycles -= std::max(11 - (int(p.spriteList[nextSprite].spx) - xpos), 6);

				for (unsigned i = nextSprite + 1; int(p.spriteList[i].spx) < xpos + 8; ++i)
					cycles -= 6;

				if (cycles < 0)
					break;

				p.cycles = cycles;

				do {
					unsigned char const *const oam = p.spriteMapper.oamram();
					unsigned reg0, reg1   = oam[p.spriteList[nextSprite].oampos + 2] * 16;
					unsigned const attrib = oam[p.spriteList[nextSprite].oampos + 3];
					unsigned const spline = (  attrib & attr_yflip
					                         ? p.spriteList[nextSprite].line ^ 15
					                         : p.spriteList[nextSprite].line     ) * 2;

					reg0 = p.vram[(lcdcObj2x(p) ? (reg1 & ~16) | spline : reg1 | (spline & ~16))    ];
					reg1 = p.vram[(lcdcObj2x(p) ? (reg1 & ~16) | spline : reg1 | (spline & ~16)) + 1];

					p.spwordList[nextSprite] = expand_lut[reg0 + (attrib << 3 & 0x100)]
					                         + expand_lut[reg1 + (attrib << 3 & 0x100)] * 2;
					p.spriteList[nextSprite].attrib = attrib;
					++nextSprite;
				} while (int(p.spriteList[nextSprite].spx) < xpos + 8);
			} else {
				if (cycles < 0)
					break;

				p.cycles = cycles;

				do {
					++nextSprite;
				} while (int(p.spriteList[nextSprite].spx) < xpos + 8);
			}

			p.nextSprite = nextSprite;
		} else if (nextSprite-1 < 0 || int(p.spriteList[nextSprite-1].spx) <= xpos - 8) {
			if (!(p.cycles & ~7))
				break;

			int n = ((  xend + 7 < int(p.spriteList[nextSprite].spx)
			          ? xend + 7 : int(p.spriteList[nextSprite].spx)) - xpos) & ~7;
			n = (p.cycles & ~7) < n ? p.cycles & ~7 : n;
			p.cycles -= n;

			unsigned ntileword = p.ntileword;
			uint_least32_t *      dst    = dbufline + xpos - 8;
			uint_least32_t *const dstend = dst + n;
			xpos += n;

			if (!lcdcBgEn(p)) {
				do { *dst++ = p.bgPalette[0]; } while (dst != dstend);
				tileMapXpos += n >> 3;

				unsigned const tno = tileMapLine[(tileMapXpos - 1) & 0x1F];
				ntileword = expand_lut[(tileDataLine + tno * 16 - (tno & tileIndexSign) * 32)[0]]
				          + expand_lut[(tileDataLine + tno * 16 - (tno & tileIndexSign) * 32)[1]] * 2;
			} else do {
				dst[0] = p.bgPalette[ ntileword & 0x0003       ];
				dst[1] = p.bgPalette[(ntileword & 0x000C) >>  2];
				dst[2] = p.bgPalette[(ntileword & 0x0030) >>  4];
				dst[3] = p.bgPalette[(ntileword & 0x00C0) >>  6];
				dst[4] = p.bgPalette[(ntileword & 0x0300) >>  8];
				dst[5] = p.bgPalette[(ntileword & 0x0C00) >> 10];
				dst[6] = p.bgPalette[(ntileword & 0x3000) >> 12];
				dst[7] = p.bgPalette[ ntileword           >> 14];
				dst += 8;

				unsigned const tno = tileMapLine[tileMapXpos & 0x1F];
				tileMapXpos = (tileMapXpos & 0x1F) + 1;
				ntileword = expand_lut[(tileDataLine + tno * 16 - (tno & tileIndexSign) * 32)[0]]
				          + expand_lut[(tileDataLine + tno * 16 - (tno & tileIndexSign) * 32)[1]] * 2;
			} while (dst != dstend);

			p.ntileword = ntileword;
			continue;
		} else {
			int cycles = p.cycles - 8;
			if (cycles < 0)
				break;

			p.cycles = cycles;
		}

		{
			uint_least32_t *const dst = dbufline + (xpos - 8);
			unsigned const tileword = -(p.lcdc & 1U) & p.ntileword;

			dst[0] = p.bgPalette[ tileword & 0x0003       ];
			dst[1] = p.bgPalette[(tileword & 0x000C) >>  2];
			dst[2] = p.bgPalette[(tileword & 0x0030) >>  4];
			dst[3] = p.bgPalette[(tileword & 0x00C0) >>  6];
			dst[4] = p.bgPalette[(tileword & 0x0300) >>  8];
			dst[5] = p.bgPalette[(tileword & 0x0C00) >> 10];
			dst[6] = p.bgPalette[(tileword & 0x3000) >> 12];
			dst[7] = p.bgPalette[ tileword           >> 14];

			int i = nextSprite - 1;

			if (!lcdcObjEn(p)) {
				do {
					int pos = int(p.spriteList[i].spx) - xpos;
					p.spwordList[i] >>= pos * 2 >= 0 ? 16 - pos * 2 : 16 + pos * 2;
					--i;
				} while (i >= 0 && int(p.spriteList[i].spx) > xpos - 8);
			} else {
				do {
					int n;
					int pos = int(p.spriteList[i].spx) - xpos;
					if (pos < 0) {
						n = pos + 8;
						pos = 0;
					} else
						n = 8 - pos;

					unsigned const attrib = p.spriteList[i].attrib;
					unsigned spword       = p.spwordList[i];
					unsigned long const *const spPalette = p.spPalette + (attrib >> 2 & 4);
					uint_least32_t *d = dst + pos;

					if (!(attrib & attr_bgpriority)) {
						switch (n) {
						case 8: if (spword >> 14    ) { d[7] = spPalette[spword >> 14    ]; }
						case 7: if (spword >> 12 & 3) { d[6] = spPalette[spword >> 12 & 3]; }
						case 6: if (spword >> 10 & 3) { d[5] = spPalette[spword >> 10 & 3]; }
						case 5: if (spword >>  8 & 3) { d[4] = spPalette[spword >>  8 & 3]; }
						case 4: if (spword >>  6 & 3) { d[3] = spPalette[spword >>  6 & 3]; }
						case 3: if (spword >>  4 & 3) { d[2] = spPalette[spword >>  4 & 3]; }
						case 2: if (spword >>  2 & 3) { d[1] = spPalette[spword >>  2 & 3]; }
						case 1: if (spword       & 3) { d[0] = spPalette[spword       & 3]; }
						}

						spword >>= n * 2;

						/*do {
							if (spword & 3)
								dst[pos] = spPalette[spword & 3];

							spword >>= 2;
							++pos;
						} while (--n);*/
					} else {
						unsigned tw = tileword >> pos * 2;
						d += n;
						n = -n;

						do {
							if (spword & 3) {
								d[n] = tw & 3
								     ? p.bgPalette[    tw & 3]
								     :   spPalette[spword & 3];
							}

							spword >>= 2;
							tw     >>= 2;
						} while (++n);
					}

					p.spwordList[i] = spword;
					--i;
				} while (i >= 0 && int(p.spriteList[i].spx) > xpos - 8);
			}
		}

		unsigned const tno = tileMapLine[tileMapXpos & 0x1F];
		tileMapXpos = (tileMapXpos & 0x1F) + 1;
		p.ntileword = expand_lut[(tileDataLine + tno * 16 - (tno & tileIndexSign) * 32)[0]]
		            + expand_lut[(tileDataLine + tno * 16 - (tno & tileIndexSign) * 32)[1]] * 2;

		xpos = xpos + 8;
	} while (xpos < xend);

	p.xpos = xpos;
}

static void doFullTilesUnrolledCgb(PPUPriv &p, int const xend, uint_least32_t *const dbufline,
		unsigned char const *const tileMapLine, unsigned const tileline, unsigned tileMapXpos) {
	int xpos = p.xpos;
	unsigned char const *const vram = p.vram;
	unsigned const tdoffset = tileline * 2 + (~p.lcdc & 0x10) * 0x100;

	do {
		int nextSprite = p.nextSprite;

		if (int(p.spriteList[nextSprite].spx) < xpos + 8) {
			int cycles = p.cycles - 8;
			cycles -= std::max(11 - (int(p.spriteList[nextSprite].spx) - xpos), 6);

			for (unsigned i = nextSprite + 1; int(p.spriteList[i].spx) < xpos + 8; ++i)
				cycles -= 6;

			if (cycles < 0)
				break;

			p.cycles = cycles;

			do {
				unsigned char const *const oam = p.spriteMapper.oamram();
				unsigned reg0, reg1   = oam[p.spriteList[nextSprite].oampos + 2] * 16;
				unsigned const attrib = oam[p.spriteList[nextSprite].oampos + 3];
				unsigned const spline = (  attrib & attr_yflip
				                         ? p.spriteList[nextSprite].line ^ 15
				                         : p.spriteList[nextSprite].line     ) * 2;

				reg0 = vram[(attrib << 10 & 0x2000)
				          + (lcdcObj2x(p) ? (reg1 & ~16) | spline : reg1 | (spline & ~16))    ];
				reg1 = vram[(attrib << 10 & 0x2000)
				          + (lcdcObj2x(p) ? (reg1 & ~16) | spline : reg1 | (spline & ~16)) + 1];

				p.spwordList[nextSprite] = expand_lut[reg0 + (attrib << 3 & 0x100)]
				                         + expand_lut[reg1 + (attrib << 3 & 0x100)] * 2;
				p.spriteList[nextSprite].attrib = attrib;
				++nextSprite;
			} while (int(p.spriteList[nextSprite].spx) < xpos + 8);

			p.nextSprite = nextSprite;
		} else if (nextSprite-1 < 0 || int(p.spriteList[nextSprite-1].spx) <= xpos - 8) {
			if (!(p.cycles & ~7))
				break;

			int n = ((  xend + 7 < int(p.spriteList[nextSprite].spx)
			          ? xend + 7 : int(p.spriteList[nextSprite].spx)) - xpos) & ~7;
			n = (p.cycles & ~7) < n ? p.cycles & ~7 : n;
			p.cycles -= n;

			unsigned ntileword = p.ntileword;
			unsigned nattrib   = p.nattrib;
			uint_least32_t *      dst    = dbufline + xpos - 8;
			uint_least32_t *const dstend = dst + n;
			xpos += n;

			do {
				unsigned long const *const bgPalette = p.bgPalette + (nattrib & 7) * 4;
				dst[0] = bgPalette[ ntileword & 0x0003       ];
				dst[1] = bgPalette[(ntileword & 0x000C) >>  2];
				dst[2] = bgPalette[(ntileword & 0x0030) >>  4];
				dst[3] = bgPalette[(ntileword & 0x00C0) >>  6];
				dst[4] = bgPalette[(ntileword & 0x0300) >>  8];
				dst[5] = bgPalette[(ntileword & 0x0C00) >> 10];
				dst[6] = bgPalette[(ntileword & 0x3000) >> 12];
				dst[7] = bgPalette[ ntileword           >> 14];
				dst += 8;

				unsigned const tno = tileMapLine[ tileMapXpos & 0x1F          ];
				nattrib            = tileMapLine[(tileMapXpos & 0x1F) + 0x2000];
				tileMapXpos = (tileMapXpos & 0x1F) + 1;

				unsigned const tdo = tdoffset & ~(tno << 5);
				unsigned char const *const td = vram + tno * 16
				                                     + (nattrib & attr_yflip ? tdo ^ 14 : tdo)
				                                     + (nattrib << 10 & 0x2000);
				unsigned short const *const explut = expand_lut + (nattrib << 3 & 0x100);
				ntileword = explut[td[0]] + explut[td[1]] * 2;
			} while (dst != dstend);

			p.ntileword = ntileword;
			p.nattrib   = nattrib;
			continue;
		} else {
			int cycles = p.cycles - 8;

			if (cycles < 0)
				break;

			p.cycles = cycles;
		}

		{
			uint_least32_t *const dst = dbufline + (xpos - 8);
			unsigned const tileword = p.ntileword;
			unsigned const attrib   = p.nattrib;
			unsigned long const *const bgPalette = p.bgPalette + (attrib & 7) * 4;

			dst[0] = bgPalette[ tileword & 0x0003       ];
			dst[1] = bgPalette[(tileword & 0x000C) >>  2];
			dst[2] = bgPalette[(tileword & 0x0030) >>  4];
			dst[3] = bgPalette[(tileword & 0x00C0) >>  6];
			dst[4] = bgPalette[(tileword & 0x0300) >>  8];
			dst[5] = bgPalette[(tileword & 0x0C00) >> 10];
			dst[6] = bgPalette[(tileword & 0x3000) >> 12];
			dst[7] = bgPalette[ tileword           >> 14];

			int i = nextSprite - 1;

			if (!lcdcObjEn(p)) {
				do {
					int pos = int(p.spriteList[i].spx) - xpos;
					p.spwordList[i] >>= pos * 2 >= 0 ? 16 - pos * 2 : 16 + pos * 2;
					--i;
				} while (i >= 0 && int(p.spriteList[i].spx) > xpos - 8);
			} else {
				unsigned char idtab[8] = { 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF };
				unsigned const bgprioritymask = p.lcdc << 7;

				do {
					int n;
					int pos = int(p.spriteList[i].spx) - xpos;

					if (pos < 0) {
						n = pos + 8;
						pos = 0;
					} else
						n = 8 - pos;

					unsigned char const id = p.spriteList[i].oampos;
					unsigned const sattrib = p.spriteList[i].attrib;
					unsigned spword        = p.spwordList[i];
					unsigned long const *const spPalette = p.spPalette + (sattrib & 7) * 4;

					if (!((attrib | sattrib) & bgprioritymask)) {
						unsigned char  *const idt = idtab + pos;
						uint_least32_t *const   d =   dst + pos;

						switch (n) {
						case 8: if ((spword >> 14    ) && id < idt[7]) {
						        	idt[7] = id;
						        	  d[7] = spPalette[spword >> 14    ];
						        }
						case 7: if ((spword >> 12 & 3) && id < idt[6]) {
						        	idt[6] = id;
						        	  d[6] = spPalette[spword >> 12 & 3];
						        }
						case 6: if ((spword >> 10 & 3) && id < idt[5]) {
						        	idt[5] = id;
						        	  d[5] = spPalette[spword >> 10 & 3];
						        }
						case 5: if ((spword >>  8 & 3) && id < idt[4]) {
						        	idt[4] = id;
						        	  d[4] = spPalette[spword >>  8 & 3];
						        }
						case 4: if ((spword >>  6 & 3) && id < idt[3]) {
						        	idt[3] = id;
						        	  d[3] = spPalette[spword >>  6 & 3];
						        }
						case 3: if ((spword >>  4 & 3) && id < idt[2]) {
						        	idt[2] = id;
						        	  d[2] = spPalette[spword >>  4 & 3];
						        }
						case 2: if ((spword >>  2 & 3) && id < idt[1]) {
						        	idt[1] = id;
						        	  d[1] = spPalette[spword >>  2 & 3];
						        }
						case 1: if ((spword       & 3) && id < idt[0]) {
						        	idt[0] = id;
						        	  d[0] = spPalette[spword       & 3];
						        }
						}

						spword >>= n * 2;

						/*do {
							if ((spword & 3) && id < idtab[pos]) {
								idtab[pos] = id;
									dst[pos] = spPalette[spword & 3];
							}

							spword >>= 2;
							++pos;
						} while (--n);*/
					} else {
						unsigned tw = tileword >> pos * 2;

						do {
							if ((spword & 3) && id < idtab[pos]) {
								idtab[pos] = id;
								  dst[pos] = tw & 3
								           ? bgPalette[    tw & 3]
								           : spPalette[spword & 3];
							}

							spword >>= 2;
							tw     >>= 2;
							++pos;
						} while (--n);
					}

					p.spwordList[i] = spword;
					--i;
				} while (i >= 0 && int(p.spriteList[i].spx) > xpos - 8);
			}
		}

		{
			unsigned const tno     = tileMapLine[ tileMapXpos & 0x1F          ];
			unsigned const nattrib = tileMapLine[(tileMapXpos & 0x1F) + 0x2000];
			tileMapXpos = (tileMapXpos & 0x1F) + 1;

			unsigned const tdo = tdoffset & ~(tno << 5);
			unsigned char const *const td = vram + tno * 16
			                                     + (nattrib & attr_yflip ? tdo ^ 14 : tdo)
			                                     + (nattrib << 10 & 0x2000);
			unsigned short const *const explut = expand_lut + (nattrib << 3 & 0x100);
			p.ntileword = explut[td[0]] + explut[td[1]] * 2;
			p.nattrib   = nattrib;
		}

		xpos = xpos + 8;
	} while (xpos < xend);

	p.xpos = xpos;
}

static void doFullTilesUnrolled(PPUPriv &p) {
	int xpos = p.xpos;
	int const xend = static_cast<int>(p.wx) < xpos || p.wx >= 168
	               ? 161
	               : static_cast<int>(p.wx) - 7;
	if (xpos >= xend)
		return;

	uint_least32_t *const dbufline = p.framebuf.fbline();
	unsigned char const *tileMapLine;
	unsigned tileline;
	unsigned tileMapXpos;

	if (p.winDrawState & win_draw_started) {
		tileMapLine = p.vram + (p.lcdc << 4 & 0x400)
		                     + (p.winYPos & 0xF8) * 4 + 0x1800;
		tileMapXpos = (xpos + p.wscx) >> 3;
		tileline    = p.winYPos & 7;
	} else {
		tileMapLine = p.vram + (p.lcdc << 7 & 0x400)
		                     + ((p.scy + p.lyCounter.ly()) & 0xF8) * 4 + 0x1800;
		tileMapXpos = (p.scx + xpos + 1 - p.cgb) >> 3;
		tileline    = (p.scy + p.lyCounter.ly()) & 7;
	}

	if (xpos < 8) {
		uint_least32_t prebuf[16];

		if (p.cgb) {
			doFullTilesUnrolledCgb(p, xend < 8 ? xend : 8, prebuf + (8 - xpos),
			                       tileMapLine, tileline, tileMapXpos);
		} else {
			doFullTilesUnrolledDmg(p, xend < 8 ? xend : 8, prebuf + (8 - xpos),
			                       tileMapLine, tileline, tileMapXpos);
		}

		int const newxpos = p.xpos;

		if (newxpos > 8) {
			std::memcpy(dbufline, prebuf + (8 - xpos), (newxpos - 8) * sizeof *dbufline);
		} else if (newxpos < 8)
			return;

		if (newxpos >= xend)
			return;

		tileMapXpos += (newxpos - xpos) >> 3;
	}

	if (p.cgb) {
		doFullTilesUnrolledCgb(p, xend, dbufline, tileMapLine, tileline, tileMapXpos);
	} else
		doFullTilesUnrolledDmg(p, xend, dbufline, tileMapLine, tileline, tileMapXpos);
}

static void plotPixel(PPUPriv &p) {
	int const xpos = p.xpos;
	unsigned const tileword = p.tileword;
	uint_least32_t *const fbline = p.framebuf.fbline();

	if (static_cast<int>(p.wx) == xpos
			&& (p.weMaster || (p.wy2 == p.lyCounter.ly() && lcdcWinEn(p)))
			&& xpos < 167) {
		if (p.winDrawState == 0 && lcdcWinEn(p)) {
			p.winDrawState = win_draw_start | win_draw_started;
			++p.winYPos;
		} else if (!p.cgb && (p.winDrawState == 0 || xpos == 166))
			p.winDrawState |= win_draw_start;
	}

	unsigned const twdata = tileword & ((p.lcdc & 1) | p.cgb) * 3;
	unsigned long pixel = p.bgPalette[twdata + (p.attrib & 7) * 4];
	int i = static_cast<int>(p.nextSprite) - 1;

	if (i >= 0 && int(p.spriteList[i].spx) > xpos - 8) {
		unsigned spdata = 0;
		unsigned attrib = 0;

		if (p.cgb) {
			unsigned minId = 0xFF;

			do {
				if ((p.spwordList[i] & 3) && p.spriteList[i].oampos < minId) {
					spdata = p.spwordList[i] & 3;
					attrib = p.spriteList[i].attrib;
					minId  = p.spriteList[i].oampos;
				}

				p.spwordList[i] >>= 2;
				--i;
			} while (i >= 0 && int(p.spriteList[i].spx) > xpos - 8);

			if (spdata && lcdcObjEn(p)
					&& (!((attrib | p.attrib) & attr_bgpriority) || !twdata || !lcdcBgEn(p))) {
				pixel = p.spPalette[(attrib & 7) * 4 + spdata];
			}
		} else {
			do {
				if (p.spwordList[i] & 3) {
					spdata = p.spwordList[i] & 3;
					attrib = p.spriteList[i].attrib;
				}

				p.spwordList[i] >>= 2;
				--i;
			} while (i >= 0 && int(p.spriteList[i].spx) > xpos - 8);

			if (spdata && lcdcObjEn(p) && (!(attrib & attr_bgpriority) || !twdata))
				pixel = p.spPalette[(attrib >> 2 & 4) + spdata];
		}
	}

	if (xpos - 8 >= 0)
		fbline[xpos - 8] = pixel;

	p.xpos = xpos + 1;
	p.tileword = tileword >> 2;
}

static void plotPixelIfNoSprite(PPUPriv &p) {
	if (p.spriteList[p.nextSprite].spx == p.xpos) {
		if (!(lcdcObjEn(p) | p.cgb)) {
			do {
				++p.nextSprite;
			} while (p.spriteList[p.nextSprite].spx == p.xpos);

			plotPixel(p);
		}
	} else
		plotPixel(p);
}

static unsigned long nextM2Time(PPUPriv const &p) {
	unsigned long nextm2 = p.lyCounter.isDoubleSpeed()
		? p.lyCounter.time() + (weMasterCheckPriorToLyIncLineCycle(true ) + m2_ds_offset) * 2 - 456 * 2
		: p.lyCounter.time() +  weMasterCheckPriorToLyIncLineCycle(p.cgb)                     - 456    ;
	if (p.lyCounter.ly() == 143)
		nextm2 += (456 * 10 + 456 - weMasterCheckPriorToLyIncLineCycle(p.cgb)) << p.lyCounter.isDoubleSpeed();

	return nextm2;
}

static void xpos168(PPUPriv &p) {
	p.lastM0Time = p.now - (p.cycles << p.lyCounter.isDoubleSpeed());

	unsigned long const nextm2 = nextM2Time(p);

	p.cycles = p.now >= nextm2
		?  long((p.now - nextm2) >> p.lyCounter.isDoubleSpeed())
		: -long((nextm2 - p.now) >> p.lyCounter.isDoubleSpeed());

	nextCall(0, p.lyCounter.ly() == 143 ? M2_Ly0::f0_ : M2_LyNon0::f0_, p);
}

static bool handleWinDrawStartReq(PPUPriv const &p, int const xpos, unsigned char &winDrawState) {
	bool const startWinDraw = (xpos < 167 || p.cgb)
	                       && (winDrawState &= win_draw_started);
	if (!lcdcWinEn(p))
		winDrawState &= ~win_draw_started;

	return startWinDraw;
}

static bool handleWinDrawStartReq(PPUPriv &p) {
	return handleWinDrawStartReq(p, p.xpos, p.winDrawState);
}

namespace StartWindowDraw {
	static void inc(PPUState const &nextf, PPUPriv &p) {
		if (!lcdcWinEn(p) && p.cgb) {
			plotPixelIfNoSprite(p);

			if (p.xpos == p.endx) {
				if (p.xpos < 168) {
					nextCall(1, Tile::f0_, p);
				} else
					xpos168(p);

				return;
			}
		}

		nextCall(1, nextf, p);
	}

	static void f0(PPUPriv &p) {
		if (p.xpos == p.endx) {
			p.tileword = p.ntileword;
			p.attrib   = p.nattrib;
			p.endx = p.xpos < 160 ? p.xpos + 8 : 168;
		}

		p.wscx = 8 - p.xpos;

		if (p.winDrawState & win_draw_started) {
			p.reg1    = p.vram[(p.lcdc << 4 & 0x400)
			                 + (p.winYPos & 0xF8) * 4 + 0x1800];
			p.nattrib = p.vram[(p.lcdc << 4 & 0x400)
			                 + (p.winYPos & 0xF8) * 4 + 0x3800];
		} else {
			p.reg1    = p.vram[(p.lcdc << 7 & 0x400)
			                 + ((p.scy + p.lyCounter.ly()) & 0xF8) * 4 + 0x1800];
			p.nattrib = p.vram[(p.lcdc << 7 & 0x400)
			                 + ((p.scy + p.lyCounter.ly()) & 0xF8) * 4 + 0x3800];
		}

		inc(f1_, p);
	}

	static void f1(PPUPriv &p) {
		inc(f2_, p);
	}

	static void f2(PPUPriv &p) {
		p.reg0 = loadTileDataByte0(p);
		inc(f3_, p);
	}

	static void f3(PPUPriv &p) {
		inc(f4_, p);
	}

	static void f4(PPUPriv &p) {
		int const r1 = loadTileDataByte1(p);

		p.ntileword = (expand_lut + (p.nattrib << 3 & 0x100))[p.reg0]
		            + (expand_lut + (p.nattrib << 3 & 0x100))[r1    ] * 2;

		inc(f5_, p);
	}

	static void f5(PPUPriv &p) {
		inc(Tile::f0_, p);
	}
}

namespace LoadSprites {
	static void inc(PPUState const &nextf, PPUPriv &p) {
		plotPixelIfNoSprite(p);

		if (p.xpos == p.endx) {
			if (p.xpos < 168) {
				nextCall(1, Tile::f0_, p);
			} else
				xpos168(p);
		} else
			nextCall(1, nextf, p);
	}

	static void f0(PPUPriv &p) {
		p.reg1 = p.spriteMapper.oamram()[p.spriteList[p.currentSprite].oampos + 2];
		nextCall(1, f1_, p);
	}

	static void f1(PPUPriv &p) {
		if ((p.winDrawState & win_draw_start) && handleWinDrawStartReq(p))
			return StartWindowDraw::f0(p);

		p.spriteList[p.currentSprite].attrib =
			p.spriteMapper.oamram()[p.spriteList[p.currentSprite].oampos + 3];
		inc(f2_, p);
	}

	static void f2(PPUPriv &p) {
		if ((p.winDrawState & win_draw_start) && handleWinDrawStartReq(p))
			return StartWindowDraw::f0(p);

		unsigned const spline =
			(  p.spriteList[p.currentSprite].attrib & attr_yflip
			 ? p.spriteList[p.currentSprite].line ^ 15
			 : p.spriteList[p.currentSprite].line         ) * 2;
		p.reg0 = p.vram[(p.spriteList[p.currentSprite].attrib << 10 & p.cgb * 0x2000)
		              + (lcdcObj2x(p) ? (p.reg1 * 16 & ~16) | spline : p.reg1 * 16 | (spline & ~16))];
		inc(f3_, p);
	}

	static void f3(PPUPriv &p) {
		if ((p.winDrawState & win_draw_start) && handleWinDrawStartReq(p))
			return StartWindowDraw::f0(p);

		inc(f4_, p);
	}

	static void f4(PPUPriv &p) {
		if ((p.winDrawState & win_draw_start) && handleWinDrawStartReq(p))
			return StartWindowDraw::f0(p);

		unsigned const spline =
			(  p.spriteList[p.currentSprite].attrib & attr_yflip
			 ? p.spriteList[p.currentSprite].line ^ 15
			 : p.spriteList[p.currentSprite].line         ) * 2;
		p.reg1 = p.vram[(p.spriteList[p.currentSprite].attrib << 10 & p.cgb * 0x2000)
		              + (lcdcObj2x(p) ? (p.reg1 * 16 & ~16) | spline : p.reg1 * 16 | (spline & ~16)) + 1];
		inc(f5_, p);
	}

	static void f5(PPUPriv &p) {
		if ((p.winDrawState & win_draw_start) && handleWinDrawStartReq(p))
			return StartWindowDraw::f0(p);

		plotPixelIfNoSprite(p);

		unsigned entry = p.currentSprite;

		if (entry == p.nextSprite) {
			++p.nextSprite;
		} else {
			entry = p.nextSprite - 1;
			p.spriteList[entry] = p.spriteList[p.currentSprite];
		}

		p.spwordList[entry] = expand_lut[p.reg0 + (p.spriteList[entry].attrib << 3 & 0x100)]
		                    + expand_lut[p.reg1 + (p.spriteList[entry].attrib << 3 & 0x100)] * 2;
		p.spriteList[entry].spx = p.xpos;

		if (p.xpos == p.endx) {
			if (p.xpos < 168) {
				nextCall(1, Tile::f0_, p);
			} else
				xpos168(p);
		} else {
			p.nextCallPtr = &Tile::f5_;
			nextCall(1, Tile::f5_, p);
		}
	}
}

namespace Tile {
	static void inc(PPUState const &nextf, PPUPriv &p) {
		plotPixelIfNoSprite(p);

		if (p.xpos == 168) {
			xpos168(p);
		} else
			nextCall(1, nextf, p);
	}

	static void f0(PPUPriv &p) {
		if ((p.winDrawState & win_draw_start) && handleWinDrawStartReq(p))
			return StartWindowDraw::f0(p);

		doFullTilesUnrolled(p);

		if (p.xpos == 168) {
			++p.cycles;
			return xpos168(p);
		}

		p.tileword = p.ntileword;
		p.attrib   = p.nattrib;
		p.endx = p.xpos < 160 ? p.xpos + 8 : 168;

		if (p.winDrawState & win_draw_started) {
			p.reg1    = p.vram[(p.lcdc << 4 & 0x400)
			                 + (p.winYPos & 0xF8) * 4
			                 + ((p.xpos + p.wscx) >> 3 & 0x1F) + 0x1800];
			p.nattrib = p.vram[(p.lcdc << 4 & 0x400)
			                 + (p.winYPos & 0xF8) * 4
			                 + ((p.xpos + p.wscx) >> 3 & 0x1F) + 0x3800];
		} else {
			p.reg1    = p.vram[((p.lcdc << 7 | (p.scx + p.xpos + 1 - p.cgb) >> 3) & 0x41F)
			                 + ((p.scy + p.lyCounter.ly()) & 0xF8) * 4 + 0x1800];
			p.nattrib = p.vram[((p.lcdc << 7 | (p.scx + p.xpos + 1 - p.cgb) >> 3) & 0x41F)
			                 + ((p.scy + p.lyCounter.ly()) & 0xF8) * 4 + 0x3800];
		}

		inc(f1_, p);
	}

	static void f1(PPUPriv &p) {
		if ((p.winDrawState & win_draw_start) && handleWinDrawStartReq(p))
			return StartWindowDraw::f0(p);

		inc(f2_, p);
	}

	static void f2(PPUPriv &p) {
		if ((p.winDrawState & win_draw_start) && handleWinDrawStartReq(p))
			return StartWindowDraw::f0(p);

		p.reg0 = loadTileDataByte0(p);
		inc(f3_, p);
	}

	static void f3(PPUPriv &p) {
		if ((p.winDrawState & win_draw_start) && handleWinDrawStartReq(p))
			return StartWindowDraw::f0(p);

		inc(f4_, p);
	}

	static void f4(PPUPriv &p) {
		if ((p.winDrawState & win_draw_start) && handleWinDrawStartReq(p))
			return StartWindowDraw::f0(p);

		int const r1 = loadTileDataByte1(p);

		p.ntileword = (expand_lut + (p.nattrib << 3 & 0x100))[p.reg0]
		            + (expand_lut + (p.nattrib << 3 & 0x100))[r1    ] * 2;

		plotPixelIfNoSprite(p);

		if (p.xpos == 168) {
			xpos168(p);
		} else
			nextCall(1, f5_, p);
	}

	static void f5(PPUPriv &p) {
		int endx = p.endx;
		p.nextCallPtr = &f5_;

		do {
			if ((p.winDrawState & win_draw_start) && handleWinDrawStartReq(p))
				return StartWindowDraw::f0(p);

			if (p.spriteList[p.nextSprite].spx == p.xpos) {
				if (lcdcObjEn(p) | p.cgb) {
					p.currentSprite = p.nextSprite;
					return LoadSprites::f0(p);
				}

				do {
					++p.nextSprite;
				} while (p.spriteList[p.nextSprite].spx == p.xpos);
			}

			plotPixel(p);

			if (p.xpos == endx) {
				if (endx < 168) {
					nextCall(1, f0_, p);
				} else
					xpos168(p);

				return;
			}
		} while (--p.cycles >= 0);
	}
}

} // namespace M3Loop

namespace M2_Ly0 {
	static unsigned predictCyclesUntilXpos_f0(PPUPriv const &p, unsigned winDrawState,
	                                          int targetxpos, unsigned cycles);
}

namespace M2_LyNon0 {
	static unsigned predictCyclesUntilXpos_f0(PPUPriv const &p, unsigned winDrawState,
	                                          int targetxpos, unsigned cycles);
}

namespace M3Loop {

static unsigned predictCyclesUntilXposNextLine(
		PPUPriv const &p, unsigned winDrawState, int const targetx) {
	if (p.wx == 166 && !p.cgb && p.xpos < 167
			&& (p.weMaster || (p.wy2 == p.lyCounter.ly() && lcdcWinEn(p)))) {
		winDrawState = win_draw_start | (lcdcWinEn(p) ? win_draw_started : 0);
	}

	unsigned const cycles = (nextM2Time(p) - p.now) >> p.lyCounter.isDoubleSpeed();

	return p.lyCounter.ly() == 143
	     ?    M2_Ly0::predictCyclesUntilXpos_f0(p, winDrawState, targetx, cycles)
	     : M2_LyNon0::predictCyclesUntilXpos_f0(p, winDrawState, targetx, cycles);
}

namespace StartWindowDraw {
	static unsigned predictCyclesUntilXpos_fn(PPUPriv const &p, int xpos,
		int endx, unsigned ly, unsigned nextSprite, bool weMaster,
		unsigned winDrawState, int fno, int targetx, unsigned cycles);
}

namespace Tile {
	static unsigned char const * addSpriteCycles(unsigned char const *nextSprite,
			unsigned char const *spriteEnd, unsigned char const *const spxOf,
			unsigned const maxSpx, unsigned const firstTileXpos,
			unsigned prevSpriteTileNo, unsigned *const cyclesAccumulator) {
		unsigned sum = 0;

		while (nextSprite < spriteEnd && spxOf[*nextSprite] <= maxSpx) {
			unsigned cycles = 6;
			unsigned const distanceFromTileStart = (spxOf[*nextSprite] - firstTileXpos) &  7;
			unsigned const tileNo                = (spxOf[*nextSprite] - firstTileXpos) & ~7;

			if (distanceFromTileStart < 5 && tileNo != prevSpriteTileNo)
				cycles = 11 - distanceFromTileStart;

			prevSpriteTileNo = tileNo;
			sum += cycles;
			++nextSprite;
		}

		*cyclesAccumulator += sum;

		return nextSprite;
	}

	static unsigned predictCyclesUntilXpos_fn(PPUPriv const &p, int const xpos,
			int const endx, unsigned const ly, unsigned const nextSprite,
			bool const weMaster, unsigned char winDrawState, int const fno,
			int const targetx, unsigned cycles) {
		if ((winDrawState & win_draw_start)
				&& handleWinDrawStartReq(p, xpos, winDrawState)) {
			return StartWindowDraw::predictCyclesUntilXpos_fn(p, xpos, endx,
				ly, nextSprite, weMaster, winDrawState, 0, targetx, cycles);
		}

		if (xpos > targetx)
			return predictCyclesUntilXposNextLine(p, winDrawState, targetx);

		enum { NO_TILE_NUMBER = 1 }; // low bit set, so it will never be equal to an actual tile number.

		int nwx = 0xFF;
		cycles += targetx - xpos;

		if (p.wx - unsigned(xpos) < targetx - unsigned(xpos)
				&& lcdcWinEn(p) && (weMaster || p.wy2 == ly)
				&& !(winDrawState & win_draw_started)
				&& (p.cgb || p.wx != 166)) {
			nwx = p.wx;
			cycles += 6;
		}

		if (lcdcObjEn(p) | p.cgb) {
			unsigned char const *sprite = p.spriteMapper.sprites(ly);
			unsigned char const *const spriteEnd = sprite + p.spriteMapper.numSprites(ly);
			sprite += nextSprite;

			if (sprite < spriteEnd) {
				int const spx = p.spriteMapper.posbuf()[*sprite + 1];
				unsigned firstTileXpos = endx & 7u; // ok even if endx is capped at 168,
				                                    // because fno will be used.
				unsigned prevSpriteTileNo = (xpos - firstTileXpos) & ~7; // this tile. all sprites on this
				                                                         // tile will now add 6 cycles.
				// except this one
				if (fno + spx - xpos < 5 && spx <= nwx) {
					cycles += 11 - (fno + spx - xpos);
					sprite += 1;
				}

				if (nwx < targetx) {
					sprite = addSpriteCycles(sprite, spriteEnd, p.spriteMapper.posbuf() + 1,
					                         nwx, firstTileXpos, prevSpriteTileNo, &cycles);
					firstTileXpos = nwx + 1;
					prevSpriteTileNo = NO_TILE_NUMBER;
				}

				addSpriteCycles(sprite, spriteEnd, p.spriteMapper.posbuf() + 1,
				                targetx, firstTileXpos, prevSpriteTileNo, &cycles);
			}
		}

		return cycles;
	}

	static unsigned predictCyclesUntilXpos_fn(PPUPriv const &p,
			int endx, int fno, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_fn(p, p.xpos, endx, p.lyCounter.ly(),
			p.nextSprite, p.weMaster, p.winDrawState, fno, targetx, cycles);
	}

	static unsigned predictCyclesUntilXpos_f0(PPUPriv const &p, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_fn(p, p.xpos < 160 ? p.xpos + 8 : 168, 0, targetx, cycles);
	}
	static unsigned predictCyclesUntilXpos_f1(PPUPriv const &p, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_fn(p, p.endx, 1, targetx, cycles);
	}
	static unsigned predictCyclesUntilXpos_f2(PPUPriv const &p, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_fn(p, p.endx, 2, targetx, cycles);
	}
	static unsigned predictCyclesUntilXpos_f3(PPUPriv const &p, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_fn(p, p.endx, 3, targetx, cycles);
	}
	static unsigned predictCyclesUntilXpos_f4(PPUPriv const &p, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_fn(p, p.endx, 4, targetx, cycles);
	}
	static unsigned predictCyclesUntilXpos_f5(PPUPriv const &p, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_fn(p, p.endx, 5, targetx, cycles);
	}
}

namespace StartWindowDraw {
	static unsigned predictCyclesUntilXpos_fn(PPUPriv const &p, int xpos,
			int const endx, unsigned const ly, unsigned const nextSprite, bool const weMaster,
			unsigned const winDrawState, int const fno, int const targetx, unsigned cycles) {
		if (xpos > targetx)
			return predictCyclesUntilXposNextLine(p, winDrawState, targetx);

		unsigned cinc = 6 - fno;

		if (!lcdcWinEn(p) && p.cgb) {
			unsigned xinc = std::min<int>(cinc, std::min(endx, targetx + 1) - xpos);

			if ((lcdcObjEn(p) | p.cgb) && p.spriteList[nextSprite].spx < xpos + xinc) {
				xpos = p.spriteList[nextSprite].spx;
			} else {
				cinc = xinc;
				xpos += xinc;
			}
		}

		cycles += cinc;

		if (xpos <= targetx) {
			return Tile::predictCyclesUntilXpos_fn(p, xpos, xpos < 160 ? xpos + 8 : 168,
				ly, nextSprite, weMaster, winDrawState, 0, targetx, cycles);
		}

		return cycles - 1;
	}

	static unsigned predictCyclesUntilXpos_fn(PPUPriv const &p,
			int endx, int fno, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_fn(p, p.xpos, endx, p.lyCounter.ly(),
			p.nextSprite, p.weMaster, p.winDrawState, fno, targetx, cycles);
	}

	static unsigned predictCyclesUntilXpos_f0(PPUPriv const &p, int targetx, unsigned cycles) {
		int endx = p.xpos == p.endx
		         ? (p.xpos < 160 ? p.xpos + 8 : 168)
		         : p.endx;
		return predictCyclesUntilXpos_fn(p, endx, 0, targetx, cycles);
	}
	static unsigned predictCyclesUntilXpos_f1(PPUPriv const &p, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_fn(p, p.endx, 1, targetx, cycles);
	}
	static unsigned predictCyclesUntilXpos_f2(PPUPriv const &p, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_fn(p, p.endx, 2, targetx, cycles);
	}
	static unsigned predictCyclesUntilXpos_f3(PPUPriv const &p, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_fn(p, p.endx, 3, targetx, cycles);
	}
	static unsigned predictCyclesUntilXpos_f4(PPUPriv const &p, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_fn(p, p.endx, 4, targetx, cycles);
	}
	static unsigned predictCyclesUntilXpos_f5(PPUPriv const &p, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_fn(p, p.endx, 5, targetx, cycles);
	}
}

namespace LoadSprites {
	static unsigned predictCyclesUntilXpos_fn(PPUPriv const &p,
			int const fno, int const targetx, unsigned cycles) {
		unsigned nextSprite = p.nextSprite;
		if (lcdcObjEn(p) | p.cgb) {
			cycles += 6 - fno;
			nextSprite += 1;
		}

		return Tile::predictCyclesUntilXpos_fn(p, p.xpos, p.endx, p.lyCounter.ly(),
			nextSprite, p.weMaster, p.winDrawState, 5, targetx, cycles);
	}

	static unsigned predictCyclesUntilXpos_f0(PPUPriv const &p, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_fn(p, 0, targetx, cycles);
	}
	static unsigned predictCyclesUntilXpos_f1(PPUPriv const &p, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_fn(p, 1, targetx, cycles);
	}
	static unsigned predictCyclesUntilXpos_f2(PPUPriv const &p, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_fn(p, 2, targetx, cycles);
	}
	static unsigned predictCyclesUntilXpos_f3(PPUPriv const &p, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_fn(p, 3, targetx, cycles);
	}
	static unsigned predictCyclesUntilXpos_f4(PPUPriv const &p, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_fn(p, 4, targetx, cycles);
	}
	static unsigned predictCyclesUntilXpos_f5(PPUPriv const &p, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_fn(p, 5, targetx, cycles);
	}
}

} // namespace M3Loop

namespace M3Start {
	static unsigned predictCyclesUntilXpos_f1(PPUPriv const &p, unsigned xpos, unsigned ly,
			bool weMaster, unsigned winDrawState, int targetx, unsigned cycles) {
		cycles += std::min(unsigned(p.scx - xpos) & 7, max_m3start_cycles - xpos) + 1 - p.cgb;
		return M3Loop::Tile::predictCyclesUntilXpos_fn(p, 0, 8 - (p.scx & 7), ly, 0,
			weMaster, winDrawState, std::min(p.scx & 7, 5), targetx, cycles);
	}

	static unsigned predictCyclesUntilXpos_f0(PPUPriv const &p, unsigned ly,
			bool weMaster, unsigned winDrawState, int targetx, unsigned cycles) {
		winDrawState = (winDrawState & win_draw_start) && lcdcWinEn(p) ? win_draw_started : 0;
		return predictCyclesUntilXpos_f1(p, 0, ly, weMaster, winDrawState, targetx, cycles);
	}

	static unsigned predictCyclesUntilXpos_f0(PPUPriv const &p, int targetx, unsigned cycles) {
		unsigned ly = p.lyCounter.ly() + (p.lyCounter.time() - p.now < 16);
		return predictCyclesUntilXpos_f0(p, ly, p.weMaster, p.winDrawState, targetx, cycles);
	}

	static unsigned predictCyclesUntilXpos_f1(PPUPriv const &p, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_f1(p, p.xpos, p.lyCounter.ly(), p.weMaster,
		                                 p.winDrawState, targetx, cycles);
	}
}

namespace M2_Ly0 {
	static unsigned predictCyclesUntilXpos_f0(PPUPriv const &p,
			unsigned winDrawState, int targetx, unsigned cycles) {
		bool weMaster = lcdcWinEn(p) && 0 == p.wy;
		unsigned ly = 0;

		return M3Start::predictCyclesUntilXpos_f0(p, ly, weMaster,
			winDrawState, targetx, cycles + m3StartLineCycle(p.cgb));

	}

	static unsigned predictCyclesUntilXpos_f0(PPUPriv const &p, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_f0(p, p.winDrawState, targetx, cycles);
	}
}

namespace M2_LyNon0 {
	static unsigned predictCyclesUntilXpos_f1(PPUPriv const &p, bool weMaster,
			unsigned winDrawState, int targetx, unsigned cycles) {
		unsigned ly = p.lyCounter.ly() + 1;
		weMaster |= lcdcWinEn(p) && ly == p.wy;

		return M3Start::predictCyclesUntilXpos_f0(p, ly, weMaster, winDrawState, targetx,
			cycles + 456 - weMasterCheckAfterLyIncLineCycle(p.cgb) + m3StartLineCycle(p.cgb));
	}

	static unsigned predictCyclesUntilXpos_f1(PPUPriv const &p, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_f1(p, p.weMaster, p.winDrawState, targetx, cycles);
	}

	static unsigned predictCyclesUntilXpos_f0(PPUPriv const &p,
			unsigned winDrawState, int targetx, unsigned cycles) {
		bool weMaster = p.weMaster || (lcdcWinEn(p) && p.lyCounter.ly() == p.wy);

		return predictCyclesUntilXpos_f1(p, weMaster, winDrawState, targetx,
			cycles + weMasterCheckAfterLyIncLineCycle(p.cgb)
			       - weMasterCheckPriorToLyIncLineCycle(p.cgb));
	}

	static unsigned predictCyclesUntilXpos_f0(PPUPriv const &p, int targetx, unsigned cycles) {
		return predictCyclesUntilXpos_f0(p, p.winDrawState, targetx, cycles);
	}
}

} // anon namespace

namespace gambatte {

PPUPriv::PPUPriv(NextM0Time &nextM0Time, unsigned char const *const oamram, unsigned char const *const vram)
: nextSprite(0)
, currentSprite(0xFF)
, vram(vram)
, nextCallPtr(&M2_Ly0::f0_)
, now(0)
, lastM0Time(0)
, cycles(-4396)
, tileword(0)
, ntileword(0)
, spriteMapper(nextM0Time, lyCounter, oamram)
, lcdc(0)
, scy(0)
, scx(0)
, wy(0)
, wy2(0)
, wx(0)
, winDrawState(0)
, wscx(0)
, winYPos(0)
, reg0(0)
, reg1(0)
, attrib(0)
, nattrib(0)
, xpos(0)
, endx(0)
, cgb(false)
, weMaster(false)
{
	std::memset(spriteList, 0, sizeof spriteList);
	std::memset(spwordList, 0, sizeof spwordList);
}

static void saveSpriteList(PPUPriv const &p, SaveState &ss) {
	for (unsigned i = 0; i < 10; ++i) {
		ss.ppu.spAttribList[i] = p.spriteList[i].attrib;
		ss.ppu.spByte0List[i] = p.spwordList[i] & 0xFF;
		ss.ppu.spByte1List[i] = p.spwordList[i] >> 8;
	}

	ss.ppu.nextSprite    = p.nextSprite;
	ss.ppu.currentSprite = p.currentSprite;
}

void PPU::saveState(SaveState &ss) const {
	p_.spriteMapper.saveState(ss);
	ss.ppu.videoCycles = lcdcEn(p_) ? p_.lyCounter.frameCycles(p_.now) : 0;
	ss.ppu.xpos = p_.xpos;
	ss.ppu.endx = p_.endx;
	ss.ppu.reg0 = p_.reg0;
	ss.ppu.reg1 = p_.reg1;
	ss.ppu.tileword = p_.tileword;
	ss.ppu.ntileword = p_.ntileword;
	ss.ppu.attrib = p_.attrib;
	ss.ppu.nattrib = p_.nattrib;
	ss.ppu.winDrawState = p_.winDrawState;
	ss.ppu.winYPos = p_.winYPos;
	ss.ppu.oldWy = p_.wy2;
	ss.ppu.wscx = p_.wscx;
	ss.ppu.weMaster = p_.weMaster;
	saveSpriteList(p_, ss);
	ss.ppu.state = p_.nextCallPtr->id;
	ss.ppu.lastM0Time = p_.now - p_.lastM0Time;
}

namespace {

template<class T, class K, std::size_t start, std::size_t len>
struct BSearch {
	static std::size_t upperBound(T const a[], K e) {
		if (e < a[start + len / 2])
			return BSearch<T, K, start, len / 2>::upperBound(a, e);

		return BSearch<T, K, start + len / 2 + 1, len - (len / 2 + 1)>::upperBound(a, e);
	}
};

template<class T, class K, std::size_t start>
struct BSearch<T, K, start, 0> {
	static std::size_t upperBound(T const [], K ) {
		return start;
	}
};

template<std::size_t len, class T, class K>
std::size_t upperBound(T const a[], K e) {
	return BSearch<T, K, 0, len>::upperBound(a, e);
}

struct CycleState {
	PPUState const *state;
	long cycle;
	operator long() const { return cycle; }
};

static PPUState const * decodeM3LoopState(unsigned state) {
	switch (state) {
	case M3Loop::Tile::ID0: return &M3Loop::Tile::f0_;
	case M3Loop::Tile::ID1: return &M3Loop::Tile::f1_;
	case M3Loop::Tile::ID2: return &M3Loop::Tile::f2_;
	case M3Loop::Tile::ID3: return &M3Loop::Tile::f3_;
	case M3Loop::Tile::ID4: return &M3Loop::Tile::f4_;
	case M3Loop::Tile::ID5: return &M3Loop::Tile::f5_;

	case M3Loop::LoadSprites::ID0: return &M3Loop::LoadSprites::f0_;
	case M3Loop::LoadSprites::ID1: return &M3Loop::LoadSprites::f1_;
	case M3Loop::LoadSprites::ID2: return &M3Loop::LoadSprites::f2_;
	case M3Loop::LoadSprites::ID3: return &M3Loop::LoadSprites::f3_;
	case M3Loop::LoadSprites::ID4: return &M3Loop::LoadSprites::f4_;
	case M3Loop::LoadSprites::ID5: return &M3Loop::LoadSprites::f5_;

	case M3Loop::StartWindowDraw::ID0: return &M3Loop::StartWindowDraw::f0_;
	case M3Loop::StartWindowDraw::ID1: return &M3Loop::StartWindowDraw::f1_;
	case M3Loop::StartWindowDraw::ID2: return &M3Loop::StartWindowDraw::f2_;
	case M3Loop::StartWindowDraw::ID3: return &M3Loop::StartWindowDraw::f3_;
	case M3Loop::StartWindowDraw::ID4: return &M3Loop::StartWindowDraw::f4_;
	case M3Loop::StartWindowDraw::ID5: return &M3Loop::StartWindowDraw::f5_;
	}

	return 0;
}

static long cyclesUntilM0Upperbound(PPUPriv const &p) {
	long cycles = 168 - p.xpos + 6;
	for (unsigned i = p.nextSprite; i < 10 && p.spriteList[i].spx < 168; ++i)
		cycles += 11;

	return cycles;
}

static void loadSpriteList(PPUPriv &p, SaveState const &ss) {
	if (ss.ppu.videoCycles < 144 * 456UL && ss.ppu.xpos < 168) {
		unsigned const ly = ss.ppu.videoCycles / 456;
		unsigned const numSprites = p.spriteMapper.numSprites(ly);
		unsigned char const *const sprites = p.spriteMapper.sprites(ly);

		for (unsigned i = 0; i < numSprites; ++i) {
			unsigned pos = sprites[i];
			unsigned spy = p.spriteMapper.posbuf()[pos  ];
			unsigned spx = p.spriteMapper.posbuf()[pos+1];

			p.spriteList[i].spx    = spx;
			p.spriteList[i].line   = ly + 16u - spy;
			p.spriteList[i].oampos = pos * 2;
			p.spriteList[i].attrib = ss.ppu.spAttribList[i] & 0xFF;
			p.spwordList[i] = (ss.ppu.spByte1List[i] * 0x100 + ss.ppu.spByte0List[i]) & 0xFFFF;
		}

		p.spriteList[numSprites].spx = 0xFF;
		p.nextSprite = std::min<unsigned>(ss.ppu.nextSprite, numSprites);

		while (p.spriteList[p.nextSprite].spx < ss.ppu.xpos)
			++p.nextSprite;

		p.currentSprite = std::min<unsigned>(p.nextSprite, ss.ppu.currentSprite);
	}
}

}

void PPU::loadState(SaveState const &ss, unsigned char const *const oamram) {
	PPUState const *const m3loopState = decodeM3LoopState(ss.ppu.state);
	long const videoCycles = std::min(ss.ppu.videoCycles, 70223UL);
	bool const ds = p_.cgb & ss.mem.ioamhram.get()[0x14D] >> 7;
	long const vcycs = videoCycles - ds * m2_ds_offset < 0
	                 ? videoCycles - ds * m2_ds_offset + 70224
	                 : videoCycles - ds * m2_ds_offset;
	long const lineCycles = static_cast<unsigned long>(vcycs) % 456;

	p_.now = ss.cpu.cycleCounter;
	p_.lcdc = ss.mem.ioamhram.get()[0x140];
	p_.lyCounter.setDoubleSpeed(ds);
	p_.lyCounter.reset(std::min(ss.ppu.videoCycles, 70223ul), ss.cpu.cycleCounter);
	p_.spriteMapper.loadState(ss, oamram);
	p_.winYPos = ss.ppu.winYPos;
	p_.scy = ss.mem.ioamhram.get()[0x142];
	p_.scx = ss.mem.ioamhram.get()[0x143];
	p_.wy = ss.mem.ioamhram.get()[0x14A];
	p_.wy2 = ss.ppu.oldWy;
	p_.wx = ss.mem.ioamhram.get()[0x14B];
	p_.xpos = std::min<int>(ss.ppu.xpos, 168);
	p_.endx = (p_.xpos & ~7) + (ss.ppu.endx & 7);
	p_.endx = std::min(p_.endx <= p_.xpos ? p_.endx + 8 : p_.endx, 168);
	p_.reg0 = ss.ppu.reg0 & 0xFF;
	p_.reg1 = ss.ppu.reg1 & 0xFF;
	p_.tileword = ss.ppu.tileword & 0xFFFF;
	p_.ntileword = ss.ppu.ntileword & 0xFFFF;
	p_.attrib = ss.ppu.attrib & 0xFF;
	p_.nattrib = ss.ppu.nattrib & 0xFF;
	p_.wscx = ss.ppu.wscx;
	p_.weMaster = ss.ppu.weMaster;
	p_.winDrawState = ss.ppu.winDrawState & (win_draw_start | win_draw_started);
	p_.lastM0Time = p_.now - ss.ppu.lastM0Time;
	loadSpriteList(p_, ss);

	if (m3loopState && videoCycles < 144 * 456L && p_.xpos < 168
			&& lineCycles + cyclesUntilM0Upperbound(p_) < weMasterCheckPriorToLyIncLineCycle(p_.cgb)) {
		p_.nextCallPtr = m3loopState;
		p_.cycles = -1;
	} else if (vcycs < 143 * 456L + static_cast<long>(m3StartLineCycle(p_.cgb)) + max_m3start_cycles) {
		CycleState const lineCycleStates[] = {
			{   &M3Start::f0_, m3StartLineCycle(p_.cgb) },
			{   &M3Start::f1_, m3StartLineCycle(p_.cgb) + max_m3start_cycles },
			{ &M2_LyNon0::f0_, weMasterCheckPriorToLyIncLineCycle(p_.cgb) },
			{ &M2_LyNon0::f1_, weMasterCheckAfterLyIncLineCycle(p_.cgb) },
			{   &M3Start::f0_, m3StartLineCycle(p_.cgb) + 456 }
		};

		std::size_t const pos =
			upperBound<sizeof lineCycleStates / sizeof *lineCycleStates - 1>(lineCycleStates, lineCycles);

		p_.cycles = lineCycles - lineCycleStates[pos].cycle;
		p_.nextCallPtr = lineCycleStates[pos].state;

		if (&M3Start::f1_ == lineCycleStates[pos].state) {
			p_.xpos   = lineCycles - m3StartLineCycle(p_.cgb) + 1;
			p_.cycles = -1;
		}
	} else {
		p_.cycles = vcycs - 70224;
		p_.nextCallPtr = &M2_Ly0::f0_;
	}
}

void PPU::reset(unsigned char const *oamram, unsigned char const *vram, bool cgb) {
	p_.vram = vram;
	p_.cgb = cgb;
	p_.spriteMapper.reset(oamram, cgb);
}

void PPU::resetCc(unsigned long const oldCc, unsigned long const newCc) {
	unsigned long const dec = oldCc - newCc;
	unsigned long const videoCycles = lcdcEn(p_) ? p_.lyCounter.frameCycles(p_.now) : 0;

	p_.now -= dec;
	p_.lastM0Time = p_.lastM0Time ? p_.lastM0Time - dec : p_.lastM0Time;
	p_.lyCounter.reset(videoCycles, p_.now);
	p_.spriteMapper.resetCycleCounter(oldCc, newCc);
}

void PPU::speedChange(unsigned long const cycleCounter) {
	unsigned long const videoCycles = lcdcEn(p_) ? p_.lyCounter.frameCycles(p_.now) : 0;

	p_.spriteMapper.preSpeedChange(cycleCounter);
	p_.lyCounter.setDoubleSpeed(!p_.lyCounter.isDoubleSpeed());
	p_.lyCounter.reset(videoCycles, p_.now);
	p_.spriteMapper.postSpeedChange(cycleCounter);

	if (&M2_Ly0::f0_ == p_.nextCallPtr || &M2_LyNon0::f0_ == p_.nextCallPtr) {
		if (p_.lyCounter.isDoubleSpeed()) {
			p_.cycles -= m2_ds_offset;
		} else
			p_.cycles += m2_ds_offset;
	}
}

unsigned long PPU::predictedNextXposTime(unsigned xpos) const {
	return p_.now
	    + (p_.nextCallPtr->predictCyclesUntilXpos_f(p_, xpos, -p_.cycles) << p_.lyCounter.isDoubleSpeed());
}

void PPU::setLcdc(unsigned const lcdc, unsigned long const cc) {
	if ((p_.lcdc ^ lcdc) & lcdc & lcdc_en) {
		p_.now = cc;
		p_.lastM0Time = 0;
		p_.lyCounter.reset(0, p_.now);
		p_.spriteMapper.enableDisplay(cc);
		p_.weMaster = (lcdc & lcdc_we) && 0 == p_.wy;
		p_.winDrawState = 0;
		p_.nextCallPtr = &M3Start::f0_;
		p_.cycles = -int(m3StartLineCycle(p_.cgb) + m2_ds_offset * p_.lyCounter.isDoubleSpeed());
	} else if ((p_.lcdc ^ lcdc) & lcdc_we) {
		if (!(lcdc & lcdc_we)) {
			if (p_.winDrawState == win_draw_started || p_.xpos == 168)
				p_.winDrawState &= ~win_draw_started;
		} else if (p_.winDrawState == win_draw_start) {
			p_.winDrawState |= win_draw_started;
			++p_.winYPos;
		}
	}

	if ((p_.lcdc ^ lcdc) & lcdc_obj2x) {
		if (p_.lcdc & lcdc & lcdc_en)
			p_.spriteMapper.oamChange(cc);

		p_.spriteMapper.setLargeSpritesSource(lcdc & lcdc_obj2x);
	}

	p_.lcdc = lcdc;
}

void PPU::update(unsigned long const cc) {
	int const cycles = (cc - p_.now) >> p_.lyCounter.isDoubleSpeed();

	p_.now += cycles << p_.lyCounter.isDoubleSpeed();
	p_.cycles += cycles;

	if (p_.cycles >= 0) {
		p_.framebuf.setFbline(p_.lyCounter.ly());
		p_.nextCallPtr->f(p_);
	}
}

}
