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

#ifndef INSTRUCTIONPROC_H
#define INSTRUCTIONPROC_H

#include <stdint.h>
#include "InstructionInfo.h"

// Read byte callback
typedef uint8_t (*InstructionProcReadCB)(int cpu, uint32_t addr);

// Operand number decode callback
// sout  - output to this string
// type  - character type from the dictionary
// value - input value
// result: 1 = continue, 0 = abort & error
typedef int (*InstructionProcOpNDecCB)(char *sout, char type, uint32_t addr, int value);

// Operand number encode callback
// sin    - input that contain the number/symbol
// type   - character type from the dictionary
// opcode - opcode information for the match
// data   - output data if match
// result: 1 = operand match, 0 = operand mismatch, continue
typedef int (*InstructionProcOpNEncCB)(char *sin, char type, uint32_t addr, InstructionInfo *opcode, uint8_t *data, char *err);

// Single opcode decoder
typedef struct {
	InstructionProcOpNDecCB on_opndec;	// Operand number decode callback
	InstructionProcOpNEncCB on_opnenc;	// Operand number encode callback
	char **opcode_dict;			// Opcode dictionary
	char **operand_dict;			// Operand dictionary
	char *opcode_pre;			// Opcode pre-text (Usually empty)
	char *opcode_post;			// Opcode post-text (Usually a space)
	char *operand_sep;			// Operand separator (Usually a comma)
} TSOpcDec;

// Default single opcode decoder
int DefaultOperandNumberDec(char *sout, char type, uint32_t addr, int value);
int DefaultOperandNumberEnc(char *sin, char type, uint32_t addr, InstructionInfo *opcode, uint8_t *data, char *err);
extern TSOpcDec DefaultSOpcDec;

// Get instruction data and size, return InstructionInfo
InstructionInfo *GetInstructionInfo(InstructionProcReadCB readcb, int cpu, uint32_t addr, uint8_t *data, int *size);

// Disassemble single opcode
int DisasmSingleOpcode(InstructionInfo *opcode, uint32_t addr, uint8_t *data, char *sout, TSOpcDec *sopcdec);

// Assemble single opcode
InstructionInfo *AsmSingleOpcode(char *sin, uint32_t addr, uint8_t *data, TSOpcDec *sopcdec, char *err);

#endif
