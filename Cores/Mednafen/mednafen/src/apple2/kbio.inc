/******************************************************************************/
/* Mednafen Apple II Emulation Module                                         */
/******************************************************************************/
/* kbio.inc:
**  Copyright (C) 2018 Mednafen Team
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
 Tentative mappings(driver/frontend side):

  Host TAB and ESC -> Emulated ESC
  Host CAPS LOCK and CTRL -> Emulated CTRL
  Host MINUS -> Emulated COLON
  Host EQUALS -> Emulated MINUS
  Host ENTER and BACKSLASH -> Emulated RETURN
  Host SHIFT -> Emulated SHIFT
  Host SEMICOLON -> Emulated SEMICOLON
  Host COMMA -> Emulated COMMA
  Host PERIOD -> Emulated PERIOD
  Host SLASH -> Emulated SLASH
  Host CURSOR LEFT and BACKSPACE -> Emulated CURSOR LEFT
  Host CURSOR RIGHT -> Emulated CURSOR RIGHT
  Host OPEN BRACKET and ALT -> Emulated REPT
  Host INSERT -> Emulated RESET
*/
// FIXME: H+T+R,R,R,R,R vs R+T+H,H,H,H,H,H
//        G+R+E,E,E,E,E vs E+R+G,G,G,G,G,G
//
//        Keys:   Depress H(ascii: H), depress T(ascii: T), depress J(ascii: RJ), release J, depress J(ascii: R), release J, depress J(ascii: R)
//	  
//
//	  3+Q, +9=

//
// Something really fishy with triangle patterns in X1 and X2...
//
//  
//
//
//
/*
 4-key groups with weirdness on real hardware(or my real hardware, which could be malfunctioning?):
	H, T, R, J
	BS, P, O, NAK


	D, O, I is sometimes generating a U character? WTF? (dirty keyboard, marginal something?)

*/

namespace KBIO
{
// normal, shift, control, shift+control
#define KBTAB_ALPHA(c) { (c), (c), (c) - 'A' + 0x01, (c) - 'A' + 0x01 }
#define KBTAB_N(n) { (n), (n), (n), (n) }
#define KBTAB_NS(n,s) { (n), (s), (n), (s) }
#define KBTAB_NSCCS(n,s,c,cs) { (n), (s), (c), (cs) }

#define KBTAB_EMPTY { 0, 0, 0, 0 }

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

static uint8* KBInputPtr;
//
//
//
static uint32 KBXtoY[9];
static bool KBInput_SHIFT;
static bool KBInput_CTRL;
static bool KBInput_RESET;
static bool KBInput_REPT_AKP;	// true if REPT key is pressed while any other (non-SHIFT/CTRL/RESET) key is pressed
//
static struct
{
 uint16 LastState[9];
 uint8 X;
 uint8 Y;
 uint32 StrobeDelayCounter;
 uint32 RepeatCounter;	// Probably should be abstracted separately, but this simplifies things.
 //
 int32 curtime;
} KBScan;
//
static uint8 KBOutData;

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
     KBOutData = 0x80 | KBTab[(KBScan.Y * 9 + KBScan.X)][(KBInput_SHIFT << 0) + (KBInput_CTRL << 1)];
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

static void EndTimePeriod(void)
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

static DEFRW(RWClearKBStrobe)
{
 if(!InHLPeek)
 {
  UpdateScanProcess();
  KBOutData &= 0x7F;
  //
  CPUTick1();
 }
}

static bool UpdateInput(void)
{
 const uint8 scr = KBInputPtr[11] >> 2;

 KBInput_SHIFT = (bool)(scr & 0x3);
 KBInput_CTRL = (bool)(scr & 0x4);
 KBInput_RESET = (bool)(scr & 0x10);

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

 KBInput_REPT_AKP = false;
 for(unsigned x = 0; x < 9; x++)
  KBInput_REPT_AKP |= (bool)(KBXtoY[x]);
 KBInput_REPT_AKP &= (bool)(scr & 0x08);

 //printf("%d\n", KBInput_REPT_AKP);

 //
 //
 //
 return KBInput_CTRL && KBInput_RESET;
}

static void Init(void)
{
 // Keyboard data input
 for(unsigned A = 0xC000; A < 0xC010; A++)
  SetReadHandler(A, ReadKBData);

 // Clear keyboard strobe
 for(unsigned A = 0xC010; A < 0xC020; A++)
  SetRWHandlers(A, RWClearKBStrobe, RWClearKBStrobe);
 //
 //
 KBScan.curtime = 0;
}

static void Power(void)
{
 for(unsigned x = 0; x < 9; x++)
  KBScan.LastState[x] = 0;

 KBScan.X = 0;
 KBScan.Y = 0;
 KBScan.StrobeDelayCounter = 0;
 KBScan.RepeatCounter = 1;

 KBOutData = 0x00;
}

static void Kill(void)
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

  SFVAR(KBScan.curtime),

  SFEND
 };

 MDFNSS_StateAction(sm, load, data_only, StateRegs, "KBIO");

 if(load)
 {

 }
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
 /*   X0 */ IDIIS_Button("7", "7'", -1),
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
};

static const std::vector<InputDeviceInfoStruct> InputDeviceInfoA2KBPort =
{
 // Apple II/II+ 2-piece keyboard
 {
  "twopiece",
  gettext_noop("Apple II/II+ 2-piece keyboard"),
  gettext_noop("Standard Apple II/II+ 2-piece keyboard, with AY-5-3600 encoder.  The frustration caused by trying to use a decades-old metal sheet keyboard variant is not emulated."),
  IODevice_Keyboard_Twopiece_IDII,
  InputDeviceInfoStruct::FLAG_KEYBOARD
 },

#if 0
 // Apple II 1-piece keyboard
 {
  "onepiece",
  gettext_noop("Apple II 1-piece keyboard"),
  gettext_noop("Early Apple II 1-piece keyboard, with MM5740-AAE encoder."),
  IODevice_Keyboard_Onepiece_IDII,
  InputDeviceInfoStruct::FLAG_KEYBOARD
 },
#endif

#if 0
 // Apple IIe keyboard
 // TODO: ...or have a separate "apple2e" module?
 {
  "iie",
  gettext_noop("Apple IIe keyboard"),
  gettext_noop("Standard Apple IIe keyboard."),
  IODevice_Keyboard_IIe_IDII,
  InputDeviceInfoStruct::FLAG_KEYBOARD
 },
#endif

#if 0
 // TODO
 {
  "pcstyle",
  gettext_noop("Generic PC-Style Keyboard"),
  gettext_noop("Generic keyboard with layout similar to the IBM Enhanced Keyboard.")
  IODevice_Keyboard_PCStyle
 },
#endif
};

}
