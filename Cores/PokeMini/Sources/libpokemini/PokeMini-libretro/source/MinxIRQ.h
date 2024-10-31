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

#ifndef MINXHW_IRQ
#define MINXHW_IRQ

#include <stdint.h>

// Master IRQ enable
extern int MinxIRQ_MasterIRQ;


int MinxIRQ_Create(void);

void MinxIRQ_Destroy(void);

void MinxIRQ_Reset(int hardreset);

int MinxIRQ_LoadState(FILE *fi, uint32_t bsize);

int MinxIRQ_SaveState(FILE *fi);

void MinxIRQ_SetIRQ(uint8_t intr);

uint8_t MinxIRQ_ReadReg(int cpu, uint8_t reg);

void MinxIRQ_WriteReg(int cpu, uint8_t reg, uint8_t val);

void MinxIRQ_Process(void);

//
// Callbacks (Written by the user)
//

void MinxIRQ_OnIRQ(uint8_t intr);

#endif
