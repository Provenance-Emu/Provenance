/* FCE Ultra - NES/Famicom Emulator
 *
 * Copyright notice for this file:
 *  Copyright (C) 1998 BERO
 *  Copyright (C) 2003 Xodnizel
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include "types.h"
#include "x6502.h"
#include "fceu.h"
#include "ppu.h"
#include "nsf.h"
#include "sound.h"
#include "file.h"
#include "utils/endian.h"
#include "utils/memory.h"
		 
#include "cart.h"
#include "palette.h"
#include "state.h"
#include "video.h"
#include "input.h"
#include "driver.h"
#include "debug.h"
		 
#include <cstring>
#include <cstdio>
#include <cstdlib>

#define VBlankON    (PPU[0] & 0x80)	//Generate VBlank NMI
#define Sprite16    (PPU[0] & 0x20)	//Sprites 8x16/8x8
#define BGAdrHI     (PPU[0] & 0x10)	//BG pattern adr $0000/$1000
#define SpAdrHI     (PPU[0] & 0x08)	//Sprite pattern adr $0000/$1000
#define INC32       (PPU[0] & 0x04)	//auto increment 1/32

#define SpriteON    (PPU[1] & 0x10)	//Show Sprite
#define ScreenON    (PPU[1] & 0x08)	//Show screen
#define PPUON       (PPU[1] & 0x18)	//PPU should operate
#define GRAYSCALE   (PPU[1] & 0x01)	//Grayscale (AND palette entries with 0x30)

#define SpriteLeft8 (PPU[1] & 0x04)
#define BGLeft8     (PPU[1] & 0x02)

#define PPU_status  (PPU[2])

#define READPAL(ofs)    (PALRAM[(ofs)] & (GRAYSCALE ? 0x30 : 0xFF))
#define READUPAL(ofs)   (UPALRAM[(ofs)] & (GRAYSCALE ? 0x30 : 0xFF))

static void FetchSpriteData(void);
static void RefreshLine(int lastpixel);
static void RefreshSprites(void);
static void CopySprites(uint8 *target);

static void Fixit1(void);
static uint32 ppulut1[256];
static uint32 ppulut2[256];
static uint32 ppulut3[128];

int test = 0;

template<typename T, int BITS>
struct BITREVLUT {
	T* lut;
	BITREVLUT() {
		int bits = BITS;
		int n = 1 << BITS;
		lut = new T[n];

		int m = 1;
		int a = n >> 1;
		int j = 2;

		lut[0] = 0;
		lut[1] = a;

		while (--bits) {
			m <<= 1;
			a >>= 1;
			for (int i = 0; i < m; i++)
				lut[j++] = lut[i] + a;
		}
	}

	T operator[](int index) {
		return lut[index];
	}
};
BITREVLUT<uint8, 8> bitrevlut;

struct PPUSTATUS {
	int32 sl;
	int32 cycle, end_cycle;
};

struct SPRITE_READ {
	int32 num;
	int32 count;
	int32 fetch;
	int32 found;
	int32 found_pos[8];
	int32 ret;
	int32 last;
	int32 mode;

	void reset() {
		num = count = fetch = found = ret = last = mode = 0;
		found_pos[0] = found_pos[1] = found_pos[2] = found_pos[3] = 0;
		found_pos[4] = found_pos[5] = found_pos[6] = found_pos[7] = 0;
	}

	void start_scanline() {
		num = 1;
		found = 0;
		fetch = 1;
		count = 0;
		last = 64;
		mode = 0;
		found_pos[0] = found_pos[1] = found_pos[2] = found_pos[3] = 0;
		found_pos[4] = found_pos[5] = found_pos[6] = found_pos[7] = 0;
	}
};

//doesn't need to be savestated as it is just a reflection of the current position in the ppu loop
PPUPHASE ppuphase;

//this needs to be savestated since a game may be trying to read from this across vblanks
SPRITE_READ spr_read;

//definitely needs to be savestated
uint8 idleSynch = 1;

//uses the internal counters concept at http://nesdev.icequake.net/PPU%20addressing.txt
struct PPUREGS {
	//normal clocked regs. as the game can interfere with these at any time, they need to be savestated
	uint32 fv;	//3
	uint32 v;	//1
	uint32 h;	//1
	uint32 vt;	//5
	uint32 ht;	//5

	//temp unlatched regs (need savestating, can be written to at any time)
	uint32 _fv, _v, _h, _vt, _ht;

	//other regs that need savestating
	uint32 fh;	//3 (horz scroll)
	uint32 s;	//1 ($2000 bit 4: "Background pattern table address (0: $0000; 1: $1000)")

	//other regs that don't need saving
	uint32 par;	//8 (sort of a hack, just stored in here, but not managed by this system)

	//cached state data. these are always reset at the beginning of a frame and don't need saving
	//but just to be safe, we're gonna save it
	PPUSTATUS status;

	void reset() {
		fv = v = h = vt = ht = 0;
		fh = par = s = 0;
		_fv = _v = _h = _vt = _ht = 0;
		status.cycle = 0;
		status.end_cycle = 341;
		status.sl = 241;
	}

	void install_latches() {
		fv = _fv;
		v = _v;
		h = _h;
		vt = _vt;
		ht = _ht;
	}

	void install_h_latches() {
		ht = _ht;
		h = _h;
	}

	void clear_latches() {
		_fv = _v = _h = _vt = _ht = 0;
		fh = 0;
	}

	void increment_hsc() {
		//The first one, the horizontal scroll counter, consists of 6 bits, and is
		//made up by daisy-chaining the HT counter to the H counter. The HT counter is
		//then clocked every 8 pixel dot clocks (or every 8/3 CPU clock cycles).
		ht++;
		h += (ht >> 5);
		ht &= 31;
		h &= 1;
	}

	void increment_vs() {
		fv++;
		int fv_overflow = (fv >> 3);
		vt += fv_overflow;
		vt &= 31;	//fixed tecmo super bowl
		if (vt == 30 && fv_overflow == 1) {	//caution here (only do it at the exact instant of overflow) fixes p'radikus conflict
			v++;
			vt = 0;
		}
		fv &= 7;
		v &= 1;
	}

	uint32 get_ntread() {
		return 0x2000 | (v << 0xB) | (h << 0xA) | (vt << 5) | ht;
	}

	uint32 get_2007access() {
		return ((fv & 3) << 0xC) | (v << 0xB) | (h << 0xA) | (vt << 5) | ht;
	}

	//The PPU has an internal 4-position, 2-bit shifter, which it uses for
	//obtaining the 2-bit palette select data during an attribute table byte
	//fetch. To represent how this data is shifted in the diagram, letters a..c
	//are used in the diagram to represent the right-shift position amount to
	//apply to the data read from the attribute data (a is always 0). This is why
	//you only see bits 0 and 1 used off the read attribute data in the diagram.
	uint32 get_atread() {
		return 0x2000 | (v << 0xB) | (h << 0xA) | 0x3C0 | ((vt & 0x1C) << 1) | ((ht & 0x1C) >> 2);
	}

	//address line 3 relates to the pattern table fetch occuring (the PPU always makes them in pairs).
	uint32 get_ptread() {
		return (s << 0xC) | (par << 0x4) | fv;
	}

	void increment2007(bool rendering, bool by32) {

		if (rendering)
		{
			//don't do this:
			//if (by32) increment_vs();
			//else increment_hsc();
			//do this instead:
			increment_vs();  //yes, even if we're moving by 32
			return;
		}

		//If the VRAM address increment bit (2000.2) is clear (inc. amt. = 1), all the
		//scroll counters are daisy-chained (in the order of HT, VT, H, V, FV) so that
		//the carry out of each counter controls the next counter's clock rate. The
		//result is that all 5 counters function as a single 15-bit one. Any access to
		//2007 clocks the HT counter here.
		//
		//If the VRAM address increment bit is set (inc. amt. = 32), the only
		//difference is that the HT counter is no longer being clocked, and the VT
		//counter is now being clocked by access to 2007.
		if (by32) {
			vt++;
		} else {
			ht++;
			vt += (ht >> 5) & 1;
		}
		h += (vt >> 5);
		v += (h >> 1);
		fv += (v >> 1);
		ht &= 31;
		vt &= 31;
		h &= 1;
		v &= 1;
		fv &= 7;
	}
} ppur;

int newppu_get_scanline() { return ppur.status.sl; }
int newppu_get_dot() { return ppur.status.cycle; }

static void makeppulut(void) {
	int x;
	int y;
	int cc, xo, pixel;


	for (x = 0; x < 256; x++) {
		ppulut1[x] = 0;
		for (y = 0; y < 8; y++)
			ppulut1[x] |= ((x >> (7 - y)) & 1) << (y * 4);
		ppulut2[x] = ppulut1[x] << 1;
	}

	for (cc = 0; cc < 16; cc++) {
		for (xo = 0; xo < 8; xo++) {
			ppulut3[xo | (cc << 3)] = 0;
			for (pixel = 0; pixel < 8; pixel++) {
				int shiftr;
				shiftr = (pixel + xo) / 8;
				shiftr *= 2;
				ppulut3[xo | (cc << 3)] |= ((cc >> shiftr) & 3) << (2 + pixel * 4);
			}
		}
	}
}

static int ppudead = 1;
static int kook = 0;
int fceuindbg = 0;

//mbg 6/23/08
//make the no-bg fill color configurable
//0xFF shall indicate to use palette[0]
uint8 gNoBGFillColor = 0xFF;

int MMC5Hack = 0, PEC586Hack = 0;;
uint32 MMC5HackVROMMask = 0;
uint8 *MMC5HackExNTARAMPtr = 0;
uint8 *MMC5HackVROMPTR = 0;
uint8 MMC5HackCHRMode = 0;
uint8 MMC5HackSPMode = 0;
uint8 MMC50x5130 = 0;
uint8 MMC5HackSPScroll = 0;
uint8 MMC5HackSPPage = 0;

uint8 VRAMBuffer = 0, PPUGenLatch = 0;
uint8 *vnapage[4];
uint8 PPUNTARAM = 0;
uint8 PPUCHRRAM = 0;

//Color deemphasis emulation.  Joy...
static uint8 deemp = 0;
static int deempcnt[8];

void (*GameHBIRQHook)(void), (*GameHBIRQHook2)(void);
void (*PPU_hook)(uint32 A);

uint8 vtoggle = 0;
uint8 XOffset = 0;
uint8 SpriteDMA = 0; // $4014 / Writing $xx copies 256 bytes by reading from $xx00-$xxFF and writing to $2004 (OAM data)

uint32 TempAddr = 0, RefreshAddr = 0, DummyRead = 0;

static int maxsprites = 8;

//scanline is equal to the current visible scanline we're on.
int scanline;
int g_rasterpos;
static uint32 scanlines_per_frame;

uint8 PPU[4];
uint8 PPUSPL;
uint8 NTARAM[0x800], PALRAM[0x20], SPRAM[0x100], SPRBUF[0x100];
uint8 UPALRAM[0x03];//for 0x4/0x8/0xC addresses in palette, the ones in
					//0x20 are 0 to not break fceu rendering.

#define MMC5SPRVRAMADR(V)   &MMC5SPRVPage[(V) >> 10][(V)]
#define VRAMADR(V)          &VPage[(V) >> 10][(V)]

//mbg 8/6/08 - fix a bug relating to
//"When in 8x8 sprite mode, only one set is used for both BG and sprites."
//in mmc5 docs
uint8 * MMC5BGVRAMADR(uint32 V) {
	if (!Sprite16) {
		extern uint8 mmc5ABMode;				/* A=0, B=1 */
		if (mmc5ABMode == 0)
			return MMC5SPRVRAMADR(V);
		else
			return &MMC5BGVPage[(V) >> 10][(V)];
	} else return &MMC5BGVPage[(V) >> 10][(V)];
}

