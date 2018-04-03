/******************************************************************************/
/* Mednafen Sony PS1 Emulation Module                                         */
/******************************************************************************/
/* gpu.h:
**  Copyright (C) 2011-2017 Mednafen Team
**
** This program is free software; you can redistribute it and/or
** modify it under the terms of the GNU General Public License
** as published by the Free Software Foundation; either version 2
** of the License, or (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software Foundation, Inc.,
** 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
*/

// WARNING WARNING WARNING:  ONLY use CanRead() method of BlitterFIFO, and NOT CanWrite(), since the FIFO is larger than the actual PS1 GPU FIFO to accommodate
// our lack of fancy superscalarish command sequencer.

#ifndef __MDFN_PSX_GPU_H
#define __MDFN_PSX_GPU_H

#include "FastFIFO.h"

namespace MDFN_IEN_PSX
{

struct CTEntry
{
 void (*func[4][8])(const uint32 *cb);
 uint8 len;
 uint8 fifo_fb_len;
 bool ss_cmd;
};

struct tri_vertex
{
 int32 x, y;
 int32 u, v;
 int32 r, g, b;
};

struct line_point
{
 int32 x, y;
 uint8 r, g, b;
};

struct PS_GPU
{
 uint16 CLUT_Cache[256];
 uint32 CLUT_Cache_VB;	// Don't try to be clever and reduce it to 16 bits... ~0U is value for invalidated state.

 struct	// Speedup-cache variables, derived from other variables; shouldn't be saved in save states.
 {
  // TW*_* variables derived from tww, twh, twx, twy, TexPageX, TexPageY
  uint32 TWX_AND;
  uint32 TWX_ADD;

  uint32 TWY_AND;
  uint32 TWY_ADD;
 } SUCV;

 struct
 {
  uint16 Data[4];
  uint32 Tag;
 } TexCache[256];

 uint32 DMAControl;

 //
 // Drawing stuff
 //
 //int32 TexPageX;	// 0, 64, 128, 192, etc up to 960
 //int32 TexPageY;	// 0 or 256
 //uint32 abr;		// Semi-transparency mode(0~3)
 //bool dtd;		// Dithering enable

 int32 ClipX0;
 int32 ClipY0;
 int32 ClipX1;
 int32 ClipY1;

 int32 OffsX;
 int32 OffsY;

 uint32 MaskSetOR;
 uint32 MaskEvalAND;

 bool dtd;
 bool dfe;

 bool TexDisable;
 bool TexDisableAllowChange;

 uint8 tww, twh, twx, twy;
 
 uint32 TexPageX;
 uint32 TexPageY;

 uint32 SpriteFlip;

 uint32 abr;
 uint32 TexMode;

 FastFIFO<uint32, 0x20> BlitterFIFO; // 0x10 on actual PS1 GPU, 0x20 here(see comment at top of gpu.h)
 uint32 DataReadBuffer;
 uint32 DataReadBufferEx;

 bool IRQPending;
 //
 //
 //
 // Powers of 2 for faster multiple equality testing(just for multi-testing; InCmd itself will only contain 0, or a power of 2).
 enum
 {
  INCMD_NONE = 0,
  INCMD_PLINE = (1 << 0),
  INCMD_QUAD = (1 << 1),
  INCMD_FBWRITE = (1 << 2),
  INCMD_FBREAD = (1 << 3)
 };
 uint8 InCmd;
 uint8 InCmd_CC;

 tri_vertex InQuad_F3Vertices[3];

 line_point InPLine_PrevPoint;

 uint32 FBRW_X;
 uint32 FBRW_Y;
 uint32 FBRW_W;
 uint32 FBRW_H;
 uint32 FBRW_CurY;
 uint32 FBRW_CurX;

 //
 // Display Parameters
 //
 uint32 DisplayFB_XStart;
 uint32 DisplayFB_YStart;

 uint32 HorizStart;
 uint32 HorizEnd;

 uint32 VertStart;
 uint32 VertEnd;
 uint32 DisplayMode;
 bool DisplayOff;

 //
 // Display work vars
 //
 bool PhaseChange;
 bool InVBlank;
 bool sl_zero_reached;
 bool skip;
 bool hide_hoverscan;
 bool field;
 bool field_ram_readout;
 uint32 DisplayFB_CurYOffset;
 uint32 DisplayFB_CurLineYReadout;

 //
 //
 //
 uint64 GPUClockCounter;
 uint32 GPUClockRatio;
 uint32 LinesPerField;
 uint32 scanline;
 uint32 DotClockCounter;

 int32 LineClockCounter;
 int32 LinePhase;

 int32 DrawTimeAvail;

 pscpu_timestamp_t lastts;

 uint8 DitherLUT[4][4][512];	// Y, X, 8-bit source value(256 extra for saturation)

 CTEntry Commands[256];
 //
 //
 //
 //
 //
 //
 EmulateSpecStruct *espec;
 MDFN_Surface *surface;
 MDFN_Rect *DisplayRect;
 int32 *LineWidths;
 int LineVisFirst, LineVisLast;
 int32 hmc_to_visible;
 /*const*/ bool HardwarePALType;
 uint32 OutputLUT[384];
 //
 //
 // Y, X
 uint16 GPURAM[512][1024];
};

 extern PS_GPU GPU;

 void GPU_Init(bool pal_clock_and_tv) MDFN_COLD;
 void GPU_Kill(void) MDFN_COLD;

 void GPU_SetGetVideoParams(MDFNGI* gi, const int sls, const int sle, const bool show_h_overscan) MDFN_COLD;

 void GPU_Power(void) MDFN_COLD;

 void GPU_StateAction(StateMem *sm, const unsigned load, const bool data_only);

 void GPU_ResetTS(void);

 void GPU_StartFrame(EmulateSpecStruct *espec);

 MDFN_FASTCALL pscpu_timestamp_t GPU_Update(const pscpu_timestamp_t timestamp);

 MDFN_FASTCALL void GPU_Write(const pscpu_timestamp_t timestamp, uint32 A, uint32 V);

 static INLINE bool GPU_CalcFIFOReadyBit(void)
 {
  if(GPU.InCmd & (PS_GPU::INCMD_PLINE | PS_GPU::INCMD_QUAD))
   return false;

  if(GPU.BlitterFIFO.CanRead() == 0)
   return true;

  if(GPU.InCmd & (PS_GPU::INCMD_FBREAD | PS_GPU::INCMD_FBWRITE))
   return false;

  if(GPU.BlitterFIFO.CanRead() >= GPU.Commands[GPU.BlitterFIFO.Peek() >> 24].fifo_fb_len)
   return false;

  return true;
 }

 static INLINE bool GPU_DMACanWrite(void)
 {
  return GPU_CalcFIFOReadyBit();
 }

 MDFN_FASTCALL void GPU_WriteDMA(uint32 V);
 uint32 GPU_ReadDMA(void);

 MDFN_FASTCALL uint32 GPU_Read(const pscpu_timestamp_t timestamp, uint32 A);

 static INLINE int32 GPU_GetScanlineNum(void)
 {
  return GPU.scanline;
 } 

 static INLINE uint16 GPU_PeekRAM(uint32 A)
 {
  return GPU.GPURAM[(A >> 10) & 0x1FF][A & 0x3FF];
 }

 static INLINE void GPU_PokeRAM(uint32 A, uint16 V)
 {
  GPU.GPURAM[(A >> 10) & 0x1FF][A & 0x3FF] = V;
 }
}
#endif
