/******************************************************************************/
/* Mednafen Apple II Emulation Module                                         */
/******************************************************************************/
/* video.cpp:
**  Copyright (C) 2018-2023 Mednafen Team
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

#include "apple2.h"
#include "video.h"
#include "kbio.h"

/*
 TODO:	Colorburst detection delay.

	Y black expansion setting?  cutoff at 30 or 50 IRE?

	Nonlinearity settings for color decoding?

	IIGS-style RGB decoding option?

-------------------------------------------------------
 Apple II Circuit Description, page 116, page 122


 front porch: 7.9uS		-	16 * 7 = 112	
 hsync pulse: 3.9uS		-	 8 * 7 =  56
 breezeway: 70ns		-	           1
 colorburst: 3.9uS		-	 8 * 7 =  56
 color back porch: 8.9uS	-	         127

 horiz. blanking total: 24.6us 	-	 	 352
 horizontal active				 280
 horizontal total		-		 456

 456 - (352 / 2) = 280
-------------------------------------------------------
 vertical sync pulse		-	 4
 
 vertical blanking total	-	70
 vertical active		-	192
 vertical total 		-	262
*/

namespace MDFN_IEN_APPLE2
{
namespace Video
{

static auto const& RAM = A2G.RAM;
static auto const& RAMMask = A2G.RAMMask;
static auto const& RAMSize = A2G.RAMSize;
static auto const& EnableFullAuxRAM = A2G.EnableFullAuxRAM;
static auto const& RAMPresent = A2G.RAMPresent; 

static auto& SoftSwitch = A2G.SoftSwitch;
static auto& V7RGBMode = A2G.V7RGBMode;
static auto& FrameDone = A2G.FrameDone;
static auto& FramePartialDone = A2G.FramePartialDone;
//
//
//
enum { ColorLUT_NumPixels = 13 };
static uint32 ColorLUT[2][4][1U << ColorLUT_NumPixels];
static uint32 RGBLUT[16 * 2];
static MDFN_PixelFormat format;
static bool EnableMixedTextMonoHack;
static int16 SharpCoeffs[4];
static int16 SharpGCRLUT[1024];
static int16 SharpGCALUT[4096];

static void (*BlitLineBitBuffer)(unsigned target_line);

/*
 text/lores
  page1: 0x0400-0x07FF
  page2: 0x0800-0x0BFF

 hires
  page1: 0x2000-0x3FFF
  page2: 0x4000-0x5FFF


 lores: 1 byte for 7x8 7MHz pixels, lower nybble for upper 4 pixels, upper nybble for lower 4 pixels

 hires: 1 byte for 7x1 7MHz pixels, upper bit for phase/delay thing, bit0 leftmost pixel, bit6 rightmost pixel
*/

void (*Tick)(void);

static uint8 VideoROM[0x1000];
static uint8 linebuffer[(560 + 24) / 8 + 4];
static uint8 linebuffer_ex[80 + (1 * 2)];
static uint16 linebuffer_ty[40];
static MDFN_Surface* surface;
static MDFN_Rect surface_dr;
static int32* line_widths;
static bool colorburst_present;
static uint32 HCounter, VCounter;
static bool flashything;
static int32 flashycounter;
static bool HiresDelayBit;
static uint64 NoiseLCG;

//
//
static uint8 vid_db;
static uint8 text_delay;
static uint32 shifter;
static uint32 fcounter;
//
//
void Power(void)
{
 HCounter = 0;
 VCounter = 0xFA;
 flashything = false;
 flashycounter = 0;
 HiresDelayBit = false;
 NoiseLCG = 0;
 //
 vid_db = 0;
 text_delay = 0;
 shifter = 0;
 fcounter = 0;
}

template<typename T, bool tfr>
static void BlitLineBitBuffer_RGB_Alt(unsigned target_line)
{
 T* MDFN_RESTRICT target = surface->pix<T>() + target_line * surface->pitchinpix;
 uint32 pdata = 0;
 uint32 bwlut[2];
 uint32 rtlut[32];
 uint16 ty = linebuffer_ty[0];
 uint16 ty_prev = ty;

 bwlut[0] = RGBLUT[0x0];
 bwlut[1] = RGBLUT[0xF];

 for(unsigned i = 0; i < 32; i++)
  rtlut[i] = RGBLUT[i & (tfr ? (uint32)-1 : 0x0F)];

 line_widths[target_line] = 584;

 pdata = MDFN_de16lsb(linebuffer) << 13;

 for(unsigned i = 0; i < 83; i++)
 {
  bool text;
  bool hires;

  if((ty & SOFTSWITCH_80COL) && (ty & 0x60))
  {
   text = (bool)(ty & 0x10);
   hires = (bool)(ty & SOFTSWITCH_HIRES_MODE);
  }
  else
  {
   text = (bool)(ty_prev & 0x10);
   hires = (bool)(ty_prev & (SOFTSWITCH_HIRES_MODE | 0x40));
  }

  if(text)
  {
   const uint32 p = pdata >> 6;

   target[0] = bwlut[(p >> 0) & 0x1];
   target[1] = bwlut[(p >> 1) & 0x1];
   target[2] = bwlut[(p >> 2) & 0x1];
   target[3] = bwlut[(p >> 3) & 0x1];
   target[4] = bwlut[(p >> 4) & 0x1];
   target[5] = bwlut[(p >> 5) & 0x1];
   target[6] = bwlut[(p >> 6) & 0x1];
  }
  else if(hires)
  {
   for(unsigned j = 0; j < 7; j++)
    target[j] = rtlut[*((uint8*)ColorLUT + ((((i * 7) + j) & 3) << 13) + ((pdata >> j) & 0x1FFF))];
  }
  else
  {
   uint32 sh;
   uint32 c;

   c = (pdata >> 6) & 0xF;
   sh = (i * 7 + 2) & 0x3;
   c = ((c << sh) | (c >> (4 - sh))) & 0xF;
   c = RGBLUT[c];
   target[0] = c;
   target[1] = c;
   target[2] = c;
   target[3] = c;
   target[4] = c;
   target[5] = c;
   target[6] = c;
  }
  //
  target += 7;

  static_assert(((83 - 1) * 7 + 16 + 8 * sizeof(uint16)) <= sizeof(linebuffer) * 8, "linebuffer too small");
  {
   unsigned noffs = i * 7 + 16;
   pdata >>= 7;
   pdata |= ((MDFN_de16lsb(linebuffer + (noffs >> 3)) >> (noffs & 0x7)) & 0x7F) << (13 + 16 - 7);
  }

  ty_prev = ty;
  ty = linebuffer_ty[std::min<unsigned>(39, i >> 1)];
 }

 for(int i = 0; i < 3; i++)
  *(target++) = RGBLUT[0];
}

template<typename T, bool tfr, bool qd>
static void BlitLineBitBuffer_RGB(unsigned target_line)
{
 enum
 {
  RGB_LINE_TEXT40 = 0,
  RGB_LINE_TEXT80,
  RGB_LINE_LORES40,
  RGB_LINE_LORES80,
  RGB_LINE_HIRES40,
  RGB_LINE_HIRES80
 };
 uint8 rgb_line_type;

 {
  unsigned ty = linebuffer_ty[0];
  const bool text = (bool)(ty & 0x10);
  const bool hires = (bool)(ty & SOFTSWITCH_HIRES_MODE);

  if(text)
   rgb_line_type = (ty & SOFTSWITCH_80COL) ? RGB_LINE_TEXT80 : RGB_LINE_TEXT40;
  else if(hires)
   rgb_line_type = ((ty & (SOFTSWITCH_80COL | SOFTSWITCH_AN3)) == SOFTSWITCH_80COL) ? RGB_LINE_HIRES80 : RGB_LINE_HIRES40;
  else
  {
   if(!(ty & SOFTSWITCH_80COL) && (ty & 0x40))
    rgb_line_type = RGB_LINE_HIRES40;
   else
    rgb_line_type = ((ty & (SOFTSWITCH_80COL | SOFTSWITCH_AN3)) == SOFTSWITCH_80COL) ? RGB_LINE_LORES80 : RGB_LINE_LORES40;
  }
 }
 //
 //
 //
 T* MDFN_RESTRICT target = surface->pix<T>() + target_line * surface->pitchinpix;

 line_widths[target_line] = 584;

 //if(rand() & 0x8000)
 // rgb_line_type = RGB_LINE_TEXT80;

 if(rgb_line_type == RGB_LINE_TEXT40)
 {
  line_widths[target_line] = 292;
  //
  for(int i = 0; i < 3; i++)
   *(target++) = RGBLUT[0];

  for(int x = 0; x < 578; x += 2)
  {
   const bool C = (linebuffer[x >> 3] >> (x & 0x7)) & 1;
   target[x >> 1] = RGBLUT[C ? 15 : 0];
  }
 }
 else if(rgb_line_type == RGB_LINE_LORES40)
 {
  line_widths[target_line] = 292;
  //
  for(int i = 0; i < 7; i++)
   *(target++) = RGBLUT[0];

  for(unsigned i = 0; i < 40; i++)
  {
   const unsigned shift = (i & 1) << 1;
   uint32 po = i * 14 + 7;
   uint32 tmp = MDFN_de32lsb(&linebuffer[po >> 3]) >> (po & 0x7);
   uint32 color;

   tmp &= 0xF;
   tmp = (tmp << shift) + (tmp >> (4 - shift));
   color = RGBLUT[tmp & 0xF];

   for(unsigned j = 0; j < 7; j++)
   {
    *(target++) = color;
   }
  }

  for(int i = 0; i < 5; i++)
   *(target++) = RGBLUT[0];
 }
 else if(rgb_line_type == RGB_LINE_HIRES40)
 {
  line_widths[target_line] = 292;
  //
  uint32 pdata = 0;
  uint32 pshift = 0;
  uint32 bw = 0;
  uint32 cpd = 0;
  uint32 halve = 0;

  for(int i = 0; i < 7; i++)
   *(target++) = RGBLUT[0];

  for(int x = 0; x < 560 + 14; x += 14)
  {
   uint32 po = x + 7;
   uint32 tmp = MDFN_de32lsb(&linebuffer[po >> 3]) >> (po & 0x7);

   if((tmp ^ (tmp >> 1)) & 0x1555)
   {
    tmp = ((tmp >> 1) & 0x1FFF) | (tmp & 0x2000);
    pshift |= 0x3FFF << 14;
   }
   pdata |= (tmp & 0x3FFF) << 14;

   for(int sx = 0; sx < 14; sx += 2)
   {
    uint32 pat;

    if((pdata & 0xF00) == 0xF00)
     bw |= 0xF00;

    if((pdata & 0xF00) == 0x000)
     bw |= 0xF00;

    if(tfr)
    {
     if((pdata & 0xF3C) == 0xF3C)
      halve |= 0xC0;
    }

    if(!(sx & 0x3))
    {
     unsigned shift = ((x & 2) ^ 2) + (pshift & 1);
     cpd = pdata & 0xF;
     cpd = ((cpd << shift) | (cpd >> (4 - shift))) & 0xF;
    }

    if(bw & 1)
     pat = (pdata & 0x1) ? 0xF : 0x0;
    else if(tfr)
     pat = ((halve & 0x1) << 4) + cpd;
    else
     pat = cpd;

    *target = RGBLUT[pat];
    //
    if(x >= 14)
     target++;
    bw >>= 2;
    pdata >>= 2;
    pshift >>= 2;
    if(tfr)
     halve >>= 2;
   }
  }

  for(int i = 0; i < 5; i++)
   *(target++) = RGBLUT[0];
 }
 else if(rgb_line_type == RGB_LINE_TEXT80)
 {
  uint32 pdata = 0;

  for(int x = 0; x < 584; x++)
  {
   pdata |= ((linebuffer[x >> 3] >> (x & 0x7)) & 1) << 7;
   //
   const bool C = (pdata & 1);
   target[x] = RGBLUT[C ? 15 : 0];
   //
   pdata >>= 1;
  }
 }
 else if(rgb_line_type == RGB_LINE_LORES80)
 {
  uint32 pdata = 0;
  unsigned pat = 0;
  unsigned dc = 7 + 1;

  for(int x = 0; x < 584; x++)
  {
   unsigned phase = (x - 7 + 1) & 3;
   bool nb = ((linebuffer[x >> 3] >> (x & 0x7)) & 1);

   pdata |= nb << 7;
   //
   dc--;
   if(!dc)
   {
    pat = (pdata >> 0) & 0xF;
    pat = ((pat << phase) | (pat >> (4 - phase))) & 0xF;
    dc = 7;
   }

   target[x] = RGBLUT[pat];
   //
   pdata >>= 1;
  }
 }
 else if(qd)
 {
  uint32 pdata = 0;

  line_widths[target_line] = 584 / 4;

  for(int x = 0; x < 584; x++)
  {
   bool nb = ((linebuffer[x >> 3] >> (x & 0x7)) & 1);
   unsigned mc;

   pdata |= nb << 13;
   //
   if((x & 0x3) == 0x1)
   {
    unsigned subph = (x & 0x3);
    mc = (pdata >> 4) & 0xF;
    mc = ((mc << subph) | (mc >> (4 - subph))) & 0xF;
    target[x >> 2] = RGBLUT[mc];
   }
   //
   pdata >>= 1;
  }
 }
 else
 {
  uint32 pdata = 0;

  for(int x = 0; x < 584; x++)
  {
   bool nb = ((linebuffer[x >> 3] >> (x & 0x7)) & 1);
   unsigned mc;

   pdata |= nb << 13;
   //
   mc = *((uint8*)ColorLUT + ((x & 3) << 13) + (pdata & 0x1FFF) );

   if(!tfr)
    mc &= 0x0F;

   target[x] = RGBLUT[mc];
   //
   pdata >>= 1;
  }
 }
}

template<typename T>
static void BlitLineBitBuffer_RGB_Video7(unsigned target_line)
{
 T* MDFN_RESTRICT target = surface->pix<T>() + target_line * surface->pitchinpix;
 uint32 rotlut[16];
 uint32 hrlut[2][2][8];

 for(unsigned i = 0; i < 16; i++)
  rotlut[i] = RGBLUT[((i >> 3) | (i << 1)) & 0xF];

 for(unsigned i = 0; i < 2; i++)
 {
  for(unsigned j = 0; j < 2; j++)
  {
   for(unsigned k = 0; k < 8; k++)
   {
    uint8 mc = (k >> 1) & 0x3;

    mc = (mc & 0x1) | ((mc & 0x1) << 1) | ((mc & 0x2) << 1) | ((mc & 0x2) << 2);

    if(i & 1)
     mc = ((mc << 1) | (mc >> 3)) & 0xF;

    if(j & 1)
     mc = ((mc << 2) | (mc >> 2)) & 0xF;

    if((k & 0x3) == 0x3 || (k & 0x6) == 0x6)
     mc = 0xF;
    else if((k & 0x3) == 0x0 || (k & 0x6) == 0x0)
     mc = 0x0;

    hrlut[i][j][k] = RGBLUT[mc];
   }
  }
 }
 //
 //
 line_widths[target_line] = 584;

 for(unsigned i = 0; i < 584; i++)
  target[i] = RGBLUT[0];
 //
 //
 target += 7;

 for(unsigned i = 0; i < 40; i++)
 {
  const uint16 ty = linebuffer_ty[i];
  const bool text = (bool)(ty & 0x10);
  const bool dhgr = (ty & (0x04 | SOFTSWITCH_AN3 | SOFTSWITCH_HIRES_MODE | SOFTSWITCH_80COL)) == (SOFTSWITCH_HIRES_MODE | SOFTSWITCH_80COL);
  const uint8 dhgrmode = ty & 0x03;
  const bool an3 = (bool)(ty & SOFTSWITCH_AN3);
  const bool hires = (bool)(ty & SOFTSWITCH_HIRES_MODE);
  const bool col80 = (bool)(ty & SOFTSWITCH_80COL);
  T* const starget = target + 7;
  const uint32 lboffs = i * 14;
  uint32 bwlut[2];

  bwlut[0] = RGBLUT[0x0];
  bwlut[1] = RGBLUT[0xF];

  if(text)
  {
   if(!an3 && !col80)
   {
    const uint8 ext = linebuffer_ex[i * 2 + 0];

    bwlut[0] = RGBLUT[(ext >> 0) & 0xF];
    bwlut[1] = RGBLUT[(ext >> 4) & 0xF];
   }

   const uint32 soffs = lboffs + (col80 ? 0 : 7);
   uint32 p = (MDFN_de32lsb(linebuffer + (soffs >> 3)) >> (soffs & 0x7)) & 0x3FFF;
   T* bwtarget = col80 ? target : starget;

   bwtarget[0] = bwlut[(p >> 0) & 0x1];
   bwtarget[1] = bwlut[(p >> 1) & 0x1];
   bwtarget[2] = bwlut[(p >> 2) & 0x1];
   bwtarget[3] = bwlut[(p >> 3) & 0x1];
   bwtarget[4] = bwlut[(p >> 4) & 0x1];
   bwtarget[5] = bwlut[(p >> 5) & 0x1];
   bwtarget[6] = bwlut[(p >> 6) & 0x1];
   bwtarget[7] = bwlut[(p >> 7) & 0x1];
   bwtarget[8] = bwlut[(p >> 8) & 0x1];
   bwtarget[9] = bwlut[(p >> 9) & 0x1];
   bwtarget[10] = bwlut[(p >> 10) & 0x1];
   bwtarget[11] = bwlut[(p >> 11) & 0x1];
   bwtarget[12] = bwlut[(p >> 12) & 0x1];
   bwtarget[13] = bwlut[(p >> 13) & 0x1];
  }
  else if(dhgr)
  {
   const uint8 ext = linebuffer_ex[i * 2 + 0];
   const uint8 d = linebuffer_ex[i * 2 + 1];

   if(dhgrmode == 0x3)		// 560x192
   {
    uint32 p = ((ext & 0x7F) << 0) + ((d & 0x7F) << 7);

    target[0] = bwlut[(p >> 0) & 0x1];
    target[1] = bwlut[(p >> 1) & 0x1];
    target[2] = bwlut[(p >> 2) & 0x1];
    target[3] = bwlut[(p >> 3) & 0x1];
    target[4] = bwlut[(p >> 4) & 0x1];
    target[5] = bwlut[(p >> 5) & 0x1];
    target[6] = bwlut[(p >> 6) & 0x1];
    target[7] = bwlut[(p >> 7) & 0x1];
    target[8] = bwlut[(p >> 8) & 0x1];
    target[9] = bwlut[(p >> 9) & 0x1];
    target[10] = bwlut[(p >> 10) & 0x1];
    target[11] = bwlut[(p >> 11) & 0x1];
    target[12] = bwlut[(p >> 12) & 0x1];
    target[13] = bwlut[(p >> 13) & 0x1];
   }
   else if(dhgrmode == 0x2)	// Mix mode
   {
    uint32 c;
    uint32 qp;

    if(i & 1)
     qp = ((linebuffer_ex[i * 2 - 1] >> 5) & 0x3) + ((ext & 0x7F) << 2) + (d << 9);
    else
     qp = ((ext & 0x7F) << 0) + ((d & 0x7F) << 7) + (linebuffer_ex[i * 2 + 2] << 14);

    if(!(ext & 0x80))
    {
     target[0] = bwlut[(ext >> 0) & 0x1];
     target[1] = bwlut[(ext >> 1) & 0x1];
     target[2] = bwlut[(ext >> 2) & 0x1];
     target[3] = bwlut[(ext >> 3) & 0x1];
     target[4] = bwlut[(ext >> 4) & 0x1];
     target[5] = bwlut[(ext >> 5) & 0x1];
     target[6] = bwlut[(ext >> 6) & 0x1];
    }
    else
    {
     if(i & 1)
     {
      c = rotlut[(qp >> 0) & 0xF];
      target[0] = c;
      target[1] = c;

      c = rotlut[(qp >> 4) & 0xF];
      target[2] = c;
      target[3] = c;
      target[4] = c;
      target[5] = c;

      c = rotlut[(qp >> 8) & 0xF];
      target[6] = c;
     }
     else
     {
      c = rotlut[(qp >> 0) & 0xF];
      target[0] = c;
      target[1] = c;
      target[2] = c;
      target[3] = c;

      c = rotlut[(qp >> 4) & 0xF];
      target[4] = c;
      target[5] = c;
      target[6] = c; 
     }
    }

    if(!(d & 0x80))
    {
     target[7] = bwlut[(d >> 0) & 0x1];
     target[8] = bwlut[(d >> 1) & 0x1];
     target[9] = bwlut[(d >> 2) & 0x1];
     target[10] = bwlut[(d >> 3) & 0x1];
     target[11] = bwlut[(d >> 4) & 0x1];
     target[12] = bwlut[(d >> 5) & 0x1];
     target[13] = bwlut[(d >> 6) & 0x1];
    }
    else
    {
     if(i & 1)
     {
      c = rotlut[(qp >> 8) & 0xF];
      target[7] = c;
      target[8] = c;
      target[9] = c;

      c = rotlut[(qp >> 12) & 0xF];
      target[10] = c;
      target[11] = c;
      target[12] = c;
      target[13] = c;
     }
     else
     {
      c = rotlut[(qp >> 4) & 0xF];
      target[7] = c;

      c = rotlut[(qp >> 8) & 0xF];
      target[8] = c;
      target[9] = c;
      target[10] = c;
      target[11] = c;

      c = rotlut[(qp >> 12) & 0xF];
      target[12] = c;
      target[13] = c;
     }
    }
   }
   else if(dhgrmode == 0x1) // 160x192
   {
    uint32 c;
    const int disp = 1; //(target_line & 1);

    c = RGBLUT[(ext >> 0) & 0xF];
    target[0] = c;
    target[1] = c;
    target[2] = c;
    target[3] = c;

    c = RGBLUT[(ext >> 4) & 0xF];
    target[4 - disp] = c;
    target[4] = c;
    target[5] = c;
    target[6] = c;

    c = RGBLUT[(d >> 0) & 0xF];
    target[7] = c;
    target[8] = c;
    target[9] = c;
    target[10] = c;

    c = RGBLUT[(d >> 4) & 0xF];
    target[11 - disp] = c;
    target[11] = c;
    target[12] = c;
    target[13] = c;
   }
   else	// 140x192
   {
    uint32 c;
    uint32 qp = ((ext & 0x7F) << 0) + ((d & 0x7F) << 7) + (linebuffer_ex[i * 2 + 2] << 14);

    if(i & 1)
    {
     qp = (qp << 2) | ((linebuffer_ex[i * 2 - 1] >> 5) & 0x3);
     //
     c = rotlut[(qp >> 0) & 0xF];
     target[0] = c;
     target[1] = c;

     c = rotlut[(qp >> 4) & 0xF];
     target[2] = c;
     target[3] = c;
     target[4] = c;
     target[5] = c;

     c = rotlut[(qp >> 8) & 0xF];
     target[6] = c;
     target[7] = c;
     target[8] = c;
     target[9] = c;

     c = rotlut[(qp >> 12) & 0xF];
     target[10] = c;
     target[11] = c;
     target[12] = c;
     target[13] = c;
    }
    else
    {
     c = rotlut[(qp >> 0) & 0xF];
     target[0] = c;
     target[1] = c;
     target[2] = c;
     target[3] = c;

     c = rotlut[(qp >> 4) & 0xF];
     target[4] = c;
     target[5] = c;
     target[6] = c;
     target[7] = c;

     c = rotlut[(qp >> 8) & 0xF];
     target[8] = c;
     target[9] = c;
     target[10] = c;
     target[11] = c;

     c = rotlut[(qp >> 12) & 0xF];
     target[12] = c;
     target[13] = c;
    }
   }
  }
  else if(hires)
  {
   if(an3)
   {
    uint8 d0 = i ? linebuffer_ex[(i - 1) * 2 + 1] : 0;
    uint8 d1 = linebuffer_ex[(i + 0) * 2 + 1];
    uint8 d2 = linebuffer_ex[(i + 1) * 2 + 1];
    const auto& hrl = hrlut[(bool)(d1 & 0x80)];
    uint32 hp = ((d0 >> 6) & 0x01) | ((d1 & 0x7F) << 1) | (d2 << 8);

    if(i & 1)
    {
     starget[0] = starget[1] = hrl[1][(hp >> 0) & 0x7];
     starget[2] = starget[3] = hrl[0][(hp >> 1) & 0x7];
     starget[4] = starget[5] = hrl[1][(hp >> 2) & 0x7];
     starget[6] = starget[7] = hrl[0][(hp >> 3) & 0x7];
     starget[8] = starget[9] = hrl[1][(hp >> 4) & 0x7];
     starget[10] = starget[11] = hrl[0][(hp >> 5) & 0x7];
     starget[12] = starget[13] = hrl[1][(hp >> 6) & 0x7];
    }
    else
    {
     starget[0] = starget[1] = hrl[0][(hp >> 0) & 0x7];
     starget[2] = starget[3] = hrl[1][(hp >> 1) & 0x7];
     starget[4] = starget[5] = hrl[0][(hp >> 2) & 0x7];
     starget[6] = starget[7] = hrl[1][(hp >> 3) & 0x7];
     starget[8] = starget[9] = hrl[0][(hp >> 4) & 0x7];
     starget[10] = starget[11] = hrl[1][(hp >> 5) & 0x7];
     starget[12] = starget[13] = hrl[0][(hp >> 6) & 0x7];
    }
   }
   else
   {
    uint8 ext = linebuffer_ex[i * 2 + 0];
    uint8 d = linebuffer_ex[i * 2 + 1];
    uint32 hrclut[2];

    hrclut[0] = RGBLUT[(ext >> 0) & 0xF];
    hrclut[1] = RGBLUT[(ext >> 4) & 0xF];

    starget[0] = starget[1] = hrclut[(d >> 0) & 0x1];
    starget[2] = starget[3] = hrclut[(d >> 1) & 0x1];
    starget[4] = starget[5] = hrclut[(d >> 2) & 0x1];
    starget[6] = starget[7] = hrclut[(d >> 3) & 0x1];
    starget[8] = starget[9] = hrclut[(d >> 4) & 0x1];
    starget[10] = starget[11] = hrclut[(d >> 5) & 0x1];
    starget[12] = starget[13] = hrclut[(d >> 6) & 0x1];
   }
  }
  else
  {
   uint8 ext = linebuffer_ex[i * 2 + 0];
   uint8 d = linebuffer_ex[i * 2 + 1];
   unsigned sh = (target_line & 0x4);
   uint32 c;

   if(an3 || !col80)	// LORES
   {
    c = RGBLUT[(d >> sh) & 0xF];
    starget[0] = c;
    starget[1] = c;
    starget[2] = c;
    starget[3] = c;
    starget[4] = c;
    starget[5] = c;
    starget[6] = c;
    starget[7] = c;
    starget[8] = c;
    starget[9] = c;
    starget[10] = c;
    starget[11] = c;
    starget[12] = c;
    starget[13] = c;
   }
   else	// MERES
   {
    c = (ext >> sh) & 0xF;
    c = ((c << 1) | (c >> 3)) & 0xF;
    c = RGBLUT[c];
    target[0] = c;
    target[1] = c;
    target[2] = c;
    target[3] = c;
    target[4] = c;
    target[5] = c;
    target[6] = c;

    c = RGBLUT[(d >> sh) & 0xF];
    target[7] = c;
    target[8] = c;
    target[9] = c;
    target[10] = c;
    target[11] = c;
    target[12] = c;
    target[13] = c;
   }
  }
  //
  target += 14;
 }
}

template<typename T, bool rgb555>
static void BlitLineBitBuffer_Composite(unsigned target_line)
{
 T* MDFN_RESTRICT target = surface->pix<T>() + target_line * surface->pitchinpix;
 uint32 pdata = 0;
 const unsigned nb_pos = 1 + (ColorLUT_NumPixels - 1);
 const uint8 rs = format.Rshift;
 const uint8 gs = format.Gshift;
 const uint8 bs = format.Bshift;

 line_widths[target_line] = 584;

 for(size_t x = 0; x < 584; x++)
 {
  uint32 c;

  pdata |= ((linebuffer[x >> 3] >> (x & 0x7)) & 1) << nb_pos;
  c = ColorLUT[colorburst_present][(x - 7 - nb_pos) & 3][pdata & 0x1FFF];
  c += (NoiseLCG >> 32) & ((0x7 << 0) | (0x7 << 10) | (0x7 << 20));

  if(sizeof(T) == 4)
   target[x] = (((c >> 2) & 0xFF) << rs) + (((c >> 12) & 0xFF) << gs) + (((c >> 22) & 0xFF) << bs);
  else if(rgb555)
   target[x] = (((c >> 5) & 0x1F) << rs) + (((c >> 15) & 0x1F) << gs) + (((c >> 25) & 0x1F) << bs);
  else
   target[x] = (((c >> 5) & 0x1F) << rs) + (((c >> 14) & 0x3F) << gs) + (((c >> 25) & 0x1F) << bs);

  pdata >>= 1;
  NoiseLCG = (NoiseLCG * 6364136223846793005ULL) + 1442695040888963407ULL;
 }
}

template<typename T, bool rgb555>
static void BlitLineBitBuffer_Composite_Sharp(unsigned target_line)
{
 if(!colorburst_present)
  return BlitLineBitBuffer_Composite<T, rgb555>(target_line);
 //
 T* MDFN_RESTRICT target = surface->pix<T>() + target_line * surface->pitchinpix;
 uint32 pdata = 0;
 const unsigned nb_pos = 1 + (ColorLUT_NumPixels - 1);
 const uint8 rs = format.Rshift;
 const uint8 gs = format.Gshift;
 const uint8 bs = format.Bshift;
 struct
 {
  int16 r;
  int16 g;
  int16 b;
 } tmp[2 + 584 + 2];

 line_widths[target_line] = 584;

 for(size_t x = 0; x < 584; x++)
 {
  auto* t = &tmp[2 + x];
  uint32 c;

  pdata |= ((linebuffer[x >> 3] >> (x & 0x7)) & 1) << nb_pos;

  c = ColorLUT[colorburst_present][(x - 7 - nb_pos) & 3][pdata & 0x1FFF];

  t->r = SharpGCRLUT[(c >>   0) & 0x3FF];
  t->g = SharpGCRLUT[(c >>  10) & 0x3FF];
  t->b = SharpGCRLUT[(c >>  20) & 0x3FF];

  pdata >>= 1;
 }

 tmp[0] = tmp[1] = tmp[2];
 tmp[2 + 584] = tmp[2 + 585] = tmp[2 + 583];

 for(size_t x = 0; x < 584; x++)
 {
  uint32 c;
  int32 vr, vg, vb;
  int32 vri, vgi, vbi;
  auto const* t = &tmp[2 + x];

  vr = t[0].r * SharpCoeffs[0] + (t[-1].r + t[1].r) * SharpCoeffs[1] + (t[-2].r + t[2].r) * SharpCoeffs[2];
  vg = t[0].g * SharpCoeffs[0] + (t[-1].g + t[1].g) * SharpCoeffs[1] + (t[-2].g + t[2].g) * SharpCoeffs[2];
  vb = t[0].b * SharpCoeffs[0] + (t[-1].b + t[1].b) * SharpCoeffs[1] + (t[-2].b + t[2].b) * SharpCoeffs[2];

  vr >>= 13;
  vg >>= 13;
  vb >>= 13;

  vr = (vr | ((4095 - vr) >> 31)) & ((~vr >> 31) & 4095);
  vg = (vg | ((4095 - vg) >> 31)) & ((~vg >> 31) & 4095);
  vb = (vb | ((4095 - vb) >> 31)) & ((~vb >> 31) & 4095);

  vri = SharpGCALUT[vr];
  vgi = SharpGCALUT[vg];
  vbi = SharpGCALUT[vb];

  c = (vri << 0) + (vgi << 10) + (vbi << 20);
  c += (NoiseLCG >> 32) & ((0x7 << 0) | (0x7 << 10) | (0x7 << 20));

  if(sizeof(T) == 4)
   target[x] = (((c >> 2) & 0xFF) << rs) + (((c >> 12) & 0xFF) << gs) + (((c >> 22) & 0xFF) << bs);
  else if(rgb555)
   target[x] = (((c >> 5) & 0x1F) << rs) + (((c >> 15) & 0x1F) << gs) + (((c >> 25) & 0x1F) << bs);
  else
   target[x] = (((c >> 5) & 0x1F) << rs) + (((c >> 14) & 0x3F) << gs) + (((c >> 25) & 0x1F) << bs);

  NoiseLCG = (NoiseLCG * 6364136223846793005ULL) + 1442695040888963407ULL;
 }
}

static INLINE void BlitLine(unsigned vis_vc)
{
#if 0
    // 0x0D0
    memset(linebuffer, 0, sizeof(linebuffer));

    if(vis_vc < 32)
    {
     for(unsigned i = 0; i < 4; i++)
      BitsIntract(linebuffer, 64 + 65 * i, 24, (0x0D0 << 4) + ((rand() >> 12) & 0xF000F) );
    }
    else if(vis_vc < 64)
    {
     for(unsigned i = 0; i < 4; i++)
      BitsIntract(linebuffer, 64 + 65 * i, 24, (0x0D0 << 4) + ((rand() >> 12) & 0xF801F) );
    }
    else if(vis_vc < 96)
    {
     for(unsigned i = 0; i < 4; i++)
      BitsIntract(linebuffer, 64 + 65 * i, 24, (0x0D0 << 4) + ((rand() >> 12) & 0xFC03F) );
    }
    else if(vis_vc < 128)
    {
     for(unsigned i = 0; i < 4; i++)
      BitsIntract(linebuffer, 64 + 65 * i, 24, (0x0D0 << 4) + ((rand() >> 12) & 0xFE07F) );
    }
    else if(vis_vc < 160)
    {
     for(unsigned i = 0; i < 4; i++)
      BitsIntract(linebuffer, 64 + 65 * i, 24, (0x0D0 << 4) + ((rand() >> 12) & 0xFF0FF) );
    }
#endif

#if 0
    memset(linebuffer, 0, sizeof(linebuffer));

    {
     for(unsigned i = 0; i < 4; i++)
      BitsIntract(linebuffer, 64 + 65 * i, 16, (vis_vc & 0x7F) << 5);   //((rand() >> 12) & 0xE01F) );
    }
#endif

#if 0
    // 0x02E0
    memset(linebuffer, 0, sizeof(linebuffer));

    if(vis_vc < 128)
    {
     // 0x1FF0
     //for(unsigned i = 0; i < 4; i++)
     // BitsIntract(linebuffer, 64 + 65 * i, 16, 0x02C0 + ((vis_vc >> 1) & 0x30));   //((rand() >> 12) & 0xE01F) );
     for(unsigned i = 0; i < 4; i++)
      BitsIntract(linebuffer, 64 + 65 * i, 16, 0x02C0 + (((vis_vc >> 4) & 0xF) << 12)); //((vis_vc >> 1) & 0x30) + );   //((rand() >> 12) & 0xE01F) );
    }
#endif

#if 0
    // 0x1D00
    // 0x1D10
    // 0x1D20
    // 0x1D30
    memset(linebuffer, 0, sizeof(linebuffer));

    for(unsigned i = 0; i < 4; i++)
     BitsIntract(linebuffer, 64 + 65 * i, 16, 0x1D00 + (((vis_vc >> 3) & 0xF) << 4) + ((rand() >> 16) & 0xF) );
#endif

#if 0
    memset(linebuffer, 0, sizeof(linebuffer));

    if(vis_vc < 128)
    {
     unsigned h = (vis_vc >> 2) & 0xF; //vis_vc & 0xF;
     unsigned l = (vis_vc & 0x40) ? 0xA : 0x5; //(vis_vc >> 4) | 0x8;

     for(unsigned i = 0; i < 4; i++)
      BitsIntract(linebuffer, 65 * i, 16, (h << 12) | (h << 8) | (l << 4) | (l << 0));

     for(unsigned i = 0; i < 4; i++)
      BitsIntract(linebuffer, 325 + 65 * i, 16, (l << 12) | (l << 8) | (h << 4) | (h << 0));

     BitsIntract(linebuffer, 65 * 4 - 16, 4, (vis_vc >> 3) & 0xF);
     BitsIntract(linebuffer, 65 * 4 - 16 + 1 * 17, 4, (vis_vc >> 3) & 0xF);
     BitsIntract(linebuffer, 65 * 4 - 16 + 2 * 17, 4, (vis_vc >> 3) & 0xF);
     BitsIntract(linebuffer, 65 * 4 - 16 + 3 * 17, 4, (vis_vc >> 3) & 0xF);
    }
    else if(vis_vc >= 136)
    {
     for(unsigned i = 0; i < 16; i++)
     {
      unsigned l = 0xF;
      unsigned h = i;

      if(vis_vc >= 164)
       std::swap(l, h);

      BitsIntract(linebuffer, 0 + 32 * i, 16, (h << 12) | (h << 8) | (l << 4) | (l << 0));
     }
    }
#endif

 BlitLineBitBuffer(vis_vc);
}

static const uint8 FontData[0x200] =
{
 0x00, 0x1c, 0x22, 0x2a, 0x3a, 0x1a, 0x02, 0x3c, 
 0x00, 0x08, 0x14, 0x22, 0x22, 0x3e, 0x22, 0x22, 
 0x00, 0x1e, 0x22, 0x22, 0x1e, 0x22, 0x22, 0x1e, 
 0x00, 0x1c, 0x22, 0x02, 0x02, 0x02, 0x22, 0x1c, 
 0x00, 0x1e, 0x22, 0x22, 0x22, 0x22, 0x22, 0x1e, 
 0x00, 0x3e, 0x02, 0x02, 0x1e, 0x02, 0x02, 0x3e, 
 0x00, 0x3e, 0x02, 0x02, 0x1e, 0x02, 0x02, 0x02, 
 0x00, 0x3c, 0x02, 0x02, 0x02, 0x32, 0x22, 0x3c, 
 0x00, 0x22, 0x22, 0x22, 0x3e, 0x22, 0x22, 0x22, 
 0x00, 0x1c, 0x08, 0x08, 0x08, 0x08, 0x08, 0x1c, 
 0x00, 0x20, 0x20, 0x20, 0x20, 0x20, 0x22, 0x1c, 
 0x00, 0x22, 0x12, 0x0a, 0x06, 0x0a, 0x12, 0x22, 
 0x00, 0x02, 0x02, 0x02, 0x02, 0x02, 0x02, 0x3e, 
 0x00, 0x22, 0x36, 0x2a, 0x2a, 0x22, 0x22, 0x22, 
 0x00, 0x22, 0x22, 0x26, 0x2a, 0x32, 0x22, 0x22, 
 0x00, 0x1c, 0x22, 0x22, 0x22, 0x22, 0x22, 0x1c, 
 0x00, 0x1e, 0x22, 0x22, 0x1e, 0x02, 0x02, 0x02, 
 0x00, 0x1c, 0x22, 0x22, 0x22, 0x2a, 0x12, 0x2c, 
 0x00, 0x1e, 0x22, 0x22, 0x1e, 0x0a, 0x12, 0x22, 
 0x00, 0x1c, 0x22, 0x02, 0x1c, 0x20, 0x22, 0x1c, 
 0x00, 0x3e, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 
 0x00, 0x22, 0x22, 0x22, 0x22, 0x22, 0x22, 0x1c, 
 0x00, 0x22, 0x22, 0x22, 0x22, 0x22, 0x14, 0x08, 
 0x00, 0x22, 0x22, 0x22, 0x2a, 0x2a, 0x36, 0x22, 
 0x00, 0x22, 0x22, 0x14, 0x08, 0x14, 0x22, 0x22, 
 0x00, 0x22, 0x22, 0x14, 0x08, 0x08, 0x08, 0x08, 
 0x00, 0x3e, 0x20, 0x10, 0x08, 0x04, 0x02, 0x3e, 
 0x00, 0x3e, 0x06, 0x06, 0x06, 0x06, 0x06, 0x3e, 
 0x00, 0x00, 0x02, 0x04, 0x08, 0x10, 0x20, 0x00, 
 0x00, 0x3e, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3e, 
 0x00, 0x00, 0x00, 0x08, 0x14, 0x22, 0x00, 0x00, 
 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3e, 
 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 
 0x00, 0x08, 0x08, 0x08, 0x08, 0x08, 0x00, 0x08, 
 0x00, 0x14, 0x14, 0x14, 0x00, 0x00, 0x00, 0x00, 
 0x00, 0x14, 0x14, 0x3e, 0x14, 0x3e, 0x14, 0x14, 
 0x00, 0x08, 0x3c, 0x0a, 0x1c, 0x28, 0x1e, 0x08, 
 0x00, 0x06, 0x26, 0x10, 0x08, 0x04, 0x32, 0x30, 
 0x00, 0x04, 0x0a, 0x0a, 0x04, 0x2a, 0x12, 0x2c, 
 0x00, 0x08, 0x08, 0x08, 0x00, 0x00, 0x00, 0x00, 
 0x00, 0x08, 0x04, 0x02, 0x02, 0x02, 0x04, 0x08, 
 0x00, 0x08, 0x10, 0x20, 0x20, 0x20, 0x10, 0x08, 
 0x00, 0x08, 0x2a, 0x1c, 0x08, 0x1c, 0x2a, 0x08, 
 0x00, 0x00, 0x08, 0x08, 0x3e, 0x08, 0x08, 0x00, 
 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 0x08, 0x04, 
 0x00, 0x00, 0x00, 0x00, 0x3e, 0x00, 0x00, 0x00, 
 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08, 
 0x00, 0x00, 0x20, 0x10, 0x08, 0x04, 0x02, 0x00, 
 0x00, 0x1c, 0x22, 0x32, 0x2a, 0x26, 0x22, 0x1c, 
 0x00, 0x08, 0x0c, 0x08, 0x08, 0x08, 0x08, 0x1c, 
 0x00, 0x1c, 0x22, 0x20, 0x18, 0x04, 0x02, 0x3e, 
 0x00, 0x3e, 0x20, 0x10, 0x18, 0x20, 0x22, 0x1c, 
 0x00, 0x10, 0x18, 0x14, 0x12, 0x3e, 0x10, 0x10, 
 0x00, 0x3e, 0x02, 0x1e, 0x20, 0x20, 0x22, 0x1c, 
 0x00, 0x38, 0x04, 0x02, 0x1e, 0x22, 0x22, 0x1c, 
 0x00, 0x3e, 0x20, 0x10, 0x08, 0x04, 0x04, 0x04, 
 0x00, 0x1c, 0x22, 0x22, 0x1c, 0x22, 0x22, 0x1c, 
 0x00, 0x1c, 0x22, 0x22, 0x3c, 0x20, 0x10, 0x0e, 
 0x00, 0x00, 0x00, 0x08, 0x00, 0x08, 0x00, 0x00, 
 0x00, 0x00, 0x00, 0x08, 0x00, 0x08, 0x08, 0x04, 
 0x00, 0x10, 0x08, 0x04, 0x02, 0x04, 0x08, 0x10, 
 0x00, 0x00, 0x00, 0x3e, 0x00, 0x3e, 0x00, 0x00, 
 0x00, 0x04, 0x08, 0x10, 0x20, 0x10, 0x08, 0x04, 
 0x00, 0x1c, 0x22, 0x10, 0x08, 0x08, 0x00, 0x88
};

//
// II/II+
//
static NO_INLINE void Tick_II_IIP(void)
{
 flashycounter -= 14;

 const bool text = (SoftSwitch & SOFTSWITCH_TEXT_MODE) || ((SoftSwitch & SOFTSWITCH_MIX_MODE) && (VCounter & 0xFF) >= 160);
 const bool hires = (SoftSwitch & SOFTSWITCH_HIRES_MODE);
 unsigned ram_addr;
 uint8 ram_data;

 ram_addr = ((0x68 + (HCounter & 0x3F) + ((VCounter >> 3) & 0x18) + ((VCounter >> 1) & 0x60)) & 0x7F) + (((VCounter >> 3) & 0x7) << 7);

 if(text || !hires)
 {
  ram_addr |= (HCounter < 0x58) << 12;
  ram_addr |= (SoftSwitch & SOFTSWITCH_PAGE2) ? 0x800 : 0x400;
 }
 else
 {
  ram_addr |= ((VCounter & 0x7) << 10);
  ram_addr |= (SoftSwitch & SOFTSWITCH_PAGE2) ? 0x4000 : 0x2000;
 }

 //if(HCounter == 0x0) //VCounter == 0x100)
 // printf("%03x %02x: %04x\n", VCounter, HCounter, ram_addr);
 if(MDFN_LIKELY(RAMPresent[ram_addr >> 12]))
  DB = RAM[ram_addr];

 ram_data = DB;

 {
  static const uint8 tab[16] = { 0x00, 0x03, 0x0C, 0x0F, 0x30, 0x33, 0x3C, 0x3F, 0xC0, 0xC3, 0xCC, 0xCF, 0xF0, 0xF3, 0xFC, 0xFF };
  unsigned pixb = 0;

  if(text)
  {
   uint8 fd = FontData[((ram_data & 0x3F) << 3) | (VCounter & 0x7)];
   bool invert = (!(ram_data & 0x80)) & (!(ram_data & 0x40) | !flashything);

   if(invert)
    fd ^= 0x7F;

   pixb = tab[fd & 0xF] | (tab[(fd >> 4) & 0x7] << 8);
  }
  else if(hires)
  {
   bool new_HiresDelayBit;

   pixb = tab[ram_data & 0xF] | (tab[(ram_data >> 4) & 0x7] << 8);
   new_HiresDelayBit = pixb & 0x2000;
   if(ram_data & 0x80)
    pixb = (pixb << 1) | HiresDelayBit;
   HiresDelayBit = new_HiresDelayBit;
   // 1100
   // 1001
  }
  else
  {
   pixb = (ram_data >> (VCounter & 4)) & 0xF;
   pixb |= pixb << 4;
   pixb |= pixb << 8;
   pixb >>= ((HCounter & 1) << 1);
  }

  //if(!text && hires && HCounter == 0x57)
  // printf("%3d: 0x%04x %02x\n", VCounter, ram_addr, ram_data);

  if(HCounter >= 0x58)
  {
   const size_t po = (HCounter - 0x58) * 14 + 7;
   pixb &= 0x3FFF;
   MDFN_en32lsb(&linebuffer[po >> 3], (MDFN_de32lsb(&linebuffer[po >> 3]) & ~(0x3FFF << (po & 7))) | (pixb << (po & 7)));

   linebuffer_ex[(HCounter - 0x58) * 2 + 1] = ram_data;
   linebuffer_ty[HCounter - 0x58] = (SoftSwitch & SOFTSWITCH_HIRES_MODE) | (text << 4) | (SOFTSWITCH_AN3 | 0x3);
  }
  else if(HCounter == 0x00)
  {
   // TODO/FIXME: make less kludgey.
   const size_t po = 40 * 14 + 7;
   bool b = (pixb & 1) & !text & hires & (ram_data >> 7);

   linebuffer[po >> 3] &= ~(1U << (po & 0x7));
   linebuffer[po >> 3] |= b << (po & 0x7);
  }
 }

 HCounter = ((HCounter | 0x40) + (HCounter >> 6)) & 0x7F;

 if(HCounter == 0)
 {
  timestamp += 2;
  flashycounter -= 2;
  //
  VCounter = (VCounter + 1) & 0x1FF;
  if(!VCounter)
  {
   VCounter = 0xFA;
  }
 }
 else if(HCounter == 0x40)
 {
  unsigned vis_vc = (VCounter - 1) ^ 0x100;

  if(vis_vc < 192)
  {
   BlitLine(vis_vc);
  }

  if(VCounter == 0x1C0)
  {
   FramePartialDone = true;
   FrameDone = true;
  }
  else if(VCounter == 0x13D)
  {
   FramePartialDone = true;
  }
  //
  //
  //
 }
 else if(HCounter == 0x4D)
 {
  colorburst_present = !(SoftSwitch & SOFTSWITCH_TEXT_MODE);

  if(text && EnableMixedTextMonoHack)
   colorburst_present = false;
 }

 if(flashycounter <= 0)
 {
  flashything = !flashything;
  flashycounter += flashything ? 3286338 : 3274425;
 }
}

//
// IIe
//
static NO_INLINE void Tick_IIE(void)
{
 const bool text = (SoftSwitch & SOFTSWITCH_TEXT_MODE) || ((SoftSwitch & SOFTSWITCH_MIX_MODE) && (VCounter & 0xFF) >= 160);
 const bool hires = (SoftSwitch & SOFTSWITCH_HIRES_MODE);
 const bool page2 = ((SoftSwitch & (SOFTSWITCH_PAGE2 | SOFTSWITCH_80STORE)) == SOFTSWITCH_PAGE2);
 unsigned ram_addr;
 uint8 ram_data;
 uint8 aux_data;
 const bool force_text = (EnableFullAuxRAM & !(SoftSwitch & SOFTSWITCH_AN3));

 ram_addr = ((0x68 + (HCounter & 0x3F) + ((VCounter >> 3) & 0x18) + ((VCounter >> 1) & 0x60)) & 0x7F) + (((VCounter >> 3) & 0x7) << 7);

 if((text_delay & 0x1) || !hires)
 {
  ram_addr |= 0x400 << page2;
 }
 else
 {
  ram_addr |= ((VCounter & 0x7) << 10);
  ram_addr |= 0x2000 << page2;
 }

 //if(HCounter == 0x0) //VCounter == 0x100)
 // printf("%03x %02x: %04x\n", VCounter, HCounter, ram_addr);
 {
  size_t offs = ((1 << 16) + ram_addr) & RAMMask[1];

  if(offs < RAMSize)
   vid_db = RAM[offs];

  aux_data = vid_db;
 }

 DB = RAM[(0 << 16) + ram_addr];
 vid_db = DB;
 ram_data = vid_db;
 //
 //
 size_t rom_offs;

 if(!(text_delay & 0x1))
  rom_offs = (VCounter & 0x4) + (!hires << 1) + (HCounter & 1);
 else
  rom_offs = (VCounter & 0x7);

 if(!(text_delay & 0x1))
  rom_offs += 0x800;
 else if(!(SoftSwitch & SOFTSWITCH_ALTCHARSET))
 {
  bool flash = (bool)(fcounter & 0x10);

  aux_data = (aux_data | ((aux_data << 1) & (flash << 7))) & ((aux_data >> 1) | 0xBF);
  ram_data = (ram_data | ((ram_data << 1) & (flash << 7))) & ((ram_data >> 1) | 0xBF);
 }

 if((SoftSwitch & SOFTSWITCH_80COL) && ((text_delay & 0x2) | force_text))
 {
  uint32 pixb;
  uint8 fda = VideoROM[rom_offs + (aux_data << 3)];
  uint8 fdb = VideoROM[rom_offs + (ram_data << 3)];

  pixb = ~((fda & 0x7F) | (fdb << 7));
  shifter = pixb & 0x3FFF;
 }
 else
 {
  static const uint8 tab[16] = { 0x00, 0x03, 0x0C, 0x0F, 0x30, 0x33, 0x3C, 0x3F, 0xC0, 0xC3, 0xCC, 0xCF, 0xF0, 0xF3, 0xFC, 0xFF };
  uint32 pixb;
  uint8 fda = VideoROM[rom_offs + (ram_data << 3)];

  if(!text && !hires && !force_text)
   pixb = fda | (fda << 8);
  else
   pixb = tab[fda & 0xF] | (tab[(fda >> 4)] << 8);

  pixb = ~pixb;

  {
   bool new_HiresDelayBit;

   new_HiresDelayBit = pixb & 0x2000;
   if((ram_data & 0x80) && !force_text && !(text_delay & 0x1) && hires)
    pixb = (pixb << 1) | HiresDelayBit;
   HiresDelayBit = new_HiresDelayBit;
  }

  shifter = (shifter & 0x7F) | ((pixb & 0x3FFF) << 7);
 }

 if(HCounter >= 0x58)
 {
  const size_t po = (HCounter - 0x58) * 14;
  MDFN_en32lsb(&linebuffer[po >> 3], (MDFN_de32lsb(&linebuffer[po >> 3]) & ~(0x3FFF << (po & 7))) | ((shifter & 0x3FFF) << (po & 7)));
  shifter >>= 14;
  if(HCounter == 0x7F)
  {
   const size_t po2 = (HCounter - 0x58 + 1) * 14;
   MDFN_en32lsb(&linebuffer[po2 >> 3], (MDFN_de32lsb(&linebuffer[po2 >> 3]) & ~(0x7F << (po2 & 7))) | ((shifter & 0x7F) << (po2 & 7)));
   shifter >>= 7;
  }

  linebuffer_ex[(HCounter - 0x58) * 2 + 0] = aux_data;
  linebuffer_ex[(HCounter - 0x58) * 2 + 1] = ram_data;
  linebuffer_ty[HCounter - 0x58] = (SoftSwitch & (SOFTSWITCH_AN3 | SOFTSWITCH_HIRES_MODE | SOFTSWITCH_80COL)) | ((text_delay & 3) << 4) | (force_text << 6) | V7RGBMode;
 }
 else
 {
  HiresDelayBit = 0;
  shifter = 0;
 }
 //
 //

 HCounter = ((HCounter | 0x40) + (HCounter >> 6)) & 0x7F;

 if(HCounter == 0)
 {
  timestamp += 2;
  //
  VCounter = (VCounter + 1) & 0x1FF;
  if(!VCounter)
  {
   VCounter = (0 ? 0xC8: 0xFA);
   //
   fcounter++;
   if((fcounter & 0xF) == 0x8)
    KBIO::ClockARDelay();
   else if((fcounter & 0x3) == 0x3)
    KBIO::ClockAR();
  }

  SoftSwitch &= ~SOFTSWITCH_VERTBLANK;
  SoftSwitch |= ((VCounter & (VCounter >> 1)) & 0x40) ? 0 : SOFTSWITCH_VERTBLANK;
 }
 else if(HCounter == 0x40)
 {
  unsigned vis_vc = (VCounter - 1) ^ 0x100;

  if(vis_vc < 192)
  {
   BlitLine(vis_vc);
  }

  if(VCounter == 0x1C0)
  {
   FramePartialDone = true;
   FrameDone = true;
  }
  else if(VCounter == 0x13D)
  {
   FramePartialDone = true;
  }
  //
  //
  //
 }
 else if(HCounter == 0x4D)
 {
  colorburst_present = !(SoftSwitch & SOFTSWITCH_TEXT_MODE);

  if(text && EnableMixedTextMonoHack)
   colorburst_present = false;
 }

 text_delay <<= 1;
 text_delay |= text;
}

void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(HCounter),
  SFVAR(VCounter),
  SFVAR(flashything),
  SFVAR(flashycounter),
  SFVAR(HiresDelayBit),
  SFVAR(NoiseLCG),