//this duplicates logic which is embedded in the ppu rendering code
//which figures out where to get CHR data from depending on various hack modes
//mostly involving mmc5.
//this might be incomplete.
uint8* FCEUPPU_GetCHR(uint32 vadr, uint32 refreshaddr) {
	if (MMC5Hack) {
		if (MMC5HackCHRMode == 1) {
			uint8 *C = MMC5HackVROMPTR;
			C += (((MMC5HackExNTARAMPtr[refreshaddr & 0x3ff]) & 0x3f & MMC5HackVROMMask) << 12) + (vadr & 0xfff);
			C += (MMC50x5130 & 0x3) << 18;	//11-jun-2009 for kuja_killer
			return C;
		} else {
			return MMC5BGVRAMADR(vadr);
		}
	} else return VRAMADR(vadr);
}

//likewise for ATTR
int FCEUPPU_GetAttr(int ntnum, int xt, int yt) {
	int attraddr = 0x3C0 + ((yt >> 2) << 3) + (xt >> 2);
	int temp = (((yt & 2) << 1) + (xt & 2));
	int refreshaddr = xt + yt * 32;
	if (MMC5Hack && MMC5HackCHRMode == 1)
		return (MMC5HackExNTARAMPtr[refreshaddr & 0x3ff] & 0xC0) >> 6;
	else
		return (vnapage[ntnum][attraddr] & (3 << temp)) >> temp;
}

//new ppu-----
inline void FFCEUX_PPUWrite_Default(uint32 A, uint8 V) {
	uint32 tmp = A;

	if (PPU_hook) PPU_hook(A);

	if (tmp < 0x2000) {
		if (PPUCHRRAM & (1 << (tmp >> 10)))
			VPage[tmp >> 10][tmp] = V;
	} else if (tmp < 0x3F00) {
		if (PPUNTARAM & (1 << ((tmp & 0xF00) >> 10)))
			vnapage[((tmp & 0xF00) >> 10)][tmp & 0x3FF] = V;
	} else {
		if (!(tmp & 3)) {
			if (!(tmp & 0xC))
				PALRAM[0x00] = PALRAM[0x04] = PALRAM[0x08] = PALRAM[0x0C] = V & 0x3F;
			else
				UPALRAM[((tmp & 0xC) >> 2) - 1] = V & 0x3F;
		} else
			PALRAM[tmp & 0x1F] = V & 0x3F;
	}
}

volatile int rendercount, vromreadcount, undefinedvromcount, LogAddress = -1;
unsigned char *cdloggervdata = NULL;
unsigned int cdloggerVideoDataSize = 0;

int GetCHRAddress(int A) {
	if (cdloggerVideoDataSize) {
		int result = &VPage[A >> 10][A] - CHRptr[0];
		if ((result >= 0) && (result < (int)cdloggerVideoDataSize))
			return result;
	} else
		if(A < 0x2000) return A;
	return -1;
}

#define RENDER_LOG(tmp) { \
		if (debug_loggingCD) \
		{ \
			int addr = GetCHRAddress(tmp); \
			if (addr != -1)	\
			{ \
				if (!(cdloggervdata[addr] & 1))	\
				{ \
					cdloggervdata[addr] |= 1; \
					if(cdloggerVideoDataSize) { \
						if (!(cdloggervdata[addr] & 2)) undefinedvromcount--; \
						rendercount++; \
					} \
				} \
			} \
		} \
}

uint8 FASTCALL FFCEUX_PPURead_Default(uint32 A) {
	uint32 tmp = A;

	if (PPU_hook) PPU_hook(A);

	if (tmp < 0x2000) {
		return VPage[tmp >> 10][tmp];
	} else if (tmp < 0x3F00) {
		return vnapage[(tmp >> 10) & 0x3][tmp & 0x3FF];
	} else {
		uint8 ret;
		if (!(tmp & 3)) {
			if (!(tmp & 0xC))
				ret = READPAL(0x00);
			else
				ret = READUPAL(((tmp & 0xC) >> 2) - 1);
		} else
			ret = READPAL(tmp & 0x1F);
		return ret;
	}
}


uint8 (FASTCALL *FFCEUX_PPURead)(uint32 A) = 0;
void (*FFCEUX_PPUWrite)(uint32 A, uint8 V) = 0;

#define CALL_PPUREAD(A) (FFCEUX_PPURead(A))

#define CALL_PPUWRITE(A, V) (FFCEUX_PPUWrite ? FFCEUX_PPUWrite(A, V) : FFCEUX_PPUWrite_Default(A, V))

//whether to use the new ppu (new PPU doesn't handle MMC5 extra nametables at all
int newppu = 0;

void ppu_getScroll(int &xpos, int &ypos) {
	if (newppu) {
		ypos = ppur._vt * 8 + ppur._fv + ppur._v * 256;
		xpos = ppur._ht * 8 + ppur.fh + ppur._h * 256;
	} else {
		xpos = ((RefreshAddr & 0x400) >> 2) | ((RefreshAddr & 0x1F) << 3) | XOffset;

		ypos = ((RefreshAddr & 0x3E0) >> 2) | ((RefreshAddr & 0x7000) >> 12);
		if (RefreshAddr & 0x800) ypos += 240;
	}
}
//---------------

static DECLFR(A2002) {
	if (newppu) {
		//once we thought we clear latches here, but that caused midframe glitches.
		//i think we should only reset the state machine for 2005/2006
		//ppur.clear_latches();
	}

	uint8 ret;

	FCEUPPU_LineUpdate();
	ret = PPU_status;
	ret |= PPUGenLatch & 0x1F;

#ifdef FCEUDEF_DEBUGGER
	if (!fceuindbg)
#endif
	{
		vtoggle = 0;
		PPU_status &= 0x7F;
		PPUGenLatch = ret;
	}

	return ret;
}

static DECLFR(A2004) {
	if (newppu) {
		if ((ppur.status.sl < 241) && PPUON) {
			// from cycles 0 to 63, the
			// 32 byte OAM buffer gets init
			// to 0xFF
			if (ppur.status.cycle < 64)
				return spr_read.ret = 0xFF;
			else {
				for (int i = spr_read.last;
					 i != ppur.status.cycle; ++i) {
					if (i < 256) {
						switch (spr_read.mode) {
						case 0:
							if (spr_read.count < 2)
								spr_read.ret = (PPU[3] & 0xF8) + (spr_read.count << 2);
							else
								spr_read.ret = spr_read.count << 2;

							spr_read.found_pos[spr_read.found] = spr_read.ret;
							spr_read.ret = SPRAM[spr_read.ret];

							if (i & 1) {
								//odd cycle
								//see if in range
								if (!((ppur.status.sl - 1 - spr_read.ret) & ~(Sprite16 ? 0xF : 0x7))) {
									++spr_read.found;
									spr_read.fetch = 1;
									spr_read.mode = 1;
								} else {
									if (++spr_read.count == 64) {
										spr_read.mode = 4;
										spr_read.count = 0;
									} else if (spr_read.found == 8) {
										spr_read.fetch = 0;
										spr_read.mode = 2;
									}
								}
							}
							break;
						case 1:	//sprite is in range fetch next 3 bytes
							if (i & 1) {
								++spr_read.fetch;
								if (spr_read.fetch == 4) {
									spr_read.fetch = 1;
									if (++spr_read.count == 64) {
										spr_read.count = 0;
										spr_read.mode = 4;
									} else if (spr_read.found == 8) {
										spr_read.fetch = 0;
										spr_read.mode = 2;
									} else
										spr_read.mode = 0;
								}
							}

							if (spr_read.count < 2)
								spr_read.ret = (PPU[3] & 0xF8) + (spr_read.count << 2);
							else
								spr_read.ret = spr_read.count << 2;

							spr_read.ret = SPRAM[spr_read.ret | spr_read.fetch];
							break;
						case 2:	//8th sprite fetched
							spr_read.ret = SPRAM[(spr_read.count << 2) | spr_read.fetch];
							if (i & 1) {
								if (!((ppur.status.sl - 1 - SPRAM[((spr_read.count << 2) | spr_read.fetch)]) & ~((Sprite16) ? 0xF : 0x7))) {
									spr_read.fetch = 1;
									spr_read.mode = 3;
								} else {
									if (++spr_read.count == 64) {
										spr_read.count = 0;
										spr_read.mode = 4;
									}
									spr_read.fetch =
										(spr_read.fetch + 1) & 3;
								}
							}
							spr_read.ret = spr_read.count;
							break;
						case 3:	//9th sprite overflow detected
							spr_read.ret = SPRAM[spr_read.count | spr_read.fetch];
							if (i & 1) {
								if (++spr_read.fetch == 4) {
									spr_read.count = (spr_read.count + 1) & 63;
									spr_read.mode = 4;
								}
							}
							break;
						case 4:	//read OAM[n][0] until hblank
							if (i & 1)
								spr_read.count = (spr_read.count + 1) & 63;
							spr_read.fetch = 0;
							spr_read.ret = SPRAM[spr_read.count << 2];
							break;
						}
					} else if (i < 320) {
						spr_read.ret = (i & 0x38) >> 3;
						if (spr_read.found < (spr_read.ret + 1)) {
							if (spr_read.num) {
								spr_read.ret = SPRAM[252];
								spr_read.num = 0;
							} else
								spr_read.ret = 0xFF;
						} else if ((i & 7) < 4) {
							spr_read.ret =
								SPRAM[spr_read.found_pos[spr_read.ret] | spr_read.fetch++];
							if (spr_read.fetch == 4)
								spr_read.fetch = 0;
						} else
							spr_read.ret = SPRAM[spr_read.found_pos [spr_read.ret | 3]];
					} else {
						if (!spr_read.found)
							spr_read.ret = SPRAM[252];
						else
							spr_read.ret = SPRAM[spr_read.found_pos[0]];
						break;
					}
				}
				spr_read.last = ppur.status.cycle;
				return spr_read.ret;
			}
		} else
			return SPRAM[PPU[3]];
	} else {
		FCEUPPU_LineUpdate();
		return PPUGenLatch;
	}
}

