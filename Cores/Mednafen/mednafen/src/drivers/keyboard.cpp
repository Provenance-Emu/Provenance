/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
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

#include "main.h"
#include "input.h"
#include "keyboard.h"

#include <trio/trio.h>

namespace KBMan
{

#define ICSS_ALT	1
#define ICSS_SHIFT	2
#define ICSS_CTRL	4

uint8 keys[MKK_COUNT];
uint32 mods[2][2];

static ButtConfig config_pending_bc;
static bool config_isck;

void Init(void)
{
 memset(keys, 0, sizeof(keys));
 memset(mods, 0, sizeof(mods));
}

void Kill(void)
{

}


std::string BNToString(const uint32 bn)
{
 char tmp[128];

 trio_snprintf(tmp, sizeof(tmp), "%d%s%s%s", bn & KEYBOARD_BN_INDEX_MASK,
	(bn & (ICSS_CTRL  << KEYBOARD_BN_MODS_SHIFT)) ? "+ctrl"  : "",
	(bn & (ICSS_ALT   << KEYBOARD_BN_MODS_SHIFT)) ? "+alt"   : "",
	(bn & (ICSS_SHIFT << KEYBOARD_BN_MODS_SHIFT)) ? "+shift" : "");

 return tmp;
}

bool StringToBN(const char* s, uint16* bn)
{
 const char* n = s;
 unsigned long sc = strtoul(s, (char**)&n, 10);
 uint32 m = 0;

 if(sc >= MKK_COUNT)
  return false;

 while(*n)
 {
  if(*n != '+')
   return false;

  n++;

  if(!MDFN_memazicmp(n, "alt", 3))
  {
   m |= ICSS_ALT;
   n += 3;
  }
  else if(!MDFN_memazicmp(n, "ctrl", 4))
  {
   m |= ICSS_CTRL;
   n += 4;
  }
  else if(!MDFN_memazicmp(n, "shift", 5))
  {
   m |= ICSS_SHIFT;
   n += 5;
  }
  else
   return false;
 }

 *bn = sc | (m << KEYBOARD_BN_MODS_SHIFT);

 return true;
}

void Reset_BC_ChangeCheck(bool isck)
{
 memset(&config_pending_bc, 0, sizeof(config_pending_bc));
 config_pending_bc.DeviceType = BUTTC_NONE;
 config_isck = isck;
}

bool Do_BC_ChangeCheck(ButtConfig* bc)
{
 if(config_pending_bc.DeviceType != BUTTC_NONE)
 {
  *bc = config_pending_bc;
  return true;
 }
 return false;
}

void Event(const SDL_Event* event)
{
 switch(event->type)
 {
  case SDL_KEYDOWN:
	if(event->key.repeat)
	 break;

	if(MDFN_UNLIKELY(config_pending_bc.DeviceType == BUTTC_NONE))
	{
	 if(!config_isck || (event->key.keysym.scancode != MKK(LALT) && event->key.keysym.scancode != MKK(RALT) &&
			     event->key.keysym.scancode != MKK(LSHIFT) && event->key.keysym.scancode != MKK(RSHIFT) &&
			     event->key.keysym.scancode != MKK(LCTRL) && event->key.keysym.scancode != MKK(RCTRL)))
	 {
	  config_pending_bc.DeviceType = BUTTC_KEYBOARD;
	  config_pending_bc.DeviceNum = 0;
	  config_pending_bc.DeviceID = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
	  config_pending_bc.ButtonNum = event->key.keysym.scancode;

	  if(config_isck)
	  {
	   uint32 m = 0;

	   m |= (event->key.keysym.mod & KMOD_ALT) ? ICSS_ALT : 0;
	   m |= (event->key.keysym.mod & KMOD_SHIFT) ? ICSS_SHIFT : 0;
	   m |= (event->key.keysym.mod & KMOD_CTRL) ? ICSS_CTRL : 0;

	   config_pending_bc.ButtonNum |= m << KEYBOARD_BN_MODS_SHIFT;
	  }
	 }
	}

	{
	 //printf("Down: %3u %08x %04x\n", event->key.keysym.scancode, event->key.keysym.sym, event->key.keysym.mod);
	 size_t s = event->key.keysym.scancode;

	 if(s < MKK_COUNT)
	 {
          keys[s] = (keys[s] & (KEYS_FLAG_KEYDOWN | KEYS_FLAG_KEYDOWN_SEEN)) | KEYS_FLAG_KEYDOWN;
	 }
	}
	break;

  case SDL_KEYUP:
	{
	 //printf("Up: %3u %08x %04x\n", event->key.keysym.scancode, event->key.keysym.sym, event->key.keysym.mod);
	 size_t s = event->key.keysym.scancode;

	 if(s < MKK_COUNT)
	  keys[s] |= KEYS_FLAG_KEYUP;
	}
	break;
 }
}

static void RecalcModsCache(void)
{
 for(unsigned bypass_key_masking = 0; bypass_key_masking < 2; bypass_key_masking++)
 {
  for(unsigned ignore_ralt = 0; ignore_ralt < 2; ignore_ralt++)
  {
   uint32 tmp = 0;

   if(TestSC(MKK(LALT), bypass_key_masking) || (TestSC(MKK(RALT), bypass_key_masking) & !ignore_ralt))
    tmp |= ICSS_ALT;

   if(TestSC(MKK(LSHIFT), bypass_key_masking) || TestSC(MKK(RSHIFT), bypass_key_masking))
    tmp |= ICSS_SHIFT;

   if(TestSC(MKK(LCTRL), bypass_key_masking) || TestSC(MKK(RCTRL), bypass_key_masking))
    tmp |= ICSS_CTRL;

   mods[bypass_key_masking][ignore_ralt] = tmp;
   //printf("mods[%d][%d]=%d\n", bypass_key_masking, ignore_ralt, tmp);
  }
 }
}

void UpdateKeyboards(void)
{
 for(unsigned i = 0; i < MKK_COUNT; i++)
 {
  uint8 tmp = keys[i];

  // If keyup pending, and the key was seen as being active during the last processing loop or if it's a spurious/duplicate keyup,
  // clear the key pressed state.
  if((tmp & KEYS_FLAG_KEYUP) && ((tmp & KEYS_FLAG_KEYDOWN_SEEN) || !(tmp & KEYS_FLAG_KEYDOWN)))
   tmp = 0;

  // Preserve the keyup pending bit for the next processing loop in case we didn't handle it this time, and indicate to the next processing
  // loop that the key was seen as active during this processing loop.
  tmp = (tmp & (KEYS_FLAG_KEYUP | KEYS_FLAG_KEYDOWN)) | ((tmp << 1) & KEYS_FLAG_KEYDOWN_SEEN);

  keys[i] = tmp | (tmp ? (KEYS_FLAG_PRESSED | KEYS_FLAG_PRESSED_MASKBYPASS) : 0);

  //if(tmp)
  // printf("%3u, 0x%02x\n", i, tmp);
 }

 RecalcModsCache();
}

void MaskSysKBKeys(void)
{
 for(unsigned i = 0; i < MKK_COUNT; i++)
  keys[i] &= ~KEYS_FLAG_PRESSED;

 RecalcModsCache();
}

void UnmaskSysKBKeys(const unsigned* sc, const size_t count)
{
 for(size_t i = 0; i < count; i++)
  keys[sc[i]] |= (keys[sc[i]] >> 1) & KEYS_FLAG_PRESSED;

 RecalcModsCache();
}

}