  SFVAR(vid_db),
  SFVAR(text_delay),
  SFVAR(shifter),
  SFVAR(fcounter),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "VIDEO");

 if(load)
 {
  HCounter &= 0x07F;
  VCounter &= 0x1FF;
 }
}

uint32 GetRegister(const unsigned id, char* const special, const uint32 special_len)
{
 uint32 ret = 0xDEADBEEF;

 switch(id)
 {
  case GSREG_HCOUNTER:
	ret = HCounter;
	break;

  case GSREG_VCOUNTER:
	ret = VCounter;
	break;
 }

 return ret;
}

void SetRegister(const unsigned id, const uint32 value)
{
 switch(id)
 {
  case GSREG_HCOUNTER:
	HCounter = value & 0x07F;
	break;

  case GSREG_VCOUNTER:
	VCounter = value & 0x1FF;
	break;
 }
}


void SetVideoROM(uint8* p)
{
 memcpy(VideoROM, p, sizeof(VideoROM));
}

MDFN_Rect StartFrame(MDFN_Surface* s, int32* lw)
{
 surface = s;
 line_widths = lw;

 return surface_dr;
}

void Init(const bool emulate_iie)
{
 Tick = emulate_iie ? Tick_IIE : Tick_II_IIP;
 //
 colorburst_present = false;
 memset(linebuffer, 0, sizeof(linebuffer));
 memset(linebuffer_ex, 0, sizeof(linebuffer_ex));
 memset(linebuffer_ty, 0, sizeof(linebuffer_ty));
}