static DECLFR(A200x) {	/* Not correct for $2004 reads. */
	FCEUPPU_LineUpdate();
	return PPUGenLatch;
}

static DECLFR(A2007) {
	uint8 ret;
	uint32 tmp = RefreshAddr & 0x3FFF;

	if (debug_loggingCD) {
		if (!DummyRead && (LogAddress != -1)) {
			if (!(cdloggervdata[LogAddress] & 2)) {
				cdloggervdata[LogAddress] |= 2;
				if ((!(cdloggervdata[LogAddress] & 1)) && cdloggerVideoDataSize) undefinedvromcount--;
				vromreadcount++;
			}
		} else
			DummyRead = 0;
	}

	if (newppu) {
		ret = VRAMBuffer;
		RefreshAddr = ppur.get_2007access() & 0x3FFF;
		if ((RefreshAddr & 0x3F00) == 0x3F00) {
			//if it is in the palette range bypass the
			//delayed read, and what gets filled in the temp
			//buffer is the address - 0x1000, also
			//if grayscale is set then the return is AND with 0x30
			//to get a gray color reading
			if (!(tmp & 3)) {
				if (!(tmp & 0xC))
					ret = READPAL(0x00);
				else
					ret = READUPAL(((tmp & 0xC) >> 2) - 1);
			} else
				ret = READPAL(tmp & 0x1F);
			VRAMBuffer = CALL_PPUREAD(RefreshAddr - 0x1000);
		} else {
			if (debug_loggingCD && (RefreshAddr < 0x2000))
				LogAddress = GetCHRAddress(RefreshAddr);
			VRAMBuffer = CALL_PPUREAD(RefreshAddr);
		}
		ppur.increment2007(ppur.status.sl >= 0 && ppur.status.sl < 241 && PPUON, INC32 != 0);
		RefreshAddr = ppur.get_2007access();
		return ret;
	} else {
		FCEUPPU_LineUpdate();

		if (tmp >= 0x3F00) {	// Palette RAM tied directly to the output data, without VRAM buffer
			if (!(tmp & 3)) {
				if (!(tmp & 0xC))
					ret = READPAL(0x00);
				else
					ret = READUPAL(((tmp & 0xC) >> 2) - 1);
			} else
				ret = READPAL(tmp & 0x1F);
			#ifdef FCEUDEF_DEBUGGER
			if (!fceuindbg)
			#endif
			{
				if ((tmp - 0x1000) < 0x2000)
					VRAMBuffer = VPage[(tmp - 0x1000) >> 10][tmp - 0x1000];
				else
					VRAMBuffer = vnapage[((tmp - 0x1000) >> 10) & 0x3][(tmp - 0x1000) & 0x3FF];
				if (PPU_hook) PPU_hook(tmp);
			}
		} else {
			ret = VRAMBuffer;
			#ifdef FCEUDEF_DEBUGGER
			if (!fceuindbg)
			#endif
			{
				if (PPU_hook) PPU_hook(tmp);
				PPUGenLatch = VRAMBuffer;
				if (tmp < 0x2000) {
					if (debug_loggingCD)
						LogAddress = GetCHRAddress(tmp);
					VRAMBuffer = VPage[tmp >> 10][tmp];
				} else if (tmp < 0x3F00)
					VRAMBuffer = vnapage[(tmp >> 10) & 0x3][tmp & 0x3FF];
			}
		}

	#ifdef FCEUDEF_DEBUGGER
		if (!fceuindbg)
	#endif
		{
			if ((ScreenON || SpriteON) && (scanline < 240)) {
				uint32 rad = RefreshAddr;
				if ((rad & 0x7000) == 0x7000) {
					rad ^= 0x7000;
					if ((rad & 0x3E0) == 0x3A0)
						rad ^= 0xBA0;
					else if ((rad & 0x3E0) == 0x3e0)
						rad ^= 0x3e0;
					else
						rad += 0x20;
				} else
					rad += 0x1000;
				RefreshAddr = rad;
			} else {
				if (INC32)
					RefreshAddr += 32;
				else
					RefreshAddr++;
			}
			if (PPU_hook) PPU_hook(RefreshAddr & 0x3fff);
		}
		return ret;
	}
}

static DECLFW(B2000) {
	FCEUPPU_LineUpdate();
	PPUGenLatch = V;

	if (!(PPU[0] & 0x80) && (V & 0x80) && (PPU_status & 0x80))
		TriggerNMI2();

	PPU[0] = V;
	TempAddr &= 0xF3FF;
	TempAddr |= (V & 3) << 10;

	ppur._h = V & 1;
	ppur._v = (V >> 1) & 1;
	ppur.s = (V >> 4) & 1;
}

static DECLFW(B2001) {
	FCEUPPU_LineUpdate();
	if (paldeemphswap)
		V = (V&0x9F)|((V&0x40)>>1)|((V&0x20)<<1);
	PPUGenLatch = V;
	PPU[1] = V;
	if (V & 0xE0)
		deemp = V >> 5;
}

static DECLFW(B2002) {
	PPUGenLatch = V;
}

static DECLFW(B2003) {
	PPUGenLatch = V;
	PPU[3] = V;
	PPUSPL = V & 0x7;
}

static DECLFW(B2004) {
	PPUGenLatch = V;
	if (newppu) {
		//the attribute upper bits are not connected
		//so AND them out on write, since reading them
		//should return 0 in those bits.
		if ((PPU[3] & 3) == 2)
			V &= 0xE3;
		SPRAM[PPU[3]] = V;
		PPU[3] = (PPU[3] + 1) & 0xFF;
	} else {
		if (PPUSPL >= 8) {
			if (PPU[3] >= 8)
				SPRAM[PPU[3]] = V;
		} else {
			SPRAM[PPUSPL] = V;
		}
		PPU[3]++;
		PPUSPL++;
	}
}

static DECLFW(B2005) {
	uint32 tmp = TempAddr;
	FCEUPPU_LineUpdate();
	PPUGenLatch = V;
	if (!vtoggle) {
		tmp &= 0xFFE0;
		tmp |= V >> 3;
		XOffset = V & 7;
		ppur._ht = V >> 3;
		ppur.fh = V & 7;
	} else {
		tmp &= 0x8C1F;
		tmp |= ((V & ~0x7) << 2);
		tmp |= (V & 7) << 12;
		ppur._vt = V >> 3;
		ppur._fv = V & 7;
	}
	TempAddr = tmp;
	vtoggle ^= 1;
}


static DECLFW(B2006) {
	FCEUPPU_LineUpdate();

	PPUGenLatch = V;
	if (!vtoggle) {
		TempAddr &= 0x00FF;
		TempAddr |= (V & 0x3f) << 8;

		ppur._vt &= 0x07;
		ppur._vt |= (V & 0x3) << 3;
		ppur._h = (V >> 2) & 1;
		ppur._v = (V >> 3) & 1;
		ppur._fv = (V >> 4) & 3;
	} else {
		TempAddr &= 0xFF00;
		TempAddr |= V;

		RefreshAddr = TempAddr;
		DummyRead = 1;
		if (PPU_hook)
			PPU_hook(RefreshAddr);

		ppur._vt &= 0x18;
		ppur._vt |= (V >> 5);
		ppur._ht = V & 31;

		ppur.install_latches();
	}

	vtoggle ^= 1;
}

static DECLFW(B2007) {
	uint32 tmp = RefreshAddr & 0x3FFF;

	if (debug_loggingCD) {
		if(tmp < 0x2000)
			cdloggervdata[tmp] = 0;
	}

	if (newppu) {
		PPUGenLatch = V;
		RefreshAddr = ppur.get_2007access() & 0x3FFF;
		CALL_PPUWRITE(RefreshAddr, V);
		ppur.increment2007(ppur.status.sl >= 0 && ppur.status.sl < 241 && PPUON, INC32 != 0);
		RefreshAddr = ppur.get_2007access();
	} else {
		PPUGenLatch = V;
		if (tmp < 0x2000) {
			if (PPUCHRRAM & (1 << (tmp >> 10)))
				VPage[tmp >> 10][tmp] = V;
		} else if (tmp < 0x3F00) {
			if (PPUNTARAM & (1 << ((tmp & 0xF00) >> 10)))
				vnapage[((tmp & 0xF00) >> 10)][tmp & 0x3FF] = V;
		} else {
			if (!(tmp & 3)) {
				if (!(tmp & 0xC))
					PALRAM[0x00] = PALRAM[0x04] = PALRAM[0x08] = PALRAM[0x0C] = V & 0x3F;
				else
					UPALRAM[((tmp & 0xC) >> 2) - 1] = V & 0x3F;
			} else
				PALRAM[tmp & 0x1F] = V & 0x3F;
		}
		if (INC32)
			RefreshAddr += 32;
		else
			RefreshAddr++;
		if (PPU_hook)
			PPU_hook(RefreshAddr & 0x3fff);
	}
}

static DECLFW(B4014) {
	uint32 t = V << 8;
	int x;

	for (x = 0; x < 256; x++)
		X6502_DMW(0x2004, X6502_DMR(t + x));
	SpriteDMA = V;
}

