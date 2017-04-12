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

#include "psx.h"
#include "timer.h"

/*
 GPU display timing master clock is nominally 53.693182 MHz for NTSC PlayStations, and 53.203425 MHz for PAL PlayStations.

 Non-interlaced NTSC mode line timing notes(real-world times calculated via PS1 timer and math with nominal CPU clock value):

	263 lines per frame

	~16714.85 us per frame, average.
	~63.55456 us per line, average.

	Multiplying the results of counter 0 in pixel clock mode by the clock divider of the current dot clock mode/width gives a result that's slightly less
	than expected; the dot clock divider is probably being reset each scanline.

 Non-interlaced PAL mode(but with an NTSC source clock in an NTSC PS1; calculated same way as NTSC values):

	314 lines per frame

	~19912.27 us per frame, average.
	~63.41486 us per line, average.

 FB X and Y display positions can be changed during active display; and Y display position appears to be treated as an offset to the current Y readout
 position that gets reset around vblank time.

*/

/*
 November 29, 2012 notes:

  PAL mode can be turned on, and then off again, mid-frame(creates a neat effect).

  Pixel clock can be changed mid-frame with effect(the effect is either instantaneous, or cached at some point in the scanline, not tested to see which);
  interestingly, alignment is off on a PS1 when going 5MHz->10MHz>5MHz with a grid image.

  Vertical start and end can be changed during active display, with effect(though it needs to be vs0->ve0->vs1->ve1->..., vs0->vs1->ve0 doesn't apparently do anything 
  different from vs0->ve0.
*/

