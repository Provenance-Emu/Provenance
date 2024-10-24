/******************************************************************************/
/* Mednafen Apple II Emulation Module                                         */
/******************************************************************************/
/* kbio.cpp:
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

// Apple II/II+ AY-5-3600 notes:
//
//	FIXME: H+T+R,R,R,R,R vs R+T+H,H,H,H,H,H
//        G+R+E,E,E,E,E vs E+R+G,G,G,G,G,G
//
//        Keys:   Depress H(ascii: H), depress T(ascii: T), depress J(ascii: RJ), release J, depress J(ascii: R), release J, depress J(ascii: R)
//	  
//	  3+Q, +9=
//
//	Something really fishy with triangle patterns in X1 and X2...
//
//	 4-key groups with weirdness on real hardware(or my real hardware, which could be malfunctioning?):
//		H, T, R, J
//		BS, P, O, NAK
//
//		D, O, I is sometimes generating a U character? WTF? (dirty keyboard, marginal something?)

// Apple IIe notes:
//	534-801ms delay for key repeat
//	key repeat at 15Hz

#include "apple2.h"
#include "kbio.h"

namespace MDFN_IEN_APPLE2
{
namespace KBIO
{
// normal, shift, control, shift+control
#define KBTAB_ALPHA(c) { (c), (c), (c) - 'A' + 0x01, (c) - 'A' + 0x01 }
#define KBTAB_N(n) { (n), (n), (n), (n) }
#define KBTAB_NS(n,s) { (n), (s), (n), (s) }
#define KBTAB_NSCCS(n,s,c,cs) { (n), (s), (c), (cs) }

#define KBTAB_EMPTY { 0, 0, 0, 0 }

// Apple II/II+ AY-5-3600 key to ASCII table:
static const uint8 KBTab[90][4] =
{
 /* Y0   */
 /*   X0 */ KBTAB_NS('3', '#'),
 /*   X1 */ KBTAB_ALPHA('Q'),
 /*   X2 */ KBTAB_ALPHA('D'),
 /*   X3 */ KBTAB_ALPHA('Z'),
 /*   X4 */ KBTAB_ALPHA('S'),
 /*   X5 */   KBTAB_EMPTY,
 /*   X6 */   KBTAB_EMPTY,
 /*   X7 */   KBTAB_EMPTY,
 /*   X8 */   KBTAB_EMPTY,

 /* Y1   */
 /*   X0 */ KBTAB_NS('4', '$'),
 /*   X1 */ KBTAB_ALPHA('W'),
 /*   X2 */ KBTAB_ALPHA('F'),
 /*   X3 */ KBTAB_ALPHA('X'),
 /*   X4 */ KBTAB_NS('2', '"'),
 /*   X5 */   KBTAB_EMPTY,
 /*   X6 */   KBTAB_EMPTY,
 /*   X7 */   KBTAB_EMPTY,
 /*   X8 */   KBTAB_EMPTY,

 /* Y2   */
 /*   X0 */ KBTAB_NS('5', '%'),
 /*   X1 */ KBTAB_ALPHA('E'),
 /*   X2 */ KBTAB_ALPHA('G'),
 /*   X3 */ KBTAB_ALPHA('C'),
 /*   X4 */ KBTAB_NS('1', '!'),
 /*   X5 */   KBTAB_EMPTY,
 /*   X6 */   KBTAB_EMPTY,
 /*   X7 */   KBTAB_EMPTY,
 /*   X8 */   KBTAB_EMPTY,

 /* Y3   */
 /*   X0 */ KBTAB_NS('6', '&'),
 /*   X1 */ KBTAB_ALPHA('R'),
 /*   X2 */ KBTAB_ALPHA('H'),
 /*   X3 */ KBTAB_ALPHA('V'),
 /*   X4 */ KBTAB_N(0x1B),
 /*   X5 */   KBTAB_EMPTY,
 /*   X6 */   KBTAB_EMPTY,
 /*   X7 */   KBTAB_EMPTY,
 /*   X8 */   KBTAB_EMPTY,

 /* Y4   */
 /*   X0 */ KBTAB_NS('7', '\''),
 /*   X1 */ KBTAB_ALPHA('T'),
 /*   X2 */ KBTAB_ALPHA('J'),
 /*   X3 */ KBTAB_ALPHA('B'),
 /*   X4 */ KBTAB_ALPHA('A'),
 /*   X5 */   KBTAB_EMPTY,
 /*   X6 */   KBTAB_EMPTY,
 /*   X7 */   KBTAB_EMPTY,
 /*   X8 */   KBTAB_EMPTY,

 /* Y5   */
 /*   X0 */ KBTAB_NS('8', '('),
 /*   X1 */ KBTAB_ALPHA('Y'),
 /*   X2 */ KBTAB_ALPHA('K'),
 /*   X3 */ KBTAB_NSCCS('N', '^', 0x0E, 0x1E),
 /*   X4 */ KBTAB_N(0x20),
 /*   X5 */   KBTAB_EMPTY,
 /*   X6 */   KBTAB_EMPTY,
 /*   X7 */   KBTAB_EMPTY,
 /*   X8 */   KBTAB_EMPTY,

 /* Y6   */
 /*   X0 */ KBTAB_NS('9', ')'),
 /*   X1 */ KBTAB_ALPHA('U'),
 /*   X2 */ KBTAB_ALPHA('L'),
 /*   X3 */ KBTAB_NSCCS('M', ']', 0x0D, 0x1D),
 /*   X4 */   KBTAB_EMPTY,
 /*   X5 */   KBTAB_EMPTY,
 /*   X6 */   KBTAB_EMPTY,
 /*   X7 */   KBTAB_EMPTY,
 /*   X8 */   KBTAB_EMPTY,

 /* Y7   */
 /*   X0 */ KBTAB_N('0'),
 /*   X1 */ KBTAB_ALPHA('I'),
 /*   X2 */ KBTAB_NS(';', '+'),
 /*   X3 */ KBTAB_NS(',', '<'),
 /*   X4 */   KBTAB_EMPTY,
 /*   X5 */   KBTAB_EMPTY,
 /*   X6 */   KBTAB_EMPTY,
 /*   X7 */   KBTAB_EMPTY,
 /*   X8 */   KBTAB_EMPTY,

 /* Y8   */
 /*   X0 */ KBTAB_NS(':', '*'),
 /*   X1 */ KBTAB_ALPHA('O'),
 /*   X2 */ KBTAB_N(0x08),
 /*   X3 */ KBTAB_NS('.', '>'),
 /*   X4 */   KBTAB_EMPTY,
 /*   X5 */   KBTAB_EMPTY,
 /*   X6 */   KBTAB_EMPTY,
 /*   X7 */   KBTAB_EMPTY,
 /*   X8 */   KBTAB_EMPTY,

 /* Y9   */
 /*   X0 */ KBTAB_NS('-', '='),
 /*   X1 */ KBTAB_NSCCS('P', '@', 0x10, 0x00),
 /*   X2 */ KBTAB_N(0x15),
 /*   X3 */ KBTAB_NS('/', '?'),
 /*   X4 */ KBTAB_N(0x0D),
 /*   X5 */   KBTAB_EMPTY,
 /*   X6 */   KBTAB_EMPTY,
 /*   X7 */   KBTAB_EMPTY,
 /*   X8 */   KBTAB_EMPTY,
};

