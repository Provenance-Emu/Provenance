/******************************************************************************/
/* Mednafen Apple II Emulation Module                                         */
/******************************************************************************/
/* video.inc:
**  Copyright (C) 2018-2019 Mednafen Team
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

/*
 TODO:	Colorburst detection delay.

	Y black expansion setting?  cutoff at 30 or 50 IRE?

	Sharpness setting?

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

namespace Video
{

enum { ColorLUT_NumPixels = 13 };
static uint32 ColorLUT[2][4][1U << ColorLUT_NumPixels];
static uint32 RGBLUT[16 * 2];
static MDFN_PixelFormat format;
static bool EnableMixedTextMonoHack;

static void (*BlitLineBitBuffer)(uint32* target);
template<bool tfr> static void BlitLineBitBuffer_RGB_Alt(uint32* target);
template<bool tfr> static void BlitLineBitBuffer_RGB(uint32* target);
static void BlitLineBitBuffer_Composite(uint32* target);

struct Settings
{
 float hue = 0.0;
 float saturation = 0.0;
 float contrast = 0.0;
 float brightness = 0.0;
 bool color_smooth = false;
 uint32 force_mono = 0x000000;
 bool mixed_text_mono = false;

 int mono_lumafilter = 5;
 int color_lumafilter = -3;

 enum
 {
  MODE_COMPOSITE = 0,
  MODE_RGB,
  MODE_RGB_TFR,

  MODE_RGB_ALT,
  MODE_RGB_ALT_TFR
 };

 unsigned mode = MODE_COMPOSITE;

 enum
 {
  MATRIX_MEDNAFEN = 0,

  MATRIX_LA7620,

  MATRIX_CXA2025_JAPAN,
  MATRIX_CXA2025_USA,

  MATRIX_CXA2060_JAPAN,
  MATRIX_CXA2060_USA,

  MATRIX_CXA2095_JAPAN,
  MATRIX_CXA2095_USA,
  //
  MATRIX_CUSTOM
 };

 unsigned matrix = MATRIX_CUSTOM;

 float custom_matrix[3][2];
};

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

static uint8 linebuffer[(560 + 24) / 8 + 4] = { 0 };
static MDFN_Surface* surface;
static MDFN_Rect surface_dr;
static bool colorburst_present;
static bool rgb_hires_latch;
static uint32 HCounter, VCounter;
static bool flashything;
static int32 flashycounter;
static bool HiresDelayBit = false;
static uint64 NoiseLCG;

static void Power(void)
{
 HCounter = 0;
 VCounter = 0xFA;
 flashything = false;
 flashycounter = 0;
 HiresDelayBit = false;
 NoiseLCG = 0;
}

template<bool tfr>
static void BlitLineBitBuffer_RGB_Alt(uint32* target)
{
 uint32 pdata = 0;

 if(!colorburst_present)
 {
  for(int x = 0; x < 584; x++)
  {
   pdata |= ((linebuffer[x >> 3] >> (x & 0x7)) & 1) << 12;
   //
   const bool C = (pdata & 1);
   target[x] = RGBLUT[C ? 15 : 0];
   //
   pdata >>= 1;
  }
 }
 else if(!rgb_hires_latch)
 {
  unsigned pat = 0;
  unsigned dc = 1;

  for(int x = 0; x < 584; x++)
  {
   unsigned phase = x & 3;
   bool nb = ((linebuffer[x >> 3] >> (x & 0x7)) & 1);

   pdata |= nb << 12;
   //
   dc++;
   if(dc == 14)
   {
    pat = (pdata >> 0) & 0xF;
    pat = ((pat << phase) | (pat >> (4 - phase))) & 0xF;
    dc = 0;
   }

   target[x] = RGBLUT[pat];
   //
   pdata >>= 1;
  }
 }
 else
 {
  unsigned pat = 0;
  unsigned bw = 0;
  unsigned cpd = 0;
  unsigned dc = 0;
  unsigned halve = 0;

  for(int x = 0; x < 584; x++)
  {
   unsigned phase = x & 3;
   bool nb = ((linebuffer[x >> 3] >> (x & 0x7)) & 1);

   pdata |= nb << 12;
   //
   if((pdata & 0x1FC) == 0x070)
    bw |= 0x070;

   if((pdata & 0xF00) == 0xF00)
    bw |= 0xF00;

   if((pdata & 0xF00) == 0x000)
    bw |= 0xF00;

   if(tfr)
   {
    if((pdata & 0xF3C) == 0xF3C)
     halve |= 0xC0; //bw |= 0xFFC;

    if((pdata & 0xF1E) == 0xF1E)
     halve |= 0xE0; //bw |= 0xFFE;
   }

   if((pdata & 0xF00) == 0x300) // && !(pdata & 0x400))
    dc = 0;
   else
    dc = (dc + 1) & 1;

   if(!dc)
   {
    cpd = (pdata >> 0) & 0xF;
    cpd = ((cpd << phase) | (cpd >> (4 - phase))) & 0xF;
   }

   if(bw & 0x01)
    pat = (pdata & 0x01) ? 15 : 0;
   else if(tfr)
    pat = ((halve & 0x1) << 4) + cpd;
   else if(1)
   {
    //pat = (pdata >> (ps & 1)) & 0xF;
    //pat = ((pat << phase) | (pat >> (4 - phase))) & 0xF;
    pat = cpd;
   }

   target[x] = RGBLUT[pat];
   //
   pdata >>= 1;
   bw >>= 1;
   if(tfr)
    halve >>= 1;
  }
 }
}

template<bool tfr>
static void BlitLineBitBuffer_RGB(uint32* target)
{
 for(int i = 0; i < 6; i++)
  *(target++) = RGBLUT[0];

 if(!colorburst_present)
 {
  for(int x = 0; x < 560; x += 2)
  {
   const bool C = (linebuffer[x >> 3] >> (x & 0x7)) & 1;
   target[x >> 1] = RGBLUT[C ? 15 : 0];
  }
  target += 560;
 }
 else if(!rgb_hires_latch)
 {
  for(int x = 0; x < 560; x += 14)
  {
   unsigned pat = (MDFN_de32lsb(&linebuffer[x >> 3]) >> (x & 0x7)) & 0xF;
   unsigned phase = x & 3;
   uint32 pix;

   pat = ((pat << phase) | (pat >> (4 - phase))) & 0xF;
   pix = RGBLUT[pat];

   for(int sx = 0; sx < 7; sx++)
    target[(x >> 1) + sx] = pix;
  }
  target += 560;
 }
 else
 {
  uint32 pdata = 0;
  uint32 pshift = 0;
  uint32 bw = 0;
  uint32 cpd = 0;
  uint32 halve = 0;

  for(int x = 0; x < 560 + 14; x += 14)
  {
   uint32 tmp = MDFN_de32lsb(&linebuffer[x >> 3]) >> (x & 0x7);

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
 }

 for(int i = 0; i < 6; i++)
  *(target++) = RGBLUT[0];
}

static void BlitLineBitBuffer_Composite(uint32* target)
{
 uint32 pdata = 0;
 const unsigned nb_pos = (ColorLUT_NumPixels - 1) + (12 - (ColorLUT_NumPixels / 2));
 const uint8 rs = format.Rshift;
 const uint8 gs = format.Gshift;
 const uint8 bs = format.Bshift;

 for(size_t x = 0; x < 584; x++)
 {
  uint32 c = ColorLUT[colorburst_present][(x ^ nb_pos) & 3][pdata & 0x1FFF];
  //
  pdata |= ((linebuffer[x >> 3] >> (x & 0x7)) & 1) << nb_pos;
  c += (NoiseLCG >> 32) & ((0x7 << 0) | (0x7 << 10) | (0x7 << 20));

  target[x] = (((c >> 2) & 0xFF) << rs) + (((c >> 12) & 0xFF) << gs) + (((c >> 22) & 0xFF) << bs);

  pdata >>= 1;
  NoiseLCG = (NoiseLCG * 6364136223846793005ULL) + 1442695040888963407ULL;
 }
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

static NO_INLINE void Tick(void)
{
 flashycounter -= 14;

 const bool text = (SoftSwitch & SOFTSWITCH_TEXT_MODE) || ((SoftSwitch & SOFTSWITCH_MIX_MODE) && (VCounter & 0xFF) >= 160);
 const bool hires = (SoftSwitch & SOFTSWITCH_HIRES_MODE);
 unsigned ram_addr;
 uint8 ram_data;

 ram_addr = ((0x68 + (HCounter & 0x3F) + ((VCounter >> 3) & 0x18) + ((VCounter >> 1) & 0x60)) & 0x7F) + (((VCounter >> 3) & 0x7) << 7);

 if(text || !hires)
 {
  ram_addr |= (HCounter < 0x58) << 12; // TODO: Disable this for IIe emulation
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
  DB = RAM48K[ram_addr];

 ram_data = DB;

 {
  static const uint8 tab[16] = { 0x00, 0x03, 0x0C, 0x0F, 0x30, 0x33, 0x3C, 0x3F, 0xC0, 0xC3, 0xCC, 0xCF, 0xF0, 0xF3, 0xFC, 0xFF };
  unsigned pixb = 0;

  if(text)
  {
   uint8 fd = FontData[((ram_data & 0x3F) << 3) | (VCounter & 0x7)];
   bool invert = !(ram_data & 0x80) & (!(ram_data & 0x40) | !flashything);

   if(invert)
    fd ^= 0x7F;

   pixb = tab[fd & 0xF] | (tab[(fd >> 4) & 0x7] << 8);
  }
  else
  {
   if(hires)
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
  }

  //if(!text && hires && HCounter == 0x57)
  // printf("%3d: 0x%04x %02x\n", VCounter, ram_addr, ram_data);

  if(HCounter >= 0x58)
  {
   const size_t po = (HCounter - 0x58) * 14;
   pixb &= 0x3FFF;
   MDFN_en32lsb(&linebuffer[po >> 3], (MDFN_de32lsb(&linebuffer[po >> 3]) & ~(0x3FFF << (po & 7))) | (pixb << (po & 7)));
  }
 }

 HCounter = ((HCounter | 0x40) + (HCounter >> 6)) & 0x7F;

 if(HCounter == 0)
 {
  timestamp += 2;
  flashycounter -= 2;
  //
  unsigned vis_vc = VCounter ^ 0x100;

  if(vis_vc < 192)
  {
#if 0
   for(int x = 0; x < 584; x++)
   {
    //unsigned color = (x / (4 * (1 + (vis_vc / 8)))) & 0xF;
    //unsigned color = (x & vis_vc & 8) ? ((x / 8) & 0xF) : ((x / 16) & 0xF);

    unsigned color = ((x / 4) & 1) ? ~0 : 0/*0xA*/;

    linebuffer[x >> 3] &= ~(1U << (x & 7));
    linebuffer[x >> 3] |= ((color >> (x & 3)) & 1) << (x & 7);
   }