#define PAL(c)  ((c) + cc)

#define GETLASTPIXEL    (PAL ? ((timestamp * 48 - linestartts) / 15) : ((timestamp * 48 - linestartts) >> 4))

static uint8 *Pline, *Plinef;
static int firsttile;
int linestartts;	//no longer static so the debugger can see it
static int tofix = 0;

static void ResetRL(uint8 *target) {
	memset(target, 0xFF, 256);
	InputScanlineHook(0, 0, 0, 0);
	Plinef = target;
	Pline = target;
	firsttile = 0;
	linestartts = timestamp * 48 + X.count;
	tofix = 0;
	FCEUPPU_LineUpdate();
	tofix = 1;
}

static uint8 sprlinebuf[256 + 8];

void FCEUPPU_LineUpdate(void) {
	if (newppu)
		return;

#ifdef FCEUDEF_DEBUGGER
	if (!fceuindbg)
#endif
	if (Pline) {
		int l = GETLASTPIXEL;
		RefreshLine(l);
	}
}

static bool rendersprites = true, renderbg = true;

void FCEUI_SetRenderPlanes(bool sprites, bool bg) {
	rendersprites = sprites;
	renderbg = bg;
}

void FCEUI_GetRenderPlanes(bool& sprites, bool& bg) {
	sprites = rendersprites;
	bg = renderbg;
}

static void CheckSpriteHit(int p);

static void EndRL(void) {
	RefreshLine(272);
	if (tofix)
		Fixit1();
	CheckSpriteHit(272);
	Pline = 0;
}

static int32 sphitx;
static uint8 sphitdata;

static void CheckSpriteHit(int p) {
	int l = p - 16;
	int x;

	if (sphitx == 0x100) return;

	for (x = sphitx; x < (sphitx + 8) && x < l; x++) {
		if ((sphitdata & (0x80 >> (x - sphitx))) && !(Plinef[x] & 64) && x < 255) {
			PPU_status |= 0x40;
			sphitx = 0x100;
			break;
		}
	}
}

//spork the world.  Any sprites on this line? Then this will be set to 1.
//Needed for zapper emulation and *gasp* sprite emulation.
static int spork = 0;

// lasttile is really "second to last tile."
static void RefreshLine(int lastpixel) {
	static uint32 pshift[2];
	static uint32 atlatch;
	uint32 smorkus = RefreshAddr;

	#define RefreshAddr smorkus
	uint32 vofs;
	int X1;

	register uint8 *P = Pline;
	int lasttile = lastpixel >> 3;
	int numtiles;
	static int norecurse = 0;	// Yeah, recursion would be bad.
								// PPU_hook() functions can call
								// mirroring/chr bank switching functions,
								// which call FCEUPPU_LineUpdate, which call this
								// function.
	if (norecurse) return;

	if (sphitx != 0x100 && !(PPU_status & 0x40)) {
		if ((sphitx < (lastpixel - 16)) && !(sphitx < ((lasttile - 2) * 8)))
			lasttile++;
	}

	if (lasttile > 34) lasttile = 34;
	numtiles = lasttile - firsttile;

	if (numtiles <= 0) return;

	P = Pline;

	vofs = 0;

	if(PEC586Hack)
		vofs = ((RefreshAddr & 0x200) << 3) | ((RefreshAddr >> 12) & 7);
	else
		vofs = ((PPU[0] & 0x10) << 8) | ((RefreshAddr >> 12) & 7);

	if (!ScreenON && !SpriteON) {
		uint32 tem;
		tem = READPAL(0) | (READPAL(0) << 8) | (READPAL(0) << 16) | (READPAL(0) << 24);
		tem |= 0x40404040;
		FCEU_dwmemset(Pline, tem, numtiles * 8);
		P += numtiles * 8;
		Pline = P;

		firsttile = lasttile;

		#define TOFIXNUM (272 - 0x4)
		if (lastpixel >= TOFIXNUM && tofix) {
			Fixit1();
			tofix = 0;
		}

		if ((lastpixel - 16) >= 0) {
			InputScanlineHook(Plinef, spork ? sprlinebuf : 0, linestartts, lasttile * 8 - 16);
		}
		return;
	}

	//Priority bits, needed for sprite emulation.
	PALRAM[0] |= 64;
	PALRAM[4] |= 64;
	PALRAM[8] |= 64;
	PALRAM[0xC] |= 64;

	//This high-level graphics MMC5 emulation code was written for MMC5 carts in "CL" mode.
	//It's probably not totally correct for carts in "SL" mode.

#define PPUT_MMC5
	if (MMC5Hack && geniestage != 1) {
		if (MMC5HackCHRMode == 0 && (MMC5HackSPMode & 0x80)) {
			int tochange = MMC5HackSPMode & 0x1F;
			tochange -= firsttile;
			for (X1 = firsttile; X1 < lasttile; X1++) {
				if ((tochange <= 0 && MMC5HackSPMode & 0x40) || (tochange > 0 && !(MMC5HackSPMode & 0x40))) {
					#define PPUT_MMC5SP
					#include "pputile.inc"
					#undef PPUT_MMC5SP
				} else {
					#include "pputile.inc"
				}
				tochange--;
			}
		} else if (MMC5HackCHRMode == 1 && (MMC5HackSPMode & 0x80)) {
			int tochange = MMC5HackSPMode & 0x1F;
			tochange -= firsttile;

			#define PPUT_MMC5SP
			#define PPUT_MMC5CHR1
			for (X1 = firsttile; X1 < lasttile; X1++) {
				#include "pputile.inc"
			}
			#undef PPUT_MMC5CHR1
			#undef PPUT_MMC5SP
		} else if (MMC5HackCHRMode == 1) {
			#define PPUT_MMC5CHR1
			for (X1 = firsttile; X1 < lasttile; X1++) {
				#include "pputile.inc"
			}
			#undef PPUT_MMC5CHR1
		} else {
			for (X1 = firsttile; X1 < lasttile; X1++) {
				#include "pputile.inc"
			}
		}
	}
	#undef PPUT_MMC5
	else if (PPU_hook) {
		norecurse = 1;
		#define PPUT_HOOK
		if (PEC586Hack) {
			#define PPU_BGFETCH
			for (X1 = firsttile; X1 < lasttile; X1++) {
				#include "pputile.inc"
			}
			#undef PPU_BGFETCH
		} else {
			for (X1 = firsttile; X1 < lasttile; X1++) {
				#include "pputile.inc"
			}
		}
		#undef PPUT_HOOK
		norecurse = 0;
	} else {
		if (PEC586Hack) {
			#define PPU_BGFETCH
			for (X1 = firsttile; X1 < lasttile; X1++) {
				#include "pputile.inc"
			}
			#undef PPU_BGFETCH
		} else {
			for (X1 = firsttile; X1 < lasttile; X1++) {
				#include "pputile.inc"
			}
		}
	}

#undef vofs
#undef RefreshAddr

	//Reverse changes made before.
	PALRAM[0] &= 63;
	PALRAM[4] &= 63;
	PALRAM[8] &= 63;
	PALRAM[0xC] &= 63;

	RefreshAddr = smorkus;
	if (firsttile <= 2 && 2 < lasttile && !(PPU[1] & 2)) {
		uint32 tem;
		tem = READPAL(0) | (READPAL(0) << 8) | (READPAL(0) << 16) | (READPAL(0) << 24);
		tem |= 0x40404040;
		*(uint32*)Plinef = *(uint32*)(Plinef + 4) = tem;
	}

	if (!ScreenON) {
		uint32 tem;
		int tstart, tcount;
		tem = READPAL(0) | (READPAL(0) << 8) | (READPAL(0) << 16) | (READPAL(0) << 24);
		tem |= 0x40404040;

		tcount = lasttile - firsttile;
		tstart = firsttile - 2;
		if (tstart < 0) {
			tcount += tstart;
			tstart = 0;
		}
		if (tcount > 0)
			FCEU_dwmemset(Plinef + tstart * 8, tem, tcount * 8);
	}

	if (lastpixel >= TOFIXNUM && tofix) {
		Fixit1();
		tofix = 0;
	}

	//This only works right because of a hack earlier in this function.
	CheckSpriteHit(lastpixel);

	if ((lastpixel - 16) >= 0) {
		InputScanlineHook(Plinef, spork ? sprlinebuf : 0, linestartts, lasttile * 8 - 16);
	}
	Pline = P;
	firsttile = lasttile;
}

static INLINE void Fixit2(void) {
	if (ScreenON || SpriteON) {
		uint32 rad = RefreshAddr;
		rad &= 0xFBE0;
		rad |= TempAddr & 0x041f;
		RefreshAddr = rad;
	}
}

static void Fixit1(void) {
	if (ScreenON || SpriteON) {
		uint32 rad = RefreshAddr;

		if ((rad & 0x7000) == 0x7000) {
			rad ^= 0x7000;
			if ((rad & 0x3E0) == 0x3A0)
				rad ^= 0xBA0;
			else if ((rad & 0x3E0) == 0x3e0)
				rad ^= 0x3e0;
			else
				rad += 0x20;
		} else
			rad += 0x1000;
		RefreshAddr = rad;
	}
}