static const uint8 KBTab_IIE[90][4] =
{
 /* Y0   */
 /*   X0 */ KBTAB_N(0x1B),
 /*   X1 */ KBTAB_N(0x09),
 /*   X2 */ KBTAB_ALPHA('A'),
 /*   X3 */ KBTAB_ALPHA('Z'),
 /*   X4 */   KBTAB_EMPTY,
 /*   X5 */   KBTAB_EMPTY,
 /*   X6 */   KBTAB_EMPTY,
 /*   X7 */   KBTAB_EMPTY,
 /*   X8 */   KBTAB_EMPTY,

 /* Y1   */
 /*   X0 */ KBTAB_NS('1', '!'),
 /*   X1 */ KBTAB_ALPHA('Q'),
 /*   X2 */ KBTAB_ALPHA('D'),
 /*   X3 */ KBTAB_ALPHA('X'),
 /*   X4 */   KBTAB_EMPTY,
 /*   X5 */   KBTAB_EMPTY,
 /*   X6 */   KBTAB_EMPTY,
 /*   X7 */   KBTAB_EMPTY,
 /*   X8 */   KBTAB_EMPTY,

 /* Y2   */
 /*   X0 */ KBTAB_NSCCS('2', '@', 0x00, 0x00),
 /*   X1 */ KBTAB_ALPHA('W'),
 /*   X2 */ KBTAB_ALPHA('S'),
 /*   X3 */ KBTAB_ALPHA('C'),
 /*   X4 */   KBTAB_EMPTY,
 /*   X5 */   KBTAB_EMPTY,
 /*   X6 */   KBTAB_EMPTY,
 /*   X7 */   KBTAB_EMPTY,
 /*   X8 */   KBTAB_EMPTY,

 /* Y3   */
 /*   X0 */ KBTAB_NS('3', '#'),
 /*   X1 */ KBTAB_ALPHA('E'),
 /*   X2 */ KBTAB_ALPHA('H'),
 /*   X3 */ KBTAB_ALPHA('V'),
 /*   X4 */   KBTAB_EMPTY,
 /*   X5 */   KBTAB_EMPTY,
 /*   X6 */   KBTAB_EMPTY,
 /*   X7 */   KBTAB_EMPTY,
 /*   X8 */   KBTAB_EMPTY,

 /* Y4   */
 /*   X0 */ KBTAB_NS('4', '$'),
 /*   X1 */ KBTAB_ALPHA('R'),
 /*   X2 */ KBTAB_ALPHA('F'),
 /*   X3 */ KBTAB_ALPHA('B'),
 /*   X4 */   KBTAB_EMPTY,
 /*   X5 */   KBTAB_EMPTY,
 /*   X6 */   KBTAB_EMPTY,
 /*   X7 */   KBTAB_EMPTY,
 /*   X8 */   KBTAB_EMPTY,

 /* Y5   */
 /*   X0 */ KBTAB_NSCCS('6', '^', 0x1E, 0x1E),
 /*   X1 */ KBTAB_ALPHA('Y'),
 /*   X2 */ KBTAB_ALPHA('G'),
 /*   X3 */ KBTAB_ALPHA('N'),
 /*   X4 */   KBTAB_EMPTY,
 /*   X5 */   KBTAB_EMPTY,
 /*   X6 */   KBTAB_EMPTY,
 /*   X7 */   KBTAB_EMPTY,
 /*   X8 */   KBTAB_EMPTY,

 /* Y6   */
 /*   X0 */ KBTAB_NS('5', '%'),
 /*   X1 */ KBTAB_ALPHA('T'),
 /*   X2 */ KBTAB_ALPHA('J'),
 /*   X3 */ KBTAB_ALPHA('M'),
 /*   X4 */ KBTAB_NSCCS('\\', '|', 0x1C, 0x1C),
 /*   X5 */ KBTAB_NS('`', '~'),
 /*   X6 */ KBTAB_N(0x0D),
 /*   X7 */ KBTAB_N(0x7F),
 /*   X8 */   KBTAB_EMPTY,

 /* Y7   */
 /*   X0 */ KBTAB_NS('7', '&'),
 /*   X1 */ KBTAB_ALPHA('U'),
 /*   X2 */ KBTAB_ALPHA('K'),
 /*   X3 */ KBTAB_NS(',', '<'),
 /*   X4 */ KBTAB_NS('=', '+'),
 /*   X5 */ KBTAB_ALPHA('P'),
 /*   X6 */ KBTAB_N(0x0B),
 /*   X7 */ KBTAB_N(0x0A),
 /*   X8 */   KBTAB_EMPTY,

 /* Y8   */
 /*   X0 */ KBTAB_NS('8', '*'),
 /*   X1 */ KBTAB_ALPHA('I'),
 /*   X2 */ KBTAB_NS(';', ':'),
 /*   X3 */ KBTAB_NS('.', '>'),
 /*   X4 */ KBTAB_NS('0', ')'),
 /*   X5 */ KBTAB_NSCCS('[', '{', 0x1B, 0x1B),
 /*   X6 */ KBTAB_N(0x20),
 /*   X7 */ KBTAB_N(0x08),
 /*   X8 */   KBTAB_EMPTY,

 /* Y9   */
 /*   X0 */ KBTAB_NS('9', '('),
 /*   X1 */ KBTAB_ALPHA('O'),
 /*   X2 */ KBTAB_ALPHA('L'),
 /*   X3 */ KBTAB_NS('/', '?'),
 /*   X4 */ KBTAB_NSCCS('-', '_', 0x1F, 0x1F),
 /*   X5 */ KBTAB_NSCCS(']', '}', 0x1D, 0x1D),
 /*   X6 */ KBTAB_NS('\'', '"'),
 /*   X7 */ KBTAB_N(0x15),
 /*   X8 */   KBTAB_EMPTY,
};