void Kill(void)
{

}

static const float matrixes[Settings::MATRIX_CUSTOM][3][2] =
{
 //
 // Mednafen
 //
 {
  {  1.348808,  0.504299 }, // (102.5° *  1.440) + (237.7° *  0.000) + (0.0° *  0.000),
  { -0.242363, -0.526935 }, // (102.5° *  0.000) + (237.7° *  0.580) + (0.0° *  0.000),
  { -1.089278,  1.677341 }, // (102.5° *  0.000) + (237.7° *  0.000) + (0.0° *  2.000),
 },

 //
 // LA7620
 //
 {
  {  1.701933,  0.586023 }, // (104.0° *  1.800) + (238.0° *  0.000) + (0.0° *  0.000),
  { -0.253571, -0.543785 }, // (104.0° *  0.000) + (238.0° *  0.600) + (0.0° *  0.000),
  { -1.089278,  1.677341 }, // (104.0° *  0.000) + (238.0° *  0.000) + (0.0° *  2.000),
 },

 //
 // CXA2025 Japan
 //
 {
  {  1.377398,  0.732376 }, // (95.0° *  1.560) + (240.0° *  0.000) + (0.0° *  0.000),
  { -0.272394, -0.534604 }, // (95.0° *  0.000) + (240.0° *  0.600) + (0.0° *  0.000),
  { -1.089278,  1.677341 }, // (95.0° *  0.000) + (240.0° *  0.000) + (0.0° *  2.000),
 },

 //
 // CXA2025 USA
 //
 {
  {  1.629501,  0.316743 }, // (112.0° *  1.660) + (252.0° *  0.000) + (0.0° *  0.000),
  { -0.377592, -0.466288 }, // (112.0° *  0.000) + (252.0° *  0.600) + (0.0° *  0.000),
  { -1.089278,  1.677341 }, // (112.0° *  0.000) + (252.0° *  0.000) + (0.0° *  2.000),
 },

 //
 // CXA2060 Japan
 //
 {
  {  1.377398,  0.732376 }, // (95.0° *  1.560) + (236.0° *  0.000) + (0.0° *  0.000),
  { -0.257883, -0.607533 }, // (95.0° *  0.000) + (236.0° *  0.660) + (0.0° *  0.000),
  { -1.089278,  1.677341 }, // (95.0° *  0.000) + (236.0° *  0.000) + (0.0° *  2.000),
 },

 //
 // CXA2060 USA
 //
 {
  {  1.456385,  0.559054 }, // (102.0° *  1.560) + (236.0° *  0.000) + (0.0° *  0.000),
  { -0.234439, -0.552303 }, // (102.0° *  0.000) + (236.0° *  0.600) + (0.0° *  0.000),
  { -1.089278,  1.677341 }, // (102.0° *  0.000) + (236.0° *  0.000) + (0.0° *  2.000),
 },

 //
 // CXA2095 Japan
 //
 {
  {  1.059537,  0.563366 }, // (95.0° *  1.200) + (236.0° *  0.000) + (0.0° *  0.000),
  { -0.257883, -0.607533 }, // (95.0° *  0.000) + (236.0° *  0.660) + (0.0° *  0.000),
  { -1.089278,  1.677341 }, // (95.0° *  0.000) + (236.0° *  0.000) + (0.0° *  2.000),
 },

 //
 // CXA2095 USA
 //
 {
  {  1.483648,  0.482066 }, // (105.0° *  1.560) + (236.0° *  0.000) + (0.0° *  0.000),
  { -0.257883, -0.607533 }, // (105.0° *  0.000) + (236.0° *  0.660) + (0.0° *  0.000),
  { -1.089278,  1.677341 }, // (105.0° *  0.000) + (236.0° *  0.000) + (0.0° *  2.000),
 },
};