#endif

   BlitLineBitBuffer(surface->pixels + vis_vc * surface->pitchinpix);
  }
  //
  VCounter = (VCounter + 1) & 0x1FF;
  if(VCounter == 0x1C0)
  {
   FramePartialDone = true;
   FrameDone = true;
  }
  else if(VCounter == 0x13D)
  {
   FramePartialDone = true;
  }
  else if(!VCounter)
  {
   VCounter = 0xFA;
  }
 }
 else if(HCounter == 0x40)
 {
  colorburst_present = !(SoftSwitch & SOFTSWITCH_TEXT_MODE);

  if(text && EnableMixedTextMonoHack)
   colorburst_present = false;

  rgb_hires_latch = hires && !text;
 }

 if(flashycounter <= 0)
 {
  flashything = !flashything;
  flashycounter += flashything ? 3286338 : 3274425;
 }
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

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "VIDEO");

 if(load)
 {

 }
}

static INLINE void Init(void)
{
#if 0
 //double alpha = 4.554298;
 //double tb_center = 0.132957;

 for(double alpha = 4.5; alpha < 8.0; alpha *= 1.001)
 {
  double tbcenter_max = 0;
  double tbcenter_max_coeffs[13];

  for(double tb_center = 0.10; tb_center <= 0.2; tb_center *= 1.001)
  {
   bool ok = true;
   double coeffs[13];

   DSPUtility::generate_kaiser_sinc_lp(coeffs, 13, tb_center, alpha);
   DSPUtility::normalize(coeffs, 13, 1.0);

   for(int pat = 0x0; pat < 0x10; pat++)
   {
    double sum = 0;
    double expected = 255.0 * ((bool)(pat & 1) + (bool)(pat & 2) + (bool)(pat & 4) + (bool)(pat & 8)) / 4.0;

    for(int i = 0; i < 13; i++)
     sum += coeffs[i] * ((pat >> (i & 3)) & 1);

    if(fabs(255.0 * sum - expected) >= ((pat == 0x5 || pat == 0xA) ? 0.10 : 0.50))
     ok = false;
   }

   if(ok && tb_center > tbcenter_max)
   {
    tbcenter_max = tb_center;
    memcpy(tbcenter_max_coeffs, coeffs, sizeof(coeffs));
   }
  }

  if(tbcenter_max)
  {
   printf("alpha: %f, tb_center: %f\n", alpha, tbcenter_max);
   printf("  { ");
   for(int i = 0; i < 13; i++)
    printf("% .8f, ", tbcenter_max_coeffs[i]);
   printf(" },\n");
  }
 }
 //abort();
#endif
}