static uint8 KBROM[0x800];

static uint8* KBInputPtr;
static bool KBInputIIE;
static bool EnableKeyGhosting;
static bool EnableAutoKeyRepeat;
//
//
//
static uint32 KBXtoY[9];
static bool KBInput_SHIFT;
static bool KBInput_CTRL;
static bool KBInput_RESET;
static bool KBInput_AKP;
static bool KBInput_REPT_AKP;	// true if REPT key is pressed while any other (non-SHIFT/CTRL/RESET) key is pressed
static bool KBInput_CAPSLOCK;

static bool KBInput_EnableKeyGhosting;
static bool KBInput_EnableAutoKeyRepeat;
//
static struct
{
 uint16 LastState[9];
 uint8 X;
 uint8 Y;
 uint32 StrobeDelayCounter;
 uint32 RepeatCounter;	// Probably should be abstracted separately, but this simplifies things.
 //bool AKD_Temp;
 //
 int32 curtime;
} KBScan;
//
static uint8 KBOutData;
//static bool KBAKD;
static uint8 KBARDelay;

static void UpdateScanProcess(void)
{
 while(KBScan.curtime < timestamp)
 {
  if(!KBInput_REPT_AKP)
   KBScan.RepeatCounter = 6000; // FIXME?
  else
  {
   KBScan.RepeatCounter--;
   if(!KBScan.RepeatCounter)
   {
    KBScan.RepeatCounter = 6000;
    KBOutData |= 0x80;
   }
  }

  if(KBScan.StrobeDelayCounter > 0)
  {
   KBScan.StrobeDelayCounter--;
   if(!KBScan.StrobeDelayCounter)
   {
    if(KBXtoY[KBScan.X] & (1U << KBScan.Y))	// Ensure key is still pressed.
    {
     KBOutData = 0x80 | KBROM[(!KBInput_CAPSLOCK << 9) + ((KBScan.X * 10 + KBScan.Y) * 4) + (!KBInput_SHIFT << 0) + (!KBInput_CTRL << 1)];
     KBARDelay = 0;
    }
   }
  }
  else
  {
   const bool newpress = ((KBScan.LastState[KBScan.X] ^ KBXtoY[KBScan.X]) & KBXtoY[KBScan.X]) & (1U << KBScan.Y);

   KBScan.LastState[KBScan.X] &= ~(1U << KBScan.Y);
   KBScan.LastState[KBScan.X] |= KBXtoY[KBScan.X] & (1U << KBScan.Y);

   if(newpress)
    KBScan.StrobeDelayCounter = 720;
   else
   {
    KBScan.X++;
    if(KBScan.X == 9)
    {
     KBScan.X = 0;
     KBScan.Y++;
     if(KBScan.Y == 10)
      KBScan.Y = 0;
    }
   }
  }

  KBScan.curtime += 159;
 }
 // clock is about 90khz, 1 cycle per X increment, 9 X increments per Y increment, and 10 Y compare values?
 // 8ms strobe delay when keypress detected...
}

