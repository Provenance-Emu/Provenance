/******************************************************************************/
/* Mednafen Sega Saturn Emulation Module                                      */
/******************************************************************************/
/* keyboard.cpp:
**  Copyright (C) 2017 Mednafen Team
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

// TODO: Debouncing?

//
// PS/2 keyboard adapter seems to do PS/2 processing near/at the end of a Saturn-side read sequence, which creates about 1 frame of extra latency
// in practice.  We handle things a bit differently here, to avoid the latency.
//
// Also, the PS/2 adapter seems to set the typematic delay to around 250ms, but we emulate it here as 400ms, as 250ms is
// a tad bit too short.  It can be changed to 250ms by adjusting a single #if statement, though.
//
// During testing, a couple of early-1990s PS/2 keyboards malfunctioned and failed to work with the PS/2 adapter.
// Not sure why, maybe a power draw issue?
//
// The keyboard emulated doesn't have special Windows-keyboard keys, as they don't appear to work correctly with the PS/2 adapter
// (scancode field is updated, but no make nor break bits are set to 1), and it's good to have some non-shared keys for input grabbing toggling purposes...
//
//

// make and break bits should not both be set to 1 at the same time.
// pause is special
// new key press halts repeat of held key, and it doesn't restart even if new key is released.
//

#include "common.h"
#include "keyboard.h"

namespace MDFN_IEN_SS
{

IODevice_Keyboard::IODevice_Keyboard() : phys{0,0,0,0}
{

}

IODevice_Keyboard::~IODevice_Keyboard()
{

}

void IODevice_Keyboard::Power(void)
{
 phase = -1;
 tl = true;
 data_out = 0x01;

 simbutt = simbutt_pend = 0;
 lock = lock_pend = 0;

 mkbrk_pend = 0;
 memset(buffer, 0, sizeof(buffer));

 //memcpy(processed, phys, sizeof(processed));
 memset(processed, 0, sizeof(processed));
 memset(fifo, 0, sizeof(fifo));
 fifo_rdp = 0;
 fifo_wrp = 0;
 fifo_cnt = 0;

 rep_sc = -1;
 rep_dcnt = 0;
}

void IODevice_Keyboard::UpdateInput(const uint8* data, const int32 time_elapsed)
{
 phys[0] = MDFN_de64lsb(&data[0x00]);
 phys[1] = MDFN_de64lsb(&data[0x08]);
 phys[2] = MDFN_de16lsb(&data[0x10]);
 phys[3] = 0;
 //
 if(rep_dcnt > 0)
  rep_dcnt -= time_elapsed;

 for(unsigned i = 0; i < 4; i++)
 {
  uint64 tmp = phys[i] ^ processed[i];
  unsigned bp;

  while((bp = (63 ^ MDFN_lzcount64(tmp))) < 64)
  {
   const uint64 mask = ((uint64)1 << bp);
   const int sc = ((i << 6) + bp);

   if(fifo_cnt >= (fifo_size - (sc == 0x82)))
    goto fifo_oflow_abort;

   if(phys[i] & mask)
   {
    rep_sc = sc;
#if 1
    rep_dcnt = 400000;
#else
    rep_dcnt = 250000;
#endif
    fifo[fifo_wrp] = 0x800 | sc;
    fifo_wrp = (fifo_wrp + 1) % fifo_size;
    fifo_cnt++;
   }

   if(!(phys[i] & mask) == (sc != 0x82))
   {
    if(rep_sc == sc)
     rep_sc = -1;

    fifo[fifo_wrp] = 0x100 | sc;
    fifo_wrp = (fifo_wrp + 1) % fifo_size;
    fifo_cnt++;
   }

   processed[i] = (processed[i] & ~mask) | (phys[i] & mask);
   tmp &= ~mask;
  }
 }

 if(rep_sc >= 0)
 {
  while(rep_dcnt <= 0)
  {
   if(fifo_cnt >= fifo_size)
    goto fifo_oflow_abort;

   fifo[fifo_wrp] = 0x800 | rep_sc;
   fifo_wrp = (fifo_wrp + 1) % fifo_size;
   fifo_cnt++;

   rep_dcnt += 33333;
  }
 }

 fifo_oflow_abort:;
}

void IODevice_Keyboard::UpdateOutput(uint8* data)
{
 data[0x12] = lock;
}

void IODevice_Keyboard::StateAction(StateMem* sm, const unsigned load, const bool data_only, const char* sname_prefix)
{
 SFORMAT StateRegs[] =
 {
  SFVAR(fifo),
  SFVAR(fifo_rdp),
  SFVAR(fifo_wrp),
  SFVAR(fifo_cnt),

  SFVAR(phys),
  SFVAR(processed),

  SFVAR(simbutt),
  SFVAR(simbutt_pend),
  SFVAR(lock),
  SFVAR(lock_pend),

  SFVAR(rep_sc),
  SFVAR(rep_dcnt),

  SFVAR(mkbrk_pend),
  SFVAR(buffer),

  SFVAR(data_out),
  SFVAR(tl),

  SFVAR(phase),
  SFEND
 };
 char section_name[64];
 trio_snprintf(section_name, sizeof(section_name), "%s_Keyboard", sname_prefix);

 if(!MDFNSS_StateAction(sm, load, data_only, StateRegs, section_name, true) && load)
  Power();
 else if(load)
 {
  if(rep_sc >= 0 && rep_dcnt < 0)
   rep_dcnt = 0;

  fifo_rdp %= fifo_size;
  fifo_wrp %= fifo_size;
  fifo_cnt %= fifo_size + 1;
  if(phase < 0)
   phase = -1;
  else
   phase %= 12;
 }
}

uint8 IODevice_Keyboard::UpdateBus(const sscpu_timestamp_t timestamp, const uint8 smpc_out, const uint8 smpc_out_asserted)
{
 if(smpc_out & 0x40)
 {
  phase = -1;
  tl = true;
  data_out = 0x01;
 }
 else
 {
  if((bool)(smpc_out & 0x20) != tl)
  {
   tl = !tl;
   phase += (phase < 11);

   if(!phase)
   {
    if(mkbrk_pend == (uint8)mkbrk_pend && fifo_cnt)
    {
     mkbrk_pend = fifo[fifo_rdp];
     fifo_rdp = (fifo_rdp + 1) % fifo_size;
     fifo_cnt--;

     bool p = mkbrk_pend & 0x800;

     switch(mkbrk_pend & 0xFF)
     {
      case 0x89: /*  Up */ simbutt_pend = simbutt & ~(1 <<  0); simbutt_pend &= ~(p <<  1); simbutt_pend |= (p <<  0); break;
      case 0x8A: /*Down */ simbutt_pend = simbutt & ~(1 <<  1); simbutt_pend &= ~(p <<  0); simbutt_pend |= (p <<  1); break;
      case 0x86: /*Left */ simbutt_pend = simbutt & ~(1 <<  2); simbutt_pend &= ~(p <<  3); simbutt_pend |= (p <<  2); break;
      case 0x8D: /*Right*/ simbutt_pend = simbutt & ~(1 <<  3); simbutt_pend &= ~(p <<  2); simbutt_pend |= (p <<  3); break;
      case 0x22: /*   X */ simbutt_pend = simbutt & ~(1 <<  4); simbutt_pend |= (p <<  4); break;
      case 0x21: /*   C */ simbutt_pend = simbutt & ~(1 <<  5); simbutt_pend |= (p <<  5); break;
      case 0x1A: /*   Z */ simbutt_pend = simbutt & ~(1 <<  6); simbutt_pend |= (p <<  6); break;
      case 0x76: /* Esc */ simbutt_pend = simbutt & ~(1 <<  7); simbutt_pend |= (p <<  7); break;
      case 0x23: /*   D */ simbutt_pend = simbutt & ~(1 <<  8); simbutt_pend |= (p <<  8); break;
      case 0x1B: /*   S */ simbutt_pend = simbutt & ~(1 <<  9); simbutt_pend |= (p <<  9); break;
      case 0x1C: /*   A */ simbutt_pend = simbutt & ~(1 << 10); simbutt_pend |= (p << 10); break;
      case 0x24: /*   E */ simbutt_pend = simbutt & ~(1 << 11); simbutt_pend |= (p << 11); break;
      case 0x15: /*   Q */ simbutt_pend = simbutt & ~(1 << 15); simbutt_pend |= (p << 15); break;

      case 0x7E: /* Scrl */ lock_pend = lock ^ (p ? LOCK_SCROLL : 0); break;
      case 0x77: /* Num  */ lock_pend = lock ^ (p ? LOCK_NUM : 0);    break;
      case 0x58: /* Caps */ lock_pend = lock ^ (p ? LOCK_CAPS : 0);   break;
     }
    }
    buffer[ 0] = 0x3;
    buffer[ 1] = 0x4;
    buffer[ 2] = (((simbutt_pend >>  0) ^ 0xF) & 0xF);
    buffer[ 3] = (((simbutt_pend >>  4) ^ 0xF) & 0xF);
    buffer[ 4] = (((simbutt_pend >>  8) ^ 0xF) & 0xF);
    buffer[ 5] = (((simbutt_pend >> 12) ^ 0xF) & 0x8) | 0x0;
    buffer[ 6] = lock_pend;
    buffer[ 7] = ((mkbrk_pend >> 8) & 0xF) | 0x6;
    buffer[ 8] =  (mkbrk_pend >> 4) & 0xF;
    buffer[ 9] =  (mkbrk_pend >> 0) & 0xF;
    buffer[10] = 0x0;
    buffer[11] = 0x1;
   }

   if(phase == 9)
   {
    mkbrk_pend = (uint8)mkbrk_pend;
    lock = lock_pend;
    simbutt = simbutt_pend;
   }

   data_out = buffer[phase];
  }
 }

 return (smpc_out & (smpc_out_asserted | 0xE0)) | (((tl << 4) | data_out) &~ smpc_out_asserted);
}