void MMC5_hb(int);		//Ugh ugh ugh.
static void DoLine(void) {
	if (scanline >= 240 && scanline != totalscanlines) {
		X6502_Run(256 + 69);
		scanline++;
		X6502_Run(16);
		return;
	}

	int x;
	uint8 *target = XBuf + ((scanline < 240 ? scanline : 240) << 8);
	u8* dtarget = XDBuf + ((scanline < 240 ? scanline : 240) << 8);

	if (MMC5Hack) MMC5_hb(scanline);

	X6502_Run(256);
	EndRL();

	if (!renderbg) {// User asked to not display background data.
		uint32 tem;
		uint8 col;
		if (gNoBGFillColor == 0xFF)
			col = READPAL(0);
		else col = gNoBGFillColor;
		tem = col | (col << 8) | (col << 16) | (col << 24);
		tem |= 0x40404040; 
		FCEU_dwmemset(target, tem, 256);
	}

	if (SpriteON)
		CopySprites(target);

	//greyscale handling (mask some bits off the color) ? ? ?
	if (ScreenON || SpriteON)
	{
		if (PPU[1] & 0x01) {
			for (x = 63; x >= 0; x--)
				*(uint32*)&target[x << 2] = (*(uint32*)&target[x << 2]) & 0x30303030;
		}
	}

	//some pathetic attempts at deemph
	if ((PPU[1] >> 5) == 0x7) {
		for (x = 63; x >= 0; x--)
			*(uint32*)&target[x << 2] = ((*(uint32*)&target[x << 2]) & 0x3f3f3f3f) | 0xc0c0c0c0;
	} else if (PPU[1] & 0xE0)
		for (x = 63; x >= 0; x--)
			*(uint32*)&target[x << 2] = (*(uint32*)&target[x << 2]) | 0x40404040;
	else
		for (x = 63; x >= 0; x--)
			*(uint32*)&target[x << 2] = ((*(uint32*)&target[x << 2]) & 0x3f3f3f3f) | 0x80808080;

	//write the actual deemph
	for (x = 63; x >= 0; x--)
		*(uint32*)&dtarget[x << 2] = ((PPU[1]>>5)<<0)|((PPU[1]>>5)<<8)|((PPU[1]>>5)<<16)|((PPU[1]>>5)<<24);

	sphitx = 0x100;

	if (ScreenON || SpriteON)
		FetchSpriteData();

	if (GameHBIRQHook && (ScreenON || SpriteON) && ((PPU[0] & 0x38) != 0x18)) {
		X6502_Run(6);
		Fixit2();
		X6502_Run(4);
		GameHBIRQHook();
		X6502_Run(85 - 16 - 10);
	} else {
		X6502_Run(6);	// Tried 65, caused problems with Slalom(maybe others)
		Fixit2();
		X6502_Run(85 - 6 - 16);

		// A semi-hack for Star Trek: 25th Anniversary
		if (GameHBIRQHook && (ScreenON || SpriteON) && ((PPU[0] & 0x38) != 0x18))
			GameHBIRQHook();
	}

	DEBUG(FCEUD_UpdateNTView(scanline, 0));

	if (SpriteON)
		RefreshSprites();
	if (GameHBIRQHook2 && (ScreenON || SpriteON))
		GameHBIRQHook2();
	scanline++;
	if (scanline < 240) {
		ResetRL(XBuf + (scanline << 8));
	}
	X6502_Run(16);
}

#define V_FLIP  0x80
#define H_FLIP  0x40
#define SP_BACK 0x20

typedef struct {
	uint8 y, no, atr, x;
} SPR;

typedef struct {
	uint8 ca[2], atr, x;
} SPRB;

void FCEUI_DisableSpriteLimitation(int a) {
	maxsprites = a ? 64 : 8;
}

static uint8 numsprites, SpriteBlurp;
static void FetchSpriteData(void) {
	uint8 ns, sb;
	SPR *spr;
	uint8 H;
	int n;
	int vofs;
	uint8 P0 = PPU[0];

	spr = (SPR*)SPRAM;
	H = 8;

	ns = sb = 0;

	vofs = (uint32)(P0 & 0x8 & (((P0 & 0x20) ^ 0x20) >> 2)) << 9;
	H += (P0 & 0x20) >> 2;

	if (!PPU_hook)
		for (n = 63; n >= 0; n--, spr++) {
			if ((uint32)(scanline - spr->y) >= H) continue;
			if (ns < maxsprites) {
				if (n == 63) sb = 1;

				{
					SPRB dst;
					uint8 *C;
					int t;
					uint32 vadr;

					t = (int)scanline - (spr->y);

					if (Sprite16)
						vadr = ((spr->no & 1) << 12) + ((spr->no & 0xFE) << 4);
					else
						vadr = (spr->no << 4) + vofs;

					if (spr->atr & V_FLIP) {
						vadr += 7;
						vadr -= t;
						vadr += (P0 & 0x20) >> 1;
						vadr -= t & 8;
					} else {
						vadr += t;
						vadr += t & 8;
					}

					/* Fix this geniestage hack */
					if (MMC5Hack && geniestage != 1)
						C = MMC5SPRVRAMADR(vadr);
					else
						C = VRAMADR(vadr);

					if (SpriteON)
						RENDER_LOG(vadr);
					dst.ca[0] = C[0];
					if (SpriteON)
						RENDER_LOG(vadr + 8);
					dst.ca[1] = C[8];
					dst.x = spr->x;
					dst.atr = spr->atr;

					*(uint32*)&SPRBUF[ns << 2] = *(uint32*)&dst;
				}

				ns++;
			} else {
				PPU_status |= 0x20;
				break;
			}
		}
	else
		for (n = 63; n >= 0; n--, spr++) {
			if ((uint32)(scanline - spr->y) >= H) continue;

			if (ns < maxsprites) {
				if (n == 63) sb = 1;

				{
					SPRB dst;
					uint8 *C;
					int t;
					uint32 vadr;

					t = (int)scanline - (spr->y);

					if (Sprite16)
						vadr = ((spr->no & 1) << 12) + ((spr->no & 0xFE) << 4);
					else
						vadr = (spr->no << 4) + vofs;

					if (spr->atr & V_FLIP) {
						vadr += 7;
						vadr -= t;
						vadr += (P0 & 0x20) >> 1;
						vadr -= t & 8;
					} else {
						vadr += t;
						vadr += t & 8;
					}

					if (MMC5Hack)
						C = MMC5SPRVRAMADR(vadr);
					else
						C = VRAMADR(vadr);
					if (SpriteON)
						RENDER_LOG(vadr);
					dst.ca[0] = C[0];
					if (ns < 8) {
						PPU_hook(0x2000);
						PPU_hook(vadr);
					}
					if (SpriteON)
						RENDER_LOG(vadr + 8);
					dst.ca[1] = C[8];
					dst.x = spr->x;
					dst.atr = spr->atr;


					*(uint32*)&SPRBUF[ns << 2] = *(uint32*)&dst;
				}

				ns++;
			} else {
				PPU_status |= 0x20;
				break;
			}
		}

	//Handle case when >8 sprites per scanline option is enabled.
	if (ns > 8) PPU_status |= 0x20;
	else if (PPU_hook) {
		for (n = 0; n < (8 - ns); n++) {
			PPU_hook(0x2000);
			PPU_hook(vofs);
		}
	}
	numsprites = ns;
	SpriteBlurp = sb;
}

static void RefreshSprites(void) {
	int n;
	SPRB *spr;

	spork = 0;
	if (!numsprites) return;

	FCEU_dwmemset(sprlinebuf, 0x80808080, 256);
	numsprites--;
	spr = (SPRB*)SPRBUF + numsprites;

	for (n = numsprites; n >= 0; n--, spr--) {
		uint32 pixdata;
		uint8 J, atr;

		int x = spr->x;
		uint8 *C;
		int VB;

		pixdata = ppulut1[spr->ca[0]] | ppulut2[spr->ca[1]];
		J = spr->ca[0] | spr->ca[1];
		atr = spr->atr;

		if (J) {
			if (n == 0 && SpriteBlurp && !(PPU_status & 0x40)) {
				sphitx = x;
				sphitdata = J;
				if (atr & H_FLIP)
					sphitdata = ((J << 7) & 0x80) |
								((J << 5) & 0x40) |
								((J << 3) & 0x20) |
								((J << 1) & 0x10) |
								((J >> 1) & 0x08) |
								((J >> 3) & 0x04) |
								((J >> 5) & 0x02) |
								((J >> 7) & 0x01);
			}

			C = sprlinebuf + x;
			VB = (0x10) + ((atr & 3) << 2);

			if (atr & SP_BACK) {
				if (atr & H_FLIP) {
					if (J & 0x80) C[7] = READPAL(VB | (pixdata & 3)) | 0x40;
					pixdata >>= 4;
					if (J & 0x40) C[6] = READPAL(VB | (pixdata & 3)) | 0x40;
					pixdata >>= 4;
					if (J & 0x20) C[5] = READPAL(VB | (pixdata & 3)) | 0x40;
					pixdata >>= 4;
					if (J & 0x10) C[4] = READPAL(VB | (pixdata & 3)) | 0x40;
					pixdata >>= 4;
					if (J & 0x08) C[3] = READPAL(VB | (pixdata & 3)) | 0x40;
					pixdata >>= 4;
					if (J & 0x04) C[2] = READPAL(VB | (pixdata & 3)) | 0x40;
					pixdata >>= 4;
					if (J & 0x02) C[1] = READPAL(VB | (pixdata & 3)) | 0x40;
					pixdata >>= 4;
					if (J & 0x01) C[0] = READPAL(VB | pixdata) | 0x40;
				} else {
					if (J & 0x80) C[0] = READPAL(VB | (pixdata & 3)) | 0x40;
					pixdata >>= 4;
					if (J & 0x40) C[1] = READPAL(VB | (pixdata & 3)) | 0x40;
					pixdata >>= 4;
					if (J & 0x20) C[2] = READPAL(VB | (pixdata & 3)) | 0x40;
					pixdata >>= 4;
					if (J & 0x10) C[3] = READPAL(VB | (pixdata & 3)) | 0x40;
					pixdata >>= 4;
					if (J & 0x08) C[4] = READPAL(VB | (pixdata & 3)) | 0x40;
					pixdata >>= 4;
					if (J & 0x04) C[5] = READPAL(VB | (pixdata & 3)) | 0x40;
					pixdata >>= 4;
					if (J & 0x02) C[6] = READPAL(VB | (pixdata & 3)) | 0x40;
					pixdata >>= 4;
					if (J & 0x01) C[7] = READPAL(VB | pixdata) | 0x40;
				}
			} else {
				if (atr & H_FLIP) {
					if (J & 0x80) C[7] = READPAL(VB | (pixdata & 3));
					pixdata >>= 4;
					if (J & 0x40) C[6] = READPAL(VB | (pixdata & 3));
					pixdata >>= 4;
					if (J & 0x20) C[5] = READPAL(VB | (pixdata & 3));
					pixdata >>= 4;
					if (J & 0x10) C[4] = READPAL(VB | (pixdata & 3));
					pixdata >>= 4;
					if (J & 0x08) C[3] = READPAL(VB | (pixdata & 3));
					pixdata >>= 4;
					if (J & 0x04) C[2] = READPAL(VB | (pixdata & 3));
					pixdata >>= 4;
					if (J & 0x02) C[1] = READPAL(VB | (pixdata & 3));
					pixdata >>= 4;
					if (J & 0x01) C[0] = READPAL(VB | pixdata);
				} else {
					if (J & 0x80) C[0] = READPAL(VB | (pixdata & 3));
					pixdata >>= 4;
					if (J & 0x40) C[1] = READPAL(VB | (pixdata & 3));
					pixdata >>= 4;
					if (J & 0x20) C[2] = READPAL(VB | (pixdata & 3));
					pixdata >>= 4;
					if (J & 0x10) C[3] = READPAL(VB | (pixdata & 3));
					pixdata >>= 4;
					if (J & 0x08) C[4] = READPAL(VB | (pixdata & 3));
					pixdata >>= 4;
					if (J & 0x04) C[5] = READPAL(VB | (pixdata & 3));
					pixdata >>= 4;
					if (J & 0x02) C[6] = READPAL(VB | (pixdata & 3));
					pixdata >>= 4;
					if (J & 0x01) C[7] = READPAL(VB | pixdata);
				}
			}
		}
	}
	SpriteBlurp = 0;
	spork = 1;
}