// IIe
void ClockARDelay(void)
{
 UpdateScanProcess();
 //
 if(!KBInput_AKP)
  KBARDelay = 0;
 else if(KBARDelay < 3)
  KBARDelay++;
}

// IIe
void ClockAR(void)
{
 UpdateScanProcess();
 //
 if(!KBInput_AKP)
  KBARDelay = 0;
 else if(KBARDelay == 3)
 {
  if(KBInput_EnableAutoKeyRepeat)
   KBOutData |= 0x80;
 }
}

void EndTimePeriod(void)
{
 UpdateScanProcess();
 //
 assert(KBScan.curtime >= timestamp);
 KBScan.curtime -= timestamp;
}

static DEFREAD(ReadKBData)
{
 if(!InHLPeek)
 {
  CPUTick1();
  //
  UpdateScanProcess();
 }
 DB = KBOutData;
}

static DEFREAD(ReadClearKBStrobe_IIE)
{
 if(!InHLPeek)
 {
  CPUTick1();
  //
  UpdateScanProcess();
  KBOutData &= 0x7F;
 }

 DB = (KBOutData & 0x7F) | (KBInput_AKP << 7);
}

// Called from ReadSoftSwitchStatus_IIE() and ReadBSRStatus_IIE()
MDFN_HOT void Read_C011_C01F_IIE(void)
{
 if(!InHLPeek)
 {
  CPUTick1();
  //
  KBIO::UpdateScanProcess();
 }

 DB = (DB & 0x80) | (KBOutData & 0x7F);
}

static DEFREAD(WriteClearKBStrobe_IIE)
{
 if(!InHLPeek)
 {
  CPUTick1();
  //
  UpdateScanProcess();
  KBOutData &= 0x7F;
 }
}

static DEFRW(RWClearKBStrobe)
{
 if(!InHLPeek)
 {
  CPUTick1();
  //
  UpdateScanProcess();
  KBOutData &= 0x7F;
 }
}

void TransformInput(void)
{
 KBInputPtr[11] = (KBInputPtr[11] &~ 0x80) | (!EnableKeyGhosting << 7);

 if(KBInputIIE)
  KBInputPtr[11] = (KBInputPtr[11] &~ 0x20) | (!EnableAutoKeyRepeat << 5);
}

bool UpdateInput(uint8* kb_pb)
{
 const uint8 scr = KBInputPtr[11] >> 2;

 KBInput_SHIFT = (bool)(scr & 0x3);
 KBInput_CTRL = (bool)(scr & 0x4);
 KBInput_RESET = (bool)(scr & 0x10);

 KBInput_EnableKeyGhosting = !(bool)(scr & 0x20);

 *kb_pb = 0;
 KBInput_CAPSLOCK = false;

 if(KBInputIIE)
 {
  const uint8 cal = KBInputPtr[12];

  *kb_pb |= cal & 0x3;
  KBInput_CAPSLOCK = (bool)(cal & 0x04);
 }

 //
 // x output, y input
 //
 for(int x = 0; x < 9; x++)
 {
  KBXtoY[x] = 0;
  for(int y = 0; y < 10; y++)
  {
   const unsigned bp = y * 9 + x;

   if(KBInputPtr[bp >> 3] & (1U << (bp & 0x7)))
   {
    KBXtoY[x] |= 1U << y;
    //printf("%d %d\n", x, y);
   }
  }
 }

 if(KBInput_EnableKeyGhosting)
 {
  for(int x = 0; x < 9; x++)
  {
   for(int other_x = 0; other_x < 9; other_x++)
   {
    if(KBXtoY[x] & KBXtoY[other_x])
    {
     KBXtoY[x] = KBXtoY[other_x] = (KBXtoY[x] | KBXtoY[other_x]);
    }
   }
  }
 }

 KBInput_AKP = false;
 for(unsigned x = 0; x < 9; x++)
  KBInput_AKP |= (bool)(KBXtoY[x]);

 if(KBInputIIE)
 {
  KBInput_REPT_AKP = false;
  KBInput_EnableAutoKeyRepeat = !(bool)(scr & 0x08);
 }
 else
  KBInput_REPT_AKP = KBInput_AKP & (bool)(scr & 0x08);

 //printf("%d\n", KBInput_REPT_AKP);

 //
 //
 //
 return KBInput_CTRL && KBInput_RESET;
}

