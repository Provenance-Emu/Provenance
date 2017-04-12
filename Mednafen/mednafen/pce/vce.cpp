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

/*  VCE and VPC emulation */

/*
<_Ki>	So here is what I found today: the /Hblank signal is not affected (at all) by VCE's dot clock selection.
  It seems to be completely fixed;  /HBlank-L-period = 237 x master clock cycles, and /HBlank-H-period = 1128, and 
  that makes h-period = 1365 x master clock cycles as a whole.
*/

#include "pce.h"
#include "huc.h"
#include <math.h>
#include <mednafen/video.h>
#include "vce.h"
#include <mednafen/hw_video/huc6270/vdc.h>
#include "debug.h"
#include "pcecd.h"
#include <trio/trio.h>

namespace MDFN_IEN_PCE
{

#define SUPERDUPERMODE	0

static const int vce_ratios[4] = { 4, 3, 2, 2 };

static void IRQChange_Hook(bool newstatus)
{
 extern VCE *vce; //HORRIBLE
 vce->IRQChangeCheck();
}

bool VCE::WS_Hook(int32 vdc_cycles)
{
 bool ret = true;
 int32 to_steal;

 if(vdc_cycles == -1) // Special event-based wait-stating
  to_steal = CalcNextEvent();
 else
  to_steal = ((vdc_cycles * dot_clock_ratio - clock_divider) + 2) / 3;

 if(to_steal <= 0) // This should never happen.  But in case it does...
 {
  printf("Bad steal: %d; Wanted VDC: %d; Dot clock ratio: %d; Clock divider: %d\n", to_steal, vdc_cycles, dot_clock_ratio, clock_divider);
  to_steal = 1;
 }

 if((to_steal + ws_counter) > 455 * 64)
 {
  printf("WS Over: Wanted: %d, could: %d\n", to_steal, 455 * 64 - ws_counter);
  to_steal = 455 * 64 - ws_counter;

  if(to_steal < 0)
   to_steal = 0;

  ret = FALSE;
 }

 if(to_steal > 0)
 {
  HuCPU->StealCycles(to_steal);
  ws_counter += to_steal;
 }

 return(ret);
}

static bool WS_Hook(int32 vdc_cycles)
{
 extern VCE *vce;

 return(vce->WS_Hook(vdc_cycles));
}

void VCE::IRQChangeCheck(void)
{
 bool irqtmp = 0;

 for(int chip = 0; chip < chip_count; chip++)
  irqtmp |= vdc[chip]->PeekIRQ();

 if(irqtmp)
  HuCPU->IRQBegin(HuC6280::IQIRQ1);
 else
  HuCPU->IRQEnd(HuC6280::IQIRQ1);
}

void VCE::SetShowHorizOS(bool show)
{
 ShowHorizOS = show;
}


VCE::VCE(bool want_sgfx, bool nospritelimit)
{
 ShowHorizOS = false;

 sgfx = want_sgfx;
 chip_count = sgfx ? 2 : 1;

 cd_event = 1;

 fb = NULL;
 pitch32 = 0;

 vdc[0] = vdc[1] = NULL;
 for(int chip = 0; chip < chip_count; chip++)
 {
  vdc[chip] = new VDC(nospritelimit, MDFN_GetSettingUI("pce.vramsize"));
  vdc[chip]->SetIRQHook(IRQChange_Hook);
  vdc[chip]->SetWSHook(MDFN_IEN_PCE::WS_Hook);
 }

 memset(systemColorMap32, 0, sizeof(systemColorMap32));

 #ifdef WANT_DEBUGGER
 GfxDecode_Buf = NULL;
 GfxDecode_Line = -1;
 GfxDecode_Layer = 0;
 GfxDecode_Scroll = 0;
 GfxDecode_Pbn = 0;
 #endif


 SetShowHorizOS(false);
}

VCE::~VCE()
{
 for(int chip = 0; chip < chip_count; chip++)
  delete vdc[chip];
}

void VCE::Reset(const int32 timestamp)
{
 last_ts = 0;

 pixel_offset = 0;
 dot_clock = 0;
 dot_clock_ratio = vce_ratios[dot_clock];
 clock_divider = 0;

 ws_counter = 0;
 scanline = 0;
 scanline_out_ptr = NULL;
 CR = 0;
 lc263 = 0;
 bw = 0;

 memset(color_table, 0, sizeof(color_table));
 memset(color_table_cache, 0, sizeof(color_table_cache));

 ctaddress = 0;

 hblank = 1;
 vblank = 1;

 NeedSLReset = false;

 hblank_counter = 237;
 vblank_counter = 4095 + 30;

 for(int chip = 0; chip < chip_count; chip++)
  child_event[chip] = vdc[chip]->Reset();

 // SuperGrafx VPC init
 priority[0] = 0x11;
 priority[1] = 0x11;
 winwidths[0] = 0;
 winwidths[1] = 0;
 st_mode = 0;
 window_counter[0] = 0x40;
 window_counter[1] = 0x40;

 if(fb)
  scanline_out_ptr = &fb[scanline * pitch32];
}

static int32 *LW;

static bool skipframe;

/*
 Note:  If we're skipping the frame, don't write to the data behind the pXBuf, DisplayRect, and LineWidths
 pointers at all.  There's no need to, and HES playback depends on these structures being left alone; if they're not,
 there will be graphics distortion, and maybe memory corruption.
*/

void VCE::StartFrame(MDFN_Surface *surface, MDFN_Rect *DisplayRect, int32 *LineWidths, int skip)
{
 uint32 *pXBuf = surface->pixels;

 FrameDone = false;

 //printf("Clock divider: %d\n", clock_divider);

 color_table_cache[0x200] = color_table_cache[0x300] = surface->format.MakeColor(0x00, 0xFE, 0x00);

 if(!skip)
 {
  DisplayRect->x = 0;
  DisplayRect->w = 1365;
  DisplayRect->y = 0 + 14;
  DisplayRect->h = 240; //263 - 14;

  DisplayRect->y = 14 + MDFN_GetSettingUI("pce.slstart");
  DisplayRect->h = MDFN_GetSettingUI("pce.slend") - MDFN_GetSettingUI("pce.slstart") + 1;

  for(int y = 0; y < 263; y++)
   LineWidths[y] = 0;

  pitch32 = surface->pitch32;
  fb = pXBuf;
  LW = LineWidths;
  scanline_out_ptr = &fb[scanline * pitch32];
 }
 else
 {
  pitch32 = 0;
  fb = NULL;
  LW = NULL;
  scanline_out_ptr = NULL;
 }

 skipframe = skip;
}

bool VCE::RunPartial(void)
{
 HuCPU->SetEventHandler(this);

 if(!PCE_IsCD)
  cd_event = 0x3FFFFFFF;

 ws_counter = 0;
 HuCPU->Run();

 if(!skipframe)
 {
  // Worst-case fallback
  int32 LW_Fix = 256;

  for(int y = 0; y < 263; y++)
  {
   if(LW[y])
   {
    LW_Fix = LW[y];
    break;
   }
  }

  for(int y = 0; y < 263; y++)
  {
   if(!LW[y])
    LW[y] = LW_Fix;
  }
 }

 Update(HuCPU->Timestamp());

 return(FrameDone);
}

void VCE::Update(const int32 timestamp)
{
 if(PCE_IsCD)
  SetCDEvent(PCECD_Run(timestamp));

 HuCPU->SetEvent(Sync(timestamp));
}

// If we ignore the return value of Sync(), we must do "HuCPU->SetEvent(CalcNextEvent());"
// before the function(read/write functions) that called Sync() return!
int32 VCE::Sync(const int32 timestamp)
{
 int32 clocks = timestamp - last_ts;

 cd_event -= clocks;
 if(cd_event <= 0)
  cd_event = PCECD_Run(timestamp);


 if(sgfx)
 {
  #define VCE_SGFX_MODE 1
  #include "vce_sync.inc"
  #undef VCE_SGFX_MODE
 }
 else
 {
  #include "vce_sync.inc"
 }

 int32 ret = CalcNextEvent();

 last_ts = timestamp;

 return(ret);
}

void VCE::FixPCache(int entry)
{
 const uint32 *cm32 = systemColorMap32[bw];

 if(!(entry & 0xFF))
 {
  for(int x = 0; x < 16; x++)
   color_table_cache[(entry & 0x100) + (x << 4)] = cm32[color_table[entry & 0x100]];
 }
 if(!(entry & 0xF))
  return;

 color_table_cache[entry] = cm32[color_table[entry]];
}

void VCE::SetVCECR(uint8 V)
{
 if(((V & 0x80) >> 7) != bw)
 {
  bw = V & 0x80;
  for(int x = 0; x < 512; x++)
   FixPCache(x);
 }

 lc263 = (V & 0x04);

 #if 0
 int new_dot_clock = V & 1;
 if(V & 2)
  new_dot_clock = 2;

 dot_clock = new_dot_clock;
 #endif

 dot_clock = V & 0x3;
 if(dot_clock == 3)	// Remove this once we determine any relevant differences between 2 and 3.
  dot_clock = 2;

 dot_clock_ratio = vce_ratios[dot_clock];

 CR = V;
}

void VCE::SetPixelFormat(const MDFN_PixelFormat &format, const uint8* CustomColorMap, const uint32 CustomColorMapLen)
{
 for(int x = 0; x < 512; x++)
 {
  int r, g, b;
  int sc_r, sc_g, sc_b;

  if(CustomColorMap)
  {
   r = CustomColorMap[x * 3 + 0];
   g = CustomColorMap[x * 3 + 1];
   b = CustomColorMap[x * 3 + 2];
  }
  else
  {
   b = 36 * (x & 0x007);
   r = 36 * ((x & 0x038) >> 3);
   g = 36 * ((x & 0x1c0) >> 6);
  }

  if(CustomColorMap && CustomColorMapLen == 1024)
  {
   sc_r = CustomColorMap[(512 + x) * 3 + 0];
   sc_g = CustomColorMap[(512 + x) * 3 + 1];
   sc_b = CustomColorMap[(512 + x) * 3 + 2];
  }
  else
  {
   double y;

   y = floor(0.5 + 0.300 * r + 0.589 * g + 0.111 * b);

   if(y < 0)
    y = 0;

   if(y > 255)
    y = 255;

   sc_r = sc_g = sc_b = y;
  }

  systemColorMap32[0][x] = format.MakeColor(r, g, b);
  systemColorMap32[1][x] = format.MakeColor(sc_r, sc_g, sc_b);
 }

 // I know the temptation is there, but don't combine these two loops just
 // because they loop 512 times ;)
 for(int x = 0; x < 512; x++)
  FixPCache(x);
}

uint8 VCE::Read(uint32 A)
{
 uint8 ret = 0xFF;

 if(!PCE_InDebug)
  Sync(HuCPU->Timestamp());

 switch(A & 0x7)
 {
  case 4: ret = color_table[ctaddress & 0x1FF];
	  break;

  case 5: ret = color_table[ctaddress & 0x1FF] >> 8;
	  ret &= 1;
	  ret |= 0xFE;
	  if(!PCE_InDebug)
	  {
	   ctaddress++;
	  }
	  break;
 }

 if(!PCE_InDebug)
  HuCPU->SetEvent(CalcNextEvent());

 return(ret);
}

void VCE::Write(uint32 A, uint8 V)
{
 Sync(HuCPU->Timestamp());

 //printf("VCE Write(vce scanline=%d, HuCPU.timestamp=%d): %04x %02x\n", scanline, HuCPU.timestamp, A, V);
 switch(A&0x7)
 {
  case 0:
	  {
	   int old_dot_clock = dot_clock;

	   SetVCECR(V);

	   if(old_dot_clock != dot_clock)	// FIXME, this is wrong.  A total fix will require changing the meaning
						// of clock_divider variable.
	   {
	    clock_divider = 0;
	   }
	  }
	  break;

  case 2: ctaddress &= 0x100; ctaddress |= V; break;
  case 3: ctaddress &= 0x0FF; ctaddress |= (V & 1) << 8; break;

  case 4: color_table[ctaddress & 0x1FF] &= 0x100;
	  color_table[ctaddress & 0x1FF] |= V;
	  FixPCache(ctaddress & 0x1FF);
          break;

  case 5: color_table[ctaddress & 0x1FF] &= 0xFF;
	  color_table[ctaddress & 0x1FF] |= (V & 1) << 8;
	  FixPCache(ctaddress & 0x1FF);
	  ctaddress++;
	  break;
 }

 HuCPU->SetEvent(CalcNextEvent());
}

uint8 VCE::ReadVDC(uint32 A)
{
 uint8 ret;

 if(!PCE_InDebug)
  Sync(HuCPU->Timestamp());

 if(!sgfx)
 {
  ret = vdc[0]->Read(A, child_event[0], PCE_InDebug);
 }
 else
 {
  int chip = 0;

  A &= 0x1F;

  if(A & 0x8)
  {
   ret = 0;

   switch(A)
   {
    case 0x8: ret = priority[0]; break;
    case 0x9: ret = priority[1]; break;
    case 0xA: ret = winwidths[0]; break;
    case 0xB: ret = winwidths[0] >> 8; break;
    case 0xC: ret = winwidths[1]; break;
    case 0xD: ret = winwidths[1] >> 8; break;
    case 0xE: ret = 0; break;
   }
  }
  else
  {
   chip = (A & 0x10) >> 4;
   ret = vdc[chip]->Read(A & 0x3, child_event[chip], PCE_InDebug);
  }
 }

 if(!PCE_InDebug)
  HuCPU->SetEvent(CalcNextEvent());

 return(ret);
}

void VCE::WriteVDC(uint32 A, uint8 V)
{
 Sync(HuCPU->Timestamp());

 if(!sgfx)
 {
  vdc[0]->Write(A & 0x1FFF, V, child_event[0]);
 }
 else
 {
  int chip = 0;

  // For ST0/ST1/ST2
  A |= ((A >> 31) & st_mode) << 4;

  A &= 0x1F;

  if(A & 0x8)
  {
   switch(A)
   {
    case 0x8: priority[0] = V; break;
    case 0x9: priority[1] = V; break;
    case 0xA: winwidths[0] &= 0x300; winwidths[0] |= V; break;
    case 0xB: winwidths[0] &= 0x0FF; winwidths[0] |= (V & 3) << 8; break;
    case 0xC: winwidths[1] &= 0x300; winwidths[1] |= V; break;
    case 0xD: winwidths[1] &= 0x0FF; winwidths[1] |= (V & 3) << 8; break;
    case 0xE: st_mode = V & 1; break;
   }
  }
  else
  {
   chip = (A & 0x10) >> 4;
   vdc[chip]->Write(A & 0x3, V, child_event[chip]);
  }
 }

 HuCPU->SetEvent(CalcNextEvent());
}

void VCE::WriteVDC_ST(uint32 A, uint8 V)
{
 Sync(HuCPU->Timestamp());

 if(!sgfx)
 {
  vdc[0]->Write(A, V, child_event[0]);
 }
 else
 {
  int chip = st_mode & 1;
  vdc[chip]->Write(A, V, child_event[chip]);
 }

 HuCPU->SetEvent(CalcNextEvent());
}

void VCE::SetLayerEnableMask(uint64 mask)
{
 for(unsigned chip = 0; chip < (unsigned)chip_count; chip++)
 {
  vdc[chip]->SetLayerEnableMask((mask >> (chip * 2)) & 0x3);
 }
}

void VCE::StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 SFORMAT VCE_StateRegs[] =
 {
  SFVARN(CR, "VCECR"),

  SFVAR(ws_counter),

  SFVARN(ctaddress, "ctaddress"),
  SFARRAY16N(color_table, 0x200, "color_table"),

  SFVARN(clock_divider, "clock_divider"),
  SFARRAY32N(child_event, 2, "child_event"),
  SFVARN(scanline, "scanline"),
  SFVARN(pixel_offset, "pixel_offset"),
  SFVARN(hblank_counter, "hblank_counter"),
  SFVARN(vblank_counter, "vblank_counter"),
  SFVAR(hblank),
  SFVAR(vblank),
  SFVAR(NeedSLReset),
  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, VCE_StateRegs, "VCE");

