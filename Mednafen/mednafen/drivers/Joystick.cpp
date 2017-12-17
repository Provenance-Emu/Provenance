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

Joystick::Joystick() : num_axes(0), num_rel_axes(0), num_buttons(0), id(0)
{
 name[0] = 0;
}

Joystick::~Joystick()
{

}

void Joystick::CalcOldStyleID(unsigned arg_num_axes, unsigned arg_num_balls, unsigned arg_num_hats, unsigned arg_num_buttons)
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

 id = ret;
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

JoystickManager::JoystickManager()
{
 JoystickDriver *main_driver = NULL;
 JoystickDriver *hicp_driver = NULL;

 MDFNI_printf(_("Initializing joysticks...\n"));
 MDFN_indent(1);

#if 0 && defined(WIN32)
 {
  JoystickDriver *dx5_driver = JoystickDriver_DX5_New(false);
  JoystickDriver *dx8_driver = JoystickDriver_DX8_New(false);

  while(1)
  {
   dx5_driver->UpdateJoysticks();
   dx8_driver->UpdateJoysticks();


  }
 }
#endif

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
    ce.config_prio = (JoystickDrivers[jd] == hicp_driver) ? 1 : 0;

    TryAgain:
    for(unsigned nji = 0; nji < JoystickCache.size(); nji++)
    {
     if(JoystickCache[nji].UniqueID == ce.UniqueID)
     {
      ce.UniqueID++;
      goto TryAgain;
     }
    }

    MDFN_printf(_("Joystick %u - %s - Unique ID: %016llx\n"), (unsigned)JoystickCache.size(), ce.joystick->Name(), (unsigned long long)ce.UniqueID);

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
  MDFND_PrintError(e.what());
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
 }
 MDFN_indent(-1);
}

void JoystickManager::SetAnalogThreshold(double thresh)
{
 AnalogThreshold = thresh * 32767;
}

JoystickManager::~JoystickManager()
{
 for(unsigned i = 0; i < JoystickDrivers.size(); i++)
  delete JoystickDrivers[i];
}

unsigned JoystickManager::DetectAnalogButtonsForChangeCheck(void)
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

void JoystickManager::Reset_BC_ChangeCheck(void)
{
 for(unsigned i = 0; i < JoystickCache.size(); i++)
  JoystickCache[i].prev_state_valid = false;

 memset(&BCPending, 0, sizeof(BCPending));
 BCPending.ButtType = BUTTC_NONE;
 BCPending_Prio = -1;
 BCPending_CCCC = 0;
}

