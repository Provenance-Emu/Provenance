// ----------------------------------------------------------------------------
//   ___  ___  ___  ___       ___  ____  ___  _  _
//  /__/ /__/ /  / /__  /__/ /__    /   /_   / |/ /
// /    / \  /__/ ___/ ___/ ___/   /   /__  /    /  emulator
//
// ----------------------------------------------------------------------------
// Copyright 2005 Greg Stanton
// 
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
// ----------------------------------------------------------------------------
// Input.h
// ----------------------------------------------------------------------------
#ifndef INPUT_H
#define INPUT_H
#ifndef DIRECTINPUT_VERSION
#define DIRECTINPUT_VERSION 0x0700
#define NULL 0
#endif

typedef enum {
  JOY_AXIS_UP,
  JOY_AXIS_DOWN,
  JOY_AXIS_LEFT,
  JOY_AXIS_RIGHT,
  JOY_PAD_UP,
  JOY_PAD_DOWN,
  JOY_PAD_LEFT,
  JOY_PAD_RIGHT,
  JOY_BUTTON_1,
  JOY_BUTTON_2,
  JOY_BUTTON_3,
  JOY_BUTTON_4,
  JOY_BUTTON_5,
  JOY_BUTTON_6,
  JOY_BUTTON_7,
  JOY_BUTTON_8,
  JOY_BUTTON_9,
  JOY_BUTTON_10,
  JOY_BUTTON_11,
  JOY_BUTTON_12
} e_joy_value;

#include <Windows.h>
#include <DInput.h>
#include "Resource.h"
#include "Common.h"
#include "Logger.h"

typedef unsigned char byte;
typedef unsigned short word;
typedef unsigned int uint;

extern bool input_Initialize(HWND hWnd, HINSTANCE hInstance);
extern bool input_GetKeyboardState(byte* input);
extern void input_Release( );
extern void input_ReleaseJoysticks( );
extern void input_ShowController1Dialog(HWND hWnd, HINSTANCE hInstance);
extern void input_ShowController2Dialog(HWND hWnd, HINSTANCE hInstance);
extern void input_ShowConsoleDialog(HWND hWnd, HINSTANCE hInstance);
extern void input_ShowUserDialog(HWND hWnd, HINSTANCE hInstance);
extern byte input_keys[17];
extern byte input_devices[17];
extern byte user_keys[2];
extern byte user_devices[2];
extern byte user_modifiers[2];

#endif
