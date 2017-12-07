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

#ifndef INSTRUCTIONINFO_H
#define INSTRUCTIONINFO_H

#include <stdint.h>

typedef struct {
	uint8_t flags;	// Flags, &1 = Unofficial
	uint8_t size;	// Opcode size
	uint8_t opc;	// Opcode name
	uint8_t opclen;	// Opcode len, 0 = None, 1 = Byte, 2 = Word
	uint8_t p1;	// Operand 1
	uint8_t p1off;	// Operand 1 Offset
	uint8_t p2;	// Operand 2
	uint8_t p2off;	// Operand 2 Offset
} InstructionInfo;

extern char *DebugCPUInstructions_Opcode[];
extern char *DebugCPUInstructions_Operand[];

extern InstructionInfo DebugCPUInstructions_DX[8];
extern InstructionInfo DebugCPUInstructions_XX[256];
extern InstructionInfo DebugCPUInstructions_CE[256];
extern InstructionInfo DebugCPUInstructions_CF[256];

#endif
