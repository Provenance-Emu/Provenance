/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* mouse.cpp:
**  Copyright (C) 2012-2018 Mednafen Team
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
#include "mouse.h"
#include "video.h"
#include <trio/trio.h>
#include <mednafen/hash/md5.h>
#include <mednafen/math_ops.h>

namespace MouseMan
{
//
//
//
static int32 MouseDataRel[4];

static uint32 MouseDataButtons;
static float MouseDataPointer[2];
static int32 MouseDataPointerAsAxis[2];
//
//
//
static struct __MouseState
{
 int x, y;

 int32 rel_accum[4];

 uint32 button;
 uint32 button_realstate;
 uint32 button_prevsent;
} MouseState = { 0, 0, 0, 0, 0, 0, 0 };
//
//
//
static ButtConfig config_pending_bc;

void Init(void)
{
 memset(&MouseState, 0, sizeof(MouseState));
 memset(MouseDataRel, 0, sizeof(MouseDataRel));
 memset(MouseDataPointer, 0, sizeof(MouseDataPointer));
 memset(MouseDataPointerAsAxis, 0, sizeof(MouseDataPointerAsAxis));
 MouseDataButtons = 0;

 memset(&config_pending_bc, 0, sizeof(config_pending_bc));
}

/*
 The mouse button handling convolutedness is to make sure that an extremely quick mouse button press and release will
 still register as pressed for 1 emulated frame, and without otherwise increasing the lag of a mouse button release(which
 is what the button_prevsent is for).
*/
void UpdateMice(void)
{
 //printf("%08x -- %08x %08x\n", MouseState.button & (MouseState.button_realstate | ~MouseState.button_prevsent), MouseState.button, MouseState.button_realstate);

 Video_PtoV(MouseState.x, MouseState.y, &MouseDataPointer[0], &MouseDataPointer[1]);
 {
  const int32 nw_nh_min = std::min<int32>(CurGame->nominal_width, CurGame->nominal_height);

  MouseDataPointerAsAxis[0] = std::min<int32>(32767, std::max<int32>(-32768, 32768 * (MouseDataPointer[0] * 2 - 1) * CurGame->nominal_width  / nw_nh_min));
  MouseDataPointerAsAxis[1] = std::min<int32>(32767, std::max<int32>(-32768, 32768 * (MouseDataPointer[1] * 2 - 1) * CurGame->nominal_height / nw_nh_min));
  //printf("%d %d\n", MouseDataPointerAsAxis[0], MouseDataPointerAsAxis[1]);
 }
 MouseDataButtons = MouseState.button & (MouseState.button_realstate | ~MouseState.button_prevsent);

 MouseState.button_prevsent = MouseDataButtons;
 MouseState.button &= MouseState.button_realstate;

 for(unsigned i = 0; i < 4; i++)
 {
  MouseDataRel[i] = MouseState.rel_accum[i];
  MouseState.rel_accum[i] = 0;
 }
}

void Event(const SDL_Event* event)
{
 switch(event->type)
 {
  case SDL_MOUSEBUTTONDOWN:
	if(event->button.state == SDL_PRESSED)
	{
	 if(MDFN_UNLIKELY(config_pending_bc.DeviceType == BUTTC_NONE))
	 {
	  config_pending_bc.DeviceType = BUTTC_MOUSE;
	  config_pending_bc.DeviceNum = 0;
	  config_pending_bc.DeviceID = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
	  config_pending_bc.ButtonNum = event->button.button - 1;
	 }

	 MouseState.button |= 1 << (event->button.button - 1);
	 MouseState.button_realstate |= 1 << (event->button.button - 1);
	}
	break;

  case SDL_MOUSEBUTTONUP:
	if(event->button.state == SDL_RELEASED)
	{
	 MouseState.button_realstate &= ~(1 << (event->button.button - 1));
	}
        break;

  case SDL_MOUSEMOTION:
	MouseState.x = event->motion.x;
	MouseState.y = event->motion.y;
	MouseState.rel_accum[0] += event->motion.xrel;
	MouseState.rel_accum[1] += event->motion.yrel;
	break;

  case SDL_MOUSEWHEEL:
	MouseState.rel_accum[2] += event->wheel.x; // * ((event->wheel.direction == SDL_MOUSEWHEEL_FLIPPED) ? -1 : 1);
	MouseState.rel_accum[3] += event->wheel.y;
	break;

 }
}

void Reset_BC_ChangeCheck(void)
{
 memset(&config_pending_bc, 0, sizeof(config_pending_bc));
 config_pending_bc.DeviceType = BUTTC_NONE;
}

bool Do_BC_ChangeCheck(ButtConfig *bc)
{
 if(config_pending_bc.DeviceType == BUTTC_MOUSE)
 {
  *bc = config_pending_bc;
  return true;
 }

 return false;
}

static const char* mousebstab[5] = { "left", "middle", "right", "x1", "x2" };
std::string BNToString(const uint32 bn)
{
 static const char* hntab[2][2] = { { "-+", "+-" }, { "+", "-" } };
 char tmp[256];
 std::string ret;
 const unsigned index = bn & MOUSE_BN_INDEX_MASK;
 const unsigned type = bn & MOUSE_BN_TYPE_MASK;

 switch(type)
 {
  case MOUSE_BN_TYPE_BUTTON:
	if(index < sizeof(mousebstab) / sizeof(mousebstab[0]))
	 trio_snprintf(tmp, sizeof(tmp), "button_%s", mousebstab[index]);
	else
	 trio_snprintf(tmp, sizeof(tmp), "button_%u", index);
	return tmp;

  case MOUSE_BN_TYPE_CURSOR:
  case MOUSE_BN_TYPE_REL:
	trio_snprintf(tmp, sizeof(tmp), "%s_%s%s",
		(type == MOUSE_BN_TYPE_REL) ? "rel" : "cursor",
		(index & 1) ? "y" : "x",
		hntab[(bool)(bn & MOUSE_BN_HALFAXIS)][(bool)(bn & MOUSE_BN_NEGATE)]);
	return tmp;
 }

 abort();

 return "";
}

bool StringToBN(const char* s, uint16* bn)
{
 char type_str[32];
 char idx_flags_str[32];

 if(trio_sscanf(s, "%31[^_]_%31[^_]", type_str, idx_flags_str) == 2)
 {
  unsigned type;

  if(!strcmp(type_str, "cursor"))
   type = MOUSE_BN_TYPE_CURSOR;
  else if(!strcmp(type_str, "rel"))
   type = MOUSE_BN_TYPE_REL;
  else if(!strcmp(type_str, "button"))
   type = MOUSE_BN_TYPE_BUTTON;
  else
   return false;

  if(type == MOUSE_BN_TYPE_BUTTON)
  {
   unsigned index = ~0U;

   for(unsigned i = 0; i < sizeof(mousebstab) / sizeof(mousebstab[0]); i++)
   {
    if(!strcmp(idx_flags_str, mousebstab[i]))
    {
     index = i;
     break;
    }
   }

   if(index == ~0U)
   {
    if(trio_sscanf(idx_flags_str, "%u", &index) != 1)
     return false;
   }

   *bn = type | (index & MOUSE_BN_INDEX_MASK);
   return true;
  }
  else
  {
   unsigned index = 0;
   unsigned flags = 0;

   if(idx_flags_str[0] == 'x')
    index = 0;
   else if(idx_flags_str[0] == 'y')
    index = 1;
   else
    return false;

   if(idx_flags_str[1] == '-' && idx_flags_str[2] == '+')
   { }
   else if(idx_flags_str[1] == '+' && idx_flags_str[2] == '-')
    flags |= MOUSE_BN_NEGATE;
   else if(idx_flags_str[1] == '+' && idx_flags_str[2] == 0)
    flags |= MOUSE_BN_HALFAXIS;
   else if(idx_flags_str[1] == '-' && idx_flags_str[2] == 0)
    flags |= MOUSE_BN_HALFAXIS | MOUSE_BN_NEGATE;
   else
    return false;

   *bn = type | flags  | (index & MOUSE_BN_INDEX_MASK);
   return true;
  }
 }

 return false;
}

bool Translate09xBN(unsigned bn09x, uint16* bn)
{
 if(bn09x & 0x8000)
 {
  *bn = MOUSE_BN_TYPE_CURSOR | (bn09x & 0x1);
  return true;
 }
 else
 {
  if(bn09x < 3)
  {
   *bn = MOUSE_BN_TYPE_BUTTON | bn09x;
   return true;
  }
  else if(bn09x == 3 || bn09x == 4)
  {
   *bn = MOUSE_BN_TYPE_REL | 3 | ((bn09x == 4) ? MOUSE_BN_NEGATE : 0) | MOUSE_BN_HALFAXIS;
   return true;
  }
  else if(bn09x == 5 || bn09x == 6)
  {
   *bn = MOUSE_BN_TYPE_BUTTON | (bn09x - 2);
   return true;
  }
  else
   return false;
 }
}

int64 TestAxisRel(const ButtConfig& bc)
{
 const uint32 bn = bc.ButtonNum;
 const unsigned index = bn & MOUSE_BN_INDEX_MASK;
 const unsigned type = bn & MOUSE_BN_TYPE_MASK;
 int32 ret = 0;

 switch(type)
 {
  case MOUSE_BN_TYPE_BUTTON:
	return (((MouseDataButtons >> (index & 0x1F)) & 1) * bc.Scale) << 4;

  case MOUSE_BN_TYPE_REL:
	ret = MouseDataRel[index & 3];
	break;
 }

 if(bn & MOUSE_BN_NEGATE)
  ret = -ret;

 if(bn & MOUSE_BN_HALFAXIS)
  ret = std::max<int32>(0, ret);

 return (int64)ret * bc.Scale;
}

float TestPointer(const ButtConfig& bc)
{
 const uint32 bn = bc.ButtonNum;
 const unsigned index = bn & MOUSE_BN_INDEX_MASK;
 const unsigned type = bn & MOUSE_BN_TYPE_MASK;
 float ret = 0;

 switch(type)
 {
  case MOUSE_BN_TYPE_CURSOR:
	ret = MouseDataPointer[index & 1];
	break;
 }

/*
 if(bn & MOUSE_BN_NEGATE)
  ret = -ret;

 if(bn & MOUSE_BN_HALFAXIS)
  ret = std::max<int32>(0, ret);
*/
 return ret;
}

static int32 TestAnalogUnscaled(const ButtConfig& bc)
{
 const uint32 bn = bc.ButtonNum;
 const unsigned index = bn & MOUSE_BN_INDEX_MASK;
 const unsigned type = bn & MOUSE_BN_TYPE_MASK;

 switch(type)
 {
  case MOUSE_BN_TYPE_BUTTON:
	return ((MouseDataButtons >> (index & 0x1F)) & 1) * 32767;

  case MOUSE_BN_TYPE_CURSOR:
	{
	 int32 ret = MouseDataPointerAsAxis[index & 1];

	 if(bn & MOUSE_BN_NEGATE)
	  ret = -ret;

	 if(!(bn & MOUSE_BN_HALFAXIS))
	  ret = (32767 + ret) >> 1;

	 return std::max<int32>(0, ret);
	}

  case MOUSE_BN_TYPE_REL:	// Mostly to (hackily, -/+ cancel) support mouse wheel motion pseudo-button mappings from <= 0.9.x
	{
	 int32 ret = std::min<int32>(1, std::max<int32>(-1, MouseDataRel[index & 3])) * 32767;

	 if(bn & MOUSE_BN_NEGATE)
	  ret = -ret;

	 if(!(bn & MOUSE_BN_HALFAXIS))
	  ret = (32767 + ret) >> 1;

	 return std::max<int32>(0, ret);
	}
	break;
 }

 return 0;
}

int32 TestAnalogButton(const ButtConfig& bc)
{
 return std::min<int32>(32767, (TestAnalogUnscaled(bc) * bc.Scale) >> 12);
}

bool TestButton(const ButtConfig& bc)
{
 return (TestAnalogUnscaled(bc) * bc.Scale) >= (15 * 4096);
}

}
