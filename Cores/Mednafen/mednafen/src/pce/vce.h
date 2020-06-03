/* Mednafen - Multi-system Emulator
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
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#ifndef __MDFN_PCE_VCE_H
#define __MDFN_PCE_VCE_H

#include "huc6280.h"
#include <mednafen/hw_video/huc6270/vdc.h>

namespace MDFN_IEN_PCE
{

class VCE final
{
	public:

	VCE(const bool want_sgfx, const uint32 vram_size = 32768) MDFN_COLD;
	~VCE() MDFN_COLD;

	void SetVDCUnlimitedSprites(const bool nospritelimit);
	void SetShowHorizOS(bool show);
	void SetLayerEnableMask(uint64 mask);

	void StateAction(StateMem *sm, const unsigned load, const bool data_only);

	void SetPixelFormat(const MDFN_PixelFormat &format, const uint8* CustomColorMap, const uint32 CustomColorMapLen);

	void StartFrame(MDFN_Surface *surface, MDFN_Rect *DisplayRect, int32 *LineWidths, int skip);
	bool RunPartial(void);

        void Update(const int32 timestamp);

	INLINE void ResetTS(int ts_base)
	{
	 last_ts = ts_base;
	}

	inline int GetScanlineNo(void)
	{
	 return(scanline);
	}

	void Reset(const int32 timestamp);

	void Write(uint32 A, uint8 V);
	uint8 Read(uint32 A);

        uint8 ReadVDC(uint32 A);
        void WriteVDC(uint32 A, uint8 V);
        void WriteVDC_ST(uint32 A, uint8 V);

	#ifdef WANT_DEBUGGER

	INLINE uint16 PeekPRAM(const uint16 Address)
	{
	 return color_table[Address & 0x1FF];
	}

	INLINE void PokePRAM(const uint16 Address, const uint16 Data)
	{
	 color_table[Address & 0x1FF] = Data & 0x1FF;
	 FixPCache(Address);
	}

        // Peek(VRAM/SAT) and Poke(VRAM/SAT) work in 16-bit VRAM word units(Address and Length, both).
        INLINE uint16 PeekVDCVRAM(unsigned int which, uint16 Address)
        {
	 assert(which < (unsigned int)chip_count);

	 return(vdc[which].PeekVRAM(Address));
        }

        INLINE uint16 PeekVDCSAT(unsigned int which, uint8 Address)
        {
	 assert(which < (unsigned int)chip_count);

	 return(vdc[which].PeekSAT(Address));
        }

        INLINE void PokeVDCVRAM(const unsigned int which, const uint16 Address, const uint16 Data)
	{
	 assert(which < (unsigned int)chip_count);

	 vdc[which].PokeVRAM(Address, Data);
	}

        INLINE void PokeVDCSAT(const unsigned int which, const uint8 Address, const uint16 Data)
	{
	 assert(which < (unsigned int)chip_count);

	 vdc[which].PokeSAT(Address, Data);
	}

	void SetGraphicsDecode(MDFN_Surface *surface, int line, int which, int xscroll, int yscroll, int pbn);

        enum
        {
         GSREG_CR = 0,
         GSREG_CTA,
         GSREG_SCANLINE,

	 // VPC:
	 GSREG_PRIORITY_0,
	 GSREG_PRIORITY_1,
	 GSREG_WINDOW_WIDTH_0,
	 GSREG_WINDOW_WIDTH_1,
	 GSREG_ST_MODE
	};

        uint32 GetRegister(const unsigned int id, char *special, const uint32 special_len);
        void SetRegister(const unsigned int id, const uint32 value);

	INLINE uint32 GetRegisterVDC(const unsigned int which_vdc, const unsigned int id, char *special, const uint32 special_len)
	{
	 assert(which_vdc < chip_count);
	 return vdc[which_vdc].GetRegister(id, special, special_len);
	}

	INLINE void SetRegisterVDC(const unsigned int which_vdc, const unsigned int id, const uint32 value)
	{
	 assert(which_vdc < chip_count);
	 vdc[which_vdc].SetRegister(id, value);
	}
	
	INLINE void ResetSimulateVDC(void)
	{
	 for(unsigned chip = 0; chip < chip_count; chip++)
	  vdc[chip].ResetSimulate();
	}

	INLINE int SimulateReadVDC(uint32 A, VDC_SimulateResult *result)
	{
	 if(!sgfx)
	 {
	  vdc[0].SimulateRead(A, result);
	  return(0);
	 }
	 else
	 {
	  int chip = 0;

	  A &= 0x1F;

	  if(!(A & 0x8))
	  {
	   chip = (A & 0x10) >> 4;
	   vdc[chip].SimulateRead(A & 0x3, result);
	   return(chip);
	  }
	 }

         result->ReadCount = result->WriteCount = 0;
         return(0);
	}

	// If the simulated write is due to a ST0, ST1, or ST2 instruction, set the high bit of the passed address to 1.
	INLINE int SimulateWriteVDC(uint32 A, uint8 V, VDC_SimulateResult *result)
	{
	 if(!sgfx)
	 {
	  vdc[0].SimulateWrite(A, V, result);
	  return(0);
	 }
	 else
	 {
	  // For ST0/ST1/ST2
	  A |= ((A >> 31) & st_mode) << 4;

	  A &= 0x1F;

	  if(!(A & 0x8))
	  {
	   int chip = (A & 0x10) >> 4;
	   vdc[chip].SimulateWrite(A & 0x3, V, result);
	   return(chip);
	  }
	 }

	 result->ReadCount = result->WriteCount = 0;
	 result->ReadStart = result->WriteStart = 0;
	 return(0);
	}
	#endif

        void IRQChangeCheck(void);

        bool WS_Hook(int32 vdc_cycles);

	void SetCDEvent(const int32 cycles);

	//
	//
	//
	//
	//
	//
        int32 SyncReal(const int32 timestamp);
	private:

	template<bool TA_SuperGrafx, bool TA_AwesomeMode>
	void SyncSub(int32 clocks);

        void FixPCache(int entry);
        void SetVCECR(uint8 V);

	#ifdef WANT_DEBUGGER
	void DoGfxDecode(void);
	#endif

	int32 CalcNextEvent(void);
	int32 child_event[2];

        int32 cd_event;

	uint32 *fb;	// Pointer to the framebuffer.
	uint32 pitch32;	// Pitch(in 32-bit pixels)
	bool FrameDone;
	bool ShowHorizOS;
	bool sgfx;

	bool skipframe;
	int32 *LW;
	unsigned chip_count;	// = 1 when sgfx is false, = 2 when sgfx is true

	int32 clock_divider;

	int32 scanline;
	uint32 *scanline_out_ptr;	// Pointer into fb
	int32 pixel_offset;

	int32 hblank_counter;
	int32 vblank_counter;

	bool hblank;	// true if in HBLANK, false if not.
	bool vblank;	// true if in vblank, false if not

	bool NeedSLReset;

        uint8 CR;		// Control Register
        bool lc263;     	// CR->263 line count if set, 262 if not
        bool bw;        	// CR->Black and White
        uint8 dot_clock;	// CR->Dot Clock(5, 7, or 10 MHz = 0, 1, 2/3)
	int32 dot_clock_ratio;	// CR->Dot Clock ratio cache

	int32 ws_counter;

	int32 last_ts;

	//
	// SuperGrafx HuC6202 VPC state
	//
	int32 window_counter[2];
        uint16 winwidths[2];
        uint8 priority[2];
        uint8 st_mode;
	//
	//
	//
        uint16 ctaddress;
        uint32 color_table_cache[0x200 * 2];	// * 2 for user layer disabling stuff.
	uint16 pixel_buffer[2][2048];	// Internal temporary pixel buffers.
        uint16 color_table[0x200];
	uint32 surf_clut[2][512];

	VDC vdc[2];

	#ifdef WANT_DEBUGGER
	MDFN_Surface *GfxDecode_Buf;// = NULL;
	int GfxDecode_Line;// = -1;
	int GfxDecode_Layer;// = 0;
	int GfxDecode_Scroll;// = 0;
	int GfxDecode_Pbn;// = 0;
	#endif
};


};

#endif