 if(sgfx)
 {
  SFORMAT VPC_StateRegs[] =
  {
   SFARRAYN(priority, 2, "priority"),
   SFARRAY16N(winwidths, 2, "winwidths"),
   SFVARN(st_mode, "st_mode"),
   SFARRAY32N(window_counter, 2, "window_counter"),
   SFEND
  };

  MDFNSS_StateAction(sm, load, data_only, VPC_StateRegs, "VPC");
 }

 if(load)
 {
  // TODO/FIXME:  Integrity checks to prevent buffer overflows.
  SetVCECR(CR);
  for(int x = 0; x < 512; x++)
   FixPCache(x);
 }

 for(int chip = 0; chip < chip_count; chip++)
  vdc[chip]->StateAction(sm, load, data_only, chip ? "VDCB" : "VDC");
}


#ifdef WANT_DEBUGGER

uint32 VCE::GetRegister(const unsigned int id, char *special, const uint32 special_len)
{
 uint32 value = 0xDEADBEEF;

 switch(id)
 {
  case GSREG_CR:
		value = CR;
		if(special)
		{
		 trio_snprintf(special, special_len, "Clock: %.2fMHz, %d lines/frame, Strip colorburst: %s",
				floor(0.5 + PCE_MASTER_CLOCK / 1e4 / vce_ratios[(value & 0x3) &~ ((value & 0x2) >> 1)]) / 100,
				(value & 0x04) ? 263 : 262,
				(value & 0x80) ? "On" : "Off");
		}
		break;

  case GSREG_CTA:
		value = ctaddress;
		break;

  case GSREG_SCANLINE:
		value = scanline;
		break;

  // VPC:
  case GSREG_ST_MODE:
		value = st_mode;
		break;

  case GSREG_WINDOW_WIDTH_0:
  case GSREG_WINDOW_WIDTH_1:
		value = winwidths[id - GSREG_WINDOW_WIDTH_0];
		if(special)
		{
		 trio_snprintf(special, special_len, "Window width: %d%s", value - 0x40, (value <= 0x40) ? "(window disabled)" : "");
		}
		break;

  case GSREG_PRIORITY_0:
  case GSREG_PRIORITY_1:
		value = priority[id - GSREG_PRIORITY_0];
		break;
 }
 return(value);
}