template<typename T, bool rgb555, typename U>
static void GetBlitLineFunction(const int mode, const bool sharp, U* p)
{
 switch(mode)
 {
  case Settings::MODE_COMPOSITE:
	if(sharp)
	 *p = BlitLineBitBuffer_Composite_Sharp<T, rgb555>;
	else
	 *p = BlitLineBitBuffer_Composite<T, rgb555>;
	break;

  case Settings::MODE_RGB_ALT_TFR:
	*p = BlitLineBitBuffer_RGB_Alt<T, true>;
	break;

  case Settings::MODE_RGB_ALT:
	*p = BlitLineBitBuffer_RGB_Alt<T, false>;
	break;

  case Settings::MODE_RGB_TFR:
	*p = BlitLineBitBuffer_RGB<T, true, false>;
	break;

  case Settings::MODE_RGB:
	*p = BlitLineBitBuffer_RGB<T, false, false>;
	break;

  case Settings::MODE_RGB_QD_TFR:
	*p = BlitLineBitBuffer_RGB<T, true, true>;
	break;

  case Settings::MODE_RGB_QD:
	*p = BlitLineBitBuffer_RGB<T, false, true>;
	break;

  case Settings::MODE_RGB_VIDEO7:
	*p = BlitLineBitBuffer_RGB_Video7<T>;
	break;
 }
}