static void CopySprites(uint8 *target) {
	uint8 n = ((PPU[1] & 4) ^ 4) << 1;
	uint8 *P = target;

	if (!spork) return;
	spork = 0;

	if (!rendersprites) return;	//User asked to not display sprites.

 loopskie:
	{
		uint32 t = *(uint32*)(sprlinebuf + n);

		if (t != 0x80808080) {
			#ifdef LSB_FIRST
			if (!(t & 0x80)) {
				if (!(t & 0x40) || (P[n] & 0x40))		// Normal sprite || behind bg sprite
					P[n] = sprlinebuf[n];
			}

			if (!(t & 0x8000)) {
				if (!(t & 0x4000) || (P[n + 1] & 0x40))		// Normal sprite || behind bg sprite
					P[n + 1] = (sprlinebuf + 1)[n];
			}

			if (!(t & 0x800000)) {
				if (!(t & 0x400000) || (P[n + 2] & 0x40))	// Normal sprite || behind bg sprite
					P[n + 2] = (sprlinebuf + 2)[n];
			}

			if (!(t & 0x80000000)) {
				if (!(t & 0x40000000) || (P[n + 3] & 0x40))	// Normal sprite || behind bg sprite
					P[n + 3] = (sprlinebuf + 3)[n];
			}
			#else
			/* TODO:  Simplify */
			if (!(t & 0x80000000)) {
				if (!(t & 0x40000000))	// Normal sprite
					P[n] = sprlinebuf[n];
				else if (P[n] & 64)		// behind bg sprite
					P[n] = sprlinebuf[n];
			}

			if (!(t & 0x800000)) {
				if (!(t & 0x400000))	// Normal sprite
					P[n + 1] = (sprlinebuf + 1)[n];
				else if (P[n + 1] & 64)	// behind bg sprite
					P[n + 1] = (sprlinebuf + 1)[n];
			}

			if (!(t & 0x8000)) {
				if (!(t & 0x4000))		// Normal sprite
					P[n + 2] = (sprlinebuf + 2)[n];
				else if (P[n + 2] & 64)	// behind bg sprite
					P[n + 2] = (sprlinebuf + 2)[n];
			}

			if (!(t & 0x80)) {
				if (!(t & 0x40))		// Normal sprite
					P[n + 3] = (sprlinebuf + 3)[n];
				else if (P[n + 3] & 64)	// behind bg sprite
					P[n + 3] = (sprlinebuf + 3)[n];
			}
			#endif
		}
	}
	n += 4;
	if (n) goto loopskie;
}

void FCEUPPU_SetVideoSystem(int w) {
	if (w) {
		scanlines_per_frame = dendy ? 262: 312;
		FSettings.FirstSLine = FSettings.UsrFirstSLine[1];
		FSettings.LastSLine = FSettings.UsrLastSLine[1];
		//paldeemphswap = 1; // dendy has pal ppu, and pal ppu has these swapped
	} else {
		scanlines_per_frame = 262;
		FSettings.FirstSLine = FSettings.UsrFirstSLine[0];
		FSettings.LastSLine = FSettings.UsrLastSLine[0];
		//paldeemphswap = 0;
	}
}

//Initializes the PPU
void FCEUPPU_Init(void) {
	makeppulut();
}

void PPU_ResetHooks() {
	FFCEUX_PPURead = FFCEUX_PPURead_Default;
}

void FCEUPPU_Reset(void) {
	VRAMBuffer = PPU[0] = PPU[1] = PPU_status = PPU[3] = 0;
	PPUSPL = 0;
	PPUGenLatch = 0;
	RefreshAddr = TempAddr = 0;
	vtoggle = 0;
	ppudead = 2;
	kook = 0;
	idleSynch = 1;

	ppur.reset();
	spr_read.reset();
}

void FCEUPPU_Power(void) {
	int x;

	memset(NTARAM, 0x00, 0x800);
	memset(PALRAM, 0x00, 0x20);
	memset(UPALRAM, 0x00, 0x03);
	memset(SPRAM, 0x00, 0x100);
	FCEUPPU_Reset();

	for (x = 0x2000; x < 0x4000; x += 8) {
		ARead[x] = A200x;
		BWrite[x] = B2000;
		ARead[x + 1] = A200x;
		BWrite[x + 1] = B2001;
		ARead[x + 2] = A2002;
		BWrite[x + 2] = B2002;
		ARead[x + 3] = A200x;
		BWrite[x + 3] = B2003;
		ARead[x + 4] = A2004;
		BWrite[x + 4] = B2004;
		ARead[x + 5] = A200x;
		BWrite[x + 5] = B2005;
		ARead[x + 6] = A200x;
		BWrite[x + 6] = B2006;
		ARead[x + 7] = A2007;
		BWrite[x + 7] = B2007;
	}
	BWrite[0x4014] = B4014;
}

int FCEUPPU_Loop(int skip) {
	if ((newppu) && (GameInfo->type != GIT_NSF)) {
		int FCEUX_PPU_Loop(int skip);
		return FCEUX_PPU_Loop(skip);
	}

	//Needed for Knight Rider, possibly others.
	if (ppudead) {
		memset(XBuf, 0x80, 256 * 240);
		X6502_Run(scanlines_per_frame * (256 + 85));
		ppudead--;
	} else {
		X6502_Run(256 + 85);
		PPU_status |= 0x80;

		//Not sure if this is correct.  According to Matt Conte and my own tests, it is.
		//Timing is probably off, though.
		//NOTE:  Not having this here breaks a Super Donkey Kong game.
		PPU[3] = PPUSPL = 0;

		//I need to figure out the true nature and length of this delay.
		X6502_Run(12);
		if (GameInfo->type == GIT_NSF)
			DoNSFFrame();
		else {
			if (VBlankON)
				TriggerNMI();
		}
		X6502_Run((scanlines_per_frame - 242) * (256 + 85) - 12);
		if (overclock_enabled && vblankscanlines) {
			if (!DMC_7bit || !skip_7bit_overclocking) {
				overclocking = 1;
				X6502_Run(vblankscanlines * (256 + 85) - 12);
				overclocking = 0;
			}
		}
		PPU_status &= 0x1f;
		X6502_Run(256);

		{
			int x;

			if (ScreenON || SpriteON) {
				if (GameHBIRQHook && ((PPU[0] & 0x38) != 0x18))
					GameHBIRQHook();
				if (PPU_hook)
					for (x = 0; x < 42; x++) {
						PPU_hook(0x2000); PPU_hook(0);
					}
				if (GameHBIRQHook2)
					GameHBIRQHook2();
			}
			X6502_Run(85 - 16);
			if (ScreenON || SpriteON) {
				RefreshAddr = TempAddr;
				if (PPU_hook) PPU_hook(RefreshAddr & 0x3fff);
			}

			//Clean this stuff up later.
			spork = numsprites = 0;
			ResetRL(XBuf);

			X6502_Run(16 - kook);
			kook ^= 1;
		}
		if (GameInfo->type == GIT_NSF)
			X6502_Run((256 + 85) * normalscanlines);
		#ifdef FRAMESKIP
		else if (skip) {
			int y;

			y = SPRAM[0];
			y++;

			PPU_status |= 0x20;	// Fixes "Bee 52".  Does it break anything?
			if (GameHBIRQHook) {
				X6502_Run(256);
				for (scanline = 0; scanline < 240; scanline++) {
					if (ScreenON || SpriteON)
						GameHBIRQHook();
					if (scanline == y && SpriteON) PPU_status |= 0x40;
					X6502_Run((scanline == 239) ? 85 : (256 + 85));
				}
			} else if (y < 240) {
				X6502_Run((256 + 85) * y);
				if (SpriteON) PPU_status |= 0x40;	// Quick and very dirty hack.
				X6502_Run((256 + 85) * (240 - y));
			} else
				X6502_Run((256 + 85) * 240);
		}
		#endif
		else {
			deemp = PPU[1] >> 5;

			// manual samples can't play correctly with overclocking
			if (DMC_7bit && skip_7bit_overclocking) // 7bit sample started before 240th line
				totalscanlines = normalscanlines;
			else
				totalscanlines = normalscanlines + (overclock_enabled ? postrenderscanlines : 0);

			for (scanline = 0; scanline < totalscanlines; ) {	//scanline is incremented in  DoLine.  Evil. :/
				deempcnt[deemp]++;
				if (scanline < 240)
					DEBUG(FCEUD_UpdatePPUView(scanline, 1));
				DoLine();

				if (scanline < normalscanlines || scanline == totalscanlines)
					overclocking = 0;
				else {
					if (DMC_7bit && skip_7bit_overclocking) // 7bit sample started after 240th line
						break;
					overclocking = 1;
				}
			}
			DMC_7bit = 0;

			if (MMC5Hack) MMC5_hb(scanline);

			//deemph nonsense, kept for complicated reasons (see SetNESDeemph_OldHacky implementation)
			int maxref = 0;
			for (int x = 1, max = 0; x < 7; x++) {
				if (deempcnt[x] > max) {
					max = deempcnt[x];
					maxref = x;
				}
				deempcnt[x] = 0;
			}
			SetNESDeemph_OldHacky(maxref, 0);
		}
	}	//else... to if(ppudead)

	#ifdef FRAMESKIP
	if (skip) {
		FCEU_PutImageDummy();
		return(0);
	} else
	#endif
	{
		FCEU_PutImage();
		return(1);
	}
}

