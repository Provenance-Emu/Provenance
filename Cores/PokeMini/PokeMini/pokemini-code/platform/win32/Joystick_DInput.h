/*
  PokeMini - Pokémon-Mini Emulator
  Copyright (C) 2009-2012  JustBurn

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

#pragma once

#include <windows.h>

int Joystick_DInput_Init(HINSTANCE hInst, HWND hWnd);
void Joystick_DInput_Terminate(void);
int Joystick_DInput_NumJoysticks();
char *Joystick_DInput_JoystickName(int index);
int Joystick_DInput_JoystickOpen(int index);
void Joystick_DInput_JoystickClose();
void Joystick_DInput_StopRumble();
int Joystick_DInput_Process(int rumbling);
