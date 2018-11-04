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

#include <pspkernel.h>
#include <pspdisplay.h>
#include <pspdebug.h>
#include <pspctrl.h>
#include <pspgu.h>
#include <pspgum.h>
#include <pspaudiolib.h>
#include <pspaudio.h>
#include <psppower.h>
#include <psputility_sysparam.h>
#include <psprtc.h>
#include <time.h>

// Video access
extern uint16_t *PSP_DrawVideo;

// Exit callback (Defined by the user)
int exitCallback(int arg1, int arg2, void *common);

// Initialize
void PSP_Init();

// Flip image
void PSP_Flip();

// Clear drawing
void PSP_ClearDraw();

// Quit
void PSP_Quit();