void SetInput(const char* type, uint8* p)
{
 KBInputPtr = p;
 KBInputIIE = !strcmp(type, "iie");
}

void Power(void)
{
 for(unsigned x = 0; x < 9; x++)
  KBScan.LastState[x] = 0;

 KBScan.X = 0;
 KBScan.Y = 0;
 KBScan.StrobeDelayCounter = 0;
 KBScan.RepeatCounter = 1;

 KBOutData = 0x00;
 KBARDelay = 0;
}

void Kill(void)
{

}

void StateAction(StateMem* sm, const unsigned load, const bool data_only)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(KBScan.LastState),
  SFVAR(KBScan.X),
  SFVAR(KBScan.Y),
  SFVAR(KBScan.StrobeDelayCounter),
  SFVAR(KBScan.RepeatCounter),
  SFVAR(KBOutData),
  SFVAR(KBARDelay),

  SFVAR(KBScan.curtime),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "KBIO");

 if(load)
 {
  KBScan.X %= 9;
  KBScan.Y %= 10;
 }
}

void SetKeyGhosting(bool enabled)
{
 EnableKeyGhosting = enabled;
}

void SetAutoKeyRepeat(bool enabled)
{
 EnableAutoKeyRepeat = enabled;
}

void SetDecodeROM(uint8* p, bool iie)
{
 if(p)
  memcpy(KBROM, p, 0x800);
 else if(iie)
 {
  memset(KBROM, 0, sizeof(KBROM));

  for(unsigned y = 0; y < 10; y++)
  {
   for(unsigned x = 0; x < 9; x++)
   {
    for(unsigned shift = 0; shift < 2; shift++)
    {
     for(unsigned ctrl = 0; ctrl < 2; ctrl++)
     {
      const bool capslock = false;
      uint8 tmp;

      tmp = KBTab_IIE[(y * 9 + x)][(ctrl << 1) + (shift << 0)];

      KBROM[( !capslock << 9) + ((x * 10 + y) * 4) + (!ctrl << 1) + (!shift << 0)] = (shift ? tmp : MDFN_azlower(tmp));
      KBROM[(!!capslock << 9) + ((x * 10 + y) * 4) + (!ctrl << 1) + (!shift << 0)] = MDFN_azupper(tmp);
     }
    }
   }
  }
 }
 else
 {
  memset(KBROM, 0, sizeof(KBROM));

  for(unsigned y = 0; y < 10; y++)
  {
   for(unsigned x = 0; x < 9; x++)
   {
    for(unsigned shift = 0; shift < 2; shift++)
    {
     for(unsigned ctrl = 0; ctrl < 2; ctrl++)
     {
      const bool capslock = false;
      uint8 tmp;

      tmp = KBTab[(y * 9 + x)][(ctrl << 1) + (shift << 0)];

      KBROM[( !capslock << 9) + ((x * 10 + y) * 4) + (!ctrl << 1) + (!shift << 0)] = tmp;
      KBROM[(!!capslock << 9) + ((x * 10 + y) * 4) + (!ctrl << 1) + (!shift << 0)] = tmp;
     }
    }
   }
  }
 }
}

void Init(const bool emulate_iie)
{
 if(emulate_iie)
 {
  // Keyboard data input
  for(unsigned A = 0xC000; A < 0xC010; A++)
   SetReadHandler(A, ReadKBData);

  // Clear keyboard strobe
  SetReadHandler(0xC010, ReadClearKBStrobe_IIE);

  for(unsigned A = 0xC010; A < 0xC020; A++)
   SetWriteHandler(A, WriteClearKBStrobe_IIE);
 }
 else
 {
  // Keyboard data input
  for(unsigned A = 0xC000; A < 0xC010; A++)
   SetReadHandler(A, ReadKBData);

  // Clear keyboard strobe
  for(unsigned A = 0xC010; A < 0xC020; A++)
   SetRWHandlers(A, RWClearKBStrobe, RWClearKBStrobe);
 }
 //
 //
 KBScan.curtime = 0;
}

