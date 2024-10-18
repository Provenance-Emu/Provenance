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

#include "../pce.h"
#include "../input.h"
#include "tsushinkb.h"

namespace MDFN_IEN_PCE
{

class PCE_Input_TsushinKB : public PCE_Input_Device
{
 public:

 PCE_Input_TsushinKB();

 virtual void Power(int32 timestamp) override;
 virtual void Write(int32 timestamp, bool old_SEL, bool new_SEL, bool old_CLR, bool new_CLR) override;
 virtual uint8 Read(int32 timestamp) override;
 virtual void Update(const uint8* data) override;
 virtual int StateAction(StateMem *sm, int load, int data_only, const char *section_name) override;


 private:
 bool SEL, CLR;
 uint8 TsuKBState[16];
 uint8 TsuKBLatch[16 + 2 + 1];
 uint32 TsuKBIndex;
 bool last_capslock;
};

void PCE_Input_TsushinKB::Power(int32 timestamp)
{
 SEL = CLR = 0;
 memset(TsuKBState, 0, sizeof(TsuKBState));
 memset(TsuKBLatch, 0, sizeof(TsuKBLatch));
 TsuKBIndex = 0;
 last_capslock = 0;
}

PCE_Input_TsushinKB::PCE_Input_TsushinKB()
{
 Power(0);
}

void PCE_Input_TsushinKB::Update(const uint8* data)
{
 bool capslock = TsuKBState[0xE] & 0x10;
 bool new_capslock = data[0xE] & 0x10;

 if(!last_capslock && new_capslock)
  capslock ^= 1;

 for(int i = 0; i < 16; i++)
 {
  TsuKBState[i] = data[i];
 }

 TsuKBState[0xE] = (TsuKBState[0xE] & ~0x10) | (capslock ? 0x10 : 0x00);

 last_capslock = new_capslock;
}

uint8 PCE_Input_TsushinKB::Read(int32 timestamp)
{
 uint8 ret;

 ret = ((TsuKBLatch[TsuKBIndex] >> (SEL * 4)) & 0xF);

 return(ret);
}

void PCE_Input_TsushinKB::Write(int32 timestamp, bool old_SEL, bool new_SEL, bool old_CLR, bool new_CLR)
{
 SEL = new_SEL;
 CLR = new_CLR;

 //printf("Write: %d %d %d %d\n", old_SEL, new_SEL, old_CLR, new_CLR);

 if(!old_CLR && new_CLR)
 {
  TsuKBLatch[0] = 0x02;

  for(int i = 0; i < 16; i++)
   TsuKBLatch[i + 1] = TsuKBState[i] ^ 0xFF;

  TsuKBLatch[17] = 0x02;
  TsuKBIndex = 0;
  //puts("Latched");
 }
 else if(!old_SEL && new_SEL)
 {
  TsuKBIndex = (TsuKBIndex + 1) % 18;
  if(!TsuKBIndex)
  {
   for(int i = 0; i < 16; i++)
    TsuKBLatch[i + 1] = TsuKBState[i] ^ 0xFF;
  }
 }
}

int PCE_Input_TsushinKB::StateAction(StateMem *sm, int load, int data_only, const char *section_name)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(SEL),
  SFVAR(CLR),
  SFVAR(TsuKBState),
  SFVAR(TsuKBLatch),
  SFVAR(TsuKBIndex),
  SFVAR(last_capslock),
  SFEND
 };
 int ret =  MDFNSS_StateAction(sm, load, data_only, StateRegs, section_name);
 
 return(ret);
}

