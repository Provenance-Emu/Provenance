/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* keyboard.h:
**  Copyright (C) 2017-2018 Mednafen Team
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

#ifndef __MDFN_DRIVERS_KEYBOARD_H
#define __MDFN_DRIVERS_KEYBOARD_H

#include "keyboard_scancodes.h"

#define MKK(k) MDFN_SCANCODE_##k
#define MKK_COUNT (MDFN_NUM_SCANCODES)

#define KBD_SCANCODE_STRING__(sc) #sc
#define KBD_SCANCODE_STRING_(sc) KBD_SCANCODE_STRING__(sc)
#define KBD_SCANCODE_STRING(sc) KBD_SCANCODE_STRING_(MKK(sc))

enum
{
 KEYBOARD_BN_INDEX_MASK = 0x0FFF,
 KEYBOARD_BN_MODS_SHIFT = 12,
 //KEYBOARD_BN_MODS_MASK = 0xF << KB_BN_MODS_SHIFT
};

namespace KBMan
{
 enum
 {
  KEYS_FLAG_PRESSED		= 0x1,
  KEYS_FLAG_PRESSED_MASKBYPASS	= (KEYS_FLAG_PRESSED << 1),
  //
  KEYS_FLAG_KEYUP 		= 0x4,
  KEYS_FLAG_KEYDOWN 		= 0x8,
  KEYS_FLAG_KEYDOWN_SEEN	= (KEYS_FLAG_KEYDOWN << 1),
 };

 extern uint8 keys[MKK_COUNT];
 extern uint32 mods[2][2];

 void Init(void) MDFN_COLD;
 void Kill(void) MDFN_COLD;

 void Reset_BC_ChangeCheck(bool isck);
 bool Do_BC_ChangeCheck(ButtConfig* bc);

 void Event(const SDL_Event* event);
 void UpdateKeyboards(void);

 void MaskSysKBKeys(void);
 void UnmaskSysKBKeys(const unsigned* sc, const size_t count);

 std::string BNToString(const uint32 bn);
 bool StringToBN(const char* s, uint16* bn);

 INLINE bool TestSC(const size_t sc, const bool bypass_key_masking)
 {
  return (keys[sc] >> bypass_key_masking) & KEYS_FLAG_PRESSED;
 }

 INLINE bool TestButton(const ButtConfig& bc, const bool bypass_key_masking)
 {
  return TestSC(bc.ButtonNum & KEYBOARD_BN_INDEX_MASK, bypass_key_masking);
 }

 INLINE bool TestButtonWithMods(const ButtConfig&bc, const bool bypass_key_masking, const bool ignore_ralt)
 {
  return TestButton(bc, bypass_key_masking) & ((unsigned)(bc.ButtonNum >> KEYBOARD_BN_MODS_SHIFT) == mods[bypass_key_masking][ignore_ralt]);
 }

 INLINE int32 TestAnalogButton(const ButtConfig& bc, const bool bypass_key_masking)
 {
  return std::min<int32>(32767, ((TestButton(bc, bypass_key_masking) ? 32767 : 0) * bc.Scale) >> 12);
 }

 INLINE int64 TestAxisRel(const ButtConfig& bc, const bool bypass_key_masking)
 {
  return (int64)(TestButton(bc, bypass_key_masking) * bc.Scale) << 4;
 }
}

#endif