static const IDIISG IODevice_Keyboard_Twopiece_IDII =
{
 /* Y0   */
 /*   X0 */ IDIIS_Button("3", "3", -1),
 /*   X1 */ IDIIS_Button("q", "Q", -1),
 /*   X2 */ IDIIS_Button("d", "D", -1),
 /*   X3 */ IDIIS_Button("z", "Z", -1),
 /*   X4 */ IDIIS_Button("s", "S", -1),
 /*   X5 */   IDIIS_Padding<1>(),
 /*   X6 */   IDIIS_Padding<1>(),
 /*   X7 */   IDIIS_Padding<1>(),
 /*   X8 */   IDIIS_Padding<1>(),

 /* Y1   */
 /*   X0 */ IDIIS_Button("4", "4", -1),
 /*   X1 */ IDIIS_Button("w", "W", -1), 
 /*   X2 */ IDIIS_Button("f", "F", -1),
 /*   X3 */ IDIIS_Button("x", "X", -1),
 /*   X4 */ IDIIS_Button("2", "2", -1),
 /*   X5 */   IDIIS_Padding<1>(),
 /*   X6 */   IDIIS_Padding<1>(),
 /*   X7 */   IDIIS_Padding<1>(),
 /*   X8 */   IDIIS_Padding<1>(),

 /* Y2   */
 /*   X0 */ IDIIS_Button("5", "5", -1),
 /*   X1 */ IDIIS_Button("e", "E", -1),
 /*   X2 */ IDIIS_Button("g", "G", -1),
 /*   X3 */ IDIIS_Button("c", "C", -1),
 /*   X4 */ IDIIS_Button("1", "1", -1),
 /*   X5 */   IDIIS_Padding<1>(),
 /*   X6 */   IDIIS_Padding<1>(),
 /*   X7 */   IDIIS_Padding<1>(),
 /*   X8 */   IDIIS_Padding<1>(),

 /* Y3   */
 /*   X0 */ IDIIS_Button("6", "6", -1),
 /*   X1 */ IDIIS_Button("r", "R", -1),
 /*   X2 */ IDIIS_Button("h", "H", -1),
 /*   X3 */ IDIIS_Button("v", "V", -1),
 /*   X4 */ IDIIS_Button("esc", "ESC", -1),
 /*   X5 */   IDIIS_Padding<1>(),
 /*   X6 */   IDIIS_Padding<1>(),
 /*   X7 */   IDIIS_Padding<1>(),
 /*   X8 */   IDIIS_Padding<1>(),

 /* Y4   */
 /*   X0 */ IDIIS_Button("7", "7", -1),
 /*   X1 */ IDIIS_Button("t", "T", -1),
 /*   X2 */ IDIIS_Button("j", "J", -1),
 /*   X3 */ IDIIS_Button("b", "B", -1),
 /*   X4 */ IDIIS_Button("a", "A", -1),
 /*   X5 */   IDIIS_Padding<1>(),
 /*   X6 */   IDIIS_Padding<1>(),
 /*   X7 */   IDIIS_Padding<1>(),
 /*   X8 */   IDIIS_Padding<1>(),

 /* Y5   */
 /*   X0 */ IDIIS_Button("8", "8", -1),
 /*   X1 */ IDIIS_Button("y", "Y", -1),
 /*   X2 */ IDIIS_Button("k", "K", -1),
 /*   X3 */ IDIIS_Button("n", "N", -1),
 /*   X4 */ IDIIS_Button("sp", "Space", -1),
 /*   X5 */   IDIIS_Padding<1>(),
 /*   X6 */   IDIIS_Padding<1>(),
 /*   X7 */   IDIIS_Padding<1>(),
 /*   X8 */   IDIIS_Padding<1>(),

 /* Y6   */
 /*   X0 */ IDIIS_Button("9", "9", -1),
 /*   X1 */ IDIIS_Button("u", "U", -1),
 /*   X2 */ IDIIS_Button("l", "L", -1),
 /*   X3 */ IDIIS_Button("m", "M", -1),
 /*   X4 */   IDIIS_Padding<1>(),
 /*   X5 */   IDIIS_Padding<1>(),
 /*   X6 */   IDIIS_Padding<1>(),
 /*   X7 */   IDIIS_Padding<1>(),
 /*   X8 */   IDIIS_Padding<1>(),

 /* Y7   */
 /*   X0 */ IDIIS_Button("0", "0", -1),
 /*   X1 */ IDIIS_Button("i", "I", -1),
 /*   X2 */ IDIIS_Button("semicolon", ";", -1),
 /*   X3 */ IDIIS_Button("comma", ",", -1),
 /*   X4 */   IDIIS_Padding<1>(),
 /*   X5 */   IDIIS_Padding<1>(),
 /*   X6 */   IDIIS_Padding<1>(),
 /*   X7 */   IDIIS_Padding<1>(),
 /*   X8 */   IDIIS_Padding<1>(),

 /* Y8   */
 /*   X0 */ IDIIS_Button("colon", ":", -1),
 /*   X1 */ IDIIS_Button("o", "O", -1),
 /*   X2 */ IDIIS_Button("bs", "⭠", -1),
 /*   X3 */ IDIIS_Button("period", ".", -1),
 /*   X4 */   IDIIS_Padding<1>(),
 /*   X5 */   IDIIS_Padding<1>(),
 /*   X6 */   IDIIS_Padding<1>(),
 /*   X7 */   IDIIS_Padding<1>(),
 /*   X8 */   IDIIS_Padding<1>(),

 /* Y9   */
 /*   X0 */ IDIIS_Button("minus", "-", -1),
 /*   X1 */ IDIIS_Button("p", "P", -1),
 /*   X2 */ IDIIS_Button("nak", "⭢", -1),
 /*   X3 */ IDIIS_Button("slash", "/", -1),
 /*   X4 */ IDIIS_Button("cr", "RETURN", -1),
 /*   X5 */   IDIIS_Padding<1>(),
 /*   X6 */   IDIIS_Padding<1>(),
 /*   X7 */   IDIIS_Padding<1>(),
 /*   X8 */   IDIIS_Padding<1>(),

 /*****************************************/
 IDIIS_Button("lshift", "Left SHIFT", -1),
 IDIIS_Button("rshift", "Right SHIFT", -1),
 IDIIS_Button("ctrl", "CTRL", -1),
 IDIIS_Button("rept", "REPT", -1),
 IDIIS_Button("reset", "RESET", -1),
 IDIIS_Padding<1>(), // Reserved for KBInput_EnableKeyGhosting
};

