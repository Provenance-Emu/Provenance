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
/*
 The joystick driver configuration priority system should be considered as last-resort protection for multiple-API platforms(such as DirectInput + XInput on Windows), in the
 event that all reasonable attempts at preventing the same physical device from being opened via multiple APIs fail.  (The configuration priority system generally should
 work ok as long as the user isn't extremely unlucky, doesn't try to configure too quickly(or too slowly ;)), and the controller is well-behaved; but it is still
 inherently race-conditiony).
*/
#include "main.h"
#include "input.h"
#include <trio/trio.h>
#include <mednafen/hash/md5.h>
#include <mednafen/math_ops.h>

#include "Joystick.h"

#ifdef HAVE_SDL
 #include "Joystick_SDL.h"
#endif

#ifdef HAVE_LINUX_JOYSTICK
 #include "Joystick_Linux.h"
#endif

#ifdef WIN32
 #include "Joystick_DX5.h"
 #include "Joystick_XInput.h"
#endif

#ifdef DOS
 #include "Joystick_DOS_Standard.h"
 //#include "Joystick_DOS_SideWinder.h"
#endif

Joystick::Joystick() : id_09x(0), id{{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}}, num_axes(0), num_rel_axes(0), num_buttons(0)
{

}

Joystick::~Joystick()
{

}

void Joystick::Calc09xID(unsigned arg_num_axes, unsigned arg_num_balls, unsigned arg_num_hats, unsigned arg_num_buttons)
{
 uint8 digest[16];
 int tohash[4];
 md5_context hashie;
 uint64 ret = 0;

 //printf("%u %u %u %u\n", arg_num_axes, arg_num_balls, arg_num_hats, arg_num_buttons);

 tohash[0] = arg_num_axes;
 tohash[1] = arg_num_balls;
 tohash[2] = arg_num_hats;
 tohash[3] = arg_num_buttons;

 hashie.starts();
 hashie.update((uint8 *)tohash, sizeof(tohash));
 hashie.finish(digest);

 for(int x = 0; x < 16; x++)
 {
  ret ^= (uint64)digest[x] << ((x & 7) * 8);
 }

 id_09x = ret;
}

void Joystick::SetRumble(uint8 weak_intensity, uint8 strong_intensity)
{


}

bool Joystick::IsAxisButton(unsigned axis)
{
 return(false);
}

unsigned Joystick::HatToAxisCompat(unsigned hat)
{
 return(~0U);
}

unsigned Joystick::HatToButtonCompat(unsigned hat)
{
 return(~0U);
}

JoystickDriver::JoystickDriver()
{

}

JoystickDriver::~JoystickDriver()
{

}

unsigned JoystickDriver::NumJoysticks()
{
 return 0;
}

Joystick *JoystickDriver::GetJoystick(unsigned index)
{
 return NULL;
}

void JoystickDriver::UpdateJoysticks(void)
{

}

namespace JoystickManager
{

struct JoystickManager_Cache
{
 Joystick *joystick;
 std::array<uint8, 16> UniqueID;
 uint64 UniqueID_09x;

 enum
 {
  AXIS_CONFIG_TYPE_GENERIC = 0,
  AXIS_CONFIG_TYPE_ANABUTTON_POSPRESS,
  AXIS_CONFIG_TYPE_ANABUTTON_NEGPRESS
 };

