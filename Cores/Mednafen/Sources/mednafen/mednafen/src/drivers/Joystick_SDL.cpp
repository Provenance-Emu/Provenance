/******************************************************************************/
/* Mednafen - Multi-system Emulator                                           */
/******************************************************************************/
/* Joystick_SDL.cpp:
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
#include "Joystick.h"
#include "Joystick_SDL.h"
#include <mednafen/hash/md5.h>

#include <SDL.h>

class Joystick_SDL : public Joystick
{
 public:

 Joystick_SDL(unsigned index) MDFN_COLD;
 ~Joystick_SDL() MDFN_COLD;

 void UpdateInternal(void);

 virtual unsigned HatToButtonCompat(unsigned hat);

 private:
 SDL_Joystick *sdl_joy;
 unsigned sdl_num_axes;
 unsigned sdl_num_hats;
 unsigned sdl_num_balls;
 unsigned sdl_num_buttons;
};

unsigned Joystick_SDL::HatToButtonCompat(unsigned hat)
{
 return(sdl_num_buttons + (hat * 4));
}

Joystick_SDL::Joystick_SDL(unsigned index) : sdl_joy(NULL)
{
 sdl_joy = SDL_JoystickOpen(index);
 if(sdl_joy == NULL)
 {
  throw MDFN_Error(0, "SDL_JoystickOpen(%u) failed: %s", index, SDL_GetError());
 }

 try
 {
  name = SDL_JoystickName(sdl_joy);

  sdl_num_axes = SDL_JoystickNumAxes(sdl_joy);
  sdl_num_balls = SDL_JoystickNumBalls(sdl_joy);
  sdl_num_buttons = SDL_JoystickNumButtons(sdl_joy);
  sdl_num_hats = SDL_JoystickNumHats(sdl_joy);

  Calc09xID(sdl_num_axes, sdl_num_balls, sdl_num_hats, sdl_num_buttons);
  {
   //SDL_JoystickGUID guid = SDL_JoystickGetGUID(sdl_joy);
   //memcpy(&id[0], guid.data, 16);
   //
   // Don't use SDL's GUID, as it's just equivalent to part of the joystick name on many platforms.
   // 
   md5_context h;
   uint8 d[16];

   h.starts();
   h.update((const uint8*)name.data(), name.size());
   h.finish(d);
   memcpy(&id[0], d, 8);

   MDFN_en16msb(&id[ 8], sdl_num_axes);
   MDFN_en16msb(&id[10], sdl_num_buttons);
   MDFN_en16msb(&id[12], sdl_num_hats);
   MDFN_en16msb(&id[14], sdl_num_balls);
  }
  num_axes = sdl_num_axes;
  num_rel_axes = sdl_num_balls * 2;
  num_buttons = sdl_num_buttons + (sdl_num_hats * 4);

  axis_state.resize(num_axes);
  rel_axis_state.resize(num_rel_axes);
  button_state.resize(num_buttons);
 }
 catch(...)
 {
  if(sdl_joy)
   SDL_JoystickClose(sdl_joy);

  throw;
 }
}

Joystick_SDL::~Joystick_SDL()
{
 if(sdl_joy)
 {
  SDL_JoystickClose(sdl_joy);
  sdl_joy = NULL;
 }
}

void Joystick_SDL::UpdateInternal(void)
{
 for(unsigned i = 0; i < sdl_num_axes; i++)
 {
  axis_state[i] = SDL_JoystickGetAxis(sdl_joy, i);
  if(axis_state[i] < -32767)
   axis_state[i] = -32767;
 }

 for(unsigned i = 0; i < sdl_num_balls; i++)
 {
  int dx, dy;

  SDL_JoystickGetBall(sdl_joy, i, &dx, &dy);

  rel_axis_state[i * 2 + 0] = dx;
  rel_axis_state[i * 2 + 1] = dy;
 }

 for(unsigned i = 0; i < sdl_num_buttons; i++)
 {
  button_state[i] = SDL_JoystickGetButton(sdl_joy, i);
 }

 for(unsigned i = 0; i < sdl_num_hats; i++)
 {
  uint8 hs = SDL_JoystickGetHat(sdl_joy, i);

  button_state[sdl_num_buttons + (i * 4) + 0] = (bool)(hs & SDL_HAT_UP);
  button_state[sdl_num_buttons + (i * 4) + 1] = (bool)(hs & SDL_HAT_RIGHT);
  button_state[sdl_num_buttons + (i * 4) + 2] = (bool)(hs & SDL_HAT_DOWN);
  button_state[sdl_num_buttons + (i * 4) + 3] = (bool)(hs & SDL_HAT_LEFT);
 }
}

class JoystickDriver_SDL : public JoystickDriver
{
 public:

 JoystickDriver_SDL();
 virtual ~JoystickDriver_SDL();

 virtual unsigned NumJoysticks();                       // Cached internally on JoystickDriver instantiation.
 virtual Joystick *GetJoystick(unsigned index);
 virtual void UpdateJoysticks(void);

 private:
 std::vector<Joystick_SDL *> joys;
};


JoystickDriver_SDL::JoystickDriver_SDL()
{
 SDL_InitSubSystem(SDL_INIT_JOYSTICK);

 for(int n = 0; n < SDL_NumJoysticks(); n++)
 {
  try
  {
   Joystick_SDL *jsdl = new Joystick_SDL(n);
   joys.push_back(jsdl);
  }
  catch(std::exception &e)
  {
   MDFND_OutputNotice(MDFN_NOTICE_ERROR, e.what());
  }
 }
}

JoystickDriver_SDL::~JoystickDriver_SDL()
{
 for(unsigned int n = 0; n < joys.size(); n++)
 {
  delete joys[n];
 }

 SDL_QuitSubSystem(SDL_INIT_JOYSTICK);
}

unsigned JoystickDriver_SDL::NumJoysticks(void)
{
 return joys.size();
}

Joystick *JoystickDriver_SDL::GetJoystick(unsigned index)
{
 return joys[index];
}

void JoystickDriver_SDL::UpdateJoysticks(void)
{
 SDL_JoystickUpdate();

 for(unsigned int n = 0; n < joys.size(); n++)
 {
  joys[n]->UpdateInternal();
 }
}

JoystickDriver *JoystickDriver_SDL_New(void)
{
 return new JoystickDriver_SDL();
}