static const IDIIS_SwitchPos CapsLockPositions[] =
{
 { "off", gettext_noop("Off"), gettext_noop("Lowercase") },
 { "on", gettext_noop("On"), gettext_noop("Uppercase") },
};

static const IDIISG IODevice_Keyboard_IIe_IDII =
{
 /* Y0   */
 /*   X0 */ IDIIS_Button("esc", "ESC", -1),
 /*   X1 */ IDIIS_Button("tab", "TAB", -1),
 /*   X2 */ IDIIS_Button("a", "A", -1),
 /*   X3 */ IDIIS_Button("z", "Z", -1),
 /*   X4 */   IDIIS_Padding<1>(),
 /*   X5 */   IDIIS_Padding<1>(),
 /*   X6 */   IDIIS_Padding<1>(),
 /*   X7 */   IDIIS_Padding<1>(),
 /*   X8 */   IDIIS_Padding<1>(),

 /* Y1   */
 /*   X0 */ IDIIS_Button("1", "1", -1),
 /*   X1 */ IDIIS_Button("q", "Q", -1),
 /*   X2 */ IDIIS_Button("d", "D", -1),
 /*   X3 */ IDIIS_Button("x", "X", -1),
 /*   X4 */   IDIIS_Padding<1>(),
 /*   X5 */   IDIIS_Padding<1>(),
 /*   X6 */   IDIIS_Padding<1>(),
 /*   X7 */   IDIIS_Padding<1>(),
 /*   X8 */   IDIIS_Padding<1>(),

 /* Y2   */
 /*   X0 */ IDIIS_Button("2", "2", -1),
 /*   X1 */ IDIIS_Button("w", "W", -1),
 /*   X2 */ IDIIS_Button("s", "S", -1),
 /*   X3 */ IDIIS_Button("c", "C", -1),
 /*   X4 */   IDIIS_Padding<1>(),
 /*   X5 */   IDIIS_Padding<1>(),
 /*   X6 */   IDIIS_Padding<1>(),
 /*   X7 */   IDIIS_Padding<1>(),
 /*   X8 */   IDIIS_Padding<1>(),

 /* Y3   */
 /*   X0 */ IDIIS_Button("3", "3", -1),
 /*   X1 */ IDIIS_Button("e", "E", -1),
 /*   X2 */ IDIIS_Button("h", "H", -1),
 /*   X3 */ IDIIS_Button("v", "V", -1),
 /*   X4 */   IDIIS_Padding<1>(),
 /*   X5 */   IDIIS_Padding<1>(),
 /*   X6 */   IDIIS_Padding<1>(),
 /*   X7 */   IDIIS_Padding<1>(),
 /*   X8 */   IDIIS_Padding<1>(),

 /* Y4   */
 /*   X0 */ IDIIS_Button("4", "4", -1),
 /*   X1 */ IDIIS_Button("r", "R", -1),
 /*   X2 */ IDIIS_Button("f", "F", -1),
 /*   X3 */ IDIIS_Button("b", "B", -1),
 /*   X4 */   IDIIS_Padding<1>(),
 /*   X5 */   IDIIS_Padding<1>(),
 /*   X6 */   IDIIS_Padding<1>(),
 /*   X7 */   IDIIS_Padding<1>(),
 /*   X8 */   IDIIS_Padding<1>(),

 /* Y5   */
 /*   X0 */ IDIIS_Button("6", "6", -1),
 /*   X1 */ IDIIS_Button("y", "Y", -1),
 /*   X2 */ IDIIS_Button("g", "G", -1),
 /*   X3 */ IDIIS_Button("n", "N", -1),
 /*   X4 */   IDIIS_Padding<1>(),
 /*   X5 */   IDIIS_Padding<1>(),
 /*   X6 */   IDIIS_Padding<1>(),
 /*   X7 */   IDIIS_Padding<1>(),
 /*   X8 */   IDIIS_Padding<1>(),

 /* Y6   */
 /*   X0 */ IDIIS_Button("5", "5", -1),
 /*   X1 */ IDIIS_Button("t", "T", -1),
 /*   X2 */ IDIIS_Button("j", "J", -1),
 /*   X3 */ IDIIS_Button("m", "M", -1),
 /*   X4 */ IDIIS_Button("backslash", "Backslash \\", -1),
 /*   X5 */ IDIIS_Button("grave", "Grave `", -1),
 /*   X6 */ IDIIS_Button("cr", "RETURN", -1),
 /*   X7 */ IDIIS_Button("delete", "DELETE", -1),
 /*   X8 */   IDIIS_Padding<1>(),

 /* Y7   */
 /*   X0 */ IDIIS_Button("7", "", -1),
 /*   X1 */ IDIIS_Button("u", "", -1),
 /*   X2 */ IDIIS_Button("k", "", -1),
 /*   X3 */ IDIIS_Button("comma", "Comma ,", -1),
 /*   X4 */ IDIIS_Button("equals", "Equals =", -1),
 /*   X5 */ IDIIS_Button("p", "P", -1),
 /*   X6 */ IDIIS_Button("vt", "Up ⭡", -1),
 /*   X7 */ IDIIS_Button("lf", "Down ⭣", -1),
 /*   X8 */   IDIIS_Padding<1>(),

 /* Y8   */
 /*   X0 */ IDIIS_Button("8", "", -1),
 /*   X1 */ IDIIS_Button("i", "I", -1),
 /*   X2 */ IDIIS_Button("semicolon", "Semicolon ;", -1),
 /*   X3 */ IDIIS_Button("period", "Period .", -1),
 /*   X4 */ IDIIS_Button("0", "0", -1),
 /*   X5 */ IDIIS_Button("leftbracket", "Left Bracket [", -1),
 /*   X6 */ IDIIS_Button("sp", "Space", -1),
 /*   X7 */ IDIIS_Button("bs", "Left ⭠", -1),
 /*   X8 */   IDIIS_Padding<1>(),

 /* Y9   */
 /*   X0 */ IDIIS_Button("9", "9", -1),
 /*   X1 */ IDIIS_Button("o", "O", -1),
 /*   X2 */ IDIIS_Button("l", "L", -1),
 /*   X3 */ IDIIS_Button("slash", "Slash /", -1),
 /*   X4 */ IDIIS_Button("minus", "Minus -", -1),
 /*   X5 */ IDIIS_Button("rightbracket", "Right Bracket ]", -1),
 /*   X6 */ IDIIS_Button("quote", "Quote '", -1),
 /*   X7 */ IDIIS_Button("nak", "Right ⭢", -1),
 /*   X8 */   IDIIS_Padding<1>(),

 /*****************************************/
 IDIIS_Button("lshift", "Left SHIFT", -1),
 IDIIS_Button("rshift", "Right SHIFT", -1),
 IDIIS_Button("ctrl", "CONTROL", -1),
 IDIIS_Padding<1>(), // Reserved for KBInput_EnableAutoKeyRepeat
 IDIIS_Button("reset", "RESET", -1),
 IDIIS_Padding<1>(), // Reserved for KBInput_EnableKeyGhosting
 //
 IDIIS_Button("oapple", "Open Apple ○", -1),
 IDIIS_Button("capple", "Closed Apple ●", -1),
 IDIIS_Switch<2, 1>("capslock", "CAPS LOCK", -1, CapsLockPositions, false),
};