static INLINE void Kill(void)
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

// tint, saturation, -1.0 to 1.0
static INLINE void SetFormat(const MDFN_PixelFormat& f, const Settings& s, uint8* CustomPalette, uint32 CustomPaletteNumEntries)
{
 int mode = s.mode;

 if(CustomPalette && CustomPaletteNumEntries)
 {
  if(mode == Settings::MODE_COMPOSITE)
   mode = (CustomPaletteNumEntries == 32) ? Settings::MODE_RGB_TFR : Settings::MODE_RGB;
  else if(mode == Settings::MODE_RGB && CustomPaletteNumEntries == 32)
   mode = Settings::MODE_RGB_TFR;
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
 surface_dr.w = (560 + 12*2) >> (mode == Settings::MODE_RGB || mode == Settings::MODE_RGB_TFR); 
 surface_dr.h = 192;
 //
 //
 //
 if(mode == Settings::MODE_COMPOSITE)
  BlitLineBitBuffer = BlitLineBitBuffer_Composite;
 else
 {
  if(mode == Settings::MODE_RGB_ALT_TFR)
   BlitLineBitBuffer = BlitLineBitBuffer_RGB_Alt<true>;
  else if(mode == Settings::MODE_RGB_ALT)
   BlitLineBitBuffer = BlitLineBitBuffer_RGB_Alt<false>;
  else if(mode == Settings::MODE_RGB_TFR)
   BlitLineBitBuffer = BlitLineBitBuffer_RGB<true>;
  else if(mode == Settings::MODE_RGB)
   BlitLineBitBuffer = BlitLineBitBuffer_RGB<false>;

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

   return;
  }
 }
 //
 //
 //
 const uint32 force_mono = (mode != Settings::MODE_COMPOSITE) ? 0 : s.force_mono;
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
  const float (&luma_coeffs)[ColorLUT_NumPixels] = coeffs[3 + (mono_mode ? s.mono_lumafilter : s.color_lumafilter)];

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
    const unsigned c0 = (color >> 0) & 0x1F;
    const unsigned c1 = (color >> 4) & 0x1F;
    const unsigned c2 = (color >> 8) & 0x1F;

    if(c1 == c0 || c1 == c2 || (((color >> 2) & 0x7) == ((color >> 6) & 0x7) && ((color >> 3) & 0x7) == ((color >> 7) & 0x7)))
     ColorLUT[1][phase][color] = SmoothLUT[phase][c1 & 0xF];
   }
  }
 }

 if(mode != Settings::MODE_COMPOSITE)
 {
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

   r_p = std::min<int>(255, floor(0.5 + 255 * pow(r, 1.0 / 2.2)));
   g_p = std::min<int>(255, floor(0.5 + 255 * pow(g, 1.0 / 2.2)));
   b_p = std::min<int>(255, floor(0.5 + 255 * pow(b, 1.0 / 2.2)));

   //printf("Phase: %d, Color: %d - 0x%02x 0x%02x 0x%02x\n", phase, color, r_p, g_p, b_p);

   RGBLUT[color] = format.MakeColor(r_p, g_p, b_p);
   RGBLUT[16 + color] = format.MakeColor(r_p  * 3 / 4, g_p * 3 / 4, b_p * 3 / 4);
  }
 }
}

}