void VCE::SetRegister(const unsigned int id, const uint32 value)
{
 switch(id)
 {
  case GSREG_CR:
		SetVCECR(value);
		break;

  case GSREG_CTA:
		ctaddress = value & 0x1FF;
		break;
  // VPC:
  case GSREG_ST_MODE:
                st_mode = (bool)value;
                break;

  case GSREG_WINDOW_WIDTH_0:
  case GSREG_WINDOW_WIDTH_1:
                winwidths[id - GSREG_WINDOW_WIDTH_0] = value & 0x3FF;
                break;

  case GSREG_PRIORITY_0:
  case GSREG_PRIORITY_1:
                priority[id - GSREG_PRIORITY_0] = value;
                break;

 }
}

void VCE::SetGraphicsDecode(MDFN_Surface *surface, int line, int which, int xscroll, int yscroll, int pbn)
{
 GfxDecode_Buf = surface;
 GfxDecode_Line = line;
 GfxDecode_Layer = which;
 GfxDecode_Scroll = yscroll;
 GfxDecode_Pbn = pbn;

 if(GfxDecode_Buf && GfxDecode_Line == -1)
  DoGfxDecode();
}

uint32 VCE::GetRegisterVDC(const unsigned int which_vdc, const unsigned int id, char *special, const uint32 special_len)
{
 assert(which_vdc < (unsigned int)chip_count);

 return(vdc[which_vdc]->GetRegister(id, special, special_len));
}