const std::vector<InputDeviceInfoStruct> InputDeviceInfoA2KBPort =
{
 // Apple II/II+ 2-piece keyboard
 {
  "iip",
  gettext_noop("Apple II/II+ 2-piece keyboard"),
  gettext_noop("Standard Apple II/II+ 2-piece keyboard, with AY-5-3600 encoder.  The frustration caused by trying to use a decades-old metal sheet keyboard variant is not emulated."),
  IODevice_Keyboard_Twopiece_IDII,
  InputDeviceInfoStruct::FLAG_KEYBOARD | InputDeviceInfoStruct::FLAG_UNIQUE
 },

#if 0
 // Apple II 1-piece keyboard
 {
  "ii",
  gettext_noop("Apple II 1-piece keyboard"),
  gettext_noop("Early Apple II 1-piece keyboard, with MM5740-AAE encoder."),
  IODevice_Keyboard_Onepiece_IDII,
  InputDeviceInfoStruct::FLAG_KEYBOARD | InputDeviceInfoStruct::FLAG_UNIQUE
 },
#endif

 // Apple IIe keyboard
 {
  "iie",
  gettext_noop("Apple IIe keyboard"),
  gettext_noop("Standard Apple IIe keyboard."),
  IODevice_Keyboard_IIe_IDII,
  InputDeviceInfoStruct::FLAG_KEYBOARD | InputDeviceInfoStruct::FLAG_UNIQUE
 },
};

//
//
}
}