namespace MDFN_IEN_PSX
{

static const int8 dither_table[4][4] =
{
 { -4,  0, -3,  1 },
 {  2, -2,  3, -1 },
 { -3,  1, -4,  0 },
 {  3, -1,  2, -2 },
};

PS_GPU::PS_GPU(bool pal_clock_and_tv, int sls, int sle, bool show_h_overscan)
{
 HardwarePALType = pal_clock_and_tv;

 hide_hoverscan = !show_h_overscan;

 for(int y = 0; y < 4; y++)
  for(int x = 0; x < 4; x++)
   for(int v = 0; v < 512; v++)
   {
    int value = v + dither_table[y][x];

    value >>= 3;
 
    if(value < 0)
     value = 0;

    if(value > 0x1F)
     value = 0x1F;

    DitherLUT[y][x][v] = value;
   }

 if(HardwarePALType == false)	// NTSC clock
 {
  GPUClockRatio = 103896; // 65536 * 53693181.818 / (44100 * 768)
  hmc_to_visible = 520; 
 }
 else	// PAL clock
 {
  GPUClockRatio = 102948; // 65536 * 53203425 / (44100 * 768)
  hmc_to_visible = 560; 
 }

 LineVisFirst = sls;
 LineVisLast = sle;


 memcpy(&Commands[0x00], Commands_00_1F, sizeof(Commands_00_1F));
 memcpy(&Commands[0x20], Commands_20_3F, sizeof(Commands_20_3F));
 memcpy(&Commands[0x40], Commands_40_5F, sizeof(Commands_40_5F));
 memcpy(&Commands[0x60], Commands_60_7F, sizeof(Commands_60_7F));
 memcpy(&Commands[0x80], Commands_80_FF, sizeof(Commands_80_FF));
}

PS_GPU::~PS_GPU()
{

}

void PS_GPU::FillVideoParams(MDFNGI* gi)
{
 if(HardwarePALType)
 {
  gi->lcm_width = hide_hoverscan ? 2640 : 2800;
  gi->lcm_height = (LineVisLast + 1 - LineVisFirst) * 2; //576;

  gi->nominal_width = hide_hoverscan ? 363 : 384;	// More like 385.stuff according to calculations derived from BT.601, but 384 is a nicer number. :p
  gi->nominal_height = LineVisLast + 1 - LineVisFirst; //288;

  gi->fb_width = 768;
  gi->fb_height = 576;

  gi->fps = 836203078;

  gi->VideoSystem = VIDSYS_PAL;
 }
 else
 {
  gi->lcm_width = hide_hoverscan ? 2640 : 2800;
  gi->lcm_height = (LineVisLast + 1 - LineVisFirst) * 2; //480;

  gi->nominal_width = (hide_hoverscan ? 302 : 320);
  gi->nominal_height = LineVisLast + 1 - LineVisFirst; //240;

  gi->fb_width = 768;
  gi->fb_height = 480;

  gi->fps = 1005643085;

  gi->VideoSystem = VIDSYS_NTSC;
 }


 //
 // For Justifier and Guncon.
 //
 gi->mouse_scale_x = (float)gi->lcm_width / gi->nominal_width;
 gi->mouse_offs_x = (float)(2800 - gi->lcm_width) / 2;

 gi->mouse_scale_y = 1.0;
 gi->mouse_offs_y = LineVisFirst;
}

void PS_GPU::SoftReset(void) // Control command 0x00
{
 IRQPending = false;
 IRQ_Assert(IRQ_GPU, IRQPending);

 InvalidateCache();

 DMAControl = 0;

 if(DrawTimeAvail < 0)
  DrawTimeAvail = 0;

 BlitterFIFO.Flush();
 DataReadBufferEx = 0;
 InCmd = INCMD_NONE;

 DisplayOff = 1;
 DisplayFB_XStart = 0;
 DisplayFB_YStart = 0;

 DisplayMode = 0;

 HorizStart = 0x200;
 HorizEnd = 0xC00;

 VertStart = 0x10;
 VertEnd = 0x100;

 //
 TexPageX = 0;
 TexPageY = 0;

 SpriteFlip = 0;

 abr = 0;
 TexMode = 0;

 dtd = 0;
 dfe = 0;

 //
 tww = 0; 
 twh = 0; 
 twx = 0;
 twy = 0;

 RecalcTexWindowStuff();

 //
 ClipX0 = 0;
 ClipY0 = 0;

 //
 ClipX1 = 0;
 ClipY1 = 0;

 //
 OffsX = 0;
 OffsY = 0;

 //
 MaskSetOR = 0;
 MaskEvalAND = 0;

 TexDisable = false;
 TexDisableAllowChange = false;
}

void PS_GPU::Power(void)
{
 memset(GPURAM, 0, sizeof(GPURAM));

 memset(CLUT_Cache, 0, sizeof(CLUT_Cache));
 CLUT_Cache_VB = ~0U;

 memset(TexCache, 0xFF, sizeof(TexCache));

 DMAControl = 0;

 ClipX0 = 0;
 ClipY0 = 0;
 ClipX1 = 0;
 ClipY1 = 0;

 OffsX = 0;
 OffsY = 0;

 dtd = false;
 dfe = false;

 MaskSetOR = 0;
 MaskEvalAND = 0;

 TexDisable = false;
 TexDisableAllowChange = false;

 tww = 0;
 twh = 0;
 twx = 0;
 twy = 0;

 TexPageX = 0;
 TexPageY = 0;
 SpriteFlip = 0;

 abr = 0;
 TexMode = 0;

 RecalcTexWindowStuff();

 BlitterFIFO.Flush();
 DataReadBuffer = 0;	// Don't reset in SoftReset()
 DataReadBufferEx = 0;
 InCmd = INCMD_NONE;
 FBRW_X = 0;
 FBRW_Y = 0;
 FBRW_W = 0;
 FBRW_H = 0;
 FBRW_CurY = 0;
 FBRW_CurX = 0;

 DisplayMode = 0;
 DisplayOff = 1;
 DisplayFB_XStart = 0;
 DisplayFB_YStart = 0;

 HorizStart = 0;
 HorizEnd = 0;

 VertStart = 0;
 VertEnd = 0;

 //
 //
 //
 DisplayFB_CurYOffset = 0;
 DisplayFB_CurLineYReadout = 0;
 InVBlank = true;

 // TODO: factor out in a separate function.
 LinesPerField = 263;

 //
 //
 //
 scanline = 0;
 field = 0;
 field_ram_readout = 0;
 PhaseChange = 0;

 //
 //
 //
 DotClockCounter = 0;
 GPUClockCounter = 0;
 LineClockCounter = 3412 - 200;
 LinePhase = 0;

 DrawTimeAvail = 0;

 lastts = 0;

 SoftReset();

 IRQ_Assert(IRQ_VBLANK, InVBlank);
 TIMER_SetVBlank(InVBlank);
}

void PS_GPU::ResetTS(void)
{
 lastts = 0;
}

#include "gpu_common.inc"

// Special RAM write mode(16 pixels at a time), does *not* appear to use mask drawing environment settings.
INLINE void PS_GPU::Command_FBFill(const uint32 *cb)
{
 int32 r = cb[0] & 0xFF;
 int32 g = (cb[0] >> 8) & 0xFF;
 int32 b = (cb[0] >> 16) & 0xFF;
 const uint16 fill_value = ((r >> 3) << 0) | ((g >> 3) << 5) | ((b >> 3) << 10);

 int32 destX = (cb[1] >>  0) & 0x3F0;
 int32 destY = (cb[1] >> 16) & 0x3FF;

 int32 width =  (((cb[2] >> 0) & 0x3FF) + 0xF) & ~0xF;
 int32 height = (cb[2] >> 16) & 0x1FF;

 //printf("[GPU] FB Fill %d:%d w=%d, h=%d\n", destX, destY, width, height);
 DrawTimeAvail -= 46;	// Approximate

 for(int32 y = 0; y < height; y++)
 {
  const int32 d_y = (y + destY) & 511;

  if(LineSkipTest(d_y))
   continue;

  DrawTimeAvail -= (width >> 3) + 9;

  for(int32 x = 0; x < width; x++)
  {
   const int32 d_x = (x + destX) & 1023;

   GPURAM[d_y][d_x] = fill_value;
  }
 }
}

INLINE void PS_GPU::Command_FBCopy(const uint32 *cb)
{
 int32 sourceX = (cb[1] >> 0) & 0x3FF;
 int32 sourceY = (cb[1] >> 16) & 0x3FF;
 int32 destX = (cb[2] >> 0) & 0x3FF;
 int32 destY = (cb[2] >> 16) & 0x3FF;

 int32 width = (cb[3] >> 0) & 0x3FF;
 int32 height = (cb[3] >> 16) & 0x1FF;

 if(!width)
  width = 0x400;

 if(!height)
  height = 0x200;

 InvalidateTexCache();
 //printf("FB Copy: %d %d %d %d %d %d\n", sourceX, sourceY, destX, destY, width, height);

 DrawTimeAvail -= (width * height) * 2;

 for(int32 y = 0; y < height; y++)
 {
  for(int32 x = 0; x < width; x += 128)
  {
   const int32 chunk_x_max = std::min<int32>(width - x, 128);
   uint16 tmpbuf[128];	// TODO: Check and see if the GPU is actually (ab)using the texture cache(doesn't seem to be affecting CLUT cache...).

   for(int32 chunk_x = 0; chunk_x < chunk_x_max; chunk_x++)
   {
    int32 s_y = (y + sourceY) & 511;
    int32 s_x = (x + chunk_x + sourceX) & 1023;

    tmpbuf[chunk_x] = GPURAM[s_y][s_x];
   }

   for(int32 chunk_x = 0; chunk_x < chunk_x_max; chunk_x++)
   {
    int32 d_y = (y + destY) & 511;
    int32 d_x = (x + chunk_x + destX) & 1023;

    if(!(GPURAM[d_y][d_x] & MaskEvalAND))
     GPURAM[d_y][d_x] = tmpbuf[chunk_x] | MaskSetOR;
   }
  }
 }
}

INLINE void PS_GPU::Command_FBWrite(const uint32 *cb)
{
 assert(InCmd == INCMD_NONE);

 FBRW_X = (cb[1] >>  0) & 0x3FF;
 FBRW_Y = (cb[1] >> 16) & 0x3FF;

 FBRW_W = (cb[2] >>  0) & 0x3FF;
 FBRW_H = (cb[2] >> 16) & 0x1FF;

 if(!FBRW_W)
  FBRW_W = 0x400;

 if(!FBRW_H)
  FBRW_H = 0x200;

 FBRW_CurX = FBRW_X;
 FBRW_CurY = FBRW_Y;

 InvalidateTexCache();

 if(FBRW_W != 0 && FBRW_H != 0)
  InCmd = INCMD_FBWRITE;
}

//
// FBRead: PS1 GPU in SCPH-5501 gives odd, inconsistent results when raw_height == 0, or
// raw_height != 0x200 && (raw_height & 0x1FF) == 0
//
INLINE void PS_GPU::Command_FBRead(const uint32 *cb)
{
 assert(InCmd == INCMD_NONE);

 FBRW_X = (cb[1] >>  0) & 0x3FF;
 FBRW_Y = (cb[1] >> 16) & 0x3FF;

 FBRW_W = (cb[2] >>  0) & 0x3FF;
 FBRW_H = (cb[2] >> 16) & 0x3FF;

 if(!FBRW_W)
  FBRW_W = 0x400;

 if(FBRW_H > 0x200)
  FBRW_H &= 0x1FF;

 FBRW_CurX = FBRW_X;
 FBRW_CurY = FBRW_Y;

 InvalidateTexCache();

 if(FBRW_W != 0 && FBRW_H != 0)
  InCmd = INCMD_FBREAD;
}

/*
INLINE void PS_GPU::RecalcTexPageStuff(uint32 tpage)
{


}
*/

INLINE void PS_GPU::SetTPage(const uint32 cmdw)
{
 const unsigned NewTexPageX = (cmdw & 0xF) * 64;
 const unsigned NewTexPageY = (cmdw & 0x10) * 16;
 const unsigned NewTexMode = (cmdw >> 7) & 0x3;

 abr = (cmdw >> 5) & 0x3;

 if(!NewTexMode != !TexMode || NewTexPageX != TexPageX || NewTexPageY != TexPageY)
 {
  InvalidateTexCache();
 }

 if(TexDisableAllowChange)
 {
  bool NewTexDisable = (cmdw >> 11) & 1;

  if(NewTexDisable != TexDisable)
   InvalidateTexCache();

  TexDisable = NewTexDisable;
  //printf("TexDisable: %02x\n", TexDisable);
 }

 TexPageX = NewTexPageX;
 TexPageY = NewTexPageY;
 TexMode = NewTexMode;

 //
 //
 RecalcTexWindowStuff();
}

INLINE void PS_GPU::Command_DrawMode(const uint32 *cb)
{
 const uint32 cmdw = *cb;

 SetTPage(cmdw);

 SpriteFlip = cmdw & 0x3000;
 dtd = (cmdw >> 9) & 1;
 dfe = (cmdw >> 10) & 1;

 //printf("*******************DFE: %d -- scanline=%d\n", dfe, scanline);
}

INLINE void PS_GPU::Command_TexWindow(const uint32 *cb)
{
 tww = (*cb & 0x1F);
 twh = ((*cb >> 5) & 0x1F);
 twx = ((*cb >> 10) & 0x1F);
 twy = ((*cb >> 15) & 0x1F);

 RecalcTexWindowStuff();
}

INLINE void PS_GPU::Command_Clip0(const uint32 *cb)
{
 ClipX0 = *cb & 1023;
 ClipY0 = (*cb >> 10) & 1023;

 //fprintf(stderr, "[GPU] Clip0: x=%d y=%d, raw=0x%08x --- %d\n", ClipX0, ClipY0, *cb, scanline);
}

INLINE void PS_GPU::Command_Clip1(const uint32 *cb)
{
 ClipX1 = *cb & 1023;
 ClipY1 = (*cb >> 10) & 1023;

 //fprintf(stderr, "[GPU] Clip1: x=%d y=%d, raw=0x%08x --- %d\n", ClipX1, ClipY1, *cb, scanline);
}

INLINE void PS_GPU::Command_DrawingOffset(const uint32 *cb)
{
 OffsX = sign_x_to_s32(11, (*cb & 2047));
 OffsY = sign_x_to_s32(11, ((*cb >> 11) & 2047));

 //fprintf(stderr, "[GPU] Drawing offset: x=%d y=%d, raw=0x%08x --- %d\n", OffsX, OffsY, *cb, scanline);
}

INLINE void PS_GPU::Command_MaskSetting(const uint32 *cb)
{
 //printf("Mask setting: %08x\n", *cb);
 MaskSetOR = (*cb & 1) ? 0x8000 : 0x0000;
 MaskEvalAND = (*cb & 2) ? 0x8000 : 0x0000;
}

INLINE void PS_GPU::InvalidateTexCache(void)
{
 for(auto& c : TexCache)
  c.Tag = ~0U;
}

void PS_GPU::InvalidateCache(void)
{
 CLUT_Cache_VB = ~0U;

 InvalidateTexCache();
}

INLINE void PS_GPU::Command_ClearCache(const uint32 *cb)
{
 InvalidateCache();
}

INLINE void PS_GPU::Command_IRQ(const uint32 *cb)
{
 IRQPending = true;
 IRQ_Assert(IRQ_GPU, IRQPending);
}

//
// C-style function wrappers so our command table isn't so ginormous(in memory usage).
//
static void G_Command_ClearCache(PS_GPU* g, const uint32 *cb)
{
 g->Command_ClearCache(cb);
}

static void G_Command_IRQ(PS_GPU* g, const uint32 *cb)
{
 g->Command_IRQ(cb);
}

static void G_Command_FBFill(PS_GPU* g, const uint32 *cb)
{
 g->Command_FBFill(cb);
}

static void G_Command_FBCopy(PS_GPU* g, const uint32 *cb)
{
 g->Command_FBCopy(cb);
}

static void G_Command_FBWrite(PS_GPU* g, const uint32 *cb)
{
 g->Command_FBWrite(cb);
}

static void G_Command_FBRead(PS_GPU* g, const uint32 *cb)
{
 g->Command_FBRead(cb);
}

static void G_Command_DrawMode(PS_GPU* g, const uint32 *cb)
{
 g->Command_DrawMode(cb);
}

static void G_Command_TexWindow(PS_GPU* g, const uint32 *cb)
{
 g->Command_TexWindow(cb);
}

static void G_Command_Clip0(PS_GPU* g, const uint32 *cb)
{
 g->Command_Clip0(cb);
}

static void G_Command_Clip1(PS_GPU* g, const uint32 *cb)
{
 g->Command_Clip1(cb);
}

static void G_Command_DrawingOffset(PS_GPU* g, const uint32 *cb)
{
 g->Command_DrawingOffset(cb);
}

static void G_Command_MaskSetting(PS_GPU* g, const uint32 *cb)
{
 g->Command_MaskSetting(cb);
}

CTEntry PS_GPU::Commands[0x100];

const CTEntry PS_GPU::Commands_00_1F[0x20] =
{
 /* 0x00 */
 NULLCMD(),
 OTHER_HELPER(1, 2, false, G_Command_ClearCache),
 OTHER_HELPER(3, 3, false, G_Command_FBFill),

 NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(),
 NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(),

 /* 0x10 */
 NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(),
 NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(),

 /* 0x1F */
 OTHER_HELPER(1, 1, false,  G_Command_IRQ)
};

const CTEntry PS_GPU::Commands_80_FF[0x80] =
{
 /* 0x80 ... 0x9F */
 OTHER_HELPER_X32(4, 2, false, G_Command_FBCopy),

 /* 0xA0 ... 0xBF */
 OTHER_HELPER_X32(3, 2, false, G_Command_FBWrite),

 /* 0xC0 ... 0xDF */
 OTHER_HELPER_X32(3, 2, false, G_Command_FBRead),

 /* 0xE0 */

 NULLCMD(),
 OTHER_HELPER(1, 2, false, G_Command_DrawMode),
 OTHER_HELPER(1, 2, false, G_Command_TexWindow),
 OTHER_HELPER(1, 1, true,  G_Command_Clip0),
 OTHER_HELPER(1, 1, true,  G_Command_Clip1),
 OTHER_HELPER(1, 1, true,  G_Command_DrawingOffset),
 OTHER_HELPER(1, 2, false, G_Command_MaskSetting),

 NULLCMD(),
 NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(),

 /* 0xF0 */
 NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(),
 NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD(), NULLCMD()
};

void PS_GPU::ProcessFIFO(void)
{
 if(!BlitterFIFO.CanRead())
  return;

 switch(InCmd)
 {
  default:
	abort();
	break;

  case INCMD_NONE:
	break;

  case INCMD_FBREAD:
	PSX_WARNING("[GPU] Command FIFO not empty while in FB Read?!");
	return;

  case INCMD_FBWRITE:
       {
  	uint32 InData = BlitterFIFO.Read();

  	for(int i = 0; i < 2; i++)
  	{
   	 if(!(GPURAM[FBRW_CurY & 511][FBRW_CurX & 1023] & MaskEvalAND))
    	  GPURAM[FBRW_CurY & 511][FBRW_CurX & 1023] = InData | MaskSetOR;

	 FBRW_CurX++;
   	 if(FBRW_CurX == (FBRW_X + FBRW_W))
	 {
	  FBRW_CurX = FBRW_X;
	  FBRW_CurY++;
	  if(FBRW_CurY == (FBRW_Y + FBRW_H))
	  {
	   InCmd = INCMD_NONE;
	   break;	// Break out of the for() loop.
	  }
	 }
	 InData >>= 16;
  	}
  	return;
       }
       break;

  case INCMD_QUAD:
       {
	if(DrawTimeAvail < 0)
	 return;

	const uint32 cc = InCmd_CC;
	const CTEntry *command = &Commands[cc];
	unsigned vl = 1 + (bool)(cc & 0x4) + (bool)(cc & 0x10);
	uint32 CB[3];

	if(BlitterFIFO.CanRead() >= vl)
	{
	 for(unsigned i = 0; i < vl; i++)
	 {
	  CB[i] = BlitterFIFO.Read();
	 }

	 command->func[abr][TexMode | (MaskEvalAND ? 0x4 : 0x0)](this, CB);
	}
	return;
       }
       break;

  case INCMD_PLINE:
       {
  	if(DrawTimeAvail < 0)
	 return;

	const uint32 cc = InCmd_CC;
	const CTEntry *command = &Commands[cc];
	unsigned vl = 1 + (bool)(InCmd_CC & 0x10);
	uint32 CB[2];

  	if((BlitterFIFO.Peek() & 0xF000F000) == 0x50005000)
	{
	 BlitterFIFO.Read();
	 InCmd = INCMD_NONE;
	 return;
	}

	if(BlitterFIFO.CanRead() >= vl)
	{
	 for(unsigned i = 0; i < vl; i++)
	 {
	  CB[i] = BlitterFIFO.Read();
	 }

	 command->func[abr][TexMode | (MaskEvalAND ? 0x4 : 0x0)](this, CB);
	}
	return;
       }
       break;
 }

 const uint32 cc = BlitterFIFO.Peek() >> 24;
 const CTEntry *command = &Commands[cc];

 if(DrawTimeAvail < 0 && !command->ss_cmd)
  return;

 if(BlitterFIFO.CanRead() >= command->len)
 {
  uint32 CB[0x10];

  for(unsigned i = 0; i < command->len; i++)
   CB[i] = BlitterFIFO.Read();

  if(!command->ss_cmd)
   DrawTimeAvail -= 2;

#if 0
  PSX_WARNING("[GPU] Command: %08x %s %d %d %d", CB[0], command->name, command->len, scanline, DrawTimeAvail);
  if(1)
  {
   printf("[GPU]    ");
   for(unsigned i = 0; i < command->len; i++)
    printf("0x%08x ", CB[i]);
   printf("\n");
  }
#endif
  // A very very ugly kludge to support texture mode specialization. fixme/cleanup/SOMETHING in the future.
  if(cc >= 0x20 && cc <= 0x3F && (cc & 0x4))
  {
   //
   // Don't alter SpriteFlip here.
   //
   SetTPage(CB[4 + ((cc >> 4) & 0x1)] >> 16);
  }

  if(!command->func[abr][TexMode])
  {
   if(CB[0])
    PSX_WARNING("[GPU] Unknown command: %08x, %d", CB[0], scanline);
  }
  else
  {
   command->func[abr][TexMode | (MaskEvalAND ? 0x4 : 0x0)](this, CB);
  }
 }
}

INLINE void PS_GPU::WriteCB(uint32 InData)
{
 if(BlitterFIFO.CanRead() >= 0x10 && (InCmd != INCMD_NONE || (BlitterFIFO.CanRead() - 0x10) >= Commands[BlitterFIFO.Peek() >> 24].fifo_fb_len))
 {
  PSX_DBG(PSX_DBG_WARNING, "GPU FIFO overflow!!!\n");
  return;
 }

 BlitterFIFO.Write(InData);
 ProcessFIFO();
}

void PS_GPU::Write(const pscpu_timestamp_t timestamp, uint32 A, uint32 V)
{
 V <<= (A & 3) * 8;

 if(A & 4)	// GP1 ("Control")
 {
  uint32 command = V >> 24;

  V &= 0x00FFFFFF;

  //PSX_WARNING("[GPU] Control command: %02x %06x %d", command, V, scanline);

  switch(command)
  {
   /*
    0x40-0xFF do NOT appear to be mirrors, at least not on my PS1's GPU.
   */
   default: PSX_WARNING("[GPU] Unknown control command %02x - %06x", command, V);
	    break;

   case 0x00:	// Reset GPU
	//printf("\n\n************ Soft Reset %u ********* \n\n", scanline);
	SoftReset();
	break;

   case 0x01:	// Reset command buffer
	if(DrawTimeAvail < 0)
	 DrawTimeAvail = 0;
	BlitterFIFO.Flush();
	InCmd = INCMD_NONE;
	break;

   case 0x02: 	// Acknowledge IRQ
	IRQPending = false;
	IRQ_Assert(IRQ_GPU, IRQPending);
   	break;

   case 0x03:	// Display enable
	DisplayOff = V & 1;
	break;

   case 0x04:	// DMA Setup
	DMAControl = V & 0x3;
	break;

   case 0x05:	// Start of display area in framebuffer
	DisplayFB_XStart = V & 0x3FE; // Lower bit is apparently ignored.
	DisplayFB_YStart = (V >> 10) & 0x1FF;
	break;

   case 0x06:	// Horizontal display range
	HorizStart = V & 0xFFF;
	HorizEnd = (V >> 12) & 0xFFF;
	break;

   case 0x07:
	VertStart = V & 0x3FF;
	VertEnd = (V >> 10) & 0x3FF;
	break;

   case 0x08:
	//printf("\n\nDISPLAYMODE SET: 0x%02x, %u *************************\n\n\n", V & 0xFF, scanline);
	DisplayMode = V & 0xFF;
	break;

   case 0x09:
	TexDisableAllowChange = V & 1;
	break;

   case 0x10:	// GPU info(?)
	switch(V & 0xF)
	{
	 // DataReadBuffer must remain unchanged for any unhandled GPU info index.
	 default:  break;

	 case 0x2: DataReadBufferEx &= 0xFFF00000;
		   DataReadBufferEx |= (tww << 0) | (twh << 5) | (twx << 10) | (twy << 15);
		   DataReadBuffer = DataReadBufferEx;
		   break;

	 case 0x3: DataReadBufferEx &= 0xFFF00000;
		   DataReadBufferEx |= (ClipY0 << 10) | ClipX0;
		   DataReadBuffer = DataReadBufferEx;
		   break;

 	 case 0x4: DataReadBufferEx &= 0xFFF00000;
		   DataReadBufferEx |= (ClipY1 << 10) | ClipX1;
		   DataReadBuffer = DataReadBufferEx;
		   break;

	 case 0x5: DataReadBufferEx &= 0xFFC00000;
		   DataReadBufferEx |= (OffsX & 2047) | ((OffsY & 2047) << 11);
		   DataReadBuffer = DataReadBufferEx;
		   break;

	 case 0x7: DataReadBufferEx = 2;
		   DataReadBuffer = DataReadBufferEx;
		   break;

	 case 0x8: DataReadBufferEx = 0;
		   DataReadBuffer = DataReadBufferEx;
		   break;
	}
	//fprintf(stderr, "[GPU] CC 0x10:0x%02x, DRB=0x%02x\n", V & 0xF, DataReadBuffer);
	break;

  }
 }
 else		// GP0 ("Data")
 {
  //uint32 command = V >> 24;
  //printf("Meow command: %02x\n", command);
  //assert(!(DMAControl & 2));
  WriteCB(V);
 }
}


void PS_GPU::WriteDMA(uint32 V)
{
 WriteCB(V);
}

INLINE uint32 PS_GPU::ReadData(void)
{
 if(InCmd == INCMD_FBREAD)
 {
  DataReadBufferEx = 0;
  for(int i = 0; i < 2; i++)
  {
   DataReadBufferEx |= GPURAM[FBRW_CurY & 511][FBRW_CurX & 1023] << (i * 16);

   FBRW_CurX++;
   if(FBRW_CurX == (FBRW_X + FBRW_W))
   {
    if((FBRW_CurY + 1) == (FBRW_Y + FBRW_H))
    {
     InCmd = INCMD_NONE;
    }
    else
    {
     FBRW_CurY++;
     FBRW_CurX = FBRW_X; 
    }
   }
  }

  return DataReadBufferEx;
 }

 return DataReadBuffer;
}

uint32 PS_GPU::ReadDMA(void)
{
 return ReadData();
}

uint32 PS_GPU::Read(const pscpu_timestamp_t timestamp, uint32 A)
{
 uint32 ret = 0;

 if(A & 4)	// Status
 {
  ret = (((DisplayMode << 1) & 0x7F) | ((DisplayMode >> 6) & 1)) << 16;

  ret |= (DisplayMode & 0x80) << 7;

  ret |= DMAControl << 29;

  ret |= (DisplayFB_CurLineYReadout & 1) << 31;

  ret |= (!field) << 13;

  if(DMAControl & 0x02)
   ret |= 1 << 25;

  ret |= IRQPending << 24;

  ret |= DisplayOff << 23;

  if(InCmd == INCMD_NONE && DrawTimeAvail >= 0 && BlitterFIFO.CanRead() == 0x00)	// GPU idle bit.
   ret |= 1 << 26;

  if(InCmd == INCMD_FBREAD)	// Might want to more accurately emulate this in the future?
   ret |= (1 << 27);

  ret |= CalcFIFOReadyBit() << 28;		// FIFO has room bit? (kinda).

  //
  //
  ret |= TexPageX >> 6;
  ret |= TexPageY >> 4;
  ret |= abr << 5;
  ret |= TexMode << 7;

  ret |= dtd << 9;
  ret |= dfe << 10;

  if(MaskSetOR)
   ret |= 1 << 11;

  if(MaskEvalAND)
   ret |= 1 << 12;

  ret |= TexDisable << 15;
 }
 else		// "Data"
  ret = ReadData();

 if(DMAControl & 2)
 {
  //PSX_WARNING("[GPU READ WHEN (DMACONTROL&2)] 0x%08x - ret=0x%08x, scanline=%d", A, ret, scanline);
 }

 return(ret >> ((A & 3) * 8));
}

#if 0
static INLINE uint32 MDFN_NOWARN_UNUSED ShiftHelper(uint32 val, int shamt, uint32 mask)
{
 if(shamt < 0)
  return((val >> (-shamt)) & mask);
 else
  return((val << shamt) & mask);
}
#endif

#pragma GCC push_options
#pragma GCC optimize("no-unroll-loops,no-peel-loops,no-crossjumping")
INLINE void PS_GPU::ReorderRGB_Var(uint32 out_Rshift, uint32 out_Gshift, uint32 out_Bshift, bool bpp24, const uint16 *src, uint32 *dest, const int32 dx_start, const int32 dx_end, int32 fb_x)
{
     if(bpp24)	// 24bpp
     {
      for(int32 x = dx_start; MDFN_LIKELY(x < dx_end); x++)
      {
       uint32 srcpix;

       srcpix = src[(fb_x >> 1) + 0] | (src[((fb_x >> 1) + 1) & 0x7FF] << 16);
       srcpix >>= (fb_x & 1) * 8;

       dest[x] = (((srcpix >> 0) << out_Rshift) & (0xFF << out_Rshift)) | (((srcpix >> 8) << out_Gshift) & (0xFF << out_Gshift)) |
       		 (((srcpix >> 16) << out_Bshift) & (0xFF << out_Bshift));

       fb_x = (fb_x + 3) & 0x7FF;
      }
     }				// 15bpp
     else
     {
      for(int32 x = dx_start; MDFN_LIKELY(x < dx_end); x++)
      {
       uint32 srcpix = src[fb_x >> 1];

#if 1
       dest[x] = OutputLUT[(uint8)srcpix] | (OutputLUT + 256)[(srcpix >> 8) & 0x7F];
#else
       dest[x] = ShiftHelper(srcpix, out_Rshift + 3 -  0, (0xF8 << out_Rshift)) |
	         ShiftHelper(srcpix, out_Gshift + 3 -  5, (0xF8 << out_Gshift)) |
	         ShiftHelper(srcpix, out_Bshift + 3 - 10, (0xF8 << out_Bshift));
#endif
       fb_x = (fb_x + 2) & 0x7FF;
      }
     }

}

template<uint32 out_Rshift, uint32 out_Gshift, uint32 out_Bshift>
void NO_INLINE PS_GPU::ReorderRGB(bool bpp24, const uint16 *src, uint32 *dest, const int32 dx_start, const int32 dx_end, int32 fb_x)
{
 ReorderRGB_Var(out_Rshift, out_Gshift, out_Bshift, bpp24, src, dest, dx_start, dx_end, fb_x);
}
#pragma GCC pop_options

pscpu_timestamp_t PS_GPU::Update(const pscpu_timestamp_t sys_timestamp)
{
 static const uint32 DotClockRatios[5] = { 10, 8, 5, 4, 7 };
 const uint32 dmc = (DisplayMode & 0x40) ? 4 : (DisplayMode & 0x3);
 const uint32 dmw = 2800 / DotClockRatios[dmc];	// Must be <= (768 - 32)
 const uint32 dmpa = (2800 - (hide_hoverscan ? 2640 : 2800)) / DotClockRatios[dmc] / 2;	// Must be <= 32
 const uint32 drxbo = 32;

 int32 sys_clocks = sys_timestamp - lastts;
 int32 gpu_clocks;

 //printf("GPUISH: %d\n", sys_timestamp - lastts);

 if(!sys_clocks)
  goto TheEnd;

 DrawTimeAvail += sys_clocks << 1;

 if(DrawTimeAvail > 256)
  DrawTimeAvail = 256;

 ProcessFIFO();

 //puts("GPU Update Start");

 GPUClockCounter += (uint64)sys_clocks * GPUClockRatio;

 gpu_clocks = GPUClockCounter >> 16;
 GPUClockCounter -= gpu_clocks << 16;

 while(gpu_clocks > 0)
 {
  int32 chunk_clocks = gpu_clocks;
  int32 dot_clocks;

  if(chunk_clocks > LineClockCounter)
  {
   //printf("Chunk: %u, LCC: %u\n", chunk_clocks, LineClockCounter);
   chunk_clocks = LineClockCounter;
  }

  gpu_clocks -= chunk_clocks;
  LineClockCounter -= chunk_clocks;

  DotClockCounter += chunk_clocks;
  dot_clocks = DotClockCounter / DotClockRatios[DisplayMode & 0x3];
  DotClockCounter -= dot_clocks * DotClockRatios[DisplayMode & 0x3];

  TIMER_AddDotClocks(dot_clocks);


  if(!LineClockCounter)
  {
   PSX_SetEventNT(PSX_EVENT_TIMER, TIMER_Update(sys_timestamp));  // We could just call this at the top of GPU_Update(), but do it here for slightly less CPU usage(presumably).

   LinePhase = (LinePhase + 1) & 1;

   if(LinePhase)
   {
    TIMER_SetHRetrace(true);
    LineClockCounter = 200;
    TIMER_ClockHRetrace();
   }
   else
   {
    const unsigned int FirstVisibleLine = LineVisFirst + (HardwarePALType ? 20 : 16);
    const unsigned int VisibleLineCount = LineVisLast + 1 - LineVisFirst; //HardwarePALType ? 288 : 240;

    TIMER_SetHRetrace(false);

    if(DisplayMode & 0x08)
     LineClockCounter = 3405 - 200;
    else
     LineClockCounter = 3412 + PhaseChange - 200;

    scanline = (scanline + 1) % LinesPerField;
    PhaseChange = !PhaseChange;

#ifdef WANT_DEBUGGER
    DBG_GPUScanlineHook(scanline);
#endif

    //
    //
    //
    if(scanline == (HardwarePALType ? 308 : 256))	// Will need to be redone if we ever allow for visible vertical overscan with NTSC.
    {
     if(sl_zero_reached)
     {
      //printf("Req Exit(visible fallthrough case): %u\n", scanline);
      PSX_RequestMLExit();
     }
    }

    if(scanline == (LinesPerField - 1))
    {
     if(sl_zero_reached)
     {
      //printf("Req Exit(final fallthrough case): %u\n", scanline);
      PSX_RequestMLExit();
     }

     if(DisplayMode & 0x20)
      field = !field;
     else
      field = 0;
    }

    if(scanline == 0)
    {
     assert(sl_zero_reached == false);
     sl_zero_reached = true;

     if(DisplayMode & 0x20)
     {
      skip = false;

      if(DisplayMode & 0x08)	// PAL
       LinesPerField = 313 - field;
      else			// NTSC
       LinesPerField = 263 - field;
     }
     else
     {
      field = 0;	// May not be the correct place for this?

      if(DisplayMode & 0x08)	// PAL
       LinesPerField = 314;
      else			// NTSC
       LinesPerField = 263;
     }

     if(espec)
     {
      if((bool)(DisplayMode & 0x08) != HardwarePALType)
      {
       const uint32 black = surface->MakeColor(0, 0, 0);

       DisplayRect->x = 0;
       DisplayRect->y = 0;
       DisplayRect->w = 384;
       DisplayRect->h = VisibleLineCount;

       for(int32 y = 0; y < DisplayRect->h; y++)
       {
        uint32 *dest = surface->pixels + y * surface->pitch32;

        LineWidths[y] = 384;

        for(int32 x = 0; x < 384; x++)
        {
         dest[x] = black;
        }
       }

       if(!DisplayOff)
       {
        char buffer[256];
        trio_snprintf(buffer, sizeof(buffer), _("VIDEO STANDARD MISMATCH"));
        DrawTextTrans(surface->pixels + ((DisplayRect->h / 2) - (13 / 2)) * surface->pitch32, surface->pitch32 << 2, DisplayRect->w, buffer,
		surface->MakeColor(0x00, 0xFF, 0x00), true, MDFN_FONT_6x13_12x13);
       }
      }
      else
      {
       const uint32 black = surface->MakeColor(0, 0, 0);

       espec->InterlaceOn = (bool)(DisplayMode & 0x20);
       espec->InterlaceField = (bool)(DisplayMode & 0x20) && field;

#pragma message "test to fix x offset"
       DisplayRect->x = drxbo;
       //   DisplayRect->x = 0;
       DisplayRect->y = 0;
       DisplayRect->w = 0;
       DisplayRect->h = VisibleLineCount << (bool)(DisplayMode & 0x20);

       // Clear ~0 state.
       LineWidths[0] = 0;

       for(int i = 0; i < (DisplayRect->y + DisplayRect->h); i++)
       {
	surface->pixels[i * surface->pitch32 + 0] =
	surface->pixels[i * surface->pitch32 + 1] = black;
        LineWidths[i] = 2;
       }
      }
     }
    }

    //
    // Don't mess with the order of evaluation of these scanline == VertXXX && (InVblankwhatever) if statements and the following IRQ/timer vblank stuff
    // unless you know what you're doing!!! (IE you've run further tests to refine the behavior)
    //
    if(scanline == VertEnd && !InVBlank)
    {
     if(sl_zero_reached)
     {
      // Gameplay in Descent(NTSC) has vblank at scanline 236
      //
      // Mikagura Shoujo Tanteidan has vblank at scanline 192 during intro
      //  FMV(which we don't handle here because low-latency in that case is not so important).
      //
      if(scanline >= (HardwarePALType ? 260 : 232))
      {
       //printf("Req Exit(vblank case): %u\n", scanline);
       PSX_RequestMLExit();
      }
      else
      {
       //printf("VBlank too early, chickening out early exit: %u!\n", scanline);
      }
     }

     //printf("VBLANK: %u\n", scanline);
     InVBlank = true;

     DisplayFB_CurYOffset = 0;

     if((DisplayMode & 0x24) == 0x24)
      field_ram_readout = !field;
     else
      field_ram_readout = 0;
    }

    if(scanline == VertStart && InVBlank)
    {
     InVBlank = false;

     // Note to self: X-Men Mutant Academy relies on this being set on the proper scanline in 480i mode(otherwise it locks up on startup).
     //if(HeightMode)
     // DisplayFB_CurYOffset = field;
    }

    IRQ_Assert(IRQ_VBLANK, InVBlank);
    TIMER_SetVBlank(InVBlank);
    //
    //
    //

    // Needs to occur even in vblank.
    // Not particularly confident about the timing of this in regards to vblank and the upper bit(ODE) of the GPU status port, though the test that
    // showed an oddity was pathological in that VertEnd < VertStart in it.
    if((DisplayMode & 0x24) == 0x24)
     DisplayFB_CurLineYReadout = (DisplayFB_YStart + (DisplayFB_CurYOffset << 1) + (InVBlank ? 0 : field_ram_readout)) & 0x1FF;
    else
     DisplayFB_CurLineYReadout = (DisplayFB_YStart + DisplayFB_CurYOffset) & 0x1FF;

    if((bool)(DisplayMode & 0x08) == HardwarePALType && scanline >= FirstVisibleLine && scanline < (FirstVisibleLine + VisibleLineCount) && !skip && espec)
    {
     uint32 *dest;
     int32 dest_line;
     int32 fb_x = DisplayFB_XStart * 2;
     int32 dx_start = HorizStart, dx_end = HorizEnd;

     dest_line = ((scanline - FirstVisibleLine) << espec->InterlaceOn) + espec->InterlaceField;
     dest = surface->pixels + (drxbo - dmpa) + dest_line * surface->pitch32;

     if(dx_end < dx_start)
      dx_end = dx_start;

     dx_start = dx_start / DotClockRatios[dmc];
     dx_end = dx_end / DotClockRatios[dmc];

     dx_start -= hmc_to_visible / DotClockRatios[dmc];
     dx_end -= hmc_to_visible / DotClockRatios[dmc];
     dx_start += 7;
     dx_end += 7;

     if(dx_start < 0)
     {
      fb_x -= dx_start * ((DisplayMode & 0x10) ? 3 : 2);
      fb_x &= 0x7FF; //0x3FF;
      dx_start = 0;
     }

     if((uint32)dx_end > dmw)
      dx_end = dmw;

     if(InVBlank || DisplayOff)
      dx_start = dx_end = 0;

     LineWidths[dest_line] = dmw - dmpa * 2;

     {
      const uint16 *src = GPURAM[DisplayFB_CurLineYReadout];
      const uint32 black = surface->MakeColor(0, 0, 0);

      for(int32 x = 0; x < dx_start; x++)
       dest[x] = black;

      //printf("%d %d %d - %d %d\n", scanline, dx_start, dx_end, HorizStart, HorizEnd);
      if(surface->format.Rshift == 0 && surface->format.Gshift == 8 && surface->format.Bshift == 16)
       ReorderRGB<0, 8, 16>(DisplayMode & 0x10, src, dest, dx_start, dx_end, fb_x);
      else if(surface->format.Rshift == 8 && surface->format.Gshift == 16 && surface->format.Bshift == 24)
       ReorderRGB<8, 16, 24>(DisplayMode & 0x10, src, dest, dx_start, dx_end, fb_x);
      else if(surface->format.Rshift == 16 && surface->format.Gshift == 8 && surface->format.Bshift == 0)
       ReorderRGB<16, 8, 0>(DisplayMode & 0x10, src, dest, dx_start, dx_end, fb_x);
      else if(surface->format.Rshift == 24 && surface->format.Gshift == 16 && surface->format.Bshift == 8)
       ReorderRGB<24, 16, 8>(DisplayMode & 0x10, src, dest, dx_start, dx_end, fb_x);
      else
       ReorderRGB_Var(surface->format.Rshift, surface->format.Gshift, surface->format.Bshift, DisplayMode & 0x10, src, dest, dx_start, dx_end, fb_x);

      for(uint32 x = dx_end; x < dmw; x++)
       dest[x] = black;
     }

     //if(scanline == 64)
     // printf("%u\n", sys_timestamp - ((uint64)gpu_clocks * 65536) / GPUClockRatio);

     PSX_GPULineHook(sys_timestamp, sys_timestamp - ((uint64)gpu_clocks * 65536) / GPUClockRatio, scanline == 0, dest, &surface->format, dmw, (hmc_to_visible - 220) / DotClockRatios[dmc], (HardwarePALType ? 53203425 : 53693182) / DotClockRatios[dmc], DotClockRatios[dmc]);
    }
    else
    {
     PSX_GPULineHook(sys_timestamp, sys_timestamp - ((uint64)gpu_clocks * 65536) / GPUClockRatio, scanline == 0, NULL, &surface->format, 0, 0, 0, 0);
    }

    if(!InVBlank)
    {
     DisplayFB_CurYOffset = (DisplayFB_CurYOffset + 1) & 0x1FF;
    }
   }
   PSX_SetEventNT(PSX_EVENT_TIMER, TIMER_Update(sys_timestamp));  // Mostly so the next event time gets recalculated properly in regards to our calls
								  // to TIMER_SetVBlank() and TIMER_SetHRetrace().
  }	// end if(!LineClockCounter)
 }	// end while(gpu_clocks > 0)

 //puts("GPU Update End");

 TheEnd:
 lastts = sys_timestamp;

 {
  int32 next_dt = LineClockCounter;

  next_dt = (((int64)next_dt << 16) - GPUClockCounter + GPUClockRatio - 1) / GPUClockRatio;

  next_dt = std::max<int32>(1, next_dt);
  next_dt = std::min<int32>(128, next_dt);

  //printf("%d\n", next_dt);

  return(sys_timestamp + next_dt);
 }
}

void PS_GPU::StartFrame(EmulateSpecStruct *espec_arg)
{
 sl_zero_reached = false;

 if(!espec_arg)
 {
  espec = NULL;
  surface = NULL;
  DisplayRect = NULL;
  LineWidths = NULL;
  skip = true;
  return;
 }

 espec = espec_arg;

 surface = espec->surface;
 DisplayRect = &espec->DisplayRect;
 LineWidths = espec->LineWidths;
 skip = espec->skip;

 if(espec->VideoFormatChanged)
 {
  const auto& f = surface->format;

  for(int rc = 0; rc < 0x8000; rc++)
  {
   const uint8 a = rc;
   const uint8 b = rc >> 8;

   (OutputLUT +   0)[a] = ((a & 0x1F) << (3 + f.Rshift)) | ((a >> 5) << (3 + f.Gshift));
   (OutputLUT + 256)[b] = ((b & 0x3) << (6 + f.Gshift)) | (((b >> 2) & 0x1F) << (3 + f.Bshift));
  }
 }
}

void PS_GPU::StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 uint32 TexCache_Tag[256];
 uint16 TexCache_Data[256][4];