const IDIISG PCE_TsushinKBIDII = 
{
 // 0 - DONE!
 IDIIS_Button("kp_0", "Keypad 0", 0),
 IDIIS_Button("kp_1", "Keypad 1", 0),
 IDIIS_Button("kp_2", "Keypad 2", 0),
 IDIIS_Button("kp_3", "Keypad 3", 0),
 IDIIS_Button("kp_4", "Keypad 4", 0),
 IDIIS_Button("kp_5", "Keypad 5", 0),
 IDIIS_Button("kp_6", "Keypad 6", 0),
 IDIIS_Padding<1>(),

// 1 - DONE!
 IDIIS_Button("kp_8", "Keypad 8", 0),
 IDIIS_Button("kp_9", "Keypad 9", 0),
 IDIIS_Button("kp_multiply", "Keypad *", 0),
 IDIIS_Button("kp_plus", "Keypad +", 0),
 IDIIS_Button("kp_equals", "Keypad =", 0),
 IDIIS_Button("kp_comma", "Keypad ,", 0),
 IDIIS_Button("kp_period", "Keypad .", 0),
 IDIIS_Padding<1>(),

// 2 - DONE!
 IDIIS_Button("at", "@", 0),
 IDIIS_Button("a", "a", 0),
 IDIIS_Button("b", "b", 0),
 IDIIS_Button("c", "c", 0),
 IDIIS_Button("d", "d", 0),
 IDIIS_Button("e", "e", 0),
 IDIIS_Button("f", "f", 0),
 IDIIS_Padding<1>(),

// 3 - DONE!
 IDIIS_Button("h", "h", 0),
 IDIIS_Button("i", "i", 0),
 IDIIS_Button("j", "j", 0),
 IDIIS_Button("k", "k", 0),
 IDIIS_Button("l", "l", 0),
 IDIIS_Button("m", "m", 0),
 IDIIS_Button("n", "n", 0),
 IDIIS_Padding<1>(),
 
// 4 - DONE!
 IDIIS_Button("p", "p", 0),
 IDIIS_Button("q", "q", 0),
 IDIIS_Button("r", "r", 0),
 IDIIS_Button("s", "s", 0),
 IDIIS_Button("t", "t", 0),
 IDIIS_Button("u", "u", 0),
 IDIIS_Button("v", "v", 0),
 IDIIS_Padding<1>(),

// 5 - DONE!
 IDIIS_Button("x", "x", 0),
 IDIIS_Button("y", "y", 0),
 IDIIS_Button("z", "z", 0),
 IDIIS_Button("left_bracket", "[", 0),
 IDIIS_Button("yen", "Yen", 0),
 IDIIS_Button("right_bracket", "]", 0),
 IDIIS_Button("caret", "^", 0),
 IDIIS_Padding<1>(),

// 6 - DONE!
 IDIIS_Button("0", "0", 0),
 IDIIS_Button("1", "1", 0),
 IDIIS_Button("2", "2", 0),
 IDIIS_Button("3", "3", 0),
 IDIIS_Button("4", "4", 0),
 IDIIS_Button("5", "5", 0),
 IDIIS_Button("6", "6", 0),
 IDIIS_Padding<1>(),

// 7 - DONE!
 IDIIS_Button("8", "8", 0),
 IDIIS_Button("9", "9", 0),
 IDIIS_Button("colon", ":", 0),
 IDIIS_Button("semicolon", ";", 0),
 IDIIS_Button("comma", ",", 0),
 IDIIS_Button("period", ".", 0),
 IDIIS_Button("slash", "/", 0),
 IDIIS_Padding<1>(),

// 8 - DONE enough
 IDIIS_Button("clear", "clear", 0),
 IDIIS_Button("up", "up", 0),
 IDIIS_Button("right", "right", 0),
 IDIIS_Padding<1>(),			// Alternate backspace key on PC-88 keyboard???
 IDIIS_Button("grph", "GRPH", 0),
 IDIIS_Button("kana", "カナ", 0),
 IDIIS_Padding<1>(),			// Alternate shift key on PC-88 keyboard???
 IDIIS_Padding<1>(),

// 9 - DONE!
 IDIIS_Button("stop", "STOP", 0),	// Break / STOP
 IDIIS_Button("f1", "F1", 0),
 IDIIS_Button("f2", "F2", 0),
 IDIIS_Button("f3", "F3", 0),
 IDIIS_Button("f4", "F4", 0),
 IDIIS_Button("f5", "F5", 0),
 IDIIS_Button("space", "space", 0),
 IDIIS_Padding<1>(),

// A - DONE!
 IDIIS_Button("tab", "Tab", 0),		// Tab
 IDIIS_Button("down", "down", 0),
 IDIIS_Button("left", "left", 0),
 IDIIS_Button("help", "Help", 0),	// -624
 IDIIS_Button("copy", "Copy", 0),	// -623
 IDIIS_Button("kp_minus", "Keypad Minus", 0),
 IDIIS_Button("kp_divide", "Keypad Divide", 0),
 IDIIS_Padding<1>(),

 // B - DONE(most likely)
 IDIIS_Button("roll_down", "ROLL DOWN", 0),
 IDIIS_Button("roll_up", "ROLL UP", 0),
 IDIIS_Padding<1>(),			// unknownB2
 IDIIS_Padding<1>(),			// unknownB3
 IDIIS_Button("o", "o", 0),
 IDIIS_Button("underscore", "Underscore", 0),
 IDIIS_Button("g", "g", 0),
 IDIIS_Padding<1>(),

// C - DONE!
 IDIIS_Button("f6", "f6", 0),
 IDIIS_Button("f7", "f7", 0),
 IDIIS_Button("f8", "f8", 0),
 IDIIS_Button("f9", "f9", 0),
 IDIIS_Button("f10", "F10", 0),
 IDIIS_Button("backspace", "backspace", 0),
 IDIIS_Button("insert", "insert", 0),
 IDIIS_Padding<1>(),

// D - DONE!
 IDIIS_Button("convert", "変換", 0),		// (-620) Begin marking entered text, and disable marking after pressing the 
					    	// end-of-block key.
 IDIIS_Button("nonconvert", "決定", 0),		// (-619) End text marking block
 IDIIS_Button("pc", "PC", 0),			// (-617) Selects between Rgana and Rkana.  SHIFT+this key switches between
					   	// latin and kana/gana mode?
 IDIIS_Button("width", "変換", 0),		// (-618) Chooses font width?
 IDIIS_Button("ctrl", "CTRL/Control", 0),	// CTRL
 IDIIS_Button("kp_7", "Keypad 7", 0),
 IDIIS_Button("w", "w", 0),
 IDIIS_Padding<1>(),

// E - DONE!
 IDIIS_Button("return", "return", 0), // enter
 IDIIS_Button("kp_enter", "Keypad Enter", 0), // enter
 IDIIS_Button("left_shift", "Left Shift", 0), // Left Shift
 IDIIS_Button("right_shift", "Right Shift", 0), // Right Shift
 IDIIS_Button("caps_lock", "Caps Lock", 0), // Caps Lock(mechanically-locking...)
 IDIIS_Button("delete", "Delete", 0),
 IDIIS_Button("escape", "Escape", 0),
 IDIIS_Padding<1>(),

// F - DONE(most likely)
 IDIIS_Padding<1>(),			// unknownF0
 IDIIS_Padding<1>(),			// unknownF1
 IDIIS_Padding<1>(),			// unknownF2
 IDIIS_Padding<1>(),			// unknownF3
 IDIIS_Padding<1>(),			// unknownF4
 IDIIS_Button("minus", "Minus", 0),
 IDIIS_Button("7", "7", 0),
 IDIIS_Padding<1>(),
};

PCE_Input_Device *PCEINPUT_MakeTsushinKB(void)
{
 return(new PCE_Input_TsushinKB());
}

};