static void BuildDHGRLUT(void)
{
 for(uint32 phase = 0; phase < 4; phase++)
 {
  for(uint32 pdata = 0; pdata < 0x8000; pdata += 0x0004)
  {
   unsigned mc;
   unsigned a, b;
   unsigned pat[2];
   static const uint32 weights[16] = { 0, 353, 285, 559, 351, 536 - 1, 568, 728, 347, 630, 536, 764, 644, 826, 813, 1000 };

   {
    unsigned subph = (phase + 6) & 3;
    pat[0] = (pdata >> 6) & 0xF;
    pat[0] = ((pat[0] << subph) | (pat[0] >> (4 - subph))) & 0xF;
   }

   {
    unsigned subph = (phase + 7) & 3;
    pat[1] = (pdata >> 7) & 0xF;
    pat[1] = ((pat[1] << subph) | (pat[1] >> (4 - subph))) & 0xF;
   }

   a = weights[pat[0]];
   b = weights[pat[1]];

   mc = pat[(a > b) ^ ((pdata >> 8) & 1)];

   // De-gray thingy
   if((pdata & 0x1FC0) == 0x1D00 || (pdata & 0x3FC0) == 0x0D00)
    mc = pat[0];
   else if((pdata & (0x1FC0 >> 1)) == (0x1D00 >> 1) || (pdata & (0x3FC0 >> 1)) == (0x0D00 >> 1))
    mc = pat[1];
#if 0
   //else if((pdata & 0x1FC0) == 0x02C0)
   // mc = pat[0];
   //else if((pdata & 0x1FE0) == 0x02C0 && pat[0] == 0xB)
   // mc = pat[0];
   else if((mc == 0x5 || mc == 0xA) && (pat[0] != pat[1]))
   {
    const bool eq[2] =
    {
     ((pdata >> 5) & 1) == ((pdata >>  9) & 1),
     ((pdata >> 11) & 1) == ((pdata >> 7) & 1),
    };

    if(eq[0] && eq[1])
    {

    }
    else if(eq[0])
     mc = pat[0];
    else if(eq[1])
     mc = pat[1];
   }
#endif
   {
    bool black = false;
    bool white = false;

    black |= ((pdata & 0xF00) == 0x000);
    black |= ((pdata & 0x780) == 0x000);
    black |= ((pdata & 0x3C0) == 0x000);
    black |= ((pdata & 0x1E0) == 0x000);

    white |= ((pdata & 0xF00) == 0xF00);
    white |= ((pdata & 0x780) == 0x780);
    white |= ((pdata & 0x3C0) == 0x3C0);
    white |= ((pdata & 0x1E0) == 0x1E0);

#if 0
    if(black && (pdata & 0x1E00) == 0x0600)
    {
     black = false;
     mc = pat[1];
    }

    if(black && (pdata & 0x00F0) == 0x00C0)
    {
     black = false;
     mc = pat[0];
    }
#endif
    if(black)
    {
     if((pdata & 0x600) == 0x600 || (pdata & 0x0C0) == 0x0C0 || (pdata & 0x060) == 0x060)
      mc = 0x0;

     // gray
     if((pdata & 0x0F0) == 0x0A0 || (pdata & 0xE00) == 0xA00)
      mc = 0x0;
     //
     //
     if((pdata & 0x0F0) == 0x0B0)
      mc = 0x0;
    }
    else if(white)
    {
     if((pdata & 0x600) == 0x000 || (pdata & 0x0C0) == 0x000 || (pdata & 0x060) == 0x000)
      mc = 0xF;
    }
   }

   {
    bool halve = false;

    // 1111 xx 1111
    halve |= ((pdata & 0x3CF0) == 0x3CF0) || ((pdata & 0x1E78) == 0x1E78);

    // 1111 xxx 1111
    halve |= ((pdata & 0x78F0) == 0x78F0) || ((pdata & 0x3C78) == 0x3C78) || ((pdata & 0x1E3C) == 0x1E3C);

    mc |= halve << 4;
   }

   *((uint8*)ColorLUT + (((phase + 2) & 3) << 13) + (pdata >> 2)) = mc;
  }
 }
}