 for(unsigned i = 0; i < 256; i++)
 {
  TexCache_Tag[i] = TexCache[i].Tag;

  for(unsigned j = 0; j < 4; j++)
   TexCache_Data[i][j] = TexCache[i].Data[j];
 }

 SFORMAT StateRegs[] =
 {
  SFARRAY16(&GPURAM[0][0], sizeof(GPURAM) / sizeof(GPURAM[0][0])),

  SFARRAY16(&CLUT_Cache[0], sizeof(CLUT_Cache) / sizeof(CLUT_Cache[0])),
  SFVAR(CLUT_Cache_VB),

  SFARRAY32(TexCache_Tag, sizeof(TexCache_Tag) / sizeof(TexCache_Tag[0])),
  SFARRAY16(&TexCache_Data[0][0], sizeof(TexCache_Data) / sizeof(TexCache_Data[0][0])),

  SFVAR(DMAControl),

  SFVAR(ClipX0),
  SFVAR(ClipY0),
  SFVAR(ClipX1),
  SFVAR(ClipY1),

  SFVAR(OffsX),
  SFVAR(OffsY),

  SFVAR(dtd),
  SFVAR(dfe),

  SFVAR(MaskSetOR),
  SFVAR(MaskEvalAND),

  SFVAR(TexDisable),
  SFVAR(TexDisableAllowChange),

  SFVAR(tww),
  SFVAR(twh),
  SFVAR(twx),
  SFVAR(twy),

  SFVAR(TexPageX),
  SFVAR(TexPageY),

  SFVAR(SpriteFlip),

  SFVAR(abr),
  SFVAR(TexMode),

  SFARRAY32(&BlitterFIFO.data[0], sizeof(BlitterFIFO.data) / sizeof(BlitterFIFO.data[0])),
  SFVAR(BlitterFIFO.read_pos),
  SFVAR(BlitterFIFO.write_pos),
  SFVAR(BlitterFIFO.in_count),

  SFVAR(DataReadBuffer),
  SFVAR(DataReadBufferEx),

  SFVAR(IRQPending),

  SFVAR(InCmd),
  SFVAR(InCmd_CC),

#define TVHELPER(n)	SFVAR(n.x), SFVAR(n.y), SFVAR(n.u), SFVAR(n.v), SFVAR(n.r), SFVAR(n.g), SFVAR(n.b)
  TVHELPER(InQuad_F3Vertices[0]),
  TVHELPER(InQuad_F3Vertices[1]),
  TVHELPER(InQuad_F3Vertices[2]),
#undef TVHELPER

  SFVAR(InPLine_PrevPoint.x),
  SFVAR(InPLine_PrevPoint.y),
  SFVAR(InPLine_PrevPoint.r),
  SFVAR(InPLine_PrevPoint.g),
  SFVAR(InPLine_PrevPoint.b),

  SFVAR(FBRW_X),
  SFVAR(FBRW_Y),
  SFVAR(FBRW_W),
  SFVAR(FBRW_H),
  SFVAR(FBRW_CurY),
  SFVAR(FBRW_CurX),

  SFVAR(DisplayMode),
  SFVAR(DisplayOff),
  SFVAR(DisplayFB_XStart),
  SFVAR(DisplayFB_YStart),

  SFVAR(HorizStart),
  SFVAR(HorizEnd),

  SFVAR(VertStart),
  SFVAR(VertEnd),

  SFVAR(DisplayFB_CurYOffset),
  SFVAR(DisplayFB_CurLineYReadout),

  SFVAR(InVBlank),

  SFVAR(LinesPerField),
  SFVAR(scanline),
  SFVAR(field),
  SFVAR(field_ram_readout),
  SFVAR(PhaseChange),

  SFVAR(DotClockCounter),

  SFVAR(GPUClockCounter),
  SFVAR(LineClockCounter),
  SFVAR(LinePhase),

  SFVAR(DrawTimeAvail),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "GPU");

 if(load)
 {
  for(unsigned i = 0; i < 256; i++)
  {
   TexCache[i].Tag = TexCache_Tag[i];

   for(unsigned j = 0; j < 4; j++)
    TexCache[i].Data[j] = TexCache_Data[i][j];
  }

  RecalcTexWindowStuff();
  BlitterFIFO.SaveStatePostLoad();

  HorizStart &= 0xFFF;
  HorizEnd &= 0xFFF;

  IRQ_Assert(IRQ_GPU, IRQPending);
 }
}

}
