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

#ifndef POKEMINI_MULTICART
#define POKEMINI_MULTICART

#include <stdint.h>

typedef uint8_t (*TMulticartRead)(uint32_t addr);
typedef void (*TMulticartWrite)(uint32_t addr, uint8_t data);

// Multicart read/write
extern TMulticartRead MulticartRead;
extern TMulticartWrite MulticartWrite;

// Multicart state
extern int PM_MM_Type;
extern int PM_MM_Dirty;
extern int PM_MM_BusCycle;
extern int PM_MM_GetID;
extern int PM_MM_Bypass;
extern int PM_MM_Command;
extern uint32_t PM_MM_Offset;

// For misc information
extern uint32_t PM_MM_LastErase_Start;
extern uint32_t PM_MM_LastErase_End;
extern uint32_t PM_MM_LastProg;

// Set multicart
void NewMulticart(void);
void SetMulticart(int type);

#endif