 // Helpers for input configuration(may have semantics that differ from what the names would suggest)!
 int config_prio;	// Set to -1 to exclude this joystick instance from configuration, 0 is normal, 1 is SPECIALSAUCEWITHBACON.
 std::vector<int16> axis_config_type;
 bool prev_state_valid;
 std::vector<int16> prev_axis_state;
 std::vector<int> axis_hysterical_ax_murderer;
 std::vector<bool> prev_button_state;
 std::vector<int32> rel_axis_accum_state;
};

static INLINE int TestAnalogUnscaled(const ButtConfig& bc);

static int AnalogThreshold;	// 15.12

static std::vector<JoystickDriver *> JoystickDrivers;
static std::vector<JoystickManager_Cache> JoystickCache;
static ButtConfig BCPending;
static int BCPending_Prio;
static uint32 BCPending_Time;
static uint32 BCPending_CCCC;

void Init(void)
{
 JoystickDriver *main_driver = NULL;
 JoystickDriver *hicp_driver = NULL;

 MDFNI_printf(_("Initializing joysticks...\n"));
 MDFN_indent(1);

 try
 {
  #ifdef HAVE_LINUX_JOYSTICK
  main_driver = JoystickDriver_Linux_New();
  #elif defined(WIN32)
  {
   hicp_driver = JoystickDriver_XInput_New();
   main_driver = JoystickDriver_DX5_New(hicp_driver != NULL && hicp_driver->NumJoysticks() > 0);
  }
  #elif defined(HAVE_SDL)
  main_driver = JoystickDriver_SDL_New();
  #endif

  if(hicp_driver != NULL)
  {
   JoystickDrivers.push_back(hicp_driver);
  }

  if(main_driver != NULL)
  {
   JoystickDrivers.push_back(main_driver);
  }

  for(unsigned jd = 0; jd < JoystickDrivers.size(); jd++)
  {
   for(unsigned i = 0; i < JoystickDrivers[jd]->NumJoysticks(); i++)
   {
    JoystickManager_Cache ce;

    ce.joystick = JoystickDrivers[jd]->GetJoystick(i);
    ce.UniqueID = ce.joystick->ID();
    ce.UniqueID_09x = ce.joystick->ID_09x();

    ce.config_prio = (JoystickDrivers[jd] == hicp_driver) ? 1 : 0;

    TryAgain:
    for(unsigned nji = 0; nji < JoystickCache.size(); nji++)
    {
     if(JoystickCache[nji].UniqueID == ce.UniqueID)
     {
      MDFN_en64msb(&ce.UniqueID[8], MDFN_de64msb(&ce.UniqueID[8]) + 1);
      goto TryAgain;
     }
    }

    TryAgain_09x:
    for(unsigned nji = 0; nji < JoystickCache.size(); nji++)
    {
     if(JoystickCache[nji].UniqueID_09x == ce.UniqueID_09x)
     {
      ce.UniqueID_09x++;
      goto TryAgain_09x;
     }
    }

    MDFN_printf(_("ID: 0x%016llx%016llx - %s\n"), (unsigned long long)MDFN_de64msb(&ce.UniqueID[0]), (unsigned long long)MDFN_de64msb(&ce.UniqueID[8]), ce.joystick->Name());

    ce.axis_config_type.resize(ce.joystick->NumAxes());
    ce.prev_state_valid = false;
    ce.prev_axis_state.resize(ce.joystick->NumAxes());
    ce.axis_hysterical_ax_murderer.resize(ce.joystick->NumAxes());
    ce.prev_button_state.resize(ce.joystick->NumButtons());
    ce.rel_axis_accum_state.resize(ce.joystick->NumRelAxes());

    JoystickCache.push_back(ce);
   }
  }

 }
 catch(std::exception &e)
 {
  MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
  if(main_driver != NULL)
  {
   delete main_driver;
   main_driver = NULL;
  }
  if(hicp_driver != NULL)
  {
   delete hicp_driver;
   hicp_driver = NULL;
  }

  JoystickDrivers.clear();
  JoystickCache.clear();
 }
 MDFN_indent(-1);
}

void SetAnalogThreshold(double thresh)
{
 AnalogThreshold = std::max<int32>(1, std::min<int32>(32767 * 4096, thresh * 32767 * 4096));
}

void Kill(void)
{
 for(unsigned i = 0; i < JoystickDrivers.size(); i++)
  delete JoystickDrivers[i];

 JoystickDrivers.clear();
 JoystickCache.clear();
}

unsigned DetectAnalogButtonsForChangeCheck(void)
{
 unsigned ret = 0;

 for(unsigned i = 0; i < JoystickCache.size(); i++)
 {
  for(unsigned axis = 0; axis < JoystickCache[i].joystick->NumAxes(); axis++)
  {
   JoystickCache[i].axis_config_type[axis] = JoystickManager_Cache::AXIS_CONFIG_TYPE_GENERIC;

   if(JoystickCache[i].joystick->IsAxisButton(axis))
    ret++;
   else
   {
    int pos = JoystickCache[i].joystick->GetAxis(axis);

    if(abs(pos) >= 31000)
    {
     if(pos < 0)
      JoystickCache[i].axis_config_type[axis] = JoystickManager_Cache::AXIS_CONFIG_TYPE_ANABUTTON_POSPRESS;
     else
      JoystickCache[i].axis_config_type[axis] = JoystickManager_Cache::AXIS_CONFIG_TYPE_ANABUTTON_NEGPRESS;

     printf("SPOON -- joystick=%u, axis=%u, type=%u\n", i, axis, JoystickCache[i].axis_config_type[axis]);
     ret++;
    }
   }
  }
 }
 return ret;
}

void Reset_BC_ChangeCheck(void)
{
 for(unsigned i = 0; i < JoystickCache.size(); i++)
  JoystickCache[i].prev_state_valid = false;

 memset(&BCPending, 0, sizeof(BCPending));
 BCPending.DeviceType = BUTTC_NONE;
 BCPending_Prio = -1;
 BCPending_CCCC = 0;
}

bool Do_BC_ChangeCheck(ButtConfig *bc) //, bool hint_analog)
{
 const uint32 curtime = Time::MonoMS();

 if(BCPending.DeviceType != BUTTC_NONE)
 {
  if((BCPending_Time + 150) <= curtime && BCPending_CCCC >= 5)
  {
   *bc = BCPending;
   BCPending.DeviceType = BUTTC_NONE;
   BCPending_Prio = -1;
   BCPending_CCCC = 0;
   return(true);
  }

  if(TestAnalogUnscaled(BCPending) < ((JoystickCache[BCPending.DeviceNum].config_prio > 0) ? 25000 : 26000))
  {
   BCPending.DeviceType = BUTTC_NONE;
   BCPending_Prio = -1;
   BCPending_CCCC = 0;
  }
  else
   BCPending_CCCC++;
 }

  for(unsigned i = 0; i < JoystickCache.size(); i++)
  {
   JoystickManager_Cache *const jsc = &JoystickCache[i];
   Joystick *const js = jsc->joystick;
   const int ana_low_thresh = ((jsc->config_prio > 0) ? 6000 : 5000);
   const int ana_high_thresh = ((jsc->config_prio > 0) ? 25000 : 26000);

   // Search buttons first, then axes?
   for(unsigned button = 0; button < js->NumButtons(); button++)
   {
    bool button_state = js->GetButton(button);

    if(jsc->prev_state_valid && (button_state != jsc->prev_button_state[button]) && button_state)
    {
     ButtConfig bctmp;

     bctmp.DeviceType = BUTTC_JOYSTICK;
     bctmp.DeviceNum = i;
     bctmp.ButtonNum = button;
     bctmp.DeviceID = jsc->UniqueID;

     if(jsc->config_prio >= 0 && (jsc->config_prio > BCPending_Prio || 0))	// TODO: add axis/button priority logic(replace || 0) for gamepads that send axis and button events for analog button presses.
     {
      BCPending = bctmp;
      BCPending_Prio = jsc->config_prio;
      BCPending_Time = curtime;
      BCPending_CCCC = 0;
     }
    }
    jsc->prev_button_state[button] = button_state;
   }

   for(unsigned axis = 0; axis < js->NumAxes(); axis++)
   {
    int16 axis_state = js->GetAxis(axis);

    if(jsc->axis_config_type[axis] == JoystickManager_Cache::AXIS_CONFIG_TYPE_ANABUTTON_POSPRESS)
    {
     if(axis_state < -32767)
      axis_state = -32767;

     axis_state = (axis_state + 32767) >> 1;
     //printf("%u: %u\n", axis, axis_state);
    }
    else if(jsc->axis_config_type[axis] == JoystickManager_Cache::AXIS_CONFIG_TYPE_ANABUTTON_NEGPRESS)
    {
     if(axis_state < -32767)
      axis_state = -32767;

     axis_state = -axis_state;

     axis_state = (axis_state + 32767) >> 1;
     //printf("%u: %u\n", axis, axis_state);
    }

    if(jsc->prev_state_valid)
    {
     if(jsc->axis_hysterical_ax_murderer[axis] && abs(axis_state) >= ana_high_thresh)
     {
      ButtConfig bctmp;

      bctmp.DeviceType = BUTTC_JOYSTICK;
      bctmp.DeviceNum = i;

      if(jsc->axis_config_type[axis] == JoystickManager_Cache::AXIS_CONFIG_TYPE_ANABUTTON_POSPRESS)
       bctmp.ButtonNum = JOY_BN_TYPE_ABS_AXIS | axis;
      else if(jsc->axis_config_type[axis] == JoystickManager_Cache::AXIS_CONFIG_TYPE_ANABUTTON_NEGPRESS)
       bctmp.ButtonNum = JOY_BN_TYPE_ABS_AXIS | JOY_BN_NEGATE | axis;
      else
       bctmp.ButtonNum = JOY_BN_TYPE_ABS_AXIS | JOY_BN_HALFAXIS | ((axis_state < 0) ? JOY_BN_NEGATE : 0) | axis;

      bctmp.DeviceID = jsc->UniqueID;

      if(jsc->config_prio >= 0 && (jsc->config_prio > BCPending_Prio || 0))	// TODO: add axis/button priority logic(replace || 0) for gamepads that send axis and button events for analog button presses.
      {
       BCPending = bctmp;
       BCPending_Prio = jsc->config_prio;
       BCPending_Time = curtime;
       BCPending_CCCC = 0;
      }
     }
     else if(!jsc->axis_hysterical_ax_murderer[axis] && abs(axis_state) < ana_low_thresh)
     {
      jsc->axis_hysterical_ax_murderer[axis] = 1;
     }
    }
    else
    {
     if(abs(axis_state) >= ana_low_thresh)
      jsc->axis_hysterical_ax_murderer[axis] = 0;
     else
      jsc->axis_hysterical_ax_murderer[axis] = 1;
    }

    jsc->prev_axis_state[axis] = axis_state;
   }
   //
   //
   jsc->prev_state_valid = true;
  }

 return(false);
}

void SetRumble(const std::vector<ButtConfig> &bc, uint8 weak_intensity, uint8 strong_intensity)
{
 for(unsigned i = 0; i < bc.size(); i++)
 {
  if(bc[i].DeviceType != BUTTC_JOYSTICK)
   continue;

  if(bc[i].DeviceNum >= JoystickCache.size())
   continue;

  Joystick *joy = JoystickCache[bc[i].DeviceNum].joystick;
  joy->SetRumble(weak_intensity, strong_intensity);
 }
}

void UpdateJoysticks(void)
{
 //TestRumble();
 for(unsigned i = 0; i < JoystickDrivers.size(); i++)
 {
  JoystickDrivers[i]->UpdateJoysticks();
 }
}

static INLINE int TestAnalogUnscaled(const ButtConfig& bc)
{
 if(bc.DeviceNum >= JoystickCache.size())
  return false;

 Joystick *joy = JoystickCache[bc.DeviceNum].joystick;
 unsigned type = bc.ButtonNum & JOY_BN_TYPE_MASK;
 unsigned index = bc.ButtonNum & JOY_BN_INDEX_MASK;
 bool negate = (bool)(bc.ButtonNum & JOY_BN_NEGATE);
 bool halfaxis = (bool)(bc.ButtonNum & JOY_BN_HALFAXIS);
 int32 pos;

 //
 //
 if(type == JOY_BN_TYPE_HATCOMPAT)
 {
  const unsigned old_index = index;

  index = joy->HatToAxisCompat((old_index >> 4) & 0x1F);
  if(index == ~0U)	// Not-implemented case.  See if implemented for buttons.
  {
   index = joy->HatToButtonCompat((old_index >> 4) & 0x1F);

   if(index != ~0U)
   {
    type = JOY_BN_TYPE_BUTTON;
    index += MDFN_log2(old_index & 0xF);
   }
   else
    return 0;
  }
  else
  {
   type = JOY_BN_TYPE_ABS_AXIS;
   halfaxis = true;

   if(old_index & 0x05)
    index++;

   negate = (bool)(old_index & 0x09);
  }
 }
 //
 //

 switch(bc.ButtonNum & JOY_BN_TYPE_MASK)
 {
  case JOY_BN_TYPE_BUTTON:
	if(index >= joy->NumButtons())
	 return 0;

	return joy->GetButton(index) ? 32767 : 0;
  //
  //
  //
  case JOY_BN_TYPE_ABS_AXIS:
	if(index >= joy->NumAxes())
	 return 0;

	pos = joy->GetAxis(index);
	if(pos < -32767)
	 pos = -32767;

	if(negate)
	 pos = -pos;

	if(halfaxis)
	 pos = std::max<int>(0, pos);
	else
	 pos = (pos + 32767) >> 1;

	return pos;
 }

 return 0;
}

int TestAnalogButton(const ButtConfig &bc)
{
 return std::min<int>(32767, (TestAnalogUnscaled(bc) * bc.Scale) >> 12);
}

bool TestButton(const ButtConfig &bc)
{
 return (TestAnalogUnscaled(bc) * bc.Scale) >= AnalogThreshold;
}

int64 TestAxisRel(const ButtConfig &bc)
{
 if((bc.ButtonNum & JOY_BN_TYPE_MASK) == JOY_BN_TYPE_REL_AXIS)
 {
  if(bc.DeviceNum >= JoystickCache.size())
   return 0;

  Joystick *joy = JoystickCache[bc.DeviceNum].joystick;

  const unsigned index = bc.ButtonNum & JOY_BN_INDEX_MASK;
  const bool negate = (bool)(bc.ButtonNum & JOY_BN_NEGATE);
  const bool halfaxis = (bool)(bc.ButtonNum & JOY_BN_HALFAXIS);

  if(index >= joy->NumRelAxes())
   return 0;

  int32 ret = joy->GetRelAxis(index);

  if(negate)
   ret = -ret;

  if(halfaxis)
   ret = std::max<int32>(0, ret);

  return (int64)ret * bc.Scale;
 }
 else
  return (TestAnalogUnscaled(bc) * bc.Scale) >> 10;
}

std::string BNToString(const uint32 bn)
{
 char tmp[256] = { 0 };
 const unsigned type = bn & JOY_BN_TYPE_MASK;

 switch(type)
 {
  case JOY_BN_TYPE_BUTTON:
	trio_snprintf(tmp, sizeof(tmp), "button_%u", bn & JOY_BN_INDEX_MASK);
	break;

  case JOY_BN_TYPE_ABS_AXIS:
  case JOY_BN_TYPE_REL_AXIS:
	trio_snprintf(tmp, sizeof(tmp), "%s_%u%s%s",
		(type == JOY_BN_TYPE_REL_AXIS) ? "rel" : "abs",
		bn & JOY_BN_INDEX_MASK,
		(bn & JOY_BN_HALFAXIS) ? ((bn & JOY_BN_NEGATE) ? "-" : "+") : ((bn & JOY_BN_NEGATE) ? "+-" : "-+"),
		(bn & JOY_BN_GUN_TRANSLATE) ? "g" : "");
	break;

  case JOY_BN_TYPE_HATCOMPAT:
	trio_snprintf(tmp, sizeof(tmp), "hatcompat_%04x", bn & JOY_BN_INDEX_MASK);
	break;
 }

 return tmp;
}

bool StringToBN(const char* s, uint16* bn)
{
 char type_str[32];
 unsigned index;
 char pol_str[3] = { 0 };
 char flags_str[2] = { 0 };

 if(trio_sscanf(s, "%31[^_]_%u%2[-+]%1s", type_str, &index, pol_str, flags_str) >= 2 && (index <= JOY_BN_INDEX_MASK))
 {
  unsigned type;

  if(!strcmp(type_str, "abs"))
   type = JOY_BN_TYPE_ABS_AXIS;
  else if(!strcmp(type_str, "rel"))
   type = JOY_BN_TYPE_REL_AXIS;
  else if(!strcmp(type_str, "button"))
   type = JOY_BN_TYPE_BUTTON;
  else
   return false;

  if(type == JOY_BN_TYPE_BUTTON)
  {
   *bn = type | index;
   return true;
  }
  else
  {
   unsigned flags = 0;

   if(pol_str[0] == '-' && pol_str[1] == '+')
   { }
   else if(pol_str[0] == '+' && pol_str[1] == '-')
    flags |= JOY_BN_NEGATE;
   else if(pol_str[0] == '+' && pol_str[1] == 0)
    flags |= JOY_BN_HALFAXIS;
   else if(pol_str[0] == '-' && pol_str[1] == 0)
    flags |= JOY_BN_HALFAXIS | JOY_BN_NEGATE;
   else
    return false;

   if(flags_str[0] == 'g')
    flags |= JOY_BN_GUN_TRANSLATE;

   *bn = type | flags | index;
   return true;
  }
 }

 return false;
}

bool Translate09xBN(unsigned bn09x, uint16* bn, bool abs_pointer_axis_thing)
{
 unsigned type;
 unsigned index;
 unsigned flags = 0;

 if(bn09x & 0x2000)
 {
  type = JOY_BN_TYPE_HATCOMPAT;
  index = (bn09x & 0xF) | ((bn09x >> 4) & 0x1F0);
 }
 else if(bn09x & 0x18000)
 {
  type = JOY_BN_TYPE_ABS_AXIS;
  index = bn09x & 0x1FFF;

  if(abs_pointer_axis_thing)
  {
   if(bn09x & 0x4000)
    flags |= JOY_BN_NEGATE;

   if(bn09x & (1U << 18))
    flags |= JOY_BN_GUN_TRANSLATE;
  }
  else
  {
   if(bn09x & (1U << 16))
   {
    if(bn09x & (1U << 17))
     flags |= JOY_BN_NEGATE;
   }
   else
   {
    flags |= JOY_BN_HALFAXIS;

    if(bn09x & 0x4000)
     flags |= JOY_BN_NEGATE;
   }
  }
 }
 else
 {
  type = JOY_BN_TYPE_BUTTON;
  index = bn09x & 0x1FFF;
 }

 if(index > JOY_BN_INDEX_MASK)
  return false;

 *bn = type | flags | index;

 return true;
}


unsigned GetIndexByUniqueID(const std::array<uint8, 16>& unique_id)
{
 for(unsigned i = 0; i < JoystickCache.size(); i++)
 {
  if(JoystickCache[i].UniqueID == unique_id)
   return i;
 }

 return ~0U;
}

unsigned GetIndexByUniqueID_09x(uint64 unique_id)
{
 for(unsigned i = 0; i < JoystickCache.size(); i++)
 {
  if(JoystickCache[i].UniqueID_09x == unique_id)
  {
   //printf("%16llx %u\n", unique_id, i);
   return(i);
  }
 }

 return(~0U);
}

std::array<uint8, 16> GetUniqueIDByIndex(unsigned index)
{
 if(index >= JoystickCache.size())
  return { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

 return JoystickCache[index].UniqueID;
}

}