int (*PPU_MASTER)(int skip) = FCEUPPU_Loop;

static uint16 TempAddrT, RefreshAddrT;

void FCEUPPU_LoadState(int version) {
	TempAddr = TempAddrT;
	RefreshAddr = RefreshAddrT;
}

SFORMAT FCEUPPU_STATEINFO[] = {
	{ NTARAM, 0x800, "NTAR" },
	{ PALRAM, 0x20, "PRAM" },
	{ SPRAM, 0x100, "SPRA" },
	{ PPU, 0x4, "PPUR" },
	{ &kook, 1, "KOOK" },
	{ &ppudead, 1, "DEAD" },
	{ &PPUSPL, 1, "PSPL" },
	{ &XOffset, 1, "XOFF" },
	{ &vtoggle, 1, "VTGL" },
	{ &RefreshAddrT, 2 | FCEUSTATE_RLSB, "RADD" },
	{ &TempAddrT, 2 | FCEUSTATE_RLSB, "TADD" },
	{ &VRAMBuffer, 1, "VBUF" },
	{ &PPUGenLatch, 1, "PGEN" },
	{ 0 }
};

SFORMAT FCEU_NEWPPU_STATEINFO[] = {
	{ &idleSynch, 1, "IDLS" },
	{ &spr_read.num, 4 | FCEUSTATE_RLSB, "SR_0" },
	{ &spr_read.count, 4 | FCEUSTATE_RLSB, "SR_1" },
	{ &spr_read.fetch, 4 | FCEUSTATE_RLSB, "SR_2" },
	{ &spr_read.found, 4 | FCEUSTATE_RLSB, "SR_3" },
	{ &spr_read.found_pos[0], 4 | FCEUSTATE_RLSB, "SRx0" },
	{ &spr_read.found_pos[0], 4 | FCEUSTATE_RLSB, "SRx1" },
	{ &spr_read.found_pos[0], 4 | FCEUSTATE_RLSB, "SRx2" },
	{ &spr_read.found_pos[0], 4 | FCEUSTATE_RLSB, "SRx3" },
	{ &spr_read.found_pos[0], 4 | FCEUSTATE_RLSB, "SRx4" },
	{ &spr_read.found_pos[0], 4 | FCEUSTATE_RLSB, "SRx5" },
	{ &spr_read.found_pos[0], 4 | FCEUSTATE_RLSB, "SRx6" },
	{ &spr_read.found_pos[0], 4 | FCEUSTATE_RLSB, "SRx7" },
	{ &spr_read.ret, 4 | FCEUSTATE_RLSB, "SR_4" },
	{ &spr_read.last, 4 | FCEUSTATE_RLSB, "SR_5" },
	{ &spr_read.mode, 4 | FCEUSTATE_RLSB, "SR_6" },
	{ &ppur.fv, 4 | FCEUSTATE_RLSB, "PFVx" },
	{ &ppur.v, 4 | FCEUSTATE_RLSB, "PVxx" },
	{ &ppur.h, 4 | FCEUSTATE_RLSB, "PHxx" },
	{ &ppur.vt, 4 | FCEUSTATE_RLSB, "PVTx" },
	{ &ppur.ht, 4 | FCEUSTATE_RLSB, "PHTx" },
	{ &ppur._fv, 4 | FCEUSTATE_RLSB, "P_FV" },
	{ &ppur._v, 4 | FCEUSTATE_RLSB, "P_Vx" },
	{ &ppur._h, 4 | FCEUSTATE_RLSB, "P_Hx" },
	{ &ppur._vt, 4 | FCEUSTATE_RLSB, "P_VT" },
	{ &ppur._ht, 4 | FCEUSTATE_RLSB, "P_HT" },
	{ &ppur.fh, 4 | FCEUSTATE_RLSB, "PFHx" },
	{ &ppur.s, 4 | FCEUSTATE_RLSB, "PSxx" },
	{ &ppur.status.sl, 4 | FCEUSTATE_RLSB, "PST0" },
	{ &ppur.status.cycle, 4 | FCEUSTATE_RLSB, "PST1" },
	{ &ppur.status.end_cycle, 4 | FCEUSTATE_RLSB, "PST2" },
	{ 0 }
};

void FCEUPPU_SaveState(void) {
	TempAddrT = TempAddr;
	RefreshAddrT = RefreshAddr;
}

uint32 FCEUPPU_PeekAddress()
{
	if (newppu)
	{
		return ppur.get_2007access() & 0x3FFF;
	}

	return RefreshAddr & 0x3FFF;
}

//---------------------
int pputime = 0;
int totpputime = 0;
const int kLineTime = 341;
const int kFetchTime = 2;

void runppu(int x) {
	ppur.status.cycle = (ppur.status.cycle + x) % ppur.status.end_cycle;
	X6502_Run(x);
}

//todo - consider making this a 3 or 4 slot fifo to keep from touching so much memory
struct BGData {
	struct Record {
		uint8 nt, pecnt, at, pt[2];

		INLINE void Read() {
			RefreshAddr = ppur.get_ntread();
			if (PEC586Hack)
				ppur.s = (RefreshAddr & 0x200) >> 9;
			pecnt = (RefreshAddr & 1) << 3;
			nt = CALL_PPUREAD(RefreshAddr);
			runppu(kFetchTime);

			RefreshAddr = ppur.get_atread();
			at = CALL_PPUREAD(RefreshAddr);

			//modify at to get appropriate palette shift
			if (ppur.vt & 2) at >>= 4;
			if (ppur.ht & 2) at >>= 2;
			at &= 0x03;
			at <<= 2;
			//horizontal scroll clocked at cycle 3 and then
			//vertical scroll at 251
			runppu(1);
			if (PPUON) {
				ppur.increment_hsc();
				if (ppur.status.cycle == 251)
					ppur.increment_vs();
			}
			runppu(1);

			ppur.par = nt;
			RefreshAddr = ppur.get_ptread();
			if (PEC586Hack) {
				if (ScreenON)
					RENDER_LOG(RefreshAddr | pecnt);
				pt[0] = CALL_PPUREAD(RefreshAddr | pecnt);
				runppu(kFetchTime);
				pt[1] = CALL_PPUREAD(RefreshAddr | pecnt);
				runppu(kFetchTime);
			} else {
				if (ScreenON)
					RENDER_LOG(RefreshAddr);
				pt[0] = CALL_PPUREAD(RefreshAddr);
				runppu(kFetchTime);
				RefreshAddr |= 8;
				if (ScreenON)
					RENDER_LOG(RefreshAddr);
				pt[1] = CALL_PPUREAD(RefreshAddr);
				runppu(kFetchTime);
			}
		}
	};

	Record main[34];	//one at the end is junk, it can never be rendered
} bgdata;

static inline int PaletteAdjustPixel(int pixel) {
	if ((PPU[1] >> 5) == 0x7)
		return (pixel & 0x3f) | 0xc0;
	else if (PPU[1] & 0xE0)
		return pixel | 0x40;
	else
		return (pixel & 0x3F) | 0x80;
}

