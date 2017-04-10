/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2014  JustBurn

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#ifndef POKEMINI_JOYSTICK
#define POKEMINI_JOYSTICK

#include "UI.h"

#define JOY_BUTTONS	(32)

#define JHAT_UP		(0x01)
#define JHAT_RIGHT	(0x02)
#define JHAT_DOWN	(0x04)
#define JHAT_LEFT	(0x08)

typedef void (*TJoystickUpdateCB)(int enable, int deviceid);

// Joystick menu items
extern TUIMenu_Item UIItems_Joystick[];	

// Setup joystick
void JoystickSetup(char *platform, int allowdisable, int deadzone, char **bnames, int numbuttons, int *mapping);

// Enter into the joystick menu
void JoystickEnterMenu(void);

// Register callback of when the joystick configs get updated
void JoystickUpdateCallback(TJoystickUpdateCB cb);

// Process joystick buttons packed in bits
void JoystickBitsEvent(uint32_t pressbits);

// Process joystick buttons
void JoystickButtonsEvent(int button, int pressed);

// Process joystick axis
void JoystickAxisEvent(int axis, int value);

// Process joystick hats
void JoystickHatsEvent(int hatsbitfield);

#endif