bool JoystickManager::Do_BC_ChangeCheck(ButtConfig *bc) //, bool hint_analog)
{
 if(BCPending.ButtType != BUTTC_NONE)
 {
  if((BCPending_Time + 150) <= MDFND_GetTime() && BCPending_CCCC >= 5) //(int32)(MDFND_GetTime() - BCPending_Time) >= 150)
  {
   *bc = BCPending;
   BCPending.ButtType = BUTTC_NONE;
   BCPending_Prio = -1;
   BCPending_CCCC = 0;
   return(true);
  }

  int SaveAT = AnalogThreshold;	// Begin Kludge
  AnalogThreshold = ((JoystickCache[BCPending.DeviceNum].config_prio > 0) ? 25000 : 26000);
  if(!TestButton(BCPending))
  {
   BCPending.ButtType = BUTTC_NONE;
   BCPending_Prio = -1;
   BCPending_CCCC = 0;
  }
  else
   BCPending_CCCC++;
  AnalogThreshold = SaveAT;	// End Kludge.
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

     bctmp.ButtType = BUTTC_JOYSTICK;
     bctmp.DeviceNum = i;
     bctmp.ButtonNum = button;
     bctmp.DeviceID = jsc->UniqueID;

     if(jsc->config_prio >= 0 && (jsc->config_prio > BCPending_Prio || 0))	// TODO: add axis/button priority logic(replace || 0) for gamepads that send axis and button events for analog button presses.
     {
      BCPending = bctmp;
      BCPending_Prio = jsc->config_prio;
      BCPending_Time = MDFND_GetTime();
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

      bctmp.ButtType = BUTTC_JOYSTICK;
      bctmp.DeviceNum = i;

      if(jsc->axis_config_type[axis] == JoystickManager_Cache::AXIS_CONFIG_TYPE_ANABUTTON_POSPRESS)
       bctmp.ButtonNum = (1 << 16) | axis;
      else if(jsc->axis_config_type[axis] == JoystickManager_Cache::AXIS_CONFIG_TYPE_ANABUTTON_NEGPRESS)
       bctmp.ButtonNum = (1 << 16) | (1 << 17) | axis;
      else
       bctmp.ButtonNum = 0x8000 | axis | ((axis_state < 0) ? 0x4000 : 0);

      bctmp.DeviceID = jsc->UniqueID;

      if(jsc->config_prio >= 0 && (jsc->config_prio > BCPending_Prio || 0))	// TODO: add axis/button priority logic(replace || 0) for gamepads that send axis and button events for analog button presses.
      {
       BCPending = bctmp;
       BCPending_Prio = jsc->config_prio;
       BCPending_Time = MDFND_GetTime();
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

void JoystickManager::SetRumble(const std::vector<ButtConfig> &bc, uint8 weak_intensity, uint8 strong_intensity)
{
 for(unsigned i = 0; i < bc.size(); i++)
 {
  if(bc[i].ButtType != BUTTC_JOYSTICK)
   continue;

  if(bc[i].DeviceNum >= JoystickCache.size())
   continue;

  Joystick *joy = JoystickCache[bc[i].DeviceNum].joystick;
  joy->SetRumble(weak_intensity, strong_intensity);
 }
}

void JoystickManager::TestRumble(void)
{
 uint8 weak, strong;
 //uint32 cur_time = MDFND_GetTime();

 strong = 255;
 weak = 0;
 for(unsigned i = 0; i < JoystickCache.size(); i++)
 {
  Joystick *joy = JoystickCache[i].joystick; 
  joy->SetRumble(weak, strong);
 }
}

void JoystickManager::UpdateJoysticks(void)
{
 //TestRumble();
 for(unsigned i = 0; i < JoystickDrivers.size(); i++)
 {
  JoystickDrivers[i]->UpdateJoysticks();
 }
}

bool JoystickManager::TestButton(const ButtConfig &bc)
{
 if(bc.DeviceNum >= JoystickCache.size())
  return(0);

 //printf("%u\n", AnalogThreshold);

 Joystick *joy = JoystickCache[bc.DeviceNum].joystick;

 if(bc.ButtonNum & (0x8000 | 0x2000))      /* Axis "button" (| 0x2000 for backwards-compat hat translation)*/
 {
  bool neg_req = (bool)(bc.ButtonNum & 0x4000);
  unsigned axis = bc.ButtonNum & 0x3FFF;
  int pos;

  if(bc.ButtonNum & 0x2000)
  {
   axis = joy->HatToAxisCompat((bc.ButtonNum >> 8) & 0x1F);
   if(axis == ~0U)	// Not-implemented case.  See if implemented for buttons.
   {
    unsigned button = joy->HatToButtonCompat((bc.ButtonNum >> 8) & 0x1F);

    if(button != ~0U)
    {
     button += uilog2(bc.ButtonNum & 0xF);

     if(button >= joy->NumButtons())
      return(0);

     return joy->GetButton(button);
    }
    return(0);
   }

   if(bc.ButtonNum & 0x05)
    axis++;

   neg_req = bc.ButtonNum & 0x09;
  }

  if(axis >= joy->NumAxes())
   return(0);

  pos = joy->GetAxis(axis);

  if(neg_req && (pos <= -AnalogThreshold))
   return(1);
  else if(!neg_req && (pos >= AnalogThreshold))
   return(1);
 }
 else if(bc.ButtonNum & (1 << 16))	// Analog button axis.
 {
  unsigned axis = bc.ButtonNum & 0x3FFF;
  int pos;

  if(axis >= joy->NumAxes())
   return(0);

  pos = joy->GetAxis(axis);
  if(pos < -32767)
   pos = -32767;

  if(bc.ButtonNum & (1 << 17))
   pos = -pos;

  pos += 32767;
  pos >>= 1;

  if(pos >= AnalogThreshold)
   return(1);
 }
 else
 {
  unsigned button = bc.ButtonNum;

  if(button >= joy->NumButtons())
   return(0);

  return joy->GetButton(button);
 }

 return(0);
}

int JoystickManager::TestAnalogButton(const ButtConfig &bc)
{
 if(bc.DeviceNum >= JoystickCache.size())
  return(0);

 Joystick *joy = JoystickCache[bc.DeviceNum].joystick;

 if(bc.ButtonNum & 0x8000)      /* Axis "button" */
 {
  unsigned axis = bc.ButtonNum & 0x3FFF;
  int pos;

  if(axis >= joy->NumAxes())
   return(0);
  pos = joy->GetAxis(axis);

  if((bc.ButtonNum & 0x4000) && pos < 0)
   return(std::min<int>(-pos, 32767));
  else if (!(bc.ButtonNum & 0x4000) && pos > 0)
   return(pos);
 }
 else if(bc.ButtonNum & (1 << 16))	// Analog button axis.
 {
  unsigned axis = bc.ButtonNum & 0x3FFF;
  int pos;

  if(axis >= joy->NumAxes())
   return(0);

  pos = joy->GetAxis(axis);
  if(pos < -32767)
   pos = -32767;

  if(bc.ButtonNum & (1 << 17))
   pos = -pos;

  pos += 32767;
  pos >>= 1;

  return(pos);
 }
 else
 {
  return(TestButton(bc) ? 32767 : 0);
 }

 return(0);
}

unsigned JoystickManager::GetIndexByUniqueID(uint64 unique_id)
{
 for(unsigned i = 0; i < JoystickCache.size(); i++)
 {
  if(JoystickCache[i].UniqueID == unique_id)
  {
   //printf("%16llx %u\n", unique_id, i);
   return(i);
  }
 }

 return(~0U);
}

unsigned JoystickManager::GetUniqueIDByIndex(unsigned index)
{
 return JoystickCache[index].UniqueID;
}