void VCE::SetRegisterVDC(const unsigned int which_vdc, const unsigned int id, const uint32 value)
{
 assert(which_vdc < (unsigned int)chip_count);

 vdc[which_vdc]->SetRegister(id, value);
}


uint16 VCE::PeekPRAM(const uint16 Address)
{
 return(color_table[Address & 0x1FF]);
}

void VCE::PokePRAM(const uint16 Address, const uint16 Data)
{ 
 color_table[Address & 0x1FF] = Data & 0x1FF;
 FixPCache(Address);
}


void VCE::DoGfxDecode(void)
{
 const int which_vdc = (GfxDecode_Layer >> 1) & 1;
 const bool DecodeSprites = GfxDecode_Layer & 1;
 uint32 neo_palette[16];

 assert(GfxDecode_Buf);

 if(GfxDecode_Pbn == -1)
 {
  for(int x = 0; x < 16; x++)
   neo_palette[x] = GfxDecode_Buf->MakeColor(x * 17, x * 17, x * 17, 0xFF);
 }
 else
  for(int x = 0; x < 16; x++)
   neo_palette[x] = color_table_cache[x | (DecodeSprites ? 0x100 : 0x000) | ((GfxDecode_Pbn & 0xF) << 4)] | GfxDecode_Buf->MakeColor(0, 0, 0, 0xFF);

 vdc[which_vdc]->DoGfxDecode(GfxDecode_Buf->pixels, neo_palette, GfxDecode_Buf->MakeColor(0, 0, 0, 0xFF), DecodeSprites, GfxDecode_Buf->w, GfxDecode_Buf->h, GfxDecode_Scroll);
}
#endif

};