static const IDIIS_StatusState Lock_SS[] =
{
 { "off", gettext_noop("Off") },
 { "on", gettext_noop("On") },
};

const IDIISG IODevice_Keyboard_US101_IDII =
{
 /* 0x00 */ IDIIS_Padding<1>(),
 /* 0x01 */ IDIIS_Button("f9", "F9", -1),
 /* 0x02 */ IDIIS_Padding<1>(),
 /* 0x03 */ IDIIS_Button("f5", "F5", -1),
 /* 0x04 */ IDIIS_Button("f3", "F3", -1),
 /* 0x05 */ IDIIS_Button("f1", "F1", -1),
 /* 0x06 */ IDIIS_Button("f2", "F2", -1),
 /* 0x07 */ IDIIS_Button("f12", "F12", -1),
 /* 0x08 */ IDIIS_Padding<1>(),
 /* 0x09 */ IDIIS_Button("f10", "F10", -1),
 /* 0x0A */ IDIIS_Button("f8", "F8", -1),
 /* 0x0B */ IDIIS_Button("f6", "F6", -1),
 /* 0x0C */ IDIIS_Button("f4", "F4", -1),
 /* 0x0D */ IDIIS_Button("tab", "Tab", -1),
 /* 0x0E */ IDIIS_Button("grave", "Grave `", -1),
 /* 0x0F */ IDIIS_Padding<1>(),

 /* 0x10 */ IDIIS_Padding<1>(),
 /* 0x11 */ IDIIS_Button("lalt", "Left Alt", -1),
 /* 0x12 */ IDIIS_Button("lshift", "Left Shift", -1),
 /* 0x13 */ IDIIS_Padding<1>(),
 /* 0x14 */ IDIIS_Button("lctrl", "Left Ctrl", -1),
 /* 0x15 */ IDIIS_Button("q", "Q", -1),
 /* 0x16 */ IDIIS_Button("1", "1(One)", -1),
 /* 0x17 */ IDIIS_Button("ralt", "Right Alt", -1),
 /* 0x18 */ IDIIS_Button("rctrl", "Right Ctrl", -1),
 /* 0x19 */ IDIIS_Button("kp_enter", "Keypad Enter", -1),
 /* 0x1A */ IDIIS_Button("z", "Z", -1),
 /* 0x1B */ IDIIS_Button("s", "S", -1),
 /* 0x1C */ IDIIS_Button("a", "A", -1),
 /* 0x1D */ IDIIS_Button("w", "W", -1),
 /* 0x1E */ IDIIS_Button("2", "2", -1),
 /* 0x1F */ IDIIS_Padding<1>(),

 /* 0x20 */ IDIIS_Padding<1>(),
 /* 0x21 */ IDIIS_Button("c", "C", -1),
 /* 0x22 */ IDIIS_Button("x", "X", -1),
 /* 0x23 */ IDIIS_Button("d", "D", -1),
 /* 0x24 */ IDIIS_Button("e", "E", -1),
 /* 0x25 */ IDIIS_Button("4", "4", -1),
 /* 0x26 */ IDIIS_Button("3", "3", -1),
 /* 0x27 */ IDIIS_Padding<1>(),
 /* 0x28 */ IDIIS_Padding<1>(),
 /* 0x29 */ IDIIS_Button("space", "Space", -1),
 /* 0x2A */ IDIIS_Button("v", "V", -1),
 /* 0x2B */ IDIIS_Button("f", "F", -1),
 /* 0x2C */ IDIIS_Button("t", "T", -1),
 /* 0x2D */ IDIIS_Button("r", "R", -1),
 /* 0x2E */ IDIIS_Button("5", "5", -1),
 /* 0x2F */ IDIIS_Padding<1>(),

 /* 0x30 */ IDIIS_Padding<1>(),
 /* 0x31 */ IDIIS_Button("n", "N", -1),
 /* 0x32 */ IDIIS_Button("b", "B", -1),
 /* 0x33 */ IDIIS_Button("h", "H", -1),
 /* 0x34 */ IDIIS_Button("g", "G", -1),
 /* 0x35 */ IDIIS_Button("y", "Y", -1),
 /* 0x36 */ IDIIS_Button("6", "6", -1),
 /* 0x37 */ IDIIS_Padding<1>(),
 /* 0x38 */ IDIIS_Padding<1>(),
 /* 0x39 */ IDIIS_Padding<1>(),
 /* 0x3A */ IDIIS_Button("m", "M", -1),
 /* 0x3B */ IDIIS_Button("j", "J", -1),
 /* 0x3C */ IDIIS_Button("u", "U", -1),
 /* 0x3D */ IDIIS_Button("7", "7", -1),
 /* 0x3E */ IDIIS_Button("8", "8", -1),
 /* 0x3F */ IDIIS_Padding<1>(),

 /* 0x40 */ IDIIS_Padding<1>(),
 /* 0x41 */ IDIIS_Button("comma", "Comma ,", -1),
 /* 0x42 */ IDIIS_Button("k", "K", -1),
 /* 0x43 */ IDIIS_Button("i", "I", -1),
 /* 0x44 */ IDIIS_Button("o", "O", -1),
 /* 0x45 */ IDIIS_Button("0", "0(Zero)", -1),
 /* 0x46 */ IDIIS_Button("9", "9", -1),
 /* 0x47 */ IDIIS_Padding<1>(),
 /* 0x48 */ IDIIS_Padding<1>(),
 /* 0x49 */ IDIIS_Button("period", "Period .", -1),
 /* 0x4A */ IDIIS_Button("slash", "Slash /", -1),
 /* 0x4B */ IDIIS_Button("l", "L", -1),
 /* 0x4C */ IDIIS_Button("semicolon", "Semicolon ;", -1),
 /* 0x4D */ IDIIS_Button("p", "P", -1),
 /* 0x4E */ IDIIS_Button("Minus", "Minus -", -1),
 /* 0x4F */ IDIIS_Padding<1>(),

 /* 0x50 */ IDIIS_Padding<1>(),
 /* 0x51 */ IDIIS_Padding<1>(),
 /* 0x52 */ IDIIS_Button("quote", "Quote '", -1),
 /* 0x53 */ IDIIS_Padding<1>(),
 /* 0x54 */ IDIIS_Button("leftbracket", "Left Bracket [", -1),
 /* 0x55 */ IDIIS_Button("equals", "Equals =", -1),
 /* 0x56 */ IDIIS_Padding<1>(),
 /* 0x57 */ IDIIS_Padding<1>(),
 /* 0x58 */ IDIIS_Button("capslock", "Caps Lock", -1),
 /* 0x59 */ IDIIS_Button("rshift", "Right Shift", -1),
 /* 0x5A */ IDIIS_Button("enter", "Enter", -1),
 /* 0x5B */ IDIIS_Button("rightbracket", "Right Bracket ]", -1),
 /* 0x5C */ IDIIS_Padding<1>(),
 /* 0x5D */ IDIIS_Button("backslash", "Backslash \\", -1),
 /* 0x5E */ IDIIS_Padding<1>(),
 /* 0x5F */ IDIIS_Padding<1>(),

 /* 0x60 */ IDIIS_Padding<1>(),
 /* 0x61 */ IDIIS_Padding<1>(),
 /* 0x62 */ IDIIS_Padding<1>(),
 /* 0x63 */ IDIIS_Padding<1>(),
 /* 0x64 */ IDIIS_Padding<1>(),
 /* 0x65 */ IDIIS_Padding<1>(),
 /* 0x66 */ IDIIS_Button("backspace", "Backspace", -1),
 /* 0x67 */ IDIIS_Padding<1>(),
 /* 0x68 */ IDIIS_Padding<1>(),
 /* 0x69 */ IDIIS_Button("kp_end", "Keypad End/1", -1),
 /* 0x6A */ IDIIS_Padding<1>(),
 /* 0x6B */ IDIIS_Button("kp_left", "Keypad Left/4", -1),
 /* 0x6C */ IDIIS_Button("kp_home", "Keypad Home/7", -1),
 /* 0x6D */ IDIIS_Padding<1>(),
 /* 0x6E */ IDIIS_Padding<1>(),
 /* 0x6F */ IDIIS_Padding<1>(),

 /* 0x70 */ IDIIS_Button("kp_insert", "Keypad Insert/0", -1),
 /* 0x71 */ IDIIS_Button("kp_delete", "Keypad Delete", -1),
 /* 0x72 */ IDIIS_Button("kp_down", "Keypad Down/2", -1),
 /* 0x73 */ IDIIS_Button("kp_center", "Keypad Center/5", -1),
 /* 0x74 */ IDIIS_Button("kp_right", "Keypad Right/6", -1),
 /* 0x75 */ IDIIS_Button("kp_up", "Keypad Up/8", -1),
 /* 0x76 */ IDIIS_Button("esc", "Escape", -1),
 /* 0x77 */ IDIIS_Button("numlock", "Num Lock", -1),
 /* 0x78 */ IDIIS_Button("f11", "F11", -1),
 /* 0x79 */ IDIIS_Button("kp_plus", "Keypad Plus", -1),
 /* 0x7A */ IDIIS_Button("kp_pagedown", "Keypad Pagedown/3", -1),
 /* 0x7B */ IDIIS_Button("kp_minus", "Keypad Minus", -1),
 /* 0x7C */ IDIIS_Button("kp_asterisk", "Keypad Asterisk(Multiply)", -1),
 /* 0x7D */ IDIIS_Button("kp_pageup", "Keypad Pageup/9", -1),
 /* 0x7E */ IDIIS_Button("scrolllock", "Scroll Lock", -1),
 /* 0x7F */ IDIIS_Padding<1>(),

 /* 0x80 */ IDIIS_Button("kp_slash", "Keypad Slash(Divide)", -1),
 /* 0x81 */ IDIIS_Button("insert", "Insert", -1),
 /* 0x82 */ IDIIS_Button("pause", "Pause", -1),
 /* 0x83 */ IDIIS_Button("f7", "F7", -1),
 /* 0x84 */ IDIIS_Button("printscreen", "Print Screen", -1),
 /* 0x85 */ IDIIS_Button("delete", "Delete", -1),
 /* 0x86 */ IDIIS_Button("left", "Cursor Left", -1),
 /* 0x87 */ IDIIS_Button("home", "Home", -1),
 /* 0x88 */ IDIIS_Button("end", "End", -1),
 /* 0x89 */ IDIIS_Button("up", "Up", -1),
 /* 0x8A */ IDIIS_Button("down", "Down", -1),
 /* 0x8B */ IDIIS_Button("pageup", "Page Up", -1),
 /* 0x8C */ IDIIS_Button("pagedown", "Page Down", -1),
 /* 0x8D */ IDIIS_Button("right", "Right", -1),
 /* 0x8E */ IDIIS_Padding<1>(),
 /* 0x8F */ IDIIS_Padding<1>(),

 IDIIS_Status("scrolllock_status", "Scroll Lock", Lock_SS),
 IDIIS_Status("numlock_status", "Num Lock", Lock_SS),
 IDIIS_Status("capslock_status", "Caps Lock", Lock_SS)
};

}