int framectr = 0;
int FCEUX_PPU_Loop(int skip) {
	//262 scanlines
	if (ppudead) {
		// not quite emulating all the NES power up behavior
		// since it is known that the NES ignores writes to some
		// register before around a full frame, but no games
		// should write to those regs during that time, it needs
		// to wait for vblank
		ppur.status.sl = 241;
		if (PAL)
			runppu(70 * kLineTime);
		else
			runppu(20 * kLineTime);
		ppur.status.sl = 0;
		runppu(242 * kLineTime);
		--ppudead;
		goto finish;
	}

	{
		PPU_status |= 0x80;
		ppuphase = PPUPHASE_VBL;

		//Not sure if this is correct.  According to Matt Conte and my own tests, it is.
		//Timing is probably off, though.
		//NOTE:  Not having this here breaks a Super Donkey Kong game.
		PPU[3] = PPUSPL = 0;
		const int delay = 20;	//fceu used 12 here but I couldnt get it to work in marble madness and pirates.

		ppur.status.sl = 241;	//for sprite reads

		//formerly: runppu(delay);
		for(int dot=0;dot<delay;dot++)
			runppu(1);

		if (VBlankON) TriggerNMI();
		int sltodo = PAL?70:20;
		
		//formerly: runppu(20 * (kLineTime) - delay);
		for(int S=0;S<sltodo;S++)
		{
			for(int dot=(S==0?delay:0);dot<kLineTime;dot++)
				runppu(1);
			ppur.status.sl++;
		}

		//this seems to run just before the dummy scanline begins
		PPU_status = 0;
		//this early out caused metroid to fail to boot. I am leaving it here as a reminder of what not to do
		//if(!PPUON) { runppu(kLineTime*242); goto finish; }

		//There are 2 conditions that update all 5 PPU scroll counters with the
		//contents of the latches adjacent to them. The first is after a write to
		//2006/2. The second, is at the beginning of scanline 20, when the PPU starts
		//rendering data for the first time in a frame (this update won't happen if
		//all rendering is disabled via 2001.3 and 2001.4).

		//if(PPUON)
		//	ppur.install_latches();

		static uint8 oams[2][64][8];//[7] turned to [8] for faster indexing
		static int oamcounts[2] = { 0, 0 };
		static int oamslot = 0;
		static int oamcount;

		//capture the initial xscroll
		//int xscroll = ppur.fh;
		//render 241/291 scanlines (1 dummy at beginning, dendy's 50 at the end)
		//ignore overclocking!
		for (int sl = 0; sl < normalscanlines; sl++) {
			spr_read.start_scanline();

			g_rasterpos = 0;
			ppur.status.sl = sl;

			linestartts = timestamp * 48 + X.count; // pixel timestamp for debugger

			const int yp = sl - 1;
			ppuphase = PPUPHASE_BG;

			if (sl != 0 && sl < 241) { // ignore the invisible
				DEBUG(FCEUD_UpdatePPUView(scanline = yp, 1));
				DEBUG(FCEUD_UpdateNTView(scanline = yp, 1));
			}

			if (MMC5Hack) MMC5_hb(yp);


			//twiddle the oam buffers
			const int scanslot = oamslot ^ 1;
			const int renderslot = oamslot;
			oamslot ^= 1;

			oamcount = oamcounts[renderslot];

			//the main scanline rendering loop:
			//32 times, we will fetch a tile and then render 8 pixels.
			//two of those tiles were read in the last scanline.
			for (int xt = 0; xt < 32; xt++) {
				bgdata.main[xt + 2].Read();

				//ok, we're also going to draw here.
				//unless we're on the first dummy scanline
				if (sl != 0 && sl < 241) { // cape at 240 for dendy, its PPU does nothing afterwards
					int xstart = xt << 3;
					oamcount = oamcounts[renderslot];
					uint8 * const target = XBuf + (yp << 8) + xstart;
					uint8 * const dtarget = XDBuf + (yp << 8) + xstart;
					uint8 *ptr = target;
					uint8 *dptr = dtarget;
					int rasterpos = xstart;

					//check all the conditions that can cause things to render in these 8px
					const bool renderspritenow = SpriteON && rendersprites && (xt > 0 || SpriteLeft8);
					const bool renderbgnow = ScreenON && renderbg && (xt > 0 || BGLeft8);
					for (int xp = 0; xp < 8; xp++, rasterpos++, g_rasterpos++) {
						//bg pos is different from raster pos due to its offsetability.
						//so adjust for that here
						const int bgpos = rasterpos + ppur.fh;
						const int bgpx = bgpos & 7;
						const int bgtile = bgpos >> 3;

						uint8 pixel = 0, pixelcolor;

						//according to qeed's doc, use palette 0 or $2006's value if it is & 0x3Fxx
						if (!ScreenON && !SpriteON)
						{
							// if there's anything wrong with how we're doing this, someone please chime in
							int addr = ppur.get_2007access();
							if ((addr & 0x3F00) == 0x3F00)
							{
								pixel = addr & 0x1F;
							}
							pixelcolor = PALRAM[pixel];
						}

						//generate the BG data
						if (renderbgnow) {
							uint8* pt = bgdata.main[bgtile].pt;
							pixel = ((pt[0] >> (7 - bgpx)) & 1) | (((pt[1] >> (7 - bgpx)) & 1) << 1) | bgdata.main[bgtile].at;
						}
						pixelcolor = READPAL(pixel);

						//look for a sprite to be drawn
						bool havepixel = false;
						for (int s = 0; s < oamcount; s++) {
							uint8* oam = oams[renderslot][s];
							int x = oam[3];
							if (rasterpos >= x && rasterpos < x + 8) {
								//build the pixel.
								//fetch the LSB of the patterns
								uint8 spixel = oam[4] & 1;
								spixel |= (oam[5] & 1) << 1;

								//shift down the patterns so the next pixel is in the LSB
								oam[4] >>= 1;
								oam[5] >>= 1;

								if (!renderspritenow) continue;

								//bail out if we already have a pixel from a higher priority sprite
								if (havepixel) continue;

								//transparent pixel bailout
								if (spixel == 0) continue;

								//spritehit:
								//1. is it sprite#0?
								//2. is the bg pixel nonzero?
								//then, it is spritehit.
								if (oam[6] == 0 && (pixel & 3) != 0 &&
									rasterpos < 255) {
									PPU_status |= 0x40;
								}
								havepixel = true;

								//priority handling
								if (oam[2] & 0x20) {
									//behind background:
									if ((pixel & 3) != 0) continue;
								}

								//bring in the palette bits and palettize
								spixel |= (oam[2] & 3) << 2;
								pixelcolor = READPAL(0x10 + spixel);
							}
						}

						*ptr++ = PaletteAdjustPixel(pixelcolor);
						*dptr++= PPU[1]>>5; //grab deemph
					}
				}
			}

			//look for sprites (was supposed to run concurrent with bg rendering)
			oamcounts[scanslot] = 0;
			oamcount = 0;
			const int spriteHeight = Sprite16 ? 16 : 8;
			for (int i = 0; i < 64; i++) {
				oams[scanslot][oamcount][7] = 0;
				uint8* spr = SPRAM + i * 4;
				if (yp >= spr[0] && yp < spr[0] + spriteHeight) {
					//if we already have maxsprites, then this new one causes an overflow,
					//set the flag and bail out.
					if (oamcount >= 8 && PPUON) {
						PPU_status |= 0x20;
						if (maxsprites == 8)
							break;
					}

					//just copy some bytes into the internal sprite buffer
					for (int j = 0; j < 4; j++)
						oams[scanslot][oamcount][j] = spr[j];
					oams[scanslot][oamcount][7] = 1;

					//note that we stuff the oam index into [6].
					//i need to turn this into a struct so we can have fewer magic numbers
					oams[scanslot][oamcount][6] = (uint8)i;
					oamcount++;
				}
			}
			oamcounts[scanslot] = oamcount;

			//FV is clocked by the PPU's horizontal blanking impulse, and therefore will increment every scanline.
			//well, according to (which?) tests, maybe at the end of hblank.
			//but, according to what it took to get crystalis working, it is at the beginning of hblank.

			//this is done at cycle 251
			//rendering scanline, it doesn't need to be scanline 0,
			//because on the first scanline when the increment is 0, the vs_scroll is reloaded.
			//if(PPUON && sl != 0)
			//	ppur.increment_vs();

			//todo - think about clearing oams to a predefined value to force deterministic behavior

			ppuphase = PPUPHASE_OBJ;

			//fetch sprite patterns
			for (int s = 0; s < maxsprites; s++) {
				//if we have hit our eight sprite pattern and we dont have any more sprites, then bail
				if (s == oamcount && s >= 8)
					break;

				//if this is a real sprite sprite, then it is not above the 8 sprite limit.
				//this is how we support the no 8 sprite limit feature.
				//not that at some point we may need a virtual CALL_PPUREAD which just peeks and doesnt increment any counters
				//this could be handy for the debugging tools also
				const bool realSprite = (s < 8);

				uint8* const oam = oams[scanslot][s];
				uint32 line = yp - oam[0];
				if (oam[2] & 0x80)	//vflip
					line = spriteHeight - line - 1;

				uint32 patternNumber = oam[1];
				uint32 patternAddress;

				//create deterministic dummy fetch pattern
				if (!oam[7]) {
					patternNumber = 0;
					line = 0;
				}

				//8x16 sprite handling:
				if (Sprite16) {
					uint32 bank = (patternNumber & 1) << 12;
					patternNumber = patternNumber & ~1;
					patternNumber |= (line >> 3);
					patternAddress = (patternNumber << 4) | bank;
				} else {
					patternAddress = (patternNumber << 4) | (SpAdrHI << 9);
				}

				//offset into the pattern for the current line.
				//tricky: tall sprites have already had lines>8 taken care of by getting a new pattern number above.
				//so we just need the line offset for the second pattern
				patternAddress += line & 7;

				//garbage nametable fetches
				int garbage_todo = 2;
				if (PPUON)
				{
					if (sl == 0 && ppur.status.cycle == 304)
					{
						runppu(1);
						if (PPUON) ppur.install_latches();
						runppu(1);
						garbage_todo = 0;
					}
					if ((sl != 0 && sl < 241) && ppur.status.cycle == 256)
					{
						runppu(1);
						//at 257: 3d world runner is ugly if we do this at 256
						if (PPUON) ppur.install_h_latches();
						runppu(1);
						garbage_todo = 0;
					}
				}
				if (realSprite) runppu(garbage_todo);

				//Dragon's Lair (Europe version mapper 4)
				//does not set SpriteON in the beginning but it does
				//set the bg on so if using the conditional SpriteON the MMC3 counter
				//the counter will never count and no IRQs will be fired so use PPUON
				if (((PPU[0] & 0x38) != 0x18) && s == 2 && PPUON) {
					//(The MMC3 scanline counter is based entirely on PPU A12, triggered on rising edges (after the line remains low for a sufficiently long period of time))
					//http://nesdevwiki.org/wiki/index.php/Nintendo_MMC3
					//test cases for timing: SMB3, Crystalis
					//crystalis requires deferring this til somewhere in sprite [1,3]
					//kirby requires deferring this til somewhere in sprite [2,5..
					//if (PPUON && GameHBIRQHook) {
					if (GameHBIRQHook) {
						GameHBIRQHook();
					}
				}

				if (realSprite) runppu(kFetchTime);


				//pattern table fetches
				RefreshAddr = patternAddress;
				if (SpriteON)
					RENDER_LOG(RefreshAddr);
				oam[4] = CALL_PPUREAD(RefreshAddr);
				if (realSprite) runppu(kFetchTime);

				RefreshAddr += 8;
				if (SpriteON)
					RENDER_LOG(RefreshAddr);
				oam[5] = CALL_PPUREAD(RefreshAddr);
				if (realSprite) runppu(kFetchTime);

				//hflip
				if (!(oam[2] & 0x40)) {
					oam[4] = bitrevlut[oam[4]];
					oam[5] = bitrevlut[oam[5]];
				}
			}

			ppuphase = PPUPHASE_BG;

			//fetch BG: two tiles for next line
			for (int xt = 0; xt < 2; xt++)
				bgdata.main[xt].Read();

			//I'm unclear of the reason why this particular access to memory is made.
			//The nametable address that is accessed 2 times in a row here, is also the
			//same nametable address that points to the 3rd tile to be rendered on the
			//screen (or basically, the first nametable address that will be accessed when
			//the PPU is fetching background data on the next scanline).
			//(not implemented yet)
			runppu(kFetchTime);
			if (sl == 0) {
				if (idleSynch && PPUON && !PAL)
					ppur.status.end_cycle = 340;
				else
					ppur.status.end_cycle = 341;
				idleSynch ^= 1;
			} else
				ppur.status.end_cycle = 341;
			runppu(kFetchTime);

			//After memory access 170, the PPU simply rests for 4 cycles (or the
			//equivelant of half a memory access cycle) before repeating the whole
			//pixel/scanline rendering process. If the scanline being rendered is the very
			//first one on every second frame, then this delay simply doesn't exist.
			if (ppur.status.end_cycle == 341)
				runppu(1);
		}	//scanline loop

		DMC_7bit = 0;

		if (MMC5Hack) MMC5_hb(240);

		//idle for one line
		runppu(kLineTime);
		framectr++;
	}

finish:
	FCEU_PutImage();

	return 0;
}