// tint, saturation, -1.0 to 1.0
void SetFormat(const MDFN_PixelFormat& f, const Settings& s, uint8* CustomPalette, uint32 CustomPaletteNumEntries)
{
 int mode = s.mode;

 if(CustomPalette && CustomPaletteNumEntries)
 {
  if(mode == Settings::MODE_COMPOSITE)
   mode = (CustomPaletteNumEntries == 32) ? Settings::MODE_RGB_TFR : Settings::MODE_RGB;
  else if(mode == Settings::MODE_RGB && CustomPaletteNumEntries == 32)
   mode = Settings::MODE_RGB_TFR;
  else if(mode == Settings::MODE_RGB_QD && CustomPaletteNumEntries == 32)
   mode = Settings::MODE_RGB_QD_TFR;
  else if(mode == Settings::MODE_RGB_ALT && CustomPaletteNumEntries == 32)
   mode = Settings::MODE_RGB_ALT_TFR;
 }
 //
 //
 format = f;
 EnableMixedTextMonoHack = (mode != Settings::MODE_COMPOSITE) ? true : s.mixed_text_mono;
 //
 //
 surface_dr.x = 0;
 surface_dr.y = 0;
 surface_dr.w = 0;
 surface_dr.h = 192;
 //
 //
 const uint32 force_mono = (mode != Settings::MODE_COMPOSITE) ? 0 : s.force_mono;
 bool sharp = false;

 if(mode == Settings::MODE_COMPOSITE && !force_mono)
 {
  const float sa = s.postsharp;
  const double m[4] = { 1.0 + sa * (1.0 - 0.396825396825396803), sa * -0.250000000000000000, sa * -0.051587301587301571, 0 };

  for(unsigned i = 0; i < 4; i++)
   SharpCoeffs[i] = (int)floor(0.5 + m[i] * 8192);

  sharp = (SharpCoeffs[1] != 0);
 }

 if(sharp)
 {
  for(unsigned i = 0; i < 1024; i++)
   SharpGCRLUT[i] = 4095.0 * pow(i / 1016.0, 2.2);

  for(unsigned i = 0; i < 4096; i++)
   SharpGCALUT[i] = (int)floor(0.5 + 1016.0 * pow(i / 4095.0, 1.0 / 2.2));
 }
 //
 //
 //
 if(format.opp == 4)
  GetBlitLineFunction<uint32, false>(mode, sharp, &BlitLineBitBuffer);
 else
 {
  if(format.Gprec == 5)
   GetBlitLineFunction<uint16, true>(mode, sharp, &BlitLineBitBuffer);
  else
   GetBlitLineFunction<uint16, false>(mode, sharp, &BlitLineBitBuffer);
 }

 if(mode != Settings::MODE_COMPOSITE)
 {
  if(CustomPalette && (CustomPaletteNumEntries == 16 || CustomPaletteNumEntries == 32))
  {
   for(unsigned i = 0; i < 16; i++)
   {
    RGBLUT[i] = format.MakeColor(CustomPalette[i * 3 + 0], CustomPalette[i * 3 + 1], CustomPalette[i * 3 + 2]);
    //
    uint32 tfr_pix = format.MakeColor(CustomPalette[i * 3 + 0] * 3 / 4, CustomPalette[i * 3 + 1] * 3 / 4, CustomPalette[i * 3 + 2] * 3 / 4);

    if(CustomPaletteNumEntries == 32)
     tfr_pix = format.MakeColor(CustomPalette[(16 + i) * 3 + 0], CustomPalette[(16 + i ) * 3 + 1], CustomPalette[(16 + i) * 3 + 2]);

    RGBLUT[16 + i] = tfr_pix;
   }

   RGBLUT[0x10] = RGBLUT[0x00];
   RGBLUT[0x1F] = RGBLUT[0x0F];

   BuildDHGRLUT();
   return;
  }
 }
 //
 //
 //
 const float (&d)[3][2] = *((s.matrix == Settings::MATRIX_CUSTOM) ? &s.custom_matrix : &matrixes[s.matrix]);
 float demod_tab[2][4];

 for(unsigned cd_i = 0; cd_i < 2; cd_i++)
 {
  static const float angles[2] = { 123.0, 33.0 };

  for(int x = 0; x < 4; x++)
  {
   demod_tab[cd_i][x] = sin(((x / 4.0) - s.hue / 8.0 + angles[cd_i] / 360.0) * (M_PI * 2.0));
   //printf("%d, %d, %f\n", cd_i, x, demod_tab[cd_i][x]);
  }
 }


 for(unsigned cbp = 0; cbp < 2; cbp++)
 {
  static const float coeffs[11][ColorLUT_NumPixels] =
  {
   /* -3 */ {  0.00172554, -0.00760881, -0.03068241, -0.01602947,  0.09901781,  0.27344111,  0.36027244,  0.27344111,  0.09901781, -0.01602947, -0.03068241, -0.00760881,  0.00172554, }, /* 1.000000 */
   /* -2 */ { -0.00085195, -0.00688802, -0.00964609,  0.02346799,  0.11669260,  0.23333631,  0.28777829,  0.23333631,  0.11669260,  0.02346799, -0.00964609, -0.00688802, -0.00085195, }, /* 1.000000 */
   /* -1 */ { -0.00666994, -0.01931400, -0.01700092,  0.03131011,  0.13104562,  0.23818615,  0.28488591,  0.23818615,  0.13104562,  0.03131011, -0.01700092, -0.01931400, -0.00666994, }, /* 1.000000 */
   /*  0 */ {  0.00000000,  0.00535462,  0.02579365,  0.06746032,  0.12500000,  0.17718506,  0.19841270,  0.17718506,  0.12500000,  0.06746032,  0.02579365,  0.00535462,  0.00000000, }, /* 1.000000 */
   /*  1 */ {  0.00000000,  0.00000000,  0.00957449,  0.04780242,  0.12137789,  0.20219758,  0.23809524,  0.20219758,  0.12137789,  0.04780242,  0.00957449,  0.00000000,  0.00000000, }, /* 1.000000 */
   /*  2 */ {  0.00000000,  0.00000000,  0.00000000,  0.01977578,  0.10119048,  0.23022422,  0.29761904,  0.23022422,  0.10119048,  0.01977578,  0.00000000,  0.00000000,  0.00000000, }, /* 1.000000 */
   /*  3 */ {  0.00000000,  0.00000000,  0.00000000,  0.01464626,  0.08312087,  0.23555925,  0.33334723,  0.23555925,  0.08312087,  0.01464626,  0.00000000,  0.00000000,  0.00000000, }, /* 1.000000 */
   /*  4 */ {  0.00000000,  0.00000000,  0.00000000,  0.00000000,  0.05158730,  0.25000000,  0.39682540,  0.25000000,  0.05158730,  0.00000000,  0.00000000,  0.00000000,  0.00000000, }, /* 1.000000 */
   /*  5 */ {  0.00000000,  0.00000000,  0.00000000,  0.00000000,  0.00000000,  0.25000000,  0.50000000,  0.25000000,  0.00000000,  0.00000000,  0.00000000,  0.00000000,  0.00000000, }, /* 1.000000 */
   /*  6 */ {  0.00000000,  0.00000000,  0.00000000,  0.00000000,  0.00000000,  0.16666667,  0.66666669,  0.16666667,  0.00000000,  0.00000000,  0.00000000,  0.00000000,  0.00000000, }, /* 1.000000 */
   /*  7 */ {  0.00000000,  0.00000000,  0.00000000,  0.00000000,  0.00000000,  0.00000000,  1.00000000,  0.00000000,  0.00000000,  0.00000000,  0.00000000,  0.00000000,  0.00000000, }, /* 1.000000 */
  };
  const bool mono_mode = !cbp || force_mono;
  static const float colordiff_coeffs[ColorLUT_NumPixels] = {  0.00329843,  0.01538324,  0.04024864,  0.07809234,  0.12141892,  0.15652442,  0.17006803,  0.15652442,  0.12141892,  0.07809234,  0.04024864,  0.01538324,  0.00329843  };
  const float (&luma_coeffs)[ColorLUT_NumPixels] = (mode != Settings::MODE_COMPOSITE) ? colordiff_coeffs : coeffs[3 + (mono_mode ? s.mono_lumafilter : s.color_lumafilter)];

#if 0
  for(unsigned ci = 0; ci < 11; ci++)
  {
   float sum = 0;

   printf("   /* % d */ { ", (int)ci - 3);

   for(unsigned i = 0; i < ColorLUT_NumPixels; i++)
   {
    assert(coeffs[ci][i] == coeffs[ci][ColorLUT_NumPixels - 1 - i]);
    sum += coeffs[ci][i];
    printf("% .8f, ", coeffs[ci][i]);
   }

   printf("}, /* %f */\n", sum);
  }
#endif

  for(unsigned phase = 0; phase < 4; phase++)
  {
   for(unsigned color = 0; color < (1U << ColorLUT_NumPixels); color++)
   {
    float y = 0;
    float color_diff[2] = { 0, 0 };

    for(unsigned i = 0; i < ColorLUT_NumPixels; i++)
     y += luma_coeffs[i] * ((color >> i) & 1);

    y = y * ((s.contrast * 0.50) + 1.0) + (s.brightness * 0.50);

    for(unsigned cd_i = 0; cd_i < 2; cd_i++)
    {
     for(unsigned i = 0; i < ColorLUT_NumPixels; i++)
     {
      float chroma = ((color >> i) & 1);

      color_diff[cd_i] += colordiff_coeffs[i] * demod_tab[cd_i][(i + phase) & 3] * chroma;
     }
     color_diff[cd_i] *= 1.0 + s.saturation;

     if(mono_mode)
      color_diff[cd_i] = 0;
    }

    unsigned rgb_cc[3];

    for(unsigned cc_i = 0; cc_i < 3; cc_i++)
    {
     float eff_y = y * (force_mono ? (((force_mono >> ((2 - cc_i) << 3)) & 0xFF) / 255.0) : 1.0);
     float t = std::max<float>(0.0, eff_y + d[cc_i][0] * color_diff[0] + d[cc_i][1] * color_diff[1]);

     //t = pow(t, d.power);

     //if(t > 1.10)
     // printf("phase=%d color=0x%08x cc_i=%u t=%f\n", phase, color, cc_i, t);

     rgb_cc[cc_i] = std::min<int>(1016, std::max<int>(0, floor(0.5 + 1016 * t)));
    }

    //printf("color 0x%01x: y=%f pb=%.13f pr=%.13f --- %3u %3u %3u\n", color, ySL2 / 4.0, pbSL6 / 64.0, prSL6 / 64.0, r, g, b);

    ColorLUT[cbp][phase][color] = (rgb_cc[0] << 0) + (rgb_cc[1] << 10) + (rgb_cc[2] << 20);
   }
  }
 }

 if(s.color_smooth && !force_mono)
 { 
  uint32 SmoothLUT[4][16];

  for(unsigned phase = 0; phase < 4; phase++)
  {
   for(unsigned color = 0; color < 16; color++)
   {
    float r = 0;
    float g = 0;
    float b = 0;
    int r_p, g_p, b_p;

    for(unsigned i = 0; i < 4; i++)
    {
     unsigned pattern = (color | (color << 4) | (color << 8) | (color << 12) | (color << 16)) >> (4 + i - phase);
     uint32 cle = ColorLUT[1][(i) & 3][pattern & 0x1FFF];

     r_p = (cle >> 0) & 0x3FF;
     g_p = (cle >> 10) & 0x3FF;
     b_p = (cle >> 20) & 0x3FF;

     r += pow(r_p / 1016.0, 2.2);
     g += pow(g_p / 1016.0, 2.2);
     b += pow(b_p / 1016.0, 2.2);
    }

    r /= 4;
    g /= 4;
    b /= 4;

    r_p = std::min<int>(1016, floor(0.5 + 1016 * pow(r, 1.0 / 2.2)));
    g_p = std::min<int>(1016, floor(0.5 + 1016 * pow(g, 1.0 / 2.2)));
    b_p = std::min<int>(1016, floor(0.5 + 1016 * pow(b, 1.0 / 2.2)));

    //printf("Phase: %d, Color: %d - 0x%02x 0x%02x 0x%02x\n", phase, color, r_p, g_p, b_p);

    SmoothLUT[phase][color] = (r_p << 0) + (g_p << 10) + (b_p << 20);
   }
  }

  for(unsigned phase = 0; phase < 4; phase++)
  {
   for(unsigned color = 0; color < (1U << ColorLUT_NumPixels); color++)
   {
    if(s.color_smooth == 1)
    {
     const unsigned c0 = (color >> 0) & 0x1F;
     const unsigned c1 = (color >> 4) & 0x1F;
     const unsigned c2 = (color >> 8) & 0x1F;

     if(c1 == c0 || c1 == c2 || (((color >> 2) & 0x7) == ((color >> 6) & 0x7) && ((color >> 3) & 0x7) == ((color >> 7) & 0x7)))
      ColorLUT[1][phase][color] = SmoothLUT[phase][c1 & 0xF];
    }
    else
    {
     // CBA9876543210
     //       ^
     unsigned c1;
     unsigned shift;

     if((shift = 1, c1 = ((color >> 1) & 0xF)) == ((color >> 5) & 0xF) ||
        (shift = 2, c1 = ((color >> 2) & 0xF)) == ((color >> 6) & 0xF) ||
        (shift = 3, c1 = ((color >> 3) & 0xF)) == ((color >> 7) & 0xF) ||
        (shift = 0, c1 = ((color >> 4) & 0xF)) == ((color >> 8) & 0xF))
      ColorLUT[1][phase][color] = SmoothLUT[phase][((c1 << shift) | (c1 >> (4 - shift))) & 0xF];
    }
   }
  }
 }

 if(mode != Settings::MODE_COMPOSITE)
 {
  const bool enable_gray_tweak = (mode == Settings::MODE_RGB_VIDEO7 || mode == Settings::MODE_RGB_QD || mode == Settings::MODE_RGB_QD_TFR);

  for(unsigned color = 0; color < 16; color++)
  {
   float r = 0;
   float g = 0;
   float b = 0;
   int r_p, g_p, b_p;

   for(unsigned i = 0; i < 4; i++)
   {
    unsigned pattern = (color | (color << 4) | (color << 8) | (color << 12) | (color << 16)) >> (4 + i);
    uint32 cle = ColorLUT[1][i & 3][pattern & 0x1FFF];

    r_p = (cle >> 0) & 0x3FF;
    g_p = (cle >> 10) & 0x3FF;
    b_p = (cle >> 20) & 0x3FF;

    r += pow(r_p / 1016.0, 2.2);
    g += pow(g_p / 1016.0, 2.2);
    b += pow(b_p / 1016.0, 2.2);
   }

   r /= 4;
   g /= 4;
   b /= 4;

   if(enable_gray_tweak && (color == 0x5 || color == 0xA))
   {
    float y = ((color == 0x5) ? 0.375 : 0.583);

    y = y * ((s.contrast * 0.50) + 1.0) + (s.brightness * 0.50);
    y = std::max<float>(0.0, y);

    r = g = b = pow(y, 2.2);
   }

   r_p = std::min<int>(255, floor(0.5 + 255 * pow(r, 1.0 / 2.2)));
   g_p = std::min<int>(255, floor(0.5 + 255 * pow(g, 1.0 / 2.2)));
   b_p = std::min<int>(255, floor(0.5 + 255 * pow(b, 1.0 / 2.2)));

   //printf("Phase: %d, Color: %d - 0x%02x 0x%02x 0x%02x\n", phase, color, r_p, g_p, b_p);

   RGBLUT[color] = format.MakeColor(r_p, g_p, b_p);
   RGBLUT[16 + color] = format.MakeColor(r_p  * 3 / 4, g_p * 3 / 4, b_p * 3 / 4);
  }
  RGBLUT[0x10] = RGBLUT[0x00];
  RGBLUT[0x1F] = RGBLUT[0x0F];
  //
  BuildDHGRLUT();
 }
}

//
//
}
}
