// VisualBoyAdvance - Nintendo Gameboy/GameboyAdvance (TM) emulator.
// Copyright (C) 1999-2003 Forgotten
// Copyright (C) 2004 Forgotten and the VBA development team

// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2, or(at your option)
// any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software Foundation,
// Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

#include <mednafen/mednafen.h>
#include <mednafen/file.h>
#include <mednafen/general.h>
#include <mednafen/state.h>
#include <mednafen/mempatcher.h>
#include <mednafen/hash/md5.h>
#include <mednafen/FileStream.h>

#include <string.h>
#include <zlib.h>
#include <math.h>

#include <algorithm>

#include "gb.h"
#include "gbGlobals.h"
#include "memory.h"
#include "sound.h"
#include "z80.h"

namespace MDFN_IEN_GB
{

static void Cleanup(void) MDFN_COLD;

static uint32 *gbColorFilter = NULL;
static uint32 gbMonoColorMap[12 + 1];	// Mono color map(+1 = LCD off color)!

static void LoadROM(MDFNFILE *fp);
static int32 SoundTS = 0;
//extern uint16 gbLineMix[160];
extern union __gblmt
{
 uint16 cgb[160];
 uint8 dmg[160];
 uint32 dmg_32[40];
} gbLineMix;

// mappers
void (*mapper)(uint16,uint8) = NULL;
void (*mapperRAM)(uint16,uint8) = NULL;
uint8 (*mapperReadRAM)(uint16) = NULL;

static uint8 HRAM[0x80];
uint8 gbOAM[0xA0];

// 0xff00
static uint8 register_P1    = 0;

// 0xff01
static uint8 register_SB    = 0;
// 0xff02
uint8 register_SC    = 0;
// 0xff04
uint8 register_DIV   = 0;
// 0xff05
static uint8 register_TIMA  = 0;
// 0xff06
static uint8 register_TMA   = 0;
// 0xff07
static uint8 register_TAC   = 0;
// 0xff0f
uint8 register_IF    = 0;
// 0xff40
uint8 register_LCDC  = 0;
// 0xff41
static uint8 register_STAT  = 0;
// 0xff42
uint8 register_SCY   = 0;
// 0xff43
uint8 register_SCX   = 0;
// 0xff44
uint8 register_LY    = 0;
// 0xff45
uint8 register_LYC   = 0;
// 0xff46
uint8 register_DMA   = 0;
// 0xff4a
uint8 register_WY    = 0;
// 0xff4b
uint8 register_WX    = 0;
// 0xff4d
uint8 register_KEY1  = 0;
// 0xff4f
uint8 register_VBK   = 0;
// 0xff51
static uint8 register_HDMA1 = 0;
// 0xff52
static uint8 register_HDMA2 = 0;
// 0xff53
static uint8 register_HDMA3 = 0;
// 0xff54
static uint8 register_HDMA4 = 0;
// 0xff55
static uint8 register_HDMA5 = 0;

// 0xff56
static uint8 register_RP = 0;

// 0xff68
static uint8 register_BCPS = 0;
// 0xff69
static uint8 register_BCPD = 0;
// 0xff6a
static uint8 register_OCPS = 0;
// 0xff6b
static uint8 register_OCPD = 0;

// 0xff6c
static uint8 register_FF6C = 0;
// 0xff72
static uint8 register_FF72 = 0;
// 0xff73
static uint8 register_FF73 = 0;
// 0xff74
static uint8 register_FF74 = 0;
// 0xff75
static uint8 register_FF75 = 0;

// 0xff70
static uint8 register_SVBK  = 0;
// 0xffff
uint8 register_IE    = 0;

// ticks definition
static int GBDIV_CLOCK_TICKS          = 64;
static int GBLCD_MODE_0_CLOCK_TICKS   = 51;
static int GBLCD_MODE_1_CLOCK_TICKS   = 1140;
static int GBLCD_MODE_2_CLOCK_TICKS   = 20;
static int GBLCD_MODE_3_CLOCK_TICKS   = 43;
static int GBLY_INCREMENT_CLOCK_TICKS = 114;
static int GBTIMER_MODE_0_CLOCK_TICKS = 256;
static int GBTIMER_MODE_1_CLOCK_TICKS = 4;
static int GBTIMER_MODE_2_CLOCK_TICKS = 16;
static int GBTIMER_MODE_3_CLOCK_TICKS = 64;
static int GBSERIAL_CLOCK_TICKS       = 128;
static int GBSYNCHRONIZE_CLOCK_TICKS  = 52920;

// state variables
static int32 snooze;
static int32 PadInterruptDelay;

// serial
static int gbSerialOn;
static int gbSerialTicks;
static int gbSerialBits;
// timer
static int gbTimerOn;
static int gbTimerTicks;
static int gbTimerClockTicks;
static int gbTimerMode;


enum
{
 GBLCDM_HBLANK = 0,
 GBLCDM_VBLANK = 1,
 GBLCDM_OAM = 2,
 GBLCDM_OAM_VRAM = 3,
};

// lcd
int gbLcdMode = GBLCDM_OAM;
int gbLcdTicks = GBLCD_MODE_2_CLOCK_TICKS;
int gbLcdLYIncrementTicks = 0;
// div
int gbDivTicks = GBDIV_CLOCK_TICKS;
// cgb
int gbWramBank = 1;
int gbHdmaSource = 0x0000;
int gbHdmaDestination = 0x8000;
int gbHdmaBytes = 0x0000;
int gbHdmaOn = 0;
int gbSpeed = 0;

// timing
int gbSynchronizeTicks = GBSYNCHRONIZE_CLOCK_TICKS;

// emulator features
int gbBattery = 0;

static uint8 gbJoymask;

static const int gbRomSizes[] = { 0x00008000, // 32K
                     0x00010000, // 64K
                     0x00020000, // 128K
                     0x00040000, // 256K
                     0x00080000, // 512K
                     0x00100000, // 1024K
                     0x00200000, // 2048K
                     0x00400000, // 4096K
                     0x00800000  // 8192K
};

static const int gbRomSizesMasks[] = { 0x00007fff,
                          0x0000ffff,
                          0x0001ffff,
                          0x0003ffff,
                          0x0007ffff,
                          0x000fffff,
                          0x001fffff,
                          0x003fffff,
                          0x007fffff
};

static const int gbRamSizes[6] = { 0x00000000, // 0K
                      0x00000800, // 2K
                      0x00002000, // 8K
                      0x00008000, // 32K
                      0x00020000, // 128K
                      0x00010000  // 64K
};

static const int gbRamSizesMasks[6] = { 0x00000000,
                           0x000007ff,
                           0x00001fff,
                           0x00007fff,
                           0x0001ffff,
                           0x0000ffff
};

static MDFN_PaletteEntry PalTest[256];

static bool MatchExists(MDFN_PaletteEntry *pt, unsigned n, const MDFN_PaletteEntry& pe)
{
 for(unsigned x = 0; x < n; x++)
 {
  if(pt[x].r == pe.r && pt[x].g == pe.g && pt[x].b == pe.b)
   return(true);
 }
 return(false);
}

class MDFN_PaletteMapper8
{
 public:

 MDFN_PaletteMapper8(MDFN_PaletteEntry *pal);

 uint8 FindClose(const MDFN_PaletteEntry& pe);

 private:

 int rcl[256];
 int gcl[256];
 int bcl[256];
 int ccp_to_ccl[256];
};

MDFN_PaletteMapper8::MDFN_PaletteMapper8(MDFN_PaletteEntry *pal)
{
 for(unsigned i = 0; i < 256; i++)
 {
  ccp_to_ccl[i] = 65536U * pow((double)i / 255, 2.2 / 1.0);
 }

 for(unsigned i = 0; i < 256; i++)
 {
  rcl[i] = ccp_to_ccl[pal[i].r];
  gcl[i] = ccp_to_ccl[pal[i].g];
  bcl[i] = ccp_to_ccl[pal[i].b];
 }
}

uint8 MDFN_PaletteMapper8::FindClose(const MDFN_PaletteEntry& pe)
{
 int rl, gl, bl;
 int closest = -1;
 int closest_cs = 0x7FFFFFFF;

 rl = ccp_to_ccl[pe.r];
 gl = ccp_to_ccl[pe.g];
 bl = ccp_to_ccl[pe.b];

 for(unsigned x = 0; x < 256; x++)
 {
  int cs;

  cs = abs(rcl[x] - rl) * 2126 + abs(gcl[x] - gl) * 7152 + abs(bcl[x] - bl) * 722;
  if(cs < closest_cs)
  {
   closest_cs = cs;
   closest = x;
  }
 }

 return(closest);
}


static void SetPixelFormat(const MDFN_PixelFormat &format, bool cgb_mode, const uint8* CustomColorMap, const uint32 CustomColorMapNE) MDFN_COLD;
static void SetPixelFormat(const MDFN_PixelFormat &format, bool cgb_mode, const uint8* CustomColorMap, const uint32 CustomColorMapNE)
{
 if(cgb_mode)
 {
  if(format.bpp == 8)
  {
   unsigned pti = 0;

   memset(PalTest, 0, sizeof(PalTest));

   for(int i = 0; i < 8; i++)
   {
    PalTest[pti++] = format.MakePColor(i * 36, i * 36, i * 36);

    if(i)
    {
     PalTest[pti++] = format.MakePColor(i * 36, 0, 0);
     PalTest[pti++] = format.MakePColor(0, i * 36, 0);
     PalTest[pti++] = format.MakePColor(0, 0, i * 36);
     PalTest[pti++] = format.MakePColor(i * 36, i * 36, 0);
     PalTest[pti++] = format.MakePColor(i * 36, 0, i * 36);
     PalTest[pti++] = format.MakePColor(0, i * 36, i * 36);
    }
   }

   for(int r = 0; r < 8; r++)
   {
    for(int g = 0; g < 8; g++)
    {
     for(int b = 0; b < 8; b++)
     {
      if(MatchExists(PalTest, 256, format.MakePColor(r * 36, g * 36, b * 36)))
       continue;

      if(g == 6 && b == 6 && r == 5)
       goto SkipStuff;

      if(g == 6 && b == 3 && r == 5)
       goto SkipStuff;

      if(g == 4 && b == 5 && r == 3)
       goto SkipStuff;

      if(!(b & 1))
       continue;

      if(g == (r + 1))
       continue;

      //if(g == 7 && r >= 4 && b < 4)
      // continue;

      if(g == (r + 3) && b >= 5)
       continue;

      SkipStuff:;

      PalTest[pti++] = format.MakePColor(r * 36, g * 36, b * 36);

      if(pti == 256) goto EndThingy;
     }
    }
   }
   EndThingy:;
   //printf("ZOOMBA: %u\n", pti);
   //exit(1);
  }

  MDFN_PaletteMapper8 pm8(PalTest);

  for(int r = 0; r < 32; r++)
  {
   for(int g = 0; g < 32; g++)
   {
    for(int b = 0; b < 32; b++)
    {
     int nr = r * 226 + g * 29 + b * 0;
     int ng = r * 29 + g * 197 + b * 29;
     int nb = r * 30 + g * 73 + b * 152;

     nr /= 31;
     ng /= 31;
     nb /= 31;

     if(CustomColorMap)
     {
      nr = CustomColorMap[((b << 10) | (g << 5) | r) * 3 + 0];
      ng = CustomColorMap[((b << 10) | (g << 5) | r) * 3 + 1];
      nb = CustomColorMap[((b << 10) | (g << 5) | r) * 3 + 2];
     }

     if(format.bpp == 8)
      gbColorFilter[(b << 10) | (g << 5) | r] = pm8.FindClose(format.MakePColor(nr, ng, nb));
     else
      gbColorFilter[(b << 10) | (g << 5) | r] = format.MakeColor(nr, ng, nb);
    }
   }
  }
 }
 else
 {
  for(int i = 0; i < 12; i++)
  {
   int r, g, b;

   r = (3 - (i & 3)) * 48 + 32;
   g = (3 - (i & 3)) * 48 + 32;
   b = (3 - (i & 3)) * 48 + 32;

   if(CustomColorMap)
   {
    unsigned ci = i;

    if(CustomColorMapNE == 4)
     ci %= 4;
    else if(CustomColorMapNE == 8)
     ci = (ci & 0x7) | ((ci & 0x8) >> 1);

    r = CustomColorMap[ci * 3 + 0];
    g = CustomColorMap[ci * 3 + 1];
    b = CustomColorMap[ci * 3 + 2];
   }

   gbMonoColorMap[i] = format.MakeColor(r, g, b);
   PalTest[i] = format.MakePColor(r, g, b);
  }

  gbMonoColorMap[12] = gbMonoColorMap[0];
  PalTest[12] = PalTest[0];
 }
}

#if 0
   if(num_read == 4 * 3)
   {
    for(unsigned i = 4 * 3; i < 12 * 3; i++)
    {
     (*ptr)[i] = (*ptr)[i % (4 * 3)];
    }
   }
   else if(num_read == 8 * 3)
   {
    for(unsigned i = 8 * 3; i < 12 * 3; i++)
     (*ptr)[i] = (*ptr)[(4 * 3) + (i % (4 * 3))];
   }
#endif

static void gbCopyMemory(uint16 d, uint16 s, int count)
{
  while(count) 
  {
    gbWriteMemory(d, gbReadMemory(s));
    s++;
    d++;
    count--;
  }
}

static void gbDoHdma()
{
  gbCopyMemory(gbHdmaDestination,
               gbHdmaSource,
               0x10);
  
  gbHdmaDestination += 0x10;
  gbHdmaSource += 0x10;
  
  register_HDMA2 += 0x10;
  if(register_HDMA2 == 0x00)
    register_HDMA1++;
  
  register_HDMA4 += 0x10;
  if(register_HDMA4 == 0x00)
    register_HDMA3++;
  
  gbHdmaBytes -= 0x10;
  register_HDMA5--;
  if(register_HDMA5 == 0xff)
    gbHdmaOn = 0;
}

// fix for Harley and Lego Racers
static void gbCompareLYToLYC()
{
 if(register_LY == register_LYC) 
 {
  // mark that we have a match
  register_STAT |= 4;
    
  // check if we need an interrupt
  if(register_STAT & 0x40)
   register_IF |= 2;
 }
 else // no match
  register_STAT &= 0xfb;
}

static void ClockTIMA(void)
{
 register_TIMA++;

 if(register_TIMA == 0) 
 {
  // timer overflow!

  // reload timer modulo
  register_TIMA = register_TMA;

  // flag interrupt
  register_IF |= 4;
 }
}

void gbWriteMemory(uint16 address, uint8 value)
{
  if(address < 0x8000) {
    if(mapper)
      (*mapper)(address, value);
    return;
  }
   
  if(address < 0xa000) {
    gbMemoryMap[address>>12][address&0x0fff] = value;
    return;
  }
  
  if(address < 0xc000) 
  {
    if(mapper)
      (*mapperRAM)(address, value);
    return;
  }
  
  if(address < 0xfe00) {
     unsigned int page = (address >> 12);
     if(page >= 0xE) page -= 2;
    gbMemoryMap[page][address & 0x0fff] = value;
    return;
  }
  
  if(address < 0xff00) {
    if(address < 0xFEA0)
     gbOAM[address & 0xFF] = value;
    return;
  }
  //printf("Write: %04x %02x, %d\n", address, value, register_LY);
  switch(address & 0x00ff) 
  {
   case 0x00:
    register_P1 = ((register_P1 & 0xcf) | (value & 0x30));
    return;

  case 0x01: {
    register_SB = value;
    return;
  }
    
  // serial control
  case 0x02: {
    gbSerialOn = (value & 0x80);
    register_SC = value;    
    if(gbSerialOn) {
      gbSerialTicks = GBSERIAL_CLOCK_TICKS;
#ifdef LINK_EMULATION
      if(linkConnected) {
        if(value & 1) {
          linkSendByte(0x100|register_SB);
          Sleep(5);
        }
      }
#endif
    }

    gbSerialBits = 0;
    return;
  }
  
  // DIV register resets on any write
  case 0x04: {
    register_DIV = 0;
    gbDivTicks = GBDIV_CLOCK_TICKS;
    // Another weird timer 'bug' :
    // Writing to DIV register resets the internal timer,
    // and can also increase TIMA/trigger an interrupt
    // in some cases...
    //if (gbTimerOn && !(gbInternalTimer & (gbTimerClockTicks>>1)))
    //{
    // ClockTIMA();
    //}
    return;
  }
  case 0x05:
    register_TIMA = value;
    return;

  case 0x06:
    register_TMA = value;
    return;
    
    // TIMER control
  case 0x07: {
    register_TAC = value;
    gbTimerOn = (value & 4);
    gbTimerMode = value & 3;
    //    register_TIMA = register_TMA;
    switch(gbTimerMode) {
    case 0:
      gbTimerClockTicks = gbTimerTicks = GBTIMER_MODE_0_CLOCK_TICKS;
      break;
    case 1:
      gbTimerClockTicks = gbTimerTicks = GBTIMER_MODE_1_CLOCK_TICKS;
      break;
    case 2:
      gbTimerClockTicks = gbTimerTicks = GBTIMER_MODE_2_CLOCK_TICKS;
      break;
    case 3:
      gbTimerClockTicks = gbTimerTicks = GBTIMER_MODE_3_CLOCK_TICKS;
      break;
    }
    return;
  }

  case 0x0f: 
  {
    register_IF = value;
    return;
  }
  
  
  case 0x10: case 0x11: case 0x12: case 0x13: case 0x14: case 0x15: case 0x16: case 0x17:
  case 0x18: case 0x19: case 0x1a: case 0x1b: case 0x1c: case 0x1d: case 0x1e: case 0x1f:
  case 0x20: case 0x21: case 0x22: case 0x23: case 0x24: case 0x25: case 0x26: case 0x27:
  case 0x28: case 0x29: case 0x2a: case 0x2b: case 0x2c: case 0x2d: case 0x2e: case 0x2f:
  case 0x30: case 0x31: case 0x32: case 0x33: case 0x34: case 0x35: case 0x36: case 0x37:
  case 0x38: case 0x39: case 0x3a: case 0x3b: case 0x3c: case 0x3d: case 0x3e: case 0x3f:
  {
    SOUND_Write(SoundTS, address, value);
    return;
  }
  case 0x40: {
    int lcdChange = (register_LCDC & 0x80) ^ (value & 0x80);

    if(lcdChange) {
      if(value & 0x80) {
        gbLcdTicks = GBLCD_MODE_1_CLOCK_TICKS;
        gbLcdMode = GBLCDM_HBLANK;
        register_STAT &= 0xfc;
        register_LY = 0x00;
      } else {
        gbLcdTicks = 0;
        gbLcdMode = GBLCDM_HBLANK;
        register_STAT &= 0xfc;
        register_LY = 0x00;
      }
      //      compareLYToLYC();
    }
    // don't draw the window if it was not enabled and not being drawn before
    if(!(register_LCDC & 0x20) && (value & 0x20) && gbWindowLine == -1 &&
       register_LY > register_WY)
      gbWindowLine = 144;

    register_LCDC = value;

    return;
  }

  // STAT
  case 0x41: {
    //register_STAT = (register_STAT & 0x87) |
    //      (value & 0x7c);
    register_STAT = (value & 0xf8) | (register_STAT & 0x07); // fix ?
    // GB bug from Devrs FAQ
    if(!gbCgbMode && (register_LCDC & 0x80) && gbLcdMode < 2)
      register_IF |= 2;
    return;
  }

  // SCY
  case 0x42: {
    register_SCY = value;
    return;
  }
  
  // SCX
  case 0x43: {
    register_SCX = value;
    return;
  }
  
  // LY
  case 0x44: {
    // read only
    return;
  }

  // LYC
  case 0x45: {
    register_LYC = value;
    if((register_LCDC & 0x80)) {
      gbCompareLYToLYC();
    }
    return;
  }
  
  // DMA!
  case 0x46: {
    int source = value * 0x0100;

    gbCopyMemory(0xfe00,
                 source,
                 0xa0);
    register_DMA = value;
    return;
  }
  
  // BGP
  case 0x47: {
    gbBgp[0] = value & 0x03;
    gbBgp[1] = (value & 0x0c)>>2;
    gbBgp[2] = (value & 0x30)>>4;
    gbBgp[3] = (value & 0xc0)>>6;
    return;
  }
  
  // OBP0
  case 0x48: {
    gbObp0[0] = 4 | (value & 0x03);
    gbObp0[1] = 4 | ((value & 0x0c)>>2);
    gbObp0[2] = 4 | ((value & 0x30)>>4);
    gbObp0[3] = 4 | ((value & 0xc0)>>6);
    return;
  }

  // OBP1
  case 0x49: {
    gbObp1[0] = 8 | (value & 0x03);
    gbObp1[1] = 8 | ((value & 0x0c)>>2);
    gbObp1[2] = 8 | ((value & 0x30)>>4);
    gbObp1[3] = 8 | ((value & 0xc0)>>6);
    return;
  }

  case 0x4a:
    register_WY = value;
    return;
    
  case 0x4b:
    register_WX = value;
    return;
  
    // KEY1
  case 0x4d: {
    if(gbCgbMode) {
      register_KEY1 = (register_KEY1 & 0x80) | (value & 1);
      return;
    }
  }
  break;
    
  // VBK
  case 0x4f: {
    if(gbCgbMode) {
      value = value & 1;
      
      unsigned vramAddress = value * 0x2000;
      gbMemoryMap[0x08] = &gbVram[vramAddress];
      gbMemoryMap[0x09] = &gbVram[vramAddress + 0x1000];
      
      register_VBK = value;
    }
    return;
  }
  break;

  // HDMA1
  case 0x51: {
    if(gbCgbMode) {
      if(value > 0x7f && value < 0xa0)
        value = 0;
      
      gbHdmaSource = (value << 8) | (register_HDMA2 & 0xf0);
      
      register_HDMA1 = value;
      return;
    }
  }
  break;
  
  // HDMA2
  case 0x52: {
    if(gbCgbMode) {
      value = value & 0xf0;
      
      gbHdmaSource = (register_HDMA1 << 8) | (value);
      
      register_HDMA2 = value;
      return;
    }
  }
  break;

  // HDMA3
  case 0x53: {
    if(gbCgbMode) {
      value = value & 0x1f;
      gbHdmaDestination = (value << 8) | (register_HDMA4 & 0xf0);
      gbHdmaDestination += 0x8000;
      register_HDMA3 = value;
      return;
    }
  }
  break;
  
  // HDMA4
  case 0x54: {
    if(gbCgbMode) {
      value = value & 0xf0;
      gbHdmaDestination = ((register_HDMA3 & 0x1f) << 8) | value;
      gbHdmaDestination += 0x8000;
      register_HDMA4 = value;
      return;
    }
  }
  break;
  
  // HDMA5
  case 0x55: {
    if(gbCgbMode) {
      gbHdmaBytes = 16 + (value & 0x7f) * 16;
      if(gbHdmaOn) {
        if(value & 0x80) {
          register_HDMA5 = (value & 0x7f);
        } else {
          register_HDMA5 = 0xff;
          gbHdmaOn = 0;
        }
      } else {
        if(value & 0x80) {
          gbHdmaOn = 1;
          register_HDMA5 = value & 0x7f;
          if(gbLcdMode == GBLCDM_HBLANK)
            gbDoHdma();
        } else {
          // we need to take the time it takes to complete the transfer into
          // account... according to GB DEV FAQs, the setup time is the same
          // for single and double speed, but the actual transfer takes the
          // same time
          //if(gbSpeed)
          //  gbDmaTicks = 231 + 16 * (value & 0x7f);
          //else
          //  gbDmaTicks = 231 + 8 * (value & 0x7f);
	  gbDmaTicks = 231;
          gbCopyMemory(gbHdmaDestination,
                       gbHdmaSource,
                       gbHdmaBytes);
          gbHdmaDestination += gbHdmaBytes;
          gbHdmaSource += gbHdmaBytes;
          
          register_HDMA3 = ((gbHdmaDestination - 0x8000) >> 8) & 0x1f;
          register_HDMA4 = gbHdmaDestination & 0xf0;
          register_HDMA1 = (gbHdmaSource >> 8) & 0xff;
          register_HDMA2 = gbHdmaSource & 0xf0;
        }
      }
      return;
    }
  }
  break;
  
  
  case 0x56:
   	register_RP = value & 0xC1;
	break;

  // BCPS
  case 0x68: {
     if(gbCgbMode) {
      int paletteIndex = (value & 0x3f) >> 1;
      int paletteHiLo   = (value & 0x01);
      
      register_BCPS = value;
      register_BCPD = (paletteHiLo ?
                        (gbPalette[paletteIndex] >> 8) :
                        (gbPalette[paletteIndex] & 0x00ff));
      return;
    }
  }
  break;
  
  // BCPD
  case 0x69: {
    if(gbCgbMode) {
      int v = register_BCPS;
      int paletteIndex = (v & 0x3f) >> 1;
      int paletteHiLo  = (v & 0x01);
      register_BCPD = value;
      gbPalette[paletteIndex] = (paletteHiLo ?
                                 ((value << 8) | (gbPalette[paletteIndex] & 0xff)) :
                                 ((gbPalette[paletteIndex] & 0xff00) | (value))) & 0x7fff;
                                        
      if(register_BCPS & 0x80) {
        int index = ((register_BCPS & 0x3f) + 1) & 0x3f;
        
        register_BCPS = (register_BCPS & 0x80) | index;
        
        register_BCPD = (index & 1 ?
                          (gbPalette[index>>1] >> 8) :
                          (gbPalette[index>>1] & 0x00ff));
        
      }
      return;
    }
  }
  break;
  
  // OCPS 
  case 0x6a: {
    if(gbCgbMode) {
      int paletteIndex = (value & 0x3f) >> 1;
      int paletteHiLo   = (value & 0x01);
      
      paletteIndex += 32;
      
      register_OCPS = value;
      register_OCPD = (paletteHiLo ?
                        (gbPalette[paletteIndex] >> 8) :
                        (gbPalette[paletteIndex] & 0x00ff));
      return;
    }
  }
  break;
  
  // OCPD
  case 0x6b: {
    if(gbCgbMode) {
      int v = register_OCPS;
      int paletteIndex = (v & 0x3f) >> 1;
      int paletteHiLo  = (v & 0x01);
      
      paletteIndex += 32;
      
      register_OCPD = value;
      gbPalette[paletteIndex] = (paletteHiLo ?
                                 ((value << 8) | (gbPalette[paletteIndex] & 0xff)) :
                                 ((gbPalette[paletteIndex] & 0xff00) | (value))) & 0x7fff;
      if(register_OCPS & 0x80) {
        int index = ((register_OCPS & 0x3f) + 1) & 0x3f;
        
        register_OCPS = (register_OCPS & 0x80) | index;
        
        register_OCPD = (index & 1 ?
                          (gbPalette[(index>>1) + 32] >> 8) :
                          (gbPalette[(index>>1) + 32] & 0x00ff));
        
      }      
      return;
    }
  }
  break;

  case 0x6c:
   register_FF6C = value & 1;
   break;
  
  // SVBK
  case 0x70: {
    if(gbCgbMode) {
      value = value & 7;

      int bank = value;
      if(value == 0)
        bank = 1;

      if(bank == gbWramBank)
        return;

      int wramAddress = bank * 0x1000;
      gbMemoryMap[0x0d] = &gbWram[wramAddress];

      MDFNMP_AddRAM(0x1000, 0xD000, &gbWram[wramAddress]);

      gbWramBank = bank;
      register_SVBK = value;
      return;
    }
  }
  break;

  case 0x80: case 0x81: case 0x82: case 0x83: case 0x84: case 0x85: case 0x86: case 0x87:
  case 0x88: case 0x89: case 0x8a: case 0x8b: case 0x8c: case 0x8d: case 0x8e: case 0x8f:
  case 0x90: case 0x91: case 0x92: case 0x93: case 0x94: case 0x95: case 0x96: case 0x97:
  case 0x98: case 0x99: case 0x9a: case 0x9b: case 0x9c: case 0x9d: case 0x9e: case 0x9f:
  case 0xa0: case 0xa1: case 0xa2: case 0xa3: case 0xa4: case 0xa5: case 0xa6: case 0xa7:
  case 0xa8: case 0xa9: case 0xaa: case 0xab: case 0xac: case 0xad: case 0xae: case 0xaf:
  case 0xb0: case 0xb1: case 0xb2: case 0xb3: case 0xb4: case 0xb5: case 0xb6: case 0xb7:
  case 0xb8: case 0xb9: case 0xba: case 0xbb: case 0xbc: case 0xbd: case 0xbe: case 0xbf:
  case 0xc0: case 0xc1: case 0xc2: case 0xc3: case 0xc4: case 0xc5: case 0xc6: case 0xc7:
  case 0xc8: case 0xc9: case 0xca: case 0xcb: case 0xcc: case 0xcd: case 0xce: case 0xcf:
  case 0xd0: case 0xd1: case 0xd2: case 0xd3: case 0xd4: case 0xd5: case 0xd6: case 0xd7:
  case 0xd8: case 0xd9: case 0xda: case 0xdb: case 0xdc: case 0xdd: case 0xde: case 0xdf:
  case 0xe0: case 0xe1: case 0xe2: case 0xe3: case 0xe4: case 0xe5: case 0xe6: case 0xe7:
  case 0xe8: case 0xe9: case 0xea: case 0xeb: case 0xec: case 0xed: case 0xee: case 0xef:
  case 0xf0: case 0xf1: case 0xf2: case 0xf3: case 0xf4: case 0xf5: case 0xf6: case 0xf7:
  case 0xf8: case 0xf9: case 0xfa: case 0xfb: case 0xfc: case 0xfd: case 0xfe:
	  HRAM[address & 0x7F] = value;
	  return;

  case 0xff: 
    register_IE = value;
    return;
  }
  
  //printf("%04x\n", address);
  //gbMemory[address - 0x8000] = value;
}

uint8 gbReadMemory(uint16 address)
{
  uint8 retval = 0xFF;

  if(address < 0xa000)
    retval = gbMemoryMap[address>>12][address&0x0fff];
  else if(address < 0xc000) 
  {
   if(mapperReadRAM)
    retval = mapperReadRAM(address);
   else if(mapper && gbMemoryMap[address >> 12])
   {
    //printf("%04x %d\n", address, gbRamSizeMask);
    retval = gbMemoryMap[address >> 12][address & 0x0fff & gbRamSizeMask];
   }
  }
  else if(address < 0xfe00)
  {
   unsigned int page = (address >> 12);
   if(page >= 0xE) page -= 2;
   retval = gbMemoryMap[page][address & 0x0fff];
  }
  else if(address < 0xfea0)
   retval = gbOAM[address & 0xFF];
  else if(address >= 0xff00) 
  {
    switch(address & 0x00ff) 
    {
     case 0x00:
      {
        int b = register_P1;

        if((b & 0x30) == 0x20) {
          b &= 0xf0;

	  b |= ((gbJoymask >> 4) & 0xF) ^ 0xF;

          register_P1 = b;
        } else if((b & 0x30) == 0x10) {
          b &= 0xf0;

          b |= ((gbJoymask >> 0) & 0xF) ^ 0xF;
          
          register_P1 = b;
        } else {
            register_P1 = 0xff;
        }
      }
      retval = register_P1;
      break;
    case 0x01:
      retval = register_SB;
      break;
    case 0x02:
      retval = register_SC;
      break;
    case 0x04:
      retval = register_DIV;
      break;
    case 0x05:
	retval = register_TIMA;
	break;
    case 0x06:
	retval = register_TMA;
	break;
    case 0x07:
	retval = 0xf8 | register_TAC;
	break;
    case 0x0f:
	retval = 0xe0 | register_IF;
	break;
    case 0x10: case 0x11: case 0x12: case 0x13: case 0x14: case 0x15: case 0x16: case 0x17:
    case 0x18: case 0x19: case 0x1a: case 0x1b: case 0x1c: case 0x1d: case 0x1e: case 0x1f:
    case 0x20: case 0x21: case 0x22: case 0x23: case 0x24: case 0x25: case 0x26: case 0x27:
    case 0x28: case 0x29: case 0x2a: case 0x2b: case 0x2c: case 0x2d: case 0x2e: case 0x2f:
    case 0x30: case 0x31: case 0x32: case 0x33: case 0x34: case 0x35: case 0x36: case 0x37:
    case 0x38: case 0x39: case 0x3a: case 0x3b: case 0x3c: case 0x3d: case 0x3e: case 0x3f:
	retval = SOUND_Read(SoundTS, address);
	break;
    case 0x40:
	retval = register_LCDC;
	break;
    case 0x41:
	retval = 0x80 | register_STAT;
	break;
    case 0x42:
	retval = register_SCY;
	break;
    case 0x43:
	retval = register_SCX;
	break;
    case 0x44:
	retval = register_LY;
	break;
    case 0x45:
	retval = register_LYC;
	break;
    case 0x46:
	retval = register_DMA;
	break;
    case 0x47:
	retval = gbBgp[0] | (gbBgp[1] << 2) | (gbBgp[2] << 4) | (gbBgp[3] << 6);
	break;
    case 0x48:
	retval = (gbObp0[0] & 3) | ((gbObp0[1] & 3) << 2) | ((gbObp0[2] & 3) << 4) | ((gbObp0[3] & 3) << 6);
	break;
    case 0x49:
	retval = (gbObp1[0] & 3) | ((gbObp1[1] & 3) << 2) | ((gbObp1[2] & 3) << 4) | ((gbObp1[3] & 3) << 6);
	break;
    case 0x4a:
	retval = register_WY;
	break;
    case 0x4b:
	retval = register_WX;
	break;
    case 0x4d:
	retval = register_KEY1;
	break;
    case 0x4f:
	retval = 0xfe | register_VBK;
	break;
    case 0x51:
	retval = register_HDMA1;
	break;
    case 0x52:
	retval = register_HDMA2;
	break;
    case 0x53:
	retval = register_HDMA3;
	break;
    case 0x54:
	retval = register_HDMA4;
	break;
    case 0x55:
	retval = register_HDMA5;
	break;
    case 0x56:
	retval = register_RP;
	break;
    case 0x68:
	retval = register_BCPS;
	break;
    case 0x69:
	retval = register_BCPD;
	break;
    case 0x6a:
	retval = register_OCPS;
	break;
    case 0x6b:
	retval = register_OCPD;
	break;
    case 0x6c:
	retval = (register_FF6C & 1) | 0xFE;
	break;
    case 0x70:
	retval = (0xf8 | register_SVBK);
	break;
    case 0x72:
	retval = gbCgbMode ? register_FF72 : 0xFF;
	break;
    case 0x73:
	retval = gbCgbMode ? register_FF73 : 0xFF;
	break;
    case 0x74:
	retval = gbCgbMode ? register_FF74 : 0xFF;
	break;
    case 0x75:
	retval = gbCgbMode ? ((register_FF75 &~0x8F) | 0x8F) : 0xFF;
	break;
    case 0x76:
	retval = gbCgbMode ? 0x00 : 0xFF;
	break;
    case 0x77:
	retval = gbCgbMode ? 0x00 : 0xFF;
	break;

    case 0x80: case 0x81: case 0x82: case 0x83: case 0x84: case 0x85: case 0x86: case 0x87:
    case 0x88: case 0x89: case 0x8a: case 0x8b: case 0x8c: case 0x8d: case 0x8e: case 0x8f:
    case 0x90: case 0x91: case 0x92: case 0x93: case 0x94: case 0x95: case 0x96: case 0x97:
    case 0x98: case 0x99: case 0x9a: case 0x9b: case 0x9c: case 0x9d: case 0x9e: case 0x9f:
    case 0xa0: case 0xa1: case 0xa2: case 0xa3: case 0xa4: case 0xa5: case 0xa6: case 0xa7:
    case 0xa8: case 0xa9: case 0xaa: case 0xab: case 0xac: case 0xad: case 0xae: case 0xaf:
    case 0xb0: case 0xb1: case 0xb2: case 0xb3: case 0xb4: case 0xb5: case 0xb6: case 0xb7:
    case 0xb8: case 0xb9: case 0xba: case 0xbb: case 0xbc: case 0xbd: case 0xbe: case 0xbf:
    case 0xc0: case 0xc1: case 0xc2: case 0xc3: case 0xc4: case 0xc5: case 0xc6: case 0xc7:
    case 0xc8: case 0xc9: case 0xca: case 0xcb: case 0xcc: case 0xcd: case 0xce: case 0xcf:
    case 0xd0: case 0xd1: case 0xd2: case 0xd3: case 0xd4: case 0xd5: case 0xd6: case 0xd7:
    case 0xd8: case 0xd9: case 0xda: case 0xdb: case 0xdc: case 0xdd: case 0xde: case 0xdf:
    case 0xe0: case 0xe1: case 0xe2: case 0xe3: case 0xe4: case 0xe5: case 0xe6: case 0xe7:
    case 0xe8: case 0xe9: case 0xea: case 0xeb: case 0xec: case 0xed: case 0xee: case 0xef:
    case 0xf0: case 0xf1: case 0xf2: case 0xf3: case 0xf4: case 0xf5: case 0xf6: case 0xf7:
    case 0xf8: case 0xf9: case 0xfa: case 0xfb: case 0xfc: case 0xfd: case 0xfe:
	retval = HRAM[address & 0x7F];
	break;
    case 0xff:
	retval = register_IE;
	break;
    }
  }

 if(SubCheatsOn)
 {
  std::vector<SUBCHEAT>::iterator chit;

  for(chit = SubCheats[address & 0x7].begin(); chit != SubCheats[address & 0x7].end(); chit++)
  {
   if(address == chit->addr)
   {
    //printf("%02x %02x %02x\n", retval, chit->value, chit->compare);
    if(chit->compare == -1 || chit->compare == retval)
    {
     retval = chit->value;
    }
   }
  }
 }
  
 return(retval);
 //printf("Unknown read: %04x\n", address);
 //return(0xFF);
 //return gbMemoryMap[address>>12][address & 0x0fff];
}

void gbSpeedSwitch()
{
  if(gbSpeed == 0) {
    gbSpeed = 1;
    GBLCD_MODE_0_CLOCK_TICKS = 51 * 2; //127; //51 * 2;
    GBLCD_MODE_1_CLOCK_TICKS = 1140 * 2;
    GBLCD_MODE_2_CLOCK_TICKS = 20 * 2; //52; //20 * 2;
    GBLCD_MODE_3_CLOCK_TICKS = 43 * 2; //99; //43 * 2;
    GBDIV_CLOCK_TICKS = 64 * 2;
    GBLY_INCREMENT_CLOCK_TICKS = 114 * 2;
    GBTIMER_MODE_0_CLOCK_TICKS = 256; //256*2;
    GBTIMER_MODE_1_CLOCK_TICKS = 4; //4*2;
    GBTIMER_MODE_2_CLOCK_TICKS = 16; //16*2;
    GBTIMER_MODE_3_CLOCK_TICKS = 64; //64*2;
    GBSERIAL_CLOCK_TICKS = 128 * 2;
    gbDivTicks *= 2;
    gbLcdTicks *= 2;
    gbLcdLYIncrementTicks *= 2;
    //    timerTicks *= 2;
    //    timerClockTicks *= 2;
    gbSerialTicks *= 2;
    //    synchronizeTicks *= 2;
    //    SYNCHRONIZE_CLOCK_TICKS *= 2;
  } else {
    gbSpeed = 0;
    GBLCD_MODE_0_CLOCK_TICKS = 51;
    GBLCD_MODE_1_CLOCK_TICKS = 1140;
    GBLCD_MODE_2_CLOCK_TICKS = 20;
    GBLCD_MODE_3_CLOCK_TICKS = 43;
    GBDIV_CLOCK_TICKS = 64;
    GBLY_INCREMENT_CLOCK_TICKS = 114;
    GBTIMER_MODE_0_CLOCK_TICKS = 256;
    GBTIMER_MODE_1_CLOCK_TICKS = 4;
    GBTIMER_MODE_2_CLOCK_TICKS = 16;
    GBTIMER_MODE_3_CLOCK_TICKS = 64;
    GBSERIAL_CLOCK_TICKS = 128;
    gbDivTicks /= 2;
    gbLcdTicks /= 2;
    gbLcdLYIncrementTicks /= 2;
    //    timerTicks /= 2;
    //    timerClockTicks /= 2;
    gbSerialTicks /= 2;
    //    synchronizeTicks /= 2;
    //    SYNCHRONIZE_CLOCK_TICKS /= 2;    
  }
}

void gbReset()
{
 GBZ80_Reset();

  register_DIV = 0;
  register_TIMA = 0;
  register_TMA = 0;
  register_TAC = 0;
  register_IF = 1;
  register_LCDC = 0x91;
  register_STAT = 0;
  register_SCY = 0;
  register_SCX = 0;  
  register_LY = 0;  
  register_LYC = 0;
  register_DMA = 0;
  register_WY = 0;
  register_WX = 0;
  register_VBK = 0;
  register_HDMA1 = 0;
  register_HDMA2 = 0;
  register_HDMA3 = 0;
  register_HDMA4 = 0;
  register_HDMA5 = 0;
  register_SVBK = 0;
  register_IE = 0;  

  if(gbCgbMode) 
  {
    register_HDMA5 = 0xff;
    register_BCPS = 0xc0;
    register_OCPS = 0xc0;    
  } 
  else 
  {
    for(int i = 0; i < 8; i++)
    {
     int fun = 3 - (i & 3);
     fun *= 6;
     fun += 4;
     gbPalette[i] = fun | (fun << 5) | (fun << 10);
    }
  }

  if(gbSpeed) {
    gbSpeedSwitch();
    register_KEY1 = 0;
  }
  
  gbDivTicks = GBDIV_CLOCK_TICKS;
  gbLcdMode = GBLCDM_OAM;
  gbLcdTicks = GBLCD_MODE_2_CLOCK_TICKS;
  gbLcdLYIncrementTicks = 0;
  gbTimerTicks = 0;
  gbTimerClockTicks = 0;
  gbSerialTicks = 0;
  gbSerialBits = 0;
  gbSerialOn = 0;
  gbWindowLine = -1;
  gbTimerOn = 0;
  gbTimerMode = 0;
  //  gbSynchronizeTicks = GBSYNCHRONIZE_CLOCK_TICKS;
  gbSpeed = 0;
  gbJoymask = 0;
  
  if(gbCgbMode) {
    gbSpeed = 0;
    gbHdmaOn = 0;
    gbHdmaSource = 0x0000;
    gbHdmaDestination = 0x8000;
    gbWramBank = 1;
    register_LY = 0x90;
    gbLcdMode = GBLCDM_VBLANK;
    for(int i = 0; i < 64; i++)
      gbPalette[i] = 0x7fff;
  }

  for(int i = 0; i < 4; i++)
  {
   gbBgp[i] = i;
   gbObp0[i] = 4 | i;
   gbObp1[i] = 8 | i;
  }

  memset(&gbDataMBC1,0, sizeof(gbDataMBC1));
  gbDataMBC1.mapperROMBank = 1;

  gbDataMBC2.mapperRAMEnable = 0;
  gbDataMBC2.mapperROMBank = 1;

  memset(&gbDataMBC3,0, 6 * sizeof(int));
  gbDataMBC3.mapperROMBank = 1;

  memset(&gbDataMBC5, 0, sizeof(gbDataMBC5));
  gbDataMBC5.mapperROMBank = 1;

  memset(&gbDataHuC1, 0, sizeof(gbDataHuC1));
  gbDataHuC1.mapperROMBank = 1;

  memset(&gbDataHuC3, 0, sizeof(gbDataHuC3));
  gbDataHuC3.mapperROMBank = 1;

  gbMemoryMap[0x00] = &gbRom[0x0000];
  gbMemoryMap[0x01] = &gbRom[0x1000];
  gbMemoryMap[0x02] = &gbRom[0x2000];
  gbMemoryMap[0x03] = &gbRom[0x3000];
  gbMemoryMap[0x04] = &gbRom[0x4000];
  gbMemoryMap[0x05] = &gbRom[0x5000];
  gbMemoryMap[0x06] = &gbRom[0x6000];
  gbMemoryMap[0x07] = &gbRom[0x7000];
  gbMemoryMap[0x08] = &gbVram[0x0000];
  gbMemoryMap[0x09] = &gbVram[0x1000];
  gbMemoryMap[0x0a] = NULL;
  gbMemoryMap[0x0b] = NULL;
  gbMemoryMap[0x0c] = &gbWram[0x0000];
  gbMemoryMap[0x0d] = &gbWram[0x1000];
  gbMemoryMap[0x0e] = NULL; 
  gbMemoryMap[0x0f] = NULL; 

 if(gbRam)
 {
  gbMemoryMap[0x0a] = &gbRam[0x0000];

  if(gbRamSize > 0x1000)
   gbMemoryMap[0x0b] = &gbRam[0x1000];
  else
   gbMemoryMap[0x0b] = gbMemoryMap[0x0a];
 }

 SOUND_Reset();

 // BIOS simulate
 SOUND_Write(0, 0xFF26, 0x80);
 SOUND_Write(0, 0xFF11, 0x80);
 SOUND_Write(0, 0xFF12, 0xF3);
 SOUND_Write(0, 0xFF25, 0xF3);
 SOUND_Write(0, 0xFF24, 0x77);
}

static void gbPower(void)
{
 snooze = 0;
 PadInterruptDelay = 0;

  if(gbCgbMode)
  {
   memset(gbWram,0,0x8000);
   memset(gbVram, 0, 0x4000);
  }
  else
  {
   memset(gbWram, 0x00, 0x2000);
   memset(gbVram, 0x00, 0x2000);
  }
  memset(gbOAM, 0x00, 0xA0);
  memset(HRAM, 0x00, 0x80);

  if(gbRam && !gbBattery)
   memset(gbRam, 0xFF, gbRamSize);

  gbReset();
}

static void gbWriteSaveMBC1(const std::string& path)
{
 MDFN_DumpToFile(path, gbRam, gbRamSize, true);
}

static void gbWriteSaveMBC2(const std::string& path)
{
 MDFN_DumpToFile(path, gbRam, 256 * 2, true);
}

static void gbWriteSaveMBC3(const std::string& path, bool extendedSave)
{
 std::vector<PtrLengthPair> EvilRams;
 uint8 time_buffer[10 * 4 + 8]; // 10 uint32, 1 uint64

 EvilRams.push_back(PtrLengthPair(gbRam, gbRamSize));

 if(extendedSave)
 {
  MDFN_en32lsb(time_buffer + 0, gbDataMBC3.mapperSeconds);
  MDFN_en32lsb(time_buffer + 4, gbDataMBC3.mapperMinutes);
  MDFN_en32lsb(time_buffer + 8, gbDataMBC3.mapperHours);
  MDFN_en32lsb(time_buffer + 12, gbDataMBC3.mapperDays);
  MDFN_en32lsb(time_buffer + 16, gbDataMBC3.mapperControl);
  MDFN_en32lsb(time_buffer + 20, gbDataMBC3.mapperLSeconds);
  MDFN_en32lsb(time_buffer + 24, gbDataMBC3.mapperLMinutes);
  MDFN_en32lsb(time_buffer + 28, gbDataMBC3.mapperLHours);
  MDFN_en32lsb(time_buffer + 32, gbDataMBC3.mapperLDays);
  MDFN_en32lsb(time_buffer + 36, gbDataMBC3.mapperLControl);
  MDFN_en64lsb(time_buffer + 40, gbDataMBC3.mapperLastTime);

  EvilRams.push_back(PtrLengthPair(time_buffer, sizeof(time_buffer)));
 }  

 MDFN_DumpToFile(path, EvilRams, true);
}

static void gbWriteSaveMBC5(const std::string& path)
{
 MDFN_DumpToFile(path, gbRam, gbRamSize, true);
}

static void gbWriteSaveMBC7(const std::string& path)
{
 MDFN_DumpToFile(path, gbRam, 256, true);
}

static void gbReadSaveMBC1(const std::string& path)
{
 std::unique_ptr<Stream> file = MDFN_AmbigGZOpenHelper(path, std::vector<size_t>({ (unsigned)gbRamSize }));

 file->read(gbRam, gbRamSize);
}

static void gbReadSaveMBC2(const std::string& path)
{
 std::unique_ptr<Stream> file = MDFN_AmbigGZOpenHelper(path, std::vector<size_t>({ 256 * 2 }));

 file->read(gbRam, 256 * 2);
}

static void gbReadSaveMBC3(const std::string& path)
{
 uint8 time_buffer[10 * 4 + 8]; // 10 uint32, 1 uint64
 std::unique_ptr<Stream> file = MDFN_AmbigGZOpenHelper(path, std::vector<size_t>({ (unsigned)gbRamSize, (unsigned)gbRamSize + sizeof(time_buffer) }));

 file->read(gbRam, gbRamSize);

 if(file->read(&time_buffer[0], 1, false) == 1)
 {
  file->read(&time_buffer[1], sizeof(time_buffer) - 1);

  gbDataMBC3.mapperSeconds = MDFN_de32lsb(time_buffer + 0);
  gbDataMBC3.mapperMinutes = MDFN_de32lsb(time_buffer + 4);
  gbDataMBC3.mapperHours = MDFN_de32lsb(time_buffer + 8);
  gbDataMBC3.mapperDays = MDFN_de32lsb(time_buffer + 12);
  gbDataMBC3.mapperControl = MDFN_de32lsb(time_buffer + 16);
  gbDataMBC3.mapperLSeconds = MDFN_de32lsb(time_buffer + 20);
  gbDataMBC3.mapperLMinutes = MDFN_de32lsb(time_buffer + 24);
  gbDataMBC3.mapperLHours = MDFN_de32lsb(time_buffer + 28);
  gbDataMBC3.mapperLDays = MDFN_de32lsb(time_buffer + 32);
  gbDataMBC3.mapperLControl = MDFN_de32lsb(time_buffer + 36);
  gbDataMBC3.mapperLastTime = MDFN_de64lsb(time_buffer + 40);
 }
}

static void gbReadSaveMBC5(const std::string& path)
{
 std::unique_ptr<Stream> file = MDFN_AmbigGZOpenHelper(path, std::vector<size_t>({ (unsigned)gbRamSize }));

 file->read(gbRam, gbRamSize);
}

static void gbReadSaveMBC7(const std::string& path)
{
 std::unique_ptr<Stream> file = MDFN_AmbigGZOpenHelper(path, std::vector<size_t>({ 256 }));

 file->read(gbRam, 256);
}

static void gbWriteBatteryFile(const std::string& path, bool extendedSave)
{
  if(gbBattery)
  {
   int type = gbRom[0x147];

   switch(type)
   {
    case 0x03:
      gbWriteSaveMBC1(path);
      break;
    case 0x06:
      gbWriteSaveMBC2(path);
      break;
    case 0x0f:
    case 0x10:
    case 0x13:
      gbWriteSaveMBC3(path, extendedSave);
      break;
    case 0x1b:
    case 0x1e:
      gbWriteSaveMBC5(path);
      break;
    case 0x22:
      gbWriteSaveMBC7(path);
      break;
    case 0xff:
      gbWriteSaveMBC1(path);
      break;
   }
  }
}

static void gbReadBatteryFile(const std::string& path)
{
  if(gbBattery)
  {
   int type = gbRom[0x147];
    
   switch(type)
   {
    case 0x03:
      gbReadSaveMBC1(path);
      break;

    case 0x06:
      gbReadSaveMBC2(path);
      break;

    case 0x0f:
    case 0x10:
    case 0x13:
      //
      // Initialize time data before loading from save file, in case save file doesn't exist(or doesn't contain the time data) and throws an exception.
      //
      {
	time_t tmp;

        time(&tmp);
        gbDataMBC3.mapperLastTime = tmp;
        struct tm *lt;
        lt = localtime(&tmp);
        gbDataMBC3.mapperSeconds = lt->tm_sec;
        gbDataMBC3.mapperMinutes = lt->tm_min;
        gbDataMBC3.mapperHours = lt->tm_hour;
        gbDataMBC3.mapperDays = lt->tm_yday & 255;
        gbDataMBC3.mapperControl = (gbDataMBC3.mapperControl & 0xfe) |
          (lt->tm_yday > 255 ? 1: 0);
      }
      gbReadSaveMBC3(path);
      break;

    case 0x1b:
    case 0x1e:
      gbReadSaveMBC5(path);
      break;

    case 0x22:
      gbReadSaveMBC7(path);
      break;

    case 0xff:
      gbReadSaveMBC1(path);
      break;
   }
  }
}

static SFORMAT Joy_StateRegs[] =
{
 SFVAR(gbJoymask),
 SFEND
};

static SFORMAT MBC1_StateRegs[] =
{
 SFVARN(gbDataMBC1.mapperRAMEnable, "RAME"),
 SFVARN(gbDataMBC1.mapperROMBank, "ROMB"),
 SFVARN(gbDataMBC1.mapperRAMBank,"RAMB"),
 SFVARN(gbDataMBC1.mapperMemoryModel, "MEMM"),
 SFEND
};

static SFORMAT MBC2_StateRegs[] =
{
 SFVARN(gbDataMBC2.mapperRAMEnable, "RAME"),
 SFVARN(gbDataMBC2.mapperROMBank, "ROMB"),
 SFEND
};

static SFORMAT MBC3_StateRegs[] =
{
 SFVARN(gbDataMBC3.mapperRAMEnable, "RAME"),
 SFVARN(gbDataMBC3.mapperROMBank, "ROMB"),
 SFVARN(gbDataMBC3.mapperRAMBank, "RAMB"),
 SFVARN(gbDataMBC3.mapperClockLatch, "CLKL"),
 SFVARN(gbDataMBC3.mapperClockRegister, "CLKR"),
 SFVARN(gbDataMBC3.mapperSeconds, "SEC"),
 SFVARN(gbDataMBC3.mapperHours, "HOUR"),
 SFVARN(gbDataMBC3.mapperDays, "DAY"),
 SFVARN(gbDataMBC3.mapperControl, "CTRL"),

 SFVARN(gbDataMBC3.mapperLSeconds, "LSEC"),
 SFVARN(gbDataMBC3.mapperLHours, "LHUR"),
 SFVARN(gbDataMBC3.mapperLDays, "LDAY"),
 SFVARN(gbDataMBC3.mapperLControl, "LCTR"),
 SFVARN(gbDataMBC3.mapperLastTime, "LTIM"),
 SFEND
};

static SFORMAT MBC5_StateRegs[] =
{
 SFVAR(gbDataMBC5.mapperRAMEnable),
 SFVAR(gbDataMBC5.mapperROMBank),
 SFVAR(gbDataMBC5.mapperRAMBank),
 SFVAR(gbDataMBC5.mapperROMHighAddress),
 SFVAR(gbDataMBC5.isRumbleCartridge),
 SFEND
};

static SFORMAT MBC7_StateRegs[] =
{
 SFVARN(gbDataMBC7.mapperROMBank, "ROMB"),
 SFVARN(gbDataMBC7.cs, "CS"),
 SFVARN(gbDataMBC7.sk, "SK"),
 SFVARN(gbDataMBC7.state, "STTE"),
 SFVARN(gbDataMBC7.buffer, "BUF"),
 SFVARN(gbDataMBC7.idle, "IDLE"),
 SFVARN(gbDataMBC7.count, "CONT"),
 SFVARN(gbDataMBC7.code, "CODE"),
 SFVARN(gbDataMBC7.address, "ADDR"),
 SFVARN(gbDataMBC7.writeEnable, "WRE"),
 SFVARN(gbDataMBC7.value, "VALU"),

 SFVARN(gbDataMBC7.curtiltx, "TILTX"),
 SFVARN(gbDataMBC7.curtilty, "TILTY"),

 SFEND
};

static SFORMAT HuC1_StateRegs[] =
{
 SFVARN(gbDataHuC1.mapperRAMEnable, "RAME"),
 SFVARN(gbDataHuC1.mapperROMBank, "ROMB"),
 SFVARN(gbDataHuC1.mapperRAMBank, "RAMB"),
 SFVARN(gbDataHuC1.mapperMemoryModel, "MEMM"),
 SFVARN(gbDataHuC1.mapperROMHighAddress, "ROMH"),
 SFEND
};

static SFORMAT HuC3_StateRegs[] =
{
 SFVARN(gbDataHuC3.mapperRAMEnable, "RAME"),
 SFVARN(gbDataHuC3.mapperROMBank, "ROMB"),
 SFVARN(gbDataHuC3.mapperRAMBank, "RAMB"),
 SFVARN(gbDataHuC3.mapperAddress, "ADDR"),
 SFVARN(gbDataHuC3.mapperRAMFlag, "RAMF"),
 SFVARN(gbDataHuC3.mapperRAMValue, "RAMV"),
 SFVARN(gbDataHuC3.mapperRegister1, "REG1"),
 SFVARN(gbDataHuC3.mapperRegister2, "REG2"),
 SFVARN(gbDataHuC3.mapperRegister3, "REG3"),
 SFVARN(gbDataHuC3.mapperRegister4, "REG4"),
 SFVARN(gbDataHuC3.mapperRegister5, "REG5"),
 SFVARN(gbDataHuC3.mapperRegister6, "REG6"),
 SFVARN(gbDataHuC3.mapperRegister7, "REG7"),
 SFVARN(gbDataHuC3.mapperRegister8, "REG8"),

 SFEND
};


static SFORMAT gbSaveGameStruct[] = 
{
  SFVAR(GBLCD_MODE_0_CLOCK_TICKS),
  SFVAR(GBLCD_MODE_1_CLOCK_TICKS),
  SFVAR(GBLCD_MODE_2_CLOCK_TICKS),
  SFVAR(GBLCD_MODE_3_CLOCK_TICKS),
  SFVAR(GBDIV_CLOCK_TICKS),
  SFVAR(GBLY_INCREMENT_CLOCK_TICKS),
  SFVAR(GBTIMER_MODE_0_CLOCK_TICKS),
  SFVAR(GBTIMER_MODE_1_CLOCK_TICKS),
  SFVAR(GBTIMER_MODE_2_CLOCK_TICKS),
  SFVAR(GBTIMER_MODE_3_CLOCK_TICKS),
  SFVAR(GBSERIAL_CLOCK_TICKS),
  SFVAR(GBSYNCHRONIZE_CLOCK_TICKS),

  SFVAR(snooze),
  SFVAR(PadInterruptDelay),

  SFVAR(gbDivTicks),
  SFVAR(gbLcdMode),
  SFVAR(gbLcdTicks),
  SFVAR(gbLcdLYIncrementTicks),
  SFVAR(gbTimerTicks),
  SFVAR(gbTimerClockTicks),
  SFVAR(gbSerialTicks),
  SFVAR(gbSerialBits),
  SFVAR(gbSynchronizeTicks),
  SFVAR(gbTimerOn),
  SFVAR(gbTimerMode),
  SFVAR(gbSerialOn),
  SFVAR(gbWindowLine),
  //SFVAR(gbCgbMode),
  SFVAR(gbWramBank),
  SFVAR(gbHdmaSource),
  SFVAR(gbHdmaDestination),
  SFVAR(gbHdmaBytes),
  SFVAR(gbHdmaOn),
  SFVAR(gbSpeed),
  SFVAR(gbDmaTicks),
  SFVAR(register_P1),
  SFVAR(register_SB),
  SFVAR(register_SC),
  SFVAR(register_DIV),
  SFVAR(register_TIMA),
  SFVAR(register_TMA),
  SFVAR(register_TAC),
  SFVAR(register_IF),
  SFVAR(register_LCDC),
  SFVAR(register_STAT),
  SFVAR(register_SCY),
  SFVAR(register_SCX),
  SFVAR(register_LY),
  SFVAR(register_LYC),
  SFVAR(register_DMA),
  SFVAR(register_WY),
  SFVAR(register_WX),
  SFVAR(register_VBK),
  SFVAR(register_HDMA1),
  SFVAR(register_HDMA2),
  SFVAR(register_HDMA3),
  SFVAR(register_HDMA4),
  SFVAR(register_HDMA5),
  SFVAR(register_RP),
  SFVAR(register_FF6C),
  SFVAR(register_SVBK),
  SFVAR(register_FF72),
  SFVAR(register_FF73),
  SFVAR(register_FF74),
  SFVAR(register_FF75),
  SFVAR(register_IE),
  SFARRAYN(gbBgp, 4, "BGP"),
  SFARRAYN(gbObp0, 4, "OBP0"),
  SFARRAYN(gbObp1, 4, "OBP1"),
  SFEND
};

static void CloseGame(void) MDFN_COLD;
static void CloseGame(void)
{
 try
 {
  gbWriteBatteryFile(MDFN_MakeFName(MDFNMKF_SAV, 0, "sav"), true);
 }
 catch(std::exception &e)
 {
  MDFN_PrintError("%s", e.what());
 }

 Cleanup();
}

static void StateRest(int version)
{
 register_SVBK &= 7;
 register_VBK &= 1;

 for(unsigned i = 0; i < 4; i++)
 {
  gbBgp[i] = gbBgp[i] & 0x3;
  gbObp0[i] = (gbObp0[i] & 0x3) | 4;
  gbObp1[i] = (gbObp1[i] & 0x3) | 8;
 }

  gbMemoryMap[0x00] = &gbRom[0x0000];
  gbMemoryMap[0x01] = &gbRom[0x1000];
  gbMemoryMap[0x02] = &gbRom[0x2000];
  gbMemoryMap[0x03] = &gbRom[0x3000];
  gbMemoryMap[0x04] = &gbRom[0x4000];
  gbMemoryMap[0x05] = &gbRom[0x5000];
  gbMemoryMap[0x06] = &gbRom[0x6000];
  gbMemoryMap[0x07] = &gbRom[0x7000];
  gbMemoryMap[0x08] = &gbVram[0x0000];
  gbMemoryMap[0x09] = &gbVram[0x1000];
  gbMemoryMap[0x0a] = NULL;
  gbMemoryMap[0x0b] = NULL;
  gbMemoryMap[0x0c] = &gbWram[0x0000];
  gbMemoryMap[0x0d] = &gbWram[0x1000];
  gbMemoryMap[0x0e] = NULL;
  gbMemoryMap[0x0f] = NULL;

  if(gbRam)
  {
   gbMemoryMap[0x0a] = &gbRam[0x0000];

   if(gbRamSize > 0x1000)
    gbMemoryMap[0x0b] = &gbRam[0x1000];
   else
    gbMemoryMap[0x0b] = gbMemoryMap[0x0a];
  }

  int type = gbRom[0x147];

  switch(type) {
  case 0x00:
  case 0x01:
  case 0x02:
  case 0x03:
    // MBC 1
    memoryUpdateMapMBC1();
    break;
  case 0x05:
  case 0x06:
    // MBC2
    memoryUpdateMapMBC2();
    break;
  case 0x0f:
  case 0x10:
  case 0x11:
  case 0x12:
  case 0x13:
    // MBC 3
    memoryUpdateMapMBC3();
    break;
  case 0x19:
  case 0x1a:
  case 0x1b:
    // MBC5
    memoryUpdateMapMBC5();
    break;
  case 0x1c:
  case 0x1d:
  case 0x1e:
    // MBC 5 Rumble
    memoryUpdateMapMBC5();
    break;
  case 0x22:
    // MBC 7
    memoryUpdateMapMBC7();
    break;
  case 0xfe:
    // HuC3
    memoryUpdateMapHuC3();
    break;
  case 0xff:
    // HuC1
    memoryUpdateMapHuC1();
    break;
  }

  if(gbCgbMode)
  {
    int value = register_SVBK;
    if(value == 0)
      value = 1;

    gbMemoryMap[0x08] = &gbVram[register_VBK * 0x2000];
    gbMemoryMap[0x09] = &gbVram[register_VBK * 0x2000 + 0x1000];
    gbMemoryMap[0x0d] = &gbWram[value * 0x1000];

    gbWramBank = value;
  }

}

uint32 gblayerSettings;

static const char *GetGBRAMSizeString(uint8 t)
{
 const char *type = _("Unknown");

 switch(t) 
 {
  case 0:
    type = _("None");
    break;
  case 1:
    type = "2K";
    break;
  case 2:
    type = "8K";
    break;
  case 3:
    type = "32K";
    break;
  case 4:
    type = "128K";
    break;
  case 5:
    type = "64K";
    break;
 }

 return(type);
}


static const char *GetGBTypeString(uint8 t)
{
 const char *type = _("Unknown");

 switch(t)
 {
  case 0x00:
    type = "ROM";
    break;
  case 0x01:
    type = "ROM+MBC1";
    break;
  case 0x02:
    type = "ROM+MBC1+RAM";
    break;
  case 0x03:
    type = "ROM+MBC1+RAM+BATT";
    break;
  case 0x05:
    type = "ROM+MBC2";
    break;
  case 0x06:
    type = "ROM+MBC2+BATT";
    break;
  case 0x0f:
    type = "ROM+MBC3+TIMER+BATT";
    break;
  case 0x10:
    type = "ROM+MBC3+TIMER+RAM+BATT";
    break;
  case 0x11:
    type = "ROM+MBC3";
    break;
  case 0x12:
    type = "ROM+MBC3+RAM";
    break;
  case 0x13:
    type = "ROM+MBC3+RAM+BATT";
    break;
  case 0x19:
    type = "ROM+MBC5";
    break;
  case 0x1a:
    type = "ROM+MBC5+RAM";
    break;
  case 0x1b:
    type = "ROM+MBC5+RAM+BATT";
    break;
  case 0x1c:
    type = "ROM+MBC5+RUMBLE";
    break;
  case 0x1d:
    type = "ROM+MBC5+RUMBLE+RAM";
    break;
  case 0x1e:
    type = "ROM+MBC5+RUMBLE+RAM+BATT";
    break;
  case 0x22:
    type = "ROM+MBC7+BATT";
    break;
  case 0xfe:
    type = "ROM+HuC-3";
    break;
  case 0xff:
    type = "ROM+HuC-1";
    break;
 }

 return(type);
}

static bool TestMagic(MDFNFILE *fp)
{
 static const uint8 GBMagic[8] = { 0xCE, 0xED, 0x66, 0x66, 0xCC, 0x0D, 0x00, 0x0B };
 uint8 data[0x200];

 if(fp->read(data, 0x200, false) != 0x200 || memcmp(data + 0x104, GBMagic, 8))
  return false;

 return true;
}

static void Cleanup(void)
{
 SOUND_Kill();

 if(gbRam != NULL) 
 {
  delete[] gbRam;
  gbRam = NULL;
 }

 if(gbRom != NULL) 
 {
  delete[] gbRom;
  gbRom = NULL;
 }

 if(gbVram != NULL) 
 {
  delete[] gbVram;
  gbVram = NULL;
 }

 if(gbWram != NULL) 
 {
  delete[] gbWram;
  gbWram = NULL;
 }

 if(gbColorFilter)
 {
  delete[] gbColorFilter;
  gbColorFilter = NULL;
 }
}

static void Load(MDFNFILE *fp) MDFN_COLD;
static void Load(MDFNFILE *fp)
{
 try
 {
  gbColorFilter = new uint32[32768];

  gbEmulatorType = MDFN_GetSettingI("gb.system_type");

  MDFNMP_Init(128, (65536 + 32768) / 128); // + 32768 for GBC WRAM for supported GameShark cheats with RAM page numbers

  SOUND_Init();

  LoadROM(fp);

  md5_context md5;
  md5.starts();
  md5.update(gbRom, gbRomSize);
  md5.finish(MDFNGameInfo->MD5);

  MDFNGameInfo->GameSetMD5Valid = FALSE;

  MDFN_printf(_("ROM:       %dKiB\n"), (gbRomSize + 1023) / 1024);
  MDFN_printf(_("ROM CRC32: 0x%08x\n"), (unsigned int)crc32(0, gbRom, gbRomSize));
  MDFN_printf(_("ROM MD5:   0x%s\n"), md5_context::asciistr(MDFNGameInfo->MD5, 0).c_str());
  MDFN_printf(_("Type:      0x%02x(%s)\n"), gbRom[0x147], GetGBTypeString(gbRom[0x147]));
  MDFN_printf(_("RAM Size:  0x%02x(%s)\n"), gbRom[0x149], GetGBRAMSizeString(gbRom[0x149]));
  MDFN_printf(_("Version:   0x%02x\n"), gbRom[0x14C]);

  //
  //
  //

  try
  {
   gbReadBatteryFile(MDFN_MakeFName(MDFNMKF_SAV, 0, "sav"));
  }
  catch(MDFN_Error &e)
  {
   if(e.GetErrno() != ENOENT)
    throw;
  }
  gblayerSettings = 0xFF;


  MDFNGameInfo->CPInfoActiveBF = 1 << (bool)gbCgbMode;
 }
 catch(std::exception &e)
 {
  Cleanup();
  throw;
 }
}

static void LoadROM(MDFNFILE* fp)
{
  uint8 header[0x200];

  fp->read(header, 0x200);

  if(header[0x148] > 8) 
   throw MDFN_Error(0, _("Unsupported ROM size specified in GB header."));

  gbRomSize = gbRomSizes[header[0x148]];
  gbRomSizeMask = gbRomSizesMasks[header[0x148]];

  gbRom = new uint8[gbRomSize];
  memset(gbRom, 0xFF, gbRomSize);
  memcpy(gbRom, header, std::min<uint64>(0x200, gbRomSize));

  if(gbRomSize > 0x200) // && in_rom_size > 0x200)
   fp->read(gbRom + 0x200, gbRomSize - 0x200); // std::min<uint64>(in_rom_size, gbRomSize) - 0x200);
  
  if(header[0x149] > 5) 
   throw MDFN_Error(0, _("Unsupported RAM size specified in GB header."));

  gbRamSize = gbRamSizes[header[0x149]];
  gbRamSizeMask = gbRamSizesMasks[header[0x149]];

  int type = header[0x147];

  mapperReadRAM = NULL;
  
  switch(type) {
  case 0x00:
  case 0x01:
  case 0x02:
  case 0x03:
    // MBC 1
    mapper = mapperMBC1ROM;
    mapperRAM = mapperMBC1RAM;
    break;
  case 0x05:
  case 0x06:
    // MBC2
    mapper = mapperMBC2ROM;
    mapperRAM = mapperMBC2RAM;
    gbRamSize = 0x200;
    gbRamSizeMask = 0x1ff;
    break;
  case 0x0f:
  case 0x10:
  case 0x11:
  case 0x12:
  case 0x13:
    // MBC 3
    mapper = mapperMBC3ROM;
    mapperRAM = mapperMBC3RAM;
    mapperReadRAM = mapperMBC3ReadRAM;
    break;
  case 0x19:
  case 0x1a:
  case 0x1b:
    // MBC5
    mapper = mapperMBC5ROM;
    mapperRAM = mapperMBC5RAM;
    break;
  case 0x1c:
  case 0x1d:
  case 0x1e:
    // MBC 5 Rumble
    mapper = mapperMBC5ROM;
    mapperRAM = mapperMBC5RAM;
    break;
  case 0x22:
    // MBC 7
    mapper = mapperMBC7ROM;
    mapperRAM = mapperMBC7RAM;
    mapperReadRAM = mapperMBC7ReadRAM;
    gbRamSize = 0x200;
    gbRamSizeMask = 0x1ff;
    break;
  case 0xfe:
    // HuC3
    mapper = mapperHuC3ROM;
    mapperRAM = mapperHuC3RAM;
    mapperReadRAM = mapperHuC3ReadRAM;
    break;
  case 0xff:
    // HuC1
    mapper = mapperHuC1ROM;
    mapperRAM = mapperHuC1RAM;
    break;
  default:
    throw MDFN_Error(0, _("Unsupported mapper type specified in GB header."));
  }

  switch(type) {
  case 0x03:
  case 0x06:
  case 0x0f:
  case 0x10:
  case 0x13:
  case 0x1b:
  case 0x1d:
  case 0x1e:
  case 0x22:
  case 0xff:
    gbBattery = 1;
    break;
  }

  if(gbRamSize) {
    gbRam = new uint8[gbRamSize];
    memset(gbRam, 0xFF, gbRamSize);
  }

  // CGB bit
  if(header[0x143] & 0x80)
  {
    if(gbEmulatorType == 0 ||
       gbEmulatorType == 1 ||
       gbEmulatorType == 4 ||
       gbEmulatorType == 5) {
      gbCgbMode = 1;
      memset(gbPalette,0, 2*128);
    } else {
      gbCgbMode = 0;
    }
  } 
  else
   gbCgbMode = 0;

  if(gbCgbMode)
  {
   gbWram = new uint8[0x8000];
   memset(gbWram, 0, 0x8000);
   MDFNMP_AddRAM(0x8000, 0x10000, gbWram);

   gbVram = new uint8[0x4000];
   memset(gbVram, 0, 0x4000);
  }
  else
  {
   gbWram = new uint8[0x2000];
   memset(gbWram,0,0x2000);

   for(unsigned x = 0; x < 32768; x += 8192)
    MDFNMP_AddRAM(0x2000, 0x10000 | x, &gbWram[0]);

   gbVram = new uint8[0x2000];
   memset(gbVram, 0, 0x2000);
  }

  MDFNMP_AddRAM(0x80, 0xFF80, HRAM);
  MDFNMP_AddRAM(0x2000, 0xC000, gbWram);

  if(gbRam)
   MDFNMP_AddRAM(gbRamSize > 8192 ? 8192 : gbRamSize, 0xA000, gbRam);

  switch(type) {
  case 0x1c:
  case 0x1d:
  case 0x1e:
    gbDataMBC5.isRumbleCartridge = 1;
  }

  gbPower();
}


template<typename T>
static void CopyLineSurface(MDFN_Surface *surface)
{
	T *dest = surface->pix<T>() + register_LY * surface->pitchinpix;

	if(gbCgbMode)
	{
         for(int x = 0; x < 160;) 
	 {
                      *dest++ = gbColorFilter[gbLineMix.cgb[x++]];
                      *dest++ = gbColorFilter[gbLineMix.cgb[x++]];
                      *dest++ = gbColorFilter[gbLineMix.cgb[x++]];
                      *dest++ = gbColorFilter[gbLineMix.cgb[x++]];
                      
                      *dest++ = gbColorFilter[gbLineMix.cgb[x++]];
                      *dest++ = gbColorFilter[gbLineMix.cgb[x++]];
                      *dest++ = gbColorFilter[gbLineMix.cgb[x++]];
                      *dest++ = gbColorFilter[gbLineMix.cgb[x++]];

                      *dest++ = gbColorFilter[gbLineMix.cgb[x++]];
                      *dest++ = gbColorFilter[gbLineMix.cgb[x++]];
                      *dest++ = gbColorFilter[gbLineMix.cgb[x++]];
                      *dest++ = gbColorFilter[gbLineMix.cgb[x++]];

                      *dest++ = gbColorFilter[gbLineMix.cgb[x++]];
                      *dest++ = gbColorFilter[gbLineMix.cgb[x++]];
                      *dest++ = gbColorFilter[gbLineMix.cgb[x++]];
                      *dest++ = gbColorFilter[gbLineMix.cgb[x++]];
         }              
	}
	else // to if(gbCgbMode)
	{
	 if(sizeof(T) == 1)
	 {
          for(int x = 0; x < 160; x++)
	   dest[x] = gbLineMix.dmg[x];
	 }
	 else
	 {
          for(int x = 0; x < 160; x++)
	   dest[x] = gbMonoColorMap[gbLineMix.dmg[x]];
	 }
	}
}

template<typename T>
static void FillLineSurface(MDFN_Surface *surface, int y)
{
 T* dest = surface->pix<T>() + y * surface->pitchinpix;
 uint32 fill_color = gbCgbMode ? gbColorFilter[gbPalette[0]] : ((sizeof(T) == 1) ? 12 : gbMonoColorMap[12]);

 for(int x = 0; x < 160; x++)
  dest[x] = fill_color;
}

static uint8 *paddie, *tilt_paddie;

static void MDFNGB_SetInput(unsigned port, const char *type, uint8 *ptr)
{
 if(port)
  tilt_paddie = (uint8*)ptr;
 else
  paddie = (uint8*)ptr;
}

static void Emulate(EmulateSpecStruct *espec)
{
 bool linedrawn[144];

#if 0
 {
  static bool firstcat = true;
  MDFN_PixelFormat nf;

  nf.bpp = 8;
  nf.colorspace = MDFN_COLORSPACE_RGB;
  nf.Rshift = 0;
  nf.Gshift = 0;
  nf.Bshift = 0;
  nf.Ashift = 8;
  
  nf.Rprec = 6;
  nf.Gprec = 6;
  nf.Bprec = 6;
  nf.Aprec = 0;

  espec->surface->SetFormat(nf, false);
  espec->VideoFormatChanged = firstcat;
  firstcat = false;
 }
#endif

 if(espec->VideoFormatChanged)
  SetPixelFormat(espec->surface->format, gbCgbMode, espec->CustomPalette, espec->CustomPaletteNumEntries);

 if(espec->SoundFormatChanged)
  MDFNGB_SetSoundRate(espec->SoundRate);



 espec->DisplayRect.x = 0;
 espec->DisplayRect.y = 0;
 espec->DisplayRect.w = 160;
 espec->DisplayRect.h = 144;

 memset(linedrawn, 0, sizeof(linedrawn));

 if(!espec->skip && espec->surface->palette)
  memcpy(espec->surface->palette, PalTest, sizeof(PalTest));

 if(gbRom[0x147] == 0x22)
 {
  gbDataMBC7.curtiltx = 2048 + ((int32)MDFN_de16lsb(&tilt_paddie[0x4]) - (int32)MDFN_de16lsb(&tilt_paddie[0x6])) / 200;
  gbDataMBC7.curtilty = 2048 + ((int32)MDFN_de16lsb(&tilt_paddie[0x0]) - (int32)MDFN_de16lsb(&tilt_paddie[0x2])) / 200;
 }

 if(*paddie != gbJoymask)
 {
  PadInterruptDelay = 20;
 }

 MDFNMP_ApplyPeriodicCheats();
 int clockTicks = 0;
 int doret = 0;
  
 while(!doret && SoundTS < 72000)
 {
  if(gbDmaTicks)
  {
   clockTicks = 4;
   gbDmaTicks -= 4;
   if(gbDmaTicks < 0) { clockTicks += gbDmaTicks; gbDmaTicks = 0; }
  }
  else
   clockTicks = GBZ80_RunOp();

  SoundTS += clockTicks << (2 - gbSpeed);
    
  gbDivTicks -= clockTicks;
  while(gbDivTicks <= 0) 
  {
    register_DIV++;
    gbDivTicks += GBDIV_CLOCK_TICKS;
  }

  if(PadInterruptDelay > 0)
  {
   PadInterruptDelay -= clockTicks;
   if(PadInterruptDelay <= 0)
   {
    gbJoymask = *paddie;
    register_IF |= 0x10;
   }
  }

  if(snooze > 0)
  {
   snooze -= clockTicks;
   if(snooze <= 0)
   {
              register_IF |= 1; // V-Blank interrupt
              if(register_STAT & 0x10)
                register_IF |= 2;
   }
  }


  if(register_LCDC & 0x80) 
  {
    // LCD stuff
    gbLcdTicks -= clockTicks;
    if(gbLcdMode == GBLCDM_VBLANK) 
    {
      // during V-BLANK,we need to increment LY at the same rate!
      gbLcdLYIncrementTicks -= clockTicks;
      while(gbLcdLYIncrementTicks <= 0) 
      {
       gbLcdLYIncrementTicks += GBLY_INCREMENT_CLOCK_TICKS;

       if(register_LY < 153) 
       {
        register_LY++;
        gbCompareLYToLYC();
            
        if(register_LY >= 153)
         gbLcdLYIncrementTicks = 6;
       } 
       else 
       {
        register_LY = 0x00;
        // reset the window line
        gbWindowLine = -1;
        gbLcdLYIncrementTicks = GBLY_INCREMENT_CLOCK_TICKS * 2;
        gbCompareLYToLYC();
       }
      }
     }

      // our counter is off, see what we need to do
      while(gbLcdTicks <= 0) 
      {
       switch(gbLcdMode) 
       {
        case GBLCDM_HBLANK:
          // H-Blank
          register_LY++;
          gbCompareLYToLYC();
          
          // check if we reached the V-Blank period       
          if(register_LY == 144) 
	  {
	    doret = 1;
            // Yes, V-Blank
            // set the LY increment counter
            gbLcdLYIncrementTicks = gbLcdTicks + GBLY_INCREMENT_CLOCK_TICKS;
            gbLcdTicks += GBLCD_MODE_1_CLOCK_TICKS;
            gbLcdMode = 1;

            if(register_LCDC & 0x80) 
	    {
	     snooze = 6;
             //register_IF |= 1; // V-Blank interrupt
             //if(register_STAT & 0x10)
             //  register_IF |= 2;
            }
           } else {
            // go the the OAM being accessed mode
            gbLcdTicks += GBLCD_MODE_2_CLOCK_TICKS;
            gbLcdMode = 2;

            // only one LCD interrupt per line. may need to generalize...
            if(!(register_STAT & 0x40) ||
               (register_LY != register_LYC)) {
              if((register_STAT & 0x28) == 0x20)
                register_IF |= 2;
            }
          }
          break;

        case GBLCDM_VBLANK:
          // V-Blank
          // next mode is OAM being accessed mode
          gbLcdTicks += GBLCD_MODE_2_CLOCK_TICKS;
          gbLcdMode = GBLCDM_OAM;
          if(!(register_STAT & 0x40) ||
             (register_LY != register_LYC)) {
            if((register_STAT & 0x28) == 0x20)
              register_IF |= 2;
          }
          break;

        case GBLCDM_OAM:
          // OAM being accessed mode
          
          // next mode is OAM and VRAM in use
          gbLcdTicks += GBLCD_MODE_3_CLOCK_TICKS;
          gbLcdMode = GBLCDM_OAM_VRAM;
          break;

        case GBLCDM_OAM_VRAM:
          // OAM and VRAM in use
          // next mode is H-Blank
          if(register_LY < 144) 
	  {
		linedrawn[register_LY] = 1;
                gbRenderLine();

		switch(espec->surface->format.bpp)
		{
		 case 8:
			CopyLineSurface<uint8>(espec->surface);
			break;

		 case 16:
			CopyLineSurface<uint16>(espec->surface);
			break;

		 case 32:
			CopyLineSurface<uint32>(espec->surface);
			break;
		}
		MDFN_MidLineUpdate(espec, register_LY);
          }
          gbLcdMode = GBLCDM_HBLANK;
          // only one LCD interrupt per line. may need to generalize...
          if(!(register_STAT & 0x40) || (register_LY != register_LYC)) 
	  {
            if(register_STAT & 0x08)
              register_IF |= 2;
          }
          if(gbHdmaOn) 
	  {
            gbDoHdma();
	    //gbDmaTicks += GBLCD_MODE_0_CLOCK_TICKS - 4;
          }

	  gbLcdTicks += GBLCD_MODE_0_CLOCK_TICKS;
          break;
        }
        // mark the correct lcd mode on STAT register
        register_STAT = (register_STAT & 0xfc) | gbLcdMode;
      }
    }

    // serial emulation
    if(gbSerialOn) {
#ifdef LINK_EMULATION
      if(linkConnected) {
        gbSerialTicks -= clockTicks;

        while(gbSerialTicks <= 0) {
          // increment number of shifted bits
          gbSerialBits++;
          linkProc();
          if(gbSerialOn && (register_SC & 1)) {
            if(gbSerialBits == 8) {
              gbSerialBits = 0;
	      register_SB = 0xff;
              register_SC &= 0x7f;
              gbSerialOn = 0;
              register_IF |= 8;
              gbSerialTicks = 0;
            }
          }
          gbSerialTicks += GBSERIAL_CLOCK_TICKS;
        }
      } else {
#endif
        if(register_SC & 1) {
          gbSerialTicks -= clockTicks;
          
          // overflow
          while(gbSerialTicks <= 0) {
            // shift serial byte to right and put a 1 bit in its place
            //      register_SB = 0x80 | (register_SB>>1);
            // increment number of shifted bits
            gbSerialBits++;
            if(gbSerialBits == 8) {
              // end of transmission
              if(gbSerialFunction) // external device
                register_SB = gbSerialFunction(register_SB);
              else
                register_SB = 0xff;
              gbSerialTicks = 0;
              register_SC &= 0x7f;
              gbSerialOn = 0;
              register_IF |= 8;
              gbSerialBits  = 0;
            } else
              gbSerialTicks += GBSERIAL_CLOCK_TICKS;
          }
        }
#ifdef LINK_EMULATION
      }
#endif
    }

    // timer emulation
    if(gbTimerOn) {
      gbTimerTicks -= clockTicks;
      while(gbTimerTicks <= 0) {
	ClockTIMA();
        gbTimerTicks += gbTimerClockTicks;
      }
    }
 }

 //printf("%d %d\n", register_LY, SoundTS);
 for(int y = 0; y < 144; y++)
 {
  if(!linedrawn[y])
  {
   switch(espec->surface->format.bpp)
   {
    case 8:
	FillLineSurface<uint8>(espec->surface, y);
	break;

    case 16:
	FillLineSurface<uint16>(espec->surface, y);
	break;

    case 32:
	FillLineSurface<uint32>(espec->surface, y);
	break;
   }
   MDFN_MidLineUpdate(espec, y);
  }
 }

 espec->MasterCycles = SoundTS;

 espec->SoundBufSize = SOUND_Flush(SoundTS, espec->SoundBuf, espec->SoundBufMaxSize);
 SoundTS = 0;
}

static void StateAction(StateMem *sm, const unsigned load, const bool data_only)
{
 SFORMAT RAMDesc[] =
 {
  SFARRAYN(gbOAM, 0xA0, "OAM"),
  SFARRAYN(HRAM, 0x80, "HRAM"),
  SFARRAYN(gbRam, gbRamSize, "RAM"),
  SFARRAYN(gbVram, gbCgbMode ? 0x4000 : 0x2000, "VRAM"),
  SFARRAYN(gbWram, gbCgbMode ? 0x8000 : 0x2000, "WRAM"),
  SFARRAY16(gbPalette, (gbCgbMode ? 128 : 0)),
  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, gbSaveGameStruct, "MAIN");
 MDFNSS_StateAction(sm, load, data_only, Joy_StateRegs, "JOY");
 MDFNSS_StateAction(sm, load, data_only, MBC1_StateRegs, "MBC1");
 MDFNSS_StateAction(sm, load, data_only, MBC2_StateRegs, "MBC2");
 MDFNSS_StateAction(sm, load, data_only, MBC3_StateRegs, "MBC3");
 MDFNSS_StateAction(sm, load, data_only, MBC5_StateRegs, "MBC5");
 MDFNSS_StateAction(sm, load, data_only, MBC7_StateRegs, "MBC7");
 MDFNSS_StateAction(sm, load, data_only, HuC1_StateRegs, "HuC1");
 MDFNSS_StateAction(sm, load, data_only, HuC3_StateRegs, "HuC3");
 MDFNSS_StateAction(sm, load, data_only, RAMDesc, "RAM");

 GBZ80_StateAction(sm, load, data_only);

 if(load)
  StateRest(load);

 SOUND_StateAction(sm, load, data_only);
}

static void SetLayerEnableMask(uint64 mask)
{
 gblayerSettings = mask;
}

static void DoSimpleCommand(int cmd)
{
 if(cmd == MDFN_MSC_POWER || cmd == MDFN_MSC_RESET)
 {
  gbPower();
 }
}

static const MDFNSetting_EnumList SystemType_List[] =
{
 { "auto", 0, gettext_noop("Auto"), gettext_noop("Automatic detection based on headers.") },
 { "dmg", 3, gettext_noop("DMG"), gettext_noop("Original GameBoy Monochrome.") },
 { "cgb", 1, gettext_noop("CGB"), gettext_noop("GameBoy Color.\n\nThis option is not fully implemented in regards to handling of DMG games.") },
 { "agb", 4, gettext_noop("AGB"), gettext_noop("GameBoy Advance.\n\nThis option is not fully implemented in regards to handling of DMG games.") },
 { NULL, 0 },
};

static MDFNSetting GBSettings[] =
{
 { "gb.system_type", MDFNSF_EMU_STATE | MDFNSF_UNTRUSTED_SAFE, gettext_noop("Emulated GB type."), NULL, MDFNST_ENUM, "auto", NULL, NULL, NULL, NULL, SystemType_List },
 { NULL }
};

static const IDIISG IDII =
{
 { "a", "A", 		/*VIRTB_1,*/ 7, IDIT_BUTTON_CAN_RAPID, NULL },

 { "b", "B", 		/*VIRTB_0,*/ 6, IDIT_BUTTON_CAN_RAPID, NULL },

 { "select", "SELECT",	/*VIRTB_SELECT,*/ 4, IDIT_BUTTON, NULL },

 { "start", "START",	/*VIRTB_START,*/ 5, IDIT_BUTTON, NULL },

 { "right", "RIGHT →",	/*VIRTB_DP0_R,*/ 3, IDIT_BUTTON, "left" },

 { "left", "LEFT ←",	/*VIRTB_DP0_L,*/ 2, IDIT_BUTTON, "right" },

 { "up", "UP ↑", 	/*VIRTB_DP0_U,*/ 0, IDIT_BUTTON, "down" },

 { "down", "DOWN ↓",	/*VIRTB_DP0_D,*/ 1, IDIT_BUTTON, "up" },
};

static const std::vector<InputDeviceInfoStruct> InputDeviceInfo =
{
 {
  "gamepad",
  "Gamepad",
  NULL,
  IDII,
 }
};

static const IDIISG Tilt_IDII =
{
 { "up", "UP ↑", 	0, IDIT_BUTTON_ANALOG },
 { "down", "DOWN ↓",	1, IDIT_BUTTON_ANALOG },
 { "left", "LEFT ←",	2, IDIT_BUTTON_ANALOG },
 { "right", "RIGHT →",	3, IDIT_BUTTON_ANALOG },
};


static const std::vector<InputDeviceInfoStruct> Tilt_InputDeviceInfo =
{
 {
  "tilt",
  "Tilt",
  NULL,
  Tilt_IDII,
 }
};

static const std::vector<InputPortInfoStruct> PortInfo =
{
 { "builtin", "Built-In", InputDeviceInfo, "gamepad" },
 { "tilt", "Tilt", Tilt_InputDeviceInfo, "tilt" }
};

static uint8 CharToNibble(char thechar)
{
 const char lut[16] = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F' };

 thechar = toupper(thechar);

 for(int x = 0; x < 16; x++)
  if(lut[x] == thechar)
   return(x);

 return(0xFF);
}

static bool DecodeGG(const std::string& cheat_string, MemoryPatch* patch)
{
 char str[10];
 unsigned len;

 memset(str, 0, sizeof(str));

 switch(cheat_string.size())
 {
  default:
 	throw(MDFN_Error(0, _("Game Genie code is of an incorrect length.")));
	break;

  case 6:
  case 9:
	strcpy(str, cheat_string.c_str());
	break;

  case 11:
	if(cheat_string[7] != '-' && cheat_string[7] != '_' && cheat_string[7] != ' ')
	 throw(MDFN_Error(0, _("Game Genie code is malformed.")));

	str[6] = cheat_string[8];
	str[7] = cheat_string[9];
	str[8] = cheat_string[10];

  case 7:
	if(cheat_string[3] != '-' && cheat_string[3] != '_' && cheat_string[3] != ' ')
	 throw(MDFN_Error(0, _("Game Genie code is malformed.")));

 	str[0] = cheat_string[0];
	str[1] = cheat_string[1];
	str[2] = cheat_string[2];

	str[3] = cheat_string[4];
	str[4] = cheat_string[5];
	str[5] = cheat_string[6];
	break;
 }

 len = strlen(str);

 for(unsigned x = 0; x < len; x++)
 {
  if(CharToNibble(str[x]) == 0xFF)
  {
   if(str[x] & 0x80)
    throw MDFN_Error(0, _("Invalid character in Game Genie code."));
   else
    throw MDFN_Error(0, _("Invalid character in Game Genie code: %c"), str[x]);
  }
 }

 uint32 tmp_address;
 uint8 tmp_value;
 uint8 tmp_compare = 0;

 tmp_address =  (CharToNibble(str[5]) << 12) | (CharToNibble(str[2]) << 8) | (CharToNibble(str[3]) << 4) | (CharToNibble(str[4]) << 0);
 tmp_address ^= 0xF000;
 tmp_value = (CharToNibble(str[0]) << 4) | (CharToNibble(str[1]) << 0);

 if(len == 9)
 {
  tmp_compare = (CharToNibble(str[6]) << 4) | (CharToNibble(str[8]) << 0);
  tmp_compare = (tmp_compare >> 2) | ((tmp_compare << 6) & 0xC0);
  tmp_compare ^= 0xBA;
 }

 patch->addr = tmp_address;
 patch->val = tmp_value;

 if(len == 9)
 {
  patch->compare = tmp_compare;
  patch->type = 'C';
 }
 else
 {
  patch->compare = 0;
  patch->type = 'S';
 }

 patch->length = 1;

 return(false);
}

static bool DecodeGS(const std::string& cheat_string, MemoryPatch* patch)
{
 if(cheat_string.size() != 8)
  throw MDFN_Error(0, _("GameShark code is of an incorrect length."));

 for(unsigned x = 0; x < 8; x++)
 {
  if(CharToNibble(cheat_string[x]) == 0xFF)
  {
   if(cheat_string[x] & 0x80)
    throw MDFN_Error(0, _("Invalid character in GameShark code."));
   else
    throw MDFN_Error(0, _("Invalid character in GameShark code: %c"), cheat_string[x]);
  }
 }
 uint8 bank = 0;
 uint16 la = 0;


 bank = (CharToNibble(cheat_string[0]) << 4) | (CharToNibble(cheat_string[1]) << 0);
 for(unsigned x = 0; x < 4; x++)
  la |= CharToNibble(cheat_string[4 + x]) << ((x ^ 1) * 4);

 if(la >= 0xD000 && la <= 0xDFFF)
  patch->addr = 0x10000 | ((bank & 0x7) << 12) | (la & 0xFFF);
 else
  patch->addr = la;

 patch->val = (CharToNibble(cheat_string[2]) << 4) | (CharToNibble(cheat_string[3]) << 0);

 patch->compare = 0;
 patch->type = 'R';
 patch->length = 1;

 return(false);
}


static CheatFormatStruct CheatFormats[] =
{
 { "Game Genie", gettext_noop("Genies will eat your goats."), DecodeGG },
 { "GameShark", gettext_noop("Sharks in your soup."), DecodeGS },
};

static CheatFormatInfoStruct CheatFormatInfo =
{
 2,
 CheatFormats
};

static void InstallReadPatch(uint32 address, uint8 value, int compare)
{

}

static void RemoveReadPatches(void)
{

}


static const FileExtensionSpecStruct KnownExtensions[] =
{
 { ".gb", gettext_noop("GameBoy ROM Image") },
 { ".gbc", gettext_noop("GameBoy Color ROM Image") },
 { ".cgb", gettext_noop("GameBoy Color ROM Image") },
 { NULL, NULL }
};

static const CustomPalette_Spec CPInfo[] =
{
 { gettext_noop("GameBoy(mono) palette"), NULL, { 4, 8, 12, 0 } },
 { gettext_noop("GameBoy Color 15-bit RGB"), "gbc", { 32768, 0 } },
 { NULL, NULL }
};

}

using namespace MDFN_IEN_GB;

MDFNGI EmulatedGB =
{
 "gb",
 "GameBoy (Color)",
 KnownExtensions,
 MODPRIO_INTERNAL_HIGH,
 NULL,
 PortInfo,
 Load,
 TestMagic,
 NULL,
 NULL,
 CloseGame,

 SetLayerEnableMask,
 "Background\0Sprites\0Window\0",

 NULL,
 NULL,

 CPInfo,
 0,

 InstallReadPatch,
 RemoveReadPatches,
 NULL,
 &CheatFormatInfo,
 false,
 StateAction,
 Emulate,
 NULL,
 MDFNGB_SetInput,
 NULL,
 DoSimpleCommand,
 GBSettings,
 MDFN_MASTERCLOCK_FIXED(4194304),
 (uint32)((double)4194304 / 70224 * 65536 * 256),
 FALSE, // Multires possible?

 160,	// lcm_width
 144,	// lcm_height
 NULL,	// Dummy

 160,	// Nominal width
 144,	// Nominal height

 160,	// Framebuffer width
 144,	// Framebuffer height

 2,     // Number of output sound channels
};
